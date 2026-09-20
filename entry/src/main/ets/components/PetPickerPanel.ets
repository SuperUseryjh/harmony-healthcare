import { promptAction } from '@kit.ArkUI';
import { PetExpression } from '../engine/PetEngine';
import { PetCatalog, PetSpecies } from '../model/PetSpecies';
import { PetCreatorService } from '../service/PetCreatorService';
import { Theme } from '../utils/Theme';
import { OverlayHeader } from './OverlayHeader';
import { PetGrid } from './PetGrid';

/**
 * 宠物选择面板（全屏覆盖，点首页宠物卡片唤出）。
 *
 * 物种列表来自 pet_config.json，加物种不需要改这里。
 * 缩略图的渲染规则（当前物种显示此刻的样子、其余显示最终形态）在 PetGrid 里，
 * 与初始化第二步共用同一份实现。
 */
@Component
export struct PetPickerPanel {
  @Prop currentCode: string = '';
  /** 当前物种所处的阶段下标 */
  @Prop currentStageIndex: number = 0;
  @Prop expression: number = PetExpression.NORMAL;

  onClose: () => void = () => {};
  /** 选中某个物种；保存与刷新由 Index 统一处理 */
  onPick: (code: string) => void = () => {};
  /** 去创建自建伙伴 */
  onCreate: () => void = () => {};
  /** 删掉了自建伙伴；Index 要判断删的是不是当前在用的那个 */
  onDeleted: (code: string) => void = () => {};

  /** 面板内的即时高亮，不等外部刷新 */
  @State selectedCode: string = '';
  /** 删除后目录变了，靠它触发网格重建 */
  @State listVersion: number = 0;

  aboutToAppear(): void {
    this.selectedCode = this.currentCode;
  }

  private customPets(): PetSpecies[] {
    return PetCatalog.all().filter((s: PetSpecies) => s.custom);
  }

  private confirmDelete(code: string, label: string): void {
    promptAction.showDialog({
      title: '删除伙伴',
      message: `确定要删掉「${label}」吗？健康记录和成长进度都不受影响。`,
      buttons: [
        { text: '取消', color: Theme.TEXT_SECONDARY },
        { text: '删除', color: Theme.PRIMARY }
      ]
    })
      .then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index === 1) {
          void this.doDelete(code);
        }
      })
      .catch(() => {
        // 弹窗失败不处理，用户再点一次即可
      });
  }

  private async doDelete(code: string): Promise<void> {
    await PetCreatorService.remove(code);
    const list: PetSpecies[] = await PetCreatorService.loadAll();
    PetCatalog.setUserPets(list);
    this.listVersion = this.listVersion + 1;
    this.onDeleted(code);
  }

  build() {
    Column() {
      OverlayHeader({
        title: '换个伙伴',
        closeLabel: '关闭',
        onClose: () => {
          this.onClose();
        }
      })

      Scroll() {
        Column({ space: 14 }) {
          Button('＋ 做一个自己的伙伴')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor(Theme.PRIMARY_SOFT)
            .fontColor(Theme.PRIMARY)
            .borderRadius(Theme.RADIUS_CHIP)
            .border({ width: 1, color: Theme.PRIMARY_LINE })
            .onClick(() => {
              this.onCreate();
            })

          PetGrid({
            selectedCode: this.selectedCode,
            currentCode: this.currentCode,
            currentStageIndex: this.currentStageIndex,
            expression: this.expression,
            listVersion: this.listVersion,
            onPick: (code: string) => {
              this.selectedCode = code;
              this.onPick(code);
            }
          })

          // 自建伙伴单独列一份管理入口。不把删除放进格子里，
          // 是因为格子本身是可点的选中区，里面再套一个删除按钮容易误触
          if (this.customPets().length > 0) {
            Column({ space: 8 }) {
              Text('我做的伙伴').fontSize(13).fontColor(Theme.TEXT_SECONDARY).width('100%')
              ForEach(this.customPets(), (spec: PetSpecies) => {
                Row({ space: 10 }) {
                  Text(spec.label)
                    .fontSize(14)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text('删除')
                    .fontSize(13)
                    .fontColor(Theme.PRIMARY)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(Theme.RADIUS_CHIP)
                    .border({ width: 1, color: Theme.PRIMARY_LINE })
                    .stateStyles({ pressed: { .opacity(0.6) } })
                    .onClick(() => {
                      this.confirmDelete(spec.code, spec.label);
                    })
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(Theme.CARD)
                .borderRadius(Theme.RADIUS_CHIP)
                .border({ width: 1, color: Theme.LINE })
              }, (spec: PetSpecies) => `${spec.code}-${this.listVersion}`)
            }
            .width('100%')
          }

          Text(`共 ${PetCatalog.all().length} 个伙伴，其中 ${this.customPets().length} 个是你自己做的`)
            .fontSize(11).fontColor(Theme.TEXT_TERTIARY).width('100%')
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 8, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
