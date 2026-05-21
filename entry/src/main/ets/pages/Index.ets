import { LibraryPage } from './LibraryPage'
import { ImportPage } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import {
  LibraryPresentationByComicId,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import { ComicId } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  InMemoryReaderSessionStore,
  ReaderSessionConfig,
  ReaderSessionStore,
  createReaderSessionConfigFromComic,
} from '../model/ReaderSessionStore'

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()

@Entry
@Component
struct Index {
  @State selectedTab: number = 0
  @State private readerOpen: boolean = false
  @State private readerPageIndex: number = 0
  @State private readerChromeVisible: boolean = true
  @State private readerWebtoonMode: boolean = false
  @State private readerSessionConfig: ReaderSessionConfig = MOCK_LIBRARY_READER_SESSION
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId

  private tabLabel(index: number): string {
    if (index === 0) { return '书架' }
    if (index === 1) { return '导入' }
    if (index === 2) { return '历史' }
    return '设置'
  }

  private openReader(comicId: ComicId) {
    const comic = this.libraryStore.getComic(comicId)
    this.readerSessionConfig = comic === undefined ? MOCK_LIBRARY_READER_SESSION : createReaderSessionConfigFromComic(comic)
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(this.readerSessionConfig)
    this.readerChromeVisible = true
    this.readerOpen = true
  }

  @Builder
  private TabItem(index: number) {
    Column() {
      Text(this.tabLabel(index))
        .fontSize(12)
        .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedTab === index ? $r('app.color.koma_accent') : $r('app.color.koma_text_secondary'))
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        Stack() {
          if (this.selectedTab === 0) {
            LibraryPage({
              libraryStore: this.libraryStore,
              presentationByComicId: this.presentationByComicId,
              sessionStore: this.readerSessionStore,
              onOpenReader: (comicId: ComicId) => {
                this.openReader(comicId)
              }
            })
          } else if (this.selectedTab === 1) {
            ImportPage()
          } else {
            Column({ space: 12 }) {
              Text(this.tabLabel(this.selectedTab))
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.koma_text_primary'))
              Text(this.selectedTab === 2 ? '阅读历史会显示最近打开的本地漫画。' : '框架占位页，后续按漫画阅读器路线补齐。')
                .fontSize(15)
                .fontColor($r('app.color.koma_text_secondary'))
              if (this.selectedTab === 2) {
                Button('打开阅读器原型')
                  .height(46)
                  .padding({ left: 22, right: 22 })
                  .borderRadius(23)
                  .fontSize(15)
                  .backgroundColor($r('app.color.koma_accent'))
                  .onClick(() => {
                    this.openReader(MOCK_LIBRARY_READER_SESSION.comicId)
                  })
              }
            }
            .width('100%')
            .padding(24)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignContent(Alignment.TopStart)

        Tabs({ index: this.selectedTab }) {
          TabContent() { }.tabBar(this.TabItem(0))
          TabContent() { }.tabBar(this.TabItem(1))
          TabContent() { }.tabBar(this.TabItem(2))
          TabContent() { }.tabBar(this.TabItem(3))
        }
        .height(72)
        .barPosition(BarPosition.End)
        .onChange((index: number) => { this.selectedTab = index })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.koma_background'))
      .padding({ top: 72 })
      .hitTestBehavior(this.readerOpen ? HitTestMode.None : HitTestMode.Default)

      if (this.readerOpen) {
        ReaderPage({
          readerOpen: $readerOpen,
          pageIndex: $readerPageIndex,
          chromeVisible: $readerChromeVisible,
          webtoonMode: $readerWebtoonMode,
          sessionStore: this.readerSessionStore,
          sessionConfig: this.readerSessionConfig
        })
          .zIndex(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0A09')
  }
}
