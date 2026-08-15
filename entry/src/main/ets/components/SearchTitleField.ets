import { AppStrings } from '../i18n/AppStrings'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaSearchField } from './KomaSearchField'

export const SEARCH_TITLE_BOTTOM_HEIGHT: number = ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_SM

function s(name: string): string {
  return AppStrings.get(name)
}

/**
 * Stable Search instance hosted by a pushed search route's HDS title-bar
 * bottomBuilder. The route host caches ComponentContent while this component
 * mirrors the route-local query so title-bar updates do not remount a focused
 * field.
 */
@ComponentV2
export struct SearchTitleField {
  @Param chrome: SearchRouteChromeState = new SearchRouteChromeState()
  @Local private fieldText: string = ''

  aboutToAppear(): void {
    this.fieldText = this.chrome.query
  }

  @Monitor('chrome.query')
  private syncExternalQuery(): void {
    if (this.fieldText !== this.chrome.query) {
      this.fieldText = this.chrome.query
    }
  }

  build() {
    Row() {
      KomaSearchField({
        value: this.fieldText,
        placeholder: s('search_placeholder'),
        showSearchButton: true,
        searchButtonText: s('tab_search'),
        change: (value: string) => {
          this.fieldText = value
          this.chrome.updateQuery(value)
        },
        submit: (value: string) => {
          this.fieldText = value
          this.chrome.submitQuery(value)
        },
      })
        .layoutWeight(1)
    }
    .width('100%')
    .height(SEARCH_TITLE_BOTTOM_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      bottom: ThemeConstants.SPACE_SM,
    })
  }
}

@Builder
export function SearchTitleFieldContentBuilder(chrome: SearchRouteChromeState) {
  SearchTitleField({ chrome: chrome })
}
