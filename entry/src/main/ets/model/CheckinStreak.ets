/** 连续打卡状态，按天一行 */
export class CheckinStreak {
  /** 'YYYY-MM-DD'，主键 */
  recordDate: string = '';
  completedItems: number = 0;
  /** 1 表示这一天断了（未达成当日最低打卡要求） */
  isBroken: number = 0;
  /** 1 表示这一天是靠补签救回来的 */
  repairUsed: number = 0;
}
