import { Theme } from '../../utils/Theme';

/**
 * 桌面卡片 2×2：宠物 + 一句台词 + 今天的热量。
 *
 * 卡片跑在桌面的进程里，拿不到数据库、也不能联网，数据由 EntryFormAbility
 * 通过 formBindingData 推过来，这里只按 key 取。字段名要和 CardData 一致。
 *
 * 布局刻意**不用绝对长度**，只用百分比、layoutWeight 和字号：
 * 卡片配置里写了 designWidth，长度单位会被按设计宽等比缩放，而字号是 fp、不跟着缩，
 * 一旦把字号和尺寸都按"设计单位"写（比如字号 34、图片 210），实际会渲成
 * 大字号挤在小框里——上一版就是这么翻车的。字号按正常页面的数值写，尺寸交给布局算。
 *
 * 另外卡片环境的组件有白名单限制，进度条用两个色块拼，没用 Progress。
 */
let storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct PetCard2x2 {
  @LocalStorageProp('petName') petName: string = '伙伴';
  @LocalStorageProp('message') message: string = '';
  @LocalStorageProp('stageName') stageName: string = '';
  @LocalStorageProp('intakeKcal') intakeKcal: number = 0;
  @LocalStorageProp('targetKcal') targetKcal: number = 0;
  @LocalStorageProp('streakDays') streakDays: number = 0;
  @LocalStorageProp('petImage') petImage: string = '';

  /** 名字 + 阶段，合成一行 */
  private titleLine(): string {
    if (this.stageName.length === 0) {
      return this.petName;
    }
    return `${this.petName} · ${this.stageName}`;
  }

  /** 热量进度，用两块色块拼；目标未知时按 0 处理 */
  private intakePercent(): string {
    if (this.targetKcal <= 0) {
      return '0%';
    }
    const percent: number = this.intakeKcal / this.targetKcal * 100;
    return `${Math.max(0, Math.min(100, percent))}%`;
  }

  build() {
    Column({ space: 6 }) {
      // 宠物：底托是一块柔和色板，图没准备好时也是一块完整的构图，不至于剩个空洞
      Stack() {
        Text('')
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(16)

        if (this.petImage.length > 0) {
          Image('memory://' + this.petImage)
            .width('84%')
            .height('84%')
            .objectFit(ImageFit.Contain)
        }
      }
      .width('100%')
      .layoutWeight(1)

      Text(this.titleLine())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Text(this.message)
        .fontSize(12)
        .fontColor(Theme.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 6 }) {
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

        Text(`连续 ${this.streakDays} 天`)
          .fontSize(11)
          .fontColor(Theme.PRIMARY)
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .onClick(() => {
      // 卡片上不做写入：打卡要选餐次、还要算汇总，那是应用里的活
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { from: 'petCard' }
      });
    })
  }
}
