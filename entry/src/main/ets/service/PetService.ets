import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PetSpeciesCatalog } from '../model/PetSpecies';
import { AppContext } from '../utils/AppContext';

const DOMAIN: number = 0x0000;
const TAG: string = 'PetService';

/** 宠物外观的本地配置。单独一个 preferences 文件，与健康数据库、提醒配置都不相干 */
const STORE_NAME: string = 'pet_setting';
const KEY_SPECIES: string = 'species_code';

/**
 * 宠物外观选择的持久化。
 *
 * 物种只影响"长什么样"，不影响任何健康数据，所以存 preferences 而不是关系库——
 * 它本来就不是需要查询和聚合的数据。
 */
export class PetService {

  /** 读不到、读到非法值都回落到默认物种 */
  static async loadSpeciesCode(): Promise<string> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(AppContext.get(), STORE_NAME);
      const raw = await store.get(KEY_SPECIES, PetSpeciesCatalog.defaultCode());
      const code: string = typeof raw === 'string' ? raw : '';
      // 走一次 find：物种下线或配置被改坏时自动回落，不让界面拿到空编码
      return PetSpeciesCatalog.find(code).code;
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取宠物外观失败: %{public}s', JSON.stringify(err));
      return PetSpeciesCatalog.defaultCode();
    }
  }

  static async saveSpeciesCode(code: string): Promise<void> {
    try {
      const store: preferences.Preferences =
        await preferences.getPreferences(AppContext.get(), STORE_NAME);
      await store.put(KEY_SPECIES, code);
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存宠物外观失败: %{public}s', JSON.stringify(err));
    }
  }
}
