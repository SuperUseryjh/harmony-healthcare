import { Theme } from '../utils/Theme';

/** 分段高度：外层 44 减去上下各 4 的内边距 */
const SEGMENT_HEIGHT: number = 36;

/**
 * 分段控件。
 *
 * 选中底板做成独立的一层、靠 transition 淡入，而不是直接改文字自己的底色——
 * 底色的变化是瞬间的，切换时看着像"啪"地跳了一下，和别处的动效节奏不一致。
 * 底板跟着 key 一起重建，所以淡入是可靠的，不依赖属性级刷新。
 */
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
          Stack() {
            if (index === this.selected) {
              Text('')
                .width('100%')
                .height('100%')
                .backgroundColor(Theme.CARD)
                .borderRadius(Theme.RADIUS_CHIP)
                .border({ width: 1, color: Theme.LINE })
                .transition(Theme.fadeEffect())
            }

            Text(label)
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
          }
          .layoutWeight(1)
          .height(SEGMENT_HEIGHT)
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