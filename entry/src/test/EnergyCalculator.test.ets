import { describe, it, expect } from '@ohos/hypium';
import { ActivityType, Gender, Goal, Intensity } from '../main/ets/model/Enums';
import { EnergyCalculator, MacroTarget } from '../main/ets/engine/EnergyCalculator';

/**
 * EnergyCalculator 单元测试。
 *
 * 这些公式是整个应用的数据基础（目标热量、营养素目标、运动消耗），
 * 一旦算错，后面的分析、建议、健康分全部会偏。
 * 因此这里覆盖的不只是常规值，也包括边界：性别未设置、减脂下限保护、饮水上下限裁剪。
 */
export default function energyCalculatorTest() {

  describe('EnergyCalculatorTest', () => {

    // BMR = 10w + 6.25h − 5a + 5（男）
    // 10×70 + 6.25×175 − 5×25 + 5 = 700 + 1093.75 − 125 + 5 = 1673.75
    it('calcBmr_male', 0, () => {
      expect(Math.round(EnergyCalculator.calcBmr(Gender.MALE, 70, 175, 25))).assertEqual(1674);
    });

    // BMR = 10w + 6.25h − 5a − 161（女）
    // 600 + 1031.25 − 125 − 161 = 1345.25
    it('calcBmr_female', 0, () => {
      expect(Math.round(EnergyCalculator.calcBmr(Gender.FEMALE, 60, 165, 25))).assertEqual(1345);
    });

    // 性别未设置时取男女均值，即常数项为 −78
    // 700 + 1093.75 − 125 − 78 = 1590.75
    it('calcBmr_unknownGender', 0, () => {
      expect(Math.round(EnergyCalculator.calcBmr(Gender.UNKNOWN, 70, 175, 25))).assertEqual(1591);
    });

    it('activityFactor_allLevels', 0, () => {
      expect(EnergyCalculator.activityFactor(1)).assertEqual(1.2);
      expect(EnergyCalculator.activityFactor(2)).assertEqual(1.375);
      expect(EnergyCalculator.activityFactor(3)).assertEqual(1.55);
      expect(EnergyCalculator.activityFactor(4)).assertEqual(1.725);
      expect(EnergyCalculator.activityFactor(5)).assertEqual(1.9);
    });

    // 1673.75 × 1.375 = 2301.40625
    it('calcTdee_lightActivity', 0, () => {
      expect(Math.round(EnergyCalculator.calcTdee(1673.75, 2))).assertEqual(2301);
    });

    it('calcTargetIntake_keep', 0, () => {
      expect(Math.round(EnergyCalculator.calcTargetIntake(2301.40625, 1673.75, Goal.KEEP))).assertEqual(2301);
    });

    // 2301.40625 × 0.85 = 1956.1953125，高于下限 1673.75 × 1.1 = 1841.125，取下限保护之外的计划值
    it('calcTargetIntake_lose_normal', 0, () => {
      expect(Math.round(EnergyCalculator.calcTargetIntake(2301.40625, 1673.75, Goal.LOSE))).assertEqual(1956);
    });

    // 下限保护：TDEE 1800 × 0.85 = 1530 低于 BMR 1500 × 1.1 = 1650，应返回下限 1650
    it('calcTargetIntake_lose_floorProtection', 0, () => {
      expect(Math.round(EnergyCalculator.calcTargetIntake(1800, 1500, Goal.LOSE))).assertEqual(1650);
    });

    // 2301.40625 × 1.10 = 2531.546875
    it('calcTargetIntake_gain', 0, () => {
      expect(Math.round(EnergyCalculator.calcTargetIntake(2301.40625, 1673.75, Goal.GAIN))).assertEqual(2532);
    });

    it('macroRatioOf_sumsToOne', 0, () => {
      expect(EnergyCalculator.macroRatioOf(Goal.LOSE).protein).assertEqual(0.30);
      expect(EnergyCalculator.macroRatioOf(Goal.KEEP).carb).assertEqual(0.50);
      expect(EnergyCalculator.macroRatioOf(Goal.GAIN).fat).assertEqual(0.20);
    });

    // 减脂目标 1956.1953125 kcal：
    // 蛋白 30% → 586.85859375 kcal → 146.7146484375 g → 147
    // 脂肪 25% → 489.048828125 kcal → 54.3387586806 g → 54
    // 碳水 45% → 880.287890625 kcal → 220.071972656 g → 220
    it('calcMacroTarget_lose', 0, () => {
      const target: MacroTarget = EnergyCalculator.calcMacroTarget(1956.1953125, Goal.LOSE);
      expect(Math.round(target.proteinG)).assertEqual(147);
      expect(Math.round(target.fatG)).assertEqual(54);
      expect(Math.round(target.carbG)).assertEqual(220);
    });

    it('metOf_allTypes', 0, () => {
      expect(EnergyCalculator.metOf(ActivityType.WALK)).assertEqual(3.0);
      expect(EnergyCalculator.metOf(ActivityType.RUN)).assertEqual(7.0);
      expect(EnergyCalculator.metOf(ActivityType.CYCLE)).assertEqual(6.0);
      expect(EnergyCalculator.metOf(ActivityType.BALL)).assertEqual(6.5);
      expect(EnergyCalculator.metOf(ActivityType.STRENGTH)).assertEqual(5.0);
      expect(EnergyCalculator.metOf(ActivityType.SWIM)).assertEqual(7.0);
      expect(EnergyCalculator.metOf(ActivityType.OTHER)).assertEqual(4.0);
    });

    // 7.0 × 70 × 0.5 × 1.0 = 245
    it('calcExerciseKcal_mediumIntensity', 0, () => {
      expect(Math.round(EnergyCalculator.calcExerciseKcal(
        ActivityType.RUN, 70, 30, Intensity.MEDIUM))).assertEqual(245);
    });

    // 245 × 1.15 = 281.75
    it('calcExerciseKcal_highIntensity', 0, () => {
      expect(Math.round(EnergyCalculator.calcExerciseKcal(
        ActivityType.RUN, 70, 30, Intensity.HIGH))).assertEqual(282);
    });

    // 3.0 × 70 × 1 × 0.85 = 178.5
    it('calcExerciseKcal_lowIntensity', 0, () => {
      expect(Math.round(EnergyCalculator.calcExerciseKcal(
        ActivityType.WALK, 70, 60, Intensity.LOW))).assertEqual(179);
    });

    it('calcExerciseKcal_guardsInvalidInput', 0, () => {
      expect(EnergyCalculator.calcExerciseKcal(ActivityType.RUN, 70, 0, Intensity.MEDIUM)).assertEqual(0);
      expect(EnergyCalculator.calcExerciseKcal(ActivityType.RUN, 0, 30, Intensity.MEDIUM)).assertEqual(0);
    });

    it('calcWaterTargetMl_normal', 0, () => {
      expect(EnergyCalculator.calcWaterTargetMl(70)).assertEqual(2450);
    });

    it('calcWaterTargetMl_clampLow', 0, () => {
      // 40 × 35 = 1400，低于下限 1500
      expect(EnergyCalculator.calcWaterTargetMl(40)).assertEqual(1500);
    });

    it('calcWaterTargetMl_clampHigh', 0, () => {
      // 100 × 35 = 3500，高于上限 3000
      expect(EnergyCalculator.calcWaterTargetMl(100)).assertEqual(3000);
    });
  });
}
