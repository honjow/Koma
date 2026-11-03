import { komaModalContentBackground, komaSheetOptions } from '../theme/KomaPopupOptions'
import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationMenuItemOptions, hdsMaterial, ScrollEffectType, BlurStrategy, DividerShowType } from '@kit.UIDesignKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'
import { ThemeConstants } from '../theme/ThemeConstants'

export const KOMA_MODAL_TABS_HEADER_HEIGHT: number = ThemeConstants.BUTTON_HEIGHT +
  ThemeConstants.SPACE_XS * 2 + ThemeConstants.SPACE_MD + ThemeConstants.SPACE_SM

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
  @Param tabScrolled: boolean = false
  @Event onTabSelect: (index: number) => void = () => {}
  @Event onTabHeaderHeightChange: (height: number) => void = () => {}
  @Local private tabHeaderHeight: number = KOMA_MODAL_TABS_HEADER_HEIGHT
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

  @Builder
  private TabHeader() {
    Column() {
      KomaSegmentedControl({ labels: this.tabLabels, selectedIndex: this.selectedTab,
        select: (index: number): void => { this.onTabSelect(index) } })
    }
    .width('100%')
    .padding({ left: this.contentHorizontalPadding, right: this.contentHorizontalPadding,
      top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_SM })
    .onSizeChange((_oldSize: SizeOptions, size: SizeOptions): void => {
      const height = Number(size.height)
      if (height > 0 && height !== this.tabHeaderHeight) {
        this.tabHeaderHeight = height
        this.onTabHeaderHeightChange(height)
      }
    })
  }

  @Builder
  private TabbedModal() {
    // HDS does not read a retained offset when swapping list bindings.
    // The reader supplies whether the visible list is already past its top.
    HdsNavigation() {
      Column() { this.content() }
        .width('100%').height('100%')
        .padding({ left: this.contentHorizontalPadding, right: this.contentHorizontalPadding })
    }
    .titleBar({
      enableComponentSafeArea: false,
      content: { title: { mainTitle: '' },
        divider: { showType: DividerShowType.OFF } },
      style: {
        systemMaterialEffect: deviceInfo.apiAvailable('6.1.0') ? {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        } : undefined,
        blurStrategy: BlurStrategy.ENABLE,
        scrollEffectOpts: { enableScrollEffect: !this.tabScrolled, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.tabLabels.length > 0) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.TabbedModal()
          this.TabHeader()
        }.width('100%').height('100%')
      } else {
        HdsNavigation() {
          Column() {
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
              enableScrollEffect: true,
              scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            },
            blurStrategy: BlurStrategy.ENABLE,
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
        .bindToScrollable([this.scroller])
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(komaModalContentBackground(this.modalSurfaceColor))
  }
}
