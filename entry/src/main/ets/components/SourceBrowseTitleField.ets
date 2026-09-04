import { AppStrings } from '../i18n/AppStrings'
import { SourceBrowseRouteChromeState } from '../state/SourceRouteChromeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaSearchField } from './KomaSearchField'

export const SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT: number = ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_SM

function s(name: string): string {
  return AppStrings.get(name)
}

/**
 * In-place source search field pinned in the browse page's HDS title-bar
 * bottomBuilder. Typing searches the current source without leaving browse;
 * the page mirrors the query through SourceBrowseRouteChromeState.
 */
@ComponentV2
export struct SourceBrowseTitleField {
  @Param chrome: SourceBrowseRouteChromeState = new SourceBrowseRouteChromeState()
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

  private placeholder(): string {
    const sourceName = this.chrome.sourceName.trim()
    return sourceName.length > 0 ? `${s('source_search_placeholder')} · ${sourceName}` : s('source_search_placeholder')
  }

  build() {
    Row() {
      KomaSearchField({
        value: this.fieldText,
        placeholder: this.placeholder(),
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
    .height(SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      bottom: ThemeConstants.SPACE_SM,
    })
  }
}

@Builder
export function SourceBrowseTitleFieldContentBuilder(chrome: SourceBrowseRouteChromeState) {
  SourceBrowseTitleField({ chrome: chrome })
}
