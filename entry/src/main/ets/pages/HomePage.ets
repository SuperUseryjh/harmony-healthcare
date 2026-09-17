import { hilog } from '@kit.PerformanceAnalysisKit';
import { AdviceItem } from '../engine/AdviceEngine';
import { FormatUtils } from '../utils/FormatUtils';
import { HomeData, HomeViewModel } from '../viewmodel/HomeViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'HomePage';

/** 打卡卡片的动作编号。-1 表示当前仅为状态展示，录入功能在后续阶段接入 */
const ACTION_NONE: number = -1;
const ACTION_WATER: number = 1;
const ACTION_ROUTINE: number = 2;

/**
 * @Builder 的参数载体。
 *
 * 必须包成"单个对象参数"：@Builder 默认按值传递，多个参数或按值传状态变量时，
 * 状态变化不会引起其内部 UI 刷新。只有"单个参数 + 对象字面量"才走按引用传递。
 */
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
  action: number = ACTION_NONE;
}

/**
 * 首页：今日总览。
 *
 * 每次打卡后都通过 HomeViewModel 重新取一份完整数据整体替换，
 * 界面不维护自己的副本，也就不存在"界面显示的数值和库里不一致"的问题。
 */
@Component
export struct HomePage {
  @State data: HomeData = new HomeData();
  @State busy: boolean = false;

  aboutToAppear(): void {
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
    if (action === ACTION_WATER) {
      await this.applyChange(HomeViewModel.addWater());
    } else if (action === ACTION_ROUTINE) {
      await this.applyChange(HomeViewModel.toggleRoutine());
    }
  }

  /** 环形进度的取值：摄入超过目标时封顶，避免进度环溢出 */
  private ringValue(): number {
    return Math.min(this.data.intakeKcal, Math.max(this.data.targetKcal, 1));
  }

  private ringTotal(): number {
    return Math.max(this.data.targetKcal, 1);
  }

  @Builder
  nutrientRow(param: NutrientParam) {
    Column({ space: 6 }) {
      Row() {
        Text(param.label).fontSize(14).fontColor('#4D4D4D')
        Blank()
        Text(`${Math.round(param.current)} / ${Math.round(param.target)} g`)
          .fontSize(13).fontColor('#8A8F99')
      }
      .width('100%')

      Progress({
        value: Math.min(param.current, Math.max(param.target, 1)),
        total: Math.max(param.target, 1),
        type: ProgressType.Linear
      })
        .color(param.barColor)
        .backgroundColor('#EEF1F6')
        .height(8)
    }
    .width('100%')
  }

  @Builder
  checkinCard(param: CheckinCardParam) {
    Column({ space: 6 }) {
      Row() {
        Text(param.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
        Blank()
        Text(param.hint)
          .fontSize(11)
          .fontColor(param.action === ACTION_NONE ? '#C2C7D0' : '#0A59F7')
      }
      .width('100%')

      Text(param.subtitle).fontSize(13).fontColor('#8A8F99').width('100%')
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .onClick(() => {
      void this.tapCard(param.action);
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {

        // 顶部：日期与连续天数
        Row() {
          Column({ space: 2 }) {
            Text(FormatUtils.formatDateLabelWithWeek(this.data.dateKey))
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text('今天').fontSize(13).fontColor('#8A8F99')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column({ space: 2 }) {
            Text(`${this.data.streakDays}`)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#0A59F7')
            Text('连续天数').fontSize(12).fontColor('#8A8F99')
          }
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor('#F5F8FF')
          .borderRadius(12)
        }
        .width('100%')

        // 热量进度环
        Stack() {
          Progress({
            value: this.ringValue(),
            total: this.ringTotal(),
            type: ProgressType.Ring
          })
            .width(196)
            .height(196)
            .color('#0A59F7')
            .backgroundColor('#E4E9F2')
            .style({ strokeWidth: 14 })

          Column({ space: 2 }) {
            Text('已摄入').fontSize(13).fontColor('#8A8F99')
            Text(`${Math.round(this.data.intakeKcal)}`)
              .fontSize(34).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text(`/ ${Math.round(this.data.targetKcal)} kcal`).fontSize(13).fontColor('#8A8F99')
            Text(`净 ${Math.round(this.data.intakeKcal - this.data.burnedKcal)} kcal`)
              .fontSize(12).fontColor('#B0B5BF').margin({ top: 4 })
          }
        }
        .width('100%')
        .height(220)
        .padding({ top: 10, bottom: 10 })
        .backgroundColor(Color.White)
        .borderRadius(16)

        // 健康分与运动消耗
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('健康分').fontSize(13).fontColor('#8A8F99')
            Row({ space: 3 }) {
              Text(`${this.data.score}`)
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#0A59F7')
              Text('/100').fontSize(12).fontColor('#8A8F99')
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)

          Column({ space: 4 }) {
            Text('运动消耗').fontSize(13).fontColor('#8A8F99')
            Row({ space: 3 }) {
              Text(`${Math.round(this.data.burnedKcal)}`)
                .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              Text('kcal').fontSize(12).fontColor('#8A8F99')
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(14)
        }
        .width('100%')

        // 营养素
        Column({ space: 12 }) {
          Text('营养素').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            .width('100%')
          this.nutrientRow({
            label: '蛋白质', current: this.data.proteinG,
            target: this.data.targetProteinG, barColor: '#0A59F7'
          })
          this.nutrientRow({
            label: '脂肪', current: this.data.fatG,
            target: this.data.targetFatG, barColor: '#E8A33D'
          })
          this.nutrientRow({
            label: '碳水', current: this.data.carbG,
            target: this.data.targetCarbG, barColor: '#28A76E'
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(16)

        // 打卡入口
        Column({ space: 12 }) {
          Row() {
            Text('今日打卡').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            Blank()
            Text(`已记录 ${this.data.mealCount} 餐`).fontSize(12).fontColor('#B0B5BF')
          }
          .width('100%')

          Row({ space: 12 }) {
            this.checkinCard({
              title: '三餐', subtitle: `已记录 ${this.data.mealCount} 餐`,
              hint: '录入待接入', action: ACTION_NONE
            })
            this.checkinCard({
              title: '运动', subtitle: `已运动 ${Math.round(this.data.activityMin)} 分钟`,
              hint: '录入待接入', action: ACTION_NONE
            })
          }
          .width('100%')

          Row({ space: 12 }) {
            this.checkinCard({
              title: '饮水',
              subtitle: `${Math.round(this.data.waterMl)} / ${Math.round(this.data.targetWaterMl)} ml`,
              hint: this.data.waterDone ? '已达标' : '+250ml',
              action: ACTION_WATER
            })
            this.checkinCard({
              title: '作息',
              subtitle: this.data.routineDone ? '今天作息规律' : '还没打卡',
              hint: this.data.routineDone ? '已打卡' : '点我打卡',
              action: ACTION_ROUTINE
            })
          }
          .width('100%')
        }
        .width('100%')

        // 新解锁徽章
        if (this.data.newBadgeNames.length > 0) {
          Column({ space: 6 }) {
            Text('解锁新徽章').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#8A5B00')
              .width('100%')
            Text(this.data.newBadgeNames.join('、')).fontSize(15).fontColor('#8A5B00')
              .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFF7E6')
          .borderRadius(14)
        }

        // 今日建议
        Column({ space: 12 }) {
          Text('今日建议').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            .width('100%')

          // 建议文案由 code 决定，因此 key 里带 code 即可保证内容变化时重建
          ForEach(this.data.advices, (item: AdviceItem) => {
            Row({ space: 10 }) {
              Divider()
                .vertical(true)
                .height(16)
                .strokeWidth(3)
                .color(item.severity === 1 ? '#E8A33D' : '#0A59F7')
              Text(item.text).fontSize(14).fontColor('#4D4D4D').layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }, (item: AdviceItem, index: number) => `${index}-${item.code}`)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(16)

        if (!this.data.hasProfile) {
          Text('尚未完成个人资料，目标值暂时无法计算')
            .fontSize(13).fontColor('#E8A33D').width('100%').textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F1F3F5')
    .scrollBar(BarState.Off)
  }
}
