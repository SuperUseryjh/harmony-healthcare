import { CheckinStreak } from '../model/CheckinStreak';
import { CheckinStreakDao } from '../database/CheckinStreakDao';
import { DateUtils } from '../utils/DateUtils';

/**
 * 连续打卡服务。
 *
 * 这里的核心是**断卡判定规则**，它直接决定养成机制公不公平：
 *
 * - 当天尚未结束，即使一项都没打卡也**不判定为断卡**。否则用户早上打开应用
 *   就会看到"连续天数已归零"，体验很糟。
 * - 历史某天若未达标（完成项数 < MIN_ITEMS），才算断卡。
 * - 达标线设为 2 项而不是 6 项全勤：全勤要求过高会让大多数人第二天就放弃，
 *   而"至少做两件事"是可持续的门槛。
 */
export class StreakService {
  /** 当日达标所需的最少打卡项数 */
  static readonly MIN_ITEMS: number = 2;
  /** 回溯上限，避免逐日查询无边界 */
  static readonly LOOKBACK_DAYS: number = 180;

  /**
   * 写入某日的完成情况，并返回截至该日的连续天数。
   * 每次打卡后调用。
   */
  static async update(dateKey: string, completedItems: number): Promise<number> {
    const existing: CheckinStreak | undefined = await CheckinStreakDao.get(dateKey);
    const record: CheckinStreak = existing === undefined ? new CheckinStreak() : existing;
    record.recordDate = dateKey;
    record.completedItems = completedItems;
    // 今天不算断卡（还没结束），过去的日子未达标才算断
    const isPastDay: boolean = !DateUtils.isToday(dateKey);
    record.isBroken = (isPastDay && completedItems < StreakService.MIN_ITEMS) ? 1 : 0;
    await CheckinStreakDao.save(record);

    return await StreakService.currentStreak(dateKey);
  }

  /**
   * 从今天往前数连续达标的天数。
   * 今天若还没达标，则从昨天开始数——避免"凌晨打开应用看到 0 天"。
   */
  static async currentStreak(todayKey: string): Promise<number> {
    let offset: number = 0;
    const todayRecord: CheckinStreak | undefined = await CheckinStreakDao.get(todayKey);
    if (todayRecord === undefined || todayRecord.completedItems < StreakService.MIN_ITEMS) {
      offset = 1;
    }

    let streak: number = 0;
    for (let i = offset; i < StreakService.LOOKBACK_DAYS; i++) {
      const key: string = DateUtils.addDays(todayKey, -i);
      const record: CheckinStreak | undefined = await CheckinStreakDao.get(key);
      if (record === undefined || record.completedItems < StreakService.MIN_ITEMS) {
        break;
      }
      streak++;
    }
    return streak;
  }
}
