import { hilog } from '@kit.PerformanceAnalysisKit';
import { DbHelper } from '../database/DbHelper';
import { UserProfileDao } from '../database/UserProfileDao';
import { DockItem, FloatingDock } from '../components/FloatingDock';
import { PetDebugPanel } from '../components/PetDebugPanel';
import { PetPickerPanel } from '../components/PetPickerPanel';
import { PetCatalog } from '../model/PetSpecies';
import { PetService } from '../service/PetService';
import { Theme } from '../utils/Theme';
import { WidgetService } from '../widget/WidgetService';
import { ActivityPage } from './ActivityPage';
import { AnalysisPage } from './AnalysisPage';
import { CheckinPage } from './CheckinPage';
import { HomePage } from './HomePage';
import { OnboardingPage } from './OnboardingPage';
import { PetCreatePage } from './PetCreatePage';
import { ProfilePage } from './ProfilePage';

const DOMAIN: number = 0x0000;
const TAG: string = 'Index';

const BOOT_LOADING: number = 0;
const BOOT_ONBOARDING: number = 1;
const BOOT_HOME: number = 2;

const TAB_HOME: number = 0;
const TAB_ANALYSIS: number = 1;
const TAB_PROFILE: number = 2;

/** 二级页以全屏覆盖的形式出现，盖住内容与 Dock */
const OVERLAY_NONE: number = 0;
const OVERLAY_CHECKIN: number = 1;
const OVERLAY_ACTIVITY: number = 2;
const OVERLAY_PROFILE_EDIT: number = 3;
/** 宠物调试面板，长按首页宠物卡片唤出 */
const OVERLAY_PET_DEBUG: number = 4;
/** 宠物物种选择，点击首页宠物卡片唤出 */
const OVERLAY_PET_PICKER: number = 5;
/** 自建伙伴（导入照片 / 捏一只） */
const OVERLAY_PET_CREATE: number = 6;

const DOCK_ITEMS: DockItem[] = [
  new DockItem('首页'), new DockItem('趋势'), new DockItem('我的')];

/**
 * 应用入口。
 *
 * 一级页面（首页 / 趋势 / 我的）通过底部悬浮 Dock 切换，不用路由栈——
 * 三者是平级的，没有"返回"语义，用栈反而会让返回行为变得含糊。
 *
 * 二级页（记录三餐 / 记录运动 / 编辑档案）是明确的"进入 → 完成 → 退出"流程，
 * 用全屏覆盖承载，盖住 Dock 以阻止中途切换。
 *
 * 数据联动：任何写入完成后把 dataVersion +1，各页面用 @Prop @Watch 感知并重新取数。
 * 这样页面不需要判断"我是不是被返回的那个"，行为只取决于数据是否变过。
 *
 * 注意：成员名不要用 currentTab / activeOverlay 之外的近义短名。
 * tabIndex、overlay 这类名字与 ArkUI CustomComponent 的内置属性同名，
 * 会因为类型不匹配直接编译失败。
 */
@Entry
@Component
struct Index {
  @State bootState: number = BOOT_LOADING;
  @State errorMessage: string = '';
  @State currentTab: number = TAB_HOME;
  @State activeOverlay: number = OVERLAY_NONE;
  /** 任何写入完成后 +1，各页面据此重新取数；桌面卡片也跟着一起刷 */
  @State @Watch('onDataVersionChanged') dataVersion: number = 0;
  /** 打开物种选择面板时，由首页把当前的伙伴状态带上来，缩略图按真实阶段渲染 */
  @State pickerCode: string = '';
  @State pickerStage: number = 0;
  @State pickerExpression: number = 0;
  /** 打开三餐录入页时要预选的餐次，-1 表示用默认值 */
  @State checkinMealType: number = -1;

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
      // 每次打开应用都把桌面卡片刷一遍。用户从卡片点进来时，
      // 卡片上显示的正是上次离开时的旧数据，这里顺手把它对齐
      void WidgetService.refreshAll();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '启动初始化失败: %{public}s', JSON.stringify(err));
      this.errorMessage = '初始化失败，请重启应用后重试';
    }
  }

  /**
   * 数据变了就通知桌面卡片。
   *
   * 挂在 dataVersion 上而不是各自打卡处：打卡、喝水、换伙伴、导入自建宠物
   * 都会递增这个值，一处接住就够了，以后新增写入路径也不用记得改这里。
   */
  onDataVersionChanged(): void {
    void WidgetService.refreshAll();
  }

  /** @param changed 数据是否发生了变化；变了才需要通知各页刷新 */
  private closeOverlay(changed: boolean): void {
    this.activeOverlay = OVERLAY_NONE;
    if (changed) {
      this.dataVersion = this.dataVersion + 1;
    }
  }

  /**
   * 保存选中的物种并通知首页刷新。
   * 面板不关闭，用户可以继续比较；首页在背后已经换好了，关掉就能看到。
   * 同时记下当前编码：删掉自建伙伴时要靠它判断删的是不是正在用的那个。
   */
  private applySpecies(code: string): void {
    this.pickerCode = code;
    PetService.saveSpeciesCode(code)
      .then(() => {
        this.dataVersion = this.dataVersion + 1;
      })
      .catch((err: Object) => {
        hilog.error(DOMAIN, TAG, '保存宠物外观失败: %{public}s', JSON.stringify(err));
      });
  }

  /**
   * 自建伙伴被删掉之后的收尾。
   *
   * 删的正是当前在用的那个时必须落回内置物种——否则外观编码指向一个不存在的物种，
   * 宠物会整个消失，用户只会觉得"它把我的伙伴弄没了"。
   */
  private handlePetDeleted(code: string): void {
    if (code !== this.pickerCode) {
      return;
    }
    const fallback: string = PetCatalog.defaultCode();
    this.pickerStage = 0;
    this.applySpecies(fallback);
  }

  @Builder
  bootScreen() {
    Column({ space: 14 }) {
      LoadingProgress().width(44).height(44).color(Theme.PRIMARY)
      Text('正在准备…').fontSize(14).fontColor(Theme.TEXT_TERTIARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  errorScreen() {
    Column({ space: 10 }) {
      Text('出了点问题').fontSize(18).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
      Text(this.errorMessage).fontSize(14).fontColor(Theme.TEXT_TERTIARY).textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      if (this.errorMessage.length > 0) {
        this.errorScreen()
      } else if (this.bootState === BOOT_LOADING) {
        this.bootScreen()
      } else if (this.bootState === BOOT_ONBOARDING) {
        // 首次启动必须先完成档案，因此这一屏没有退出入口
        OnboardingPage({
          onFinished: () => {
            this.bootState = BOOT_HOME;
          }
        })
      } else {
        Column() {
          if (this.currentTab === TAB_HOME) {
            HomePage({
              dataVersion: this.dataVersion,
              onOpenCheckin: (mealType: number) => {
                this.checkinMealType = mealType;
                this.activeOverlay = OVERLAY_CHECKIN;
              },
              onOpenActivity: () => {
                this.activeOverlay = OVERLAY_ACTIVITY;
              },
              onOpenPetDebug: () => {
                this.activeOverlay = OVERLAY_PET_DEBUG;
              },
              onOpenPetPicker: (code: string, stage: number, expression: number) => {
                this.pickerCode = code;
                this.pickerStage = stage;
                this.pickerExpression = expression;
                this.activeOverlay = OVERLAY_PET_PICKER;
              }
            })
              .transition(Theme.pageEffect())
          } else if (this.currentTab === TAB_ANALYSIS) {
            AnalysisPage({ dataVersion: this.dataVersion })
              .transition(Theme.pageEffect())
          } else {
            ProfilePage({
              dataVersion: this.dataVersion,
              onEditProfile: () => {
                this.activeOverlay = OVERLAY_PROFILE_EDIT;
              }
            })
              .transition(Theme.pageEffect())
          }
        }
        .width('100%')
        .height('100%')

        FloatingDock({
          items: DOCK_ITEMS,
          selected: this.currentTab,
          onPick: (index: number) => {
            this.currentTab = index;
          }
        })
        .margin({ bottom: 22 })

        if (this.activeOverlay === OVERLAY_CHECKIN) {
          CheckinPage({
            initialMealType: this.checkinMealType,
            onClose: (changed: boolean) => {
              this.closeOverlay(changed);
            }
          })
            .transition(Theme.overlayEffect())
        } else if (this.activeOverlay === OVERLAY_ACTIVITY) {
          ActivityPage({
            onClose: (changed: boolean) => {
              this.closeOverlay(changed);
            }
          })
            .transition(Theme.overlayEffect())
        } else if (this.activeOverlay === OVERLAY_PROFILE_EDIT) {
          OnboardingPage({
            onFinished: () => {
              this.closeOverlay(true);
            },
            onCancel: () => {
              this.closeOverlay(false);
            }
          })
            .transition(Theme.overlayEffect())
        } else if (this.activeOverlay === OVERLAY_PET_DEBUG) {
          // 关闭时统一递增 dataVersion，首页会重新取数并应用/撤销调试预设
          PetDebugPanel({
            onClose: () => {
              this.closeOverlay(true);
            }
          })
            .transition(Theme.overlayEffect())
        } else if (this.activeOverlay === OVERLAY_PET_PICKER) {
          PetPickerPanel({
            currentCode: this.pickerCode,
            currentStageIndex: this.pickerStage,
            expression: this.pickerExpression,
            onClose: () => {
              // 每次点选都已经递增过 dataVersion，这里不必再刷一遍
              this.closeOverlay(false);
            },
            onPick: (code: string) => {
              this.applySpecies(code);
            },
            onCreate: () => {
              this.activeOverlay = OVERLAY_PET_CREATE;
            },
            onDeleted: (code: string) => {
              this.handlePetDeleted(code);
            }
          })
            .transition(Theme.overlayEffect())
        } else if (this.activeOverlay === OVERLAY_PET_CREATE) {
          PetCreatePage({
            onClose: (newCode: string) => {
              if (newCode.length > 0) {
                // 新建完直接换上，用户马上能看到自己的作品
                this.applySpecies(newCode);
              }
              this.closeOverlay(false);
            }
          })
            .transition(Theme.overlayEffect())
        }
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
