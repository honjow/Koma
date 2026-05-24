import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import {
  ContinueReadingCardViewModel,
  LibraryPresentationByComicId,
  LibraryViewModel,
  createLibraryViewModelFromComics,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import { Comic, ComicId } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { isRemovableLocalComic } from '../model/LibraryPersistence'
import { InMemoryReaderSessionStore, ReaderSessionStore } from '../model/ReaderSessionStore'

const TITLE_BAR_HEIGHT: number = 56
const FLOATING_TAB_BAR_PADDING: number = 96

@Component
struct ContinueReadingShelfCard {
  @Prop info: ContinueReadingCardViewModel = {
    title: '',
    detail: '',
    progress: 0,
    color: '#16745F',
    comicId: '',
  }
  @Prop revision: number = 0
  onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}

  build() {
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
      .backgroundColor(this.info.color)

      Column({ space: 8 }) {
        Text('继续阅读')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_accent'))
        Text(this.info.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.info.detail)
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: this.info.progress, total: 100, type: ProgressType.Linear })
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
      this.onOpenReader(this.info.comicId)
    })
  }
}

@Component
export struct LibraryPage {
  @StorageProp('topAvoidHeight') topAvoidHeight: number = 0
  @StorageProp('bottomAvoidHeight') bottomAvoidHeight: number = 0
  libraryStore: LibraryStore = createSeededLibraryStore()
  @Prop @Watch('syncDisplayedSnapshotFromProps') libraryComics: Comic[] = createSeededLibraryStore().listComics()
  @Prop @Watch('syncDisplayedSnapshotFromProps') libraryRevision: number = 0
  @State private displayedComics: Comic[] = createSeededLibraryStore().listComics()
  @State private displayedRevision: number = 0
  presentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
  sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  onImportRequested: () => void = () => {}
  onRemoveComicRequested: (comicId: ComicId) => boolean = (_comicId: ComicId) => false

  private syncDisplayedSnapshotFromProps(): void {
    this.displayedComics = this.libraryComics
    this.displayedRevision = this.libraryRevision
  }

  private refreshDisplayedSnapshotFromStore(): void {
    this.displayedComics = this.libraryStore.listComics()
    this.displayedRevision += 1
  }

  private viewModel(): LibraryViewModel {
    return createLibraryViewModelFromComics(this.displayedComics, this.sessionStore, this.presentationByComicId)
  }

  private gridComics(): ComicCoverInfo[] {
    return this.viewModel().comics.map((comic: ComicCoverInfo): ComicCoverInfo => {
      return {
        id: comic.id,
        title: comic.title,
        subtitle: comic.subtitle,
        progressText: comic.progressText,
        coverColor: comic.coverColor,
        accentColor: comic.accentColor,
        pageCount: comic.pageCount,
        coverUri: comic.coverUri,
      }
    })
  }

  private hasLibraryContent(): boolean {
    return this.displayedRevision >= 0 && this.displayedComics.length > 0
  }

  private canRemoveComic(comicId: ComicId): boolean {
    return this.displayedRevision >= 0 && isRemovableLocalComic(this.libraryStore.getComic(comicId))
  }

  private comicRenderKey(comic: ComicCoverInfo): string {
    return `${this.displayedRevision}:${comic.id}`
  }

  private isEvenDisplayedRevision(): boolean {
    return this.displayedRevision % 2 === 0
  }

  private showRemoveConfirmation(comic: ComicCoverInfo): void {
    if (!this.canRemoveComic(comic.id)) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '移出书架',
      message: `从书架中移出《${comic.title}》？`,
      autoCancel: true,
      primaryButton: {
        value: '移出',
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          if (this.onRemoveComicRequested(comic.id)) {
            this.refreshDisplayedSnapshotFromStore()
          }
        },
      },
      secondaryButton: {
        value: '取消',
        action: () => {},
      },
    })
  }

  @Builder
  private ComicActionMenu(comic: ComicCoverInfo) {
    Menu() {
      if (this.canRemoveComic(comic.id)) {
        MenuItem({ content: '移出书架' })
          .contentFontColor($r('app.color.koma_danger'))
          .onClick(() => {
            this.showRemoveConfirmation(comic)
          })
      }
    }
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
          Stack({ alignContent: Alignment.TopEnd }) {
            if (this.canRemoveComic(comic.id)) {
              ComicCoverCard({
                comic: comic,
                title: comic.title,
                subtitle: comic.subtitle,
                progressText: comic.progressText,
                coverColor: comic.coverColor,
                accentColor: comic.accentColor,
              })
                .onClick(() => {
                  this.onOpenReader(comic.id)
                })
                .bindContextMenu(this.ComicActionMenu(comic), ResponseType.LongPress)

              Button('…')
                .width(32)
                .height(32)
                .borderRadius(8)
                .fontSize(20)
                .fontColor($r('app.color.koma_text_primary'))
                .backgroundColor($r('app.color.koma_card'))
                .margin({ top: 8, right: 8 })
                .bindMenu(this.ComicActionMenu(comic))
            } else {
              ComicCoverCard({
                comic: comic,
                title: comic.title,
                subtitle: comic.subtitle,
                progressText: comic.progressText,
                coverColor: comic.coverColor,
                accentColor: comic.accentColor,
              })
                .onClick(() => {
                  this.onOpenReader(comic.id)
                })
            }
          }
          .width('100%')
        }
      }, (comic: ComicCoverInfo) => this.comicRenderKey(comic))
    }
    .width('100%')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(14)
    .rowsGap(22)
  }

  @Builder
  private LibraryGridEven(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
  }

  @Builder
  private LibraryGridOdd(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
  }

  aboutToAppear(): void {
    this.syncDisplayedSnapshotFromProps()
  }

  build() {
    List({ space: 20 }) {
      if (this.hasLibraryContent()) {
        ListItem() {
          ContinueReadingShelfCard({
            info: this.viewModel().continueReading,
            revision: this.displayedRevision,
            onOpenReader: (comicId: ComicId) => {
              this.onOpenReader(comicId)
            },
          })
        }

        ListItem() {
          Row() {
            Text('最近加入')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Blank()
            Text(`${this.viewModel().comics.length} 本`)
              .fontSize(13)
              .fontColor($r('app.color.koma_text_secondary'))
            Button('+')
              .width(36)
              .height(36)
              .borderRadius(8)
              .fontSize(22)
              .fontColor($r('app.color.koma_text_primary'))
              .backgroundColor($r('app.color.koma_card'))
              .margin({ left: 10 })
              .onClick(() => {
                this.onImportRequested()
              })
          }
          .width('100%')
        }

        ListItem() {
          if (this.isEvenDisplayedRevision()) {
            this.LibraryGridEven(this.gridComics())
          } else {
            this.LibraryGridOdd(this.gridComics())
          }
        }
      } else {
        ListItem() {
          this.EmptyLibrary()
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 20,
      right: 20,
      top: this.topAvoidHeight + TITLE_BAR_HEIGHT,
      bottom: this.bottomAvoidHeight + FLOATING_TAB_BAR_PADDING,
    })
    .scrollBar(BarState.Off)
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
