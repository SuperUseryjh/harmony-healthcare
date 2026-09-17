/**
 * 日期工具。
 *
 * 全项目统一用 'YYYY-MM-DD' 字符串作为"日期"的表示形式（对应各表的 record_date 字段），
 * 时间戳只在需要精确时刻时使用。这样按天分组、跨天切分都不需要处理时区换算。
 */
export class DateUtils {
  static readonly MS_PER_DAY: number = 86400000;

  private static pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** 时间戳 → 'YYYY-MM-DD'（设备本地时区） */
  static toDateKey(ts: number): string {
    const d: Date = new Date(ts);
    return `${d.getFullYear()}-${DateUtils.pad2(d.getMonth() + 1)}-${DateUtils.pad2(d.getDate())}`;
  }

  /** 今天 */
  static todayKey(): string {
    return DateUtils.toDateKey(Date.now());
  }

  /** 'YYYY-MM-DD' → 当日 00:00:00 的时间戳 */
  static keyToTimestamp(key: string): number {
    const parts: string[] = key.split('-');
    const y: number = Number.parseInt(parts[0], 10);
    const m: number = Number.parseInt(parts[1], 10);
    const d: number = Number.parseInt(parts[2], 10);
    return new Date(y, m - 1, d).getTime();
  }

  /** 日期加减天数 */
  static addDays(key: string, days: number): string {
    return DateUtils.toDateKey(DateUtils.keyToTimestamp(key) + days * DateUtils.MS_PER_DAY);
  }

  /** toKey − fromKey 的天数差，正数表示 toKey 更晚 */
  static diffDays(fromKey: string, toKey: string): number {
    const delta: number = DateUtils.keyToTimestamp(toKey) - DateUtils.keyToTimestamp(fromKey);
    return Math.round(delta / DateUtils.MS_PER_DAY);
  }

  /** 生成从 startKey 开始的连续 count 天日期数组 */
  static rangeKeys(startKey: string, count: number): string[] {
    const keys: string[] = [];
    for (let i = 0; i < count; i++) {
      keys.push(DateUtils.addDays(startKey, i));
    }
    return keys;
  }

  /** key 是否早于今天 */
  static isPast(key: string): boolean {
    return DateUtils.diffDays(key, DateUtils.todayKey()) > 0;
  }

  /** key 是否是今天 */
  static isToday(key: string): boolean {
    return DateUtils.diffDays(key, DateUtils.todayKey()) === 0;
  }

  /** 当天 0 点时间戳 */
  static todayStartTs(): number {
    return DateUtils.keyToTimestamp(DateUtils.todayKey());
  }

  /** 现在几点（0-23），用于建议引擎判断时段 */
  static currentHour(): number {
    return new Date(Date.now()).getHours();
  }
}
