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

  @Builder
  private SegmentBadge(label: string, count: number, selected: boolean) {
    Row() {
      if (count > 0) {
        Badge({ count, position: BadgePosition.Right, style: {} }) {
          // Match the native label's width, including localization and font weight.
          Text(label)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
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
      }
    }
    .hitTestBehavior(HitTestMode.None)
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
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
        this.SegmentBadge(AppStrings.get('settings_row_sources_title'), this.sourceUpdateCount(),
          this.chrome.section === 'sources')
        this.SegmentBadge(AppStrings.get('image_plugins_title'), this.imageRuleState.updateCount,
          this.chrome.section === 'plugins')
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

@Builder
export function SourceCatalogSectionsBuilder(chrome: SourceCatalogPageChrome) {
  SourceCatalogSections({ chrome })
}
