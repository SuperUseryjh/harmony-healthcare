import { ActivityLevel, Gender, Goal } from './Enums';

/**
 * 用户档案。表中固定只有一行，id 恒为 1。
 * 这份数据是所有热量与营养目标的输入源。
 */
export class UserProfile {
  id: number = 1;
  nickname: string = '';
  gender: number = Gender.UNKNOWN;
  birthYear: number = 2000;
  heightCm: number = 170;
  weightKg: number = 60;
  activityLevel: number = ActivityLevel.LIGHT;
  goal: number = Goal.KEEP;
  targetWeightKg: number = 60;
  updatedAt: number = 0;

  /** 按当前年份推算年龄，用于 BMR 公式 */
  age(nowYear: number): number {
    const age: number = nowYear - this.birthYear;
    return age > 0 ? age : 0;
  }
}
