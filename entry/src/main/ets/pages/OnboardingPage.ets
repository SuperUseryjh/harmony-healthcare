import { hilog } from '@kit.PerformanceAnalysisKit';
import { ActivityLevel, Gender, Goal } from '../model/Enums';
import { OnboardingDraft, OnboardingPreview, OnboardingViewModel } from '../viewmodel/OnboardingViewModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'OnboardingPage';

/** 分段控件的分组编号，用于在统一的点击回调里区分是哪个选择器 */
const GROUP_GENDER: number = 0;
const GROUP_ACTIVITY: number = 1;
const GROUP_GOAL: number = 2;

/**
 * @Builder 的参数载体。
 *
 * 必须包成"单个对象参数"：@Builder 默认按值传递，多参数或按值传状态变量时
 * 状态变化不会引起其内部 UI 刷新。只有"单个参数 + 对象字面量"才会走按引用传递，
 * 从而让内部的 Text / 选中态跟着状态变量一起更新。
 */
class SectionTitleParam {
  title: string = '';
  hint: string = '';
}

class SegmentParam {
  labels: string[] = [];
  selected: number = 0;
  group: number = 0;
}

/**
 * 引导页：首次启动时录入档案。
 *
 * 表单上实时显示算出来的 BMR、TDEE 和目标热量——拖一下体重滑块就能看到目标值变化，
 * 让用户明白这些数字不是凭空给的。这是 engine 层第一次直接呈现给用户。
 */
@Component
export struct OnboardingPage {
  /** 保存完成后由父组件切换到首页 */
  onFinished: () => void = () => {};

  /** 分段控件选项顺序与枚举取值的映射。写成显式数组而不是 index 加减，
   *  避免以后调整选项顺序时悄悄错位 */
  private static readonly ACTIVITY_ORDER: number[] = [
    ActivityLevel.SEDENTARY, ActivityLevel.LIGHT, ActivityLevel.MODERATE,
    ActivityLevel.ACTIVE, ActivityLevel.VERY_ACTIVE];
  private static readonly GOAL_ORDER: number[] = [Goal.LOSE, Goal.KEEP, Goal.GAIN];

  @State draft: OnboardingDraft = new OnboardingDraft();
  @State preview: OnboardingPreview = new OnboardingPreview();
  @State saving: boolean = false;

  aboutToAppear(): void {
    this.refreshPreview();
  }

  private refreshPreview(): void {
    this.preview = OnboardingViewModel.preview(this.draft);
  }

  private pick(group: number, index: number): void {
    if (group === GROUP_GENDER) {
      this.draft.gender = index === 0 ? Gender.MALE : Gender.FEMALE;
    } else if (group === GROUP_ACTIVITY) {
      this.draft.activityLevel = OnboardingPage.ACTIVITY_ORDER[index];
    } else if (group === GROUP_GOAL) {
      this.draft.goal = OnboardingPage.GOAL_ORDER[index];
    }
    this.refreshPreview();
  }

  private async submit(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await OnboardingViewModel.save(this.draft);
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
      Text(param.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
      Blank()
      Text(param.hint).fontSize(14).fontColor('#8A8F99')
    }
    .width('100%')
  }

  @Builder
  segmented(param: SegmentParam) {
    Row() {
      // key 里带上 selected：选中态变化时让 ForEach 重建子项，
      // 否则 key 不变会复用旧节点，样式不会跟着更新
      ForEach(param.labels, (label: string, index: number) => {
        Text(label)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .fontColor(index === param.selected ? Color.White : '#4D4D4D')
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(index === param.selected ? '#0A59F7' : Color.Transparent)
          .borderRadius(8)
          .onClick(() => {
            this.pick(param.group, index);
          })
      }, (label: string, index: number) => `${param.group}-${index}-${param.selected}`)
    }
    .width('100%')
    .padding(4)
    .backgroundColor('#F1F3F5')
    .borderRadius(12)
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 6 }) {
          Text('先认识一下你').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text('填几项基本信息，换算出适合你的每日目标')
            .fontSize(14).fontColor('#8A8F99')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        // 性别
        Column({ space: 10 }) {
          this.sectionTitle({ title: '性别', hint: '影响基础代谢公式' })
          this.segmented({
            labels: ['男', '女'],
            selected: this.draft.gender === Gender.MALE ? 0 : 1,
            group: GROUP_GENDER
          })
        }
        .width('100%')

        // 年龄
        Column({ space: 10 }) {
          this.sectionTitle({ title: '年龄', hint: `${this.draft.age} 岁` })
          Slider({ value: this.draft.age, min: 14, max: 70, step: 1, style: SliderStyle.OutSet })
            .blockColor('#0A59F7').selectedColor('#0A59F7').trackColor('#E4E9F2')
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
            .blockColor('#0A59F7').selectedColor('#0A59F7').trackColor('#E4E9F2')
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
            .blockColor('#0A59F7').selectedColor('#0A59F7').trackColor('#E4E9F2')
            .onChange((value: number) => {
              this.draft.weightKg = Math.round(value);
              this.refreshPreview();
            })
        }
        .width('100%')

        // 活动量
        Column({ space: 10 }) {
          this.sectionTitle({ title: '日常活动量', hint: '不算专门运动' })
          this.segmented({
            labels: ['久坐', '轻度', '中度', '高度', '极高'],
            selected: this.draft.activityLevel - 1,
            group: GROUP_ACTIVITY
          })
        }
        .width('100%')

        // 目标
        Column({ space: 10 }) {
          this.sectionTitle({ title: '目标', hint: '决定热量缺口与营养配比' })
          this.segmented({
            labels: ['减脂', '保持', '增肌'],
            selected: this.draft.goal,
            group: GROUP_GOAL
          })
        }
        .width('100%')

        // 实时预览
        Column({ space: 12 }) {
          Text('你的每日目标').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            .width('100%')

          Row() {
            Text('基础代谢 BMR').fontSize(14).fontColor('#8A8F99')
            Blank()
            Text(`${Math.round(this.preview.bmr)} kcal`).fontSize(14).fontColor('#4D4D4D')
          }.width('100%')

          Row() {
            Text('每日消耗 TDEE').fontSize(14).fontColor('#8A8F99')
            Blank()
            Text(`${Math.round(this.preview.tdee)} kcal`).fontSize(14).fontColor('#4D4D4D')
          }.width('100%')

          Divider().color('#EEF1F6')

          Row() {
            Text('目标摄入').fontSize(15).fontColor('#1A1A1A').fontWeight(FontWeight.Medium)
            Blank()
            Text(`${Math.round(this.preview.targetKcal)} kcal`)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#0A59F7')
          }.width('100%')

          Row({ space: 16 }) {
            Text(`蛋白 ${Math.round(this.preview.proteinG)}g`).fontSize(13).fontColor('#8A8F99')
            Text(`脂肪 ${Math.round(this.preview.fatG)}g`).fontSize(13).fontColor('#8A8F99')
            Text(`碳水 ${Math.round(this.preview.carbG)}g`).fontSize(13).fontColor('#8A8F99')
            Blank()
            Text(`水 ${Math.round(this.preview.waterMl)}ml`).fontSize(13).fontColor('#8A8F99')
          }.width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#F5F8FF')
        .borderRadius(16)

        Button(this.saving ? '保存中…' : '开始记录')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor('#0A59F7')
          .enabled(!this.saving)
          .onClick(() => {
            void this.submit();
          })

        Text('数据只保存在本机，不会上传')
          .fontSize(12).fontColor('#B0B5BF').width('100%').textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 32, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .scrollBar(BarState.Off)
  }
}
