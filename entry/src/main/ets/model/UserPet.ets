import { PetFace, PetSpecies, PetStage } from './PetSpecies';

/**
 * 用户自建宠物的持久化结构。
 *
 * 存储上刻意分成两层：元数据（这里）进 preferences，图片进 filesDir。
 * 图片是二进制、体积不受控，塞进 preferences 会让每次读写都变慢。
 */

export class UserPetStageCfg {
  name: string = '';
  minDays: number = 0;
  scale: number = 1;
  /** file:// 沙箱 URI，直接交给 Image 加载 */
  image: string = '';
}

/** 表情的五个数值。与 PetFace 的可调部分一一对应，其余（cx/eyeDy/single 等）用默认值 */
export class UserPetCfg {
  code: string = '';
  label: string = '';
  /** 'image' = 导入的图片，'recipe' = 参数化生成 */
  kind: string = '';
  faceOn: boolean = true;
  faceCy: number = -2.6;
  faceEyeDx: number = 9.6;
  faceEyeR: number = 2.7;
  faceBlushDx: number = 18.6;
  faceBlushR: number = 3.3;
  stages: UserPetStageCfg[] = [];
}

/** JSON.parse 的承接类型：字段可能缺失，转换时逐个兜底 */
export interface RawStage {
  name?: string;
  minDays?: number;
  scale?: number;
  image?: string;
}

export interface RawPet {
  code?: string;
  label?: string;
  kind?: string;
  faceOn?: boolean;
  faceCy?: number;
  faceEyeDx?: number;
  faceEyeR?: number;
  faceBlushDx?: number;
  faceBlushR?: number;
  stages?: RawStage[];
}

function num(v: number | undefined, fallback: number): number {
  return typeof v === 'number' && isFinite(v) ? v : fallback;
}

function str(v: string | undefined, fallback: string): string {
  return typeof v === 'string' ? v : fallback;
}

/** 把解析出来的裸对象规整成 UserPetCfg；缺字段的条目由调用方丢弃 */
export function toUserPetCfg(raw: RawPet): UserPetCfg | undefined {
  const code: string = str(raw.code, '');
  const label: string = str(raw.label, '');
  const rawStages: RawStage[] = raw.stages === undefined ? [] : raw.stages;
  if (code.length === 0 || label.length === 0 || rawStages.length === 0) {
    return undefined;
  }
  const cfg: UserPetCfg = new UserPetCfg();
  cfg.code = code;
  cfg.label = label;
  cfg.kind = str(raw.kind, 'recipe');
  cfg.faceOn = raw.faceOn === undefined ? true : raw.faceOn;
  cfg.faceCy = num(raw.faceCy, -2.6);
  cfg.faceEyeDx = num(raw.faceEyeDx, 9.6);
  cfg.faceEyeR = num(raw.faceEyeR, 2.7);
  cfg.faceBlushDx = num(raw.faceBlushDx, 18.6);
  cfg.faceBlushR = num(raw.faceBlushR, 3.3);
  const stages: UserPetStageCfg[] = [];
  for (const rs of rawStages) {
    const image: string = str(rs.image, '');
    if (image.length === 0) {
      return undefined;
    }
    const st: UserPetStageCfg = new UserPetStageCfg();
    st.name = str(rs.name, '');
    st.minDays = num(rs.minDays, 0);
    st.scale = num(rs.scale, 1);
    st.image = image;
    stages.push(st);
  }
  stages.sort((a: UserPetStageCfg, b: UserPetStageCfg) => a.minDays - b.minDays);
  cfg.stages = stages;
  return cfg;
}

/** 转成渲染层用的物种。阶段按 minDays 排好序，判定逻辑才能"取最后一个满足条件的" */
export function toSpecies(cfg: UserPetCfg): PetSpecies {
  const species: PetSpecies = new PetSpecies();
  species.code = cfg.code;
  species.label = cfg.label;
  species.custom = true;
  const stages: PetStage[] = [];
  for (const sc of cfg.stages) {
    const stage: PetStage = new PetStage();
    stage.name = sc.name;
    stage.minDays = sc.minDays;
    stage.scale = sc.scale > 0 ? sc.scale : 1;
    stage.image = sc.image;
    stage.hint = '';
    stage.faceOn = cfg.faceOn;
    const face: PetFace = new PetFace();
    face.cy = cfg.faceCy;
    face.eyeDx = cfg.faceEyeDx;
    face.eyeR = cfg.faceEyeR;
    face.blushDx = cfg.faceBlushDx;
    face.blushR = cfg.faceBlushR;
    stage.face = face;
    stages.push(stage);
  }
  species.stages = stages;
  return species;
}
