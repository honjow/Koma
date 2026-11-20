import { ComicId } from '../model/ComicModels'
import { ContinueReadingCardViewModel } from '../model/MockLibraryData'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { CachedCoverImage } from './CachedCoverImage'
import { KomaIconButton } from './ui/KomaIconButton'

const COVER_SIZE = 44
// Match the space above and below the cover in the native MiniBar.
const EXPANDED_COVER_LEFT_INSET = 6

@ComponentV2
export struct LibraryResumeMiniBar {
  @Param @Require info: ContinueReadingCardViewModel
  @Param expanded: boolean = false
  @Event onContinueReading: (comicId: ComicId) => void = (_comicId: ComicId) => {}

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
      if (this.info.coverUri !== undefined && this.info.coverUri.length > 0) {
        CachedCoverImage({
          uri: this.info.coverUri,
          coverOwnerId: this.info.comicId,
          objectFit: ImageFit.Cover,
          sourceRuntimeId: this.info.sourceRuntimeId ?? '',
          sourceImageId: this.info.sourceImageId ?? this.info.comicId,
          sourceKind: this.info.sourceKind,
          remoteServerId: this.info.remoteServerId ?? '',
          sourceMangaUrl: this.info.sourceMangaUrl ?? '',
          decodeMaxEdge: 160,
        })
      }
    }
    .width(COVER_SIZE)
    .height(COVER_SIZE)
    .borderRadius(COVER_SIZE / 2)
    .clip(true)
    .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
    .id('library-resume-minibar-cover')
    .accessibilityText(this.info.title)
    // HdsTabs owns the tap that expands the collapsed slot.
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      this.Cover()
      if (this.expanded) {
        Column({ space: 2 }) {
          Text(this.info.title)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.info.detail)
            .fontSize(ThemeConstants.FONT_SIZE_TINY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        // Let the native MiniBar provide the surface and keep the button's press feedback.
        KomaIconButton({
          icon: $r('sys.symbol.flipping_page_fill'),
          kind: 'ghost',
          controlSize: ThemeConstants.TOUCH_TARGET_SM,
          action: () => { this.onContinueReading(this.info.comicId) },
        })
        .id('library-resume-minibar-open')
        .accessibilityText(AppStrings.get('library_continue_reading'))
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.expanded ? { left: EXPANDED_COVER_LEFT_INSET, right: ThemeConstants.SPACE_SM } : 0)
    .justifyContent(this.expanded ? FlexAlign.Start : FlexAlign.Center)
    .id('library-resume-minibar')
  }
}
