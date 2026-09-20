/**
 * 宠物造型生成器（运行期）。
 *
 * 内置宠物的 SVG 是构建前用脚本生成的，落在 rawfile 里；
 * 用户在应用内"捏"出来的宠物没有这个环节，所以要在这里按同样的规则现场拼出 SVG，
 * 再写进沙箱由 Image 加载。
 *
 * 拼装规则和产出必须与预生成的那批保持一致：同一套墨色描边、同一套高光做法、
 * 同样的成熟度换色（HSL 换色相），否则自建宠物一眼就能看出是"另一种画风"。
 */

// ==================== 形状描述 ====================

/** 一个绘制元素。用类而不是对象字面量，避免 ArkTS 对字面量类型的额外约束 */
class Sh {
  /** 'c' 圆 | 'e' 椭圆 | 'p' 路径 */
  t: string = 'c';
  cx: number = 0;
  cy: number = 0;
  r: number = 0;
  rx: number = 0;
  ry: number = 0;
  rot: number = 0;
  d: string = '';
}

function circle(cx: number, cy: number, r: number): Sh {
  const s: Sh = new Sh();
  s.t = 'c';
  s.cx = cx;
  s.cy = cy;
  s.r = r;
  return s;
}

function path(d: string): Sh {
  const s: Sh = new Sh();
  s.t = 'p';
  s.d = d;
  return s;
}

// ==================== 颜色 ====================

const INK: string = '#2A3833';
const LEAF: string = '#6E9E6B';
const STEM: string = '#8A6A45';
const GOLD: string = '#F2C14E';
/** 主体描边宽度 */
const SW: number = 2.9;
/** 细节描边宽度 */
const DW: number = 2.2;

function toHex(v: number): string {
  const n: number = Math.round(Math.max(0, Math.min(255, v)));
  return n < 16 ? '0' + n.toString(16) : n.toString(16);
}

function rgbParts(color: string): number[] {
  return [
    parseInt(color.substring(1, 3), 16),
    parseInt(color.substring(3, 5), 16),
    parseInt(color.substring(5, 7), 16)
  ];
}

/** 线性混合，只用于同色系微调（加深/提亮），不做跨色相混合 */
function mix(a: string, b: string, t: number): string {
  const A: number[] = rgbParts(a);
  const B: number[] = rgbParts(b);
  return '#' + toHex(A[0] + (B[0] - A[0]) * t)
    + toHex(A[1] + (B[1] - A[1]) * t)
    + toHex(A[2] + (B[2] - A[2]) * t);
}

function darken(color: string, t: number): string {
  return mix(color, INK, t);
}

function lighten(color: string, t: number): string {
  return mix(color, '#FFFFFF', t);
}

function clamp01(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}

/** 返回 [h(0-360), s(0-1), l(0-1)] */
function rgb2hsl(color: string): number[] {
  const p: number[] = rgbParts(color);
  const r: number = p[0] / 255;
  const g: number = p[1] / 255;
  const b: number = p[2] / 255;
  const mx: number = Math.max(r, Math.max(g, b));
  const mn: number = Math.min(r, Math.min(g, b));
  const l: number = (mx + mn) / 2;
  const d: number = mx - mn;
  let h: number = 0;
  let s: number = 0;
  if (d > 0) {
    s = d / (1 - Math.abs(2 * l - 1));
    if (mx === r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (mx === g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
  }
  return [((h % 360) + 360) % 360, s, l];
}

function hsl2rgb(h: number, s: number, l: number): string {
  const t: number = ((h % 360) + 360) % 360;
  const c: number = (1 - Math.abs(2 * l - 1)) * s;
  const x: number = c * (1 - Math.abs(((t / 60) % 2) - 1));
  const m: number = l - c / 2;
  let r: number = 0;
  let g: number = 0;
  let b: number = 0;
  if (t < 60) {
    r = c;
    g = x;
  } else if (t < 120) {
    r = x;
    g = c;
  } else if (t < 180) {
    g = c;
    b = x;
  } else if (t < 240) {
    g = x;
    b = c;
  } else if (t < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  return '#' + toHex((r + m) * 255) + toHex((g + m) * 255) + toHex((b + m) * 255);
}

/**
 * 成熟度换色。
 *
 * 用 HSL 换色相，而不是 RGB 往绿混合——后者会经过色相环上的泥色段，
 * 红果的青果阶段会变成土褐色。幼体统一压到黄绿区，半熟保留本色只降饱和提亮度。
 */
export function stageFillOf(ripe: string, stageIndex: number): string {
  const hsl: number[] = rgb2hsl(ripe);
  const h: number = hsl[0];
  const s: number = hsl[1];
  const l: number = hsl[2];
  if (stageIndex === 2) {
    return ripe;
  }
  if (stageIndex === 0) {
    return hsl2rgb(76 + (h - 76) * 0.15, clamp01(s * 0.5, 0.26, 0.46), clamp01(l + 0.20, 0.60, 0.74));
  }
  return hsl2rgb(h, clamp01(s * 0.62, 0, 0.72), clamp01(l + 0.14, 0, 0.80));
}

// ==================== 元素序列化 ====================

function el(d: Sh, fill: string, stroke: string, w: number): string {
  const rot: string = d.rot !== 0
    ? ` transform="rotate(${d.rot} ${d.cx} ${d.cy})"` : '';
  const st: string = stroke.length === 0
    ? '' : ` stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`;
  if (d.t === 'e') {
    return `<ellipse cx="${d.cx}" cy="${d.cy}" rx="${d.rx}" ry="${d.ry}"${rot} fill="${fill}"${st}/>`;
  }
  if (d.t === 'c') {
    return `<circle cx="${d.cx}" cy="${d.cy}" r="${d.r}" fill="${fill}"${st}/>`;
  }
  return `<path d="${d.d}" fill="${fill}"${st}/>`;
}

/**
 * 多块拼合的身体。
 *
 * 描边层在下且宽度加倍（上层填充会盖掉内侧那一半），纯填充层在上盖掉内部线条，
 * 这样合并轮廓的内外都干净——否则鸭子的头和身体之间会露出一圈多余的线。
 */
function unionLayer(pieces: Sh[], fill: string): string {
  let out: string = '';
  for (const p of pieces) {
    out += el(p, fill, INK, SW * 2);
  }
  for (const p of pieces) {
    out += el(p, fill, '', 0);
  }
  return out;
}

function bodyLayer(pieces: Sh[], fill: string): string {
  if (pieces.length > 1) {
    return unionLayer(pieces, fill);
  }
  return el(pieces[0], fill, INK, SW);
}

function highlight(cx: number, cy: number, rx: number, ry: number, rot: number, opacity: number): string {
  return `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" transform="rotate(${rot} ${cx} ${cy})" fill="#FFFFFF" opacity="${opacity}"/>`;
}

function pore(cx: number, cy: number, r: number, color: string): string {
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}" opacity="0.45"/>`;
}

// ==================== 圆弧转贝塞尔 ====================

/**
 * 不用 SVG 的 A 指令——ArkUI 对 SVG 指令的支持是有限子集，
 * A 是否被解析没有把握，而 C 一定是安全的。每段不超过 90°，误差可忽略。
 */
function arcBezier(cx: number, cy: number, r: number, a0: number, a1: number): string {
  const RAD: number = Math.PI / 180;
  const total: number = (a1 - a0) * RAD;
  const n: number = Math.max(1, Math.ceil(Math.abs(total) / (Math.PI / 2)));
  const step: number = total / n;
  let out: string = '';
  let ang: number = a0 * RAD;
  for (let i = 0; i < n; i++) {
    const a: number = ang;
    const b: number = ang + step;
    const k: number = (4 / 3) * Math.tan((b - a) / 4);
    const x0: number = cx + r * Math.cos(a);
    const y0: number = cy + r * Math.sin(a);
    const x3: number = cx + r * Math.cos(b);
    const y3: number = cy + r * Math.sin(b);
    const x1: number = x0 - k * r * Math.sin(a);
    const y1: number = y0 + k * r * Math.cos(a);
    const x2: number = x3 + k * r * Math.sin(b);
    const y2: number = y3 - k * r * Math.cos(b);
    out += ` C${x1.toFixed(2)} ${y1.toFixed(2)} ${x2.toFixed(2)} ${y2.toFixed(2)} ${x3.toFixed(2)} ${y3.toFixed(2)}`;
    ang = b;
  }
  return out;
}

/** 月牙：外弧圆心 (0,-13.39) R34.39、内弧圆心 (0,-47.62) r38.62，两端交于 (±32,-26)，肚厚 30 */
function crescentPath(): string {
  return 'M32 -26'
    + arcBezier(0, -13.39, 34.39, -21.47, 201.47)
    + arcBezier(0, -47.62, 38.62, 145.97, 34.03)
    + ' Z';
}

// ==================== 可选轮廓 ====================

/** 一个可选的基础轮廓 */
export class ShapeDef {
  id: string = '';
  label: string = '';
  /** 决定身体零件与表面细节 */
  kind: string = '';
  /** 配饰锚点（局部坐标）与缩放 */
  anchorX: number = 0;
  anchorY: number = 0;
  anchorScale: number = 1;
  /** 香蕉这类造型不适合插果梗 */
  hasStem: boolean = true;

  /**
   * 脸型。必须跟轮廓走而不是全局用一套：
   * 月牙形身体的可用区域比圆形窄，沿用默认的腮红间距会甩到果肉外面。
   */
  faceCy: number = -2.6;
  faceEyeDx: number = 9.6;
  faceEyeR: number = 2.7;
  faceBlushDx: number = 18.6;
  faceBlushR: number = 3.3;
}

function shape(id: string, label: string, kind: string,
  ax: number, ay: number, aScale: number, hasStem: boolean): ShapeDef {
  const s: ShapeDef = new ShapeDef();
  s.id = id;
  s.label = label;
  s.kind = kind;
  s.anchorX = ax;
  s.anchorY = ay;
  s.anchorScale = aScale;
  s.hasStem = hasStem;
  return s;
}

// ==================== 可选配色 ====================

export class PaletteDef {
  id: string = '';
  label: string = '';
  /** 成熟期的本色，幼体和半熟由 stageFillOf 推出来 */
  ripe: string = '';
}

function palette(id: string, label: string, ripe: string): PaletteDef {
  const p: PaletteDef = new PaletteDef();
  p.id = id;
  p.label = label;
  p.ripe = ripe;
  return p;
}

// ==================== 可选配饰 ====================

export class AccessoryDef {
  id: string = '';
  label: string = '';
}

function accessory(id: string, label: string): AccessoryDef {
  const a: AccessoryDef = new AccessoryDef();
  a.id = id;
  a.label = label;
  return a;
}

// ==================== 造型装配 ====================

function bodyOf(kind: string): Sh[] {
  if (kind === 'oval') {
    return [
      path('M-2 -36 C10 -34 27 -21 27 -2 C27 18 14 33 0 33 C-14 33 -26 20 -26 0 C-26 -20 -12 -36 -2 -36 Z'),
      path('M-7 -30 L1 -40 L6 -30 Z'),
      path('M-5 32 L1 41 L6 32 Z')
    ];
  }
  if (kind === 'heart') {
    return [path('M0 -33 C-16 -33 -30 -20 -30 -6 C-30 12 -14 30 0 40 C14 30 30 12 30 -6 C30 -20 16 -33 0 -33 Z')];
  }
  if (kind === 'pear') {
    return [path('M0 -33 C14 -33 24 -22 24 -8 C24 2 31 8 31 18 C31 28 17 34 0 34 C-17 34 -31 28 -31 18 C-31 8 -24 2 -24 -8 C-24 -22 -14 -33 0 -33 Z')];
  }
  if (kind === 'crescent') {
    return [path(crescentPath()), circle(32, -26, 2.6), circle(-32, -26, 2.6)];
  }
  if (kind === 'cluster') {
    return [
      circle(0, 0, 12.5), circle(-16, -6, 12), circle(16, -6, 12), circle(0, -20, 11.5),
      circle(-12, 13, 11.5), circle(12, 13, 11.5), circle(0, 24, 11.5)
    ];
  }
  // 默认圆
  return [circle(0, 0, 31), path('M-4 -29 L0 -37 L4 -29 Z')];
}

/**
 * 表面细节。
 *
 * 所有花纹都避开表情区（局部坐标 x∈[-24,24]、y∈[-12,10]）——
 * 眼睛和腮红是另外叠上去的，花纹压在那里会变成一脸麻子。
 */
function detailOf(kind: string, fill: string): string {
  if (kind === 'heart') {
    const seed: string = lighten(fill, 0.62);
    const pts: number[][] = [
      [-21, -17], [21, -17], [-10, -26], [10, -26],
      [-21, 13], [21, 13], [-11, 22], [11, 22], [0, 30]
    ];
    let out: string = '';
    for (const p of pts) {
      out += `<ellipse cx="${p[0]}" cy="${p[1]}" rx="1.8" ry="2.5" fill="${seed}" opacity="0.9"/>`;
    }
    return out;
  }
  if (kind === 'oval') {
    return highlight(-13, -12, 7, 5, -28, 0.4)
      + pore(-16, 14, 1.6, darken(fill, 0.22)) + pore(16, 14, 1.6, darken(fill, 0.22))
      + pore(0, 24, 1.6, darken(fill, 0.22)) + pore(-8, 8, 1.6, darken(fill, 0.22));
  }
  if (kind === 'pear') {
    return highlight(-15, -16, 7, 5, -30, 0.4);
  }
  if (kind === 'crescent') {
    return highlight(-8, 0, 8, 4, -8, 0.4) + highlight(10, 12, 5, 3, -8, 0.32);
  }
  if (kind === 'cluster') {
    return highlight(-20, -10, 2.8, 2.1, -25, 0.34)
      + highlight(-4, -24, 2.8, 2.1, -25, 0.34)
      + highlight(8, 9, 2.8, 2.1, -25, 0.34);
  }
  return highlight(-14, -14, 9, 7, -28, 0.4)
    + pore(-17, 15, 1.7, darken(fill, 0.2)) + pore(17, 15, 1.7, darken(fill, 0.2))
    + pore(-6, 24, 1.7, darken(fill, 0.2)) + pore(7, 24, 1.7, darken(fill, 0.2))
    + pore(0, 12, 1.7, darken(fill, 0.2));
}

function stemOf(x: number, y: number, len: number): string {
  return `<path d="M${x} ${y} L${x + 1} ${y - len}" fill="none" stroke="${STEM}" stroke-width="3" stroke-linecap="round"/>`;
}

function leafPair(x: number, y: number, s: number): string {
  const right: string = `M${x} ${y} Q${x + 13 * s} ${y - 10 * s} ${x + 18 * s} ${y - 2 * s} Q${x + 9 * s} ${y + 5 * s} ${x} ${y} Z`;
  const left: string = `M${x} ${y} Q${x - 13 * s} ${y - 10 * s} ${x - 18 * s} ${y - 2 * s} Q${x - 9 * s} ${y + 5 * s} ${x} ${y} Z`;
  const stroke: string = darken(LEAF, 0.35);
  return `<path d="${left}" fill="${LEAF}" stroke="${stroke}" stroke-width="${DW}" stroke-linejoin="round"/>`
    + `<path d="${right}" fill="${LEAF}" stroke="${stroke}" stroke-width="${DW}" stroke-linejoin="round"/>`;
}

function flowerOf(x: number, y: number, s: number, fill: string): string {
  const petal: string = lighten(fill, 0.62);
  let out: string = '';
  for (let k = 0; k < 5; k++) {
    const ang: number = (k * 72 - 90) * Math.PI / 180;
    out += `<circle cx="${(x + 5 * s * Math.cos(ang)).toFixed(2)}" cy="${(y + 5 * s * Math.sin(ang)).toFixed(2)}" r="${(3.3 * s).toFixed(2)}" fill="${petal}" stroke="${INK}" stroke-width="${DW}" stroke-linejoin="round"/>`;
  }
  out += `<circle cx="${x}" cy="${y}" r="${(2.4 * s).toFixed(2)}" fill="${GOLD}" stroke="${INK}" stroke-width="1.8"/>`;
  return out;
}

function starOf(x: number, y: number, s: number): string {
  let pts: string = '';
  for (let k = 0; k < 10; k++) {
    const ang: number = -Math.PI / 2 + (k * Math.PI) / 5;
    const rad: number = (k % 2 === 0 ? 7.5 : 3.2) * s;
    const px: number = x + Math.cos(ang) * rad;
    const py: number = y + Math.sin(ang) * rad;
    pts += (k === 0 ? 'M' : ' L') + px.toFixed(2) + ' ' + py.toFixed(2);
  }
  return `<path d="${pts} Z" fill="${GOLD}" stroke="${INK}" stroke-width="${DW}" stroke-linejoin="round"/>`;
}

function accessoryOf(accId: string, sh: ShapeDef, fill: string): string {
  if (accId === 'none') {
    return '';
  }
  const x: number = sh.anchorX;
  const y: number = sh.anchorY;
  const s: number = sh.anchorScale;
  const stem: string = sh.hasStem ? stemOf(x, y, 11 * s) : '';
  if (accId === 'leaf') {
    return stem + leafPair(x, y - 4 * s, s);
  }
  if (accId === 'flower') {
    return stem + flowerOf(x, y - 8 * s, s, fill);
  }
  return stem + starOf(x, y - 9 * s, s);
}

// ==================== 对外接口 ====================

export class PetArtLib {
  private static readonly SHAPES: ShapeDef[] = PetArtLib.makeShapes();

  private static makeShapes(): ShapeDef[] {
    const list: ShapeDef[] = [
      shape('round', '圆圆', 'round', 0, -33, 1, true),
      shape('oval', '椭椭', 'oval', 3, -38, 0.9, true),
      shape('heart', '心心', 'heart', 0, -31, 1.05, true),
      shape('pear', '梨梨', 'pear', 0, -33, 1, true),
      shape('cluster', '串串', 'cluster', 0, -32, 1, true),
      shape('crescent', '弯弯', 'crescent', -30, -30, 0.75, false)
    ];
    // 弯弯沿用内置香蕉那套缩小的脸型
    const crescent: ShapeDef = list[5];
    crescent.faceCy = 8;
    crescent.faceEyeDx = 7.5;
    crescent.faceEyeR = 2.6;
    crescent.faceBlushDx = 14;
    crescent.faceBlushR = 2.8;
    return list;
  }

  private static readonly PALETTES: PaletteDef[] = [
    palette('coral', '珊瑚', '#E4574C'),
    palette('peach', '蜜桃', '#F0A184'),
    palette('amber', '琥珀', '#E8933C'),
    palette('lemon', '柠檬', '#E9C93F'),
    palette('apple', '青苹', '#89B85C'),
    palette('teal', '青碧', '#4FA089'),
    palette('indigo', '靛蓝', '#5A73BE'),
    palette('violet', '紫晶', '#8A6FBC')
  ];

  private static readonly ACCESSORIES: AccessoryDef[] = [
    accessory('leaf', '叶子'),
    accessory('flower', '小花'),
    accessory('star', '星星'),
    accessory('none', '不加')
  ];

  static shapes(): ShapeDef[] {
    return PetArtLib.SHAPES;
  }

  static palettes(): PaletteDef[] {
    return PetArtLib.PALETTES;
  }

  static accessories(): AccessoryDef[] {
    return PetArtLib.ACCESSORIES;
  }

  static findShape(id: string): ShapeDef {
    for (const s of PetArtLib.SHAPES) {
      if (s.id === id) {
        return s;
      }
    }
    return PetArtLib.SHAPES[0];
  }

  static findPalette(id: string): PaletteDef {
    for (const p of PetArtLib.PALETTES) {
      if (p.id === id) {
        return p;
      }
    }
    return PetArtLib.PALETTES[0];
  }

  static findAccessory(id: string): AccessoryDef {
    for (const a of PetArtLib.ACCESSORIES) {
      if (a.id === id) {
        return a;
      }
    }
    return PetArtLib.ACCESSORIES[0];
  }

  /**
   * 拼出某个阶段的完整 SVG。
   *
   * canvas 固定 112×116（与内置宠物一致），身体由 translate(56,60) + scale 承载；
   * scale 与内置的 0.8/0.92/1.0 对齐，表情叠加乘的是同一个值，两边才不会错位。
   */
  static buildSvg(shapeId: string, paletteId: string, accessoryId: string, stageIndex: number): string {
    const sh: ShapeDef = PetArtLib.findShape(shapeId);
    const pal: PaletteDef = PetArtLib.findPalette(paletteId);
    const fill: string = stageFillOf(pal.ripe, stageIndex);
    const scale: string = PetArtLib.stageScale(stageIndex).toString();
    const inner: string = bodyLayer(bodyOf(sh.kind), fill)
      + detailOf(sh.kind, fill)
      + accessoryOf(accessoryId, sh, fill);
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 112 116" width="112" height="116">`
      + `<g transform="translate(56,60) scale(${scale})">${inner}</g></svg>`;
  }

  static stageScale(stageIndex: number): number {
    return stageIndex === 0 ? 0.8 : (stageIndex === 1 ? 0.92 : 1);
  }
}
