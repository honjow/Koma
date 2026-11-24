import { CutoutRect, viewportFromArea } from '../utils/ContentCutout'
import { KomaSheetOptions, komaModalContentBackground, komaSheetOptions } from '../theme/KomaPopupOptions'
import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, hdsMaterial, ScrollEffectType, BlurStrategy, DividerShowType, BottomBuilderParams } from '@kit.UIDesignKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'
import { ThemeConstants } from '../theme/ThemeConstants'

export const KOMA_MODAL_TABS_HEADER_HEIGHT: number = ThemeConstants.BUTTON_HEIGHT +
  ThemeConstants.SPACE_XS * 2 + ThemeConstants.SPACE_MD + ThemeConstants.SPACE_SM

// This scaffold owns its HDS title bar. Reserve no second title/drag-bar row
// above it; the native drag indicator floats over the standard modal header.
export function komaModalSheetOptions(options: KomaSheetOptions): SheetOptions {
  options.enableFloatingDragBar = true
  return komaSheetOptions(options)
}

export function komaModalCloseAction(onClose: () => void): HdsNavigationMenuItemOptions {
  return { content: { label: AppStrings.get('common_close'), icon: $r('sys.symbol.xmark'),
    isEnabled: true, action: onClose } }
}

export function komaModalTitleBarOptions(title: ResourceStr, actions: HdsNavigationMenuItemOptions[],
  subtitle?: ResourceStr, titleBottom?: BottomBuilderParams): HdsNavigationTitleBarOptions {
  return {
    enableComponentSafeArea: true,
    style: {
      systemMaterialEffect: deviceInfo.apiAvailable('6.1.0') ? {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      } : undefined,
      scrollEffectOpts: { enableScrollEffect: true, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
      blurStrategy: BlurStrategy.ENABLE,
    },
    content: {
      bottomBuilder: titleBottom,
      title: { mainTitle: title, subTitle: subtitle },
      menu: { value: actions, maxCount: Math.min(3, actions.length) },
    },
  }
}

@ComponentV2
export struct KomaModalContent {
  @Local private viewport?: CutoutRect = undefined
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param useInset: boolean = true
  @BuilderParam content: () => void

  build() {
    if (this.useInset) {
      Column() {
        this.content()
      }
      .width('100%')
      .height('100%')
      .padding(this.viewport === undefined ? { left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG } :
        this.safeArea.sidePadding(ThemeConstants.SPACE_LG, this.viewport))
      .onAreaChange((_old: Area, area: Area): void => { this.viewport = viewportFromArea(area) })
    } else {
      this.content()
    }
  }
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
  @Param contentOwnsNavigation: boolean = false
  // Fixed search results can consume scrolling without changing the sheet detent.
  @Param keepScrollInContent: boolean = false
  @Param titleBottom: BottomBuilderParams | undefined = undefined
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
  @Local private viewport?: CutoutRect = undefined
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  private bodyPadding(): Padding {
    const base = this.contentHorizontalPadding
    return this.viewport === undefined ? { left: base, right: base } : this.layout.sidePadding(base, this.viewport)
  }

  // Editors share the native modal title bar. Optional confirmation stays
  // outside the scrolling form; existing read-only sheets retain only Close.
  private titleBarActions(): HdsNavigationMenuItemOptions[] {
    const items: HdsNavigationMenuItemOptions[] = this.additionalActions.slice()
    if (this.confirmLabel !== undefined) {
      items.push({ content: { label: this.confirmLabel, icon: $r('sys.symbol.checkmark'),
        isEnabled: this.confirmEnabled, action: (): void => { this.onConfirm() } } })
    }
    items.push(komaModalCloseAction(this.onClose))
    return items
  }

  @Builder
  private TabHeader() {
    Column() {
      KomaSegmentedControl({ labels: this.tabLabels, selectedIndex: this.selectedTab,
        select: (index: number): void => { this.onTabSelect(index) } })
    }
    .width('100%')
    .padding({ left: this.bodyPadding().left, right: this.bodyPadding().right,
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
        .padding(this.bodyPadding())
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
      if (this.contentOwnsNavigation) {
        this.content()
      } else if (this.tabLabels.length > 0) {
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
              .padding(this.bodyPadding())
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
              .padding(this.bodyPadding())
              .scrollBar(BarState.Off)
              // Keep outgoing rows rendered while they pass beneath the HDS title bar.
              .clip(false)
              .cachedCount(3, true)
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .nestedScroll({
                scrollForward: this.keepScrollInContent ? NestedScrollMode.SELF_ONLY : NestedScrollMode.SELF_FIRST,
                scrollBackward: this.keepScrollInContent ? NestedScrollMode.SELF_ONLY : NestedScrollMode.SELF_FIRST,
              })
            }
          }.width('100%').height('100%')
        }
        .titleBar(komaModalTitleBarOptions(this.title, this.titleBarActions(), this.subtitle, this.titleBottom))
        .titleMode(HdsNavigationTitleMode.MODAL)
        .bindToScrollable([this.scroller])
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old: Area, area: Area): void => { this.viewport = viewportFromArea(area) })
    .clip(this.contentOwnsNavigation)
    .backgroundColor(komaModalContentBackground(this.modalSurfaceColor))
  }
}
