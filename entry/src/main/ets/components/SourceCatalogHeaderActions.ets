import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { ThemeConstants } from '../theme/ThemeConstants'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'

export class SourceCatalogHeaderActionsParams {
  chrome: SourceCatalogPageChrome
  toggleSearch: () => void
  openManager: () => void
  constructor(chrome: SourceCatalogPageChrome, toggleSearch: () => void, openManager: () => void) {
    this.chrome = chrome
    this.toggleSearch = toggleSearch
    this.openManager = openManager
  }
}

/** The badge owns the actual management button, so both follow the HDS title. */
@ComponentV2
export struct SourceCatalogHeaderActions {
  @Require @Param params: SourceCatalogHeaderActionsParams
  @Local private sourceCache: SourcePackageManagerCache = appSourcePackageManagerCache
  @Local private imageRules: ImageRuleState = connectImageRuleState()
  @Local private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  private count(): number {
    void this.sourceCache.revision
    return this.sourceCache.updateCount + this.imageRules.updateCount
  }

  private endPadding(): number {
    const width = this.layout.windowWidthVp
    return width >= 800 ? ThemeConstants.SPACE_XXL : width >= 600 ? ThemeConstants.SPACE_XL : ThemeConstants.SPACE_LG
  }

  private material(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      colorInvert: true, applyShadow: true, interactive: true })
  }

  @Builder
  private IconAction(icon: Resource, label: string, id: string, action: () => void) {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(icon).fontSize(ThemeConstants.FONT_SIZE_H1).fontColor([$r('sys.color.font_primary')])
      }
      .id(id).width(ThemeConstants.INPUT_HEIGHT).height(ThemeConstants.INPUT_HEIGHT)
      .buttonStyle(ButtonStyleMode.NORMAL).backgroundColor(Color.Transparent).systemMaterial(this.material())
      .accessibilityText(label).onClick(action)
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(icon).fontSize(ThemeConstants.FONT_SIZE_H1).fontColor([$r('sys.color.font_primary')])
      }
      .id(id).width(ThemeConstants.INPUT_HEIGHT).height(ThemeConstants.INPUT_HEIGHT)
      .buttonStyle(ButtonStyleMode.NORMAL).accessibilityText(label).onClick(action)
    }
  }

  @Builder
  private ManagerButton() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      Button(AppStrings.get('route_source_package_manager_title'))
        .id('source-catalog-manage').height(ThemeConstants.INPUT_HEIGHT)
        .buttonStyle(ButtonStyleMode.NORMAL).fontColor($r('sys.color.font_primary')).borderRadius($r('sys.float.corner_radius_level10'))
        .backgroundColor(Color.Transparent).systemMaterial(this.material()).onClick(this.params.openManager)
    } else {
      Button(AppStrings.get('route_source_package_manager_title'))
        .id('source-catalog-manage').height(ThemeConstants.INPUT_HEIGHT)
        .buttonStyle(ButtonStyleMode.NORMAL).fontColor($r('sys.color.font_primary')).borderRadius($r('sys.float.corner_radius_level10'))
        .onClick(this.params.openManager)
    }
  }

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      this.IconAction($r('sys.symbol.magnifyingglass'), AppStrings.get('source_catalog_search_placeholder'),
        'source-catalog-search', this.params.toggleSearch)
      this.IconAction($r('sys.symbol.funnel'), AppStrings.get('common_filter'), 'source-catalog-filter',
        (): void => { this.params.chrome.request('filters') })
      if (this.count() > 0) {
        // Preserve the original count-keyed badge refresh while attaching it to its real button.
        ForEach([this.count()], (count: number) => {
          Badge({ count: count, position: BadgePosition.RightTop, style: {} }) { this.ManagerButton() }
        }, (count: number): string => count.toString())
      } else {
        this.ManagerButton()
      }
    }
    .width('100%').height(ThemeConstants.TITLE_BAR_HEIGHT)
    .justifyContent(FlexAlign.End).alignItems(VerticalAlign.Center)
    .padding({ right: this.endPadding() }).hitTestBehavior(HitTestMode.Transparent)
  }
}

@Builder
export function SourceCatalogHeaderActionsBuilder(params: SourceCatalogHeaderActionsParams) {
  SourceCatalogHeaderActions({ params: params })
}
