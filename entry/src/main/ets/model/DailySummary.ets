import { BitFlags, CHECKIN_ITEM_COUNT, CheckinBit } from './Enums';

/**
 * 每日汇总（物化表）。
 *
 * 明细表（meal_record / activity_record / water_record）是数据的真实来源，
 * 这张表是它们的聚合结果。每次打卡写入后由 Service 层重算，看板页只读这一张表，
 * 避免每次打开首页都去扫全量明细。
 */
export class DailySummary {
  /** 'YYYY-MM-DD'，主键 */
  recordDate: string = '';
  intakeKcal: number = 0;
  burnedKcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  waterMl: number = 0;
  activityMin: number = 0;
  /** CheckinBit 的位或 */
  checkinFlags: number = 0;
  /** 健康分 0-100 */
  score: number = 0;
  /** 当日结束时的连续打卡天数 */
  streakDays: number = 0;

  /** 净热量：摄入 − 消耗 */
  netKcal(): number {
    return this.intakeKcal - this.burnedKcal;
  }

  /** 已完成的打卡项数 */
  completedCheckinCount(): number {
    return BitFlags.count(this.checkinFlags, CheckinBit.BREAKFAST | CheckinBit.LUNCH | CheckinBit.DINNER |
      CheckinBit.ACTIVITY | CheckinBit.WATER | CheckinBit.ROUTINE);
  }

  /** 打卡完成度 0-1 */
  checkinRatio(): number {
    return this.completedCheckinCount() / CHECKIN_ITEM_COUNT;
  }

  /** 三大营养素合计热量（用于配比分析） */
  macroKcal(): number {
    return this.proteinG * 4 + this.carbG * 4 + this.fatG * 9;
  }
}
