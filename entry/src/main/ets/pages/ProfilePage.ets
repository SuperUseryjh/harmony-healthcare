import { hilog } from '@kit.PerformanceAnalysisKit';
import { FormatUtils } from '../utils/FormatUtils';
import { Theme } from '../utils/Theme';
import { MealReminderSetting } from '../service/MealReminderService';
import { BadgeView, ProfileData, ProfileViewModel } from '../viewmodel/ProfileViewModel';
import { SectionTitle } from '../components/SectionTitle';

const DOMAIN: number = 0x0000;
const TAG: string = 'ProfilePage';

/** 徽章墙列数与单元格高度，用于推算网格总高 */
const BADGE_COLUMNS: number = 3;
const BADGE_CELL_HEIGHT: number = 76;
const BADGE_GAP: number = 8;

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class InfoRowParam {
  label: string = '';
  value: string = '';
}

class BadgeCellParam {
  badge: BadgeView = new BadgeView();
}

class StatParam {
  label: string = '';
  value: string = '';
}

/**
 * "我的"页面：档案、累计数据、成就徽章。
 *
 * 编辑档案不另做一个表单，而是复用引导页——它本来就是同一份档案的录入界面，
 * 只是进入时改为预填已有数据。这样公式与校验永远只有一份。
 */
@Component
export struct ProfilePage {
  /** 由 Index 递增，表示数据可能已变化（含从编辑页返回） */
  @Prop @Watch('onDataChanged') dataVersion: number = 0;
  onEditProfile: () => void = () => {};

  @State data: ProfileData = new ProfileData();
  /** 提醒同步失败时的提示；空串表示无异常 */
  @State reminderMessage: string = '';

  aboutToAppear(): void {
    void this.reload();
  }

  onDataChanged(): void {
    void this.reload();
  }

  private async reload(): Promise<void> {
    try {
      this.data = await ProfileViewModel.load();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '加载个人数据失败: %{public}s', JSON.stringify(err));
    }
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private reminderSummary(): string {
    let count: number = 0;
    for (const setting of this.data.reminders) {
      if (setting.enabled) {
        count++;
      }
    }
    return count > 0 ? `已开启 ${count} 项` : '未开启';
  }

  private async toggleReminder(index: number, enabled: boolean): Promise<void> {
    this.reminderMessage =
      await ProfileViewModel.setReminderEnabled(this.data.reminders, index, enabled);
    // 整体重新取数：提醒设置嵌在 ProfileData 里，局部修改不会被 @State 观察到
    await this.reload();
  }

  /** 打开时间选择器，默认停在当前设置的时间上 */
  private pickTime(index: number, setting: MealReminderSetting): void {
    const preset: Date = new Date();
    preset.setHours(setting.hour, setting.minute, 0, 0);
    TimePickerDialog.show({
      selected: preset,
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        void this.applyTime(index, value.hour, value.minute);
      }
    });
  }

  private async applyTime(index: number, hour: number, minute: number): Promise<void> {
    this.reminderMessage =
      await ProfileViewModel.setReminderTime(this.data.reminders, index, hour, minute);
    await this.reload();
  }

  /** 徽章数量变化时网格高度要跟着变 */
  private badgeGridHeight(): number {
    const rows: number = Math.ceil(this.data.badges.length / BADGE_COLUMNS);
    return rows * BADGE_CELL_HEIGHT + (rows - 1) * BADGE_GAP;
  }

  @Builder
  infoRow(param: InfoRowParam) {
    Row() {
      Text(param.label).fontSize(14).fontColor(Theme.TEXT_SECONDARY)
      Blank()
      Text(param.value).fontSize(14).fontColor(Theme.TEXT_PRIMARY)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  @Builder
  statItem(param: StatParam) {
    Column({ space: 5 }) {
      Text(param.value)
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
        .letterSpacing(0.5)
      Text(param.label).fontSize(11).fontColor(Theme.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  badgeCell(param: BadgeCellParam) {
    Column({ space: 5 }) {
      Text(param.badge.name)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(param.badge.unlocked ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(param.badge.desc)
        .fontSize(10)
        .fontColor(param.badge.unlocked ? Theme.TEXT_TERTIARY : Theme.TEXT_DISABLED)
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(6)
    .backgroundColor(param.badge.unlocked ? Theme.PRIMARY_SOFT : Theme.TRACK)
    .borderRadius(Theme.RADIUS_CARD)
    .border({ width: 1, color: param.badge.unlocked ? Theme.PRIMARY_LINE : Theme.LINE })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {

        Text('我的')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
          .letterSpacing(1)
          .width('100%')

        // 每日目标
        Column({ space: 12 }) {
          Row() {
            Text('每日目标').fontSize(13).fontColor(Theme.TEXT_SECONDARY).letterSpacing(0.6)
            Blank()
            Text('重新测算')
              .fontSize(13)
              .fontColor(Theme.PRIMARY)
              .onClick(() => {
                this.onEditProfile();
              })
          }
          .width('100%')

          Row() {
            Text(`${Math.round(this.data.preview.targetKcal)}`)
              .fontSize(32).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
              .letterSpacing(1)
            Text(' kcal').fontSize(13).fontColor(Theme.TEXT_SECONDARY)
              .margin({ bottom: 6, left: 2 })
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)

          Row({ space: 12 }) {
            Text(`蛋白 ${Math.round(this.data.preview.proteinG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            Text(`脂肪 ${Math.round(this.data.preview.fatG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            Text(`碳水 ${Math.round(this.data.preview.carbG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            Blank()
            Text(`水 ${Math.round(this.data.preview.waterMl)}ml`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.PRIMARY_SOFT)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.PRIMARY_LINE })

        // 档案
        Column({ space: 6 }) {
          SectionTitle({ text: '我的档案' })
          this.infoRow({ label: '性别', value: FormatUtils.genderLabel(this.data.draft.gender) })
          this.infoRow({ label: '年龄', value: `${this.data.draft.age} 岁` })
          this.infoRow({ label: '身高', value: `${Math.round(this.data.draft.heightCm)} cm` })
          this.infoRow({ label: '体重', value: FormatUtils.formatKg(this.data.draft.weightKg) })
          this.infoRow({
            label: '日常活动量',
            value: FormatUtils.activityLevelLabel(this.data.draft.activityLevel)
          })
          this.infoRow({ label: '目标', value: FormatUtils.goalLabel(this.data.draft.goal) })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 饭点提醒：走系统日历，应用被杀也能准时提醒
        Column({ space: 12 }) {
          SectionTitle({
            text: '饭点提醒',
            accent: Theme.WARNING,
            trailing: this.reminderSummary()
          })

          ForEach(this.data.reminders, (setting: MealReminderSetting, index: number) => {
            Row() {
              Column({ space: 3 }) {
                Text(setting.label).fontSize(15).fontColor(Theme.TEXT_PRIMARY)
                Text(`${this.pad2(setting.hour)}:${this.pad2(setting.minute)}`)
                  .fontSize(13).fontColor(Theme.PRIMARY)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .onClick(() => {
                this.pickTime(index, setting);
              })

              Toggle({ type: ToggleType.Switch, isOn: setting.enabled })
                .selectedColor(Theme.PRIMARY)
                .onChange((isOn: boolean) => {
                  void this.toggleReminder(index, isOn);
                })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .alignItems(VerticalAlign.Center)
          }, (setting: MealReminderSetting, index: number) =>
              `${index}-${setting.enabled}-${setting.hour}-${setting.minute}`)

          if (this.reminderMessage.length > 0) {
            Text(this.reminderMessage).fontSize(12).fontColor(Theme.WARNING).width('100%')
          }

          Text('开启后会写入系统日历，应用关闭后也能准时收到提醒')
            .fontSize(11).fontColor(Theme.TEXT_TERTIARY).width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 累计数据
        Column({ space: 14 }) {
          SectionTitle({ text: '累计', accent: Theme.SUCCESS })
          Row({ space: 8 }) {
            this.statItem({ label: '有记录天数', value: `${this.data.stats.totalDays}` })
            this.statItem({ label: '最长连续', value: `${this.data.stats.maxStreakDays}` })
            this.statItem({ label: '饮食记录', value: `${this.data.stats.mealCount}` })
            this.statItem({ label: '运动记录', value: `${this.data.stats.activityCount}` })
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        // 徽章墙
        Column({ space: 14 }) {
          SectionTitle({
            text: '成就徽章',
            accent: Theme.WARNING,
            trailing: `${this.data.stats.badgeCount} / ${this.data.stats.badgeTotal}`
          })

          Grid() {
            ForEach(this.data.badges, (badge: BadgeView) => {
              GridItem() {
                this.badgeCell({ badge: badge })
              }
            }, (badge: BadgeView) => `${badge.code}-${badge.unlocked}`)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(BADGE_GAP)
          .rowsGap(BADGE_GAP)
          .height(this.badgeGridHeight())
        }
        .width('100%')
        .padding(18)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })
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
