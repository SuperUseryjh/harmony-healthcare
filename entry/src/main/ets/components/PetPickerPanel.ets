import { PetExpression } from '../engine/PetEngine';
import { PetCatalog, PetSpecies, PetStage } from '../model/PetSpecies';
import { Theme } from '../utils/Theme';
import { OverlayHeader } from './OverlayHeader';
import { PetView } from './PetView';

/** 选择面板每行放几个 */
const COLUMNS: number = 3;
/** 单个格子高度：缩略图(116×0.62≈72) + 文字 + 内边距 */
const CELL_HEIGHT: number = 108;
const GRID_GAP: number = 10;
const PREVIEW_SCALE: number = 0.62;

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class PreviewParam {
  stage: PetStage = new PetStage();
  expression: number = PetExpression.NORMAL;
}

/**
 * 宠物选择面板（全屏覆盖，点首页宠物卡片唤出）。
 *
 * 物种列表来自 pet_config.json，加物种不需要改这里。
 * 缩略图用真实阶段渲染：当前在用的物种显示它此刻的样子，
 * 其他物种显示最终形态——否则刚玩两天的人看到的全是幼体，选不出喜欢哪个。
 */
@Component
export struct PetPickerPanel {
  @Prop currentCode: string = '';
  /** 当前物种所处的阶段下标 */
  @Prop currentStageIndex: number = 0;
  @Prop expression: number = PetExpression.NORMAL;

  onClose: () => void = () => {};
  /** 选中某个物种；保存与刷新由 Index 统一处理 */
  onPick: (code: string) => void = () => {};

  /** 面板内的即时高亮，不等外部刷新 */
  @State selectedCode: string = '';

  aboutToAppear(): void {
    this.selectedCode = this.currentCode;
  }

  private previewStageOf(spec: PetSpecies): PetStage {
    const last: number = spec.stages.length - 1;
    if (spec.code === this.currentCode) {
      return spec.stages[Math.min(this.currentStageIndex, last)];
    }
    return spec.stages[last];
  }

  @Builder
  preview(param: PreviewParam) {
    PetView({
      imagePath: param.stage.image,
      expression: param.expression,
      stageScale: param.stage.scale,
      faceCx: param.stage.face.cx,
      faceCy: param.stage.face.cy,
      faceEyeDx: param.stage.face.eyeDx,
      faceEyeDy: param.stage.face.eyeDy,
      faceEyeR: param.stage.face.eyeR,
      faceBlushDx: param.stage.face.blushDx,
      faceBlushDy: param.stage.face.blushDy,
      faceBlushR: param.stage.face.blushR,
      faceSingle: param.stage.face.single,
      renderScale: PREVIEW_SCALE
    })
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
          Text('造型和进阶规则都来自 pet_config.json，换 PNG 只需要改配置里的文件名')
            .fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%')

          Grid() {
            // key 带 selectedCode：选中态变化时重建格子，否则边框和底色不会跟着变
            ForEach(PetCatalog.all(), (spec: PetSpecies) => {
              GridItem() {
                Column({ space: 2 }) {
                  this.preview({ stage: this.previewStageOf(spec), expression: this.expression })
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
          .height(Math.ceil(PetCatalog.all().length / COLUMNS) * CELL_HEIGHT
            + (Math.ceil(PetCatalog.all().length / COLUMNS) - 1) * GRID_GAP)

          Text(`共 ${PetCatalog.all().length} 个伙伴，可自行往 pet_config.json 里加`)
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
