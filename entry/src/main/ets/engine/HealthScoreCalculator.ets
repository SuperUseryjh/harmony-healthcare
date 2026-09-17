import { MacroDistribution, NutritionAnalyzer } from './NutritionAnalyzer';
import { MacroRatio } from './EnergyCalculator';

/** 健康分计算的输入 */
export interface ScoreInput {
  intakeKcal: number;
  targetKcal: number;
  proteinG: number;
  fatG: number;
  carbG: number;
  targetProteinG: number;
  targetFatG: number;
  targetCarbG: number;
  completedCheckins: number;
  totalCheckins: number;
}

/** 健康分明细，各分项均为 0-1 的达成度 */
export interface ScoreBreakdown {
  /** 0-100 的最终得分 */
  total: number;
  /** 热量达成度 */
  heatScore: number;
  /** 营养素配比相似度 */
  macroScore: number;
  /** 打卡完成度 */
  checkinScore: number;
}

/**
 * 健康分引擎。
 *
 * 把「热量达成度」「营养素配比」「打卡完成度」三个维度揉成一个 0-100 的分数，
 * 目的是给用户一个可感知的进步标尺，而不是三个互不相关的数字。
 *
 * 权重：热量 40 分 + 配比 30 分 + 打卡 30 分。
 */
export class HealthScoreCalculator {
  static readonly WEIGHT_HEAT: number = 40;
  static readonly WEIGHT_MACRO: number = 30;
  static readonly WEIGHT_CHECKIN: number = 30;
  static readonly MAX_SCORE: number = 100;

  /** 热量达成度：越接近目标越高，偏差达到 100% 时为 0 */
  static heatScore(intakeKcal: number, targetKcal: number): number {
    if (targetKcal <= 0) {
      return 0;
    }
    const deviation: number = Math.abs(intakeKcal - targetKcal) / targetKcal;
    return HealthScoreCalculator.clamp01(1 - deviation);
  }

  /** 打卡完成度 */
  static checkinScore(completedItems: number, totalItems: number): number {
    if (totalItems <= 0) {
      return 0;
    }
    return HealthScoreCalculator.clamp01(completedItems / totalItems);
  }

  /** 综合计算 */
  static calc(input: ScoreInput): ScoreBreakdown {
    const heat: number = HealthScoreCalculator.heatScore(input.intakeKcal, input.targetKcal);

    const actualDist: MacroDistribution =
      NutritionAnalyzer.distribution(input.proteinG, input.fatG, input.carbG);
    const targetRatio: MacroRatio = NutritionAnalyzer.targetRatioFromGrams(
      input.targetProteinG, input.targetFatG, input.targetCarbG);
    const macro: number = NutritionAnalyzer.similarity(actualDist, targetRatio);

    const checkin: number = HealthScoreCalculator.checkinScore(
      input.completedCheckins, input.totalCheckins);

    const raw: number = heat * HealthScoreCalculator.WEIGHT_HEAT +
      macro * HealthScoreCalculator.WEIGHT_MACRO +
      checkin * HealthScoreCalculator.WEIGHT_CHECKIN;

    const breakdown: ScoreBreakdown = {
      total: Math.round(HealthScoreCalculator.clampRange(raw, 0, HealthScoreCalculator.MAX_SCORE)),
      heatScore: heat,
      macroScore: macro,
      checkinScore: checkin
    };
    return breakdown;
  }

  private static clamp01(value: number): number {
    return HealthScoreCalculator.clampRange(value, 0, 1);
  }

  private static clampRange(value: number, min: number, max: number): number {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
