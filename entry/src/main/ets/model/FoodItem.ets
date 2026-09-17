import { SceneBit } from './Enums';

/**
 * 场景化食物库条目。营养字段统一按每 100g 存储，
 * 计算一餐摄入时按 amount × unitGram / 100 折算。
 */
export class FoodItem {
  id: number = 0;
  name: string = '';
  /** FoodCategory 取值 */
  category: number = 0;
  /** SceneBit 的位或 */
  sceneFlags: number = 0;
  /** 计量单位名，如"碗""份""杯" */
  unitName: string = '份';
  /** 一个计量单位对应多少克 */
  unitGram: number = 100;
  kcalPer100g: number = 0;
  proteinPer100g: number = 0;
  fatPer100g: number = 0;
  carbPer100g: number = 0;
  /** 0=预置 1=用户自建 */
  isCustom: number = 0;

  /** 判断是否适用于某个场景 */
  fitsScene(scene: number): boolean {
    return (this.sceneFlags & scene) !== 0;
  }

  /** 是否属于任一场景（sceneFlags 为 0 时视为通用） */
  isUniversal(): boolean {
    return this.sceneFlags === 0 || (this.sceneFlags & (SceneBit.CANTEEN | SceneBit.TAKEOUT | SceneBit.CONVENIENCE | SceneBit.HOMEMADE)) === 0;
  }
}
