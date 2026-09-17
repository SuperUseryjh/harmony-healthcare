/** 营养合计值，供各 DAO 的聚合查询复用 */
export class NutritionTotals {
  kcal: number = 0;
  proteinG: number = 0;
  fatG: number = 0;
  carbG: number = 0;

  /** 三大营养素折算出的热量（用于配比分析，与 kcal 不一定相等） */
  macroKcal(): number {
    return this.proteinG * 4 + this.carbG * 4 + this.fatG * 9;
  }
}
