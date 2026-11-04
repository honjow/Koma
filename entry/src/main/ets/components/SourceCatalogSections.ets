import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'

export const SOURCE_MANAGER_SECTIONS_HEIGHT: number = 64

@ComponentV2
struct SourceCatalogSections {
  @Require @Param chrome: SourceCatalogPageChrome

  @Local private sourceCache: SourcePackageManagerCache = appSourcePackageManagerCache
  @Local private imageRuleState: ImageRuleState = connectImageRuleState()

  private sourceUpdateCount(): number {
    void this.sourceCache.revision
    return this.sourceCache.updateCount
  }


  build() {
    Stack({ alignContent: Alignment.Center }) {
      KomaSegmentedControl({
        labels: [AppStrings.get('settings_row_sources_title'), AppStrings.get('image_plugins_title')],
        selectedIndex: this.chrome.section === 'sources' ? 0 : 1,
        select: (index: number): void => {
          // Keep HDS actions outside the segmented control's selection animation.
          this.getUIContext().animateToImmediately({ duration: 0 }, (): void => {
            this.chrome.selectSection(index === 0 ? 'sources' : 'plugins')
          })
        },
      })
      // The native segments still handle selection and animation.
      Row() {
        SourceCatalogSegmentBadge({ label: AppStrings.get('settings_row_sources_title'),
          count: this.sourceUpdateCount(), selected: this.chrome.section === 'sources' })
        SourceCatalogSegmentBadge({ label: AppStrings.get('image_plugins_title'),
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
export function SourceCatalogSectionsBuilder(chrome: SourceCatalogPageChrome) {
  SourceCatalogSections({ chrome })
}
