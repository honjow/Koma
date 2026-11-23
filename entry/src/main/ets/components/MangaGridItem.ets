import { CachedCoverImage, NativeCoverImage, cachedCoverFailureKey, coverDecodeEdgeForDisplay } from './CachedCoverImage'
import { ComicSourceKind } from '../model/ComicModels'
import { SourceManga, sourceMangaListInfo } from '../model/SourceModels'
import { SourceMangaListInfo, sourceMangaListInfoText } from '../model/SourceMangaListInfo'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'
import { AppStrings } from '../i18n/AppStrings'

const SOURCE_LIST_COVER_WIDTH = 56
const SOURCE_LIST_COVER_HEIGHT = 78

export interface MangaGridCoverOptions {
  nativeImage: boolean
  imageId: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
}

@ComponentV2
export struct MangaGridItem {
  @Param inLibrary: boolean = false
  @Param reserveTitleSpace: boolean = false
  @Param listLayout: boolean = false
  @Param deferOffscreenCover: boolean = false
  @Param subtitle: string | undefined = undefined
  @Param coverOptions: MangaGridCoverOptions | undefined = undefined
  @Param manga: SourceManga = {
    id: '',
    sourceId: '',
    title: '',
  }
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}
  @Local private failedCoverUrl: string = ''
  @Local private coverWasVisible: boolean = false
  @Local private gridCoverDecodeEdge: number = 0
  @Local private retryWhenVisibleAgain: boolean = false

  private coverVisibilityChanged(visible: boolean): void {
    if (this.deferOffscreenCover && visible && !this.coverWasVisible) this.coverWasVisible = true
    if (!visible && this.failedCoverUrl === this.coverFailureKey()) {
      this.retryWhenVisibleAgain = true
    } else if (visible && this.retryWhenVisibleAgain) {
      // The automatic retry inside CachedCoverImage has already run. Re-enter
      // the viewport is a new user-visible opportunity, not a background poll.
      this.retryWhenVisibleAgain = false
      this.failedCoverUrl = ''
    }
  }

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(this.manga.coverUrl, this.manga.sourceId, this.coverOptions?.imageId ?? this.manga.id,
      this.coverOptions?.sourceKind, this.coverOptions?.remoteServerId, this.manga.url, this.manga.coverHeaders)
  }

  @Builder
  private CoverPlaceholder() {
    Column() {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(this.listLayout ? ThemeConstants.FONT_SIZE_H2 : 42)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
    }
      .width('100%')
      .height('100%')
      .padding(ThemeConstants.SPACE_MD)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
  }

  @Builder
  private CoverContent() {
    this.CoverPlaceholder()
    // ArkUI can pre-layout several screenfuls. A card can keep its measured
    // size without admitting a network request before it enters the viewport.
    if ((!this.deferOffscreenCover || this.coverWasVisible) && this.hasCover()) {
      if (this.coverOptions?.nativeImage === true) {
        NativeCoverImage({
          uri: this.manga.coverUrl ?? '',
          onError: () => { this.failedCoverUrl = this.coverFailureKey() },
        })
      } else if (this.listLayout || this.gridCoverDecodeEdge > 0) {
        CachedCoverImage({
          uri: this.manga.coverUrl ?? '',
          // Both layouts reuse cards. Keep the old cover only while the same work reloads.
          coverOwnerId: JSON.stringify([this.manga.sourceId, this.manga.id]),
          objectFit: ImageFit.Cover,
          decodeMaxEdge: this.listLayout ? coverDecodeEdgeForDisplay(SOURCE_LIST_COVER_HEIGHT) : this.gridCoverDecodeEdge,
          sourceRuntimeId: this.manga.sourceId,
          sourceImageId: this.coverOptions?.imageId ?? this.manga.id,
          sourceMangaUrl: this.manga.url ?? '',
          sourceCoverHeaders: this.manga.coverHeaders,
          sourceKind: this.coverOptions?.sourceKind,
          remoteServerId: this.coverOptions?.remoteServerId ?? '',
          onError: () => { this.failedCoverUrl = this.coverFailureKey() },
        })
      }
    }
  }

  @Builder
  private InLibraryBadge() {
    if (this.inLibrary) {
      SymbolGlyph($r('sys.symbol.bookmark_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor([Color.White])
        .padding(ThemeConstants.SPACE_XS)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(ThemeConstants.RADIUS_COVER)
        .margin(ThemeConstants.SPACE_XS)
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(AppStrings.get('source_in_library'))
        .id('source-in-library-' + this.manga.sourceId + ':' + this.manga.id)
    }
  }

  @Builder
  private ListCover() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.CoverContent()
      this.InLibraryBadge()
    }
    .width(SOURCE_LIST_COVER_WIDTH)
    .height(SOURCE_LIST_COVER_HEIGHT)
    .borderRadius(ThemeConstants.RADIUS_COVER)
    .clip(true)
    .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
    .onVisibleAreaChange([0.01], (visible: boolean) => { this.coverVisibilityChanged(visible) })
  }

  @Builder
  private ListText() {
    Column({ space: 2 }) {
      Text(this.manga.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(2)
        .wordBreak(WordBreak.BREAK_WORD)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      ForEach(sourceMangaListInfo(this.manga), (info: SourceMangaListInfo) => {
        Text(sourceMangaListInfoText(info))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private GridCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.TopStart }) {
        this.CoverContent()
        this.InLibraryBadge()
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(ThemeConstants.RADIUS_COVER)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
      .shadow({ radius: 14, color: ThemeConstants.SHADOW_CARD, offsetY: 7 })
      .onSizeChange((_old: SizeOptions, size: SizeOptions): void => {
        // Search carousels and source grids can have different lane widths.
        // Resolve the actual cover box before requesting its first still image.
        const height = Number(size.height)
        if (height <= 0 || this.coverOptions?.nativeImage === true) return
        const edge = coverDecodeEdgeForDisplay(height)
        if (edge !== this.gridCoverDecodeEdge) this.gridCoverDecodeEdge = edge
      })
      .onVisibleAreaChange([0.01], (visible: boolean) => { this.coverVisibilityChanged(visible) })

      Text(this.manga.title)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(2)
        .lineHeight(18)
        .constraintSize({ minHeight: this.reserveTitleSpace ? 36 : 0 })
        .align(this.subtitle !== undefined ? Alignment.TopStart : Alignment.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.subtitle !== undefined) {
        Text(this.subtitle)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .constraintSize({ minHeight: ThemeConstants.LINE_HEIGHT_BODY })
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onMangaTap(this.manga)
    })
  }

  build() {
    if (this.listLayout) {
      Row() {
        ConciseListRow({ title: this.manga.title, wrapTitle: true, wrapTitleByWord: true,
          showChevron: false, prefixActsAsLeading: true,
          textBuilderParam: () => { this.ListText() },
          prefixBuilderParam: () => { this.ListCover() }, action: () => { this.onMangaTap(this.manga) } })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
      .backgroundColor(ThemeConstants.CARD)
    } else {
      this.GridCard()
    }
  }
}
