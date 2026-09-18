/**
 * 宠物物种定义。
 *
 * 目前有两大类：小鸭（会经历蛋阶段）和水果（不走孵化，一上来就是小果）。
 * 之所以把"是否有蛋"做成物种属性而不是写死在引擎里：蛋是鸟类的生理过程，
 * 草莓从蛋里孵出来会很怪。这个差异必须是数据，不然以后每加一个物种都要改判定逻辑。
 */

/** 水果造型。每种对应一段画法 */
export enum FruitShape {
  ROUND = 0,
  /** 草莓：上宽下尖的心形 */
  HEART = 1,
  /** 柠檬：竖长椭圆 */
  ELLIPSE = 2,
  /** 梨 / 牛油果：上窄下宽 */
  PEAR = 3,
  /** 葡萄：一串小球 */
  CLUSTER = 4,
  /** 香蕉：弯月形 */
  CRESCENT = 5
}

/** 表面细节，画在body之后、五官之前 */
export enum FruitDetail {
  NONE = 0,
  /** 顶部一片叶 */
  LEAF = 1,
  /** 梗 + 叶 */
  STEM_LEAF = 2,
  /** 西瓜纹 */
  STRIPES = 3,
  /** 桃子中缝 */
  CREASE = 4,
  /** 草莓籽 */
  SEEDS = 5,
  /** 猕猴桃：内圈 + 籽 */
  INNER_SEEDS = 6,
  /** 牛油果：内圈 + 核 */
  INNER_PIT = 7
}

/** 各阶段名称。水果没有蛋，第 0 项用不到，与第 1 项同值兜底 */
const EGG_STAGE_NAMES: string[] = ['蛋', '幼生期', '成长期', '成熟期'];
const FRUIT_STAGE_NAMES: string[] = ['小果', '小果', '半熟', '熟透'];

export class PetSpecies {
  code: string = '';
  label: string = '';
  /** 是否会经历"蛋"阶段 */
  hasEgg: boolean = true;
  /** 这一族各阶段的叫法，长度固定 4 */
  stageNames: string[] = EGG_STAGE_NAMES;

  /** 主体色 */
  bodyColor: string = '';
  /** 辅助色：内圈、翅羽、条纹等 */
  accentColor: string = '';
  /** 叶与蒂的颜色 */
  leafColor: string = '#6B9E58';
  /** 轮廓色 */
  outlineColor: string = '';

  shape: number = FruitShape.ROUND;
  detail: number = FruitDetail.NONE;
}

function species(code: string, label: string, hasEgg: boolean, bodyColor: string,
  accentColor: string, outlineColor: string, shape: number,
  detail: number): PetSpecies {
  const item: PetSpecies = new PetSpecies();
  item.code = code;
  item.label = label;
  item.hasEgg = hasEgg;
  item.stageNames = hasEgg ? EGG_STAGE_NAMES : FRUIT_STAGE_NAMES;
  item.bodyColor = bodyColor;
  item.accentColor = accentColor;
  item.outlineColor = outlineColor;
  item.shape = shape;
  item.detail = detail;
  return item;
}

/** 小鸭的编码，绘制时按它走专门的分支 */
export const SPECIES_DUCK: string = 'duck';

/**
 * 全部可选物种。
 *
 * 前 10 个水果覆盖了简笔画里的全部造型结构（圆 / 心形 / 椭圆 / 梨形 / 串 / 弯月），
 * 后续再加同类水果只需要追加一行配置。
 */
export const PET_SPECIES: PetSpecies[] = [
  species(SPECIES_DUCK, '小鸭', true,
    '#F7DE9E', '#EFCB7A', '#D6C29E', FruitShape.ROUND, FruitDetail.NONE),

  species('strawberry', '草莓', false,
    '#E9564F', '#F2897F', '#C24A44', FruitShape.HEART, FruitDetail.SEEDS),
  species('peach', '桃子', false,
    '#F6B7A8', '#F49A86', '#D8927F', FruitShape.ROUND, FruitDetail.CREASE),
  species('lemon', '柠檬', false,
    '#F6E27A', '#EFD055', '#D9C256', FruitShape.ELLIPSE, FruitDetail.LEAF),
  species('orange', '橙子', false,
    '#F0A341', '#E08C29', '#CE8531', FruitShape.ROUND, FruitDetail.STEM_LEAF),
  species('watermelon', '西瓜', false,
    '#7DB86A', '#4E8C4A', '#5E9A57', FruitShape.ROUND, FruitDetail.STRIPES),
  species('apple', '苹果', false,
    '#E9615C', '#D34A45', '#C4494A', FruitShape.ROUND, FruitDetail.STEM_LEAF),
  species('kiwi', '猕猴桃', false,
    '#9DBE6A', '#F3F1DE', '#8A9A5B', FruitShape.ROUND, FruitDetail.INNER_SEEDS),
  species('grape', '葡萄', false,
    '#A98BD1', '#9A79C6', '#8C6FB5', FruitShape.CLUSTER, FruitDetail.STEM_LEAF),
  species('banana', '香蕉', false,
    '#F7DE83', '#E9C95E', '#D8BE62', FruitShape.CRESCENT, FruitDetail.NONE),
  species('avocado', '牛油果', false,
    '#8CB26A', '#E8EDC9', '#6E9354', FruitShape.PEAR, FruitDetail.INNER_PIT),
  species('blueberry', '蓝莓', false,
    '#6E7EB8', '#8A98C9', '#5A69A0', FruitShape.ROUND, FruitDetail.NONE)
];

export class PetSpeciesCatalog {

  /** 找不到时回落到小鸭，避免配置写错就白屏 */
  static find(code: string): PetSpecies {
    for (const item of PET_SPECIES) {
      if (item.code === code) {
        return item;
      }
    }
    return PET_SPECIES[0];
  }

  static defaultCode(): string {
    return SPECIES_DUCK;
  }

  static indexOf(code: string): number {
    for (let i = 0; i < PET_SPECIES.length; i++) {
      if (PET_SPECIES[i].code === code) {
        return i;
      }
    }
    return 0;
  }
}
