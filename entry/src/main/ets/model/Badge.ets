/** 已解锁的徽章记录 */
export class Badge {
  id: number = 0;
  badgeCode: string = '';
  unlockedAt: number = 0;
}

/** 徽章定义（静态目录，不入库） */
export class BadgeDef {
  code: string = '';
  name: string = '';
  desc: string = '';

  constructor(code: string, name: string, desc: string) {
    this.code = code;
    this.name = name;
    this.desc = desc;
  }
}

/**
 * 徽章目录。
 * 解锁判定逻辑在 BadgeService 中，这里只定义"有哪些徽章"及其展示文案。
 */
export class BadgeCatalog {
  static readonly ALL: BadgeDef[] = [
    new BadgeDef('FIRST_CHECKIN', '初次打卡', '完成第一次打卡'),
    new BadgeDef('STREAK_3', '三日之约', '连续打卡 3 天'),
    new BadgeDef('STREAK_7', '一周不辍', '连续打卡 7 天'),
    new BadgeDef('STREAK_30', '月满坚持', '连续打卡 30 天'),
    new BadgeDef('FIRST_MEAL', '第一餐记录', '首次记录饮食'),
    new BadgeDef('MEAL_50', '饮食记录家', '累计记录 50 餐'),
    new BadgeDef('FIRST_ACTIVITY', '动起来', '首次记录运动'),
    new BadgeDef('ACTIVITY_10', '运动习惯', '累计记录 10 次运动'),
    new BadgeDef('WATER_GOAL', '补水达人', '单日饮水达标'),
    new BadgeDef('SCORE_90', '满分状态', '单日健康分达到 90 以上'),
    new BadgeDef('REPAIR_FIRST', '没断就好', '首次使用补签')
  ];

  /** 按 code 查定义，找不到返回 undefined */
  static find(code: string): BadgeDef | undefined {
    for (const def of BadgeCatalog.ALL) {
      if (def.code === code) {
        return def;
      }
    }
    return undefined;
  }

  static nameOf(code: string): string {
    const def: BadgeDef | undefined = BadgeCatalog.find(code);
    return def === undefined ? code : def.name;
  }
}
