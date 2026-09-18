import { Theme } from '../utils/Theme';
import { PET_DEBUG_PRESETS, PetDebug, PetDebugPreset } from '../utils/PetDebug';
import { OverlayHeader } from './OverlayHeader';

/**
 * 宠物调试面板（全屏覆盖，长按首页的宠物卡片唤出）。
 *
 * 走覆盖层而不是在首页里弹气泡：覆盖层会盖住 Dock，进入后不会误触切页，
 * 而且和"记录三餐""记录运动"用的是同一套交互，不用再学一次。
 *
 * 面板本身不持有宠物状态，只把选择写进 PetDebug；关闭时由 Index 递增 dataVersion
 * 触发首页重新取数，宠物就换成新形象了。
 */
@Component
export struct PetDebugPanel {
  onClose: () => void = () => {};

  /** 当前生效的预设下标，-1 表示用真实数据 */
  @State activeIndex: number = -1;

  aboutToAppear(): void {
    this.activeIndex = PetDebug.activeIndex();
  }

  private pick(index: number): void {
    if (index < 0) {
      PetDebug.clear();
    } else {
      PetDebug.setPreset(index);
    }
    this.activeIndex = PetDebug.activeIndex();
  }

  build() {
    Column() {
      OverlayHeader({
        title: '宠物调试',
        closeLabel: '关闭',
        onClose: () => {
          this.onClose();
        }
      })

      Scroll() {
        Column({ space: 12 }) {
          Text('仅切换显示效果，不会写入或改动任何记录；重启应用后自动恢复真实数据')
            .fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%')

          // key 带 activeIndex：选中态变化时重建条目
          ForEach(PET_DEBUG_PRESETS, (preset: PetDebugPreset, index: number) => {
            Row() {
              Column({ space: 4 }) {
                Text(preset.label)
                  .fontSize(15)
                  .fontWeight(index === this.activeIndex ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(index === this.activeIndex ? Theme.PRIMARY : Theme.TEXT_PRIMARY)
                Text(`累计 ${preset.growDays} 天 · 主餐 ${preset.mainMealCount} 餐 · 运动 ${preset.activityMin} 分`)
                  .fontSize(11).fontColor(Theme.TEXT_TERTIARY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (index === this.activeIndex) {
                Text('已应用').fontSize(12).fontColor(Theme.PRIMARY)
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(index === this.activeIndex ? Theme.PRIMARY_SOFT : Theme.CARD)
            .borderRadius(Theme.RADIUS_CARD)
            .border({
              width: 1,
              color: index === this.activeIndex ? Theme.PRIMARY_LINE : Theme.LINE
            })
            .onClick(() => {
              this.pick(index);
            })
          }, (preset: PetDebugPreset, index: number) => `${index}-${this.activeIndex}`)

          Button('恢复真实数据')
            .width('100%')
            .height(44)
            .fontSize(15)
            .backgroundColor(this.activeIndex < 0 ? Theme.TEXT_DISABLED : Theme.CARD)
            .fontColor(this.activeIndex < 0 ? Color.White : Theme.TEXT_PRIMARY)
            .borderRadius(Theme.RADIUS_CARD)
            .border({ width: 1, color: Theme.LINE })
            .enabled(this.activeIndex >= 0)
            .onClick(() => {
              this.pick(-1);
            })

          Text('提示：每天真实记录 3 天、7 天、30 天会依次进入幼生期、成长期、成熟期')
            .fontSize(11).fontColor(Theme.TEXT_TERTIARY).width('100%')
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 8, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
