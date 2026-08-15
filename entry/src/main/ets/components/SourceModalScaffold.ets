import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from '@kit.UIDesignKit'
import { ThemeConstants } from '../theme/ThemeConstants'

// This is the HDS modal title reserve from the official Scroll-based
// half-modal example. It keeps the first content node below the modal title.
const SOURCE_MODAL_TITLE_BAR_HEIGHT: number = 80

@ComponentV2
export struct SourceModalScaffold {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Event onClose: () => void = () => {}
  @BuilderParam content: () => void
  private scroller: Scroller = new Scroller()

  build() {
    HdsNavigation() {
      Scroll(this.scroller) {
        Column() {
          Blank().height(SOURCE_MODAL_TITLE_BAR_HEIGHT)
          this.content()
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: this.title,
          subTitle: this.subtitle,
        },
        subIcon: {
          content: {
            label: 'modal_close',
            isEnabled: true,
            type: IconStyleMode.SMALL,
            action: () => {
              this.onClose()
            },
          },
        },
        menu: {
          value: [],
          maxCount: 0,
        },
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .bindToScrollable([this.scroller])
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
