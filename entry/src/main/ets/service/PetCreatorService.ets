import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContext } from '../utils/AppContext';
import { PetArtLib, ShapeDef } from '../engine/PetArtLib';
import { RawPet, UserPetCfg, UserPetStageCfg, toUserPetCfg, toSpecies } from '../model/UserPet';
import { PetSpecies } from '../model/PetSpecies';

const DOMAIN: number = 0x0000;
const TAG: string = 'PetCreator';

const STORE_NAME: string = 'pet_setting';
const KEY_USER_PETS: string = 'user_pets';
const PET_DIR: string = 'pets';

/** 自建宠物最多三个，和内置的成长节奏对齐 */
const STAGE_NAMES: string[] = ['幼生期', '成长期', '成熟期'];
const STAGE_MIN_DAYS: number[] = [0, 7, 30];
const STAGE_SCALES: number[] = [0.8, 0.92, 1.0];

/** 图片选择器最多能选几张 */
const MAX_PICK: number = 3;

/** 允许拷进沙箱的图片扩展名，其余一律按 jpg 处理 */
const IMAGE_EXTS: string[] = ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp', 'heif'];

/**
 * 用户自建宠物的创建与存储。
 *
 * 两条创建路线复用同一套存储与目录合并逻辑：
 * - 导入图片：用户从相册选图，拷进沙箱当造型。图库选择器本身不需要权限。
 * - 参数化生成：选轮廓/配色/配饰，由 PetArtLib 现场拼出 SVG 再写进沙箱。
 */
export class PetCreatorService {

  // ==================== 存储 ====================

  private static dir(): string {
    return AppContext.get().filesDir + '/' + PET_DIR;
  }

  private static ensureDir(): void {
    const d: string = PetCreatorService.dir();
    if (!fs.accessSync(d)) {
      fs.mkdirSync(d);
    }
  }

  private static async store(): Promise<preferences.Preferences> {
    return await preferences.getPreferences(AppContext.get(), STORE_NAME);
  }

  private static async readCfgs(): Promise<UserPetCfg[]> {
    const list: UserPetCfg[] = [];
    try {
      const store: preferences.Preferences = await PetCreatorService.store();
      const raw = await store.get(KEY_USER_PETS, '');
      const text: string = typeof raw === 'string' ? raw : '';
      if (text.length === 0) {
        return list;
      }
      const raws: RawPet[] = JSON.parse(text) as RawPet[];
      for (const r of raws) {
        const cfg: UserPetCfg | undefined = toUserPetCfg(r);
        if (cfg !== undefined) {
          list.push(cfg);
        } else {
          hilog.warn(DOMAIN, TAG, '有一条自建宠物配置不完整，已跳过');
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取自建宠物失败: %{public}s', JSON.stringify(err));
    }
    return list;
  }

  private static async writeCfgs(list: UserPetCfg[]): Promise<void> {
    try {
      const store: preferences.Preferences = await PetCreatorService.store();
      await store.put(KEY_USER_PETS, JSON.stringify(list));
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存自建宠物失败: %{public}s', JSON.stringify(err));
    }
  }

  /** 启动时调用：读出全部自建宠物，交给目录合并 */
  static async loadAll(): Promise<PetSpecies[]> {
    const cfgs: UserPetCfg[] = await PetCreatorService.readCfgs();
    const out: PetSpecies[] = [];
    for (const cfg of cfgs) {
      out.push(toSpecies(cfg));
    }
    hilog.info(DOMAIN, TAG, '自建宠物装载完成，共 %{public}d 个', out.length);
    return out;
  }

  private static newCode(): string {
    return 'u' + Date.now().toString();
  }

  // ==================== 导入图片 ====================

  /**
   * 拉起图库选择器。
   *
   * 官方明确这个接口不需要申请权限，所以不会给应用增加任何权限弹窗。
   * 返回值只在这里拿一次，真正的读文件由调用方在用户点"保存"时触发——
   * 官方要求不能在 picker 的返回回调里立刻打开文件。
   */
  static async pickImages(): Promise<string[]> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = MAX_PICK;
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      return result.photoUris;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '选择图片失败 code=%{public}d message=%{public}s', e.code, e.message);
      return [];
    }
  }

  private static extOf(uri: string): string {
    const name: string = PetCreatorService.fileNameOf(uri);
    const dot: number = name.lastIndexOf('.');
    if (dot < 0) {
      return 'jpg';
    }
    const ext: string = name.substring(dot + 1).toLowerCase();
    return IMAGE_EXTS.includes(ext) ? ext : 'jpg';
  }

  private static fileNameOf(uri: string): string {
    const i: number = uri.lastIndexOf('/');
    return i < 0 ? uri : uri.substring(i + 1);
  }

  /**
   * 把宠物图片的 file:// URI 还原成沙箱里的绝对路径。
   *
   * 需要它是为了桌面卡片：卡片跑在桌面的进程里，读不到本应用的沙箱，
   * 只能由扩展进程按路径打开文件、把 fd 交给卡片。图片都在 pets 目录下，
   * 所以取出文件名再拼回来就够了，不用去解析 URI 的 authority。
   */
  static absolutePathOf(uri: string): string {
    const name: string = PetCreatorService.fileNameOf(uri);
    return name.length === 0 ? '' : `${PetCreatorService.dir()}/${name}`;
  }

  /**
   * 用导入的图片建一只。
   *
   * 只给一张图也能建：三个阶段共用同一张，靠缩放表现成长。
   * 返回新宠物的 code，失败返回空串。
   */
  static async createFromImages(label: string, uris: string[], faceOn: boolean,
    faceCy: number, faceScale: number): Promise<string> {
    if (uris.length === 0) {
      return '';
    }
    const code: string = PetCreatorService.newCode();
    try {
      PetCreatorService.ensureDir();
      const dir: string = PetCreatorService.dir();
      const names: string[] = [];
      for (let i = 0; i < uris.length; i++) {
        const name: string = `${code}_${i + 1}.${PetCreatorService.extOf(uris[i])}`;
        const src = fs.openSync(uris[i], fs.OpenMode.READ_ONLY);
        try {
          fs.copyFileSync(src.fd, `${dir}/${name}`);
        } finally {
          fs.closeSync(src);
        }
        names.push(name);
      }

      const cfg: UserPetCfg = new UserPetCfg();
      cfg.code = code;
      cfg.label = PetCreatorService.normalizeLabel(label);
      cfg.kind = 'image';
      cfg.faceOn = faceOn;
      cfg.faceCy = faceCy;
      // 脸的大小做成一个倍率，五个数值按同一比例缩放，形状关系不会走样
      cfg.faceEyeDx = 9.6 * faceScale;
      cfg.faceEyeR = 2.7 * faceScale;
      cfg.faceBlushDx = 18.6 * faceScale;
      cfg.faceBlushR = 3.3 * faceScale;
      const stages: UserPetStageCfg[] = [];
      for (let i = 0; i < 3; i++) {
        // 只给一张图时三个阶段共用；给多张时按顺序对应
        const name: string = names.length === 1 ? names[0] : names[Math.min(i, names.length - 1)];
        const st: UserPetStageCfg = new UserPetStageCfg();
        st.name = STAGE_NAMES[i];
        st.minDays = STAGE_MIN_DAYS[i];
        st.scale = STAGE_SCALES[i];
        st.image = fileUri.getUriFromPath(`${dir}/${name}`);
        stages.push(st);
      }
      cfg.stages = stages;

      const list: UserPetCfg[] = await PetCreatorService.readCfgs();
      list.push(cfg);
      await PetCreatorService.writeCfgs(list);
      hilog.info(DOMAIN, TAG, '自建宠物（导入图片）创建成功 code=%{public}s', code);
      return code;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '导入图片失败 code=%{public}d message=%{public}s', e.code, e.message);
      PetCreatorService.removeFiles(code, []);
      return '';
    }
  }

  // ==================== 参数化生成 ====================

  /**
   * 用"轮廓 + 配色 + 配饰"生成一只。
   *
   * 三个阶段各生成一张 SVG 写进沙箱——不这么做就没有成长变化，
   * 而成长变化正是这个宠物系统激励用户坚持的抓手。
   */
  static async createFromRecipe(label: string, shapeId: string,
    paletteId: string, accessoryId: string): Promise<string> {
    const code: string = PetCreatorService.newCode();
    try {
      PetCreatorService.ensureDir();
      const dir: string = PetCreatorService.dir();
      const cfg: UserPetCfg = new UserPetCfg();
      cfg.code = code;
      cfg.label = PetCreatorService.normalizeLabel(label);
      cfg.kind = 'recipe';
      cfg.faceOn = true;
      // 轮廓自带脸型：月牙形比圆形窄，沿用默认的腮红间距会甩到身体外面
      const sh: ShapeDef = PetArtLib.findShape(shapeId);
      cfg.faceCy = sh.faceCy;
      cfg.faceEyeDx = sh.faceEyeDx;
      cfg.faceEyeR = sh.faceEyeR;
      cfg.faceBlushDx = sh.faceBlushDx;
      cfg.faceBlushR = sh.faceBlushR;

      const stages: UserPetStageCfg[] = [];
      for (let i = 0; i < 3; i++) {
        const name: string = `${code}_${i + 1}.svg`;
        const svg: string = PetArtLib.buildSvg(shapeId, paletteId, accessoryId, i);
        const file = fs.openSync(`${dir}/${name}`,
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        try {
          fs.writeSync(file.fd, svg);
        } finally {
          fs.closeSync(file);
        }
        const st: UserPetStageCfg = new UserPetStageCfg();
        st.name = STAGE_NAMES[i];
        st.minDays = STAGE_MIN_DAYS[i];
        st.scale = STAGE_SCALES[i];
        st.image = fileUri.getUriFromPath(`${dir}/${name}`);
        stages.push(st);
      }
      cfg.stages = stages;

      const list: UserPetCfg[] = await PetCreatorService.readCfgs();
      list.push(cfg);
      await PetCreatorService.writeCfgs(list);
      hilog.info(DOMAIN, TAG, '自建宠物（捏）创建成功 code=%{public}s', code);
      return code;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '生成宠物失败 code=%{public}d message=%{public}s', e.code, e.message);
      PetCreatorService.removeFiles(code, []);
      return '';
    }
  }

  // ==================== 删除 ====================

  private static removeFiles(code: string, extra: string[]): void {
    const dir: string = PetCreatorService.dir();
    // 图片阶段可能多个阶段共用一个文件，所以按名字去重再删
    const names: Set<string> = new Set<string>();
    for (const n of extra) {
      names.add(n);
    }
    // 命名规则是我们自己定的：<code>_<序号>.<扩展名>，逐个尝试删掉即可
    for (const ext of ['svg', 'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp', 'heif']) {
      for (let i = 1; i <= MAX_PICK; i++) {
        names.add(`${code}_${i}.${ext}`);
      }
    }
    for (const n of names) {
      const p: string = `${dir}/${n}`;
      try {
        if (fs.accessSync(p)) {
          fs.unlinkSync(p);
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '清理文件失败 %{public}s', p);
      }
    }
  }

  /** 删掉一只自建宠物：先落配置，再清文件。配置先写可以避免"文件没了但条目还在" */
  static async remove(code: string): Promise<void> {
    const list: UserPetCfg[] = await PetCreatorService.readCfgs();
    const kept: UserPetCfg[] = [];
    for (const c of list) {
      if (c.code !== code) {
        kept.push(c);
      }
    }
    await PetCreatorService.writeCfgs(kept);
    PetCreatorService.removeFiles(code, []);
    hilog.info(DOMAIN, TAG, '已删除自建宠物 code=%{public}s', code);
  }

  // ==================== 预览 ====================

  /**
   * 生成"捏一只"的预览图。
   *
   * 每次改选项换一个新的文件名，而不是覆盖同一个路径——
   * Image 按路径缓存，覆盖写不会触发重新解码，预览就会一直停在第一版。
   * 传入上一次的 URI，顺便把它删掉。
   */
  static renderPreview(shapeId: string, paletteId: string, accessoryId: string, prevUri: string): string {
    try {
      PetCreatorService.ensureDir();
      PetCreatorService.unlinkUri(prevUri);
      const name: string = `preview_${Date.now()}.svg`;
      const abs: string = `${PetCreatorService.dir()}/${name}`;
      const file = fs.openSync(abs, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, PetArtLib.buildSvg(shapeId, paletteId, accessoryId, 2));
      } finally {
        fs.closeSync(file);
      }
      return fileUri.getUriFromPath(abs);
    } catch (err) {
      hilog.error(DOMAIN, TAG, '生成预览失败: %{public}s', JSON.stringify(err));
      return prevUri;
    }
  }

  private static unlinkUri(uri: string): void {
    if (uri.length === 0) {
      return;
    }
    const name: string = PetCreatorService.fileNameOf(uri);
    if (name.length === 0) {
      return;
    }
    const p: string = `${PetCreatorService.dir()}/${name}`;
    try {
      if (fs.accessSync(p)) {
        fs.unlinkSync(p);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, '清理预览文件失败 %{public}s', p);
    }
  }

  /** 离开创建页时清掉预览文件，别在沙箱里留垃圾 */
  static clearPreview(uri: string): void {
    PetCreatorService.unlinkUri(uri);
  }

  private static normalizeLabel(label: string): string {
    const t: string = label.trim();
    return t.length === 0 ? '我的伙伴' : (t.length > 8 ? t.substring(0, 8) : t);
  }
}
