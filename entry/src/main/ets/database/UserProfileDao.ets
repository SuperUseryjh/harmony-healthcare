import { relationalStore } from '@kit.ArkData';
import { UserProfile } from '../model/UserProfile';
import { DbHelper } from './DbHelper';

const TABLE: string = 'user_profile';
const COLUMNS: string[] = ['id', 'nickname', 'gender', 'birth_year', 'height_cm', 'weight_kg',
  'activity_level', 'goal', 'target_weight_kg', 'updated_at'];
const PROFILE_ID: number = 1;

/** 用户档案 DAO。表中固定只有 id = 1 的一行 */
export class UserProfileDao {

  private static map(rs: relationalStore.ResultSet): UserProfile {
    const profile: UserProfile = new UserProfile();
    profile.id = rs.getLong(rs.getColumnIndex('id'));
    profile.nickname = rs.getString(rs.getColumnIndex('nickname'));
    profile.gender = rs.getLong(rs.getColumnIndex('gender'));
    profile.birthYear = rs.getLong(rs.getColumnIndex('birth_year'));
    profile.heightCm = rs.getDouble(rs.getColumnIndex('height_cm'));
    profile.weightKg = rs.getDouble(rs.getColumnIndex('weight_kg'));
    profile.activityLevel = rs.getLong(rs.getColumnIndex('activity_level'));
    profile.goal = rs.getLong(rs.getColumnIndex('goal'));
    profile.targetWeightKg = rs.getDouble(rs.getColumnIndex('target_weight_kg'));
    profile.updatedAt = rs.getLong(rs.getColumnIndex('updated_at'));
    return profile;
  }

  private static toBucket(profile: UserProfile): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'id': PROFILE_ID,
      'nickname': profile.nickname,
      'gender': profile.gender,
      'birth_year': profile.birthYear,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'activity_level': profile.activityLevel,
      'goal': profile.goal,
      'target_weight_kg': profile.targetWeightKg,
      'updated_at': profile.updatedAt
    };
    return bucket;
  }

  /** 读取档案，未初始化时返回 undefined */
  static async get(): Promise<UserProfile | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', PROFILE_ID);
    const rs: relationalStore.ResultSet = await store.query(predicates, COLUMNS);
    let profile: UserProfile | undefined = undefined;
    if (rs.goToFirstRow()) {
      profile = UserProfileDao.map(rs);
    }
    rs.close();
    return profile;
  }

  /** 是否存在档案，用于判断是否需要走引导页 */
  static async exists(): Promise<boolean> {
    const profile: UserProfile | undefined = await UserProfileDao.get();
    return profile !== undefined;
  }

  /** 新增或覆盖档案 */
  static async save(profile: UserProfile): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    profile.id = PROFILE_ID;
    await store.insert(TABLE, UserProfileDao.toBucket(profile),
      relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }
}
