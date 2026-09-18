import { EnergyCalculator } from '../engine/EnergyCalculator';
import { UserProfile } from '../model/UserProfile';
import { UserProfileDao } from '../database/UserProfileDao';
import { CheckinService } from '../service/CheckinService';

/**
 * 运动录入的视图模型。
 *
 * 消耗量走 engine 层已有的 MET 公式，这里不重复实现；服务层只负责落库与重算汇总。
 */
export class ActivityCheckinViewModel {

  /** 预估消耗（kcal）。体重未知时返回 0，界面据此提示先完善档案 */
  static estimateKcal(weightKg: number, activityType: number,
    minutes: number, intensity: number): number {
    return EnergyCalculator.calcExerciseKcal(activityType, weightKg, minutes, intensity);
  }

  /** 取当前体重；未完成引导时返回 0 */
  static async currentWeightKg(): Promise<number> {
    const profile: UserProfile | undefined = await UserProfileDao.get();
    return profile === undefined ? 0 : profile.weightKg;
  }

  /** 记录一次运动 */
  static async commit(dateKey: string, activityType: number, minutes: number,
    intensity: number, kcalBurned: number): Promise<void> {
    await CheckinService.addActivity(dateKey, activityType, minutes, intensity, kcalBurned);
  }
}
