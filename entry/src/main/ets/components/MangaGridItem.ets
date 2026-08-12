import { CachedCoverImage, cachedCoverFailureKey } from './CachedCoverImage'
import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct MangaGridItem {
  @Param manga: SourceManga = {
    id: '',
    sourceId: '',
    title: '',
  }
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}
  @Local private failedCoverUrl: string = ''

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(this.manga.coverUrl, this.manga.sourceId, this.manga.id)
  }

  @Builder
  private CoverPlaceholder() {
    SymbolGlyph($r('sys.symbol.book'))
      .fontSize(34)
      .fontColor([ThemeConstants.TEXT_TERTIARY])
      .opacity(0.8)
      .width('100%')
      .height('100%')
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        this.CoverPlaceholder()

        if (this.hasCover()) {
          CachedCoverImage({
            uri: this.manga.coverUrl ?? '',
            objectFit: ImageFit.Cover,
            sourceRuntimeId: this.manga.sourceId,
            sourceImageId: this.manga.id,
            onError: () => {
              this.failedCoverUrl = this.coverFailureKey()
            },
          })
        }
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(ThemeConstants.RADIUS_THUMB)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)

      Text(this.manga.title)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(2)
        .lineHeight(18)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.onMangaTap(this.manga)
    })
  }
}
