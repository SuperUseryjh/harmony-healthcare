import { ActivityLevel, ActivityType, Gender, Goal, Intensity } from '../model/Enums';

/** 三大营养素的目标摄入量（克）与对应热量 */
export interface MacroTarget {
  proteinG: number;
  fatG: number;
  carbG: number;
  proteinKcal: number;
  fatKcal: number;
  carbKcal: number;
}

/** 三大营养素的热量占比，三项之和为 1 */
export interface MacroRatio {
  protein: number;
  fat: number;
  carb: number;
}

/** 常量：蛋白与碳水 4 kcal/g，脂肪 9 kcal/g */
export const KCAL_PER_G_PROTEIN: number = 4;
export const KCAL_PER_G_CARB: number = 4;
export const KCAL_PER_G_FAT: number = 9;

/**
 * 能量计算引擎。
 *
 * 全部为静态纯函数，不依赖任何系统能力，可直接用本地单元测试覆盖。
 * 返回值为未取整的原始精度，展示时再四舍五入。
 */
export class EnergyCalculator {
  /** 每日饮水目标下限与上限（ml） */
  static readonly WATER_MIN_ML: number = 1500;
  static readonly WATER_MAX_ML: number = 3000;
  /** 每公斤体重的推荐饮水量（ml） */
  static readonly WATER_ML_PER_KG: number = 35;

  /**
   * 基础代谢率，Mifflin-St Jeor 公式。
   * 男：10w + 6.25h − 5a + 5
   * 女：10w + 6.25h − 5a − 161
   * 性别未设置时取两者均值。
   */
  static calcBmr(gender: number, weightKg: number, heightCm: number, age: number): number {
    const base: number = 10 * weightKg + 6.25 * heightCm - 5 * age;
    if (gender === Gender.MALE) {
      return base + 5;
    }
    if (gender === Gender.FEMALE) {
      return base - 161;
    }
    return base - 78;
  }

  /** 活动系数 */
  static activityFactor(level: number): number {
    if (level === ActivityLevel.SEDENTARY) {
      return 1.2;
    }
    if (level === ActivityLevel.LIGHT) {
      return 1.375;
    }
    if (level === ActivityLevel.MODERATE) {
      return 1.55;
    }
    if (level === ActivityLevel.ACTIVE) {
      return 1.725;
    }
    if (level === ActivityLevel.VERY_ACTIVE) {
      return 1.9;
    }
    return 1.375;
  }

  /** 每日总消耗 = BMR × 活动系数 */
  static calcTdee(bmr: number, activityLevel: number): number {
    return bmr * EnergyCalculator.activityFactor(activityLevel);
  }

  /**
   * 每日目标摄入热量。
   * 减脂按 TDEE 的 85% 制造缺口，但设下限保护：不低于 BMR 的 1.1 倍，
   * 避免长期过低摄入导致肌肉流失。
   */
  static calcTargetIntake(tdee: number, bmr: number, goal: number): number {
    if (goal === Goal.LOSE) {
      const planned: number = tdee * 0.85;
      const floor: number = bmr * 1.1;
      return planned < floor ? floor : planned;
    }
    if (goal === Goal.GAIN) {
      return tdee * 1.10;
    }
    return tdee;
  }

  /** 按目标返回三大营养素的目标热量占比 */
  static macroRatioOf(goal: number): MacroRatio {
    if (goal === Goal.LOSE) {
      const lose: MacroRatio = { protein: 0.30, fat: 0.25, carb: 0.45 };
      return lose;
    }
    if (goal === Goal.GAIN) {
      const gain: MacroRatio = { protein: 0.30, fat: 0.20, carb: 0.50 };
      return gain;
    }
    const keep: MacroRatio = { protein: 0.25, fat: 0.25, carb: 0.50 };
    return keep;
  }

  /** 按目标摄入热量与目标占比，换算出三大营养素的克数 */
  static calcMacroTarget(targetKcal: number, goal: number): MacroTarget {
    const ratio: MacroRatio = EnergyCalculator.macroRatioOf(goal);
    const proteinKcal: number = targetKcal * ratio.protein;
    const fatKcal: number = targetKcal * ratio.fat;
    const carbKcal: number = targetKcal * ratio.carb;
    const target: MacroTarget = {
      proteinKcal: proteinKcal,
      fatKcal: fatKcal,
      carbKcal: carbKcal,
      proteinG: proteinKcal / KCAL_PER_G_PROTEIN,
      fatG: fatKcal / KCAL_PER_G_FAT,
      carbG: carbKcal / KCAL_PER_G_CARB
    };
    return target;
  }

  /** 各运动类型的 MET 参考值 */
  static metOf(activityType: number): number {
    if (activityType === ActivityType.WALK) {
      return 3.0;
    }
    if (activityType === ActivityType.RUN) {
      return 7.0;
    }
    if (activityType === ActivityType.CYCLE) {
      return 6.0;
    }
    if (activityType === ActivityType.BALL) {
      return 6.5;
    }
    if (activityType === ActivityType.STRENGTH) {
      return 5.0;
    }
    if (activityType === ActivityType.SWIM) {
      return 7.0;
    }
    return 4.0;
  }

  /** 强度系数 */
  static intensityFactor(intensity: number): number {
    if (intensity === Intensity.LOW) {
      return 0.85;
    }
    if (intensity === Intensity.HIGH) {
      return 1.15;
    }
    return 1.0;
  }

  /**
   * 单次运动消耗，MET 法：kcal = MET × 体重(kg) × 时长(h) × 强度系数
   */
  static calcExerciseKcal(activityType: number, weightKg: number, minutes: number, intensity: number): number {
    if (minutes <= 0 || weightKg <= 0) {
      return 0;
    }
    const hours: number = minutes / 60;
    return EnergyCalculator.metOf(activityType) * weightKg * hours *
      EnergyCalculator.intensityFactor(intensity);
  }

  /** 每日饮水目标，按体重推算并做上下限保护 */
  static calcWaterTargetMl(weightKg: number): number {
    const raw: number = weightKg * EnergyCalculator.WATER_ML_PER_KG;
    if (raw < EnergyCalculator.WATER_MIN_ML) {
      return EnergyCalculator.WATER_MIN_ML;
    }
    if (raw > EnergyCalculator.WATER_MAX_ML) {
      return EnergyCalculator.WATER_MAX_ML;
    }
    return raw;
  }
}
