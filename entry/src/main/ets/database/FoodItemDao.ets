import { relationalStore } from '@kit.ArkData';
import { FoodItem } from '../model/FoodItem';
import { DbHelper } from './DbHelper';

const TABLE: string = 'food_item';
const COLUMNS: string[] = ['id', 'name', 'category', 'scene_flags', 'unit_name', 'unit_gram',
  'kcal_per_100g', 'protein_per_100g', 'fat_per_100g', 'carb_per_100g', 'is_custom'];

/** 场景化食物库 DAO */
export class FoodItemDao {

  private static map(rs: relationalStore.ResultSet): FoodItem {
    const item: FoodItem = new FoodItem();
    item.id = rs.getLong(rs.getColumnIndex('id'));
    item.name = rs.getString(rs.getColumnIndex('name'));
    item.category = rs.getLong(rs.getColumnIndex('category'));
    item.sceneFlags = rs.getLong(rs.getColumnIndex('scene_flags'));
    item.unitName = rs.getString(rs.getColumnIndex('unit_name'));
    item.unitGram = rs.getDouble(rs.getColumnIndex('unit_gram'));
    item.kcalPer100g = rs.getDouble(rs.getColumnIndex('kcal_per_100g'));
    item.proteinPer100g = rs.getDouble(rs.getColumnIndex('protein_per_100g'));
    item.fatPer100g = rs.getDouble(rs.getColumnIndex('fat_per_100g'));
    item.carbPer100g = rs.getDouble(rs.getColumnIndex('carb_per_100g'));
    item.isCustom = rs.getLong(rs.getColumnIndex('is_custom'));
    return item;
  }

  private static toBucket(item: FoodItem): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'name': item.name,
      'category': item.category,
      'scene_flags': item.sceneFlags,
      'unit_name': item.unitName,
      'unit_gram': item.unitGram,
      'kcal_per_100g': item.kcalPer100g,
      'protein_per_100g': item.proteinPer100g,
      'fat_per_100g': item.fatPer100g,
      'carb_per_100g': item.carbPer100g,
      'is_custom': item.isCustom
    };
    return bucket;
  }

  /**
   * 按场景 + 关键词查询食物。
   * @param scene SceneBit 取值；传 0 表示不限场景
   * @param keyword 名称模糊匹配；传空串表示不筛选
   * @param limit 返回条数上限
   */
  static async query(scene: number, keyword: string, limit: number): Promise<FoodItem[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const conditions: string[] = [];
    const args: relationalStore.ValueType[] = [];

    if (scene > 0) {
      conditions.push('(scene_flags & ?) != 0');
      args.push(scene);
    }
    if (keyword.length > 0) {
      conditions.push('name LIKE ?');
      args.push(`%${keyword}%`);
    }

    let sql: string = 'SELECT * FROM food_item';
    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    // 用户自建条目优先，其次按分类与录入顺序
    sql += ' ORDER BY is_custom DESC, category ASC, id ASC LIMIT ?';
    args.push(limit);

    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: FoodItem[] = [];
    while (rs.goToNextRow()) {
      list.push(FoodItemDao.map(rs));
    }
    rs.close();
    return list;
  }

  /** 按分类 + 场景查询，供打卡页的分类切换使用 */
  static async queryByCategory(category: number, scene: number, limit: number): Promise<FoodItem[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const args: relationalStore.ValueType[] = [category];
    let sql: string = 'SELECT * FROM food_item WHERE category = ?';
    if (scene > 0) {
      sql += ' AND (scene_flags & ?) != 0';
      args.push(scene);
    }
    sql += ' ORDER BY is_custom DESC, id ASC LIMIT ?';
    args.push(limit);

    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    const list: FoodItem[] = [];
    while (rs.goToNextRow()) {
      list.push(FoodItemDao.map(rs));
    }
    rs.close();
    return list;
  }

  static async getById(id: number): Promise<FoodItem | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    let item: FoodItem | undefined = undefined;
    if (rs.goToFirstRow()) {
      item = FoodItemDao.map(rs);
    }
    rs.close();
    return item;
  }

  /** 新增用户自建食物，返回新行 id */
  static async insertCustom(item: FoodItem): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    item.isCustom = 1;
    return await store.insert(TABLE, FoodItemDao.toBucket(item));
  }

  static async deleteCustom(id: number): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    predicates.equalTo('is_custom', 1);
    return await store.delete(predicates);
  }

  static async countAll(): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql('SELECT COUNT(*) AS c FROM food_item');
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return count;
  }
}
