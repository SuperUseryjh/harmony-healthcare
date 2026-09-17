import { relationalStore } from '@kit.ArkData';
import { CheckinStreak } from '../model/CheckinStreak';
import { DbHelper } from './DbHelper';

const TABLE: string = 'checkin_streak';
const COLUMNS: string[] = ['record_date', 'completed_items', 'is_broken', 'repair_used'];

/** 连续打卡状态 DAO。按天一行，记录当天的完成度与是否断卡/补签 */
export class CheckinStreakDao {

  private static map(rs: relationalStore.ResultSet): CheckinStreak {
    const streak: CheckinStreak = new CheckinStreak();
    streak.recordDate = rs.getString(rs.getColumnIndex('record_date'));
    streak.completedItems = rs.getLong(rs.getColumnIndex('completed_items'));
    streak.isBroken = rs.getLong(rs.getColumnIndex('is_broken'));
    streak.repairUsed = rs.getLong(rs.getColumnIndex('repair_used'));
    return streak;
  }

  private static toBucket(streak: CheckinStreak): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'record_date': streak.recordDate,
      'completed_items': streak.completedItems,
      'is_broken': streak.isBroken,
      'repair_used': streak.repairUsed
    };
    return bucket;
  }

  static async save(streak: CheckinStreak): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    await store.insert(TABLE, CheckinStreakDao.toBucket(streak),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  static async get(dateKey: string): Promise<CheckinStreak | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('record_date', dateKey);
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    let streak: CheckinStreak | undefined = undefined;
    if (rs.goToFirstRow()) {
      streak = CheckinStreakDao.map(rs);
    }
    rs.close();
    return streak;
  }

  /** 查询区间内状态，按日期倒序（便于从今天往前回溯连续天数） */
  static async queryRangeDesc(startKey: string, endKey: string): Promise<CheckinStreak[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT * FROM ${TABLE} WHERE record_date >= ? AND record_date <= ?
      ORDER BY record_date DESC`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: CheckinStreak[] = [];
    while (rs.goToNextRow()) {
      list.push(CheckinStreakDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 从今天起往前回溯，统计连续未断卡的天数 */
  static async currentStreak(todayKey: string, lookbackDays: number): Promise<number> {
    const startKey: string = CheckinStreakDao.shiftDays(todayKey, -(lookbackDays - 1));
    const records: CheckinStreak[] = await CheckinStreakDao.queryRangeDesc(startKey, todayKey);
    const brokenSet: Set<string> = new Set<string>();
    for (const record of records) {
      if (record.isBroken === 1) {
        brokenSet.add(record.recordDate);
      }
    }

    let streak: number = 0;
    for (let i = 0; i < lookbackDays; i++) {
      const key: string = CheckinStreakDao.shiftDays(todayKey, -i);
      if (brokenSet.has(key)) {
        break;
      }
      streak++;
    }
    return streak;
  }

  /** 使用一次补签：把某天标记为未断卡 */
  static async repair(dateKey: string): Promise<void> {
    const existing: CheckinStreak | undefined = await CheckinStreakDao.get(dateKey);
    const streak: CheckinStreak = existing === undefined ? new CheckinStreak() : existing;
    streak.recordDate = dateKey;
    streak.isBroken = 0;
    streak.repairUsed = 1;
    await CheckinStreakDao.save(streak);
  }

  /** 是否用过补签 */
  static async hasUsedRepair(): Promise<boolean> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT COUNT(*) AS c FROM ${TABLE} WHERE repair_used = 1`;
    const rs: relationalStore.ResultSet = await store.querySql(sql);
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return count > 0;
  }

  /** 'YYYY-MM-DD' 偏移若干天。此处不引入 DateUtils，保持 DAO 只依赖数据库语义 */
  private static shiftDays(key: string, days: number): string {
    const parts: string[] = key.split('-');
    const base: number = new Date(Number.parseInt(parts[0], 10), Number.parseInt(parts[1], 10) - 1,
      Number.parseInt(parts[2], 10)).getTime();
    const shifted: Date = new Date(base + days * 86400000);
    const m: number = shifted.getMonth() + 1;
    const d: number = shifted.getDate();
    return `${shifted.getFullYear()}-${m < 10 ? '0' : ''}${m}-${d < 10 ? '0' : ''}${d}`;
  }
}
