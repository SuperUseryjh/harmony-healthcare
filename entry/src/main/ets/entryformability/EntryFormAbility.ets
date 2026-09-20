import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WidgetService } from '../widget/WidgetService';
import { CardData } from '../widget/CardData';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryFormAbility';

/**
 * 桌面卡片的提供方。
 *
 * 分两个执行环境，这点决定了整个实现方式：
 * - 卡片 UI 跑在桌面的进程里，读不到应用的数据库、也不能联网，只能显示推给它的数据；
 * - 这个 FormExtensionAbility 跑在应用自己的进程/沙箱里，能读库、能读沙箱文件。
 *
 * 所以这里负责"取数 → 组装 → 推给卡片"，数据来源统一在 WidgetService，
 * 和应用内主动刷新用的是同一份实现，卡片上看到的和首页必然一致。
 *
 * 注意：不要在这个文件（及其依赖链）里 import camera / media / audio /
 * backgroundTaskManager 这类能力——卡片扩展进程里加载它们会直接崩。
 */
export default class EntryFormAbility extends FormExtensionAbility {

  onAddForm(want: Want): formBindingData.FormBindingData {
    // onAddForm 必须同步返回，而取数要读数据库，所以先给一屏占位内容，
    // 真实数据随后由 updateForm 推上去（官方的图片卡片也是这个套路）
    const placeholder: CardData = new CardData();
    placeholder.message = '正在读取今天的记录…';

    const formId: string = EntryFormAbility.formIdOf(want);
    if (formId.length > 0) {
      // 记下来是为了应用内打完卡能主动刷新这张卡片
      void WidgetService.rememberForm(formId);
      void this.pushLatest(formId);
    } else {
      // 拿不到 id 就没法 updateForm，卡片会一直停在占位内容上，必须留个线索
      hilog.warn(DOMAIN, TAG, '加卡时没有拿到卡片 id，数据推不上去');
    }
    return formBindingData.createFormBindingData(placeholder);
  }

  onUpdateForm(formId: string): void {
    // form_config.json 里的 updateDuration 到点会走到这里
    void this.pushLatest(formId);
  }

  onRemoveForm(formId: string): void {
    void WidgetService.forgetForm(formId);
  }

  private async pushLatest(formId: string): Promise<void> {
    try {
      await WidgetService.refreshForm(this.context, formId);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, '刷新卡片失败 code=%{public}d message=%{public}s', e.code, e.message);
    }
  }

  /** 卡片实例 id，加卡时由系统带上来 */
  private static formIdOf(want: Want): string {
    const params: Record<string, Object> | undefined = want.parameters;
    if (params === undefined) {
      return '';
    }
    const id: Object | undefined = params[formInfo.FormParam.IDENTITY_KEY];
    return id === undefined ? '' : id.toString();
  }
}
