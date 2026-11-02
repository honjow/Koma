import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'

export const SOURCE_MANAGER_SECTIONS_HEIGHT: number = 64

@ComponentV2
struct SourceCatalogSections {
  @Require @Param chrome: SourceCatalogPageChrome

  build() {
    Column() {
      KomaSegmentedControl({
        labels: [AppStrings.get('settings_row_sources_title'), AppStrings.get('image_plugins_title')],
        selectedIndex: this.chrome.section === 'sources' ? 0 : 1,
        select: (index: number): void => { this.chrome.selectSection(index === 0 ? 'sources' : 'plugins') },
      })
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
