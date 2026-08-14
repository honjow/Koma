import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

// HdsNavigation lays out its own Scroll below the modal title. A caller-owned
// Scroll starts beneath that overlay, so it reserves the official modal title
// height as its own first child.
export const KOMA_MODAL_CALLER_SCROLL_TITLE_RESERVE: number = 80

export enum KomaModalScrollOwner {
  SCAFFOLD,
  CALLER,
}

@ComponentV2
export struct KomaModalScaffold {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param scrollOwner: KomaModalScrollOwner = KomaModalScrollOwner.SCAFFOLD
  @Param scroller: Scroller = new Scroller()
  @Event onClose: () => void = () => {}
  @BuilderParam content: () => void

  build() {
    HdsNavigation() {
      if (this.scrollOwner === KomaModalScrollOwner.SCAFFOLD) {
        Scroll(this.scroller) {
          Column() {
            this.content()
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST,
        })
        .width('100%')
        .height('100%')
      } else {
        Column() {
          this.content()
        }
        .width('100%')
        .height('100%')
      }
    }
    .titleBar({
      content: {
        title: {
          mainTitle: this.title,
          subTitle: this.subtitle,
        },
        subIcon: {
          content: {
            label: AppStrings.get('common_close'),
            icon: $r('sys.symbol.xmark'),
            isEnabled: true,
            action: () => {
              this.onClose()
            },
          },
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
