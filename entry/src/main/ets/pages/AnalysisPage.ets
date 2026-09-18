import { hilog } from '@kit.PerformanceAnalysisKit';
import { FormatUtils } from '../utils/FormatUtils';
import { Theme } from '../utils/Theme';
import { AnalysisData, AnalysisViewModel, BarStatus, ChartBar } from '../viewmodel/AnalysisViewModel';
import { SectionTitle } from '../components/SectionTitle';
import { SegmentedBar } from '../components/SegmentedBar';

const DOMAIN: number = 0x0000;
const TAG: string = 'AnalysisPage';

const PERIOD_LABELS: string[] = ['近 7 天', '近 30 天'];
const PERIOD_DAYS: number[] = [7, 30];

/** 柱体高度区间：无记录的组也留一条底座，否则看起来像漏了数据 */
const BAR_MAX_HEIGHT: number = 96;
const BAR_MIN_HEIGHT: number = 4;

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class MetricParam {
  label: string = '';
  value: string = '';
  highlight: boolean = false;
}

class RatioRowParam {
  label: string = '';
  actual: number = 0;
  target: number = 0;
  barColor: string = '';
}

class BarParam {
  bar: ChartBar = new ChartBar();
  height: number = BAR_MIN_HEIGHT;
  color: string = Theme.BAR_EMPTY;
  showValue: boolean = true;
}

/**
 * 趋势分析页。
 *
 * 图表用最朴素的"按比例定高的色块"实现，没有引入图表库——
 * 需求只是表达摄入相对目标的偏离，堆叠视图层级反而更容易出错。
 *
 * 30 天视图下一天一根柱子会挤成一片，因此由视图模型按 6 天一组聚合成 5 根，
 * 柱高是组内日均，柱顶直接标数值——比靠刻度估算更实用。
 */
@Component
export struct AnalysisPage {
  /** 由 Index 递增，表示数据可能已变化 */
  @Prop @Watch('onDataChanged') dataVersion: number = 0;

  @State data: AnalysisData = new AnalysisData();
  @State periodIndex: number = 0;

  aboutToAppear(): void {
    void this.reload();
  }

  onDataChanged(): void {
    void this.reload();
  }

  private async reload(): Promise<void> {
    try {
      this.data = await AnalysisViewModel.load(PERIOD_DAYS[this.periodIndex]);
    } catch (err) {
      hilog.error(DOMAIN, TAG, '加载趋势数据失败: %{public}s', JSON.stringify(err));
    }
  }

  private barHeight(bar: ChartBar): number {
    return BAR_MIN_HEIGHT + bar.heightRatio * BAR_MAX_HEIGHT;
  }

  /** 视图模型只给状态，颜色在页面层映射，避免视图模型依赖主题 */
  private barColor(status: number): string {
    if (status === BarStatus.OK) {
      return Theme.SUCCESS;
    }
    if (status === BarStatus.OVER) {
      return Theme.WARNING;
    }
    if (status === BarStatus.UNDER) {
      return Theme.BAR_UNDER;
    }
    return Theme.BAR_EMPTY;
  }

  /** 归一化到 0-1，供 Progress 取值 */
  private ratioValue(ratio: number): number {
    return Math.max(0, Math.min(1, ratio));
  }

  /** 图表标题里的"口径"说明，避免用户误读柱高代表什么 */
  private chartHint(): string {
    if (this.data.bucketDays <= 1) {
      return '每根柱 = 当天';
    }
    return `每根柱 = 每 ${this.data.bucketDays} 天的日均`;
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
  ratioRow(param: RatioRowParam) {
    Column({ space: 7 }) {
      Row() {
        Text(param.label).fontSize(14).fontColor(Theme.TEXT_SECONDARY)
        Blank()
        Text(`实际 ${FormatUtils.formatPercent(param.actual)} · 目标 ${FormatUtils.formatPercent(param.target)}`)
          .fontSize(12).fontColor(Theme.TEXT_TERTIARY)
      }
      .width('100%')

      Progress({ value: this.ratioValue(param.actual), total: 1, type: ProgressType.Linear })
        .color(param.barColor)
        .backgroundColor(Theme.TRACK)
        .height(7)
    }
    .width('100%')
  }

  @Builder
  barColumn(param: BarParam) {
    Column({ space: 5 }) {
      // 柱顶直接标数值：只有 5-7 根柱子，有空间写清楚
      if (param.showValue) {
        Text(`${Math.round(param.bar.avgIntake)}`)
          .fontSize(10)
          .fontColor(Theme.TEXT_SECONDARY)
      } else {
        Text('').fontSize(10)
      }

      Text('')
        .width('100%')
        .height(param.height)
        .backgroundColor(param.color)
        .borderRadius(3)

      Text(param.bar.label).fontSize(10).fontColor(Theme.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.End)
  }

  @Builder
  legendDot(color: string, label: string) {
    Row({ space: 5 }) {
      // 同 HomePage：避免使用需要 API 26 的 Circle().fill()
      Text('')
        .width(7).height(7)
        .backgroundColor(color)
        .borderRadius(4)
      Text(label).fontSize(11).fontColor(Theme.TEXT_TERTIARY)
    }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {

        Text('趋势分析')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
          .letterSpacing(1)
          .width('100%')

        SegmentedBar({
          labels: PERIOD_LABELS,
          selected: this.periodIndex,
          onPick: (index: number) => {
            this.periodIndex = index;
            void this.reload();
          }
        })

        // 周期汇总
        Column({ space: 14 }) {
          Row({ space: 8 }) {
            this.metric({
              label: '日均摄入 kcal', value: `${Math.round(this.data.avgIntake)}`, highlight: false
            })
            this.metric({
              label: '日均消耗 kcal', value: `${Math.round(this.data.avgBurned)}`, highlight: false
            })
            this.metric({
              label: '日均健康分', value: `${Math.round(this.data.avgScore)}`, highlight: true
            })
          }
          .width('100%')

          Divider().color(Theme.DIVIDER)

          Row({ space: 8 }) {
            this.metric({
              label: '已记录天数', value: `${this.data.recordedDays}`, highlight: false
            })
            this.metric({
              label: '摄入达标天数', value: `${this.data.goalMetDays}`, highlight: false
            })
            this.metric({
              label: '日均打卡项', value: this.data.avgCheckinCount.toFixed(1), highlight: false
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 摄入趋势
        Column({ space: 14 }) {
          SectionTitle({
            text: '摄入趋势',
            trailing: this.data.targetKcal > 0 ? `目标 ${Math.round(this.data.targetKcal)} kcal` : '目标未知'
          })

          Text(this.chartHint()).fontSize(11).fontColor(Theme.TEXT_TERTIARY).width('100%')

          Row({ space: this.data.bars.length > 7 ? 4 : 10 }) {
            ForEach(this.data.bars, (bar: ChartBar) => {
              this.barColumn({
                bar: bar,
                height: this.barHeight(bar),
                color: this.barColor(bar.status),
                showValue: bar.recordedDays > 0
              })
            }, (bar: ChartBar, index: number) => `${index}-${bar.label}-${Math.round(bar.avgIntake)}-${bar.status}`)
          }
          .width('100%')
          .height(BAR_MAX_HEIGHT + BAR_MIN_HEIGHT + 34)
          .alignItems(VerticalAlign.Bottom)

          Row({ space: 14 }) {
            this.legendDot(Theme.SUCCESS, '达标')
            this.legendDot(Theme.BAR_UNDER, '偏少')
            this.legendDot(Theme.WARNING, '偏多')
            this.legendDot(Theme.BAR_EMPTY, '无记录')
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 营养配比
        Column({ space: 14 }) {
          SectionTitle({
            text: '营养配比',
            accent: Theme.SUCCESS,
            trailing: this.data.hasMacroData
              ? `与目标相似度 ${FormatUtils.formatPercent(this.data.similarity)}`
              : '暂无数据'
          })

          this.ratioRow({
            label: '蛋白质', actual: this.data.actualRatio.protein,
            target: this.data.targetRatio.protein, barColor: Theme.PRIMARY
          })
          this.ratioRow({
            label: '脂肪', actual: this.data.actualRatio.fat,
            target: this.data.targetRatio.fat, barColor: Theme.WARNING
          })
          this.ratioRow({
            label: '碳水', actual: this.data.actualRatio.carb,
            target: this.data.targetRatio.carb, barColor: Theme.SUCCESS
          })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        if (this.data.recordedDays === 0) {
          Text('这个周期还没有记录，去首页打个卡吧')
            .fontSize(13).fontColor(Theme.TEXT_TERTIARY).width('100%').textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      // 底部留出 Dock 的高度
      .padding({ left: 18, right: 18, top: 22, bottom: 108 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
