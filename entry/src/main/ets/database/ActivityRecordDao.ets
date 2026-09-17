import { relationalStore } from '@kit.ArkData';
import { ActivityRecord } from '../model/ActivityRecord';
import { DbHelper } from './DbHelper';

const TABLE: string = 'activity_record';
const COLUMNS: string[] = ['id', 'record_date', 'activity_type', 'duration_min', 'intensity',
  'kcal_burned', 'created_at'];

/** 运动记录 DAO */
export class ActivityRecordDao {

  private static map(rs: relationalStore.ResultSet): ActivityRecord {
    const record: ActivityRecord = new ActivityRecord();
    record.id = rs.getLong(rs.getColumnIndex('id'));
    record.recordDate = rs.getString(rs.getColumnIndex('record_date'));
    record.activityType = rs.getLong(rs.getColumnIndex('activity_type'));
    record.durationMin = rs.getLong(rs.getColumnIndex('duration_min'));
    record.intensity = rs.getLong(rs.getColumnIndex('intensity'));
    record.kcalBurned = rs.getDouble(rs.getColumnIndex('kcal_burned'));
    record.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
    return record;
  }

  private static toBucket(record: ActivityRecord): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'record_date': record.recordDate,
      'activity_type': record.activityType,
      'duration_min': record.durationMin,
      'intensity': record.intensity,
      'kcal_burned': record.kcalBurned,
      'created_at': record.createdAt
    };
    return bucket;
  }

  static async insert(record: ActivityRecord): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    return await store.insert(TABLE, ActivityRecordDao.toBucket(record));
  }

  static async queryByDate(dateKey: string): Promise<ActivityRecord[]> {
    return await ActivityRecordDao.queryRange(dateKey, dateKey);
  }

  static async queryRange(startKey: string, endKey: string): Promise<ActivityRecord[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT * FROM ${TABLE} WHERE record_date >= ? AND record_date <= ?
      ORDER BY record_date ASC, created_at ASC`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: ActivityRecord[] = [];
    while (rs.goToNextRow()) {
      list.push(ActivityRecordDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 某日运动消耗合计（kcal） */
  static async sumBurnedByDate(dateKey: string): Promise<number> {
    return await ActivityRecordDao.sumBurnedRange(dateKey, dateKey);
  }

  /** 区间运动消耗合计（kcal） */
  static async sumBurnedRange(startKey: string, endKey: string): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT IFNULL(SUM(kcal_burned), 0) AS kcal FROM ${TABLE}
      WHERE record_date >= ? AND record_date <= ?`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    let kcal: number = 0;
    if (rs.goToFirstRow()) {
      kcal = rs.getDouble(rs.getColumnIndex('kcal'));
    }
    rs.close();
    return kcal;
  }

  /** 某日运动时长合计（分钟） */
  static async sumMinutesByDate(dateKey: string): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT IFNULL(SUM(duration_min), 0) AS minutes FROM ${TABLE}
      WHERE record_date = ?`;
    const args: relationalStore.ValueType[] = [dateKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    let minutes: number = 0;
    if (rs.goToFirstRow()) {
      minutes = rs.getDouble(rs.getColumnIndex('minutes'));
    }
    rs.close();
    return minutes;
  }

  static async deleteById(id: number): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await store.delete(predicates);
  }

  static async countAll(): Promise<number> {
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
