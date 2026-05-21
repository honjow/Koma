import { common } from '@kit.AbilityKit'
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
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
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
  private libraryPersistenceService?: LibraryStorePersistenceService
  private libraryPersistenceRestored: boolean = false

  private tabLabel(index: number): string {
    if (index === 0) { return '书架' }
    if (index === 1) { return '导入' }
    return ''
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
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      this.libraryStore.upsertComic(comic)
    } else {
      try {
        upsertComicAndPersistLibraryStore(this.libraryStore, persistenceService, comic)
      } catch (error) {
        const e = error as Error
        console.error('persist imported comic failed: ' + e.message)
        throw e
      }
    }
    this.libraryRevision += 1
    this.selectedTab = 0
  }

  private ensureLibraryPersistenceService(): LibraryStorePersistenceService | undefined {
    if (this.libraryPersistenceService !== undefined) {
      return this.libraryPersistenceService
    }
    const context = getContext(this) as common.UIAbilityContext
    if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
      return undefined
    }
    this.libraryPersistenceService = new LibraryStorePersistenceService(
      this.libraryStore,
      new AppFilesLibraryStorePersistenceAdapter(context.filesDir)
    )
    return this.libraryPersistenceService
  }

  aboutToAppear(): void {
    if (this.libraryPersistenceRestored) {
      return
    }
    this.libraryPersistenceRestored = true
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      return
    }
    try {
      persistenceService.restore()
      this.libraryRevision += 1
    } catch (error) {
      const e = error as Error
      console.error('restore library store failed: ' + e.message)
    }
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
              },
              onImportRequested: () => {
                this.selectedTab = 1
              }
            })
          } else if (this.selectedTab === 1) {
            ImportPage({
              onArchiveImportSucceeded: (comic: Comic) => {
                this.handleArchiveImportSucceeded(comic)
              }
            })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .alignContent(Alignment.TopStart)

        Tabs({ index: this.selectedTab }) {
          TabContent() { }.tabBar(this.TabItem(0))
          TabContent() { }.tabBar(this.TabItem(1))
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
