import { Theme } from '../../utils/Theme';

/**
 * 桌面卡片 2×4：宠物 + 三项状态 + 热量进度 + 连续天数。
 *
 * 和 2×2 是两张独立的卡片，而不是一张卡片的两种尺寸：卡片尺寸一变，
 * 提供方不一定能收到通知，靠尺寸字段切换布局很容易出现"数据说 2×2、实际是 2×4"
 * 的错位。两张卡片各自固定一种尺寸，就没有这个问题。
 *
 * 布局原则和 2×2 一致：不用绝对长度，只靠百分比、layoutWeight 和字号——
 * 卡片配置里的 designWidth 会等比缩放长度单位，字号却不跟着缩，混着写就会走形。
 * 数据字段与 CardData 保持一致；进度条用两个色块拼，不用 Progress。
 */
let storage: LocalStorage = new LocalStorage();

/** @Builder 的参数载体：单对象参数才走按引用传递 */
class StatParam {
  label: string = '';
  value: number = 0;
  color: string = '';
}

@Entry(storage)
@Component
struct PetCard2x4 {
  @LocalStorageProp('petName') petName: string = '伙伴';
  @LocalStorageProp('message') message: string = '';
  @LocalStorageProp('stageName') stageName: string = '';
  @LocalStorageProp('growDays') growDays: number = 0;
  @LocalStorageProp('isMaxStage') isMaxStage: boolean = false;
  @LocalStorageProp('daysToNextStage') daysToNextStage: number = 0;
  @LocalStorageProp('fullness') fullness: number = 0;
  @LocalStorageProp('vitality') vitality: number = 0;
  @LocalStorageProp('mood') mood: number = 0;
  @LocalStorageProp('intakeKcal') intakeKcal: number = 0;
  @LocalStorageProp('targetKcal') targetKcal: number = 0;
  @LocalStorageProp('mealCount') mealCount: number = 0;
  @LocalStorageProp('streakDays') streakDays: number = 0;
  @LocalStorageProp('updatedAt') updatedAt: string = '';
  @LocalStorageProp('petImage') petImage: string = '';

  private stageLine(): string {
    return `${this.stageName} · 已陪伴 ${this.growDays} 天`;
  }

  private growthLine(): string {
    return this.isMaxStage ? '已经长大' : `再 ${this.daysToNextStage} 天成长`;
  }

  private intakePercent(): string {
    if (this.targetKcal <= 0) {
      return '0%';
    }
    const percent: number = this.intakeKcal / this.targetKcal * 100;
    return `${Math.max(0, Math.min(100, percent))}%`;
  }

  @Builder
  statBar(param: StatParam) {
    Row({ space: 6 }) {
      Text(param.label)
        .fontSize(11)
        .fontColor(Theme.TEXT_SECONDARY)
        .maxLines(1)

      Row() {
        Text('')
          .width(`${Math.max(0, Math.min(100, param.value))}%`)
          .height('100%')
          .backgroundColor(param.color)
      }
      .layoutWeight(1)
      .height(5)
      .backgroundColor(Theme.TRACK)
      .borderRadius(3)
      .clip(true)

      Text(`${param.value}`)
        .fontSize(11)
        .fontColor(Theme.TEXT_TERTIARY)
        .maxLines(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Row({ space: 12 }) {
      // 宠物：底托是一块柔和色板，图没准备好时也留着完整的构图
      Stack() {
        Text('')
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(16)

        if (this.petImage.length > 0) {
          Image('memory://' + this.petImage)
            .width('86%')
            .height('86%')
            .objectFit(ImageFit.Contain)
        }
      }
      .height('100%')
      .width('28%')

      Column({ space: 7 }) {
        Row({ space: 8 }) {
          Text(this.petName)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`连续 ${this.streakDays} 天`)
            .fontSize(11)
            .fontColor(Theme.PRIMARY)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Text(this.stageLine())
            .fontSize(11)
            .fontColor(Theme.TEXT_TERTIARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.growthLine())
            .fontSize(11)
            .fontColor(Theme.PRIMARY)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.statBar({ label: '饱食', value: this.fullness, color: Theme.PRIMARY })
        this.statBar({ label: '活力', value: this.vitality, color: Theme.SUCCESS })
        this.statBar({ label: '心情', value: this.mood, color: Theme.WARNING })

        Row({ space: 6 }) {
          Text('热量')
            .fontSize(11)
            .fontColor(Theme.TEXT_SECONDARY)
            .maxLines(1)

          Row() {
            Text('')
              .width(this.intakePercent())
              .height('100%')
              .backgroundColor(Theme.PRIMARY)
          }
          .layoutWeight(1)
          .height(5)
          .backgroundColor(Theme.TRACK)
          .borderRadius(3)
          .clip(true)

          Text(`${this.intakeKcal}/${this.targetKcal}`)
            .fontSize(11)
            .fontColor(Theme.TEXT_TERTIARY)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 8 }) {
          Text(this.message)
            .fontSize(11)
            .fontColor(Theme.TEXT_SECONDARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`今日 ${this.mealCount} 餐 · ${this.updatedAt}`)
            .fontSize(10)
            .fontColor(Theme.TEXT_TERTIARY)
            .maxLines(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { from: 'petCard' }
      });
    })
  }
}
