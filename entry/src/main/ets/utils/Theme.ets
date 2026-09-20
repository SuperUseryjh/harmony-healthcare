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

  /** 动效时长。集中写在这里，各处节奏才一致 */
  static readonly DURATION_FAST: number = 150;
  static readonly DURATION_BASE: number = 240;

  /**
   * 二级页（全屏覆盖）的进出场：淡入 + 轻微上浮。
   *
   * 这些页面原先是一瞬间就贴上去的，和整体的手帐气质不搭。淡入加一点位移，
   * 既说明"这是叠上来的一层"，又不至于拖慢操作手感。
   */
  static overlayEffect(): TransitionEffect {
    const fade: TransitionEffect = TransitionEffect.OPACITY
      .animation({ duration: Theme.DURATION_BASE, curve: Curve.FastOutSlowIn });
    const rise: TransitionEffect = TransitionEffect.translate({ y: 28 })
      .animation({ duration: Theme.DURATION_BASE, curve: Curve.FastOutSlowIn });
    return fade.combine(rise);
  }

  /** 整块底板这类元素的淡入淡出：比如分段控件的选中底板 */
  static fadeEffect(): TransitionEffect {
    return TransitionEffect.OPACITY
      .animation({ duration: Theme.DURATION_FAST, curve: Curve.FastOutSlowIn });
  }

  /** 选中标记这类小元素的出现：从 0.7 倍淡入放大到原尺寸，比直接跳出来自然 */
  static popEffect(): TransitionEffect {
    const fade: TransitionEffect = TransitionEffect.OPACITY
      .animation({ duration: Theme.DURATION_FAST, curve: Curve.FastOutSlowIn });
    const grow: TransitionEffect = TransitionEffect.scale({ x: 0.7, y: 0.7 })
      .animation({ duration: Theme.DURATION_FAST, curve: Curve.FastOutSlowIn });
    return fade.combine(grow);
  }

  /** 一级页切换与页签切换：比覆盖层快一点，频繁切换时不显得拖沓 */
  static pageEffect(): TransitionEffect {
    const fade: TransitionEffect = TransitionEffect.OPACITY
      .animation({ duration: Theme.DURATION_FAST, curve: Curve.EaseOut });
    const rise: TransitionEffect = TransitionEffect.translate({ y: 10 })
      .animation({ duration: Theme.DURATION_FAST, curve: Curve.EaseOut });
    return fade.combine(rise);
  }

  /** 趋势图 */
  static readonly BAR_EMPTY: string = '#DCE7E3';
  static readonly BAR_UNDER: string = '#78B79B';
}