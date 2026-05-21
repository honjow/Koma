export interface ComicCoverInfo {
  id: string
  title: string
  subtitle: string
  progressText: string
  coverColor: string
  accentColor: string
  pageCount?: number
  coverUri?: string
}

@Component
export struct ComicCoverCard {
  comic: ComicCoverInfo = {
    id: '',
    title: '',
    subtitle: '',
    progressText: '',
    coverColor: '#FFFFFF',
    accentColor: '#E66A3A'
  }

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Column() {
          Text(this.comic.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .lineHeight(22)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          Text('Koma')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#EAF8F1')
            .opacity(0.86)
        }
        .width('100%')
        .height('100%')
        .padding(14)
        .backgroundColor(this.comic.coverColor)

        Row() {
          Text(this.comic.progressText)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .height(26)
        .padding({ left: 10, right: 10 })
        .margin({ left: 10, bottom: 10 })
        .borderRadius(13)
        .backgroundColor(this.comic.accentColor)
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 14, color: '#1A000000', offsetY: 7 })

      Text(this.comic.title)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
        .maxLines(2)
        .lineHeight(18)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.comic.subtitle)
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.koma_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
