import { KCAL_PER_G_CARB, KCAL_PER_G_FAT, KCAL_PER_G_PROTEIN, MacroRatio } from './EnergyCalculator';

/** 实际摄入的三大营养素热量占比 */
export interface MacroDistribution {
  protein: number;
  fat: number;
  carb: number;
  /** 三大营养素折算的总热量，为 0 时表示没有有效数据 */
  totalKcal: number;
}

/** 营养分析引擎。纯函数，无系统依赖 */
export class NutritionAnalyzer {

  /** 由三大营养素克数算出热量占比 */
  static distribution(proteinG: number, fatG: number, carbG: number): MacroDistribution {
    const proteinKcal: number = proteinG * KCAL_PER_G_PROTEIN;
    const fatKcal: number = fatG * KCAL_PER_G_FAT;
    const carbKcal: number = carbG * KCAL_PER_G_CARB;
    const total: number = proteinKcal + fatKcal + carbKcal;

    if (total <= 0) {
      const empty: MacroDistribution = { protein: 0, fat: 0, carb: 0, totalKcal: 0 };
      return empty;
    }
    const dist: MacroDistribution = {
      protein: proteinKcal / total,
      fat: fatKcal / total,
      carb: carbKcal / total,
      totalKcal: total
    };
    return dist;
  }

  /**
   * 实际配比与目标配比的相似度，1 表示完全一致，0 表示偏差最大。
   * 三个分类的绝对差之和最大为 2，因此除以 2 归一化。
   */
  static similarity(actual: MacroDistribution, target: MacroRatio): number {
    if (actual.totalKcal <= 0) {
      return 0;
    }
    const diff: number = Math.abs(actual.protein - target.protein) +
      Math.abs(actual.fat - target.fat) +
      Math.abs(actual.carb - target.carb);
    const normalized: number = 1 - diff / 2;
    return Math.max(0, Math.min(1, normalized));
  }

  /** 净热量 = 摄入 − 消耗 */
  static energyBalance(intakeKcal: number, burnedKcal: number): number {
    return intakeKcal - burnedKcal;
  }

  /** 摄入达成率，目标为 0 时返回 0 */
  static intakeRatio(intakeKcal: number, targetKcal: number): number {
    if (targetKcal <= 0) {
      return 0;
    }
    return intakeKcal / targetKcal;
  }

  /** 摄入是否超出目标 tolerance 比例（默认 15%） */
  static isOverIntake(intakeKcal: number, targetKcal: number, tolerance: number): boolean {
    if (targetKcal <= 0) {
      return false;
    }
    return intakeKcal > targetKcal * (1 + tolerance);
  }

  /** 摄入是否明显不足（低于目标的 threshold 比例） */
  static isUnderIntake(intakeKcal: number, targetKcal: number, threshold: number): boolean {
    if (targetKcal <= 0) {
      return false;
    }
    return intakeKcal < targetKcal * threshold;
  }

  /** 从宏量营养素目标反推目标热量占比，避免建议引擎依赖 Goal 枚举 */
  static targetRatioFromGrams(proteinG: number, fatG: number, carbG: number): MacroRatio {
    const dist: MacroDistribution = NutritionAnalyzer.distribution(proteinG, fatG, carbG);
    const ratio: MacroRatio = { protein: dist.protein, fat: dist.fat, carb: dist.carb };
    return ratio;
  }
}
