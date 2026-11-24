import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ContentSidePadding, CutoutRect, viewportFromArea } from '../utils/ContentCutout'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
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

  private placeholder(): string {
    const sourceName = sourceDisplayName(this.chrome.sourceId, this.chrome.sourceName).trim()
    return sourceName.length > 0 ? `${s('source_search_placeholder')} · ${sourceName}` : s('source_search_placeholder')
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
      left: this.sidePadding().left,
      right: this.sidePadding().right,
      bottom: ThemeConstants.SPACE_SM,
    })
    .onAreaChange((_old: Area, area: Area): void => { this.viewport = viewportFromArea(area) })
  }
}

@Builder
export function SourceBrowseTitleFieldContentBuilder(chrome: SourceBrowseRouteChromeState) {
  SourceBrowseTitleField({ chrome: chrome })
}
