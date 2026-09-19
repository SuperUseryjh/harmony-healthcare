import { Theme } from '../utils/Theme';

export class DockItem {
  label: string = '';

  constructor(label: string) {
    this.label = label;
  }
}

const ITEM_WIDTH: number = 78;
const ITEM_HEIGHT: number = 50;
const ITEM_GAP: number = 4;
const SLIDE_DURATION: number = 220;

@Component
export struct FloatingDock {
  items: DockItem[] = [];
  @Prop selected: number = 0;
  onPick: (index: number) => void = () => {};

  @Builder
  navIcon(index: number) {
    if (index === 0) {
      Image($rawfile('icons/nav-home.svg'))
        .width(22)
        .height(22)
        .opacity(index === this.selected ? 1 : 0.45)
    } else if (index === 1) {
      Image($rawfile('icons/nav-trend.svg'))
        .width(22)
        .height(22)
        .opacity(index === this.selected ? 1 : 0.45)
    } else {
      Image($rawfile('icons/nav-profile.svg'))
        .width(22)
        .height(22)
        .opacity(index === this.selected ? 1 : 0.45)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      /**
       * 选中态底板独立于 ForEach，保证切换时可以平滑移动。
       */
      Text('')
        .width(ITEM_WIDTH)
        .height(ITEM_HEIGHT)
        .backgroundColor(Theme.PRIMARY_SOFT)
        .borderRadius(Theme.RADIUS_CHIP)
        .border({
          width: 1,
          color: Theme.PRIMARY_LINE
        })
        .offset({
          x: this.selected * (ITEM_WIDTH + ITEM_GAP)
        })
        .animation({
          duration: SLIDE_DURATION,
          curve: Curve.EaseOut
        })

      Row({ space: ITEM_GAP }) {
        ForEach(
          this.items,
          (item: DockItem, index: number) => {
            Column({ space: 2 }) {
              this.navIcon(index)

              Text(item.label)
                .fontSize(11)
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
            .width(ITEM_WIDTH)
            .height(ITEM_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.onPick(index);
            })
          },
          (item: DockItem, index: number) =>
            `${index}-${item.label}-${this.selected}`
        )
      }
    }
    .padding(5)
    .backgroundColor(Theme.FROSTED)
    .borderRadius(Theme.RADIUS_DOCK)
    .border({
      width: 1,
      color: Theme.HAIRLINE
    })
  }
}