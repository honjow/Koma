import { AppStrings } from '../i18n/AppStrings'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { ThemeConstants } from '../theme/ThemeConstants'

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
      Search({ value: this.fieldText, placeholder: s('search_placeholder') })
        .layoutWeight(1)
        .height(ThemeConstants.INPUT_HEIGHT)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
        .searchButton(s('tab_search'), { fontColor: ThemeConstants.BRAND_PRIMARY })
        .onChange((value: string) => {
          this.fieldText = value
          this.chrome.updateQuery(value)
        })
        .onSubmit((value: string) => {
          this.fieldText = value
          this.chrome.submitQuery(value)
        })
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
