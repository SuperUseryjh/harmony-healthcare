import { ALL_CHECKINS, BitFlags, CheckinBit, MealType } from '../model/Enums';
import { DailySummary } from '../model/DailySummary';
import { WaterRecord } from '../model/WaterRecord';
import { ActivityRecord } from '../model/ActivityRecord';
import { UserProfile } from '../model/UserProfile';
import { NutritionTotals } from '../model/Totals';
import { WaterRecordDao } from '../database/WaterRecordDao';
import { MealRecordDao } from '../database/MealRecordDao';
import { ActivityRecordDao } from '../database/ActivityRecordDao';
import { DailySummaryDao } from '../database/DailySummaryDao';
import { UserProfileDao } from '../database/UserProfileDao';
import { HealthScoreCalculator, ScoreBreakdown, ScoreInput } from '../engine/HealthScoreCalculator';
import { DailyPlan, PlanService } from './PlanService';
import { StreakService } from './StreakService';
import { BadgeService } from './BadgeService';

/**
 * 只能由用户手动置位的打卡项。
 *
 * 三餐、运动、饮水都能从明细表推导出来，但"作息"没有对应的数据源，
 * 只能由用户主动打卡。因此重算汇总时必须把这一位保留下来，否则每次刷新都会被清零。
 */
const MANUAL_CHECKIN_BITS: number = CheckinBit.ROUTINE;

/** 一次打卡刷新的结果 */
export class CheckinRefreshResult {
  summary: DailySummary = new DailySummary();
  /** 本次新解锁的徽章名称 */
  newBadgeNames: string[] = [];
}

/**
 * 打卡服务：所有写操作的统一入口。
 *
 * 核心是 refresh() —— 明细表是数据的真实来源，daily_summary 是它们的聚合结果。
 * 任何一次写入之后都重算汇总，而不是直接给汇总表做加减，
 * 这样即使某次写入异常，下一次刷新也能自动纠正到正确状态。
 */
export class CheckinService {
  /** 一次饮水打卡的默认量 */
  static readonly WATER_STEP_ML: number = 250;

  /** 取当前计划；未完成引导时返回 undefined */
  static async currentPlan(): Promise<DailyPlan | undefined> {
    const profile: UserProfile | undefined = await UserProfileDao.get();
    if (profile === undefined) {
      return undefined;
    }
    const nowYear: number = new Date(Date.now()).getFullYear();
    return PlanService.build(profile, nowYear);
  }

  /** 重算某日汇总并落库 */
  static async refresh(dateKey: string): Promise<CheckinRefreshResult> {
    return await CheckinService.refreshInternal(dateKey, undefined);
  }

  /** 饮水打卡：追加一条记录后重算汇总 */
  static async addWater(dateKey: string, ml: number): Promise<CheckinRefreshResult> {
    if (ml > 0) {
      const record: WaterRecord = new WaterRecord();
      record.recordDate = dateKey;
      record.amountMl = ml;
      record.createdAt = Date.now();
      await WaterRecordDao.insert(record);
    }
    return await CheckinService.refresh(dateKey);
  }

  /** 撤销最近一次饮水打卡 */
  static async undoLastWater(dateKey: string): Promise<CheckinRefreshResult> {
    await WaterRecordDao.deleteLatestOfDate(dateKey);
    return await CheckinService.refresh(dateKey);
  }

  /**
   * 运动打卡。
   * @param kcalBurned 由调用方用 EnergyCalculator.calcExerciseKcal 算好传进来，
   *                   服务层不重复实现一遍 MET 公式
   */
  static async addActivity(dateKey: string, activityType: number, durationMin: number,
    intensity: number, kcalBurned: number): Promise<CheckinRefreshResult> {
    if (durationMin > 0) {
      const record: ActivityRecord = new ActivityRecord();
      record.recordDate = dateKey;
      record.activityType = activityType;
      record.durationMin = Math.round(durationMin);
      record.intensity = intensity;
      record.kcalBurned = kcalBurned;
      record.createdAt = Date.now();
      await ActivityRecordDao.insert(record);
    }
    return await CheckinService.refresh(dateKey);
  }

  /**
   * 作息打卡的开关。
   *
   * 这里不先把手动位单独写库再刷新，而是把翻转后的值直接交给重算流程，
   * 只落一次库——否则中途失败会留下一条除打卡位以外全是 0 的汇总。
   */
  static async toggleRoutine(dateKey: string): Promise<CheckinRefreshResult> {
    const existing: DailySummary | undefined = await DailySummaryDao.get(dateKey);
    const currentFlags: number = existing === undefined ? 0 : existing.checkinFlags;
    const flipped: number = BitFlags.has(currentFlags, CheckinBit.ROUTINE)
      ? BitFlags.remove(currentFlags, CheckinBit.ROUTINE)
      : BitFlags.add(currentFlags, CheckinBit.ROUTINE);
    return await CheckinService.refreshInternal(dateKey, flipped);
  }

  /** 今日是否已打过作息卡，用于按钮文案 */
  static hasRoutineCheckedIn(summary: DailySummary): boolean {
    return BitFlags.has(summary.checkinFlags, CheckinBit.ROUTINE);
  }

  /**
   * 汇总重算。
   * @param manualFlagsOverride 传入时用它作为"已有的手动打卡位"，否则从库里读
   */
  private static async refreshInternal(dateKey: string,
    manualFlagsOverride: number | undefined): Promise<CheckinRefreshResult> {
    const plan: DailyPlan | undefined = await CheckinService.currentPlan();
    const existing: DailySummary | undefined = await DailySummaryDao.get(dateKey);
    const summary: DailySummary = existing === undefined ? new DailySummary() : existing;

    let manualFlags: number;
    if (manualFlagsOverride !== undefined) {
      manualFlags = manualFlagsOverride & MANUAL_CHECKIN_BITS;
    } else {
      manualFlags = (existing === undefined ? 0 : existing.checkinFlags) & MANUAL_CHECKIN_BITS;
    }

    const totals: NutritionTotals = await MealRecordDao.sumByDate(dateKey);
    const burned: number = await ActivityRecordDao.sumBurnedByDate(dateKey);
    const activityMin: number = await ActivityRecordDao.sumMinutesByDate(dateKey);
    const waterMl: number = await WaterRecordDao.sumByDate(dateKey);
    const mealTypes: number[] = await MealRecordDao.mealTypesOfDate(dateKey);

    summary.recordDate = dateKey;
    summary.intakeKcal = totals.kcal;
    summary.proteinG = totals.proteinG;
    summary.fatG = totals.fatG;
    summary.carbG = totals.carbG;
    summary.burnedKcal = burned;
    summary.activityMin = activityMin;
    summary.waterMl = waterMl;

    // 由明细推导的打卡状态
    let autoFlags: number = 0;
    if (mealTypes.indexOf(MealType.BREAKFAST) >= 0) {
      autoFlags = autoFlags | CheckinBit.BREAKFAST;
    }
    if (mealTypes.indexOf(MealType.LUNCH) >= 0) {
      autoFlags = autoFlags | CheckinBit.LUNCH;
    }
    if (mealTypes.indexOf(MealType.DINNER) >= 0) {
      autoFlags = autoFlags | CheckinBit.DINNER;
    }
    if (activityMin > 0) {
      autoFlags = autoFlags | CheckinBit.ACTIVITY;
    }
    if (plan !== undefined && waterMl >= plan.waterMl) {
      autoFlags = autoFlags | CheckinBit.WATER;
    }
    summary.checkinFlags = autoFlags | manualFlags;

    const completed: number = BitFlags.count(summary.checkinFlags, ALL_CHECKINS);
    summary.score = CheckinService.calcScore(summary, plan, completed);
    summary.streakDays = await StreakService.update(dateKey, completed);

    await DailySummaryDao.save(summary);

    const newBadgeNames: string[] = await BadgeService.evaluate(summary, plan);
    const result: CheckinRefreshResult = new CheckinRefreshResult();
    result.summary = summary;
    result.newBadgeNames = newBadgeNames;
    return result;
  }

  private static calcScore(summary: DailySummary, plan: DailyPlan | undefined,
    completed: number): number {
    if (plan === undefined) {
      return 0;
    }
    const input: ScoreInput = {
      intakeKcal: summary.intakeKcal,
      targetKcal: plan.targetKcal,
      proteinG: summary.proteinG,
      fatG: summary.fatG,
      carbG: summary.carbG,
      targetProteinG: plan.proteinG,
      targetFatG: plan.fatG,
      targetCarbG: plan.carbG,
      completedCheckins: completed,
      totalCheckins: BitFlags.count(ALL_CHECKINS, ALL_CHECKINS)
    };
    const breakdown: ScoreBreakdown = HealthScoreCalculator.calc(input);
    return breakdown.total;
  }
}
