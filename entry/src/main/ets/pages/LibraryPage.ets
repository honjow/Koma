import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { createLibraryViewModel, ContinueReadingCardViewModel, LibraryViewModel } from '../model/MockLibraryData'
import { InMemoryReaderSessionStore, ReaderSessionStore } from '../model/ReaderSessionStore'

@Component
export struct LibraryPage {
  private hasComics: boolean = true
  sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  onOpenReader: () => void = () => {}

  private viewModel(): LibraryViewModel {
    return createLibraryViewModel(this.sessionStore)
  }

  @Builder
  private ContinueReadingCard(info: ContinueReadingCardViewModel) {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(76)
      .height(102)
      .borderRadius(18)
      .backgroundColor(info.color)

      Column({ space: 8 }) {
        Text('继续阅读')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_accent'))
        Text(info.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(info.detail)
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: info.progress, total: 100, type: ProgressType.Linear })
          .height(4)
          .color($r('app.color.koma_accent'))
          .backgroundColor('#1FE66A3A')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(26)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.onOpenReader()
    })
  }

  @Builder
  private EmptyLibrary() {
    Column({ space: 14 }) {
      Text('Koma')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Text('还没有本地漫画')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('导入 CBZ/ZIP 或图片文件夹后，会在这里显示封面、进度和最近阅读。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
      Button('导入本地漫画')
        .height(46)
        .padding({ left: 24, right: 24 })
        .borderRadius(23)
        .fontSize(15)
        .backgroundColor($r('app.color.koma_accent'))
    }
    .width('100%')
    .padding(26)
    .borderRadius(28)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private LibraryGrid(comics: ComicCoverInfo[]) {
    Grid() {
      ForEach(comics, (comic: ComicCoverInfo) => {
        GridItem() {
          ComicCoverCard({ comic: comic })
        }
      }, (comic: ComicCoverInfo) => comic.id)
    }
    .width('100%')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(14)
    .rowsGap(22)
    .layoutWeight(1)
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 6 }) {
          Text('书架')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text('本地漫画和私有库内容会集中在这里')
            .fontSize(15)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.hasComics) {
          this.ContinueReadingCard(this.viewModel().continueReading)

          Row() {
            Text('最近加入')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Blank()
            Text(`${this.viewModel().comics.length} 本`)
              .fontSize(13)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .width('100%')

          this.LibraryGrid(this.viewModel().comics)
        } else {
          this.EmptyLibrary()
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
  }
}
