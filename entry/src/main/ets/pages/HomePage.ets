import { hilog } from '@kit.PerformanceAnalysisKit';
import { AdviceItem } from '../engine/AdviceEngine';
import { FormatUtils } from '../utils/FormatUtils';
import { Theme } from '../utils/Theme';
import { HomeData, HomeViewModel } from '../viewmodel/HomeViewModel';
import { SectionTitle } from '../components/SectionTitle';
import { PetView } from '../components/PetView';

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

class PetBarParam {
  label: string = '';
  value: number = 0;
  color: string = '';
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
  /** 长按宠物卡片唤出调试面板 */
  onOpenPetDebug: () => void = () => {};
  /** 点击宠物卡片更换物种；把当前状态一并交给面板，缩略图按真实阶段渲染 */
  onOpenPetPicker: (code: string, stage: number, expression: number) => void = () => {};

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
  petBar(param: PetBarParam) {
    Row({ space: 8 }) {
      Text(param.label).fontSize(10).fontColor(Theme.TEXT_TERTIARY).width(24)
      Progress({ value: param.value, total: 100, type: ProgressType.Linear })
        .color(param.color)
        .backgroundColor(Theme.TRACK)
        .height(6)
        .layoutWeight(1)
      Text(`${Math.round(param.value)}`)
        .fontSize(10).fontColor(Theme.TEXT_TERTIARY).width(20).textAlign(TextAlign.End)
    }
    .width('100%')
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
      Column({ space: 16 }) {

        // 头部
                Row() {
          Column({ space: 5 }) {
            Text('今日概览')
              .fontSize(13)
              .fontColor(Theme.TEXT_TERTIARY)

            Text(FormatUtils.formatDateLabelWithWeek(this.data.dateKey))
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_PRIMARY)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 7 }) {
            Text('连续')
              .fontSize(11)
              .fontColor(Theme.TEXT_SECONDARY)

            Text(`${this.data.streakDays}`)
              .fontSize(23)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.PRIMARY)

            Text('天')
              .fontSize(11)
              .fontColor(Theme.TEXT_SECONDARY)
          }
          .height(42)
          .padding({
            left: 12,
            right: 12
          })
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.RADIUS_CHIP)
          .border({
            width: 1,
            color: Theme.PRIMARY_LINE
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 宠物：把"照顾它"和"坚持记录"做成同一件事，所以放在最显眼的位置
        Column({ space: 12 }) {
          Row({ space: 6 }) {
            PetView({
              imagePath: this.data.pet.imagePath,
              expression: this.data.pet.expression,
              stageScale: this.data.pet.stageScale,
              faceCx: this.data.pet.face.cx,
              faceCy: this.data.pet.face.cy,
              faceEyeDx: this.data.pet.face.eyeDx,
              faceEyeDy: this.data.pet.face.eyeDy,
              faceEyeR: this.data.pet.face.eyeR,
              faceBlushDx: this.data.pet.face.blushDx,
              faceBlushDy: this.data.pet.face.blushDy,
              faceBlushR: this.data.pet.face.blushR,
              faceSingle: this.data.pet.face.single
            })

            Column({ space: 9 }) {
              Row() {
                Text(`${this.data.speciesLabel} · ${this.data.pet.stageName}`)
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
                Text(` · 已陪伴 ${this.data.pet.growDays} 天`)
                  .fontSize(12).fontColor(Theme.TEXT_TERTIARY)
                Blank()
                Text(this.data.pet.isMaxStage ? '已成熟' : `再 ${this.data.pet.daysToNextStage} 天成长`)
                  .fontSize(11).fontColor(Theme.PRIMARY)
              }
              .width('100%')

              this.petBar({ label: '饱食', value: this.data.pet.fullness, color: Theme.PRIMARY })
              this.petBar({ label: '活力', value: this.data.pet.vitality, color: Theme.SUCCESS })
              this.petBar({ label: '心情', value: this.data.pet.mood, color: Theme.WARNING })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 8 }) {
            Text('')
              .width(3).height(14)
              .backgroundColor(Theme.PRIMARY)
              .borderRadius(2)
            Text(this.data.pet.message)
              .fontSize(13).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
            Text('更换 ›')
              .fontSize(11).fontColor(Theme.TEXT_TERTIARY)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })
        .onClick(() => {
          this.onOpenPetPicker(this.data.speciesCode, this.data.pet.stage,
            this.data.pet.expression);
        })
        // 长按唤出宠物调试：做成隐藏入口，正式演示时不会露出来
        .gesture(LongPressGesture().onAction(() => {
          this.onOpenPetDebug();
        }))

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
      .padding({ left: 20, right: 20, top: 20, bottom: 116 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
