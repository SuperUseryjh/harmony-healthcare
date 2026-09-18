import { MacroRatio } from '../engine/EnergyCalculator';
import { MacroDistribution, NutritionAnalyzer } from '../engine/NutritionAnalyzer';
import { DailySummary } from '../model/DailySummary';
import { ALL_CHECKINS, BitFlags } from '../model/Enums';
import { DailySummaryDao } from '../database/DailySummaryDao';
import { CheckinService } from '../service/CheckinService';
import { DailyPlan } from '../service/PlanService';
import { DateUtils } from '../utils/DateUtils';
import { FormatUtils } from '../utils/FormatUtils';

/** 柱子的达标状态。颜色由页面层映射，视图模型不依赖主题 */
export enum BarStatus {
  EMPTY = 0,
  OK = 1,
  OVER = 2,
  UNDER = 3
}

/** 趋势图上的一根柱子：单日视图下是一天，多日视图下是一组（多天）的日均 */
export class ChartBar {
  /** 横轴标签，取该组起始日期 */
  label: string = '';
  /** 组内日均摄入（按有记录的天数平均） */
  avgIntake: number = 0;
  /** 相对本周期最大值的比例，0-1，用于决定柱高 */
  heightRatio: number = 0;
  /** 相对目标摄入的比例 */
  targetRatio: number = 0;
  status: number = BarStatus.EMPTY;
  /** 组内有记录的天数 */
  recordedDays: number = 0;
  /** 组内总天数 */
  dayCount: number = 0;
}

export class AnalysisData {
  loaded: boolean = false;
  days: number = 7;
  /** 每根柱子代表几天。1 表示单日一根柱子 */
  bucketDays: number = 1;
  targetKcal: number = 0;
  bars: ChartBar[] = [];

  recordedDays: number = 0;
  /** 摄入落在目标 ±15% 区间内的天数（仍按天统计，不因分组而稀释） */
  goalMetDays: number = 0;

  /** 以下均值都只按"有记录的天数"计算，否则没打开应用的日子会把均值拉低 */
  avgIntake: number = 0;
  avgBurned: number = 0;
  avgScore: number = 0;
  avgCheckinCount: number = 0;

  actualRatio: MacroRatio = { protein: 0, fat: 0, carb: 0 };
  targetRatio: MacroRatio = { protein: 0, fat: 0, carb: 0 };
  similarity: number = 0;
  hasMacroData: boolean = false;
}

const OVER_TOLERANCE: number = 1.15;
const UNDER_THRESHOLD: number = 0.85;
/** 多日视图下固定的柱子数量 */
const AGGREGATED_BAR_COUNT: number = 5;

/**
 * 趋势分析的视图模型。
 *
 * 数据源只用 daily_summary 一张表——它已经把每日的摄入、消耗、打卡、得分都聚合好了，
 * 比在页面上分别去查四五张明细表再算一遍要简单得多。
 * 代价是"没有记录的日子没有行"，所以要按日期生成完整序列再补齐空位。
 *
 * 天数一多，一天一根柱子会挤成一片看不清，所以超过一周就按组聚合：
 * 30 天分成 5 组、每组 6 天，柱高是组内**有记录天数**的日均摄入。
 * 这里刻意不用"除以组内总天数"——那样偶尔记录两天的用户会看到一根很矮的柱子，
 * 反映的是记录频率而不是摄入水平。
 */
export class AnalysisViewModel {

  static async load(days: number): Promise<AnalysisData> {
    const endKey: string = DateUtils.todayKey();
    const startKey: string = DateUtils.addDays(endKey, -(days - 1));

    const plan: DailyPlan | undefined = await CheckinService.currentPlan();
    const summaries: DailySummary[] = await DailySummaryDao.queryRange(startKey, endKey);

    const byDate: Map<string, DailySummary> = new Map<string, DailySummary>();
    for (const summary of summaries) {
      byDate.set(summary.recordDate, summary);
    }

    const bucketDays: number = days <= 7 ? 1 : Math.ceil(days / AGGREGATED_BAR_COUNT);

    const data: AnalysisData = new AnalysisData();
    data.days = days;
    data.bucketDays = bucketDays;
    data.targetKcal = plan === undefined ? 0 : plan.targetKcal;

    let sumIntake: number = 0;
    let sumBurned: number = 0;
    let sumScore: number = 0;
    let sumCheckin: number = 0;
    let sumProtein: number = 0;
    let sumFat: number = 0;
    let sumCarb: number = 0;
    let recordedDays: number = 0;
    let goalMetDays: number = 0;
    let maxAvg: number = 1;

    const bucketCount: number = Math.ceil(days / bucketDays);
    for (let b = 0; b < bucketCount; b++) {
      let bucketIntake: number = 0;
      let bucketRecorded: number = 0;
      let bucketDayCount: number = 0;

      for (let i = 0; i < bucketDays; i++) {
        const offset: number = b * bucketDays + i;
        if (offset >= days) {
          break;
        }
        bucketDayCount++;
        const key: string = DateUtils.addDays(startKey, offset);
        const summary: DailySummary | undefined = byDate.get(key);
        if (summary === undefined) {
          continue;
        }
        bucketRecorded++;
        recordedDays++;
        bucketIntake += summary.intakeKcal;
        sumIntake += summary.intakeKcal;
        sumBurned += summary.burnedKcal;
        sumScore += summary.score;
        sumCheckin += BitFlags.count(summary.checkinFlags, ALL_CHECKINS);
        sumProtein += summary.proteinG;
        sumFat += summary.fatG;
        sumCarb += summary.carbG;

        if (data.targetKcal > 0) {
          const ratio: number = summary.intakeKcal / data.targetKcal;
          if (ratio >= UNDER_THRESHOLD && ratio <= OVER_TOLERANCE) {
            goalMetDays++;
          }
        }
      }

      const bar: ChartBar = new ChartBar();
      bar.label = FormatUtils.formatShortDate(DateUtils.addDays(startKey, b * bucketDays));
      bar.dayCount = bucketDayCount;
      bar.recordedDays = bucketRecorded;
      bar.avgIntake = bucketRecorded > 0 ? bucketIntake / bucketRecorded : 0;
      if (bar.avgIntake > maxAvg) {
        maxAvg = bar.avgIntake;
      }
      data.bars.push(bar);
    }

    for (const bar of data.bars) {
      bar.heightRatio = bar.avgIntake / maxAvg;
      if (bar.recordedDays === 0) {
        bar.status = BarStatus.EMPTY;
        continue;
      }
      if (data.targetKcal <= 0) {
        bar.status = BarStatus.OK;
        continue;
      }
      bar.targetRatio = bar.avgIntake / data.targetKcal;
      if (bar.targetRatio > OVER_TOLERANCE) {
        bar.status = BarStatus.OVER;
      } else if (bar.targetRatio < UNDER_THRESHOLD) {
        bar.status = BarStatus.UNDER;
      } else {
        bar.status = BarStatus.OK;
      }
    }

    data.recordedDays = recordedDays;
    data.goalMetDays = goalMetDays;

    if (recordedDays > 0) {
      data.avgIntake = sumIntake / recordedDays;
      data.avgBurned = sumBurned / recordedDays;
      data.avgScore = sumScore / recordedDays;
      data.avgCheckinCount = sumCheckin / recordedDays;
    }

    const actual: MacroDistribution = NutritionAnalyzer.distribution(sumProtein, sumFat, sumCarb);
    data.actualRatio = { protein: actual.protein, fat: actual.fat, carb: actual.carb };
    data.hasMacroData = actual.totalKcal > 0;

    if (plan !== undefined) {
      data.targetRatio = NutritionAnalyzer.targetRatioFromGrams(plan.proteinG, plan.fatG, plan.carbG);
      data.similarity = NutritionAnalyzer.similarity(actual, data.targetRatio);
    } else {
      data.similarity = 0;
    }

    data.loaded = true;
    return data;
  }
}
