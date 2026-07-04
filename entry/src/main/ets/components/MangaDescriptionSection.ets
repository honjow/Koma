import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaActionButton } from './ui/KomaActionButton'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct MangaDescriptionSection {
  @Param description: string | undefined = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private expanded: boolean = false

  private normalizedDescription(): string {
    return this.description?.trim() ?? ''
  }

  private hasDescription(): boolean {
    return this.normalizedDescription().length > 0
  }

  private toggleLabel(): string {
    return this.expanded ? s('common_collapse') : s('common_expand')
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(s('common_description'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      Text(this.hasDescription() ? this.normalizedDescription() : s('manga_detail_description_empty'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(this.hasDescription() ? ThemeConstants.TEXT_PRIMARY : ThemeConstants.TEXT_SECONDARY)
        .maxLines(this.expanded || !this.hasDescription() ? 20 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 180, curve: Curve.EaseInOut })

      if (this.hasDescription()) {
        KomaActionButton({
          label: this.toggleLabel(),
          kind: 'ghost',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.expanded = !this.expanded
          },
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
