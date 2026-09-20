import { Theme } from '../utils/Theme';

/**
 * 一排可选项。
 *
 * 做成组件而不是 @Builder：@Builder 多参数是按值传递，父组件的状态变了它不会重新执行，
 * 选中态就永远停在第一帧。@Prop 走的是正常的更新链路。
 */
@Component
export struct ChipRow {
  labels: string[] = [];
  @Prop selected: number = 0;
  /** 放进 ForEach 的 key 里，避免不同组的 chip 被复用 */
  group: string = '';
  onPick: (index: number) => void = () => {};

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.labels, (label: string, index: number) => {
        Text(label)
          .fontSize(13)
          .fontColor(index === this.selected ? Color.White : Theme.TEXT_SECONDARY)
          .backgroundColor(index === this.selected ? Theme.PRIMARY : Theme.CARD)
          .borderRadius(Theme.RADIUS_CHIP)
          .border({ width: 1, color: index === this.selected ? Theme.PRIMARY : Theme.LINE })
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .margin({ right: 8, bottom: 8 })
          .onClick(() => {
            this.onPick(index);
          })
      }, (label: string, index: number) => `${this.group}-${index}-${label}-${this.selected}`)
    }
    .width('100%')
  }
}
