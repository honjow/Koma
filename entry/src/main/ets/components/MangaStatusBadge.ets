import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

/** The detail header and shelf list share the existing status pill, including
 * its semantic colors and native typography. Unknown status remains a caller's
 * visibility decision; the detail header still displays its original label. */
@ComponentV2
export struct MangaStatusBadge {
  @Param status: string = 'unknown'
  @Param presentation: 'pill' | 'inline' = 'pill'
  @Local private languageState: LanguageState = connectLanguageState()

  private label(): string {
    void this.languageState.effectiveLocale
    return AppStrings.get(this.status === 'ongoing' || this.status === 'completed' ||
      this.status === 'hiatus' || this.status === 'cancelled' ? `manga_status_${this.status}` : 'manga_status_unknown')
  }

  private statusBackgroundColor(): ResourceColor {
    if (this.status === 'ongoing') return ThemeConstants.STATUS_SUCCESS
    if (this.status === 'completed') return ThemeConstants.STATUS_INFO
    if (this.status === 'hiatus') return ThemeConstants.STATUS_MUTED
    if (this.status === 'cancelled') return ThemeConstants.STATUS_DANGER
    return ThemeConstants.TEXT_SECONDARY
  }

  build() {
    if (this.presentation === 'inline') {
      Text(this.label())
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(ThemeConstants.LINE_HEIGHT_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.statusBackgroundColor())
        .maxLines(1)
    } else {
      Text(this.label())
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD,
          top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(this.statusBackgroundColor())
    }
  }
}
