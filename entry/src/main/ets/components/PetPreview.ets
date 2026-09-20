import { PetExpression } from '../engine/PetEngine';
import { Theme } from '../utils/Theme';
import { PetView } from './PetView';

/**
 * 带底框的宠物预览。
 *
 * 直接用 PetView 会把它塞进一个多参数的 @Builder 里，那样状态变了不刷新；
 * 包成组件后所有参数都走 @Prop，改脸的位置和大小能实时看到。
 */
@Component
export struct PetPreview {
  @Prop imagePath: string = '';
  @Prop showFace: boolean = true;
  @Prop stageScale: number = 1;
  @Prop faceCy: number = -2.6;
  @Prop faceEyeDx: number = 9.6;
  @Prop faceEyeR: number = 2.7;
  @Prop faceBlushDx: number = 18.6;
  @Prop faceBlushR: number = 3.3;
  @Prop boxHeight: number = 170;
  @Prop renderScale: number = 1.25;

  build() {
    Column() {
      PetView({
        imagePath: this.imagePath,
        expression: PetExpression.NORMAL,
        stageScale: this.stageScale,
        showFace: this.showFace,
        faceCy: this.faceCy,
        faceEyeDx: this.faceEyeDx,
        faceEyeR: this.faceEyeR,
        faceBlushDx: this.faceBlushDx,
        faceBlushR: this.faceBlushR,
        renderScale: this.renderScale
      })
    }
    .width('100%')
    .height(this.boxHeight)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.CARD)
    .borderRadius(Theme.RADIUS_CARD)
    .border({ width: 1, color: Theme.LINE })
  }
}
