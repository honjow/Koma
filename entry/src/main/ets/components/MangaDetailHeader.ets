import { connectMangaDetailTransition, MangaDetailTransitionState } from '../state/MangaDetailTransitionState'
import { LengthMetrics } from '@kit.ArkUI'
import { CachedCoverImage, cachedCoverFailureKey, coverDecodeEdgeForDisplay } from './CachedCoverImage'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { MangaDetail } from '../model/MangaDetailModels'
import { MangaStatusBadge } from './MangaStatusBadge'
import { ComicSourceKind } from '../model/ComicModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { formatMangaCreatorList } from './MangaCreatorText'

const DETAIL_COVER_HEIGHT = 148

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct MangaDetailHeader {
  @Param transitionCoverId: string = ''
  @Local private detailTransition: MangaDetailTransitionState = connectMangaDetailTransition()
  @Param manga: MangaDetail = {
    id: '',
    title: '',
    chapterCount: 0,
    isInLibrary: false,
  }
  @Param showChapterCount: boolean = true
  @Param sourceKind: ComicSourceKind | undefined = undefined
  @Param remoteServerId: string = ''
  @Param sourceUnavailable: boolean = false
  @Event onSourceClick: () => void = () => {}
  @Event onTitleClick?: () => void
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private failedCoverUrl: string = ''

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(
      this.manga.coverUrl,
      this.manga.sourceId ?? '',
      this.manga.sourceImageId ?? this.manga.id,
      this.sourceKind,
      this.remoteServerId,
      this.manga.url,
    )
  }

  private displayTitle(): string {
    return this.manga.title.length > 0 ? this.manga.title : s('manga_detail_title_fallback')
  }

  private creatorText(): string {
    const author = this.manga.author === undefined ? '' : this.manga.author
    const artist = this.manga.artist === undefined ? '' : this.manga.artist
    if (author.length > 0 && artist.length > 0 && author !== artist) {
      return `${formatMangaCreatorList(author)} / ${formatMangaCreatorList(artist)}`
    }
    if (author.length > 0) {
      return formatMangaCreatorList(author)
    }
    if (artist.length > 0) {
      return formatMangaCreatorList(artist)
    }
    return s('manga_detail_creator_unknown')
  }

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(this.hasCover() ? 42 : 48)
        .fontColor([this.hasCover() ? ThemeConstants.TEXT_TERTIARY : ThemeConstants.TEXT_ON_BRAND])
      if (this.hasCover()) {
        CachedCoverImage({
          uri: this.manga.coverUrl ?? '',
          decodeMaxEdge: coverDecodeEdgeForDisplay(DETAIL_COVER_HEIGHT),
          objectFit: ImageFit.Cover,
          sourceRuntimeId: this.manga.sourceId ?? '',
          sourceImageId: this.manga.sourceImageId ?? this.manga.id,
          sourceKind: this.sourceKind,
          remoteServerId: this.remoteServerId,
          sourceMangaUrl: this.manga.url ?? '',
          onError: () => {
            this.failedCoverUrl = this.coverFailureKey()
          },
        })
      }
    }
    .id(this.transitionCoverId)
    .width(104)
    .height(DETAIL_COVER_HEIGHT)
    .backgroundColor(this.hasCover() ? ThemeConstants.COVER_PLACEHOLDER : ThemeConstants.BRAND_PRIMARY)
    .borderRadius(ThemeConstants.RADIUS_THUMB)
    .clip(true)
    .shadow({ radius: 10, color: ThemeConstants.SHADOW_CARD, offsetY: 4 })
    // CURRENT_STATUS #359: the flight owns the only visible cover. Keep this
    // node mounted for its landing geometry and cached image, but hide its
    // entire paint (including placeholder, fallback glyph and shadow) so the
    // detail background shows through until the flying cover lands.
    .opacity(this.transitionCoverId.length > 0 &&
      this.detailTransition.targetCoverComponentId === this.transitionCoverId && this.detailTransition.coverMaskVisible() ? 0 : 1)
  }

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      this.Cover()

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(this.displayTitle())
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .lineHeight(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(this.manga.title.length > 0 ? CopyOptions.LocalDevice : CopyOptions.None)
          .onClick(() => { this.onTitleClick?.() })

        Text(this.creatorText())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Flex({ wrap: FlexWrap.Wrap, space: {
          main: LengthMetrics.vp(ThemeConstants.SPACE_SM),
          cross: LengthMetrics.vp(ThemeConstants.SPACE_SM),
        } }) {
          MangaStatusBadge({ status: this.manga.status ?? 'unknown' })

          if (this.manga.sourceName !== undefined && this.manga.sourceName.length > 0) {
            Row({ space: ThemeConstants.SPACE_XS }) {
              Text(this.manga.sourceName)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.BRAND_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.sourceUnavailable) {
                SymbolGlyph($r('sys.symbol.exclamationmark_triangle_fill'))
                  .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                  .fontColor([ThemeConstants.DANGER])
              }
            }
              .constraintSize({ maxWidth: '100%' })
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor(ThemeConstants.SOFT_TINT)
              .onClick((): void => { if (this.manga.sourceId) this.onSourceClick() })
          }
        }
        .width('100%')

        if (this.showChapterCount) {
          Text(s('manga_detail_chapter_count').replace('%s', `${this.manga.chapterCount}`))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
