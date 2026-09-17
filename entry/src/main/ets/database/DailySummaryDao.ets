import { relationalStore } from '@kit.ArkData';
import { DailySummary } from '../model/DailySummary';
import { DbHelper } from './DbHelper';

const TABLE: string = 'daily_summary';
const COLUMNS: string[] = ['record_date', 'intake_kcal', 'burned_kcal', 'protein_g', 'fat_g',
  'carb_g', 'water_ml', 'activity_min', 'checkin_flags', 'score', 'streak_days'];

/** 每日汇总 DAO。record_date 为主键，写入时用 REPLACE 冲突策略实现 upsert */
export class DailySummaryDao {

  private static map(rs: relationalStore.ResultSet): DailySummary {
    const summary: DailySummary = new DailySummary();
    summary.recordDate = rs.getString(rs.getColumnIndex('record_date'));
    summary.intakeKcal = rs.getDouble(rs.getColumnIndex('intake_kcal'));
    summary.burnedKcal = rs.getDouble(rs.getColumnIndex('burned_kcal'));
    summary.proteinG = rs.getDouble(rs.getColumnIndex('protein_g'));
    summary.fatG = rs.getDouble(rs.getColumnIndex('fat_g'));
    summary.carbG = rs.getDouble(rs.getColumnIndex('carb_g'));
    summary.waterMl = rs.getDouble(rs.getColumnIndex('water_ml'));
    summary.activityMin = rs.getDouble(rs.getColumnIndex('activity_min'));
    summary.checkinFlags = rs.getLong(rs.getColumnIndex('checkin_flags'));
    summary.score = rs.getLong(rs.getColumnIndex('score'));
    summary.streakDays = rs.getLong(rs.getColumnIndex('streak_days'));
    return summary;
  }

  private static toBucket(summary: DailySummary): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'record_date': summary.recordDate,
      'intake_kcal': summary.intakeKcal,
      'burned_kcal': summary.burnedKcal,
      'protein_g': summary.proteinG,
      'fat_g': summary.fatG,
      'carb_g': summary.carbG,
      'water_ml': summary.waterMl,
      'activity_min': summary.activityMin,
      'checkin_flags': summary.checkinFlags,
      'score': summary.score,
      'streak_days': summary.streakDays
    };
    return bucket;
  }

  static async get(dateKey: string): Promise<DailySummary | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('record_date', dateKey);
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    let summary: DailySummary | undefined = undefined;
    if (rs.goToFirstRow()) {
      summary = DailySummaryDao.map(rs);
    }
    rs.close();
    return summary;
  }

  /** 新增或覆盖某日汇总 */
  static async save(summary: DailySummary): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    await store.insert(TABLE, DailySummaryDao.toBucket(summary),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  /** 查询 [startKey, endKey] 闭区间的汇总，按日期正序。缺失的日期不会补空行 */
  static async queryRange(startKey: string, endKey: string): Promise<DailySummary[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT * FROM ${TABLE} WHERE record_date >= ? AND record_date <= ?
      ORDER BY record_date ASC`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: DailySummary[] = [];
    while (rs.goToNextRow()) {
      list.push(DailySummaryDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 最近一条汇总的日期，用于跨天检测 */
  static async latestDateKey(): Promise<string | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT record_date FROM ${TABLE} ORDER BY record_date DESC LIMIT 1`;
    const rs: relationalStore.ResultSet = await store.querySql(sql);
    let key: string | undefined = undefined;
    if (rs.goToFirstRow()) {
      key = rs.getString(rs.getColumnIndex('record_date'));
    }
    rs.close();
    return key;
  }

  /** 历史最高连续天数，供成就展示使用 */
  static async maxStreakDays(): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT IFNULL(MAX(streak_days), 0) AS d FROM ${TABLE}`;
    const rs: relationalStore.ResultSet = await store.querySql(sql);
    let days: number = 0;
    if (rs.goToFirstRow()) {
      days = rs.getLong(rs.getColumnIndex('d'));
    }
    rs.close();
    return days;
  }

  /** 累计有记录的天数 */
  static async countDays(): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(`SELECT COUNT(*) AS c FROM ${TABLE}`);
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return count;
  }
}
