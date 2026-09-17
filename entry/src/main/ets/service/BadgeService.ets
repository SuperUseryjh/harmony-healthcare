import { BadgeCatalog } from '../model/Badge';
import { BadgeDao } from '../database/BadgeDao';
import { MealRecordDao } from '../database/MealRecordDao';
import { ActivityRecordDao } from '../database/ActivityRecordDao';
import { DailySummary } from '../model/DailySummary';
import { DailyPlan } from './PlanService';

/**
 * 成就徽章服务：判定哪些徽章该解锁了。
 *
 * 设计上把"徽章目录"（BadgeCatalog，静态文案）与"解锁条件"（这里）分开，
 * 加新徽章只需要在两处各加一行，不需要动数据库。
 */
export class BadgeService {
  /** 健康分达到多少算"状态很好" */
  static readonly EXCELLENT_SCORE: number = 90;

  /**
   * 评估并解锁徽章。
   * @returns 本次**新解锁**的徽章名称，已拥有的不会重复返回
   */
  static async evaluate(summary: DailySummary, plan: DailyPlan | undefined): Promise<string[]> {
    const unlocked: string[] = [];
    const now: number = Date.now();

    const totalMeals: number = await MealRecordDao.countAll();
    const totalActivities: number = await ActivityRecordDao.countAll();

    if (summary.checkinFlags !== 0) {
      await BadgeService.tryUnlock('FIRST_CHECKIN', now, unlocked);
    }
    if (totalMeals >= 1) {
      await BadgeService.tryUnlock('FIRST_MEAL', now, unlocked);
    }
    if (totalMeals >= 50) {
      await BadgeService.tryUnlock('MEAL_50', now, unlocked);
    }
    if (totalActivities >= 1) {
      await BadgeService.tryUnlock('FIRST_ACTIVITY', now, unlocked);
    }
    if (totalActivities >= 10) {
      await BadgeService.tryUnlock('ACTIVITY_10', now, unlocked);
    }
    if (plan !== undefined && summary.waterMl >= plan.waterMl) {
      await BadgeService.tryUnlock('WATER_GOAL', now, unlocked);
    }
    if (summary.score >= BadgeService.EXCELLENT_SCORE) {
      await BadgeService.tryUnlock('SCORE_90', now, unlocked);
    }
    if (summary.streakDays >= 3) {
      await BadgeService.tryUnlock('STREAK_3', now, unlocked);
    }
    if (summary.streakDays >= 7) {
      await BadgeService.tryUnlock('STREAK_7', now, unlocked);
    }
    if (summary.streakDays >= 30) {
      await BadgeService.tryUnlock('STREAK_30', now, unlocked);
    }

    return unlocked;
  }

  /** 已解锁徽章的展示名称，供"我的"页面使用 */
  static async unlockedNames(): Promise<string[]> {
    const badges = await BadgeDao.getAll();
    const names: string[] = [];
    for (const badge of badges) {
      names.push(BadgeCatalog.nameOf(badge.badgeCode));
    }
    return names;
  }

  private static async tryUnlock(code: string, ts: number, collected: string[]): Promise<void> {
    const isNew: boolean = await BadgeDao.unlock(code, ts);
    if (isNew) {
      collected.push(BadgeCatalog.nameOf(code));
    }
  }
}
