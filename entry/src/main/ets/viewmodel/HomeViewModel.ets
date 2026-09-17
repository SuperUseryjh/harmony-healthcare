import { AdviceContext, AdviceEngine, AdviceItem } from '../engine/AdviceEngine';
import { DailySummary } from '../model/DailySummary';
import { MealRecordDao } from '../database/MealRecordDao';
import { CheckinRefreshResult, CheckinService } from '../service/CheckinService';
import { DailyPlan } from '../service/PlanService';
import { DateUtils } from '../utils/DateUtils';

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

    data.advices = HomeViewModel.buildAdvices(summary, plan);
    return data;
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
