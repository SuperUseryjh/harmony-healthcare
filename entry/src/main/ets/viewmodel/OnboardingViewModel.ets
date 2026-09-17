import { ActivityLevel, Gender, Goal } from '../model/Enums';
import { UserProfile } from '../model/UserProfile';
import { UserProfileDao } from '../database/UserProfileDao';
import { MacroTarget, EnergyCalculator } from '../engine/EnergyCalculator';

/** 引导页的表单草稿 */
export class OnboardingDraft {
  gender: number = Gender.FEMALE;
  age: number = 22;
  heightCm: number = 165;
  weightKg: number = 55;
  activityLevel: number = ActivityLevel.LIGHT;
  goal: number = Goal.KEEP;
}

/** 表单实时预览出来的目标值 */
export class OnboardingPreview {
  bmr: number = 0;
  tdee: number = 0;
  targetKcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  waterMl: number = 0;
}

/**
 * 引导页的视图模型。
 *
 * 这里把 engine 层的公式直接暴露成"边填边算"的预览——
 * 用户拖动体重滑块就能看到目标热量在变，比填完再跳转更能让人理解这些数字怎么来的。
 */
export class OnboardingViewModel {

  /** 依据草稿算出一份预览，用于表单实时展示 */
  static preview(draft: OnboardingDraft): OnboardingPreview {
    const bmr: number = EnergyCalculator.calcBmr(
      draft.gender, draft.weightKg, draft.heightCm, draft.age);
    const tdee: number = EnergyCalculator.calcTdee(bmr, draft.activityLevel);
    const targetKcal: number = EnergyCalculator.calcTargetIntake(tdee, bmr, draft.goal);
    const macro: MacroTarget = EnergyCalculator.calcMacroTarget(targetKcal, draft.goal);

    const preview: OnboardingPreview = new OnboardingPreview();
    preview.bmr = bmr;
    preview.tdee = tdee;
    preview.targetKcal = targetKcal;
    preview.proteinG = macro.proteinG;
    preview.fatG = macro.fatG;
    preview.carbG = macro.carbG;
    preview.waterMl = EnergyCalculator.calcWaterTargetMl(draft.weightKg);
    return preview;
  }

  /** 保存档案。年龄会换算成出生年份以匹配表结构 */
  static async save(draft: OnboardingDraft): Promise<void> {
    const nowYear: number = new Date(Date.now()).getFullYear();
    const profile: UserProfile = new UserProfile();
    profile.gender = draft.gender;
    profile.birthYear = nowYear - draft.age;
    profile.heightCm = draft.heightCm;
    profile.weightKg = draft.weightKg;
    profile.activityLevel = draft.activityLevel;
    profile.goal = draft.goal;
    profile.targetWeightKg = draft.weightKg;
    profile.updatedAt = Date.now();
    await UserProfileDao.save(profile);
  }
}
