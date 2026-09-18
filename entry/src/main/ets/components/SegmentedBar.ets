import { Theme } from '../utils/Theme';

/**
 * 分段选择条（如"男/女""早/午/晚/加"）。
 *
 * 这里刻意用自定义组件而不是 @Builder：@Builder 默认按值传递，多参数时状态变化
 * 不会引起其内部 UI 刷新（之前踩过这个坑）。而自定义组件的 @Prop 会随父组件重新
 * 渲染而单向同步，选中态能可靠地刷新。
 */
@Component
export struct SegmentedBar {
  labels: string[] = [];
  /** 选中项下标，由父组件同步 */
  @Prop selected: number = 0;
  /** 点击回调，参数为被点中的下标 */
  onPick: (index: number) => void = () => {};

  build() {
    Row() {
      // key 里带上 selected：选中态变化时让 ForEach 重建子项，
      // 否则 key 不变会复用旧节点，样式不跟着更新
      ForEach(this.labels, (label: string, index: number) => {
        Text(label)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(index === this.selected ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(index === this.selected ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
          .padding({ top: 9, bottom: 9 })
          .backgroundColor(index === this.selected ? Theme.CARD : Color.Transparent)
          .borderRadius(Theme.RADIUS_CHIP)
          .border({
            width: 1,
            color: index === this.selected ? Theme.LINE : Color.Transparent
          })
          .onClick(() => {
            this.onPick(index);
          })
      }, (label: string, index: number) => `${index}-${label}-${this.selected}`)
    }
    .width('100%')
    .padding(4)
    .backgroundColor(Theme.TRACK)
    .borderRadius(Theme.RADIUS_CHIP + 2)
  }
}
