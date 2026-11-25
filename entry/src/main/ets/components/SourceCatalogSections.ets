import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'
import { KomaSearchField } from './KomaSearchField'
import { AppearanceState, connectAppearanceState } from '../state/AppearanceState'

export const SOURCE_MANAGER_SECTIONS_HEIGHT: number = 64

export interface SourceCatalogSectionsParams {
  chrome: SourceCatalogPageChrome
  recovery: boolean
}

@ComponentV2
struct SourceCatalogSections {
  @Require @Param chrome: SourceCatalogPageChrome
  @Param recovery: boolean = false

  @Local private sourceCache: SourcePackageManagerCache = appSourcePackageManagerCache
  @Local private imageRuleState: ImageRuleState = connectImageRuleState()
  @Local private appearanceState: AppearanceState = connectAppearanceState()

  private sourceUpdateCount(): number {
    void this.sourceCache.revision
    return this.sourceCache.updateCount
  }

  private installedLabel(): string {
    return AppStrings.get(this.recovery ? 'settings_row_sources_title' : 'source_pkg_tab_installed')
  }

  private pluginsLabel(): string {
    return AppStrings.get(this.recovery ? 'image_plugins_title' : 'source_pkg_tab_plugins')
  }


  build() {
    // The cached ComponentContent keeps this V2 owner mounted; observe the
    // search state here so the fixed slot actually switches when it changes.
    if (this.chrome.searchExpanded) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaSearchField({ value: this.chrome.search.query, placeholder: AppStrings.get('source_catalog_search_placeholder'),
          autoFocus: true, useSystemMaterial: true,
          change: (value: string): void => { this.chrome.search.updateQuery(value) },
          submit: (value: string): void => { this.chrome.search.submitQuery(value) } })
          .layoutWeight(1)
      }
      .width('100%')
      .height(SOURCE_MANAGER_SECTIONS_HEIGHT)
      .alignItems(VerticalAlign.Center)
      .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS,
        left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    } else {
    Stack({ alignContent: Alignment.Center }) {
      // This title-bar ComponentContent is retained across theme changes. The
      // native segment caches its colours, so refresh just it on a mode change;
      // selection and scroll position remain owned by chrome and the page.
      ForEach([this.appearanceState.colorMode], (_mode: number) => {
        KomaSegmentedControl({
          labels: this.recovery ? [this.installedLabel(), this.pluginsLabel()] :
            [this.installedLabel(), AppStrings.get('source_pkg_tab_available'), this.pluginsLabel()],
          selectedIndex: this.chrome.section === 'sources' ? 0 : this.recovery || this.chrome.section === 'available' ? 1 : 2,
          select: (index: number): void => {
            // Keep HDS actions outside the segmented control's selection animation.
            this.getUIContext().animateToImmediately({ duration: 0 }, (): void => {
              this.chrome.selectSection(index === 0 ? 'sources' : index === 1 && !this.recovery ? 'available' : 'plugins')
            })
          },
        })
      }, (mode: number): string => mode.toString())
      // The native segments still handle selection and animation.
      Row() {
        SourceCatalogSegmentBadge({ label: this.installedLabel(),
          count: this.sourceUpdateCount(), selected: this.chrome.section === 'sources' })
        if (!this.recovery) SourceCatalogSegmentBadge({ label: AppStrings.get('source_pkg_tab_available') })
        SourceCatalogSegmentBadge({ label: this.pluginsLabel(),
          count: this.imageRuleState.updateCount, selected: this.chrome.section === 'plugins' })
      }
      .width('100%')
      .height('100%')
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(SOURCE_MANAGER_SECTIONS_HEIGHT)
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_SM })
    }
  }
}

@ComponentV2
struct SourceCatalogSegmentBadge {
  @Require @Param label: string
  @Param count: number = 0
  @Param selected: boolean = false

  build() {
    Row() {
      ForEach(this.count > 0 ? [this.count] : [], (count: number) => {
        Badge({ count, position: BadgePosition.Right, style: {} }) {
          // Match the native label's width, including localization and font weight.
          Text(this.label)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(this.selected ? FontWeight.Bold : FontWeight.Medium)
            .maxLines(1)
            .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
            .opacity(0)
            .accessibilityLevel('no')
            .hitTestBehavior(HitTestMode.None)
        }
        // BadgePosition.Right overlaps its anchor. Offset by a badge inset so
        // the number clears the visible label instead of covering its last glyph.
        .translate({ x: ThemeConstants.SPACE_LG })
        .hitTestBehavior(HitTestMode.None)
      }, (count: number): string => count.toString())
    }
    .hitTestBehavior(HitTestMode.None)
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}

@Builder
export function SourceCatalogSectionsBuilder(params: SourceCatalogSectionsParams) {
  SourceCatalogSections({ chrome: params.chrome, recovery: params.recovery })
}
