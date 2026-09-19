import { Theme } from '../utils/Theme';

@Component
export struct OverlayHeader {
  title: string = '';
  closeLabel: string = '取消';
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.closeLabel)
          .fontSize(14)
          .fontColor(Theme.TEXT_SECONDARY)
          .padding({
            left: 8,
            right: 8,
            top: 8,
            bottom: 8
          })
          .onClick(() => {
            this.onClose();
          })

        Blank()

        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)

        Blank()

        Text('')
          .width(48)
          .height(1)
      }
      .width('100%')
      .height(56)
      .padding({
        left: 16,
        right: 16
      })
      .alignItems(VerticalAlign.Center)

      Divider()
        .color(Theme.DIVIDER)
        .strokeWidth(1)
    }
    .width('100%')
    .backgroundColor(Theme.CARD)
  }
}