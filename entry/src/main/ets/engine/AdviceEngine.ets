import { MacroDistribution, NutritionAnalyzer } from './NutritionAnalyzer';
import { MacroRatio } from './EnergyCalculator';

/** 一条建议 */
export class AdviceItem {
  /** 规则代号，便于埋点与测试断言 */
  code: string = '';
  text: string = '';
  /** 0 = 提示，1 = 需要留意 */
  severity: number = 0;
}

/** 建议生成所需的上下文 */
export class AdviceContext {
  intakeKcal: number = 0;
  burnedKcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  waterMl: number = 0;
  activityMin: number = 0;
  targetKcal: number = 0;
  targetProteinG: number = 0;
  targetFatG: number = 0;
  targetCarbG: number = 0;
  targetWaterMl: number = 0;
  /** 当前小时 0-23，用于判断时段相关的建议 */
  currentHour: number = 12;
  streakDays: number = 0;
}

/**
 * 建议引擎。
 *
 * 这是一套**规则库**，不是模型推理：按固定优先级依次匹配，取前若干条输出。
 * 优先级设计原则是「先纠正明显问题，再谈锦上添花」，
 * 同时把依赖时段的规则（喝水、运动）放到晚上才触发，避免白天唠叨。
 */
export class AdviceEngine {
  static readonly SEVERITY_INFO: number = 0;
  static readonly SEVERITY_WARN: number = 1;

  /** 热量超标判定阈值：超过目标的 15% */
  static readonly OVER_INTAKE_TOLERANCE: number = 0.15;
  /** 热量严重不足判定阈值：低于目标的 60% */
  static readonly UNDER_INTAKE_THRESHOLD: number = 0.6;
  /** 营养素占比偏离容忍度 */
  static readonly MACRO_TOLERANCE: number = 0.3;
  /** 晚间喝水不足阈值（ml） */
  static readonly WATER_LOW_ML: number = 1200;
  /** 喝水量开始提醒的小时 */
  static readonly WATER_REMIND_HOUR: number = 18;
  /** 运动/进食不足开始提醒的小时 */
  static readonly EVENING_REMIND_HOUR: number = 20;
  /** 连续打卡值得表扬的天数 */
  static readonly STREAK_PRAISE_DAYS: number = 7;

  /**
   * 生成建议。
   * @param ctx 当日数据与目标
   * @param maxCount 最多返回几条，默认 3
   */
  static generate(ctx: AdviceContext, maxCount: number = 3): AdviceItem[] {
    const result: AdviceItem[] = [];

    // 未完成引导时无法做任何定量分析，只给一条引导
    if (ctx.targetKcal <= 0) {
      result.push(AdviceEngine.make('PROFILE_MISSING', '先完善个人资料，才能算出适合你的热量目标', AdviceEngine.SEVERITY_INFO));
      return result;
    }

    // 1. 热量超标
    if (NutritionAnalyzer.isOverIntake(ctx.intakeKcal, ctx.targetKcal, AdviceEngine.OVER_INTAKE_TOLERANCE)) {
      result.push(AdviceEngine.make('OVER_INTAKE', '今天热量超了，晚上可以只吃点蔬菜和蛋白质', AdviceEngine.SEVERITY_WARN));
    }

    // 2. 晚间摄入严重不足
    if (ctx.currentHour >= AdviceEngine.EVENING_REMIND_HOUR &&
      NutritionAnalyzer.isUnderIntake(ctx.intakeKcal, ctx.targetKcal, AdviceEngine.UNDER_INTAKE_THRESHOLD)) {
      result.push(AdviceEngine.make('UNDER_INTAKE', '今天吃得太少了，长期低于基础代谢会掉肌肉', AdviceEngine.SEVERITY_WARN));
    }

    // 3-5. 营养素配比：仅在有有效摄入数据时才判断，否则空数据会误触发
    const actual: MacroDistribution = NutritionAnalyzer.distribution(ctx.proteinG, ctx.fatG, ctx.carbG);
    const targetRatio: MacroRatio = NutritionAnalyzer.targetRatioFromGrams(
      ctx.targetProteinG, ctx.targetFatG, ctx.targetCarbG);
    if (actual.totalKcal > 0 && targetRatio.protein > 0) {
      if (actual.protein < targetRatio.protein * (1 - AdviceEngine.MACRO_TOLERANCE)) {
        result.push(AdviceEngine.make('PROTEIN_LOW', '蛋白质摄入偏少，加个鸡蛋或一份鸡胸', AdviceEngine.SEVERITY_INFO));
      }
      if (actual.fat > targetRatio.fat * (1 + AdviceEngine.MACRO_TOLERANCE)) {
        result.push(AdviceEngine.make('FAT_HIGH', '脂肪偏高了，明天少点油炸和红烧类', AdviceEngine.SEVERITY_WARN));
      }
      if (actual.carb > targetRatio.carb * (1 + AdviceEngine.MACRO_TOLERANCE)) {
        result.push(AdviceEngine.make('CARB_HIGH', '主食偏多，可以把一半米饭换成杂粮或蔬菜', AdviceEngine.SEVERITY_INFO));
      }
    }

    // 6. 晚间喝水不足
    if (ctx.currentHour >= AdviceEngine.WATER_REMIND_HOUR && ctx.waterMl < AdviceEngine.WATER_LOW_ML) {
      result.push(AdviceEngine.make('WATER_LOW', '今天水喝得太少，睡前补两杯', AdviceEngine.SEVERITY_WARN));
    }

    // 7. 晚间还没运动
    if (ctx.currentHour >= AdviceEngine.EVENING_REMIND_HOUR && ctx.activityMin <= 0) {
      result.push(AdviceEngine.make('NO_ACTIVITY', '今天还没动，饭后散步 20 分钟也算', AdviceEngine.SEVERITY_INFO));
    }

    // 8. 连续打卡鼓励
    if (ctx.streakDays >= AdviceEngine.STREAK_PRAISE_DAYS) {
      result.push(AdviceEngine.make('STREAK_PRAISE', `已经连续打卡 ${ctx.streakDays} 天了，保持住`, AdviceEngine.SEVERITY_INFO));
    }

    // 9. 兜底
    if (result.length === 0) {
      result.push(AdviceEngine.make('ALL_GOOD', '今天的节奏保持得不错，继续加油', AdviceEngine.SEVERITY_INFO));
    }

    return result.length > maxCount ? result.slice(0, maxCount) : result;
  }

  private static make(code: string, text: string, severity: number): AdviceItem {
    const item: AdviceItem = new AdviceItem();
    item.code = code;
    item.text = text;
    item.severity = severity;
    return item;
  }
}
