import { CachedCoverImage, cachedCoverFailureKey } from './CachedCoverImage'
import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'

const SOURCE_LIST_COVER_WIDTH = 56
const SOURCE_LIST_COVER_HEIGHT = 78

@ComponentV2
export struct MangaGridItem {
  @Param reserveTitleSpace: boolean = false
  @Param listLayout: boolean = false
  @Param deferOffscreenCover: boolean = false
  @Param manga: SourceManga = {
    id: '',
    sourceId: '',
    title: '',
  }
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}
  @Local private failedCoverUrl: string = ''
  @Local private coverWasVisible: boolean = false

  private coverVisibilityChanged(visible: boolean): void {
    if (this.deferOffscreenCover && visible && !this.coverWasVisible) this.coverWasVisible = true
  }

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(this.manga.coverUrl, this.manga.sourceId, this.manga.id, undefined, undefined,
      this.manga.url, this.manga.coverHeaders)
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
      CachedCoverImage({
        uri: this.manga.coverUrl ?? '',
        objectFit: ImageFit.Cover,
        sourceRuntimeId: this.manga.sourceId,
        sourceImageId: this.manga.id,
        sourceMangaUrl: this.manga.url ?? '',
        sourceCoverHeaders: this.manga.coverHeaders,
        onError: () => { this.failedCoverUrl = this.coverFailureKey() },
      })
    }
  }

  @Builder
  private ListCover() {
    Stack({ alignContent: Alignment.Center }) { this.CoverContent() }
    .width(SOURCE_LIST_COVER_WIDTH)
    .height(SOURCE_LIST_COVER_HEIGHT)
    .borderRadius(ThemeConstants.RADIUS_COVER)
    .clip(true)
    .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
    .onVisibleAreaChange([0.01], (visible: boolean) => { this.coverVisibilityChanged(visible) })
  }

  @Builder
  private GridCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) { this.CoverContent() }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(ThemeConstants.RADIUS_COVER)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
      .shadow({ radius: 14, color: ThemeConstants.SHADOW_CARD, offsetY: 7 })
      .onVisibleAreaChange([0.01], (visible: boolean) => { this.coverVisibilityChanged(visible) })

      Text(this.manga.title)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(2)
        .lineHeight(18)
        .constraintSize({ minHeight: this.reserveTitleSpace ? 36 : 0 })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
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
