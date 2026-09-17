import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SceneBit } from '../model/Enums';

const DOMAIN: number = 0x0000;
const TAG: string = 'DbHelper';
const DB_NAME: string = 'health_life.db';
const SEED_RAW_FILE: string = 'food_seed.json';

/** food_seed.json 中的单条记录 */
interface SeedFoodItem {
  name: string;
  category: number;
  scene: string[];
  unitName: string;
  unitGram: number;
  kcalPer100g: number;
  proteinPer100g: number;
  fatPer100g: number;
  carbPer100g: number;
}

/** food_seed.json 的文件结构 */
interface SeedFile {
  version: number;
  items: SeedFoodItem[];
}

/**
 * 数据库入口：负责建库、建表、首次启动导入预置食物库。
 *
 * 使用方式：在 EntryAbility.onCreate 中 await DbHelper.init(this.context)，
 * 之后各 DAO 通过 DbHelper.getStore() 取连接。
 */
export class DbHelper {
  private static store: relationalStore.RdbStore | undefined = undefined;
  /** 并发调用 init 时复用同一个初始化任务，避免重复建表 */
  private static initTask: Promise<void> | undefined = undefined;

  private static readonly CREATE_TABLES: string[] = [
    `CREATE TABLE IF NOT EXISTS user_profile (
      id               INTEGER PRIMARY KEY,
      nickname         TEXT    NOT NULL DEFAULT '',
      gender           INTEGER NOT NULL DEFAULT 0,
      birth_year       INTEGER NOT NULL DEFAULT 2000,
      height_cm        REAL    NOT NULL DEFAULT 170,
      weight_kg        REAL    NOT NULL DEFAULT 60,
      activity_level   INTEGER NOT NULL DEFAULT 2,
      goal             INTEGER NOT NULL DEFAULT 1,
      target_weight_kg REAL    NOT NULL DEFAULT 60,
      updated_at       INTEGER NOT NULL DEFAULT 0
    )`,

    `CREATE TABLE IF NOT EXISTS food_item (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      name             TEXT    NOT NULL,
      category         INTEGER NOT NULL DEFAULT 0,
      scene_flags      INTEGER NOT NULL DEFAULT 0,
      unit_name        TEXT    NOT NULL DEFAULT '份',
      unit_gram        REAL    NOT NULL DEFAULT 100,
      kcal_per_100g    REAL    NOT NULL DEFAULT 0,
      protein_per_100g REAL    NOT NULL DEFAULT 0,
      fat_per_100g     REAL    NOT NULL DEFAULT 0,
      carb_per_100g    REAL    NOT NULL DEFAULT 0,
      is_custom        INTEGER NOT NULL DEFAULT 0
    )`,

    `CREATE INDEX IF NOT EXISTS idx_food_scene ON food_item(scene_flags)`,

    `CREATE TABLE IF NOT EXISTS meal_record (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      record_date TEXT    NOT NULL,
      meal_type   INTEGER NOT NULL,
      scene       INTEGER NOT NULL DEFAULT 1,
      food_id     INTEGER NOT NULL,
      food_name   TEXT    NOT NULL,
      amount      REAL    NOT NULL DEFAULT 1,
      kcal        REAL    NOT NULL DEFAULT 0,
      protein_g   REAL    NOT NULL DEFAULT 0,
      fat_g       REAL    NOT NULL DEFAULT 0,
      carb_g      REAL    NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL
    )`,

    `CREATE INDEX IF NOT EXISTS idx_meal_date ON meal_record(record_date)`,

    `CREATE TABLE IF NOT EXISTS activity_record (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      record_date   TEXT    NOT NULL,
      activity_type INTEGER NOT NULL,
      duration_min  INTEGER NOT NULL DEFAULT 0,
      intensity     INTEGER NOT NULL DEFAULT 2,
      kcal_burned   REAL    NOT NULL DEFAULT 0,
      created_at    INTEGER NOT NULL
    )`,

    `CREATE INDEX IF NOT EXISTS idx_activity_date ON activity_record(record_date)`,

    `CREATE TABLE IF NOT EXISTS water_record (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      record_date TEXT    NOT NULL,
      amount_ml   INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL
    )`,

    `CREATE INDEX IF NOT EXISTS idx_water_date ON water_record(record_date)`,

    `CREATE TABLE IF NOT EXISTS daily_summary (
      record_date   TEXT PRIMARY KEY,
      intake_kcal   REAL    NOT NULL DEFAULT 0,
      burned_kcal   REAL    NOT NULL DEFAULT 0,
      protein_g     REAL    NOT NULL DEFAULT 0,
      fat_g         REAL    NOT NULL DEFAULT 0,
      carb_g        REAL    NOT NULL DEFAULT 0,
      water_ml      INTEGER NOT NULL DEFAULT 0,
      activity_min  INTEGER NOT NULL DEFAULT 0,
      checkin_flags INTEGER NOT NULL DEFAULT 0,
      score         INTEGER NOT NULL DEFAULT 0,
      streak_days   INTEGER NOT NULL DEFAULT 0
    )`,

    `CREATE TABLE IF NOT EXISTS checkin_streak (
      record_date     TEXT PRIMARY KEY,
      completed_items INTEGER NOT NULL DEFAULT 0,
      is_broken       INTEGER NOT NULL DEFAULT 0,
      repair_used     INTEGER NOT NULL DEFAULT 0
    )`,

    `CREATE TABLE IF NOT EXISTS badge (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      badge_code  TEXT    NOT NULL UNIQUE,
      unlocked_at INTEGER NOT NULL
    )`
  ];

  /**
   * 初始化数据库。可重复调用，内部保证只真正执行一次。
   * @param context 应用上下文，通常是 UIAbilityContext
   */
  static async init(context: common.Context): Promise<void> {
    if (DbHelper.store !== undefined) {
      return;
    }
    if (DbHelper.initTask === undefined) {
      DbHelper.initTask = DbHelper.doInit(context);
    }
    await DbHelper.initTask;
    DbHelper.initTask = undefined;
  }

  /** 取得数据库连接。未初始化时抛错，避免静默失败 */
  static getStore(): relationalStore.RdbStore {
    const store: relationalStore.RdbStore | undefined = DbHelper.store;
    if (store === undefined) {
      throw new Error('DbHelper 尚未初始化，请先在 EntryAbility.onCreate 中调用 DbHelper.init(context)');
    }
    return store;
  }

  /**
   * 等待已在进行的初始化完成，不触发新的初始化。
   *
   * 页面侧用它来"等 Ability 把库建好"，这样页面自己不需要再取一次 Context。
   * @returns 是否已就绪
   */
  static async waitReady(): Promise<boolean> {
    if (DbHelper.store !== undefined) {
      return true;
    }
    const task: Promise<void> | undefined = DbHelper.initTask;
    if (task !== undefined) {
      await task;
    }
    return DbHelper.store !== undefined;
  }

  static isReady(): boolean {
    return DbHelper.store !== undefined;
  }

  private static async doInit(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    try {
      const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
      for (const sql of DbHelper.CREATE_TABLES) {
        await store.execute(sql);
      }
      DbHelper.store = store;
      hilog.info(DOMAIN, TAG, '%{public}s', '数据库初始化完成');
      await DbHelper.seedFoodIfEmpty(context, store);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '数据库初始化失败 code=%{public}d message=%{public}s', e.code, e.message);
      throw err as Error;
    }
  }

  /** 食物库为空时，从 rawfile 导入预置数据。只在首次启动执行 */
  private static async seedFoodIfEmpty(context: common.Context, store: relationalStore.RdbStore): Promise<void> {
    const count: number = await DbHelper.countFood(store);
    if (count > 0) {
      return;
    }
    try {
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(SEED_RAW_FILE);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const text: string = decoder.decodeToString(bytes);
      const seed: SeedFile = JSON.parse(text) as SeedFile;

      const buckets: relationalStore.ValuesBucket[] = [];
      for (const item of seed.items) {
        const bucket: relationalStore.ValuesBucket = {
          'name': item.name,
          'category': item.category,
          'scene_flags': DbHelper.sceneArrayToFlags(item.scene),
          'unit_name': item.unitName,
          'unit_gram': item.unitGram,
          'kcal_per_100g': item.kcalPer100g,
          'protein_per_100g': item.proteinPer100g,
          'fat_per_100g': item.fatPer100g,
          'carb_per_100g': item.carbPer100g,
          'is_custom': 0
        };
        buckets.push(bucket);
      }
      const inserted: number = await store.batchInsert('food_item', buckets);
      hilog.info(DOMAIN, TAG, '预置食物库导入完成，共 %{public}d 条', inserted);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '预置食物库导入失败 code=%{public}d message=%{public}s', e.code, e.message);
      // 导入失败不阻断应用启动，用户可以手动新增食物
    }
  }

  private static async countFood(store: relationalStore.RdbStore): Promise<number> {
    const rs: relationalStore.ResultSet = await store.querySql('SELECT COUNT(*) AS c FROM food_item');
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return count;
  }

  /** 把 food_seed.json 里的场景字符串数组转成位标记 */
  private static sceneArrayToFlags(scenes: string[]): number {
    let flags: number = 0;
    for (const scene of scenes) {
      if (scene === 'canteen') {
        flags = flags | SceneBit.CANTEEN;
      } else if (scene === 'takeout') {
        flags = flags | SceneBit.TAKEOUT;
      } else if (scene === 'convenience') {
        flags = flags | SceneBit.CONVENIENCE;
      } else if (scene === 'homemade') {
        flags = flags | SceneBit.HOMEMADE;
      }
    }
    return flags;
  }
}
