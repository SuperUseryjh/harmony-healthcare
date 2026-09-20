import { PetExpression } from '../engine/PetEngine';
import { PetCatalog, PetSpecies, PetStage } from '../model/PetSpecies';
import { Theme } from '../utils/Theme';
import { PetView } from './PetView';

/** 每行放几个 */
const COLUMNS: number = 3;
/** 单个格子高度：缩略图(116×0.62≈72) + 文字 + 内边距 */
const CELL_HEIGHT: number = 108;
const GRID_GAP: number = 10;
const PREVIEW_SCALE: number = 0.62;

/**
 * 宠物选择网格。
 *
 * 首页的"换个伙伴"面板与初始化的第二步共用同一份实现，
 * 免得两处各写一套格子样式和选中逻辑，改一处漏一处。
 *
 * 缩略图用真实阶段渲染：当前在用的物种显示它此刻的样子，用户一眼能对上
 * "这就是我现在养的"；其余物种显示最终形态——否则刚玩两天的人看到的全是幼体，
 * 选不出喜欢哪个。
 */
@Component
export struct PetGrid {
  /** 高亮哪一格 */
  @Prop selectedCode: string = '';
  /** 当前在用的物种编码；初始化时还没有伙伴，传空串 */
  @Prop currentCode: string = '';
  @Prop currentStageIndex: number = 0;
  @Prop expression: number = PetExpression.NORMAL;
  /** 目录变动（新建 / 删除自建伙伴）时递增，用来触发网格重建 */
  @Prop listVersion: number = 0;

  onPick: (code: string) => void = () => {};

  private stageOf(spec: PetSpecies): PetStage {
    const last: number = spec.stages.length - 1;
    if (spec.code === this.currentCode) {
      return spec.stages[Math.min(this.currentStageIndex, last)];
    }
    return spec.stages[last];
  }

  /** Grid 没有自适应高度，按行数把高度算出来 */
  private gridHeight(): number {
    const rows: number = Math.ceil(PetCatalog.all().length / COLUMNS);
    return rows === 0 ? 0 : rows * CELL_HEIGHT + (rows - 1) * GRID_GAP;
  }

  build() {
    Grid() {
      // key 带 selectedCode：选中态变化时重建格子，否则边框和底色不会跟着变；
      // 带 listVersion：删掉自建伙伴后目录变了，也要重建
      ForEach(PetCatalog.all(), (spec: PetSpecies) => {
        GridItem() {
          Column({ space: 2 }) {
            PetView({
              imagePath: this.stageOf(spec).image,
              expression: this.expression,
              stageScale: this.stageOf(spec).scale,
              showFace: this.stageOf(spec).faceOn,
              faceCx: this.stageOf(spec).face.cx,
              faceCy: this.stageOf(spec).face.cy,
              faceEyeDx: this.stageOf(spec).face.eyeDx,
              faceEyeDy: this.stageOf(spec).face.eyeDy,
              faceEyeR: this.stageOf(spec).face.eyeR,
              faceBlushDx: this.stageOf(spec).face.blushDx,
              faceBlushDy: this.stageOf(spec).face.blushDy,
              faceBlushR: this.stageOf(spec).face.blushR,
              faceSingle: this.stageOf(spec).face.single,
              renderScale: PREVIEW_SCALE
            })

            // 自建伙伴的名字最长 8 个字，窄格子里放不下就省略，不要顶出格子
            Text(spec.label)
              .fontSize(12)
              .fontWeight(spec.code === this.selectedCode
                ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(spec.code === this.selectedCode
                ? Theme.PRIMARY : Theme.TEXT_SECONDARY)
              .width('100%')
              .padding({ left: 4, right: 4 })
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
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
          .stateStyles({ pressed: { .opacity(0.68) } })
          .onClick(() => {
            this.onPick(spec.code);
          })
        }
      }, (spec: PetSpecies) => `${spec.code}-${this.selectedCode}-${this.listVersion}`)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(GRID_GAP)
    .rowsGap(GRID_GAP)
    .width('100%')
    .height(this.gridHeight())
  }
}
