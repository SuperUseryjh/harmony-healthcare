import { common } from '@kit.AbilityKit';

/**
 * 全局 UIAbilityContext 持有者。
 *
 * Calendar Kit 取 CalendarManager、preferences 建配置库都需要 Context，
 * 而页面侧拿 Context 要么用已废弃的 getContext()、要么写一层带 undefined 判断的强制转换。
 * 统一在 EntryAbility.onCreate 里注入一次，页面侧直接取，避免处处做类型转换。
 */
export class AppContext {
  private static abilityContext: common.UIAbilityContext | undefined = undefined;

  static set(context: common.UIAbilityContext): void {
    AppContext.abilityContext = context;
  }

  /** 未初始化时抛错，避免静默失败 */
  static get(): common.UIAbilityContext {
    const context: common.UIAbilityContext | undefined = AppContext.abilityContext;
    if (context === undefined) {
      throw new Error('AppContext 尚未初始化，请先在 EntryAbility.onCreate 中调用 AppContext.set(context)');
    }
    return context;
  }

  static isReady(): boolean {
    return AppContext.abilityContext !== undefined;
  }
}
