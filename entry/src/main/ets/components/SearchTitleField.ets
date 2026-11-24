import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ContentSidePadding, CutoutRect, viewportFromArea } from '../utils/ContentCutout'
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
  @Param placeholder: string = s('search_placeholder')
  @Param focusOnShow: boolean = false
  @Local private viewport?: CutoutRect = undefined
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
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

  private sidePadding(): ContentSidePadding {
    const base = ThemeConstants.SPACE_LG
    return this.viewport === undefined ? { left: base, right: base } :
      this.safeArea.sidePadding(base, this.viewport, false)
  }

  build() {
    Row() {
      KomaSearchField({
        value: this.fieldText,
        placeholder: this.placeholder,
        autoFocus: this.chrome.autoFocus || this.focusOnShow,
        showSearchButton: true,
        searchButtonText: s('tab_search'),
        useSystemMaterial: true,
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
      left: this.sidePadding().left,
      right: this.sidePadding().right,
      bottom: ThemeConstants.SPACE_SM,
    })
    .onAreaChange((_old: Area, area: Area): void => { this.viewport = viewportFromArea(area) })
  }
}

@Builder
export function SearchTitleFieldContentBuilder(chrome: SearchRouteChromeState) {
  SearchTitleField({ chrome: chrome })
}

@Builder
export function TrackerSearchTitleFieldContentBuilder(chrome: SearchRouteChromeState) {
  SearchTitleField({ chrome: chrome, placeholder: s('manga_detail_tracker_search') })
}
