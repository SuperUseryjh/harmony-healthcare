import { hilog } from '@kit.PerformanceAnalysisKit';
import { ActivityType, Intensity } from '../model/Enums';
import { DateUtils } from '../utils/DateUtils';
import { Theme } from '../utils/Theme';
import { ActivityCheckinViewModel } from '../viewmodel/ActivityCheckinViewModel';
import { OverlayHeader } from '../components/OverlayHeader';
import { SegmentedBar } from '../components/SegmentedBar';

const DOMAIN: number = 0x0000;
const TAG: string = 'ActivityPage';

/** 展示顺序 ↔ 枚举取值的显式映射 */
const TYPE_LABELS: string[] = ['走路', '跑步', '骑行', '球类', '力量', '游泳', '其它'];
const TYPE_VALUES: number[] = [ActivityType.WALK, ActivityType.RUN, ActivityType.CYCLE,
  ActivityType.BALL, ActivityType.STRENGTH, ActivityType.SWIM, ActivityType.OTHER];

const INTENSITY_LABELS: string[] = ['低强度', '中强度', '高强度'];
const INTENSITY_VALUES: number[] = [Intensity.LOW, Intensity.MEDIUM, Intensity.HIGH];

/** 7 个类型排 3 列 = 3 行，用于给网格定高 */
const GRID_ROWS: number = 3;
const GRID_CELL_HEIGHT: number = 44;
const GRID_GAP: number = 8;

/**
 * 运动录入页（全屏覆盖）。
 *
 * 消耗量随"类型 / 强度 / 时长"三者实时变化——直接调用 engine 层的 MET 公式，
 * 用户在拖动时长时就能看到数字在动，比提交后再告诉结果更有反馈感。
 */
@Component
export struct ActivityPage {
  /** @param changed 是否写入了新数据 */
  onClose: (changed: boolean) => void = () => {};

  @State typeIndex: number = 0;
  @State intensityIndex: number = 1;
  @State minutes: number = 30;
  /** 0 表示档案缺失，此时代谢估算无法进行 */
  @State weightKg: number = 0;
  @State busy: boolean = false;

  aboutToAppear(): void {
    void this.loadWeight();
  }

  private async loadWeight(): Promise<void> {
    try {
      this.weightKg = await ActivityCheckinViewModel.currentWeightKg();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取体重失败: %{public}s', JSON.stringify(err));
    }
  }

  private estimatedKcal(): number {
    return ActivityCheckinViewModel.estimateKcal(this.weightKg,
      TYPE_VALUES[this.typeIndex], this.minutes, INTENSITY_VALUES[this.intensityIndex]);
  }

  private async commit(): Promise<void> {
    if (this.busy || this.weightKg <= 0) {
      return;
    }
    this.busy = true;
    try {
      await ActivityCheckinViewModel.commit(DateUtils.todayKey(),
        TYPE_VALUES[this.typeIndex], this.minutes,
        INTENSITY_VALUES[this.intensityIndex], this.estimatedKcal());
      this.onClose(true);
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存运动记录失败: %{public}s', JSON.stringify(err));
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      OverlayHeader({
        title: '记录运动',
        closeLabel: '取消',
        onClose: () => {
          this.onClose(false);
        }
      })

      Column({ space: 22 }) {

        // 预估消耗放在最上面：它是这次记录最关心的结果
        Column({ space: 6 }) {
          Text('预计消耗').fontSize(13).fontColor(Theme.TEXT_TERTIARY)
          Row({ space: 4 }) {
            Text(`${Math.round(this.estimatedKcal())}`)
              .fontSize(40).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
            Text('kcal').fontSize(14).fontColor(Theme.TEXT_SECONDARY)
              .margin({ bottom: 8 })
          }
          .alignItems(VerticalAlign.Bottom)
          Text(this.weightKg > 0
            ? `按体重 ${Math.round(this.weightKg)} kg 与 MET 公式估算`
            : '尚未完善个人资料，无法估算消耗')
            .fontSize(12).fontColor(this.weightKg > 0 ? Theme.TEXT_TERTIARY : Theme.WARNING)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 运动类型
        Column({ space: 12 }) {
          Text('运动类型').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
            .width('100%')
          Grid() {
            ForEach(TYPE_LABELS, (label: string, index: number) => {
              GridItem() {
                Text(label)
                  .width('100%')
                  .height('100%')
                  .textAlign(TextAlign.Center)
                  .fontSize(14)
                  .fontWeight(index === this.typeIndex ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(index === this.typeIndex ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
                  .backgroundColor(index === this.typeIndex ? Theme.PRIMARY_SOFT : Theme.CARD)
                  .borderRadius(Theme.RADIUS_CARD)
                  .border({ width: 1, color: index === this.typeIndex ? Theme.PRIMARY_LINE : Theme.LINE })
                  .onClick(() => {
                    this.typeIndex = index;
                  })
              }
            }, (label: string, index: number) => `type-${index}-${this.typeIndex}`)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(GRID_GAP)
          .rowsGap(GRID_GAP)
          .height(GRID_ROWS * GRID_CELL_HEIGHT + (GRID_ROWS - 1) * GRID_GAP)
        }
        .width('100%')

        // 强度
        Column({ space: 12 }) {
          Text('强度').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
            .width('100%')
          SegmentedBar({
            labels: INTENSITY_LABELS,
            selected: this.intensityIndex,
            onPick: (index: number) => {
              this.intensityIndex = index;
            }
          })
        }
        .width('100%')

        // 时长
        Column({ space: 12 }) {
          Row() {
            Text('时长').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
            Blank()
            Text(`${Math.round(this.minutes)} 分钟`).fontSize(14).fontColor(Theme.TEXT_SECONDARY)
          }
          .width('100%')

          Slider({ value: this.minutes, min: 5, max: 180, step: 5, style: SliderStyle.OutSet })
            .blockColor(Theme.PRIMARY).selectedColor(Theme.PRIMARY).trackColor(Theme.TRACK)
            .onChange((value: number) => {
              this.minutes = Math.round(value);
            })
        }
        .width('100%')

        Blank()
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 18, right: 18, top: 4 })
      .alignItems(HorizontalAlign.Start)

      Button(this.busy ? '保存中…' : '记录这次运动')
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor(this.weightKg > 0 ? Theme.PRIMARY : Theme.TEXT_DISABLED)
        .enabled(this.weightKg > 0 && !this.busy)
        .margin({ left: 18, right: 18, bottom: 24 })
        .onClick(() => {
          void this.commit();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
