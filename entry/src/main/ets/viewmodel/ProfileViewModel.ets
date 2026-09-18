import { Badge, BadgeCatalog } from '../model/Badge';
import { UserProfile } from '../model/UserProfile';
import { BadgeDao } from '../database/BadgeDao';
import { DailySummaryDao } from '../database/DailySummaryDao';
import { MealRecordDao } from '../database/MealRecordDao';
import { ActivityRecordDao } from '../database/ActivityRecordDao';
import { UserProfileDao } from '../database/UserProfileDao';
import { MealReminderService, MealReminderSetting } from '../service/MealReminderService';
import { OnboardingDraft, OnboardingPreview, OnboardingViewModel } from './OnboardingViewModel';

/** 徽章墙上的一个格子 */
export class BadgeView {
  code: string = '';
  name: string = '';
  desc: string = '';
  unlocked: boolean = false;
}

export class ProfileStats {
  totalDays: number = 0;
  maxStreakDays: number = 0;
  mealCount: number = 0;
  activityCount: number = 0;
  badgeCount: number = 0;
  badgeTotal: number = 0;
}

export class ProfileData {
  loaded: boolean = false;
  hasProfile: boolean = false;
  /** 当前档案对应的表单草稿，供"重新测算"跳转时预填 */
  draft: OnboardingDraft = new OnboardingDraft();
  preview: OnboardingPreview = new OnboardingPreview();
  stats: ProfileStats = new ProfileStats();
  badges: BadgeView[] = [];
  /** 三个饭点的提醒设置 */
  reminders: MealReminderSetting[] = [];
}

/**
 * "我的"页面视图模型。
 *
 * 目标值不重新实现一遍换算，而是复用 OnboardingViewModel.preview ——
 * 引导页、运动页、这里用的必须是同一套公式，否则同一份档案会算出不同的目标。
 */
export class ProfileViewModel {

  static async load(): Promise<ProfileData> {
    const data: ProfileData = new ProfileData();

    const profile: UserProfile | undefined = await UserProfileDao.get();
    if (profile !== undefined) {
      data.hasProfile = true;
      const nowYear: number = new Date(Date.now()).getFullYear();
      data.draft.gender = profile.gender;
      data.draft.age = profile.age(nowYear);
      data.draft.heightCm = profile.heightCm;
      data.draft.weightKg = profile.weightKg;
      data.draft.activityLevel = profile.activityLevel;
      data.draft.goal = profile.goal;
      data.preview = OnboardingViewModel.preview(data.draft);
    }

    const stats: ProfileStats = new ProfileStats();
    stats.totalDays = await DailySummaryDao.countDays();
    stats.maxStreakDays = await DailySummaryDao.maxStreakDays();
    stats.mealCount = await MealRecordDao.countAll();
    stats.activityCount = await ActivityRecordDao.countAll();

    const unlockedList: Badge[] = await BadgeDao.getAll();
    const unlockedCodes: Set<string> = new Set<string>();
    for (const badge of unlockedList) {
      unlockedCodes.add(badge.badgeCode);
    }

    const views: BadgeView[] = [];
    for (const def of BadgeCatalog.ALL) {
      const view: BadgeView = new BadgeView();
      view.code = def.code;
      view.name = def.name;
      view.desc = def.desc;
      view.unlocked = unlockedCodes.has(def.code);
      views.push(view);
    }
    data.badges = views;
    stats.badgeCount = unlockedCodes.size;
    stats.badgeTotal = BadgeCatalog.ALL.length;
    data.stats = stats;

    // 提醒配置存在 preferences 里，读取不需要权限，所以打开"我的"不会弹任何窗
    data.reminders = await MealReminderService.loadSettings();

    data.loaded = true;
    return data;
  }

  /**
   * 切换某个饭点提醒的开关。
   * @param settings 传入 ProfileData.reminders，就地修改后同步到系统日历
   * @returns 空串表示成功，否则是给用户看的失败原因
   */
  static async setReminderEnabled(settings: MealReminderSetting[], index: number,
    enabled: boolean): Promise<string> {
    if (index < 0 || index >= settings.length) {
      return '';
    }
    settings[index].enabled = enabled;
    return await MealReminderService.saveSettings(settings);
  }

  /** 修改某个饭点提醒的时间 */
  static async setReminderTime(settings: MealReminderSetting[], index: number,
    hour: number, minute: number): Promise<string> {
    if (index < 0 || index >= settings.length) {
      return '';
    }
    settings[index].hour = hour;
    settings[index].minute = minute;
    return await MealReminderService.saveSettings(settings);
  }

  /** 表单草稿的实时预览，转发给 OnboardingViewModel 以保证公式唯一 */
  static preview(draft: OnboardingDraft): OnboardingPreview {
    return OnboardingViewModel.preview(draft);
  }
}
