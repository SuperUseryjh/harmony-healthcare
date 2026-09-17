import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbHelper } from '../database/DbHelper';
import { UserProfileDao } from '../database/UserProfileDao';
import { HomePage } from './HomePage';
import { OnboardingPage } from './OnboardingPage';

const DOMAIN: number = 0x0000;
const TAG: string = 'Index';

const BOOT_LOADING: number = 0;
const BOOT_ONBOARDING: number = 1;
const BOOT_HOME: number = 2;

/**
 * 应用入口。
 *
 * 只做一件事：等数据库就绪，检查有没有用户档案，决定进引导页还是首页。
 *
 * 数据库的实际初始化在 EntryAbility.onCreate 里发起，这里只等它完成——
 * 这样页面侧不需要再获取一次 Context，也不会出现两处各自建库的情况。
 *
 * 子页面（打卡、分析、我的）将在后续阶段接入 Navigation，目前用条件渲染即可。
 */
@Entry
@Component
struct Index {
  @State bootState: number = BOOT_LOADING;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    void this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    try {
      const ready: boolean = await DbHelper.waitReady();
      if (!ready) {
        this.errorMessage = '本地数据库未能初始化，请重启应用后重试';
        return;
      }
      const hasProfile: boolean = await UserProfileDao.exists();
      this.bootState = hasProfile ? BOOT_HOME : BOOT_ONBOARDING;
    } catch (err) {
      hilog.error(DOMAIN, TAG, '启动初始化失败: %{public}s', JSON.stringify(err));
      this.errorMessage = '初始化失败，请重启应用后重试';
    }
  }

  build() {
    Stack() {
      if (this.errorMessage.length > 0) {
        Column({ space: 10 }) {
          Text('出了点问题').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          Text(this.errorMessage).fontSize(14).fontColor('#8A8F99').textAlign(TextAlign.Center)
        }
        .width('100%')
        .height('100%')
        .padding(32)
        .justifyContent(FlexAlign.Center)
      } else if (this.bootState === BOOT_LOADING) {
        Column({ space: 14 }) {
          LoadingProgress().width(48).height(48).color('#0A59F7')
          Text('正在准备…').fontSize(14).fontColor('#8A8F99')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.bootState === BOOT_ONBOARDING) {
        OnboardingPage({
          onFinished: () => {
            this.bootState = BOOT_HOME;
          }
        })
      } else {
        HomePage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
