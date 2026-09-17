import { relationalStore } from '@kit.ArkData';
import { Badge } from '../model/Badge';
import { DbHelper } from './DbHelper';

const TABLE: string = 'badge';
const COLUMNS: string[] = ['id', 'badge_code', 'unlocked_at'];

/** 成就徽章 DAO */
export class BadgeDao {

  private static map(rs: relationalStore.ResultSet): Badge {
    const badge: Badge = new Badge();
    badge.id = rs.getLong(rs.getColumnIndex('id'));
    badge.badgeCode = rs.getString(rs.getColumnIndex('badge_code'));
    badge.unlockedAt = rs.getLong(rs.getColumnIndex('unlocked_at'));
    return badge;
  }

  static async getAll(): Promise<Badge[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.orderByAsc('unlocked_at');
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    const list: Badge[] = [];
    while (rs.goToNextRow()) {
      list.push(BadgeDao.map(rs));
    }
    rs.close();
    return list;
  }

  static async has(code: string): Promise<boolean> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const sql: string = `SELECT COUNT(*) AS c FROM ${TABLE} WHERE badge_code = ?`;
    const args: relationalStore.ValueType[] = [code];
    const rs: relationalStore.ResultSet = await store.querySql(sql, args);
    let count: number = 0;
    if (rs.goToFirstRow()) {
      count = rs.getLong(rs.getColumnIndex('c'));
    }
    rs.close();
    return count > 0;
  }

  /** 解锁徽章。badge_code 有唯一约束，重复解锁不会产生重复行 */
  static async unlock(code: string, unlockedAt: number): Promise<boolean> {
    const already: boolean = await BadgeDao.has(code);
    if (already) {
      return false;
    }
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const bucket: relationalStore.ValuesBucket = {
      'badge_code': code,
      'unlocked_at': unlockedAt
    };
    await store.insert(TABLE, bucket, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
    return true;
  }

  static async count(): Promise<number> {
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
