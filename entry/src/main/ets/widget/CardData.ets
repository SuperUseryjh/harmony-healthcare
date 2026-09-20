/**
 * 桌面卡片的数据。
 *
 * 卡片 UI 跑在桌面的进程里，读不到应用的数据库、也不能联网，所有内容都由
 * FormExtensionAbility 算好后通过 formBindingData 推过去，卡片页面用
 * @LocalStorageProp('字段名') 接收——**两边的字段名必须严格一致**，改这里就要看两张卡片。
 *
 * 这个文件刻意只放纯数据：卡片页面会 import 它，一旦引入了 relationalStore
 * 这类卡片进程不支持的能力，加卡片时会直接崩。
 */
export class CardData {
  /** 宠物名字（物种标签） */
  petName: string = '伙伴';
  /** 阶段名，如"成长期" */
  stageName: string = '';
  /** 宠物说的一句话 */
  message: string = '';
  /** 已陪伴天数 */
  growDays: number = 0;
  /** 距离下一阶段还差几天；已成熟为 0 */
  daysToNextStage: number = 0;
  isMaxStage: boolean = false;

  /** 三项状态，0-100 */
  fullness: number = 0;
  vitality: number = 0;
  mood: number = 0;

  /** 今日热量 */
  intakeKcal: number = 0;
  targetKcal: number = 0;
  /** 今日已记录的餐次数量 */
  mealCount: number = 0;
  /** 连续打卡天数 */
  streakDays: number = 0;

  /**
   * 宠物造型的"内存图片"名字，对应 formImages 里那个 key；空串表示这次没有图。
   *
   * 内置宠物的图在 rawfile、自建宠物的照片在应用沙箱，两种卡片进程都读不到，
   * 所以一律由扩展进程把图片内容准备好、开一个 fd 随绑定数据传过去。
   * 这个名字每次刷新都要换——卡片按名字缓存解码结果，名字不变就永远停在第一张图上。
   */
  petImage: string = '';

  /** 数据生成时间，卡片上显示"几点更新" */
  updatedAt: string = '';

  /**
   * 传递图片用的字段：key 是图片名，value 是打开后的 fd。
   * 官方要求这个字段名固定为 formImages，不可缺省或改名；
   * 即使没有图片也要留着（空对象），卡片侧按 petImage 取值。
   */
  formImages: Record<string, number> = {};
}
