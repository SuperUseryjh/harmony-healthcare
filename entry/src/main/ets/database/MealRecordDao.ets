import { relationalStore } from '@kit.ArkData';
import { MealRecord } from '../model/MealRecord';
import { NutritionTotals } from '../model/Totals';
import { DbHelper } from './DbHelper';

const TABLE: string = 'meal_record';
const COLUMNS: string[] = ['id', 'record_date', 'meal_type', 'scene', 'food_id', 'food_name',
  'amount', 'kcal', 'protein_g', 'fat_g', 'carb_g', 'created_at'];

/** 用餐记录 DAO */
export class MealRecordDao {

  private static map(rs: relationalStore.ResultSet): MealRecord {
    const record: MealRecord = new MealRecord();
    record.id = rs.getLong(rs.getColumnIndex('id'));
    record.recordDate = rs.getString(rs.getColumnIndex('record_date'));
    record.mealType = rs.getLong(rs.getColumnIndex('meal_type'));
    record.scene = rs.getLong(rs.getColumnIndex('scene'));
    record.foodId = rs.getLong(rs.getColumnIndex('food_id'));
    record.foodName = rs.getString(rs.getColumnIndex('food_name'));
    record.amount = rs.getDouble(rs.getColumnIndex('amount'));
    record.kcal = rs.getDouble(rs.getColumnIndex('kcal'));
    record.proteinG = rs.getDouble(rs.getColumnIndex('protein_g'));
    record.fatG = rs.getDouble(rs.getColumnIndex('fat_g'));
    record.carbG = rs.getDouble(rs.getColumnIndex('carb_g'));
    record.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
    return record;
  }

  private static toBucket(record: MealRecord): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'record_date': record.recordDate,
      'meal_type': record.mealType,
      'scene': record.scene,
      'food_id': record.foodId,
      'food_name': record.foodName,
      'amount': record.amount,
      'kcal': record.kcal,
      'protein_g': record.proteinG,
      'fat_g': record.fatG,
      'carb_g': record.carbG,
      'created_at': record.createdAt
    };
    return bucket;
  }

  /** 插入一条用餐记录，营养值应为调用方算好的快照 */
  static async insert(record: MealRecord): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    return await store.insert(TABLE, MealRecordDao.toBucket(record));
  }

  static async queryByDate(dateKey: string): Promise<MealRecord[]> {
    return await MealRecordDao.queryRange(dateKey, dateKey);
  }

  /** 查询 [startKey, endKey] 闭区间内的记录，按时间正序 */
  static async queryRange(startKey: string, endKey: string): Promise<MealRecord[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT * FROM ${TABLE} WHERE record_date >= ? AND record_date <= ?
      ORDER BY record_date ASC, created_at ASC`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: MealRecord[] = [];
    while (rs.goToNextRow()) {
      list.push(MealRecordDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 某日营养合计 */
  static async sumByDate(dateKey: string): Promise<NutritionTotals> {
    return await MealRecordDao.sumRange(dateKey, dateKey);
  }

  /** 区间营养合计 */
  static async sumRange(startKey: string, endKey: string): Promise<NutritionTotals> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT IFNULL(SUM(kcal), 0) AS kcal,
      IFNULL(SUM(protein_g), 0) AS protein_g,
      IFNULL(SUM(fat_g), 0) AS fat_g,
      IFNULL(SUM(carb_g), 0) AS carb_g
      FROM ${TABLE} WHERE record_date >= ? AND record_date <= ?`;
    const args: relationalStore.ValueType[] = [startKey, endKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);

    const totals: NutritionTotals = new NutritionTotals();
    if (rs.goToFirstRow()) {
      totals.kcal = rs.getDouble(rs.getColumnIndex('kcal'));
      totals.proteinG = rs.getDouble(rs.getColumnIndex('protein_g'));
      totals.fatG = rs.getDouble(rs.getColumnIndex('fat_g'));
      totals.carbG = rs.getDouble(rs.getColumnIndex('carb_g'));
    }
    rs.close();
    return totals;
  }

  /** 某日有记录的餐次集合（用于判断早餐/午餐/晚餐是否已打卡） */
  static async mealTypesOfDate(dateKey: string): Promise<number[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT DISTINCT meal_type FROM ${TABLE} WHERE record_date = ?`;
    const args: relationalStore.ValueType[] = [dateKey];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const types: number[] = [];
    while (rs.goToNextRow()) {
      types.push(rs.getLong(rs.getColumnIndex('meal_type')));
    }
    rs.close();
    return types;
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
