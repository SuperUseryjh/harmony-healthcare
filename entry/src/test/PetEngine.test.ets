import { describe, it, expect } from '@ohos/hypium';
import { MealType } from '../main/ets/model/Enums';
import { PetEngine, PetExpression, PetStage, PetState } from '../main/ets/engine/PetEngine';
import { PetSpecies, PetSpeciesCatalog } from '../main/ets/model/PetSpecies';

/**
 * PetEngine 单元测试。
 *
 * 重点是三处容易写错的地方：
 *   1. 阶段门槛的边界（差一天算不算跨阶段）
 *   2. 三项状态的上限裁剪（暴饮暴食或狂运动不能超过 100）
 *   3. 台词的分支选择——并列时不能漏掉真正最低的那一项
 */
export default function petEngineTest() {

  describe('PetEngineTest', () => {

    // 加餐不计入饱食：只记加餐时主餐数应为 0
    it('countMainMeals_onlyCountsMainMeals', 0, () => {
      expect(PetEngine.countMainMeals([
        MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK])).assertEqual(3);
    });

    it('countMainMeals_empty', 0, () => {
      expect(PetEngine.countMainMeals([])).assertEqual(0);
    });

    it('fullness_threeMealsIsFull', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 0, false, 0, 0);
      expect(state.fullness).assertEqual(100);
    });

    // 1/3 ≈ 33.33 → 33
    it('fullness_oneMealIsThird', 0, () => {
      const state: PetState = PetEngine.evaluate(1, 0, false, 0, 0);
      expect(Math.round(state.fullness)).assertEqual(33);
    });

    // 超过三顿也不能超过 100
    it('fullness_clampedAboveThree', 0, () => {
      const state: PetState = PetEngine.evaluate(6, 0, false, 0, 0);
      expect(state.fullness).assertEqual(100);
    });

    it('vitality_waterOnlyGivesHalf', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, true, 0, 0);
      expect(state.vitality).assertEqual(50);
    });

    // 运动 10/20 分钟 → 25 分，加上饮水 50 = 75
    it('vitality_partialActivityPlusWater', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 10, true, 0, 0);
      expect(state.vitality).assertEqual(75);
    });

    // 运动超时也封顶在 50
    it('vitality_activityClamped', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 120, true, 0, 0);
      expect(state.vitality).assertEqual(100);
    });

    it('mood_fullStreakGivesFull', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 7, 0);
      expect(state.mood).assertEqual(100);
    });

    // 3/7 ≈ 42.86 → 43
    it('mood_partialStreak', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 3, 0);
      expect(Math.round(state.mood)).assertEqual(43);
    });

    it('stage_zeroDaysIsEgg', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 0);
      expect(state.stage).assertEqual(PetStage.EGG);
      expect(state.stageName).assertEqual('蛋');
    });

    // 门槛是"达到即进入"：3 天正好进幼生期，2 天还留在蛋
    it('stage_boundaryAtThreeDays', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 3).stage).assertEqual(PetStage.BABY);
    });

    it('stage_justBelowFirstBoundary', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 2).stage).assertEqual(PetStage.EGG);
    });

    it('stage_boundaryAtSevenDays', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 7).stage).assertEqual(PetStage.GROWING);
    });

    it('stage_boundaryAtThirtyDays', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 30);
      expect(state.stage).assertEqual(PetStage.ADULT);
      expect(state.isMaxStage).assertTrue();
    });

    it('daysToNextStage_eggNeedsThree', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 0).daysToNextStage).assertEqual(3);
    });

    it('daysToNextStage_zeroAtMaxStage', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 40).daysToNextStage).assertEqual(0);
    });

    // 三项都满分 → 开心
    it('expression_happyWhenAllHigh', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 7, 0);
      expect(state.expression).assertEqual(PetExpression.HAPPY);
    });

    // 三项都是 0 → 难过
    it('expression_sadWhenAllLow', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 0);
      expect(state.expression).assertEqual(PetExpression.SAD);
    });

    // 100 / 50 / 0 → 均值 50，落在中间档
    it('expression_normalInMiddleRange', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 0, true, 0, 0);
      expect(state.expression).assertEqual(PetExpression.NORMAL);
    });

    it('message_eggHintsHatch', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 1);
      expect(state.message).assertEqual('再记录 2 天就能孵化了');
    });

    it('message_fullnessLowest', 0, () => {
      // 饱食 0，其余满分
      const state: PetState = PetEngine.evaluate(0, 30, true, 7, 5);
      expect(state.message).assertEqual('肚子有点饿了，记一餐吧');
    });

    it('message_vitalityLowest', 0, () => {
      // 饱食 100、心情 100，活力 0
      const state: PetState = PetEngine.evaluate(3, 0, false, 7, 5);
      expect(state.message).assertEqual('想活动一下，陪我动一动？');
    });

    // 饱食与活力并列满分时，不能因为先比较饱食就把心情最低这个事实盖掉
    it('message_moodLowestDespiteTieAbove', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 0, 5);
      expect(state.message).assertEqual('好久没一起打卡了，别断呀');
    });

    it('message_praiseWhenAllGood', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 7, 5);
      expect(state.message).assertEqual('今天把我照顾得很好，继续保持');
    });
  });

  /**
   * 物种差异。
   *
   * 核心是「水果不经历蛋阶段」这一条：蛋是鸟类的生理过程，
   * 草莓从蛋里孵出来不合常理，这是需求明确要求的。
   */
  describe('PetSpeciesTest', () => {

    it('duck_stillStartsAsEgg', 0, () => {
      const duck: PetSpecies = PetSpeciesCatalog.find(PetSpeciesCatalog.defaultCode());
      expect(PetEngine.evaluate(0, 0, false, 0, 0, duck).stage).assertEqual(PetStage.EGG);
    });

    it('fruit_neverStartsAsEgg', 0, () => {
      const fruit: PetSpecies = PetSpeciesCatalog.find('strawberry');
      expect(PetEngine.evaluate(0, 0, false, 0, 0, fruit).stage).assertEqual(PetStage.BABY);
    });

    // 门槛数组不变，所以水果在 3 天时仍停在小果，要到 7 天才进阶
    it('fruit_staysAtFirstStageUntilDay7', 0, () => {
      const fruit: PetSpecies = PetSpeciesCatalog.find('watermelon');
      expect(PetEngine.evaluate(0, 0, false, 0, 3, fruit).stage).assertEqual(PetStage.BABY);
      expect(PetEngine.evaluate(0, 0, false, 0, 7, fruit).stage).assertEqual(PetStage.GROWING);
    });

    it('fruit_usesFruitStageNames', 0, () => {
      const fruit: PetSpecies = PetSpeciesCatalog.find('lemon');
      expect(PetEngine.evaluate(0, 0, false, 0, 0, fruit).stageName).assertEqual('小果');
      expect(PetEngine.evaluate(0, 0, false, 0, 7, fruit).stageName).assertEqual('半熟');
      expect(PetEngine.evaluate(0, 0, false, 0, 30, fruit).stageName).assertEqual('熟透');
    });

    // 0 天时已是第 1 阶，距下一阶（7 天）还有 7 天；不能因为跳过蛋而算错
    it('fruit_daysToNextStageCountsFromRealThreshold', 0, () => {
      const fruit: PetSpecies = PetSpeciesCatalog.find('apple');
      expect(PetEngine.evaluate(0, 0, false, 0, 0, fruit).daysToNextStage).assertEqual(7);
    });

    it('evaluate_carriesSpeciesCodeForRendering', 0, () => {
      const fruit: PetSpecies = PetSpeciesCatalog.find('grape');
      expect(PetEngine.evaluate(0, 0, false, 0, 0, fruit).speciesCode).assertEqual('grape');
    });

    // 配置写错或物种下线时不能崩，回落小鸭
    it('catalog_unknownCodeFallsBackToDuck', 0, () => {
      expect(PetSpeciesCatalog.find('not_a_species').code).assertEqual('duck');
    });

    // 选择面板按 3 列排，物种数不是 3 的倍数时最后一行会不齐，这里锁住数量假设
    it('catalog_hasTwelveSpecies', 0, () => {
      expect(PetSpeciesCatalog.indexOf('blueberry')).assertEqual(11);
    });
  });
}
