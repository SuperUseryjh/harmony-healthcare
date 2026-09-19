import { describe, it, expect } from '@ohos/hypium';
import { MealType } from '../main/ets/model/Enums';
import { PetEngine, PetExpression, PetState } from '../main/ets/engine/PetEngine';
import { PetCatalog, PetSpecies, PetStage } from '../main/ets/model/PetSpecies';

/** 阶段下标。阶段数和门槛都来自配置，这里只是给测试物种的取值起个名字 */
const S_EGG: number = 0;
const S_BABY: number = 1;
const S_GROWING: number = 2;
const S_ADULT: number = 3;

function mkStage(name: string, minDays: number, hint: string): PetStage {
  const stage: PetStage = new PetStage();
  stage.name = name;
  stage.minDays = minDays;
  stage.hint = hint;
  stage.image = `pets/${name}.svg`;
  return stage;
}

/**
 * 与正式配置同构的四阶段物种。
 * 引擎本身不再持有任何门槛常量，所以测试必须自己给一份配置——
 * 这正好也证明了"阶段规则完全由配置决定"。
 */
function buildFourStage(): PetSpecies {
  const species: PetSpecies = new PetSpecies();
  species.code = 'test';
  species.label = '测试';
  species.stages = [
    mkStage('蛋', 0, '再记录 {n} 天就能孵化了'),
    mkStage('幼生期', 3, ''),
    mkStage('成长期', 7, ''),
    mkStage('成熟期', 30, '')
  ];
  return species;
}

const SPEC: PetSpecies = buildFourStage();

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
      const state: PetState = PetEngine.evaluate(3, 0, false, 0, 0, SPEC);
      expect(state.fullness).assertEqual(100);
    });

    // 1/3 ≈ 33.33 → 33
    it('fullness_oneMealIsThird', 0, () => {
      const state: PetState = PetEngine.evaluate(1, 0, false, 0, 0, SPEC);
      expect(Math.round(state.fullness)).assertEqual(33);
    });

    // 超过三顿也不能超过 100
    it('fullness_clampedAboveThree', 0, () => {
      const state: PetState = PetEngine.evaluate(6, 0, false, 0, 0, SPEC);
      expect(state.fullness).assertEqual(100);
    });

    it('vitality_waterOnlyGivesHalf', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, true, 0, 0, SPEC);
      expect(state.vitality).assertEqual(50);
    });

    // 运动 10/20 分钟 → 25 分，加上饮水 50 = 75
    it('vitality_partialActivityPlusWater', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 10, true, 0, 0, SPEC);
      expect(state.vitality).assertEqual(75);
    });

    // 运动超时也封顶在 50
    it('vitality_activityClamped', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 120, true, 0, 0, SPEC);
      expect(state.vitality).assertEqual(100);
    });

    it('mood_fullStreakGivesFull', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 7, 0, SPEC);
      expect(state.mood).assertEqual(100);
    });

    // 3/7 ≈ 42.86 → 43
    it('mood_partialStreak', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 3, 0, SPEC);
      expect(Math.round(state.mood)).assertEqual(43);
    });

    it('stage_zeroDaysIsEgg', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 0, SPEC);
      expect(state.stage).assertEqual(S_EGG);
      expect(state.stageName).assertEqual('蛋');
    });

    // 门槛是"达到即进入"：3 天正好进幼生期，2 天还留在蛋
    it('stage_boundaryAtThreeDays', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 3, SPEC).stage).assertEqual(S_BABY);
    });

    it('stage_justBelowFirstBoundary', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 2, SPEC).stage).assertEqual(S_EGG);
    });

    it('stage_boundaryAtSevenDays', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 7, SPEC).stage).assertEqual(S_GROWING);
    });

    it('stage_boundaryAtThirtyDays', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 30, SPEC);
      expect(state.stage).assertEqual(S_ADULT);
      expect(state.isMaxStage).assertTrue();
    });

    it('daysToNextStage_eggNeedsThree', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 0, SPEC).daysToNextStage).assertEqual(3);
    });

    it('daysToNextStage_zeroAtMaxStage', 0, () => {
      expect(PetEngine.evaluate(0, 0, false, 0, 40, SPEC).daysToNextStage).assertEqual(0);
    });

    // 三项都满分 → 开心
    it('expression_happyWhenAllHigh', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 7, 0, SPEC);
      expect(state.expression).assertEqual(PetExpression.HAPPY);
    });

    // 三项都是 0 → 难过
    it('expression_sadWhenAllLow', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 0, SPEC);
      expect(state.expression).assertEqual(PetExpression.SAD);
    });

    // 100 / 50 / 0 → 均值 50，落在中间档
    it('expression_normalInMiddleRange', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 0, true, 0, 0, SPEC);
      expect(state.expression).assertEqual(PetExpression.NORMAL);
    });

    // 第一阶段优先用配置里的 hint，并把 {n} 换成真实天数
    it('message_firstStageUsesConfiguredHint', 0, () => {
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 1, SPEC);
      expect(state.message).assertEqual('再记录 2 天就能孵化了');
    });

    it('message_fullnessLowest', 0, () => {
      // 饱食 0，其余满分
      const state: PetState = PetEngine.evaluate(0, 30, true, 7, 5, SPEC);
      expect(state.message).assertEqual('肚子有点饿了，记一餐吧');
    });

    it('message_vitalityLowest', 0, () => {
      // 饱食 100、心情 100，活力 0
      const state: PetState = PetEngine.evaluate(3, 0, false, 7, 5, SPEC);
      expect(state.message).assertEqual('想活动一下，陪我动一动？');
    });

    // 饱食与活力并列满分时，不能因为先比较饱食就把心情最低这个事实盖掉
    it('message_moodLowestDespiteTieAbove', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 0, 5, SPEC);
      expect(state.message).assertEqual('好久没一起打卡了，别断呀');
    });

    it('message_praiseWhenAllGood', 0, () => {
      const state: PetState = PetEngine.evaluate(3, 30, true, 7, 5, SPEC);
      expect(state.message).assertEqual('今天把我照顾得很好，继续保持');
    });

    // 阶段只到最高一级时不该再说"再 N 天"
    it('message_singleStageSpeciesNeverSaysDays', 0, () => {
      const single: PetSpecies = new PetSpecies();
      single.code = 'one';
      single.stages = [mkStage('唯一', 0, '再记录 {n} 天就长大了')];
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 0, single);
      expect(state.isMaxStage).assertTrue();
      expect(state.message).assertEqual('肚子有点饿了，记一餐吧');
    });
  });

  /**
   * 配置解析。
   *
   * 阶段数、门槛、脸型覆盖全部走配置——这组用例锁的就是"配置能不能如实生效"，
   * 因为加物种、改进阶天数现在只动 JSON，一旦解析出错是没有任何编译期保护的。
   */
  describe('PetCatalogTest', () => {

    const CONFIG: string = `{
      "version": 1,
      "species": [
        {
          "code": "duck", "label": "小鸭",
          "face": { "cx": 14, "cy": -10, "eyeDx": 5, "eyeDy": -4, "eyeR": 3.2,
                    "blushDx": 1, "blushDy": 9, "blushR": 3.6, "single": true },
          "stages": [
            { "name": "蛋", "minDays": 0, "scale": 1.0, "image": "pets/duck_1.svg",
              "hint": "再记录 {n} 天就能孵化了",
              "face": { "cx": 0, "cy": 8, "eyeDx": 9, "eyeDy": 0, "eyeR": 3,
                        "blushDx": 15, "blushDy": 7, "blushR": 3.5, "single": false } },
            { "name": "小鸭", "minDays": 7, "scale": 0.85, "image": "pets/duck_2.svg" },
            { "name": "大鸭", "minDays": 30, "scale": 1.0, "image": "pets/duck_3.svg" }
          ]
        },
        {
          "code": "berry", "label": "莓",
          "stages": [
            { "name": "熟透", "minDays": 5, "scale": 1.0, "image": "pets/berry_2.svg" },
            { "name": "青果", "minDays": 0, "scale": 0.8, "image": "pets/berry_1.svg" }
          ]
        }
      ]
    }`;

    PetCatalog.loadFrom(CONFIG);

    it('loads_allSpecies', 0, () => {
      expect(PetCatalog.all().length).assertEqual(2);
      expect(PetCatalog.isLoaded()).assertTrue();
    });

    // 阶段数由配置决定，不同物种可以不一样
    it('stageCountComesFromConfig', 0, () => {
      const duck: PetSpecies | undefined = PetCatalog.find('duck');
      const berry: PetSpecies | undefined = PetCatalog.find('berry');
      expect(duck === undefined ? -1 : duck.stages.length).assertEqual(3);
      expect(berry === undefined ? -1 : berry.stages.length).assertEqual(2);
    });

    // 配置里写反了顺序也要能正确判定：装载时按 minDays 排过序
    it('stagesAreSortedByMinDays', 0, () => {
      const berry: PetSpecies | undefined = PetCatalog.find('berry');
      expect(berry === undefined ? '' : berry.stages[0].name).assertEqual('青果');
      expect(berry === undefined ? '' : berry.stages[1].name).assertEqual('熟透');
    });

    it('customThresholdsTakeEffect', 0, () => {
      const berry: PetSpecies | undefined = PetCatalog.find('berry');
      if (berry === undefined) {
        expect(false).assertTrue();
        return;
      }
      expect(PetEngine.evaluate(0, 0, false, 0, 4, berry).stage).assertEqual(0);
      expect(PetEngine.evaluate(0, 0, false, 0, 5, berry).stage).assertEqual(1);
    });

    // 阶段上的 face 覆盖物种的 face
    it('stageFaceOverridesSpeciesFace', 0, () => {
      const duck: PetSpecies | undefined = PetCatalog.find('duck');
      expect(duck === undefined ? -1 : duck.stages[0].face.cx).assertEqual(0);
      expect(duck === undefined ? true : duck.stages[0].face.single).assertFalse();
    });

    // 没写 face 的阶段继承物种的 face
    it('stageInheritsSpeciesFaceWhenAbsent', 0, () => {
      const duck: PetSpecies | undefined = PetCatalog.find('duck');
      expect(duck === undefined ? -1 : duck.stages[1].face.cx).assertEqual(14);
      expect(duck === undefined ? false : duck.stages[1].face.single).assertTrue();
    });

    // 物种也没写 face 时用默认正面脸型（两眼、非侧脸）
    it('speciesWithoutFaceUsesDefaultFront', 0, () => {
      const berry: PetSpecies | undefined = PetCatalog.find('berry');
      expect(berry === undefined ? true : berry.stages[0].face.single).assertFalse();
      expect(berry === undefined ? -1 : berry.stages[0].face.eyeDx).assertEqual(9.6);
    });

    it('stageCarriesImageAndScaleToState', 0, () => {
      const duck: PetSpecies | undefined = PetCatalog.find('duck');
      if (duck === undefined) {
        expect(false).assertTrue();
        return;
      }
      const state: PetState = PetEngine.evaluate(0, 0, false, 0, 10, duck);
      expect(state.stageName).assertEqual('小鸭');
      expect(state.imagePath).assertEqual('pets/duck_2.svg');
      expect(state.stageScale).assertEqual(0.85);
      expect(state.stageCount).assertEqual(3);
    });

    it('unknownCodeReturnsUndefined', 0, () => {
      expect(PetCatalog.find('not_a_species') === undefined).assertTrue();
    });

    it('defaultCodeIsFirstSpecies', 0, () => {
      expect(PetCatalog.defaultCode()).assertEqual('duck');
      expect(PetCatalog.indexOf('berry')).assertEqual(1);
      expect(PetCatalog.indexOf('nope')).assertEqual(-1);
    });
  });
}
