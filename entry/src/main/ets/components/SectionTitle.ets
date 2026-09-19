import { Theme } from '../utils/Theme';

@Component
export struct SectionTitle {
  text: string = '';
  @Prop trailing: string = '';
  accent: string = Theme.PRIMARY;

  build() {
    Row({ space: 12 }) {
      Text('')
        .width(4)
        .height(18)
        .backgroundColor(this.accent)
        .borderRadius(2)

      Text(this.text)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)

      Blank()

      if (this.trailing.length > 0) {
        Text(this.trailing)
          .fontSize(12)
          .fontColor(Theme.TEXT_TERTIARY)
      }
    }
    .width('100%')
    .height(24)
    .alignItems(VerticalAlign.Center)
  }
}