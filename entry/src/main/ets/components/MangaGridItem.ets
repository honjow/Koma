import { SourceManga } from '../model/SourceModels'

@Component
export struct MangaGridItem {
  @Prop manga: SourceManga = {
    id: '',
    sourceId: '',
    title: '',
  }
  onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private titleInitial(): string {
    if (this.manga.title.length === 0) {
      return 'K'
    }
    return this.manga.title.substring(0, 1).toLocaleUpperCase()
  }

  private hasCover(): boolean {
    return this.manga.coverUrl !== undefined && this.manga.coverUrl.length > 0
  }

  build() {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.hasCover()) {
          Image(this.manga.coverUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Column({ space: 8 }) {
            Text(this.titleInitial())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_secondary'))
            Text(this.manga.title)
              .fontSize(12)
              .fontColor($r('app.color.koma_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('100%')
          .padding(12)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#FFE6E8E6')
        }
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(8)
      .clip(true)
      .backgroundColor('#FFE6E8E6')

      Text(this.manga.title)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
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
