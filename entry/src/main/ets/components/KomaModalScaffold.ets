import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct KomaModalScaffold {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param modalSurfaceColor: ResourceColor = ThemeConstants.BG_SUB
  @Param contentHorizontalPadding: number = 0
  @Param contentOwnsScrolling: boolean = false
  @Event onClose: () => void = () => {}
  @BuilderParam content: () => void
  private scroller: Scroller = new Scroller()
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation() {
        if (this.contentOwnsScrolling) {
          Column() {
            this.content()
          }
          .height('100%')
          .width('100%')
          .padding({
            left: this.contentHorizontalPadding,
            right: this.contentHorizontalPadding,
          })
        } else {
          List({ space: ThemeConstants.SPACE_SM, scroller: this.scroller }) {
            this.content()
            ListItem() {
              Column() {
                Blank()
                  .height(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD)
              }
              .width('100%')
            }
          }
          .height('100%')
          .width('100%')
          .padding({
            left: this.contentHorizontalPadding,
            right: this.contentHorizontalPadding,
          })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST,
          })
        }
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: {
            mainTitle: this.title,
            subTitle: this.subtitle,
          },
          menu: {
            value: [{
              content: {
                label: AppStrings.get('common_close'),
                icon: $r('sys.symbol.xmark'),
                isEnabled: true,
                action: () => {
                  this.onClose()
                },
              },
            }],
            maxCount: 1,
          },
        },
      })
      .titleMode(HdsNavigationTitleMode.MODAL)
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.modalSurfaceColor)
  }
}
