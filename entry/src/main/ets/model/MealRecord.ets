import { MealType } from './Enums';

/**
 * 用餐记录。
 *
 * 注意：这里的 foodName / kcal / proteinG / fatG / carbG 是**写入时的快照**，
 * 不是外键关联值。食物库后续修正数据时，不应改变已经记下的历史，
 * 因此这些字段必须在插入时算好并固化下来。
 */
export class MealRecord {
  id: number = 0;
  /** 'YYYY-MM-DD' */
  recordDate: string = '';
  /** MealType 取值 */
  mealType: number = MealType.LUNCH;
  /** 用餐场景，SceneBit 取值（单选） */
  scene: number = 1;
  foodId: number = 0;
  /** 快照：食物名 */
  foodName: string = '';
  /** 份数 */
  amount: number = 1;
  /** 快照：该份对应的热量（kcal） */
  kcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;
  createdAt: number = 0;
}
