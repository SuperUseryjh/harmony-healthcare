import { PetExpression } from '../engine/PetEngine';

/** 图片与表情共用的逻辑坐标系尺寸，所有造型资源都按这个尺寸产出 */
const CANVAS_WIDTH: number = 112;
const CANVAS_HEIGHT: number = 116;

const INK: string = '#5A4B3C';
const BLUSH: string = '#F2B49E';

/**
 * 宠物形象。
 *
 * 身体来自配置指定的图片（SVG 或 PNG 都能用），表情另外叠加——
 * 因为体型只跟阶段有关，而表情要随当天的数据实时变，两者生命周期不同，
 * 烘焙进同一张图就得为「阶段 × 表情」准备 9 倍资源。
 *
 * 表情的位置、大小来自物种配置，并按该阶段的 scale 一起缩放，
 * 所以身体变小时表情也跟着小，不会出现"小身体顶着大脸"。
 *
 * 注意成员名不要撞 ArkUI 的内置属性名（width/height/overlay/tabIndex 等），
 * 这类冲突会直接编译失败。
 */
@Component
export struct PetView {
  /** 当前阶段的图片，rawfile 下的相对路径 */
  @Prop @Watch('onStateChanged') imagePath: string = '';
  @Prop @Watch('onStateChanged') expression: number = PetExpression.NORMAL;
  /** 当前阶段整体缩放，表情要跟着一起缩 */
  @Prop @Watch('onStateChanged') stageScale: number = 1;

  /** 表情叠加位置，来自配置的阶段脸型 */
  @Prop @Watch('onStateChanged') faceCx: number = 0;
  @Prop @Watch('onStateChanged') faceCy: number = -2.6;
  @Prop @Watch('onStateChanged') faceEyeDx: number = 9.6;
  @Prop @Watch('onStateChanged') faceEyeDy: number = 0;
  @Prop @Watch('onStateChanged') faceEyeR: number = 2.7;
  @Prop @Watch('onStateChanged') faceBlushDx: number = 18.6;
  @Prop @Watch('onStateChanged') faceBlushDy: number = 7.7;
  @Prop @Watch('onStateChanged') faceBlushR: number = 3.3;
  /** true = 侧脸，只有一只眼、一块腮红 */
  @Prop @Watch('onStateChanged') faceSingle: boolean = false;

  /** 渲染倍数：选择面板里用小于 1 的值显示缩略图 */
  @Prop @Watch('onStateChanged') renderScale: number = 1.0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 就绪前不能绘制，此时只记录状态，由 onReady 补画 */
  private ready: boolean = false;

  /**
   * @Prop 变化时组件会重新渲染，但 Canvas 的内容是绘制上去的，不会跟着变，
   * 所以表情层必须显式重绘。图片那层由框架自己换。
   */
  onStateChanged(): void {
    if (this.ready) {
      this.drawFace();
    }
  }

  private dot(x: number, y: number, radius: number, color: string): void {
    this.ctx.beginPath();
    this.ctx.arc(x, y, radius, 0, Math.PI * 2);
    this.ctx.closePath();
    this.ctx.fillStyle = color;
    this.ctx.fill();
  }

  /** 表情靠眼睛传达：开心是弯月眼，其余是圆点 */
  private drawEye(x: number, y: number, radius: number): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    if (this.expression === PetExpression.HAPPY) {
      ctx.beginPath();
      ctx.arc(x, y + radius, radius * 1.4, Math.PI * 1.12, Math.PI * 1.88);
      ctx.strokeStyle = INK;
      ctx.lineWidth = 2;
      ctx.stroke();
      return;
    }
    this.dot(x, y, this.expression === PetExpression.SAD ? radius * 0.78 : radius, INK);
  }

  /**
   * 只画表情，其余透明。
   * 坐标 = 图片中心 + 配置的局部偏移 × 阶段缩放。
   */
  private drawFace(): void {
    const k: number = this.renderScale;
    const s: number = this.stageScale;
    const ctx: CanvasRenderingContext2D = this.ctx;

    ctx.clearRect(0, 0, CANVAS_WIDTH * k, CANVAS_HEIGHT * k);
    ctx.save();
    ctx.scale(k, k);

    const ox: number = CANVAS_WIDTH / 2 + this.faceCx * s;
    const oy: number = CANVAS_HEIGHT / 2 + this.faceCy * s;
    const eyeR: number = this.faceEyeR * s;
    const blushR: number = this.faceBlushR * s;
    const showBlush: boolean = this.expression !== PetExpression.SAD;

    if (this.faceSingle) {
      // 侧脸：只有一只眼、一块腮红，位置由配置给的正向偏移决定
      this.drawEye(ox + this.faceEyeDx * s, oy + this.faceEyeDy * s, eyeR);
      if (showBlush) {
        this.dot(ox + this.faceBlushDx * s, oy + this.faceBlushDy * s, blushR, BLUSH);
      }
    } else {
      this.drawEye(ox + this.faceEyeDx * s, oy + this.faceEyeDy * s, eyeR);
      this.drawEye(ox - this.faceEyeDx * s, oy + this.faceEyeDy * s, eyeR);
      if (showBlush) {
        this.dot(ox + this.faceBlushDx * s, oy + this.faceBlushDy * s, blushR, BLUSH);
        this.dot(ox - this.faceBlushDx * s, oy + this.faceBlushDy * s, blushR, BLUSH);
      }
    }

    ctx.restore();
  }

  build() {
    Stack() {
      if (this.imagePath.length > 0) {
        Image($rawfile(this.imagePath))
          .width(CANVAS_WIDTH * this.renderScale)
          .height(CANVAS_HEIGHT * this.renderScale)
          // 图片与容器的宽高比一致，用 Fill 保证两层像素级对齐
          .objectFit(ImageFit.Fill)
          .draggable(false)
      }
      Canvas(this.ctx)
        .width(CANVAS_WIDTH * this.renderScale)
        .height(CANVAS_HEIGHT * this.renderScale)
        .onReady(() => {
          this.ready = true;
          this.drawFace();
        })
    }
    .width(CANVAS_WIDTH * this.renderScale)
    .height(CANVAS_HEIGHT * this.renderScale)
  }
}
