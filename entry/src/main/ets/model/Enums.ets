/**
 * 全局枚举与位标记定义。
 *
 * 位标记（SceneBit / CheckinBit）与数据库中的 scene_flags / checkin_flags 字段一一对应，
 * 用一个整数存下多个布尔状态，后续新增打卡项或场景时不需要改表结构。
 */

/** 性别 */
export enum Gender {
  UNKNOWN = 0,
  MALE = 1,
  FEMALE = 2
}

/** 活动量等级，参与 TDEE 计算 */
export enum ActivityLevel {
  SEDENTARY = 1,
  LIGHT = 2,
  MODERATE = 3,
  ACTIVE = 4,
  VERY_ACTIVE = 5
}

/** 健康目标 */
export enum Goal {
  LOSE = 0,
  KEEP = 1,
  GAIN = 2
}

/** 餐次 */
export enum MealType {
  BREAKFAST = 0,
  LUNCH = 1,
  DINNER = 2,
  SNACK = 3
}

/** 食物分类 */
export enum FoodCategory {
  STAPLE = 0,
  MEAT = 1,
  VEGETABLE = 2,
  SOUP = 3,
  DRINK = 4,
  SNACK = 5,
  FRUIT = 6,
  EGG_MILK = 7
}

/** 用餐场景，按位组合后存入 food_item.scene_flags */
export enum SceneBit {
  CANTEEN = 1,
  TAKEOUT = 2,
  CONVENIENCE = 4,
  HOMEMADE = 8
}

/** 全部场景的位或，用于"不限场景"查询 */
export const ALL_SCENES: number = SceneBit.CANTEEN | SceneBit.TAKEOUT | SceneBit.CONVENIENCE | SceneBit.HOMEMADE;

/** 打卡项，按位组合后存入 daily_summary.checkin_flags */
export enum CheckinBit {
  BREAKFAST = 1,
  LUNCH = 2,
  DINNER = 4,
  ACTIVITY = 8,
  WATER = 16,
  ROUTINE = 32
}

/** 全部打卡项的位或 */
export const ALL_CHECKINS: number =
  CheckinBit.BREAKFAST | CheckinBit.LUNCH | CheckinBit.DINNER |
  CheckinBit.ACTIVITY | CheckinBit.WATER | CheckinBit.ROUTINE;

/** 打卡项总数，用于计算打卡完成度 */
export const CHECKIN_ITEM_COUNT: number = 6;

/** 运动类型 */
export enum ActivityType {
  WALK = 0,
  RUN = 1,
  CYCLE = 2,
  BALL = 3,
  STRENGTH = 4,
  SWIM = 5,
  OTHER = 6
}

/** 运动强度 */
export enum Intensity {
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3
}

/** 位标记读写工具 */
export class BitFlags {
  /** 判断 flags 中是否包含 bit */
  static has(flags: number, bit: number): boolean {
    return (flags & bit) !== 0;
  }

  /** 置位 */
  static add(flags: number, bit: number): number {
    return flags | bit;
  }

  /** 清位 */
  static remove(flags: number, bit: number): number {
    return flags & ~bit;
  }

  /** 统计 flags 中落在 all 范围内的位个数 */
  static count(flags: number, all: number): number {
    let rest: number = flags & all;
    let n: number = 0;
    while (rest !== 0) {
      n += rest & 1;
      rest = rest >> 1;
    }
    return n;
  }

  /** 展开为置位的 bit 值数组，例如 5 -> [1, 4] */
  static toArray(flags: number, all: number): number[] {
    const result: number[] = [];
    let bit: number = 1;
    while (bit <= all) {
      if ((all & bit) !== 0 && (flags & bit) !== 0) {
        result.push(bit);
      }
      bit = bit << 1;
    }
    return result;
  }
}
