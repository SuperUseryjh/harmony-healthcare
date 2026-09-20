import { hilog } from '@kit.PerformanceAnalysisKit';
import { ActivityLevel, Gender, Goal } from '../model/Enums';
import { PetCatalog } from '../model/PetSpecies';
import { UserProfile } from '../model/UserProfile';
import { UserProfileDao } from '../database/UserProfileDao';
import { PetService } from '../service/PetService';
import { Theme } from '../utils/Theme';
import { OnboardingDraft, OnboardingPreview, OnboardingViewModel } from '../viewmodel/OnboardingViewModel';
import { OverlayHeader } from '../components/OverlayHeader';
import { PetGrid } from '../components/PetGrid';
import { SegmentedBar } from '../components/SegmentedBar';

const DOMAIN: number = 0x0000;
const TAG: string = 'OnboardingPage';

/** 首次引导的两步：先填基础信息，再挑初始伙伴 */
const STEP_PROFILE: number = 0;
const STEP_PET: number = 1;

/** 活动量与目标的分段控件选项顺序 ↔ 枚举取值映射。写成显式数组而不是下标加减，
 *  避免以后调整选项顺序时悄悄错位 */
const ACTIVITY_LABELS: string[] = ['久坐', '轻度', '中度', '高度', '极高'];
const ACTIVITY_VALUES: number[] = [ActivityLevel.SEDENTARY, ActivityLevel.LIGHT,
  ActivityLevel.MODERATE, ActivityLevel.ACTIVE, ActivityLevel.VERY_ACTIVE];
const GOAL_LABELS: string[] = ['减脂', '保持', '增肌'];
const GOAL_VALUES: number[] = [Goal.LOSE, Goal.KEEP, Goal.GAIN];

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class SectionTitleParam {
  title: string = '';
  hint: string = '';
}

/**
 * 引导页 / 档案编辑页。
 *
 * 同一个页面承担两件事：首次启动时录入档案，以及后续从"我的"进入修改。
 * 两者的差别只有"进来时草稿是空的还是预填的"，因此没有做两个表单——
 * 公式、校验、选项顺序都只有一份实现。
 *
 * 首次引导分两步：先填基础信息（决定每日目标），再挑一只初始伙伴。
 * 拆开是因为这两件事的心智完全不同——前者是"填数据"，后者是"选一个陪着我的人"，
 * 挤在一屏里滚到底，第二步很容易被当成又一个表单项划过去。
 * 编辑档案没有第二步：已经有伙伴了，换外观在首页点宠物卡片就能做。
 *
 * 表单上实时显示算出来的 BMR、TDEE 和目标热量，拖一下体重滑块就能看到目标值变化，
 * 让用户明白这些数字不是凭空给的。
 */
@Component
export struct OnboardingPage {
  /** 保存完成后的去向：首次引导切首页，编辑档案则关闭覆盖层 */
  onFinished: () => void = () => {};
  /** 仅编辑模式可取消；首次引导必须走完，因此不会触发 */
  onCancel: () => void = () => {};

  @State draft: OnboardingDraft = new OnboardingDraft();
  @State preview: OnboardingPreview = new OnboardingPreview();
  @State saving: boolean = false;
  /** 是否已有档案，决定文案与是否显示取消入口 */
  @State isEditing: boolean = false;
  /** 首次引导当前处于第几步 */
  @State step: number = STEP_PROFILE;
  /** 第二步选中的初始伙伴编码 */
  @State speciesCode: string = '';

  aboutToAppear(): void {
    void this.loadExistingProfile();
  }

  /** 已有档案时预填，使本页同时可用于修改 */
  private async loadExistingProfile(): Promise<void> {
    try {
      const profile: UserProfile | undefined = await UserProfileDao.get();
      if (profile !== undefined) {
        const nowYear: number = new Date(Date.now()).getFullYear();
        this.draft.gender = profile.gender;
        this.draft.age = profile.age(nowYear);
        this.draft.heightCm = profile.heightCm;
        this.draft.weightKg = profile.weightKg;
        this.draft.activityLevel = profile.activityLevel;
        this.draft.goal = profile.goal;
        this.isEditing = true;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, '读取已有档案失败: %{public}s', JSON.stringify(err));
    }
    this.refreshPreview();
    // 初始伙伴先选上配置里的第一个：用户不挑也能直接开始，想换点一下就行
    await PetCatalog.waitReady();
    this.speciesCode = PetCatalog.defaultCode();
  }

  private refreshPreview(): void {
    this.preview = OnboardingViewModel.preview(this.draft);
  }

  /** 由下标反查枚举取值，下标越界时保持原值 */
  private static pickFrom(values: number[], index: number, fallback: number): number {
    return index >= 0 && index < values.length ? values[index] : fallback;
  }

  /** 由枚举取值反查下标，找不到时返回 0 */
  private static indexOf(values: number[], value: number): number {
    const index: number = values.indexOf(value);
    return index >= 0 ? index : 0;
  }

  private async submit(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await OnboardingViewModel.save(this.draft);
      // 第二步才需要落伙伴的外观；编辑档案时不会有这一步
      if (this.step === STEP_PET) {
        await PetService.saveSpeciesCode(this.speciesCode);
      }
      this.onFinished();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存档案失败: %{public}s', JSON.stringify(err));
    } finally {
      this.saving = false;
    }
  }

  @Builder
  sectionTitle(param: SectionTitleParam) {
    Row() {
      Text(param.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT_PRIMARY)
      Blank()
      Text(param.hint).fontSize(14).fontColor(Theme.TEXT_TERTIARY)
    }
    .width('100%')
  }

  /** 步进指示：两根进度条 + 一行说明，让人知道还差几步 */
  @Builder
  stepIndicator() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text('')
          .layoutWeight(1).height(3).borderRadius(2)
          .backgroundColor(Theme.PRIMARY)

        Text('')
          .layoutWeight(1).height(3).borderRadius(2)
          .backgroundColor(this.step >= STEP_PET ? Theme.PRIMARY : Theme.TRACK)
          .animation({ duration: Theme.DURATION_BASE, curve: Curve.EaseOut })
      }
      .width('100%')

      Text(this.step === STEP_PET ? '第 2 步 · 挑一个初始伙伴' : '第 1 步 · 填几项基本信息')
        .fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%')
    }
    .width('100%')
  }

  /** 第一步：基础信息，以及由它算出来的每日目标 */
  @Builder
  profileStep() {
    Column({ space: 22 }) {
      Column({ space: 6 }) {
        Text(this.isEditing ? '调整你的档案' : '先认识一下你')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
          .letterSpacing(1)
        Text(this.isEditing ? '改完立刻按新数据重算目标' : '填几项基本信息，换算出适合你的每日目标')
          .fontSize(14).fontColor(Theme.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      // 性别
          Column({ space: 10 }) {
            this.sectionTitle({ title: '性别', hint: '影响基础代谢公式' })
            SegmentedBar({
              labels: ['男', '女'],
              selected: this.draft.gender === Gender.MALE ? 0 : 1,
              onPick: (index: number) => {
                this.draft.gender = index === 0 ? Gender.MALE : Gender.FEMALE;
                this.refreshPreview();
              }
            })
          }
          .width('100%')

          // 年龄
          Column({ space: 10 }) {
            this.sectionTitle({ title: '年龄', hint: `${this.draft.age} 岁` })
            Slider({ value: this.draft.age, min: 14, max: 70, step: 1, style: SliderStyle.OutSet })
              .blockColor(Theme.PRIMARY).selectedColor(Theme.PRIMARY).trackColor(Theme.TRACK)
              .onChange((value: number) => {
                this.draft.age = Math.round(value);
                this.refreshPreview();
              })
          }
          .width('100%')

          // 身高
          Column({ space: 10 }) {
            this.sectionTitle({ title: '身高', hint: `${Math.round(this.draft.heightCm)} cm` })
            Slider({ value: this.draft.heightCm, min: 140, max: 210, step: 1, style: SliderStyle.OutSet })
              .blockColor(Theme.PRIMARY).selectedColor(Theme.PRIMARY).trackColor(Theme.TRACK)
              .onChange((value: number) => {
                this.draft.heightCm = Math.round(value);
                this.refreshPreview();
              })
          }
          .width('100%')

          // 体重
          Column({ space: 10 }) {
            this.sectionTitle({ title: '体重', hint: `${Math.round(this.draft.weightKg)} kg` })
            Slider({ value: this.draft.weightKg, min: 35, max: 150, step: 1, style: SliderStyle.OutSet })
              .blockColor(Theme.PRIMARY).selectedColor(Theme.PRIMARY).trackColor(Theme.TRACK)
              .onChange((value: number) => {
                this.draft.weightKg = Math.round(value);
                this.refreshPreview();
              })
          }
          .width('100%')

          // 活动量
          Column({ space: 10 }) {
            this.sectionTitle({ title: '日常活动量', hint: '不算专门运动' })
            SegmentedBar({
              labels: ACTIVITY_LABELS,
              selected: OnboardingPage.indexOf(ACTIVITY_VALUES, this.draft.activityLevel),
              onPick: (index: number) => {
                this.draft.activityLevel = OnboardingPage.pickFrom(
                  ACTIVITY_VALUES, index, this.draft.activityLevel);
                this.refreshPreview();
              }
            })
          }
          .width('100%')

          // 目标
          Column({ space: 10 }) {
            this.sectionTitle({ title: '目标', hint: '决定热量缺口与营养配比' })
            SegmentedBar({
              labels: GOAL_LABELS,
              selected: OnboardingPage.indexOf(GOAL_VALUES, this.draft.goal),
              onPick: (index: number) => {
                this.draft.goal = OnboardingPage.pickFrom(GOAL_VALUES, index, this.draft.goal);
                this.refreshPreview();
              }
            })
          }
          .width('100%')

          // 实时预览
          Column({ space: 12 }) {
            Text('你的每日目标').fontSize(15).fontWeight(FontWeight.Medium).fontColor(Theme.PRIMARY)
              .width('100%')

            Row() {
              Text('基础代谢 BMR').fontSize(14).fontColor(Theme.TEXT_SECONDARY)
              Blank()
              Text(`${Math.round(this.preview.bmr)} kcal`).fontSize(14).fontColor(Theme.TEXT_PRIMARY)
            }.width('100%')

            Row() {
              Text('每日消耗 TDEE').fontSize(14).fontColor(Theme.TEXT_SECONDARY)
              Blank()
              Text(`${Math.round(this.preview.tdee)} kcal`).fontSize(14).fontColor(Theme.TEXT_PRIMARY)
            }.width('100%')

            Divider().color(Theme.PRIMARY_LINE)

            Row() {
              Text('目标摄入').fontSize(15).fontColor(Theme.TEXT_PRIMARY).fontWeight(FontWeight.Medium)
              Blank()
              Text(`${Math.round(this.preview.targetKcal)} kcal`)
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor(Theme.PRIMARY)
            }.width('100%')

            Row({ space: 14 }) {
              Text(`蛋白 ${Math.round(this.preview.proteinG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
              Text(`脂肪 ${Math.round(this.preview.fatG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
              Text(`碳水 ${Math.round(this.preview.carbG)}g`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
              Blank()
              Text(`水 ${Math.round(this.preview.waterMl)}ml`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            }.width('100%')
          }
          .width('100%')
          .padding(18)
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(Theme.RADIUS_CARD)
          .border({ width: 1, color: Theme.PRIMARY_LINE })
    }
    .width('100%')
  }

  /** 第二步：挑一只初始伙伴。默认已选上配置里的第一个，不挑也能直接开始 */
  @Builder
  petStep() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text('挑一个初始伙伴')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
          .letterSpacing(1)
        Text('它会跟着你的记录一起长大，之后随时能换')
          .fontSize(14).fontColor(Theme.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      PetGrid({
        selectedCode: this.speciesCode,
        currentCode: '',
        currentStageIndex: 0,
        onPick: (code: string) => {
          this.speciesCode = code;
        }
      })

      Text('现在看到的是它的最终形态，往后的样子会随记录天数变化')
        .fontSize(11).fontColor(Theme.TEXT_TERTIARY).width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.isEditing) {
        OverlayHeader({
          title: '编辑档案',
          closeLabel: '取消',
          onClose: () => {
            this.onCancel();
          }
        })
      }

      Scroll() {
        Column({ space: 22 }) {
          if (!this.isEditing) {
            this.stepIndicator()
          }

          // 包一层容器才能挂 transition：@Builder 的调用是语句，没法直接链式调用
          if (this.step === STEP_PET) {
            Column() {
              this.petStep()
            }
            .width('100%')
            .transition(Theme.pageEffect())
          } else {
            Column() {
              this.profileStep()
            }
            .width('100%')
            .transition(Theme.pageEffect())
          }

          // 按钮随步骤变：编辑档案只走一步，首次引导要走完两步才落伙伴外观
          if (this.step === STEP_PET) {
            Row({ space: 12 }) {
              Button('上一步')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .backgroundColor(Theme.CARD)
                .fontColor(Theme.TEXT_PRIMARY)
                .borderRadius(Theme.RADIUS_CHIP)
                .border({ width: 1, color: Theme.LINE })
                .enabled(!this.saving)
                .onClick(() => {
                  this.step = STEP_PROFILE;
                })

              Button(this.saving ? '保存中…' : '开始记录')
                .layoutWeight(2)
                .height(48)
                .fontSize(16)
                .backgroundColor(Theme.PRIMARY)
                .enabled(!this.saving)
                .onClick(() => {
                  void this.submit();
                })
            }
            .width('100%')
          } else {
            Button(this.saving ? '保存中…' : (this.isEditing ? '保存修改' : '下一步'))
              .width('100%')
              .height(48)
              .fontSize(16)
              .backgroundColor(Theme.PRIMARY)
              .enabled(!this.saving)
              .onClick(() => {
                if (this.isEditing) {
                  void this.submit();
                } else {
                  this.step = STEP_PET;
                }
              })
          }

          Text('数据只保存在本机，不会上传')
            .fontSize(12).fontColor(Theme.TEXT_TERTIARY).width('100%').textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
