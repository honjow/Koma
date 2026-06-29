import { MangaDetail, MangaStatus } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct MangaDetailHeader {
  @Param manga: MangaDetail = {
    id: '',
    title: '',
    chapterCount: 0,
    isInLibrary: false,
  }

  private hasCover(): boolean {
    return this.manga.coverUrl !== undefined && this.manga.coverUrl.length > 0
  }

  private titleInitial(): string {
    return this.manga.title.length > 0 ? this.manga.title.substring(0, 1) : 'K'
  }

  private creatorText(): string {
    const author = this.manga.author === undefined ? '' : this.manga.author
    const artist = this.manga.artist === undefined ? '' : this.manga.artist
    if (author.length > 0 && artist.length > 0 && author !== artist) {
      return `${author} / ${artist}`
    }
    if (author.length > 0) {
      return author
    }
    if (artist.length > 0) {
      return artist
    }
    return '作者未知'
  }

  private statusLabel(): string {
    const status = this.manga.status === undefined ? MangaStatus.UNKNOWN : this.manga.status
    if (status === MangaStatus.ONGOING) {
      return '连载中'
    }
    if (status === MangaStatus.COMPLETED) {
      return '已完结'
    }
    if (status === MangaStatus.HIATUS) {
      return '暂停'
    }
    if (status === MangaStatus.CANCELLED) {
      return '已取消'
    }
    return '状态未知'
  }

  private statusBackgroundColor(): ResourceColor {
    const status = this.manga.status === undefined ? MangaStatus.UNKNOWN : this.manga.status
    if (status === MangaStatus.ONGOING) {
      return ThemeConstants.STATUS_SUCCESS
    }
    if (status === MangaStatus.COMPLETED) {
      return ThemeConstants.STATUS_INFO
    }
    if (status === MangaStatus.HIATUS) {
      return ThemeConstants.STATUS_MUTED
    }
    if (status === MangaStatus.CANCELLED) {
      return ThemeConstants.STATUS_DANGER
    }
    return ThemeConstants.TEXT_SECONDARY
  }

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasCover()) {
        Image(this.manga.coverUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          Blank()
          Text(this.titleInitial())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
      }
    }
    .width(120)
    .height(180)
    .borderRadius(ThemeConstants.RADIUS_THUMB)
    .clip(true)
    .shadow({ radius: 16, color: ThemeConstants.SHADOW_PROMINENT, offsetY: 8 })
  }

  build() {
    Row({ space: ThemeConstants.SPACE_LG }) {
      this.Cover()

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(this.manga.title)
          .fontSize(ThemeConstants.FONT_SIZE_H1)
          .lineHeight(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.creatorText())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.statusLabel())
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(this.statusBackgroundColor())

          if (this.manga.sourceName !== undefined && this.manga.sourceName.length > 0) {
            Text(this.manga.sourceName)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor(ThemeConstants.SOFT_TINT)
          }
        }
        .width('100%')

        Text(`${this.manga.chapterCount} 章`)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
