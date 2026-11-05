import { AppStrings } from '../i18n/AppStrings'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { SearchTitleField } from './SearchTitleField'

/** Keep the shared title search mounted through the closing height animation. */
@ComponentV2
export struct SourceCatalogBottomSearch {
  @Require @Param chrome: SourceCatalogPageChrome

  build() {
    Column() {
      if (this.chrome.searchVisible) {
        SearchTitleField({ chrome: this.chrome.search, placeholder: AppStrings.get('source_catalog_search_placeholder'),
          focusOnShow: this.chrome.searchFocus })
      }
    }
    .width('100%')
    .height(this.chrome.searchHeight)
    // Clip only while height changes; the settled search keeps its material shadow.
    .clip(this.chrome.searchAnimating)
  }
}

@Builder
export function SourceCatalogBottomSearchBuilder(chrome: SourceCatalogPageChrome) {
  SourceCatalogBottomSearch({ chrome: chrome })
}
