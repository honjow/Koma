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
  @Prop comic: ComicCoverInfo = {
    id: '',
    title: '',
    subtitle: '',
    progressText: '',
    coverColor: '#FFFFFF',
    accentColor: '#E66A3A'
  }
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop progressText: string = ''
  @Prop coverColor: string = ''
  @Prop accentColor: string = ''
  @Prop selected: boolean = false

  private displayTitle(): string {
    return this.title.length > 0 ? this.title : this.comic.title
  }

  private displaySubtitle(): string {
    return this.subtitle.length > 0 ? this.subtitle : this.comic.subtitle
  }

  private displayProgressText(): string {
    return this.progressText.length > 0 ? this.progressText : this.comic.progressText
  }

  private displayCoverColor(): string {
    return this.coverColor.length > 0 ? this.coverColor : this.comic.coverColor
  }

  private displayAccentColor(): string {
    return this.accentColor.length > 0 ? this.accentColor : this.comic.accentColor
  }

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Column() {
          Text(this.displayTitle())
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
        .backgroundColor(this.displayCoverColor())

        Row() {
          Text(this.displayProgressText())
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .height(26)
        .padding({ left: 10, right: 10 })
        .margin({ left: 10, bottom: 10 })
        .borderRadius(13)
        .backgroundColor(this.displayAccentColor())

        if (this.selected) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')

          Stack({ alignContent: Alignment.Center }) {
            Text('✓')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(34)
          .height(34)
          .margin({ top: 10, right: 10 })
          .borderRadius(17)
          .backgroundColor($r('app.color.koma_accent'))
          .border({ width: 2, color: Color.White })
          .align(Alignment.TopEnd)
        }
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 14, color: '#1A000000', offsetY: 7 })

      Text(this.displayTitle())
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
        .maxLines(2)
        .lineHeight(18)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.displaySubtitle())
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
