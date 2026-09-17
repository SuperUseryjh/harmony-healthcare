import { EnergyCalculator, MacroTarget } from '../engine/EnergyCalculator';
import { UserProfile } from '../model/UserProfile';

/** 一天的目标值，由用户档案推导，不落库 */
export class DailyPlan {
  /** 目标摄入热量（kcal） */
  targetKcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  /** 目标饮水量（ml） */
  waterMl: number = 0;
}

/**
 * 每日计划服务：把用户档案换算成可执行的目标。
 *
 * 之所以单独成层而不是塞进 DAO 或页面里，是因为"档案 → 目标"这条换算
 * 在首页、分析页、建议引擎里都要用，必须只有一份实现。
 */
export class PlanService {

  /** 由档案推导每日目标 */
  static build(profile: UserProfile, nowYear: number): DailyPlan {
    const age: number = profile.age(nowYear);
    const bmr: number = EnergyCalculator.calcBmr(
      profile.gender, profile.weightKg, profile.heightCm, age);
    const tdee: number = EnergyCalculator.calcTdee(bmr, profile.activityLevel);
    const targetKcal: number = EnergyCalculator.calcTargetIntake(tdee, bmr, profile.goal);
    const macro: MacroTarget = EnergyCalculator.calcMacroTarget(targetKcal, profile.goal);

    const plan: DailyPlan = new DailyPlan();
    plan.targetKcal = targetKcal;
    plan.proteinG = macro.proteinG;
    plan.fatG = macro.fatG;
    plan.carbG = macro.carbG;
    plan.waterMl = EnergyCalculator.calcWaterTargetMl(profile.weightKg);
    return plan;
  }
}
