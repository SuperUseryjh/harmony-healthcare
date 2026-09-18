import { PetExpression, PetStage } from '../engine/PetEngine';
import { FruitDetail, FruitShape, PetSpecies, PetSpeciesCatalog, SPECIES_DUCK } from '../model/PetSpecies';

/** 蛋壳与小鸭 */
const SHELL: string = '#F3E9D6';
const SHELL_CRACK: string = '#CBB693';
const DUCK_BODY: string = '#F7DE9E';
const DUCK_WING: string = '#EFCB7A';
const DUCK_BEAK: string = '#E9A23B';
const DUCK_OUTLINE: string = '#D6C29E';
/** 共用 */
const INK: string = '#5A4B3C';
const BLUSH: string = '#F2B49E';
const STEM: string = '#8A6B45';
const LEAF_OUTLINE: string = '#5E8A4E';
const KIWI_SEED: string = '#4A4A3A';
const AVOCADO_PIT: string = '#9A6B3F';

/** 逻辑坐标系尺寸，各阶段共用，避免成长时卡片高度跳动 */
const CANVAS_WIDTH: number = 112;
const CANVAS_HEIGHT: number = 116;

/**
 * 宠物形象。
 *
 * 用 Canvas 而不是拼圆角矩形：圆角块画不出可辨认的造型——试过一版，
 * 蛋看起来像个竖着的胶囊。Canvas 从 API 8 就有，不受
 * `Circle`/`Ellipse` 的 `.fill()`（API 26）限制。
 *
 * 所有绘制都在固定的 112×116 逻辑坐标里完成，再由 renderScale 统一缩放，
 * 这样选择面板要显示缩略图时不用重写一套小尺寸的画法。
 */
@Component
export struct PetView {
  @Prop @Watch('onStateChanged') speciesCode: string = SPECIES_DUCK;
  @Prop @Watch('onStateChanged') stage: number = PetStage.EGG;
  @Prop @Watch('onStateChanged') expression: number = PetExpression.NORMAL;
  /** 渲染倍数：选择面板里用小于 1 的值显示缩略图 */
  @Prop @Watch('onStateChanged') renderScale: number = 1.0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 就绪前不能绘制，此时只记录状态，由 onReady 补画 */
  private ready: boolean = false;

  /**
   * @Prop 变化时组件会重新渲染，但 Canvas 的内容是绘制上去的，不会跟着变，
   * 所以必须显式重绘。
   */
  onStateChanged(): void {
    if (this.ready) {
      this.draw();
    }
  }

  /** 各阶段的整体缩放，水果就是"从小长到大" */
  private stageScale(): number {
    if (this.stage === PetStage.BABY) {
      return 0.8;
    }
    return this.stage === PetStage.GROWING ? 0.92 : 1.0;
  }

  private draw(): void {
    const k: number = this.renderScale;
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, CANVAS_WIDTH * k, CANVAS_HEIGHT * k);
    ctx.save();
    ctx.scale(k, k);

    const species: PetSpecies = PetSpeciesCatalog.find(this.speciesCode);
    if (species.code === SPECIES_DUCK) {
      if (this.stage === PetStage.EGG) {
        this.drawEgg();
      } else {
        this.drawDuck();
      }
    } else {
      this.drawFruit(species);
    }

    ctx.restore();
  }

  /** 一个实心圆点，用于眼睛、腮红、籽 */
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

  // ==================== 小鸭 ====================

  private drawEgg(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cx: number = CANVAS_WIDTH / 2;
    const cy: number = CANVAS_HEIGHT / 2 + 6;
    const rx: number = 31;
    const ry: number = 39;

    ctx.beginPath();
    ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    ctx.closePath();
    ctx.fillStyle = SHELL;
    ctx.fill();
    ctx.strokeStyle = DUCK_OUTLINE;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // 锯齿裂纹：折线比直线更像"快裂开了"
    ctx.beginPath();
    ctx.moveTo(cx - 17, cy - 6);
    ctx.lineTo(cx - 7, cy - 12);
    ctx.lineTo(cx + 1, cy - 5);
    ctx.lineTo(cx + 9, cy - 11);
    ctx.lineTo(cx + 17, cy - 6);
    ctx.strokeStyle = SHELL_CRACK;
    ctx.lineWidth = 2;
    ctx.stroke();

    this.dot(cx - 9, cy + 4, 3, INK);
    this.dot(cx + 9, cy + 4, 3, INK);
    this.dot(cx - 15, cy + 11, 3.5, BLUSH);
    this.dot(cx + 15, cy + 11, 3.5, BLUSH);
  }

  private drawDuck(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    const s: number = this.stageScale();
    const baseY: number = CANVAS_HEIGHT - 10;

    // 身体压在底下，头的下沿与它重叠，连成一体
    const bodyRy: number = 23 * s;
    const bodyRx: number = 31 * s;
    const bodyCx: number = CANVAS_WIDTH / 2 - 7 * s;
    const bodyCy: number = baseY - bodyRy;

    ctx.beginPath();
    ctx.ellipse(bodyCx, bodyCy, bodyRx, bodyRy, 0, 0, Math.PI * 2);
    ctx.closePath();
    ctx.fillStyle = DUCK_BODY;
    ctx.fill();
    ctx.strokeStyle = DUCK_OUTLINE;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    const headR: number = 20 * s;
    const headCx: number = bodyCx + 21 * s;
    const headCy: number = bodyCy - bodyRy - headR * 0.5;

    ctx.beginPath();
    ctx.arc(headCx, headCy, headR, 0, Math.PI * 2);
    ctx.closePath();
    ctx.fillStyle = DUCK_BODY;
    ctx.fill();
    ctx.stroke();

    // 喙：朝右的圆角三角
    const beakY: number = headCy + 3 * s;
    ctx.beginPath();
    ctx.moveTo(headCx + headR * 0.7, beakY - 6 * s);
    ctx.quadraticCurveTo(headCx + headR + 15 * s, beakY + 1 * s,
      headCx + headR * 0.7, beakY + 7 * s);
    ctx.closePath();
    ctx.fillStyle = DUCK_BEAK;
    ctx.fill();

    // 翅膀
    ctx.beginPath();
    ctx.ellipse(bodyCx - 3 * s, bodyCy + 2 * s, 15 * s, 9 * s, -0.22, 0, Math.PI * 2);
    ctx.closePath();
    ctx.fillStyle = DUCK_WING;
    ctx.fill();

    // 呆毛：成长期之后才长出来，是"长大了"最直观的信号
    if (this.stage === PetStage.GROWING || this.stage === PetStage.ADULT) {
      ctx.beginPath();
      ctx.moveTo(headCx - 3 * s, headCy - headR + 2 * s);
      ctx.quadraticCurveTo(headCx, headCy - headR - 14 * s,
        headCx + 11 * s, headCy - headR - 7 * s);
      ctx.strokeStyle = DUCK_WING;
      ctx.lineWidth = 3 * s;
      ctx.stroke();
    }

    this.drawEye(headCx + 5 * s, headCy - 4 * s, 3.2 * s);
    if (this.expression === PetExpression.HAPPY) {
      this.dot(headCx + 1 * s, headCy + 9 * s, 3.6 * s, BLUSH);
    }
  }

  // ==================== 水果 ====================

  private drawFruit(spec: PetSpecies): void {
    const s: number = this.stageScale();
    const cx: number = CANVAS_WIDTH / 2;
    const cy: number = CANVAS_HEIGHT / 2 + 2;
    const r: number = 32 * s;

    this.ctx.strokeStyle = spec.outlineColor;
    this.ctx.lineWidth = 1.6;

    if (spec.shape === FruitShape.CLUSTER) {
      // 葡萄没有单一轮廓，每颗各自描边
      this.drawCluster(cx, cy, r, spec);
    } else {
      this.traceBody(cx, cy, r, spec.shape);
      this.ctx.fillStyle = spec.bodyColor;
      this.ctx.fill();
      this.ctx.stroke();
      this.drawFruitDetail(cx, cy, r, spec);
    }

    // 一串葡萄的重心在上半部分，脸要跟着上移
    const faceCy: number = spec.shape === FruitShape.CLUSTER ? cy - r * 0.3 : cy - r * 0.08;
    this.drawFruitFace(cx, faceCy, r);
    this.drawFruitTop(cx, cy, r, spec);
  }

  /** 描出各形状的轮廓路径，调用方负责填充与描边 */
  private traceBody(cx: number, cy: number, r: number, shape: number): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.beginPath();

    if (shape === FruitShape.ELLIPSE) {
      ctx.ellipse(cx, cy, r * 0.8, r * 1.08, 0, 0, Math.PI * 2);
    } else if (shape === FruitShape.HEART) {
      // 草莓：上方圆肩、下方收尖
      ctx.moveTo(cx - r * 0.95, cy - r * 0.3);
      ctx.bezierCurveTo(cx - r * 1.0, cy - r * 1.15,
        cx + r * 1.0, cy - r * 1.15, cx + r * 0.95, cy - r * 0.3);
      ctx.bezierCurveTo(cx + r * 0.9, cy + r * 0.5,
        cx + r * 0.35, cy + r * 1.0, cx, cy + r * 1.15);
      ctx.bezierCurveTo(cx - r * 0.35, cy + r * 1.0,
        cx - r * 0.9, cy + r * 0.5, cx - r * 0.95, cy - r * 0.3);
    } else if (shape === FruitShape.PEAR) {
      ctx.moveTo(cx, cy - r * 1.1);
      ctx.bezierCurveTo(cx + r * 0.72, cy - r * 1.1,
        cx + r * 0.78, cy - r * 0.15, cx + r * 0.95, cy + r * 0.4);
      ctx.bezierCurveTo(cx + r * 1.05, cy + r * 1.05,
        cx - r * 1.05, cy + r * 1.05, cx - r * 0.95, cy + r * 0.4);
      ctx.bezierCurveTo(cx - r * 0.78, cy - r * 0.15,
        cx - r * 0.72, cy - r * 1.1, cx, cy - r * 1.1);
    } else if (shape === FruitShape.CRESCENT) {
      // 香蕉：上沿弯得厉害、下沿平缓，形成月牙
      ctx.moveTo(cx - r * 0.92, cy - r * 0.15);
      ctx.quadraticCurveTo(cx, cy - r * 1.15, cx + r * 0.92, cy - r * 0.15);
      ctx.quadraticCurveTo(cx, cy + r * 0.22, cx - r * 0.92, cy - r * 0.15);
    } else {
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
    }
    ctx.closePath();
  }

  private drawCluster(cx: number, cy: number, r: number, spec: PetSpecies): void {
    const gr: number = r * 0.37;
    const offsets: number[][] = [
      [0, -0.95], [-0.62, -0.44], [0.62, -0.44],
      [-0.95, 0.2], [0, 0.2], [0.95, 0.2],
      [-0.52, 0.82], [0.52, 0.82], [0, 1.3]
    ];
    for (const offset of offsets) {
      this.ctx.beginPath();
      this.ctx.arc(cx + offset[0] * r, cy + offset[1] * gr * 1.35, gr, 0, Math.PI * 2);
      this.ctx.closePath();
      this.ctx.fillStyle = spec.bodyColor;
      this.ctx.fill();
      this.ctx.strokeStyle = spec.outlineColor;
      this.ctx.lineWidth = 1.6;
      this.ctx.stroke();
    }
  }

  private drawFruitDetail(cx: number, cy: number, r: number, spec: PetSpecies): void {
    const ctx: CanvasRenderingContext2D = this.ctx;

    if (spec.detail === FruitDetail.STRIPES) {
      ctx.strokeStyle = spec.accentColor;
      ctx.lineWidth = 5;
      const lanes: number[] = [-0.52, 0, 0.52];
      for (const lane of lanes) {
        ctx.beginPath();
        ctx.moveTo(cx + lane * r, cy - r * 0.9);
        ctx.quadraticCurveTo(cx + lane * r * 1.35, cy, cx + lane * r, cy + r * 0.9);
        ctx.stroke();
      }
    } else if (spec.detail === FruitDetail.CREASE) {
      ctx.strokeStyle = spec.accentColor;
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.moveTo(cx, cy - r * 0.92);
      ctx.quadraticCurveTo(cx - r * 0.24, cy - r * 0.62, cx, cy - r * 0.36);
      ctx.stroke();
    } else if (spec.detail === FruitDetail.SEEDS) {
      const seeds: number[][] = [
        [-0.58, -0.1], [-0.22, -0.36], [0.26, -0.36], [0.6, -0.1],
        [-0.44, 0.32], [0.04, 0.32], [0.46, 0.32], [-0.16, 0.68]
      ];
      for (const seed of seeds) {
        this.dot(cx + seed[0] * r, cy + seed[1] * r, r * 0.055, '#F7E9B0');
      }
    } else if (spec.detail === FruitDetail.INNER_SEEDS) {
      // 猕猴桃：外圈果肉 + 一圈籽
      ctx.beginPath();
      ctx.ellipse(cx, cy, r * 0.74, r * 0.8, 0, 0, Math.PI * 2);
      ctx.closePath();
      ctx.fillStyle = spec.accentColor;
      ctx.fill();

      const seedCount: number = 10;
      for (let i = 0; i < seedCount; i++) {
        const angle: number = i * Math.PI * 2 / seedCount;
        this.dot(cx + Math.cos(angle) * r * 0.46, cy + Math.sin(angle) * r * 0.5,
          r * 0.045, KIWI_SEED);
      }
    } else if (spec.detail === FruitDetail.INNER_PIT) {
      // 牛油果：果肉 + 核
      ctx.beginPath();
      ctx.ellipse(cx, cy + r * 0.16, r * 0.6, r * 0.7, 0, 0, Math.PI * 2);
      ctx.closePath();
      ctx.fillStyle = spec.accentColor;
      ctx.fill();
      this.dot(cx, cy + r * 0.44, r * 0.3, AVOCADO_PIT);
    }
  }

  private drawFruitFace(cx: number, cy: number, r: number): void {
    const eyeDx: number = r * 0.3;
    const eyeR: number = r * 0.085;
    this.drawEye(cx - eyeDx, cy, eyeR);
    this.drawEye(cx + eyeDx, cy, eyeR);
    if (this.expression !== PetExpression.SAD) {
      this.dot(cx - r * 0.58, cy + r * 0.24, r * 0.1, BLUSH);
      this.dot(cx + r * 0.58, cy + r * 0.24, r * 0.1, BLUSH);
    }
  }

  /** 顶部的叶与梗 */
  private drawFruitTop(cx: number, cy: number, r: number, spec: PetSpecies): void {
    const isLeaf: boolean = spec.detail === FruitDetail.LEAF;
    const isStemLeaf: boolean = spec.detail === FruitDetail.STEM_LEAF;
    if (!isLeaf && !isStemLeaf) {
      return;
    }

    const ctx: CanvasRenderingContext2D = this.ctx;
    const topY: number = cy - r * (spec.shape === FruitShape.ELLIPSE ? 1.04 : 0.96);

    let leafY: number = topY - r * 0.1;
    if (isStemLeaf) {
      ctx.beginPath();
      ctx.moveTo(cx, topY + 2);
      ctx.lineTo(cx, topY - r * 0.3);
      ctx.strokeStyle = STEM;
      ctx.lineWidth = 2.4;
      ctx.stroke();
      leafY = topY - r * 0.3;
    }

    // 柳叶形：两段二次曲线收成尖角
    ctx.beginPath();
    ctx.moveTo(cx, leafY);
    ctx.quadraticCurveTo(cx + r * 0.46, leafY - r * 0.32, cx + r * 0.64, leafY - r * 0.02);
    ctx.quadraticCurveTo(cx + r * 0.32, leafY + r * 0.2, cx, leafY);
    ctx.closePath();
    ctx.fillStyle = spec.leafColor;
    ctx.fill();
    ctx.strokeStyle = LEAF_OUTLINE;
    ctx.lineWidth = 1.2;
    ctx.stroke();
  }

  build() {
    Canvas(this.ctx)
      .width(CANVAS_WIDTH * this.renderScale)
      .height(CANVAS_HEIGHT * this.renderScale)
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
  }
}
