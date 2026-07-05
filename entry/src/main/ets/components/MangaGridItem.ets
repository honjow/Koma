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

  private titleInitial(): string {
    if (this.manga.title.length === 0) {
      return 'K'
    }
    return this.manga.title.substring(0, 1).toLocaleUpperCase()
  }

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== coverUrl
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.hasCover()) {
          Image(this.manga.coverUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .interpolation(ImageInterpolation.Medium)
            .onError(() => {
              this.failedCoverUrl = this.manga.coverUrl ?? ''
            })
        } else {
          Column({ space: ThemeConstants.SPACE_SM }) {
            Text(this.titleInitial())
              .fontSize(ThemeConstants.SPACE_XXL)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
            Text(this.manga.title)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('100%')
          .padding(ThemeConstants.SPACE_MD)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
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
