/**
 * 全局视觉规范 —— 纸感手帐风。
 *
 * 三条规则贯穿所有页面：
 *   1. 不用阴影，只用 1px 细描边。阴影是"现代扁平卡片"的信号，正是要避开的东西。
 *   2. 底色偏暖（米黄纸），文字用暖墨色而不是纯黑，避免冷硬。
 *   3. 圆角收小（8 / 6），接近纸片的直角感，而不是现代 UI 的大圆角胶囊。
 *
 * 字段名沿用改造前的一套，这样各页面只需要换值、不必改引用点。
 */
export class Theme {
  /** 页面底色：上浅下略深的纸色 */
  static readonly BG_TOP: string = '#F8F4EB';
  static readonly BG_BOTTOM: string = '#F1EBDD';

  /** 卡片纸面，比页面底更亮一点，靠色差而非阴影区分层次 */
  static readonly CARD: string = '#FFFDF8';
  /** 描边：分隔卡片与纸底 */
  static readonly LINE: string = '#E3DACA';

  /** 主点缀色：赭红，像手帐里的红印章 */
  static readonly PRIMARY: string = '#B4543C';
  static readonly PRIMARY_SOFT: string = '#F6E7E1';
  /** 强调底色的描边：比 LINE 略暖，用于主色块 */
  static readonly PRIMARY_LINE: string = '#E8CFC6';
  /** 达标/正向：橄榄绿 */
  static readonly SUCCESS: string = '#5F7A55';
  /** 提醒/偏离：芥末黄 */
  static readonly WARNING: string = '#C08A2E';
  static readonly WARNING_SOFT: string = '#F8F0DE';
  static readonly WARNING_LINE: string = '#E8D9B8';
  static readonly GOLD_TEXT: string = '#8A6420';

  /** 文字三级：暖墨色，不用纯黑 */
  static readonly TEXT_PRIMARY: string = '#3D3830';
  static readonly TEXT_SECONDARY: string = '#7A7266';
  static readonly TEXT_TERTIARY: string = '#A69C8C';
  static readonly TEXT_DISABLED: string = '#C8BFB0';

  static readonly DIVIDER: string = '#EDE6D8';
  /** 进度条底槽 */
  static readonly TRACK: string = '#EDE6D8';
  /** Dock 底色：不透明纸面（原来的半透明磨砂偏现代，换掉） */
  static readonly FROSTED: string = '#FFFDF8';
  /** Dock 轮廓 */
  static readonly HAIRLINE: string = '#D2C6B0';

  static readonly RADIUS_CARD: number = 8;
  static readonly RADIUS_CHIP: number = 6;
  static readonly RADIUS_DOCK: number = 12;

  /** 图表里"无记录"的柱色 */
  static readonly BAR_EMPTY: string = '#E7E0D2';
  /** 图表里"摄入偏少"的柱色 */
  static readonly BAR_UNDER: string = '#8FA383';
}
