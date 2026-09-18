import { MealType } from '../model/Enums';
import { PetSpecies, PetSpeciesCatalog } from '../model/PetSpecies';

/** 成长阶段 */
export enum PetStage {
  EGG = 0,
  BABY = 1,
  GROWING = 2,
  ADULT = 3
}

/** 表情，由三项状态的平均值决定 */
export enum PetExpression {
  SAD = 0,
  NORMAL = 1,
  HAPPY = 2
}

export class PetState {
  /** 当前物种编码，视图据此决定画什么 */
  speciesCode: string = PetSpeciesCatalog.defaultCode();
  stage: number = PetStage.EGG;
  stageName: string = '';
  expression: number = PetExpression.NORMAL;

  /** 三项状态，取值 0-100 */
  fullness: number = 0;
  vitality: number = 0;
  mood: number = 0;

  /** 累计记录天数，也就是宠物的"年龄" */
  growDays: number = 0;
  /** 距离下一阶段还差几天；已到最高阶段为 0 */
  daysToNextStage: number = 0;
  isMaxStage: boolean = false;

  /** 宠物说的一句话，直接显示在卡片上 */
  message: string = '';
}

/** 把任意值压到 0-1 */
function clamp01(value: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}

/**
 * 宠物成长引擎。纯函数，无系统依赖，可直接用本地单元测试覆盖。
 *
 * 核心设计：**把"照顾宠物"和"健康打卡"做成同一件事**。
 * 不引入喂食、清洁这类独立玩法——那会变成第二个要维护的系统，
 * 而且和应用的真正目的（坚持记录）脱钩。这里宠物的三项状态全部直接来自
 * 用户当天的真实记录：
 *
 *   饱食 ← 早餐/午餐/晚餐记录了几餐
 *   活力 ← 是否有运动（满 20 分钟算满分）+ 饮水是否达标
 *   心情 ← 连续打卡天数
 *
 * 于是"想让宠物状态好"和"想坚持健康习惯"就是同一个动作，激励不需要额外解释。
 */
export class PetEngine {
  /** 各阶段所需的累计记录天数 */
  static readonly STAGE_THRESHOLDS: number[] = [0, 3, 7, 30];

  /** 运动满多少分钟算活力满分的一半 */
  static readonly ACTIVITY_FULL_MIN: number = 20;
  /** 连续多少天算心情满分 */
  static readonly MOOD_FULL_DAYS: number = 7;
  /** 三项状态都高于这个值时才说鼓励的话 */
  static readonly GOOD_THRESHOLD: number = 80;

  /** 一天的主餐数（早/午/晚），加餐不计入饱食 */
  static countMainMeals(mealTypes: number[]): number {
    let count: number = 0;
    for (const mealType of mealTypes) {
      if (mealType === MealType.BREAKFAST || mealType === MealType.LUNCH
        || mealType === MealType.DINNER) {
        count++;
      }
    }
    return count;
  }

  static evaluate(mainMealCount: number, activityMin: number, waterDone: boolean,
    streakDays: number, growDays: number, species?: PetSpecies): PetState {
    const target: PetSpecies = species === undefined
      ? PetSpeciesCatalog.find(PetSpeciesCatalog.defaultCode())
      : species;

    const state: PetState = new PetState();
    state.speciesCode = target.code;
    state.growDays = growDays;

    state.fullness = clamp01(mainMealCount / 3) * 100;
    state.vitality = clamp01(activityMin / PetEngine.ACTIVITY_FULL_MIN) * 50 + (waterDone ? 50 : 0);
    state.mood = clamp01(streakDays / PetEngine.MOOD_FULL_DAYS) * 100;

    let stage: number = 0;
    for (let i = 0; i < PetEngine.STAGE_THRESHOLDS.length; i++) {
      if (growDays >= PetEngine.STAGE_THRESHOLDS[i]) {
        stage = i;
      }
    }
    // 不经历蛋阶段的物种（水果）直接从小果起步。
    // 写在这里而不是改门槛数组，是因为"门槛"描述的是天数和阶段的关系，
    // 而"有没有蛋"是物种本身的属性，两件事不该混在一起。
    if (!target.hasEgg && stage === PetStage.EGG) {
      stage = PetStage.BABY;
    }

    state.stage = stage;
    state.stageName = target.stageNames[stage];
    state.isMaxStage = stage === PetEngine.STAGE_THRESHOLDS.length - 1;
    state.daysToNextStage =
      state.isMaxStage ? 0 : PetEngine.STAGE_THRESHOLDS[stage + 1] - growDays;

    const average: number = (state.fullness + state.vitality + state.mood) / 3;
    if (average >= 70) {
      state.expression = PetExpression.HAPPY;
    } else if (average >= 35) {
      state.expression = PetExpression.NORMAL;
    } else {
      state.expression = PetExpression.SAD;
    }

    state.message = PetEngine.buildMessage(state);
    return state;
  }

  /**
   * 宠物台词。优先给"最欠缺的那一项"提示，因为用户最需要的是一条可执行的建议，
   * 而不是一句笼统的加油。
   */
  private static buildMessage(state: PetState): string {
    if (state.stage === PetStage.EGG) {
      return `再记录 ${state.daysToNextStage} 天就能孵化了`;
    }

    const lowest: number = Math.min(state.fullness, Math.min(state.vitality, state.mood));
    if (lowest >= PetEngine.GOOD_THRESHOLD) {
      return '今天把我照顾得很好，继续保持';
    }
    // 每个分支都要同时比另外两项，否则并列时（比如饱食与活力都是满分）
    // 会把真正最低的那项漏掉
    if (state.fullness <= state.vitality && state.fullness <= state.mood) {
      return '肚子有点饿了，记一餐吧';
    }
    if (state.vitality <= state.fullness && state.vitality <= state.mood) {
      return '想活动一下，陪我动一动？';
    }
    return '好久没一起打卡了，别断呀';
  }
}
