/**
 * Harmony 健康看板视觉令牌。
 *
 * 页面整体采用：
 * - 冷白背景
 * - 深墨色文字
 * - 珊瑚色主行动色
 * - 薄荷绿健康状态色
 * - 低对比度边框
 */
export class Theme {
  static readonly BG_TOP: string = '#F4F7F6';
  static readonly BG_BOTTOM: string = '#F4F7F6';

  static readonly CARD: string = '#FFFFFF';
  static readonly LINE: string = '#E2EBE8';

  /** 主操作色：记录、保存、热量进度 */
  static readonly PRIMARY: string = '#E45B49';
  static readonly PRIMARY_SOFT: string = '#FFF0EC';
  static readonly PRIMARY_LINE: string = '#F5C9C0';

  /** 健康状态色 */
  static readonly SUCCESS: string = '#3E9D78';

  /** 提醒色 */
  static readonly WARNING: string = '#D59435';
  static readonly WARNING_SOFT: string = '#FFF6E5';
  static readonly WARNING_LINE: string = '#F1D8A8';
  static readonly GOLD_TEXT: string = '#A36C18';

  /** 文字层级 */
  static readonly TEXT_PRIMARY: string = '#17231F';
  static readonly TEXT_SECONDARY: string = '#56635E';
  static readonly TEXT_TERTIARY: string = '#8A9993';
  static readonly TEXT_DISABLED: string = '#B9C5C0';

  static readonly DIVIDER: string = '#EDF2F0';
  static readonly TRACK: string = '#E8EFEC';

  /** 底部导航 */
  static readonly FROSTED: string = '#FFFFFF';
  static readonly HAIRLINE: string = '#D8E4E0';

  static readonly RADIUS_CARD: number = 12;
  static readonly RADIUS_CHIP: number = 9;
  static readonly RADIUS_DOCK: number = 18;

  /** 趋势图 */
  static readonly BAR_EMPTY: string = '#DCE7E3';
  static readonly BAR_UNDER: string = '#78B79B';
}