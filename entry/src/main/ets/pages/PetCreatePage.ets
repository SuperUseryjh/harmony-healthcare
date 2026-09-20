import { promptAction } from '@kit.ArkUI';
import { AccessoryDef, PaletteDef, PetArtLib, ShapeDef } from '../engine/PetArtLib';
import { PetCatalog } from '../model/PetSpecies';
import { PetCreatorService } from '../service/PetCreatorService';
import { Theme } from '../utils/Theme';
import { ChipRow } from '../components/ChipRow';
import { OverlayHeader } from '../components/OverlayHeader';
import { PetPreview } from '../components/PetPreview';
import { SegmentedBar } from '../components/SegmentedBar';

const TAB_IMPORT: number = 0;
const TAB_RECIPE: number = 1;
const TAB_LABELS: string[] = ['导入照片', '捏一只'];

/** 脸的大小倍率范围。太小看不见，太大腮红会甩出身体 */
const FACE_SCALE_MIN: number = 0.6;
const FACE_SCALE_MAX: number = 1.5;

/**
 * 自建伙伴。
 *
 * 两条路线共用同一个页面：
 * - 导入照片：从相册选 1–3 张当三个阶段。只给一张也能用，靠体型变化表现成长。
 *   表情默认不叠加——照片里通常本来就有五官，再叠一层就成了四只眼。
 * - 捏一只：选轮廓 + 配色 + 配饰，由 PetArtLib 现场拼出 SVG。轮廓自带脸型，
 *   表情默认打开，眼睛正好落在为它留出的位置。
 *
 * 注意：这里不用带参数的 @Builder。@Builder 的参数按值传递，
 * 状态变了它不会重新执行，选中态和预览都会停住——这类活交给 ChipRow / PetPreview 两个组件。
 */
@Component
export struct PetCreatePage {
  /** 保存成功时带回新伙伴的 code；空串表示取消 */
  onClose: (newCode: string) => void = () => {};

  @State tab: number = TAB_RECIPE;
  @State draftLabel: string = '';

  // ---- 导入照片 ----
  @State pickedUris: string[] = [];
  @State faceOn: boolean = false;
  @State faceCy: number = -2.6;
  @State faceScale: number = 1;

  // ---- 捏一只 ----
  @State shapeIndex: number = 0;
  @State paletteIndex: number = 0;
  @State accessoryIndex: number = 0;
  /** 预览图的沙箱 URI。换选项时文件名会变，绕开 Image 的路径缓存 */
  @State previewUri: string = '';

  @State saving: boolean = false;

  aboutToAppear(): void {
    this.refreshPreview();
  }

  aboutToDisappear(): void {
    // 预览文件是临时的，离开就清掉；创建成功的正式文件不在这个路径上
    PetCreatorService.clearPreview(this.previewUri);
  }

  private currentShape(): ShapeDef {
    return PetArtLib.shapes()[this.shapeIndex];
  }

  private refreshPreview(): void {
    const sh: ShapeDef = this.currentShape();
    const pal: PaletteDef = PetArtLib.palettes()[this.paletteIndex];
    const acc: AccessoryDef = PetArtLib.accessories()[this.accessoryIndex];
    this.previewUri = PetCreatorService.renderPreview(sh.id, pal.id, acc.id, this.previewUri);
  }

  private async pick(): Promise<void> {
    const uris: string[] = await PetCreatorService.pickImages();
    if (uris.length === 0) {
      return;
    }
    this.pickedUris = uris;
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    if (this.tab === TAB_IMPORT && this.pickedUris.length === 0) {
      promptAction.showToast({ message: '先从相册选一张照片' });
      return;
    }
    this.saving = true;
    let code: string = '';
    if (this.tab === TAB_IMPORT) {
      code = await PetCreatorService.createFromImages(this.draftLabel, this.pickedUris,
        this.faceOn, this.faceCy, this.faceScale);
    } else {
      const sh: ShapeDef = this.currentShape();
      const pal: PaletteDef = PetArtLib.palettes()[this.paletteIndex];
      const acc: AccessoryDef = PetArtLib.accessories()[this.accessoryIndex];
      code = await PetCreatorService.createFromRecipe(this.draftLabel, sh.id, pal.id, acc.id);
    }
    this.saving = false;

    if (code.length === 0) {
      promptAction.showToast({ message: '创建失败了，再试一次' });
      return;
    }
    // 并入目录，选择面板下一次打开就能看到它
    const list = await PetCreatorService.loadAll();
    PetCatalog.setUserPets(list);
    this.onClose(code);
  }

  @Builder
  labelInput() {
    Column({ space: 6 }) {
      Text('给它起个名字').fontSize(13).fontColor(Theme.TEXT_SECONDARY).width('100%')
      TextInput({ text: this.draftLabel, placeholder: '最多 8 个字' })
        .maxLength(8)
        .height(46)
        .fontSize(15)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CHIP)
        .border({ width: 1, color: Theme.LINE })
        .onChange((value: string) => {
          this.draftLabel = value;
        })
    }
    .width('100%')
  }

  @Builder
  importTab() {
    Column({ space: 14 }) {
      this.labelInput()

      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Button(this.pickedUris.length === 0 ? '从相册选照片' : `已选 ${this.pickedUris.length} 张`)
            .fontSize(14)
            .height(42)
            .layoutWeight(1)
            .backgroundColor(Theme.PRIMARY)
            .onClick(() => {
              void this.pick();
            })
          if (this.pickedUris.length > 0) {
            Text('重选')
              .fontSize(13)
              .fontColor(Theme.TEXT_SECONDARY)
              .padding(10)
              .onClick(() => {
                this.pickedUris = [];
              })
          }
        }
        .width('100%')

        Text(this.pickedUris.length === 0
          ? '选 1–3 张：三张分别对应幼生、成长、成熟；只选一张也可以，靠体型变化表现成长'
          : '照片只在本机使用，不联网、不上传')
          .fontSize(11)
          .fontColor(Theme.TEXT_TERTIARY)
          .width('100%')
      }
      .width('100%')

      if (this.pickedUris.length > 0) {
        Row({ space: 8 }) {
          ForEach(this.pickedUris, (uri: string) => {
            Image(uri)
              .width(64)
              .height(64)
              .objectFit(ImageFit.Cover)
              .borderRadius(Theme.RADIUS_CHIP)
              .border({ width: 1, color: Theme.LINE })
          }, (uri: string, index: number) => `${index}-${uri}`)
        }
        .width('100%')

        // 叠表情的开关：默认关，因为照片里本来就有五官
        Row() {
          Column({ space: 2 }) {
            Text('叠加表情').fontSize(14).fontColor(Theme.TEXT_PRIMARY)
            Text('照片里已经有眼睛的话，不用打开').fontSize(11).fontColor(Theme.TEXT_TERTIARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.faceOn })
            .selectedColor(Theme.PRIMARY)
            .onChange((isOn: boolean) => {
              this.faceOn = isOn;
            })
        }
        .width('100%')
        .padding(14)
        .backgroundColor(Theme.CARD)
        .borderRadius(Theme.RADIUS_CARD)
        .border({ width: 1, color: Theme.LINE })

        if (this.faceOn) {
          Column({ space: 10 }) {
            Row() {
              Text('脸的位置').fontSize(13).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
              Text(`${Math.round(this.faceCy)}`).fontSize(13).fontColor(Theme.TEXT_TERTIARY)
            }
            .width('100%')

            Slider({ value: this.faceCy, min: -30, max: 30, step: 1 })
              .width('100%')
              .selectedColor(Theme.PRIMARY)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.faceCy = value;
              })

            Row() {
              Text('脸的大小').fontSize(13).fontColor(Theme.TEXT_SECONDARY).layoutWeight(1)
              Text(this.faceScale.toFixed(2)).fontSize(13).fontColor(Theme.TEXT_TERTIARY)
            }
            .width('100%')

            Slider({ value: this.faceScale, min: FACE_SCALE_MIN, max: FACE_SCALE_MAX, step: 0.05 })
              .width('100%')
              .selectedColor(Theme.PRIMARY)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.faceScale = value;
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Theme.CARD)
          .borderRadius(Theme.RADIUS_CARD)
          .border({ width: 1, color: Theme.LINE })
        }

        PetPreview({
          imagePath: this.pickedUris[0],
          showFace: this.faceOn,
          stageScale: 1,
          faceCy: this.faceCy,
          faceEyeDx: 9.6 * this.faceScale,
          faceEyeR: 2.7 * this.faceScale,
          faceBlushDx: 18.6 * this.faceScale,
          faceBlushR: 3.3 * this.faceScale
        })
      }
    }
    .width('100%')
  }

  @Builder
  recipeTab() {
    Column({ space: 14 }) {
      this.labelInput()

      PetPreview({
        imagePath: this.previewUri,
        showFace: true,
        stageScale: 1,
        faceCy: this.currentShape().faceCy,
        faceEyeDx: this.currentShape().faceEyeDx,
        faceEyeR: this.currentShape().faceEyeR,
        faceBlushDx: this.currentShape().faceBlushDx,
        faceBlushR: this.currentShape().faceBlushR
      })

      Column({ space: 10 }) {
        Text('轮廓').fontSize(13).fontColor(Theme.TEXT_SECONDARY).width('100%')
        ChipRow({
          labels: PetArtLib.shapes().map((s: ShapeDef) => s.label),
          selected: this.shapeIndex,
          group: 'shape',
          onPick: (index: number) => {
            this.shapeIndex = index;
            this.refreshPreview();
          }
        })

        Text('配色').fontSize(13).fontColor(Theme.TEXT_SECONDARY).width('100%')
        // 配色用色块而不是文字：选色这种事看一眼比读名字快。
        // 不用 Circle().fill()，那个接口要 API 26，而工程最低兼容是 6.1.0(23)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(PetArtLib.palettes(), (p: PaletteDef, index: number) => {
            Stack() {
              Text('')
                .width(30)
                .height(30)
                .backgroundColor(p.ripe)
                .borderRadius(15)
              if (index === this.paletteIndex) {
                Text('')
                  .width(38)
                  .height(38)
                  .borderRadius(19)
                  .border({ width: 2, color: Theme.TEXT_PRIMARY })
                  // 选中环是插入的节点，用 transition 让它弹出来而不是"啪"地出现
                  .transition(Theme.popEffect())
              }
            }
            .width(44)
            .height(44)
            .margin({ right: 6, bottom: 6 })
            .onClick(() => {
              this.paletteIndex = index;
              this.refreshPreview();
            })
          }, (p: PaletteDef, index: number) => `${p.id}-${index === this.paletteIndex}`)
        }
        .width('100%')

        Text('配饰').fontSize(13).fontColor(Theme.TEXT_SECONDARY).width('100%')
        ChipRow({
          labels: PetArtLib.accessories().map((a: AccessoryDef) => a.label),
          selected: this.accessoryIndex,
          group: 'acc',
          onPick: (index: number) => {
            this.accessoryIndex = index;
            this.refreshPreview();
          }
        })
      }
      .width('100%')
      .padding(14)
      .backgroundColor(Theme.CARD)
      .borderRadius(Theme.RADIUS_CARD)
      .border({ width: 1, color: Theme.LINE })
    }
    .width('100%')
  }

  build() {
    Column() {
      OverlayHeader({
        title: '做一个伙伴',
        closeLabel: '取消',
        onClose: () => {
          this.onClose('');
        }
      })

      Scroll() {
        Column({ space: 16 }) {
          SegmentedBar({
            labels: TAB_LABELS,
            selected: this.tab,
            onPick: (index: number) => {
              this.tab = index;
              if (index === TAB_RECIPE) {
                this.refreshPreview();
              }
            }
          })

          // 包一层容器才能挂 transition：@Builder 的调用是语句，没法直接链式调用
          if (this.tab === TAB_IMPORT) {
            Column() {
              this.importTab()
            }
            .width('100%')
            .transition(Theme.pageEffect())
          } else {
            Column() {
              this.recipeTab()
            }
            .width('100%')
            .transition(Theme.pageEffect())
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column() {
        Button(this.saving ? '正在保存…' : '就它了')
          .width('100%')
          .height(48)
          .fontSize(16)
          .backgroundColor(this.saving ? Theme.TRACK : Theme.PRIMARY)
          .fontColor(this.saving ? Theme.TEXT_TERTIARY : Color.White)
          .enabled(!this.saving)
          .onClick(() => {
            void this.save();
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 24 })
      .backgroundColor(Theme.CARD)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_BOTTOM)
  }
}
