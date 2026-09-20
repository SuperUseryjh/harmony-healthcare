import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DbHelper } from '../database/DbHelper';
import { PetCatalog, PetSpecies } from '../model/PetSpecies';
import { PetCreatorService } from '../service/PetCreatorService';
import { AppContext } from '../utils/AppContext';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 注入 AbilityContext：页面侧的日历能力与配置存储都要用它，
    // 在这里注入一次，页面就不必各自做带 undefined 判断的 Context 转换
    AppContext.set(this.context);
    // 建库、建表、首次启动导入预置食物库。
    // 不阻塞 Ability 启动，失败时只记日志，由页面层在取不到数据时给出提示。
    DbHelper.init(this.context).catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', '数据库初始化失败: %{public}s', JSON.stringify(err));
    });
    // 宠物造型配置。页面侧会 await PetCatalog.waitReady() 再取，
    // 所以这里同样不阻塞 Ability 启动。
    // 内置物种装完后再并入用户自建的：自建宠物存在 preferences 里，
    // 读取是异步的，两个来源都就位才能让目录完整
    PetCatalog.init(this.context)
      .then(() => PetCreatorService.loadAll())
      .then((list: PetSpecies[]) => {
        PetCatalog.setUserPets(list);
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', '宠物配置装载失败: %{public}s', JSON.stringify(err));
      });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}