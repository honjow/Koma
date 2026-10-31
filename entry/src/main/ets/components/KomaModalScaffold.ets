import { komaModalContentBackground } from '../theme/KomaPopupOptions'
import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'
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
  @Param confirmLabel: ResourceStr | undefined = undefined
  @Param confirmEnabled: boolean = true
  @Event onClose: () => void = () => {}
  @Event onConfirm: () => void = () => {}
  @BuilderParam content: () => void
  private scroller: Scroller = new Scroller()
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  // Editors share the native modal title bar. Optional confirmation stays
  // outside the scrolling form; existing read-only sheets retain only Close.
  private titleBarActions(): HdsNavigationMenuItemOptions[] {
    const items: HdsNavigationMenuItemOptions[] = []
    if (this.confirmLabel !== undefined) {
      items.push({ content: { label: this.confirmLabel, icon: $r('sys.symbol.checkmark'),
        isEnabled: this.confirmEnabled, action: (): void => { this.onConfirm() } } })
    }
    items.push({ content: { label: AppStrings.get('common_close'), icon: $r('sys.symbol.xmark'),
      isEnabled: true, action: (): void => { this.onClose() } } })
    return items
  }

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
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST,
          })
        }
      }
      .titleBar({
        enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: false,
          },
        },
        content: {
          title: {
            mainTitle: this.title,
            subTitle: this.subtitle,
          },
          menu: {
            value: this.titleBarActions(),
            maxCount: this.confirmLabel === undefined ? 1 : 2,
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
    .backgroundColor(komaModalContentBackground(this.modalSurfaceColor))
  }
}
