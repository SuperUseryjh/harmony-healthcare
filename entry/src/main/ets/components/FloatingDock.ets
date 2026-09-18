import { Theme } from '../utils/Theme';

/** Dock 上的一项 */
export class DockItem {
  label: string = '';

  constructor(label: string) {
    this.label = label;
  }
}

const ITEM_WIDTH: number = 76;
const ITEM_HEIGHT: number = 38;
const ITEM_GAP: number = 4;
const SLIDE_DURATION: number = 260;

/**
 * 悬浮式底部切换栏（类似 iOS 程序坞）。
 *
 * 动效的实现方式是有讲究的：选中态的底板**不能放进 ForEach**。
 * ForEach 用键值判断是否复用子节点，而选中态一变键值就得跟着变（否则样式不刷新），
 * 键值一变节点就被重建——重建是"新节点出现"，没有起点也就没有补间，动画必然失效。
 *
 * 所以拆成两层：底板是 Stack 里独立的一个元素，只改 offset，由 .animation 补间；
 * 文字层留在 ForEach 里，颜色瞬时切换。滑动是主导视觉，两者叠加看起来是连贯的。
 */
@Component
export struct FloatingDock {
  items: DockItem[] = [];
  @Prop selected: number = 0;
  onPick: (index: number) => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 选中底板：只改位置，交给动画补间
      Text('')
        .width(ITEM_WIDTH)
        .height(ITEM_HEIGHT)
        .backgroundColor(Theme.PRIMARY_SOFT)
        .borderRadius(Theme.RADIUS_CHIP)
        .border({ width: 1, color: Theme.PRIMARY_LINE })
        .offset({ x: this.selected * (ITEM_WIDTH + ITEM_GAP) })
        .animation({ duration: SLIDE_DURATION, curve: Curve.EaseOut })

      // 文字层：键值带 selected，保证选中态样式能刷新
      Row({ space: ITEM_GAP }) {
        ForEach(this.items, (item: DockItem, index: number) => {
          Text(item.label)
            .width(ITEM_WIDTH)
            .height(ITEM_HEIGHT)
            .textAlign(TextAlign.Center)
            .fontSize(14)
            .letterSpacing(0.5)
            .fontWeight(index === this.selected ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(index === this.selected ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
            .onClick(() => {
              this.onPick(index);
            })
        }, (item: DockItem, index: number) => `${index}-${item.label}-${this.selected}`)
      }
    }
    .padding(5)
    .backgroundColor(Theme.FROSTED)
    .borderRadius(Theme.RADIUS_DOCK)
    .border({ width: 1, color: Theme.HAIRLINE })
  }
}
