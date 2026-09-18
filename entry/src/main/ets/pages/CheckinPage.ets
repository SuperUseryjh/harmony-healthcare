import { hilog } from '@kit.PerformanceAnalysisKit';
import { FoodCategory, MealType, SceneBit } from '../model/Enums';
import { FoodItem } from '../model/FoodItem';
import { DateUtils } from '../utils/DateUtils';
import { FormatUtils } from '../utils/FormatUtils';
import { Theme } from '../utils/Theme';
import { MealCheckinViewModel, SelectedFood } from '../viewmodel/MealCheckinViewModel';
import { OverlayHeader } from '../components/OverlayHeader';
import { SegmentedBar } from '../components/SegmentedBar';

const DOMAIN: number = 0x0000;
const TAG: string = 'CheckinPage';

/** 餐次、场景、分类的"展示顺序 ↔ 枚举取值"映射，写成显式数组避免下标与取值错位 */
const MEAL_LABELS: string[] = ['早餐', '午餐', '晚餐', '加餐'];
const MEAL_VALUES: number[] = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK];

const SCENE_LABELS: string[] = ['不限', '食堂', '外卖', '便利店', '自做'];
const SCENE_VALUES: number[] = [0, SceneBit.CANTEEN, SceneBit.TAKEOUT, SceneBit.CONVENIENCE, SceneBit.HOMEMADE];

const CATEGORY_LABELS: string[] = ['全部', '主食', '荤菜', '素菜', '汤', '饮品', '零食', '水果', '蛋奶'];
const CATEGORY_VALUES: number[] = [-1, FoodCategory.STAPLE, FoodCategory.MEAT, FoodCategory.VEGETABLE,
  FoodCategory.SOUP, FoodCategory.DRINK, FoodCategory.SNACK, FoodCategory.FRUIT, FoodCategory.EGG_MILK];

/** @Builder 的参数载体：单对象参数才能走按引用传递 */
class FoodRowParam {
  food: FoodItem = new FoodItem();
  amount: number = 0;
}

/**
 * 三餐录入页（全屏覆盖）。
 *
 * 交互设计：点一次就把该食物加一份，已加入的行右侧变成"− N +"，
 * 不再单独开一个"已选清单"区域——少一层跳转，而且加减份数时能直接看到行内数字变化。
 */
@Component
export struct CheckinPage {
  /** @param changed 是否写入了新数据；调用方据此决定要不要刷新其他页面 */
  onClose: (changed: boolean) => void = () => {};
  /** 由调用方预选的餐次（饭点提示点进来时会带上），传 -1 表示用默认值 */
  initialMealType: number = -1;

  @State mealIndex: number = 1;
  @State sceneIndex: number = 0;
  @State categoryIndex: number = 0;
  @State keyword: string = '';
  /** 按场景查回来的候选集，分类与关键词在此基础上过滤 */
  @State allFoods: FoodItem[] = [];
  @State visibleFoods: FoodItem[] = [];
  @State selected: SelectedFood[] = [];
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.applyInitialMeal();
    void this.reloadFoods();
  }

  private applyInitialMeal(): void {
    if (this.initialMealType < 0) {
      return;
    }
    const index: number = MEAL_VALUES.indexOf(this.initialMealType);
    if (index >= 0) {
      this.mealIndex = index;
    }
  }

  private async reloadFoods(): Promise<void> {
    try {
      this.allFoods = await MealCheckinViewModel.loadFoodsByScene(SCENE_VALUES[this.sceneIndex]);
      this.applyFilter();
    } catch (err) {
      hilog.error(DOMAIN, TAG, '加载食物库失败: %{public}s', JSON.stringify(err));
    }
  }

  private applyFilter(): void {
    this.visibleFoods = MealCheckinViewModel.filter(
      this.allFoods, CATEGORY_VALUES[this.categoryIndex], this.keyword);
  }

  private onScenePick(index: number): void {
    this.sceneIndex = index;
    void this.reloadFoods();
  }

  private onCategoryPick(index: number): void {
    this.categoryIndex = index;
    this.applyFilter();
  }

  /** 该食物已加入的份数，0 表示未加入 */
  private amountOf(foodId: number): number {
    for (const item of this.selected) {
      if (item.food.id === foodId) {
        return item.amount;
      }
    }
    return 0;
  }

  private addFood(food: FoodItem): void {
    for (const item of this.selected) {
      if (item.food.id === food.id) {
        item.amount = item.amount + 1;
        // 整体替换数组才能触发 @State 刷新
        this.selected = this.selected.slice();
        return;
      }
    }
    const created: SelectedFood = new SelectedFood();
    created.food = food;
    created.amount = 1;
    const next: SelectedFood[] = this.selected.slice();
    next.push(created);
    this.selected = next;
  }

  private decreaseFood(foodId: number): void {
    const next: SelectedFood[] = [];
    for (const item of this.selected) {
      if (item.food.id !== foodId) {
        next.push(item);
      } else if (item.amount > 1) {
        item.amount = item.amount - 1;
        next.push(item);
      }
      // 份数减到 0 时该条不再入列，等价于移除
    }
    this.selected = next;
  }

  private async commit(): Promise<void> {
    if (this.busy || this.selected.length === 0) {
      return;
    }
    this.busy = true;
    try {
      await MealCheckinViewModel.commit(DateUtils.todayKey(),
        MEAL_VALUES[this.mealIndex], SCENE_VALUES[this.sceneIndex], this.selected);
      this.onClose(true);
    } catch (err) {
      hilog.error(DOMAIN, TAG, '保存用餐记录失败: %{public}s', JSON.stringify(err));
    } finally {
      this.busy = false;
    }
  }

  @Builder
  foodRow(param: FoodRowParam) {
    Row() {
      Column({ space: 5 }) {
        Text(param.food.name).fontSize(15).fontColor(Theme.TEXT_PRIMARY)
        Text(`${param.food.unitName} · ${Math.round(param.food.kcalPer100g * param.food.unitGram / 100)} kcal · ${FormatUtils.categoryLabel(param.food.category)}`)
          .fontSize(12).fontColor(Theme.TEXT_TERTIARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (param.amount === 0) {
        Text('+')
          .fontSize(18).fontColor(Theme.PRIMARY)
          .padding({ left: 14, right: 14, top: 5, bottom: 5 })
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(18)
          .onClick(() => {
            this.addFood(param.food);
          })
      } else {
        Row({ space: 4 }) {
          Text('-')
            .fontSize(18).fontColor(Theme.PRIMARY)
            .padding({ left: 14, right: 14, top: 5, bottom: 5 })
            .onClick(() => {
              this.decreaseFood(param.food.id);
            })
          Text(`${param.amount}`)
            .fontSize(15).width(20).textAlign(TextAlign.Center).fontColor(Theme.TEXT_PRIMARY)
          Text('+')
            .fontSize(18).fontColor(Theme.PRIMARY)
            .padding({ left: 14, right: 14, top: 5, bottom: 5 })
            .onClick(() => {
              this.addFood(param.food);
            })
        }
        .backgroundColor(Theme.PRIMARY_SOFT)
        .borderRadius(18)
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      OverlayHeader({
        title: '记录三餐',
        closeLabel: '取消',
        onClose: () => {
          this.onClose(false);
        }
      })

      // 筛选区
      Column({ space: 10 }) {
        SegmentedBar({
          labels: MEAL_LABELS,
          selected: this.mealIndex,
          onPick: (index: number) => {
            this.mealIndex = index;
          }
        })

        SegmentedBar({
          labels: SCENE_LABELS,
          selected: this.sceneIndex,
          onPick: (index: number) => {
            this.onScenePick(index);
          }
        })

        TextInput({ placeholder: '搜索食物名称' })
          .height(42)
          .fontSize(14)
          .backgroundColor(Theme.CARD)
          .borderRadius(12)
          .placeholderColor(Theme.TEXT_TERTIARY)
          .onChange((value: string) => {
            this.keyword = value;
            this.applyFilter();
          })

        Scroll() {
          Row({ space: 8 }) {
            ForEach(CATEGORY_LABELS, (label: string, index: number) => {
              Text(label)
                .fontSize(13)
                .fontColor(index === this.categoryIndex ? Color.White : Theme.TEXT_SECONDARY)
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor(index === this.categoryIndex ? Theme.PRIMARY : Theme.CARD)
                .borderRadius(16)
                .onClick(() => {
                  this.onCategoryPick(index);
                })
            }, (label: string, index: number) => `cat-${index}-${this.categoryIndex}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 4, bottom: 14 })

      // 食物列表
      Column() {
        List() {
          ForEach(this.visibleFoods, (food: FoodItem) => {
            ListItem() {
              // key 里带上份数，份数变化时只重建对应行
              this.foodRow({ food: food, amount: this.amountOf(food.id) })
            }
          }, (food: FoodItem) => `${food.id}-${this.amountOf(food.id)}`)

          if (this.visibleFoods.length === 0) {
            ListItem() {
              Text('没有匹配的食物，换个分类或关键词试试')
                .fontSize(13).fontColor(Theme.TEXT_TERTIARY)
                .width('100%').textAlign(TextAlign.Center)
                .padding({ top: 48 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16 })
        .divider({ strokeWidth: 1, color: Theme.DIVIDER })
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 18, right: 18 })
      .backgroundColor(Theme.CARD)
      .borderRadius(Theme.RADIUS_CARD)
      .clip(true)
      .border({ width: 1, color: Theme.LINE })

      // 底部合计与提交
      Column({ space: 12 }) {
        Row() {
          Column({ space: 3 }) {
            Text(`已选 ${this.selected.length} 项`).fontSize(12).fontColor(Theme.TEXT_TERTIARY)
            Text(`${Math.round(MealCheckinViewModel.totalKcal(this.selected))} kcal`)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text(`蛋白 ${Math.round(MealCheckinViewModel.totalProteinG(this.selected))}g\n脂肪 ${Math.round(MealCheckinViewModel.totalFatG(this.selected))}g · 碳水 ${Math.round(MealCheckinViewModel.totalCarbG(this.selected))}g`)
            .fontSize(11).fontColor(Theme.TEXT_TERTIARY).textAlign(TextAlign.End)
        }
        .width('100%')

        Button(this.busy ? '保存中…' : `记入${MEAL_LABELS[this.mealIndex]}`)
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor(this.selected.length === 0 ? Theme.TEXT_DISABLED : Theme.PRIMARY)
          .enabled(this.selected.length > 0 && !this.busy)
          .onClick(() => {
            void this.commit();
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
