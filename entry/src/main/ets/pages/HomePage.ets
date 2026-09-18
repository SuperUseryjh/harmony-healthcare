import { hilog } from '@kit.PerformanceAnalysisKit';
import { AdviceItem } from '../engine/AdviceEngine';
import { FormatUtils } from '../utils/FormatUtils';
import { Theme } from '../utils/Theme';
import { HomeData, HomeViewModel } from '../viewmodel/HomeViewModel';
import { SectionTitle } from '../components/SectionTitle';

const DOMAIN: number = 0x0000;
const TAG: string = 'HomePage';

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class NutrientParam {
  label: string = '';
  current: number = 0;
  target: number = 0;
  barColor: string = '';
}

class CheckinCardParam {
  title: string = '';
  subtitle: string = '';
  hint: string = '';
  done: boolean = false;
  action: number = 0;
}

class MetricParam {
  label: string = '';
  value: string = '';
  highlight: boolean = false;
}

/**
 * 首页：今日总览。
 *
 * 打卡区刻意不做成一张大卡里的四行，而是四张独立卡片浮在纸上——
 * 视觉上它们和"热量"是同级的入口，包进一张卡会让它们看起来像附属信息。
 */
@Component
export struct HomePage {
  /** 由 Index 递增，表示数据可能已变化 */
  @Prop @Watch('onDataChanged') dataVersion: number = 0;
  /** @param mealType 预选的餐次，传 -1 表示用默认餐次 */
  onOpenCheckin: (mealType: number) => void = () => {};
  onOpenActivity: () => void = () => {};

  @State data: HomeData = new HomeData();
  @State busy: boolean = false;

  aboutToAppear(): void {
    void this.reload();
  }

  onDataChanged(): void {
    void this.reload();
  }

  private async reload(): Promise<void> {
    this.busy = true;
    try {
      this.data = await HomeViewModel.load();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '加载首页数据失败: %{public}s', JSON.stringify(err));
    } finally {
      this.busy = false;
    }
  }

  private async applyChange(action: Promise<HomeData>): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      this.data = await action;
    } catch (err) {
      hilog.error(DOMAIN, TAG, '打卡失败: %{public}s', JSON.stringify(err));
    } finally {
      this.busy = false;
    }
  }

  private async tapCard(action: number): Promise<void> {
    if (action === 1) {
      await this.applyChange(HomeViewModel.addWater());
    } else if (action === 2) {
      await this.applyChange(HomeViewModel.toggleRoutine());
    } else if (action === 3) {
      this.onOpenCheckin(-1);
    } else if (action === 4) {
      this.onOpenActivity();
    }
  }

  private ringValue(): number {
    return Math.min(this.data.intakeKcal, Math.max(this.data.targetKcal, 1));
  }

  private ringTotal(): number {
    return Math.max(this.data.targetKcal, 1);
  }

  @Builder
  metric(param: MetricParam) {
    Column({ space: 4 }) {
      Text(param.value)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(param.highlight ? Theme.PRIMARY : Theme.TEXT_PRIMARY)
        .letterSpacing(0.5)
      Text(param.label).fontSize(11).fontColor(Theme.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  nutrientRow(param: NutrientParam) {
    Column({ space: 7 }) {
      Row() {
        Text(param.label).fontSize(14).fontColor(Theme.TEXT_SECONDARY)
        Blank()
        Text(`${Math.round(param.current)} / ${Math.round(param.target)} g`)
          .fontSize(13).fontColor(Theme.TEXT_TERTIARY)
      }
      .width('100%')

      Progress({
        value: Math.min(param.current, Math.max(param.target, 1)),
        total: Math.max(param.target, 1),
        type: ProgressType.Linear
      })
        .color(param.barColor)
        .backgroundColor(Theme.TRACK)
        .height(7)
    }
    .width('100%')
  }

  @Builder
  checkinCard(param: CheckinCardParam) {
    Column({ space: 7 }) {
      Row({ space: 7 }) {
        // 用定尺寸的空 Text 画状态点：Circle().fill() 要 API 26，
        // 而本工程 compatibleSdkVersion 是 6.1.0(23)，用它会有兼容性警告
        Text('')
          .width(7).height(7)
          .backgroundColor(param.done ? Theme.SUCCESS : Theme.TRACK)
          .borderRadius(4)
        Text(param.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
        Blank()
      }
      .width('100%')

      Text(param.subtitle).fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%')
      Text(param.hint).fontSize(12).fontColor(Theme.PRIMARY).width('100%')
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Theme.CARD)
    .borderRadius(Theme.RADIUS_CARD)
    .border({ width: 1, color: Theme.LINE })
    .onClick(() => {
      void this.tapCard(param.action);
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {

        // 头部
        Row() {
          Column({ space: 4 }) {
            Text('今天').fontSize(12).fontColor(Theme.TEXT_TERTIARY).letterSpacing(1)
            Text(FormatUtils.formatDateLabelWithWeek(this.data.dateKey))
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
              .letterSpacing(0.8)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text(`${this.data.streakDays}`)
              .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
            Text('连续天数').fontSize(11).fontColor(Theme.TEXT_TERTIARY)
          }
          .padding({ left: 16, right: 16, top: 7, bottom: 7 })
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.RADIUS_CARD)
          .border({ width: 1, color: Theme.LINE })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 饭点提醒：正处在饭点窗口且该餐还没记录时，给一条可点的提示
        if (this.data.showMealPrompt) {
          Row({ space: 10 }) {
            Text('')
              .width(3).height(30)
              .backgroundColor(Theme.PRIMARY)
              .borderRadius(2)
            Column({ space: 3 }) {
              Text(this.data.mealPromptTitle)
                .fontSize(14).fontWeight(FontWeight.Medium).fontColor(Theme.PRIMARY)
              Text(this.data.mealPromptDesc).fontSize(12).fontColor(Theme.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('去记录').fontSize(13).fontColor(Theme.PRIMARY)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.RADIUS_CARD)
          .border({ width: 1, color: Theme.PRIMARY_LINE })
          .onClick(() => {
            this.onOpenCheckin(this.data.mealPromptMealType);
          })
        } else if (this.data.nextMealHint.length > 0) {
          Row({ space: 8 }) {
            Text('')
              .width(5).height(5)
              .backgroundColor(Theme.TEXT_TERTIARY)
              .borderRadius(3)
            Text(this.data.nextMealHint).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            Blank()
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
        }

        // 热量主卡
        Column({ space: 14 }) {
          Stack() {
            Progress({
              value: this.ringValue(),
              total: this.ringTotal(),
              type: ProgressType.Ring
            })
              .width(180)
              .height(180)
              .color(Theme.PRIMARY)
              .backgroundColor(Theme.TRACK)
              .style({ strokeWidth: 12 })

            Column({ space: 2 }) {
              Text('已摄入').fontSize(12).fontColor(Theme.TEXT_TERTIARY).letterSpacing(1)
              Text(`${Math.round(this.data.intakeKcal)}`)
                .fontSize(34).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
                .letterSpacing(1)
              Text(`/ ${Math.round(this.data.targetKcal)} kcal`)
                .fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            }
          }
          .width('100%')
          .height(190)

          Divider().color(Theme.DIVIDER)

          Row({ space: 8 }) {
            this.metric({
              label: '目标 kcal', value: `${Math.round(this.data.targetKcal)}`, highlight: false
            })
            this.metric({
              label: '运动消耗', value: `${Math.round(this.data.burnedKcal)}`, highlight: false
            })
            this.metric({
              label: '健康分', value: `${this.data.score}`, highlight: true
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 打卡入口
        Column({ space: 12 }) {
          SectionTitle({ text: '今日打卡', trailing: `已记录 ${this.data.mealCount} 餐` })

          Row({ space: 12 }) {
            this.checkinCard({
              title: '三餐', subtitle: `已记录 ${this.data.mealCount} 餐`,
              hint: '去记录', done: this.data.mealCount > 0, action: 3
            })
            this.checkinCard({
              title: '运动', subtitle: `已运动 ${Math.round(this.data.activityMin)} 分钟`,
              hint: '去记录', done: this.data.activityMin > 0, action: 4
            })
          }
          .width('100%')

          Row({ space: 12 }) {
            this.checkinCard({
              title: '饮水',
              subtitle: `${Math.round(this.data.waterMl)} / ${Math.round(this.data.targetWaterMl)} ml`,
              hint: this.data.waterDone ? '已达标' : '+250ml',
              done: this.data.waterDone, action: 1
            })
            this.checkinCard({
              title: '作息',
              subtitle: this.data.routineDone ? '今天作息规律' : '还没有打卡',
              hint: this.data.routineDone ? '已打卡' : '点我打卡',
              done: this.data.routineDone, action: 2
            })
          }
          .width('100%')
        }
        .width('100%')

        // 营养素
        Column({ space: 14 }) {
          SectionTitle({ text: '营养素', accent: Theme.SUCCESS })
          this.nutrientRow({
            label: '蛋白质', current: this.data.proteinG,
            target: this.data.targetProteinG, barColor: Theme.PRIMARY
          })
          this.nutrientRow({
            label: '脂肪', current: this.data.fatG,
            target: this.data.targetFatG, barColor: Theme.WARNING
          })
          this.nutrientRow({
            label: '碳水', current: this.data.carbG,
            target: this.data.targetCarbG, barColor: Theme.SUCCESS
          })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 新解锁徽章
        if (this.data.newBadgeNames.length > 0) {
          Row({ space: 10 }) {
            Text('')
              .width(7).height(7)
              .backgroundColor(Theme.WARNING)
              .borderRadius(4)
            Column({ space: 3 }) {
              Text('解锁新徽章').fontSize(12).fontColor(Theme.GOLD_TEXT).letterSpacing(0.6)
              Text(this.data.newBadgeNames.join('、')).fontSize(15).fontColor(Theme.GOLD_TEXT)
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.WARNING_SOFT)
          .borderRadius(Theme.RADIUS_CARD)
          .border({ width: 1, color: Theme.WARNING_LINE })
        }

        // 今日建议
        Column({ space: 14 }) {
          SectionTitle({ text: '今日建议', accent: Theme.WARNING })

          ForEach(this.data.advices, (item: AdviceItem) => {
            Row({ space: 10 }) {
              Divider()
                .vertical(true)
                .height(15)
                .strokeWidth(3)
                .color(item.severity === 1 ? Theme.WARNING : Theme.PRIMARY)
              Text(item.text).fontSize(14).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (item: AdviceItem, index: number) => `${index}-${item.code}`)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        if (!this.data.hasProfile) {
          Text('尚未完成个人资料，目标值暂时无法计算')
            .fontSize(13).fontColor(Theme.WARNING).width('100%').textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      // 底部留出 Dock 的高度，避免最后一张卡被悬浮栏压住
      .padding({ left: 18, right: 18, top: 22, bottom: 108 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
