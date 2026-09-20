import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'PetCatalog';
const CONFIG_RAW_FILE: string = 'pet_config.json';

// ==================== 配置文件的结构 ====================
// 只用于承接 JSON.parse 的结果，随后会映射成下面的类，
// 这样字段缺失、类型不对时能在映射时兜住，而不是让 undefined 流到渲染层。

interface ConfigFace {
  cx: number;
  cy: number;
  eyeDx: number;
  eyeDy: number;
  eyeR: number;
  blushDx: number;
  blushDy: number;
  blushR: number;
  single: boolean;
}

interface ConfigStage {
  name: string;
  minDays: number;
  scale: number;
  image: string;
  /** 第一阶段给一个短期目标用；{n} 会被替换成距下一阶段的天数 */
  hint?: string;
  /** 写在阶段上时覆盖物种的脸型 */
  face?: ConfigFace;
}

interface ConfigSpecies {
  code: string;
  label: string;
  face?: ConfigFace;
  /** 省略时为 true。导入的照片通常自带五官，那种情况下要能关掉表情叠加 */
  faceOn?: boolean;
  stages: ConfigStage[];
}

interface ConfigRoot {
  version: number;
  species: ConfigSpecies[];
}

// ==================== 运行期模型 ====================

/**
 * 表情叠加的位置。
 *
 * 坐标是以图片中心为原点的逻辑坐标，**不随阶段缩放**——
 * 渲染时再乘以该阶段的 scale，这样身体缩小表情也跟着缩小。
 */
export class PetFace {
  cx: number = 0;
  cy: number = -2.6;
  eyeDx: number = 9.6;
  eyeDy: number = 0;
  eyeR: number = 2.7;
  blushDx: number = 18.6;
  blushDy: number = 7.7;
  blushR: number = 3.3;
  /** true = 侧脸，只有一只眼、一块腮红 */
  single: boolean = false;

  /** 默认正面脸型：配置里不写 face 时用它 */
  static front(): PetFace {
    return new PetFace();
  }
}

/** 一个成长阶段。阶段数、名称、触发门槛全部来自配置 */
export class PetStage {
  name: string = '';
  /** 触发条件：累计有记录的天数达到该值即进入本阶段 */
  minDays: number = 0;
  /** 该阶段整体缩放，表情叠加要跟着一起用 */
  scale: number = 1;
  /** rawfile 下的相对路径，或用户自建宠物的 file:// 沙箱 URI */
  image: string = '';
  hint: string = '';
  /** 已经解析好覆盖关系的脸型：阶段 > 物种 > 默认 */
  face: PetFace = PetFace.front();
  /** false 时只显示图片本体，不叠加眼睛和腮红 */
  faceOn: boolean = true;
}

export class PetSpecies {
  code: string = '';
  label: string = '';
  stages: PetStage[] = [];
  /** true = 用户自建的伙伴，选择面板里会给删除入口 */
  custom: boolean = false;
}

// ==================== 目录 ====================

function toFace(cfg: ConfigFace): PetFace {
  const face: PetFace = new PetFace();
  face.cx = cfg.cx;
  face.cy = cfg.cy;
  face.eyeDx = cfg.eyeDx;
  face.eyeDy = cfg.eyeDy;
  face.eyeR = cfg.eyeR;
  face.blushDx = cfg.blushDx;
  face.blushDy = cfg.blushDy;
  face.blushR = cfg.blushR;
  face.single = cfg.single;
  return face;
}

function toStage(cfg: ConfigStage, fallbackFace: PetFace, faceOn: boolean): PetStage {
  const stage: PetStage = new PetStage();
  stage.name = cfg.name;
  stage.minDays = cfg.minDays;
  stage.scale = cfg.scale > 0 ? cfg.scale : 1;
  stage.image = cfg.image;
  stage.hint = cfg.hint === undefined ? '' : cfg.hint;
  stage.face = cfg.face === undefined ? fallbackFace : toFace(cfg.face);
  stage.faceOn = faceOn;
  return stage;
}

function toSpecies(cfg: ConfigSpecies): PetSpecies {
  const species: PetSpecies = new PetSpecies();
  species.code = cfg.code;
  species.label = cfg.label;
  const fallbackFace: PetFace = cfg.face === undefined ? PetFace.front() : toFace(cfg.face);
  // 脸型是物种级的，但渲染层只拿到阶段，所以在这里就摊到每个阶段上
  const faceOn: boolean = cfg.faceOn === undefined ? true : cfg.faceOn;
  const stages: PetStage[] = [];
  for (const rawStage of cfg.stages) {
    stages.push(toStage(rawStage, fallbackFace, faceOn));
  }
  // 配置写反顺序时不至于让阶段判定错乱：判定依赖"取最后一个满足条件的"，
  // 而那个逻辑要求 minDays 递增，这里排一次更省心
  stages.sort((a: PetStage, b: PetStage) => a.minDays - b.minDays);
  species.stages = stages;
  return species;
}

/**
 * 物种目录。
 *
 * 阶段相关的规则（几个阶段、几天进阶、长什么样）全部读自 rawfile/pet_config.json，
 * 代码里不再有任何写死的门槛或物种列表——加物种、改进阶天数、把 SVG 换成 PNG
 * 都只动配置和资源文件。
 */
export class PetCatalog {
  /** 内置物种，来自 rawfile 配置 */
  private static builtinItems: PetSpecies[] = [];
  /** 用户自建物种，来自 preferences。排在后面，所以 defaultCode 永远是内置的第一个 */
  private static customItems: PetSpecies[] = [];
  private static items: PetSpecies[] = [];
  private static loaded: boolean = false;
  /** 装载中的 Promise，用于让调用方等它结束 */
  private static pending: Promise<void> | undefined = undefined;

  /** 开始装载。重复调用只装载一次，和 DbHelper.init 是同一套用法 */
  static init(context: common.Context): Promise<void> {
    if (PetCatalog.pending === undefined) {
      PetCatalog.pending = PetCatalog.doLoad(context);
    }
    return PetCatalog.pending;
  }

  /** 等装载结束。页面侧先 await 它，避免在配置就绪前取到空目录 */
  static async waitReady(): Promise<void> {
    if (PetCatalog.pending !== undefined) {
      await PetCatalog.pending;
    }
  }

  static isLoaded(): boolean {
    return PetCatalog.loaded;
  }

  static all(): PetSpecies[] {
    return PetCatalog.items;
  }

  /**
   * 换入用户自建物种。
   *
   * 内置在前、自建在后：defaultCode 取 items[0]，这样把宠物删光也不会把默认外观改成自建的那个。
   */
  static setUserPets(list: PetSpecies[]): void {
    PetCatalog.customItems = list;
    PetCatalog.rebuild();
  }

  static customCount(): number {
    return PetCatalog.customItems.length;
  }

  private static rebuild(): void {
    PetCatalog.items = PetCatalog.builtinItems.concat(PetCatalog.customItems);
  }

  /** 未加载完或编码写错时返回 undefined，由调用方决定怎么兜底 */
  static find(code: string): PetSpecies | undefined {
    for (const item of PetCatalog.items) {
      if (item.code === code) {
        return item;
      }
    }
    return undefined;
  }

  static defaultCode(): string {
    return PetCatalog.items.length > 0 ? PetCatalog.items[0].code : '';
  }

  static indexOf(code: string): number {
    for (let i = 0; i < PetCatalog.items.length; i++) {
      if (PetCatalog.items[i].code === code) {
        return i;
      }
    }
    return -1;
  }

  /** 从 JSON 文本装载。抽出来是为了让单元测试不用碰资源管理器 */
  static loadFrom(text: string): void {
    const root: ConfigRoot = JSON.parse(text) as ConfigRoot;
    const parsed: PetSpecies[] = [];
    for (const rawSpecies of root.species) {
      if (rawSpecies.stages.length === 0) {
        hilog.warn(DOMAIN, TAG, '物种 %{public}s 没有配置任何阶段，已跳过', rawSpecies.code);
        continue;
      }
      parsed.push(toSpecies(rawSpecies));
    }
    PetCatalog.builtinItems = parsed;
    PetCatalog.rebuild();
    PetCatalog.loaded = parsed.length > 0;
  }

  /** 从 rawfile 装载；失败时保持未加载状态，界面按"无宠物"处理而不是崩掉 */
  private static async doLoad(context: common.Context): Promise<void> {
    try {
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(CONFIG_RAW_FILE);
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      PetCatalog.loadFrom(decoder.decodeToString(bytes));
      hilog.info(DOMAIN, TAG, '宠物配置装载完成，共 %{public}d 个物种', PetCatalog.items.length);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '宠物配置装载失败 code=%{public}d message=%{public}s', e.code, e.message);
    }
  }
}
