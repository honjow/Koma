import { MangaDetail, MangaStatus } from '../model/MangaDetailModels'

@Component
export struct MangaDetailHeader {
  @Prop manga: MangaDetail = {
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

  private statusBackgroundColor(): string {
    const status = this.manga.status === undefined ? MangaStatus.UNKNOWN : this.manga.status
    if (status === MangaStatus.ONGOING) {
      return '#1D7F5A'
    }
    if (status === MangaStatus.COMPLETED) {
      return '#3268B8'
    }
    if (status === MangaStatus.HIATUS) {
      return '#6C706C'
    }
    if (status === MangaStatus.CANCELLED) {
      return '#8B3A34'
    }
    return '#777D78'
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
            .fontColor(Color.White)
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#256E5D')
      }
    }
    .width(120)
    .height(180)
    .borderRadius(8)
    .clip(true)
    .shadow({ radius: 16, color: '#26000000', offsetY: 8 })
  }

  build() {
    Row({ space: 18 }) {
      this.Cover()

      Column({ space: 10 }) {
        Text(this.manga.title)
          .fontSize(24)
          .lineHeight(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.creatorText())
          .fontSize(14)
          .lineHeight(20)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          Text(this.statusLabel())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(13)
            .backgroundColor(this.statusBackgroundColor())

          if (this.manga.sourceName !== undefined && this.manga.sourceName.length > 0) {
            Text(this.manga.sourceName)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.koma_accent'))
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(13)
              .backgroundColor('#1A5CC8A8')
          }
        }
        .width('100%')

        Text(`${this.manga.chapterCount} 章`)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
