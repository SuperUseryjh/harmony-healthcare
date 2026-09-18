import { Theme } from '../utils/Theme';

/**
 * 分节标题：左侧一条短竖线 + 标题。
 *
 * 竖线是手帐/笔记排版里最常见的分节标记，比纯文字标题更能立起层次，
 * 而且不需要额外的图形资源。
 */
@Component
export struct SectionTitle {
  /** 标题文字，静态内容用普通成员即可 */
  text: string = '';
  /** 右侧附加信息，可能是动态的（如"已记录 3 餐"），因此用 @Prop 单向同步 */
  @Prop trailing: string = '';
  /** 竖线颜色，不传则用主色 */
  accent: string = Theme.PRIMARY;

  build() {
    Row({ space: 8 }) {
      Text('')
        .width(3)
        .height(14)
        .backgroundColor(this.accent)
        .borderRadius(2)
      Text(this.text)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)
        .letterSpacing(0.6)
      Blank()
      Text(this.trailing).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
