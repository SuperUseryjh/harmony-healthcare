import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CheckinService } from '../service/CheckinService';
import { DailyPlan } from '../service/PlanService';
import { PetCreatorService } from '../service/PetCreatorService';
import { PetService } from '../service/PetService';
import { DbHelper } from '../database/DbHelper';
import { DailySummaryDao } from '../database/DailySummaryDao';
import { MealRecordDao } from '../database/MealRecordDao';
import { PetEngine, PetState } from '../engine/PetEngine';
import { DailySummary } from '../model/DailySummary';
import { PetCatalog, PetSpecies } from '../model/PetSpecies';
import { AppContext } from '../utils/AppContext';
import { DateUtils } from '../utils/DateUtils';
import { CardData } from './CardData';

const DOMAIN: number = 0x0000;
const TAG: string = 'WidgetService';

/** 已加桌的卡片 id 存在这里，应用内打完卡要挨个推新数据 */
const STORE_NAME: string = 'widget_setting';
const KEY_FORM_IDS: string = 'form_ids';

/**
 * 卡片对图片体积有限制，超过这个大小就不传了。
 * 用户从相册导入的照片很容易超，宁可卡片上不显示宠物，也不要整张卡片渲染失败。
 */
const IMAGE_MAX_BYTES: number = 2 * 1024 * 1024;

/**
 * 桌面卡片的数据供应。
 *
 * 三条刷新路径共用这一个入口：加卡片时的初始化、扩展进程的定时刷新、
 * 应用内打卡后的主动刷新。共用一份取数逻辑，卡片上看到的一定和首页一致。
 *
 * 这里的取数刻意全部是只读查询：卡片每半小时醒一次，不该顺手去重算汇总、
 * 发徽章——那些副作用属于用户真正打开应用的时候。
 */
export class WidgetService {

  /**
   * 卡片扩展可能是冷启动的（应用没在运行），这时全局 Context、数据库、
   * 宠物目录都还没就位，得先补上。应用在运行时这些都已经是就绪状态，
   * 下面的判断都是幂等的。
   *
   * @returns 数据库是否可用；不可用时卡片只能显示兜底文案
   */
  private static async ensureReady(context: common.Context): Promise<boolean> {
    if (!AppContext.isReady()) {
      AppContext.set(context);
    }
    await DbHelper.init(context);
    const dbReady: boolean = await DbHelper.waitReady();
    if (!dbReady) {
      return false;
    }
    await PetCatalog.init(context);
    // 自建宠物存在 preferences 里，要读出来并进目录，否则用户自己做的伙伴在卡片上会变成默认那只
    const list: PetSpecies[] = await PetCreatorService.loadAll();
    PetCatalog.setUserPets(list);
    return true;
  }

  /** 组装当前应该在卡片上显示的内容 */
  static async load(context: common.Context): Promise<CardData> {
    try {
      const ready: boolean = await WidgetService.ensureReady(context);
      if (!ready) {
        return WidgetService.fallback('本地数据还没准备好，打开应用看一眼吧');
      }

      const dateKey: string = DateUtils.todayKey();
      const plan: DailyPlan | undefined = await CheckinService.currentPlan();
      const summary: DailySummary = await WidgetService.summaryOf(dateKey);
      const mealTypes: number[] = await MealRecordDao.mealTypesOfDate(dateKey);

      const speciesCode: string = await PetService.loadSpeciesCode();
      const species: PetSpecies | undefined = PetCatalog.find(speciesCode);
      if (species === undefined) {
        return WidgetService.fallback('宠物配置没装载成功，打开应用试试');
      }

      // 宠物的"年龄"用累计有记录的天数，和首页保持同一套口径
      const growDays: number = await DailySummaryDao.countDays();
      const waterDone: boolean = plan !== undefined && summary.waterMl >= plan.waterMl;
      const pet: PetState = PetEngine.evaluate(PetEngine.countMainMeals(mealTypes),
        summary.activityMin, waterDone, summary.streakDays, growDays, species);

      const data: CardData = new CardData();
      data.petName = species.label;
      data.stageName = pet.stageName;
      data.message = pet.message;
      data.growDays = pet.growDays;
      data.daysToNextStage = pet.daysToNextStage;
      data.isMaxStage = pet.isMaxStage;
      data.fullness = Math.round(pet.fullness);
      data.vitality = Math.round(pet.vitality);
      data.mood = Math.round(pet.mood);
      data.intakeKcal = Math.round(summary.intakeKcal);
      data.targetKcal = plan === undefined ? 0 : Math.round(plan.targetKcal);
      data.mealCount = mealTypes.length;
      data.streakDays = summary.streakDays;
      data.updatedAt = WidgetService.clockLabel();
      // 体型缩放不做：每个阶段的 SVG 里已经画好了对应的大小，
      // 卡片再按 scale 缩一次框，等于缩两遍，宠物会越养越小
      await WidgetService.attachImage(data, pet.imagePath, context);
      return data;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '卡片数据装载失败 code=%{public}d message=%{public}s', e.code, e.message);
      return WidgetService.fallback('数据读取失败，打开应用看一眼吧');
    }
  }

  /** 今天还没有任何记录时给一份全零的，卡片显示"还没开始"而不是空着 */
  private static async summaryOf(dateKey: string): Promise<DailySummary> {
    const existing: DailySummary | undefined = await DailySummaryDao.get(dateKey);
    if (existing !== undefined) {
      return existing;
    }
    const empty: DailySummary = new DailySummary();
    empty.recordDate = dateKey;
    return empty;
  }

  private static fallback(message: string): CardData {
    const data: CardData = new CardData();
    data.message = message;
    return data;
  }

  /** 取扩展名，只用来给内存图片起一个带格式的名字 */
  private static extOf(path: string): string {
    const dot: number = path.lastIndexOf('.');
    if (dot < 0 || dot === path.length - 1) {
      return 'img';
    }
    const ext: string = path.substring(dot + 1).toLowerCase();
    return ext.length > 4 ? 'img' : ext;
  }

  private static clockLabel(): string {
    const now: Date = new Date(Date.now());
    const minute: number = now.getMinutes();
    return `${now.getHours()}:${minute < 10 ? '0' : ''}${minute} 更新`;
  }

  /**
   * 准备卡片要显示的宠物图。
   *
   * 卡片进程读不到应用的沙箱，也读不到包内资源，所以图片只能走官方给的
   * "内存图片"通道：扩展进程把图片准备好、开一个 fd 随绑定数据传过去，
   * 卡片侧用 memory://<图片名> 显示。
   *
   * 内置宠物在 rawfile 里，先落一份到临时目录再开 fd——不去试卡片能不能直接读
   * rawfile，两条来源走同一条路，少一个变量。
   * fd 由扩展进程持有，进程销毁时释放：这是官方示例的做法，不要去 close，
   * 否则卡片还没来得及画图就失效了。
   */
  private static async attachImage(data: CardData, imagePath: string,
    context: common.Context): Promise<void> {
    if (imagePath.length === 0) {
      return;
    }
    const stamp: number = Date.now();
    try {
      if (imagePath.startsWith('file://')) {
        const path: string = PetCreatorService.absolutePathOf(imagePath);
        if (path.length > 0) {
          WidgetService.shareImage(data, path, stamp);
        }
        return;
      }
      // 内置宠物：rawfile 里是一张 SVG，读出来落到临时目录
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(imagePath);
      const tempPath: string = `${context.tempDir}/petcard_${stamp}.svg`;
      const file = fs.openSync(tempPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, bytes.buffer);
      } finally {
        fs.closeSync(file);
      }
      WidgetService.shareImage(data, tempPath, stamp);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '卡片图片准备失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 按路径开 fd 并挂到绑定数据上；体积不合适的图直接放弃，宁可卡片上没有宠物 */
  private static shareImage(data: CardData, path: string, stamp: number): void {
    const size: number = fs.statSync(path).size;
    if (size <= 0 || size > IMAGE_MAX_BYTES) {
      hilog.warn(DOMAIN, TAG, '宠物图片体积不合适，卡片上不显示 size=%{public}d', size);
      return;
    }
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    // 名字每次刷新都换：卡片按这个名字缓存解码结果，沿用旧名字会一直显示上一张图
    const name: string = `petcard_${stamp}.${WidgetService.extOf(path)}`;
    data.petImage = name;
    data.formImages[name] = file.fd;
  }

  /** 把一份数据推给某张卡片 */
  static async push(formId: string, data: CardData): Promise<void> {
    try {
      const binding: formBindingData.FormBindingData = formBindingData.createFormBindingData(data);
      await formProvider.updateForm(formId, binding);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '刷新卡片失败 formId=%{public}s code=%{public}d message=%{public}s',
        formId, e.code, e.message);
    }
  }

  /** 取最新数据后推给某张卡片 */
  static async refreshForm(context: common.Context, formId: string): Promise<void> {
    const data: CardData = await WidgetService.load(context);
    await WidgetService.push(formId, data);
  }

  /**
   * 把所有已加桌的卡片刷一遍。
   *
   * 应用内打完卡、换了伙伴之后调用。没有卡片时直接返回，
   * 不为了一个空列表去读数据库。
   */
  static async refreshAll(): Promise<void> {
    try {
      const ids: string[] = await WidgetService.formIds();
      if (ids.length === 0) {
        return;
      }
      // 所有卡片内容相同，取一次数就够了
      const data: CardData = await WidgetService.load(AppContext.get());
      for (const id of ids) {
        await WidgetService.push(id, data);
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '批量刷新卡片失败 code=%{public}d message=%{public}s', e.code, e.message);
    }
  }

  // ==================== 已加桌卡片登记 ====================

  /**
   * 加卡时记下 id。
   *
   * 系统没有"列出本应用所有卡片"的接口，要主动刷新就只能自己记——
   * 官方也是这么建议的：onAddForm 里存，onRemoveForm 里删。
   */
  static async rememberForm(formId: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }
    const ids: string[] = await WidgetService.formIds();
    if (ids.includes(formId)) {
      return;
    }
    ids.push(formId);
    await WidgetService.writeFormIds(ids);
  }

  static async forgetForm(formId: string): Promise<void> {
    const ids: string[] = await WidgetService.formIds();
    const kept: string[] = ids.filter((id: string) => id !== formId);
    if (kept.length !== ids.length) {
      await WidgetService.writeFormIds(kept);
    }
  }

  private static async store(): Promise<preferences.Preferences> {
    return await preferences.getPreferences(AppContext.get(), STORE_NAME);
  }

  private static async formIds(): Promise<string[]> {
    try {
      const store: preferences.Preferences = await WidgetService.store();
      const raw = await store.get(KEY_FORM_IDS, '');
      const text: string = typeof raw === 'string' ? raw : '';
      if (text.length === 0) {
        return [];
      }
      const ids: string[] = JSON.parse(text) as string[];
      return Array.isArray(ids) ? ids : [];
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '读取卡片登记表失败: %{public}s', JSON.stringify(err));
      return [];
    }
  }

  private static async writeFormIds(ids: string[]): Promise<void> {
    try {
      const store: preferences.Preferences = await WidgetService.store();
      await store.put(KEY_FORM_IDS, JSON.stringify(ids));
      await store.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '保存卡片登记表失败: %{public}s', JSON.stringify(err));
    }
  }
}
