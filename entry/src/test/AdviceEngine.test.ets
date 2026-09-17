import { describe, it, expect } from '@ohos/hypium';
import { AdviceContext, AdviceEngine, AdviceItem } from '../main/ets/engine/AdviceEngine';

/**
 * AdviceEngine 单元测试。
 *
 * 建议引擎是"规则库"，最容易出的问题是**误报**（没数据时说用户吃太多）
 * 和**时段错乱**（白天就催喝水、催运动）。因此这里重点验证：
 * 1. 无数据时不误触发配比类建议
 * 2. 时段相关规则只在晚间生效
 * 3. 优先级顺序与条数截断正确
 */
export default function adviceEngineTest() {

  describe('AdviceEngineTest', () => {

    it('generate_profileMissing', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 0;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('PROFILE_MISSING');
    });

    // 2400 > 2000 × 1.15 = 2300，触发超标
    it('generate_overIntake', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 2400;
      ctx.currentHour = 12;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('OVER_INTAKE');
      expect(items[0].severity).assertEqual(AdviceEngine.SEVERITY_WARN);
    });

    // 白天不催喝水、不催运动，只报热量超标
    it('generate_overIntake_noEveningRulesDuringDay', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 2400;
      ctx.currentHour = 9;
      ctx.waterMl = 0;
      ctx.activityMin = 0;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('OVER_INTAKE');
    });

    // 晚间摄入不足 + 喝水不足 + 未运动，按优先级依次输出三条
    it('generate_eveningMultipleIssues', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 1000;
      ctx.currentHour = 21;
      ctx.waterMl = 0;
      ctx.activityMin = 0;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(3);
      expect(items[0].code).assertEqual('UNDER_INTAKE');
      expect(items[1].code).assertEqual('WATER_LOW');
      expect(items[2].code).assertEqual('NO_ACTIVITY');
    });

    // 无摄入数据时，配比类规则不得误触发
    it('generate_noMacroData_noFalsePositive', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.targetProteinG = 150;
      ctx.targetFatG = 55.6;
      ctx.targetCarbG = 225;
      ctx.intakeKcal = 2000;
      ctx.proteinG = 0;
      ctx.fatG = 0;
      ctx.carbG = 0;
      ctx.currentHour = 12;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('ALL_GOOD');
    });

    // 蛋白占比 0.125 低于目标 0.30 × 0.7 = 0.21，触发蛋白偏低
    it('generate_proteinLow', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.targetProteinG = 150;
      ctx.targetFatG = 2000 * 0.25 / 9;
      ctx.targetCarbG = 225;
      ctx.intakeKcal = 2000;
      ctx.proteinG = 50;
      ctx.fatG = 2000 * 0.25 / 9;
      ctx.carbG = 225;
      ctx.currentHour = 12;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('PROTEIN_LOW');
    });

    // 脂肪占比明显超标：目标 0.25，实际给到 0.6 以上
    it('generate_fatHigh', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.targetProteinG = 150;
      ctx.targetFatG = 2000 * 0.25 / 9;
      ctx.targetCarbG = 225;
      ctx.intakeKcal = 2000;
      ctx.proteinG = 100;
      ctx.fatG = 100;
      ctx.carbG = 100;
      ctx.currentHour = 12;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      let hasFatHigh: boolean = false;
      for (const item of items) {
        if (item.code === 'FAT_HIGH') {
          hasFatHigh = true;
        }
      }
      expect(hasFatHigh).assertTrue();
    });

    it('generate_streakPraise', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 2000;
      ctx.currentHour = 12;
      ctx.streakDays = 7;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('STREAK_PRAISE');
    });

    it('generate_streakJustBelowThreshold', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 2000;
      ctx.currentHour = 12;
      ctx.streakDays = 6;
      const items: AdviceItem[] = AdviceEngine.generate(ctx);
      expect(items.length).assertEqual(1);
      expect(items[0].code).assertEqual('ALL_GOOD');
    });

    // maxCount 应截断结果条数，且保留优先级更高的
    it('generate_respectsMaxCount', 0, () => {
      const ctx: AdviceContext = new AdviceContext();
      ctx.targetKcal = 2000;
      ctx.intakeKcal = 1000;
      ctx.currentHour = 21;
      ctx.waterMl = 0;
      ctx.activityMin = 0;
      const items: AdviceItem[] = AdviceEngine.generate(ctx, 2);
      expect(items.length).assertEqual(2);
      expect(items[0].code).assertEqual('UNDER_INTAKE');
      expect(items[1].code).assertEqual('WATER_LOW');
    });
  });
}
