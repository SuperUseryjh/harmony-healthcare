import { AdviceContext, AdviceEngine, AdviceItem } from '../engine/AdviceEngine';
import { PetEngine, PetState } from '../engine/PetEngine';
import { DailySummary } from '../model/DailySummary';
import { PetSpecies, PetSpeciesCatalog } from '../model/PetSpecies';
import { MealRecordDao } from '../database/MealRecordDao';
import { DailySummaryDao } from '../database/DailySummaryDao';
import { CheckinRefreshResult, CheckinService } from '../service/CheckinService';
import { DailyPlan } from '../service/PlanService';
import { PetService } from '../service/PetService';
import { DateUtils } from '../utils/DateUtils';
import { FormatUtils } from '../utils/FormatUtils';
import { MealSchedule, MealWindow } from '../utils/MealSchedule';
import { PetDebug } from '../utils/PetDebug';

/** 首页渲染所需的全部数据。整对象替换即可触发刷新，避免深层状态同步问题 */
export class HomeData {
  loaded: boolean = false;
  hasProfile: boolean = false;
  dateKey: string = '';
  intakeKcal: number = 0;
  targetKcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  targetProteinG: number = 0;
  targetFatG: number = 0;
  targetCarbG: number = 0;
  burnedKcal: number = 0;
  activityMin: number = 0;
  waterMl: number = 0;
  targetWaterMl: number = 0;
  /** 今日已记录的餐次数量 */
  mealCount: number = 0;
  score: number = 0;
  streakDays: number = 0;
  routineDone: boolean = false;
  waterDone: boolean = false;
  advices: AdviceItem[] = [];
  /** 本次操作新解锁的徽章名称 */
  newBadgeNames: string[] = [];

  /** 正处在某个饭点窗口内、且该餐还没记录时为 true */
  showMealPrompt: boolean = false;
  /** 提示对应的餐次，点击时用它预选录入页的餐次 */
  mealPromptMealType: number = -1;
  mealPromptTitle: string = '';
  mealPromptDesc: string = '';
  /** 非饭点时的下一餐提示，如"距晚餐还有 2 小时 15 分"；空串表示不显示 */
  nextMealHint: string = '';

  /** 今日已记录的主餐数（早/午/晚），加餐不计入 */
  mainMealCount: number = 0;
  /** 当前宠物物种 */
  speciesCode: string = PetSpeciesCatalog.defaultCode();
  speciesLabel: string =
    PetSpeciesCatalog.find(PetSpeciesCatalog.defaultCode()).label;
  /** 宠物状态 */
  pet: PetState = new PetState();
}

/**
 * 首页视图模型。
 *
 * 每次操作（打开页面、打卡）都会重新走一遍 "重算汇总 → 组装展示数据" 的流程，
 * 页面只负责把返回的 HomeData 整体替换掉。这样界面上看到的一定是数据库里的真实状态，
 * 不需要在页面里维护一份可能失同步的副本。
 */
export class HomeViewModel {

  /** 打开首页 */
  static async load(): Promise<HomeData> {
    const dateKey: string = DateUtils.todayKey();
    const plan: DailyPlan | undefined = await CheckinService.currentPlan();
    if (plan === undefined) {
      const empty: HomeData = new HomeData();
      empty.loaded = true;
      empty.hasProfile = false;
      empty.dateKey = dateKey;
      return empty;
    }
    const result: CheckinRefreshResult = await CheckinService.refresh(dateKey);
    return await HomeViewModel.build(result, plan);
  }

  /** 饮水打卡 */
  static async addWater(): Promise<HomeData> {
    const dateKey: string = DateUtils.todayKey();
    const result: CheckinRefreshResult =
      await CheckinService.addWater(dateKey, CheckinService.WATER_STEP_ML);
    return await HomeViewModel.buildWithLatestPlan(result);
  }

  /** 撤销最近一次饮水 */
  static async undoWater(): Promise<HomeData> {
    const dateKey: string = DateUtils.todayKey();
    const result: CheckinRefreshResult = await CheckinService.undoLastWater(dateKey);
    return await HomeViewModel.buildWithLatestPlan(result);
  }

  /** 作息打卡开关 */
  static async toggleRoutine(): Promise<HomeData> {
    const dateKey: string = DateUtils.todayKey();
    const result: CheckinRefreshResult = await CheckinService.toggleRoutine(dateKey);
    return await HomeViewModel.buildWithLatestPlan(result);
  }

  private static async buildWithLatestPlan(result: CheckinRefreshResult): Promise<HomeData> {
    const plan: DailyPlan | undefined = await CheckinService.currentPlan();
    return await HomeViewModel.build(result, plan);
  }

  private static async build(result: CheckinRefreshResult, plan: DailyPlan | undefined): Promise<HomeData> {
    const summary: DailySummary = result.summary;
    const data: HomeData = new HomeData();
    data.loaded = true;
    data.hasProfile = plan !== undefined;
    data.dateKey = summary.recordDate;
    data.intakeKcal = summary.intakeKcal;
    data.proteinG = summary.proteinG;
    data.fatG = summary.fatG;
    data.carbG = summary.carbG;
    data.burnedKcal = summary.burnedKcal;
    data.activityMin = summary.activityMin;
    data.waterMl = summary.waterMl;
    data.score = summary.score;
    data.streakDays = summary.streakDays;
    data.routineDone = CheckinService.hasRoutineCheckedIn(summary);
    data.newBadgeNames = result.newBadgeNames;

    if (plan !== undefined) {
      data.targetKcal = plan.targetKcal;
      data.targetProteinG = plan.proteinG;
      data.targetFatG = plan.fatG;
      data.targetCarbG = plan.carbG;
      data.targetWaterMl = plan.waterMl;
      data.waterDone = summary.waterMl >= plan.waterMl;
    }

    const mealTypes: number[] = await MealRecordDao.mealTypesOfDate(summary.recordDate);
    data.mealCount = mealTypes.length;
    data.mainMealCount = PetEngine.countMainMeals(mealTypes);
    HomeViewModel.fillMealPrompt(data, mealTypes);

    const species: PetSpecies =
      PetSpeciesCatalog.find(await PetService.loadSpeciesCode());
    data.speciesCode = species.code;
    data.speciesLabel = species.label;

    // 宠物的"年龄"用累计有记录的天数，而不是注册天数——
    // 后者躺着也能涨，前者必须真的记录过才算
    const growDays: number = await DailySummaryDao.countDays();
    data.pet = PetEngine.evaluate(data.mainMealCount, data.activityMin, data.waterDone,
      data.streakDays, growDays, species);

    // 调试预设优先：长按宠物卡片切换，只覆盖显示、不改真实数据
    const debugPet: PetState | undefined = PetDebug.resolve(species);
    if (debugPet !== undefined) {
      data.pet = debugPet;
    }

    data.advices = HomeViewModel.buildAdvices(summary, plan);
    return data;
  }

  /**
   * 饭点提示。
   *
   * 只在"正处在饭点窗口内 + 该餐还没记录"时才弹提示，窗口一过就自动消失——
   * 不弹过往的餐次，否则下午三点提醒你记早餐只会变成噪音。
   * 不在窗口内时退化成"距离下一餐还有多久"，让用户知道下一次该在什么时候记录。
   */
  private static fillMealPrompt(data: HomeData, recordedMealTypes: number[]): void {
    const hour: number = DateUtils.currentHour();
    const minute: number = DateUtils.currentMinute();

    const current: MealWindow | undefined = MealSchedule.currentWindow(hour, minute);
    if (current !== undefined && recordedMealTypes.indexOf(current.mealType) < 0) {
      data.showMealPrompt = true;
      data.mealPromptMealType = current.mealType;
      data.mealPromptTitle = `${current.label}时间到了`;
      data.mealPromptDesc = `今天还没记录${current.label}`;
      return;
    }

    const next: MealWindow | undefined = MealSchedule.nextWindow(hour, minute);
    if (next === undefined) {
      data.nextMealHint = '今天的饭点都过去了，加餐也记得记一下';
      return;
    }
    const remain: number = MealSchedule.minutesUntil(next, hour, minute);
    data.nextMealHint = `距${next.label}还有 ${FormatUtils.formatMinutes(remain)}`;
  }

  /** 组装建议引擎的输入 */
  private static buildAdvices(summary: DailySummary, plan: DailyPlan | undefined): AdviceItem[] {
    const ctx: AdviceContext = new AdviceContext();
    ctx.intakeKcal = summary.intakeKcal;
    ctx.burnedKcal = summary.burnedKcal;
    ctx.proteinG = summary.proteinG;
    ctx.fatG = summary.fatG;
    ctx.carbG = summary.carbG;
    ctx.waterMl = summary.waterMl;
    ctx.activityMin = summary.activityMin;
    ctx.currentHour = DateUtils.currentHour();
    ctx.streakDays = summary.streakDays;

    if (plan !== undefined) {
      ctx.targetKcal = plan.targetKcal;
      ctx.targetProteinG = plan.proteinG;
      ctx.targetFatG = plan.fatG;
      ctx.targetCarbG = plan.carbG;
      ctx.targetWaterMl = plan.waterMl;
    }

    return AdviceEngine.generate(ctx);
  }
}
