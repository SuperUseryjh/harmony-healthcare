import { Theme } from '../utils/Theme';

/**
 * 覆盖页的顶部操作条。
 *
 * 记录三餐、记录运动、编辑档案这类页面以全屏覆盖的形式出现（盖住 Dock），
 * 因此需要一个明确的退出入口，而不是依赖系统返回手势。
 */
@Component
export struct OverlayHeader {
  title: string = '';
  /** 左侧退出按钮的文案：新建流程用"取消"，编辑流程用"返回" */
  closeLabel: string = '取消';
  onClose: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.closeLabel)
          .fontSize(15)
          .fontColor(Theme.TEXT_SECONDARY)
          .onClick(() => {
            this.onClose();
          })

        Blank()

        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .letterSpacing(0.6)

        Blank()
      }
      .width('100%')
      .height(48)
      .padding({ left: 20, right: 20 })

      Divider().color(Theme.LINE)
    }
    .width('100%')
    .backgroundColor(Theme.BG_TOP)
  }
}
