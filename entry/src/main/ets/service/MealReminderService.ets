import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MealType } from '../model/Enums';
import { FormatUtils } from '../utils/FormatUtils';
import { AppContext } from '../utils/AppContext';

const DOMAIN: number = 0x0000;
const TAG: string = 'MealReminder';

/** 配置存储：单独一个 preferences 文件，与健康数据的关系库互不干扰 */
const STORE_NAME: string = 'meal_reminder';
const STORE_KEY: string = 'config';

/** 本应用专属的日历账户名。用它来圈定"哪些日程是本应用写的" */
const CALENDAR_ACCOUNT_NAME: string = 'health_checkin_meal';
const CALENDAR_DISPLAY_NAME: string = '健康打卡';

/** 日程时长与重复次数 */
const EVENT_DURATION_MS: number = 15 * 60 * 1000;
const RECUR_COUNT: number = 365;
const MS_PER_DAY: number = 86400000;

/** 权限列表 */
const CALENDAR_PERMISSIONS: Permissions[] =
  ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR'];

/** 一个饭点的提醒设置 */
export class MealReminderSetting {
  mealType: number = MealType.BREAKFAST;
  label: string = '';
  enabled: boolean = false;
  hour: number = 8;
  minute: number = 0;
}

/** 默认时间：早餐 7:30 / 午餐 12:00 / 晚餐 18:00 */
const DEFAULTS: MealReminderSetting[] = buildDefaults();

function buildDefaults(): MealReminderSetting[] {
  const breakfast: MealReminderSetting = new MealReminderSetting();
  breakfast.mealType = MealType.BREAKFAST;
  breakfast.label = '早餐';
  breakfast.enabled = false;
  breakfast.hour = 7;
  breakfast.minute = 30;

  const lunch: MealReminderSetting = new MealReminderSetting();
  lunch.mealType = MealType.LUNCH;
  lunch.label = '午餐';
  lunch.enabled = false;
  lunch.hour = 12;
  lunch.minute = 0;

  const dinner: MealReminderSetting = new MealReminderSetting();
  dinner.mealType = MealType.DINNER;
  dinner.label = '晚餐';
  dinner.enabled = false;
  dinner.hour = 18;
  dinner.minute = 0;

  const list: MealReminderSetting[] = [];
  list.push(breakfast);
  list.push(lunch);
  list.push(dinner);
  return list;
}

/**
 * 饭点提醒服务 —— 走系统日历（Calendar Kit）而不是代理提醒。
 *
 * 之所以不用 reminderAgentManager：手机、平板、PC 上代理提醒存在管控，
 * 未申请权益的应用配额被直接置为 0，调用必定失败。官方指定的替代方案就是 Calendar Kit。
 * 走日历的好处是应用退到后台甚至被杀，提醒依然由系统日历准时投递。
 *
 * 设计上把"配置"和"日历日程"分开：
 *   - 配置存在 preferences 里，读它不需要任何权限，所以"我的"页面能正常渲染开关；
 *   - 日历日程只是投递手段，每次保存时整体清空本账户下的旧日程再重写，天然幂等。
 * 这样即使用户在系统日历里手动删掉了日程，重新保存一次就能恢复。
 */
export class MealReminderService {

  /** 读取本地配置（不碰日历，无需权限） */
  static async loadSettings(): Promise<MealReminderSetting[]> {
    const settings: MealReminderSetting[] = cloneSettings(DEFAULTS);
    try {
      const store: preferences.Preferences = await preferences.getPreferences(AppContext.get(), STORE_NAME);
      const raw = await store.get(STORE_KEY, '');
      const text: string = typeof raw === 'string' ? raw : '';
      applySerialized(settings, text);
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取提醒配置失败: %{public}s', JSON.stringify(err));
    }
    return settings;
  }

  /** 保存配置并把结果同步到系统日历 */
  static async saveSettings(settings: MealReminderSetting[]): Promise<string> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(AppContext.get(), STORE_NAME);
      await store.put(STORE_KEY, serialize(settings));
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存提醒配置失败: %{public}s', JSON.stringify(err));
      return '保存设置失败，请重试';
    }
    return await MealReminderService.syncToCalendar(settings);
  }

  /**
   * 把设置同步到系统日历。
   * @returns 空串表示成功；否则是给用户看的失败原因
   */
  static async syncToCalendar(settings: MealReminderSetting[]): Promise<string> {
    let enabledCount: number = 0;
    for (const setting of settings) {
      if (setting.enabled) {
        enabledCount++;
      }
    }

    // 全部关掉时不需要日历权限：能读到账户就清干净，读不到说明本来就没写过
    if (enabledCount === 0) {
      await MealReminderService.clearAllEvents();
      return '';
    }

    const granted: boolean = await MealReminderService.requestPermissions();
    if (!granted) {
      return '未获得日历权限，暂时无法写入系统提醒';
    }

    try {
      const calendar: calendarManager.Calendar = await MealReminderService.ensureCalendar();
      // 整体清空再重写：比"逐个比对增删"简单，而且天然幂等
      await MealReminderService.clearEvents(calendar);
      for (const setting of settings) {
        if (setting.enabled) {
          await calendar.addEvent(buildEvent(setting));
        }
      }
      return '';
    } catch (err) {
      hilog.error(DOMAIN, TAG, '写入系统日历失败: %{public}s', JSON.stringify(err));
      return '写入系统日历失败，请检查日历权限后重试';
    }
  }

  /** 申请日历读写权限；已授权时系统不会再弹窗 */
  private static async requestPermissions(): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(AppContext.get(), CALENDAR_PERMISSIONS);
      for (const code of result.authResults) {
        if (code !== 0) {
          return false;
        }
      }
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, '申请日历权限失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /** 取得本应用专属的日历账户；不存在则创建 */
  private static async ensureCalendar(): Promise<calendarManager.Calendar> {
    const manager: calendarManager.CalendarManager =
      calendarManager.getCalendarManager(AppContext.get());
    const account: calendarManager.CalendarAccount = {
      name: CALENDAR_ACCOUNT_NAME,
      type: calendarManager.CalendarType.LOCAL,
      displayName: CALENDAR_DISPLAY_NAME
    };
    try {
      return await manager.getCalendar(account);
    } catch (err) {
      // 账户还不存在时 getCalendar 会失败，此时创建
      return await manager.createCalendar(account);
    }
  }

  /** 清空本应用账户下的全部日程 */
  private static async clearEvents(calendar: calendarManager.Calendar): Promise<void> {
    const events: calendarManager.Event[] = await calendar.getEvents();
    for (const event of events) {
      const id: number | undefined = event.id;
      if (id !== undefined) {
        await calendar.deleteEvent(id);
      }
    }
  }

  /** 尽力而为地清空：没有权限或账户不存在都直接跳过，不向上抛 */
  private static async clearAllEvents(): Promise<void> {
    try {
      const calendar: calendarManager.Calendar = await MealReminderService.ensureCalendar();
      await MealReminderService.clearEvents(calendar);
    } catch (err) {
      hilog.info(DOMAIN, TAG, '无日历可清理: %{public}s', JSON.stringify(err));
    }
  }
}

/** 深拷贝一份默认值，避免调用方改到模块级的 DEFAULTS */
function cloneSettings(source: MealReminderSetting[]): MealReminderSetting[] {
  const result: MealReminderSetting[] = [];
  for (const item of source) {
    const copy: MealReminderSetting = new MealReminderSetting();
    copy.mealType = item.mealType;
    copy.label = item.label;
    copy.enabled = item.enabled;
    copy.hour = item.hour;
    copy.minute = item.minute;
    result.push(copy);
  }
  return result;
}

/** 序列化为 "开,时,分;开,时,分;..."，三个饭点固定顺序 */
function serialize(settings: MealReminderSetting[]): string {
  const parts: string[] = [];
  for (const setting of settings) {
    parts.push(`${setting.enabled ? 1 : 0},${setting.hour},${setting.minute}`);
  }
  return parts.join(';');
}

/** 解析并覆盖到 settings；格式不对时保持默认值 */
function applySerialized(settings: MealReminderSetting[], text: string): void {
  if (text.length === 0) {
    return;
  }
  const parts: string[] = text.split(';');
  for (let i = 0; i < settings.length && i < parts.length; i++) {
    const fields: string[] = parts[i].split(',');
    if (fields.length < 3) {
      continue;
    }
    const on: number = Number.parseInt(fields[0], 10);
    const hour: number = Number.parseInt(fields[1], 10);
    const minute: number = Number.parseInt(fields[2], 10);
    if (Number.isNaN(on) || Number.isNaN(hour) || Number.isNaN(minute)) {
      continue;
    }
    settings[i].enabled = on === 1;
    settings[i].hour = Math.max(0, Math.min(23, hour));
    settings[i].minute = Math.max(0, Math.min(59, minute));
  }
}

/** 构造一条每日重复的日程 */
function buildEvent(setting: MealReminderSetting): calendarManager.Event {
  const now: Date = new Date();
  let start: number = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
    setting.hour, setting.minute, 0).getTime();
  // 首次触发放到明天：写一个已经过去的时间点，当天的这一次就不会再响了
  if (start <= Date.now()) {
    start += MS_PER_DAY;
  }

  const event: calendarManager.Event = {
    title: `该记录${FormatUtils.mealTypeLabel(setting.mealType)}了`,
    type: calendarManager.EventType.NORMAL,
    startTime: start,
    endTime: start + EVENT_DURATION_MS,
    reminderTime: [0],
    recurrenceRule: {
      recurrenceFrequency: calendarManager.RecurrenceFrequency.DAILY,
      count: RECUR_COUNT
    }
  };
  return event;
}
