import { LibraryPage } from './LibraryPage'
import { ImportPage } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import {
  LibraryPresentationByComicId,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import { Comic, ComicId } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  InMemoryReaderSessionStore,
  ReaderSessionConfig,
  ReaderSessionStore,
  createReaderSessionConfigFromComic,
} from '../model/ReaderSessionStore'

const READER_ROUTE_NAME: string = 'ReaderPage'
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
  @State private libraryRevision: number = 0
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private readerPathStack: NavPathStack = new NavPathStack()

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
    if (!this.readerOpen) {
      this.readerPathStack.pushPath({ name: READER_ROUTE_NAME })
    }
    this.readerOpen = true
  }

  private closeReader(): void {
    if (!this.readerOpen) {
      return
    }
    this.readerOpen = false
    this.readerPathStack.pop(false)
  }

  private handleArchiveImportSucceeded(comic: Comic): void {
    this.libraryStore.upsertComic(comic)
    this.libraryRevision += 1
    this.selectedTab = 0
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

  @Builder
  private ReaderDestination(name: string, param: Object) {
    if (name === READER_ROUTE_NAME) {
      NavDestination() {
        ReaderPage({
          readerOpen: $readerOpen,
          pageIndex: $readerPageIndex,
          chromeVisible: $readerChromeVisible,
          webtoonMode: $readerWebtoonMode,
          sessionStore: this.readerSessionStore,
          sessionConfig: this.readerSessionConfig,
          onCloseReader: () => {
            this.closeReader()
          }
        })
      }
      .hideTitleBar(true)
      .onBackPressed(() => {
        this.closeReader()
        return true
      })
    }
  }

  onBackPress(): boolean {
    if (this.readerOpen) {
      this.closeReader()
      return true
    }
    return false
  }

  build() {
    Navigation(this.readerPathStack) {
      Column() {
        Stack() {
          if (this.selectedTab === 0) {
            LibraryPage({
              libraryStore: this.libraryStore,
              libraryRevision: this.libraryRevision,
              presentationByComicId: this.presentationByComicId,
              sessionStore: this.readerSessionStore,
              onOpenReader: (comicId: ComicId) => {
                this.openReader(comicId)
              }
            })
          } else if (this.selectedTab === 1) {
            ImportPage({
              onArchiveImportSucceeded: (comic: Comic) => {
                this.handleArchiveImportSucceeded(comic)
              }
            })
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0A09')
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.ReaderDestination)
  }
}
