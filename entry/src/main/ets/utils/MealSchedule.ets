import { MealType } from '../model/Enums';

/** 一个饭点的时间窗口 */
export class MealWindow {
  /** MealType 取值 */
  mealType: number = MealType.LUNCH;
  label: string = '';
  /** 窗口起点，当天第几分钟（0-1439），便于直接比较 */
  startMinute: number = 0;
  endMinute: number = 0;

  constructor(mealType: number, label: string,
    startHour: number, startMin: number, endHour: number, endMin: number) {
    this.mealType = mealType;
    this.label = label;
    this.startMinute = startHour * 60 + startMin;
    this.endMinute = endHour * 60 + endMin;
  }
}

/**
 * 三个饭点的窗口。
 *
 * 窗口比"正当饭点"略宽（比如午餐 11:00–13:30），因为学生实际吃饭时间浮动很大，
 * 收窄了会让很多人从头到尾都没被提醒过。
 * 加餐不设窗口——它本来就无规律，硬定时间只会变成骚扰。
 */
export const MEAL_WINDOWS: MealWindow[] = [
  new MealWindow(MealType.BREAKFAST, '早餐', 6, 30, 9, 30),
  new MealWindow(MealType.LUNCH, '午餐', 11, 0, 13, 30),
  new MealWindow(MealType.DINNER, '晚餐', 17, 0, 20, 0)
];

/**
 * 饭点时间表。纯函数，无系统依赖，可直接被单元测试覆盖。
 *
 * 这里是"应用内提醒"的判定基础：首页据此决定要不要弹饭点提示条。
 * 之所以不用系统通知，是因为代理提醒在手机上有管控、需要先申请权益；
 * 应用内提示零权限、立刻可用，权益批下来后再换成系统通知即可，
 * 判定逻辑这一层不用改。
 */
export class MealSchedule {

  /** 当前时刻落在哪个饭点窗口内；不在任何窗口返回 undefined */
  static currentWindow(hour: number, minute: number): MealWindow | undefined {
    const now: number = hour * 60 + minute;
    for (const window of MEAL_WINDOWS) {
      if (now >= window.startMinute && now <= window.endMinute) {
        return window;
      }
    }
    return undefined;
  }

  /** 下一个还没开始的饭点；今天的都过了返回 undefined */
  static nextWindow(hour: number, minute: number): MealWindow | undefined {
    const now: number = hour * 60 + minute;
    for (const window of MEAL_WINDOWS) {
      if (window.startMinute > now) {
        return window;
      }
    }
    return undefined;
  }

  /** 距离某个窗口开始还有多少分钟 */
  static minutesUntil(window: MealWindow, hour: number, minute: number): number {
    const remain: number = window.startMinute - (hour * 60 + minute);
    return remain > 0 ? remain : 0;
  }
}
