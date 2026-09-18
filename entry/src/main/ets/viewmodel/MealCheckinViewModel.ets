import { FoodItem } from '../model/FoodItem';
import { MealRecord } from '../model/MealRecord';
import { FoodItemDao } from '../database/FoodItemDao';
import { MealRecordDao } from '../database/MealRecordDao';

/** 已选中待提交的食物条目 */
export class SelectedFood {
  food: FoodItem = new FoodItem();
  amount: number = 1;

  /** 折算系数 = 份数 × 每份克数 ÷ 100，营养字段均按每 100g 存储 */
  factor(): number {
    return this.food.unitGram * this.amount / 100;
  }

  kcal(): number {
    return this.food.kcalPer100g * this.factor();
  }

  proteinG(): number {
    return this.food.proteinPer100g * this.factor();
  }

  fatG(): number {
    return this.food.fatPer100g * this.factor();
  }

  carbG(): number {
    return this.food.carbPer100g * this.factor();
  }
}

/**
 * 三餐录入的视图模型。
 *
 * 换算（份数 → 克 → 营养）全部在 SelectedFood 里，提交时把算好的值作为**快照**写库，
 * 而不是只存 food_id。食物库后续修正数据时不应改变已记下的历史。
 */
export class MealCheckinViewModel {
  /** 单次查询上限。场景化食物库规模有限，一次取回后在内存里切分类更跟手 */
  static readonly QUERY_LIMIT: number = 500;

  /**
   * 按场景加载候选食物。
   *
   * 只有场景交给 SQL（是一次点击触发一次查询，代价可接受）；
   * 分类和关键词都在内存里过滤——它们随每次按键变化，查库会让输入不跟手，
   * 而食物库当前只有百余条，内存过滤的代价可以忽略。
   */
  static async loadFoodsByScene(scene: number): Promise<FoodItem[]> {
    return await FoodItemDao.query(scene, '', MealCheckinViewModel.QUERY_LIMIT);
  }

  /**
   * 内存过滤：分类 + 关键词。
   * @param category 分类取值，传 -1 表示不限
   * @param keyword 名称关键词，空串表示不限
   */
  static filter(list: FoodItem[], category: number, keyword: string): FoodItem[] {
    const kw: string = keyword.trim();
    const result: FoodItem[] = [];
    for (const item of list) {
      if (category >= 0 && item.category !== category) {
        continue;
      }
      if (kw.length > 0 && item.name.indexOf(kw) < 0) {
        continue;
      }
      result.push(item);
    }
    return result;
  }

  static totalKcal(items: SelectedFood[]): number {
    let sum: number = 0;
    for (const item of items) {
      sum += item.kcal();
    }
    return sum;
  }

  static totalProteinG(items: SelectedFood[]): number {
    let sum: number = 0;
    for (const item of items) {
      sum += item.proteinG();
    }
    return sum;
  }

  static totalFatG(items: SelectedFood[]): number {
    let sum: number = 0;
    for (const item of items) {
      sum += item.fatG();
    }
    return sum;
  }

  static totalCarbG(items: SelectedFood[]): number {
    let sum: number = 0;
    for (const item of items) {
      sum += item.carbG();
    }
    return sum;
  }

  /** 提交本餐记录。营养值在写入时固化，不依赖食物库的后续变化 */
  static async commit(dateKey: string, mealType: number, scene: number,
    items: SelectedFood[]): Promise<void> {
    const now: number = Date.now();
    for (const item of items) {
      const record: MealRecord = new MealRecord();
      record.recordDate = dateKey;
      record.mealType = mealType;
      record.scene = scene;
      record.foodId = item.food.id;
      record.foodName = item.food.name;
      record.amount = item.amount;
      record.kcal = item.kcal();
      record.proteinG = item.proteinG();
      record.fatG = item.fatG();
      record.carbG = item.carbG();
      record.createdAt = now;
      await MealRecordDao.insert(record);
    }
  }
}
