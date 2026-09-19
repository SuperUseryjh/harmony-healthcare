import { Theme } from '../utils/Theme';

@Component
export struct SegmentedBar {
  labels: string[] = [];
  @Prop selected: number = 0;
  onPick: (index: number) => void = () => {};

  build() {
    Row() {
      ForEach(
        this.labels,
        (label: string, index: number) => {
          Text(label)
            .layoutWeight(1)
            .height(36)
            .textAlign(TextAlign.Center)
            .fontSize(13)
            .fontWeight(
              index === this.selected
                ? FontWeight.Medium
                : FontWeight.Normal
            )
            .fontColor(
              index === this.selected
                ? Theme.PRIMARY
                : Theme.TEXT_SECONDARY
            )
            .backgroundColor(
              index === this.selected
                ? Theme.CARD
                : Color.Transparent
            )
            .borderRadius(Theme.RADIUS_CHIP)
            .border({
              width: 1,
              color:
                index === this.selected
                  ? Theme.LINE
                  : Color.Transparent
            })
            .onClick(() => {
              this.onPick(index);
            })
        },
        (label: string, index: number) =>
          `${index}-${label}-${this.selected}`
      )
    }
    .width('100%')
    .height(44)
    .padding(4)
    .backgroundColor(Theme.TRACK)
    .borderRadius(Theme.RADIUS_CHIP)
  }
}