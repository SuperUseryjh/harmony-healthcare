import { describe, it, expect } from '@ohos/hypium';
import { HealthScoreCalculator, ScoreBreakdown, ScoreInput } from '../main/ets/engine/HealthScoreCalculator';

/**
 * HealthScoreCalculator 单元测试。
 *
 * 健康分是三个维度的加权和，单独验证每个维度的达成度，
 * 再验证加权求和不会越界（0-100），是这类"打分"逻辑最容易出错的地方。
 */
export default function healthScoreCalculatorTest() {

  describe('HealthScoreCalculatorTest', () => {

    it('heatScore_exactTarget', 0, () => {
      expect(HealthScoreCalculator.heatScore(2000, 2000)).assertEqual(1);
    });

    it('heatScore_noIntake', 0, () => {
      expect(HealthScoreCalculator.heatScore(0, 2000)).assertEqual(0);
    });

    // |3000 − 2000| / 2000 = 0.5
    it('heatScore_halfDeviation', 0, () => {
      expect(HealthScoreCalculator.heatScore(3000, 2000)).assertEqual(0.5);
      expect(HealthScoreCalculator.heatScore(1000, 2000)).assertEqual(0.5);
    });

    // 偏差达到 100% 时得分为 0，不应出现负分
    it('heatScore_extremeDeviationClampedToZero', 0, () => {
      expect(HealthScoreCalculator.heatScore(4000, 2000)).assertEqual(0);
      expect(HealthScoreCalculator.heatScore(0, 2000)).assertEqual(0);
    });

    it('heatScore_zeroTargetGivesZero', 0, () => {
      expect(HealthScoreCalculator.heatScore(2000, 0)).assertEqual(0);
    });

    it('checkinScore_partial', 0, () => {
      expect(HealthScoreCalculator.checkinScore(3, 6)).assertEqual(0.5);
    });

    it('checkinScore_full', 0, () => {
      expect(HealthScoreCalculator.checkinScore(6, 6)).assertEqual(1);
    });

    it('checkinScore_zeroTotalGivesZero', 0, () => {
      expect(HealthScoreCalculator.checkinScore(0, 0)).assertEqual(0);
    });

    it('checkinScore_clampedToOne', 0, () => {
      expect(HealthScoreCalculator.checkinScore(7, 6)).assertEqual(1);
    });

    // 满分场景：热量正好达标、营养素配比与目标一致、打卡全勤
    it('calc_perfectScore', 0, () => {
      const fatG: number = 2000 * 0.25 / 9;
      const input: ScoreInput = {
        intakeKcal: 2000,
        targetKcal: 2000,
        proteinG: 150,
        fatG: fatG,
        carbG: 225,
        targetProteinG: 150,
        targetFatG: fatG,
        targetCarbG: 225,
        completedCheckins: 6,
        totalCheckins: 6
      };
      const result: ScoreBreakdown = HealthScoreCalculator.calc(input);
      expect(result.total).assertEqual(100);
      expect(result.heatScore).assertEqual(1);
      expect(result.macroScore).assertEqual(1);
      expect(result.checkinScore).assertEqual(1);
    });

    // 完全没有记录：三个维度都是 0
    it('calc_noDataGivesZero', 0, () => {
      const input: ScoreInput = {
        intakeKcal: 0,
        targetKcal: 2000,
        proteinG: 0,
        fatG: 0,
        carbG: 0,
        targetProteinG: 150,
        targetFatG: 55.6,
        targetCarbG: 225,
        completedCheckins: 0,
        totalCheckins: 6
      };
      const result: ScoreBreakdown = HealthScoreCalculator.calc(input);
      expect(result.total).assertEqual(0);
    });

    // 只有热量达标：0.8 × 40 = 32
    it('calc_heatOnly', 0, () => {
      const input: ScoreInput = {
        intakeKcal: 2400,
        targetKcal: 2000,
        proteinG: 0,
        fatG: 0,
        carbG: 0,
        targetProteinG: 150,
        targetFatG: 55.6,
        targetCarbG: 225,
        completedCheckins: 0,
        totalCheckins: 6
      };
      const result: ScoreBreakdown = HealthScoreCalculator.calc(input);
      expect(result.total).assertEqual(32);
    });

    // 只有打卡完成一半：0.5 × 30 = 15
    it('calc_checkinOnly', 0, () => {
      const input: ScoreInput = {
        intakeKcal: 0,
        targetKcal: 2000,
        proteinG: 0,
        fatG: 0,
        carbG: 0,
        targetProteinG: 150,
        targetFatG: 55.6,
        targetCarbG: 225,
        completedCheckins: 3,
        totalCheckins: 6
      };
      const result: ScoreBreakdown = HealthScoreCalculator.calc(input);
      expect(result.total).assertEqual(15);
    });

    // 得分必须落在 0-100 之间
    it('calc_totalAlwaysWithinRange', 0, () => {
      const input: ScoreInput = {
        intakeKcal: 99999,
        targetKcal: 2000,
        proteinG: 9999,
        fatG: 9999,
        carbG: 9999,
        targetProteinG: 150,
        targetFatG: 55.6,
        targetCarbG: 225,
        completedCheckins: 99,
        totalCheckins: 6
      };
      const result: ScoreBreakdown = HealthScoreCalculator.calc(input);
      expect(result.total >= 0).assertTrue();
      expect(result.total <= 100).assertTrue();
    });
  });
}
