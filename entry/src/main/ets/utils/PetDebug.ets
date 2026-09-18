import { PetEngine, PetState } from '../engine/PetEngine';
import { PetSpecies } from '../model/PetSpecies';

/**
 * 一个调试预设。
 *
 * 存的是 PetEngine 的**入参**而不是最终的 PetState —— 这样切过去之后，
 * 三项状态条、台词、表情、阶段全部由同一套公式重新算出来，各处必然一致。
 * 如果直接塞一个 PetState，很容易出现"身子是成熟期、台词还是蛋"这种自相矛盾。
 */
export class PetDebugPreset {
  label: string = '';
  growDays: number = 0;
  mainMealCount: number = 0;
  activityMin: number = 0;
  waterDone: boolean = false;
  streakDays: number = 0;

  constructor(label: string, growDays: number, mainMealCount: number,
    activityMin: number, waterDone: boolean, streakDays: number) {
    this.label = label;
    this.growDays = growDays;
    this.mainMealCount = mainMealCount;
    this.activityMin = activityMin;
    this.waterDone = waterDone;
    this.streakDays = streakDays;
  }
}

/**
 * 四个阶段各一个典型场景，点一下就能看到对应的形象与台词。
 *
 * 入参是刻意挑的，让四个预设分别命中四种不同的台词分支
 * （孵化提示 / 想活动 / 肚子饿 / 表扬）和三种表情，演示时变化更明显。
 */
export const PET_DEBUG_PRESETS: PetDebugPreset[] = [
  new PetDebugPreset('刚开始', 0, 0, 0, false, 0),
  new PetDebugPreset('第 4 天', 4, 2, 15, false, 2),
  new PetDebugPreset('第 10 天', 10, 2, 10, true, 7),
  new PetDebugPreset('第 35 天', 35, 3, 45, true, 30)
];

/**
 * 宠物调试开关。
 *
 * 只存在内存里：不落库、不持久化——重启应用就回到真实数据。
 * 调试状态不该被持久化，否则很容易忘记关掉，之后看到的全是假象。
 *
 * 另外它**只覆盖宠物显示**，不改动任何真实记录，所以首页的"已记录 N 餐"
 * 仍然是真实值，切到某个预设时两者可能不一致，这是刻意的。
 */
export class PetDebug {
  private static presetIndex: number = -1;

  static isActive(): boolean {
    return PetDebug.presetIndex >= 0;
  }

  static activeIndex(): number {
    return PetDebug.presetIndex;
  }

  /** @param index 越界时视为关闭调试 */
  static setPreset(index: number): void {
    PetDebug.presetIndex =
      index >= 0 && index < PET_DEBUG_PRESETS.length ? index : -1;
  }

  static clear(): void {
    PetDebug.presetIndex = -1;
  }

  /** 按当前预设算出宠物状态；未开启调试时返回 undefined */
  static resolve(species: PetSpecies): PetState | undefined {
    if (PetDebug.presetIndex < 0) {
      return undefined;
    }
    const preset: PetDebugPreset = PET_DEBUG_PRESETS[PetDebug.presetIndex];
    return PetEngine.evaluate(preset.mainMealCount, preset.activityMin,
      preset.waterDone, preset.streakDays, preset.growDays, species);
  }
}
