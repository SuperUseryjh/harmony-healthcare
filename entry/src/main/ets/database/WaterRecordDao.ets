import { relationalStore } from '@kit.ArkData';
import { WaterRecord } from '../model/WaterRecord';
import { DbHelper } from './DbHelper';

const TABLE: string = 'water_record';
const COLUMNS: string[] = ['id', 'record_date', 'amount_ml', 'created_at'];

/** 饮水记录 DAO */
export class WaterRecordDao {

  private static map(rs: relationalStore.ResultSet): WaterRecord {
    const record: WaterRecord = new WaterRecord();
    record.id = rs.getLong(rs.getColumnIndex('id'));
    record.recordDate = rs.getString(rs.getColumnIndex('record_date'));
    record.amountMl = rs.getLong(rs.getColumnIndex('amount_ml'));
    record.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
    return record;
  }

  private static toBucket(record: WaterRecord): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'record_date': record.recordDate,
      'amount_ml': record.amountMl,
      'created_at': record.createdAt
    };
    return bucket;
  }

  static async insert(record: WaterRecord): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    return await store.insert(TABLE, WaterRecordDao.toBucket(record));
  }

  static async queryByDate(dateKey: string): Promise<WaterRecord[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('record_date', dateKey);
    predicates.orderByAsc('created_at');
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    const list: WaterRecord[] = [];
    while (rs.goToNextRow()) {
      list.push(WaterRecordDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 某日饮水合计（ml） */
  static async sumByDate(dateKey: string): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT IFNULL(SUM(amount_ml), 0) AS ml FROM ${TABLE} WHERE record_date = ?`;
    const args: relationalStore.ValueType[] = [dateKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    let ml: number = 0;
    if (rs.goToFirstRow()) {
      ml = rs.getDouble(rs.getColumnIndex('ml'));
    }
    rs.close();
    return ml;
  }

  /** 撤销最近一次饮水记录，返回被撤销的毫升数 */
  static async deleteLatestOfDate(dateKey: string): Promise<number> {
    const records: WaterRecord[] = await WaterRecordDao.queryByDate(dateKey);
    if (records.length === 0) {
      return 0;
    }
    const last: WaterRecord = records[records.length - 1];
    await WaterRecordDao.deleteById(last.id);
    return last.amountMl;
  }

  static async deleteById(id: number): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    return await store.delete(predicates);
  }
}
