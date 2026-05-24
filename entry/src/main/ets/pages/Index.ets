import { common } from '@kit.AbilityKit'
import { LibraryPage } from './LibraryPage'
import { BrowsePage } from './BrowsePage'
import { HistoryPage } from './HistoryPage'
import { SearchPage } from './SearchPage'
import { SettingsPage } from './SettingsPage'
import { ImportPage } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage, MANGA_DETAIL_ROUTE_NAME } from './MangaDetailPage'
import { RouteName, TabIndex, TabLabel } from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
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
  isRemovableLocalComic,
  removeComicAndPersistLibraryStore,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
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
  @State selectedTab: number = TabIndex.LIBRARY
  @State private readerOpen: boolean = false
  @State private readerPageIndex: number = 0
  @State private readerChromeVisible: boolean = true
  @State private readerWebtoonMode: boolean = false
  @State private readerSessionConfig: ReaderSessionConfig = MOCK_LIBRARY_READER_SESSION
  @State private libraryRevision: number = 0
  @State private libraryComics: Comic[] = seededLibraryStore.listComics()
  private tabController: TabsController = new TabsController()
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private appPathStack: NavPathStack = new NavPathStack()
  private libraryPersistenceService?: LibraryStorePersistenceService
  private libraryPersistenceRestored: boolean = false

  private refreshLibrarySnapshot(): void {
    this.libraryComics = this.libraryStore.listComics()
    this.libraryRevision += 1
  }

  private openReader(comicId: ComicId) {
    const comic = this.libraryStore.getComic(comicId)
    this.readerSessionConfig = comic === undefined ? MOCK_LIBRARY_READER_SESSION : createReaderSessionConfigFromComic(comic)
    this.readerPageIndex = this.readerSessionStore.restorePageIndex(this.readerSessionConfig)
    this.readerChromeVisible = true
    if (!this.readerOpen) {
      this.appPathStack.pushPath({ name: RouteName.READER })
    }
    this.readerOpen = true
  }

  private closeReader(): void {
    if (!this.readerOpen) {
      return
    }
    this.readerOpen = false
    this.appPathStack.pop(false)
  }

  private openImport(): void {
    this.appPathStack.pushPath({ name: RouteName.IMPORT })
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
    this.refreshLibrarySnapshot()
    this.selectedTab = 0
  }

  private handleRemoveComicRequested(comicId: ComicId): boolean {
    const requestedComic = this.libraryStore.getComic(comicId)
    const removable = isRemovableLocalComic(requestedComic)
    console.info(
      `[library-remove] requested found=${requestedComic !== undefined} removable=${removable}`
    )
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      if (!removable) {
        console.info('[library-remove] result removed=false persistence=unavailable')
        return false
      }
      this.libraryStore.removeComic(comicId)
      this.refreshLibrarySnapshot()
      console.info('[library-remove] result removed=true persistence=unavailable')
      return true
    }
    try {
      if (removeComicAndPersistLibraryStore(this.libraryStore, persistenceService, comicId)) {
        this.refreshLibrarySnapshot()
        console.info('[library-remove] result removed=true persistence=available')
        return true
      } else {
        console.info('[library-remove] result removed=false persistence=available')
        return false
      }
    } catch (error) {
      const e = error as Error
      console.error('persist removed comic failed: ' + e.message)
      throw e
    }
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
    RouterHelper.setAppPathStack(this.appPathStack)
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
      this.refreshLibrarySnapshot()
    } catch (error) {
      const e = error as Error
      console.error('restore library store failed: ' + e.message)
    }
  }

  @Builder
  private TabBarItem(index: number, label: string, icon: Resource) {
    Column({ space: 4 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor(this.selectedTab === index ? [$r('app.color.koma_accent')] : [$r('app.color.koma_text_secondary')])

      Text(label)
        .fontSize(12)
        .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedTab === index ? $r('app.color.koma_accent') : $r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private AppDestination(name: string, param: Object) {
    if (name === RouteName.READER) {
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
    } else if (name === RouteName.IMPORT) {
      NavDestination() {
        ImportPage({
          onArchiveImportSucceeded: (comic: Comic) => {
            this.handleArchiveImportSucceeded(comic)
            this.appPathStack.pop(false)
          },
          onLocalImageImportSucceeded: (comic: Comic) => {
            this.handleArchiveImportSucceeded(comic)
            this.appPathStack.pop(false)
          }
        })
      }
      .hideTitleBar(true)
    } else if (name === RouteName.MANGA_DETAIL) {
      NavDestination() {
        MangaDetailPage({
          params: { mangaId: (param as Record<string, string>)?.mangaId, sourceId: (param as Record<string, string>)?.sourceId },
          onBack: () => { this.appPathStack.pop(false) },
          onOpenReader: (mangaId: string, _chapterId?: string) => { this.openReader(mangaId) }
        })
      }
      .hideTitleBar(true)
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
    Navigation(this.appPathStack) {
      Tabs({ barPosition: BarPosition.End, controller: this.tabController, index: $$this.selectedTab }) {
        TabContent() {
          LibraryPage({
            libraryStore: this.libraryStore,
            libraryComics: this.libraryComics,
            libraryRevision: this.libraryRevision,
            presentationByComicId: this.presentationByComicId,
            sessionStore: this.readerSessionStore,
            onOpenReader: (comicId: ComicId) => {
              this.openReader(comicId)
            },
            onImportRequested: () => {
              this.openImport()
            },
            onRemoveComicRequested: (comicId: ComicId) => {
              return this.handleRemoveComicRequested(comicId)
            }
          })
        }
        .tabBar(this.TabBarItem(TabIndex.LIBRARY, TabLabel.LIBRARY, $r('sys.symbol.rectangle_on_rectangle_fill')))

        TabContent() {
          BrowsePage()
        }
        .tabBar(this.TabBarItem(TabIndex.BROWSE, TabLabel.BROWSE, $r('sys.symbol.dot_grid_2x2')))

        TabContent() {
          HistoryPage()
        }
        .tabBar(this.TabBarItem(TabIndex.HISTORY, TabLabel.HISTORY, $r('sys.symbol.stopwatch_fill')))

        TabContent() {
          SearchPage()
        }
        .tabBar(this.TabBarItem(TabIndex.SEARCH, TabLabel.SEARCH, $r('sys.symbol.magnifyingglass')))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.TabBarItem(TabIndex.SETTINGS, TabLabel.SETTINGS, $r('sys.symbol.more')))
      }
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barHeight(72)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.koma_background'))
      .onChange((index: number) => {
        this.selectedTab = index
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.koma_background'))
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.AppDestination)
  }
}
