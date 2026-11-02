import { komaModalContentBackground, komaSheetOptions } from '../theme/KomaPopupOptions'
import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationMenuItemOptions, hdsMaterial } from '@kit.UIDesignKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'
import { ThemeConstants } from '../theme/ThemeConstants'

// This scaffold owns its HDS title bar. Reserve no second title/drag-bar row
// above it; the native drag indicator floats over the standard modal header.
export function komaModalSheetOptions(options: SheetOptions): SheetOptions {
  options.enableFloatingDragBar = true
  return komaSheetOptions(options)
}

@ComponentV2
export struct KomaModalScaffold {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param modalSurfaceColor: ResourceColor = ThemeConstants.BG_SUB
  // The shared modal owns the standard content inset. Callers supply content,
  // not another horizontal wrapper. A full-bleed WebView explicitly opts out.
  @Param contentHorizontalPadding: number = ThemeConstants.SPACE_LG
  @Param contentOwnsScrolling: boolean = false
  @Param confirmLabel: ResourceStr | undefined = undefined
  @Param confirmEnabled: boolean = true
  @Param additionalActions: HdsNavigationMenuItemOptions[] = []
  @Event onClose: () => void = () => {}
  @Event onConfirm: () => void = () => {}
  @Param tabLabels: string[] = []
  @Param selectedTab: number = 0
  @Event onTabSelect: (index: number) => void = () => {}
  @BuilderParam content: () => void
  private scroller: Scroller = new Scroller()
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  // Editors share the native modal title bar. Optional confirmation stays
  // outside the scrolling form; existing read-only sheets retain only Close.
  private titleBarActions(): HdsNavigationMenuItemOptions[] {
    const items: HdsNavigationMenuItemOptions[] = this.additionalActions.slice()
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
        Column() {
          // An opted-in tab header replaces the title bar, while this common owner
          // retains the material, insets and native sheet/drag behavior.
          if (this.tabLabels.length > 0) {
            KomaSegmentedControl({ labels: this.tabLabels, selectedIndex: this.selectedTab,
              select: (index: number): void => { this.onTabSelect(index) } })
              .padding({ left: this.contentHorizontalPadding, right: this.contentHorizontalPadding,
                top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_SM })
          }
          if (this.contentOwnsScrolling) {
            Column() {
              this.content()
            }
            .layoutWeight(1)
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
            .layoutWeight(1)
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
        }.width('100%').height('100%')
      }
      .titleBar({
        enableComponentSafeArea: true,
        style: {
          // The sheet's material does not configure HDS title actions. Keep the
          // shared title bar on the same adaptive material contract as app pages.
          systemMaterialEffect: deviceInfo.apiAvailable('6.1.0') ? {
            materialType: hdsMaterial.MaterialType.ADAPTIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
          } : undefined,
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
            maxCount: Math.min(3, this.additionalActions.length + (this.confirmLabel === undefined ? 1 : 2)),
          },
        },
      })
      .titleMode(HdsNavigationTitleMode.MODAL)
      .hideTitleBar(this.tabLabels.length > 0)
      .bindToScrollable([this.scroller])
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(komaModalContentBackground(this.modalSurfaceColor))
  }
}
