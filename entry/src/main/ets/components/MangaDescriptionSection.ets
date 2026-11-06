import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaActionButton } from './ui/KomaActionButton'
import { MarkdownSpans } from './MarkdownContent'
import { MarkdownDocument, MarkdownInline } from '../parser/MarkdownDocument'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct MangaDescriptionSection {
  @Param titleKey: string = 'common_description'
  @Param description: string | undefined = undefined
  @Param expandOnlyWhenOverflow: boolean = false
  @Param formatSynopsis: boolean = false
  @Event onLinkClick: (url: string) => void = (_url: string) => {}
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private expanded: boolean = false
  @Local private overflowsPreview: boolean = false
  private contentWidth: number = 0

  @Monitor('description', 'expandOnlyWhenOverflow')
  private descriptionChanged(): void {
    if (!this.expandOnlyWhenOverflow) return
    this.expanded = false
    this.measurePreviewOverflow()
  }

  private measurePreviewOverflow(): void {
    if (!this.expandOnlyWhenOverflow || this.contentWidth <= 0) return
    // Notes use the native text layout at the actual width, not a character-count
    // estimate. Source synopses retain their independently accepted expand action.
    const measure = this.getUIContext().getMeasureUtils()
    const full = measure.measureTextSize({ textContent: this.normalizedDescription(),
      constraintWidth: this.contentWidth, fontSize: ThemeConstants.FONT_SIZE_BODY,
      lineHeight: ThemeConstants.LINE_HEIGHT_TITLE })
    const preview = measure.measureTextSize({ textContent: this.normalizedDescription(),
      constraintWidth: this.contentWidth, fontSize: ThemeConstants.FONT_SIZE_BODY,
      lineHeight: ThemeConstants.LINE_HEIGHT_TITLE, maxLines: 3 })
    this.overflowsPreview = Number(full.height) > Number(preview.height)
  }

  private normalizedDescription(): string {
    return this.description?.trim() ?? ''
  }

  private hasDescription(): boolean {
    return this.normalizedDescription().length > 0
  }

  @Computed
  get synopsisSpans(): MarkdownInline[] {
    return this.formatSynopsis ? MarkdownDocument.synopsisSpans(this.normalizedDescription()) : []
  }

  private toggleLabel(): string {
    return this.expanded ? s('common_collapse') : s('common_expand')
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(s(this.titleKey))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      Text(this.synopsisSpans.length > 0 ? undefined :
        (this.hasDescription() ? this.normalizedDescription() : s('manga_detail_description_empty'))) {
        if (this.synopsisSpans.length > 0) {
          MarkdownSpans(this.synopsisSpans, ThemeConstants.TEXT_PRIMARY, false, this.onLinkClick, false)
        }
      }
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(this.hasDescription() ? ThemeConstants.TEXT_PRIMARY : ThemeConstants.TEXT_SECONDARY)
        // Expanded source descriptions must include their trailing aliases.
        // Keep the existing three-line collapsed preview and empty placeholder.
        .maxLines(this.expanded ? undefined : (this.hasDescription() ? 3 : 20))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .copyOption(this.formatSynopsis && this.hasDescription() ? CopyOptions.LocalDevice : CopyOptions.None)
        .animation({ duration: 180, curve: Curve.EaseInOut })
        .onAreaChange((_oldArea: Area, area: Area) => {
          this.contentWidth = Number(area.width)
          this.measurePreviewOverflow()
        })

      if (this.hasDescription() && (!this.expandOnlyWhenOverflow || this.overflowsPreview)) {
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
