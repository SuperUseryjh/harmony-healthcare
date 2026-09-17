import { describe, it, expect } from '@ohos/hypium';
import { MacroRatio } from '../main/ets/engine/EnergyCalculator';
import { MacroDistribution, NutritionAnalyzer } from '../main/ets/engine/NutritionAnalyzer';

/**
 * NutritionAnalyzer 单元测试。
 *
 * 重点覆盖"没有数据"和"边界值"两类情况：
 * 配比分析在摄入为 0 时最容易出现除零或误判，而阈值判断的边界
 * （刚好等于阈值算不算超标）直接决定建议会不会误报。
 */
export default function nutritionAnalyzerTest() {

  describe('NutritionAnalyzerTest', () => {

    // 蛋白 30g=120kcal，脂肪 20g=180kcal，碳水 50g=200kcal，合计 500kcal
    it('distribution_basic', 0, () => {
      const dist: MacroDistribution = NutritionAnalyzer.distribution(30, 20, 50);
      expect(dist.totalKcal).assertEqual(500);
      expect(Math.round(dist.protein * 100)).assertEqual(24);
      expect(Math.round(dist.fat * 100)).assertEqual(36);
      expect(Math.round(dist.carb * 100)).assertEqual(40);
    });

    it('distribution_emptyReturnsZero', 0, () => {
      const dist: MacroDistribution = NutritionAnalyzer.distribution(0, 0, 0);
      expect(dist.totalKcal).assertEqual(0);
      expect(dist.protein).assertEqual(0);
      expect(dist.fat).assertEqual(0);
      expect(dist.carb).assertEqual(0);
    });

    it('similarity_perfectMatch', 0, () => {
      const target: MacroRatio = { protein: 0.30, fat: 0.25, carb: 0.45 };
      const actual: MacroDistribution = { protein: 0.30, fat: 0.25, carb: 0.45, totalKcal: 1000 };
      expect(NutritionAnalyzer.similarity(actual, target)).assertEqual(1);
    });

    // 两项完全错开：|1−0| + |0−1| + |0−0| = 2，归一化后相似度为 0
    it('similarity_oppositeGivesZero', 0, () => {
      const target: MacroRatio = { protein: 0, fat: 1, carb: 0 };
      const actual: MacroDistribution = { protein: 1, fat: 0, carb: 0, totalKcal: 1000 };
      expect(NutritionAnalyzer.similarity(actual, target)).assertEqual(0);
    });

    it('similarity_noDataGivesZero', 0, () => {
      const target: MacroRatio = { protein: 0.30, fat: 0.25, carb: 0.45 };
      const actual: MacroDistribution = { protein: 0, fat: 0, carb: 0, totalKcal: 0 };
      expect(NutritionAnalyzer.similarity(actual, target)).assertEqual(0);
    });

    // dist(30,20,50) 得到 0.24/0.36/0.40，与 0.30/0.25/0.45 的绝对差之和为 0.22
    // 相似度 = 1 − 0.22/2 = 0.89
    it('similarity_partialDeviation', 0, () => {
      const target: MacroRatio = { protein: 0.30, fat: 0.25, carb: 0.45 };
      const actual: MacroDistribution = NutritionAnalyzer.distribution(30, 20, 50);
      expect(Math.round(NutritionAnalyzer.similarity(actual, target) * 100)).assertEqual(89);
    });

    it('energyBalance', 0, () => {
      expect(NutritionAnalyzer.energyBalance(2000, 300)).assertEqual(1700);
      expect(NutritionAnalyzer.energyBalance(1800, 500)).assertEqual(1300);
    });

    it('intakeRatio', 0, () => {
      expect(NutritionAnalyzer.intakeRatio(2000, 2500)).assertEqual(0.8);
      expect(NutritionAnalyzer.intakeRatio(100, 0)).assertEqual(0);
    });

    // 阈值边界：2000 × 1.15 = 2300，恰好等于阈值时不算超标
    it('isOverIntake_boundary', 0, () => {
      expect(NutritionAnalyzer.isOverIntake(2300, 2000, 0.15)).assertFalse();
      expect(NutritionAnalyzer.isOverIntake(2301, 2000, 0.15)).assertTrue();
    });

    // 阈值边界：2000 × 0.6 = 1200，恰好等于阈值时不算不足
    it('isUnderIntake_boundary', 0, () => {
      expect(NutritionAnalyzer.isUnderIntake(1200, 2000, 0.6)).assertFalse();
      expect(NutritionAnalyzer.isUnderIntake(1199, 2000, 0.6)).assertTrue();
    });

    it('targetRatioFromGrams', 0, () => {
      const ratio: MacroRatio = NutritionAnalyzer.targetRatioFromGrams(30, 20, 50);
      expect(Math.round(ratio.protein * 100)).assertEqual(24);
      expect(Math.round(ratio.fat * 100)).assertEqual(36);
      expect(Math.round(ratio.carb * 100)).assertEqual(40);
    });
  });
}
