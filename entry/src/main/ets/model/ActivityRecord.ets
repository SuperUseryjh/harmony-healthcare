import { Intensity } from './Enums';

/** 运动记录 */
export class ActivityRecord {
  id: number = 0;
  /** 'YYYY-MM-DD' */
  recordDate: string = '';
  /** ActivityType 取值 */
  activityType: number = 0;
  durationMin: number = 0;
  /** Intensity 取值 */
  intensity: number = Intensity.MEDIUM;
  kcalBurned: number = 0;
  createdAt: number = 0;
}
