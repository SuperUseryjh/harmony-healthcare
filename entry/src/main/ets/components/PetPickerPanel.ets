import { PetExpression, PetStage } from '../engine/PetEngine';
import { PET_SPECIES, PetSpecies, PetSpeciesCatalog } from '../model/PetSpecies';
import { Theme } from '../utils/Theme';
import { OverlayHeader } from './OverlayHeader';
import { PetView } from './PetView';

/** 选择面板每行放几个 */
const COLUMNS: number = 3;
/** 单个格子高度：缩略图(116×0.62≈72) + 文字 + 内边距 */
const CELL_HEIGHT: number = 108;
const GRID_GAP: number = 10;

/**
 * 宠物选择面板（全屏覆盖，点首页宠物卡片唤出）。
 *
 * 缩略图用真实的阶段与表情渲染，而不是画一组抽象图标——
 * 用户看到的直接就是"换成它之后长什么样"。
 */
@Component
export struct PetPickerPanel {
  /** 当前正在使用的物种，用于高亮 */
  @Prop currentCode: string = PetSpeciesCatalog.defaultCode();
  /** 用真实的阶段与表情渲染缩略图 */
  @Prop stage: number = PetStage.EGG;
  @Prop expression: number = PetExpression.NORMAL;

  onClose: () => void = () => {};
  /** 选中某个物种；保存与刷新由 Index 统一处理 */
  onPick: (code: string) => void = () => {};

  /** 面板内的即时高亮，不等外部刷新 */
  @State selectedCode: string = '';

  aboutToAppear(): void {
    this.selectedCode = this.currentCode;
  }

  build() {
    Column() {
      OverlayHeader({
        title: '换个伙伴',
        closeLabel: '关闭',
        onClose: () => {
          this.onClose();
        }
      })

      Scroll() {
        Column({ space: 14 }) {
          Text('选一个陪你坚持的伙伴。水果不走孵化，会直接从青果开始慢慢长大。')
            .fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%')

          Grid() {
            // key 带 selectedCode：选中态变化时重建格子，否则边框和底色不会跟着变
            ForEach(PET_SPECIES, (spec: PetSpecies) => {
              GridItem() {
                Column({ space: 2 }) {
                  PetView({
                    speciesCode: spec.code,
                    stage: this.stage,
                    expression: this.expression,
                    renderScale: 0.62
                  })
                  Text(spec.label)
                    .fontSize(12)
                    .fontWeight(spec.code === this.selectedCode
                      ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(spec.code === this.selectedCode
                      ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
                }
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .backgroundColor(spec.code === this.selectedCode
                  ? Theme.PRIMARY_SOFT : Theme.CARD)
                .borderRadius(Theme.RADIUS_CARD)
                .border({
                  width: spec.code === this.selectedCode ? 1.5 : 1,
                  color: spec.code === this.selectedCode ? Theme.PRIMARY : Theme.LINE
                })
                .onClick(() => {
                  this.selectedCode = spec.code;
                  this.onPick(spec.code);
                })
              }
            }, (spec: PetSpecies) => `${spec.code}-${this.selectedCode}`)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(GRID_GAP)
          .rowsGap(GRID_GAP)
          .width('100%')
          .height(Math.ceil(PET_SPECIES.length / COLUMNS) * CELL_HEIGHT
            + (Math.ceil(PET_SPECIES.length / COLUMNS) - 1) * GRID_GAP)

          Text('阶段由累计记录天数决定：3 天、7 天、30 天各进一级')
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
