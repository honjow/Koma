import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import {
  ContinueReadingCardViewModel,
  LibraryPresentationByComicId,
  LibraryViewModel,
  createLibraryViewModelFromStores,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import { ComicId } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { InMemoryReaderSessionStore, ReaderSessionStore } from '../model/ReaderSessionStore'

@Component
export struct LibraryPage {
  libraryStore: LibraryStore = createSeededLibraryStore()
  libraryRevision: number = 0
  presentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
  sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  onImportRequested: () => void = () => {}

  private viewModel(): LibraryViewModel {
    return createLibraryViewModelFromStores(this.libraryStore, this.sessionStore, this.presentationByComicId)
  }

  private hasLibraryContent(): boolean {
    return this.libraryRevision >= 0 && this.libraryStore.listComics().length > 0
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
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.onOpenReader(info.comicId)
    })
  }

  @Builder
  private EmptyLibrary() {
    Column({ space: 12 }) {
      Text('还没有漫画')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('导入本地 CBZ 或 ZIP 后会显示在书架中。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
      Button('导入')
        .height(40)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .fontSize(15)
        .backgroundColor($r('app.color.koma_accent'))
        .onClick(() => {
          this.onImportRequested()
        })
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private LibraryGrid(comics: ComicCoverInfo[]) {
    Grid() {
      ForEach(comics, (comic: ComicCoverInfo) => {
        GridItem() {
          ComicCoverCard({ comic: comic })
            .onClick(() => {
              this.onOpenReader(comic.id)
            })
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
      Column({ space: 20 }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text('书架')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Text(this.hasLibraryContent() ? `${this.viewModel().comics.length} 本漫画` : '本地漫画')
              .fontSize(14)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('+')
            .width(40)
            .height(40)
            .borderRadius(8)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.koma_accent'))
            .onClick(() => {
              this.onImportRequested()
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.hasLibraryContent()) {
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
