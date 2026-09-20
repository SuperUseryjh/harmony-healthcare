import { common } from '@kit.AbilityKit';

/**
 * 全局 Context 持有者。
 *
 * Calendar Kit 取 CalendarManager、preferences 建配置库、卡片扩展取沙箱路径都需要 Context，
 * 而页面侧拿 Context 要么用已废弃的 getContext()、要么写一层带 undefined 判断的强制转换。
 * 统一在 EntryAbility.onCreate 里注入一次，页面侧直接取，避免处处做类型转换。
 *
 * 存的是基类 Context 而不是 UIAbilityContext：桌面卡片的 FormExtensionAbility
 * 拿到的是 FormExtensionContext，它也属于同一个应用沙箱，同样要能在这里注册——
 * 卡片扩展可能是冷启动的，那时这条链路是唯一可用的。用到的地方（preferences、
 * filesDir、权限申请、日历）都只要求基类 Context。
 */
export class AppContext {
  private static context: common.Context | undefined = undefined;

  static set(context: common.Context): void {
    AppContext.context = context;
  }

  /** 未初始化时抛错，避免静默失败 */
  static get(): common.Context {
    const context: common.Context | undefined = AppContext.context;
    if (context === undefined) {
      throw new Error('AppContext 尚未初始化，请先调用 AppContext.set(context)');
    }
    return context;
  }

  static isReady(): boolean {
    return AppContext.context !== undefined;
  }
}
