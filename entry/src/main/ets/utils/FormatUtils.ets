import { DateUtils } from './DateUtils';
import { ActivityLevel, ActivityType, FoodCategory, Gender, Goal, Intensity, MealType, SceneBit } from '../model/Enums';

/**
 * 展示层格式化工具。
 *
 * 这里的中文文案目前直接写在代码里；若后续需要多语言，
 * 应替换为 $r('app.string.xxx') 资源引用。
 */
export class FormatUtils {
  private static readonly WEEK_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  /** 分钟数 → "1 小时 23 分" / "23 分钟" / "不足 1 分钟" */
  static formatMinutes(min: number): string {
    const m: number = Math.round(min);
    if (m <= 0) {
      return '不足 1 分钟';
    }
    if (m < 60) {
      return `${m} 分钟`;
    }
    const h: number = Math.floor(m / 60);
    const rest: number = m % 60;
    return rest === 0 ? `${h} 小时` : `${h} 小时 ${rest} 分`;
  }

  /** 热量取整显示 */
  static formatKcal(kcal: number): string {
    return `${Math.round(kcal)}`;
  }

  /** 毫升 */
  static formatMl(ml: number): string {
    return `${Math.round(ml)} ml`;
  }

  /** 体重保留一位小数 */
  static formatKg(kg: number): string {
    return `${Math.round(kg * 10) / 10} kg`;
  }

  /** 0-1 的比例 → "62%" */
  static formatPercent(ratio: number): string {
    const clamped: number = Math.max(0, Math.min(1, ratio));
    return `${Math.round(clamped * 100)}%`;
  }

  /** 时间戳 → "14:05" */
  static formatClock(ts: number): string {
    const d: Date = new Date(ts);
    const h: number = d.getHours();
    const m: number = d.getMinutes();
    return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
  }

  /** 'YYYY-MM-DD' → "9月17日" */
  static formatDateLabel(key: string): string {
    const d: Date = new Date(DateUtils.keyToTimestamp(key));
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }

  /** 'YYYY-MM-DD' → "9月17日 周三" */
  static formatDateLabelWithWeek(key: string): string {
    const d: Date = new Date(DateUtils.keyToTimestamp(key));
    return `${d.getMonth() + 1}月${d.getDate()}日 ${FormatUtils.WEEK_NAMES[d.getDay()]}`;
  }

  /** 'YYYY-MM-DD' → "09-17" */
  static formatShortDate(key: string): string {
    return key.substring(5);
  }

  static sceneLabel(scene: number): string {
    if (scene === SceneBit.CANTEEN) {
      return '食堂';
    }
    if (scene === SceneBit.TAKEOUT) {
      return '外卖';
    }
    if (scene === SceneBit.CONVENIENCE) {
      return '便利店';
    }
    if (scene === SceneBit.HOMEMADE) {
      return '自做';
    }
    return '不限';
  }

  static mealTypeLabel(mealType: number): string {
    if (mealType === MealType.BREAKFAST) {
      return '早餐';
    }
    if (mealType === MealType.LUNCH) {
      return '午餐';
    }
    if (mealType === MealType.DINNER) {
      return '晚餐';
    }
    return '加餐';
  }

  static categoryLabel(category: number): string {
    if (category === FoodCategory.STAPLE) {
      return '主食';
    }
    if (category === FoodCategory.MEAT) {
      return '荤菜';
    }
    if (category === FoodCategory.VEGETABLE) {
      return '素菜';
    }
    if (category === FoodCategory.SOUP) {
      return '汤';
    }
    if (category === FoodCategory.DRINK) {
      return '饮品';
    }
    if (category === FoodCategory.SNACK) {
      return '零食';
    }
    if (category === FoodCategory.FRUIT) {
      return '水果';
    }
    return '蛋奶';
  }

  static activityTypeLabel(activityType: number): string {
    if (activityType === ActivityType.WALK) {
      return '走路';
    }
    if (activityType === ActivityType.RUN) {
      return '跑步';
    }
    if (activityType === ActivityType.CYCLE) {
      return '骑行';
    }
    if (activityType === ActivityType.BALL) {
      return '球类';
    }
    if (activityType === ActivityType.STRENGTH) {
      return '力量';
    }
    if (activityType === ActivityType.SWIM) {
      return '游泳';
    }
    return '其它';
  }

  static intensityLabel(intensity: number): string {
    if (intensity === Intensity.LOW) {
      return '低强度';
    }
    if (intensity === Intensity.HIGH) {
      return '高强度';
    }
    return '中强度';
  }

  static goalLabel(goal: number): string {
    if (goal === Goal.LOSE) {
      return '减脂';
    }
    if (goal === Goal.GAIN) {
      return '增肌';
    }
    return '保持';
  }

  static activityLevelLabel(level: number): string {
    if (level === ActivityLevel.SEDENTARY) {
      return '久坐';
    }
    if (level === ActivityLevel.LIGHT) {
      return '轻度活动';
    }
    if (level === ActivityLevel.MODERATE) {
      return '中度活动';
    }
    if (level === ActivityLevel.ACTIVE) {
      return '高度活动';
    }
    return '极高活动';
  }

  static genderLabel(gender: number): string {
    if (gender === Gender.MALE) {
      return '男';
    }
    if (gender === Gender.FEMALE) {
      return '女';
    }
    return '未设置';
  }
}
