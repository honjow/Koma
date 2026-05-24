import { common } from '@kit.AbilityKit'
import {
  BlurStrategy,
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HideMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { LibraryPage } from './LibraryPage'
import { BrowsePage } from './BrowsePage'
import { HistoryPage } from './HistoryPage'
import { SearchPage } from './SearchPage'
import { SettingsPage } from './SettingsPage'
import { ImportPage } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage } from './MangaDetailPage'
import { RouteName, TabIndex, TabLabel } from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
import { KomaTabIcon } from '../components/KomaTabIcon'
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
import { installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import {
  appSourceRuntimeRegistry,
  bootstrapSourceRuntimeAppRegistry,
} from '../sourceRuntime/SourceRuntimeAppRegistry'

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
const sourceRuntimeRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry

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
  private tabController: HdsTabsController = new HdsTabsController()
  private tabTitles: string[] = [TabLabel.LIBRARY, TabLabel.BROWSE, TabLabel.HISTORY, TabLabel.SEARCH, TabLabel.SETTINGS]
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private sourceRegistry: SourceRuntimeRegistry = sourceRuntimeRegistry
  private appPathStack: NavPathStack = new NavPathStack()
  private libraryPersistenceService?: LibraryStorePersistenceService
  private libraryPersistenceRestored: boolean = false

  private refreshLibrarySnapshot(): void {
    this.libraryComics = this.libraryStore.listComics()
    this.libraryRevision += 1
  }

  private async openReader(comicId: ComicId, chapterId?: string): Promise<void> {
    const comic = this.libraryStore.getComic(comicId)
    if (comic !== undefined) {
      try {
        await installReaderRemoteHeadersForComic(getContext(this) as common.UIAbilityContext, comic)
      } catch (error) {
        const e = error as Error
        console.error('[Favorite] step=open_remote_reader_headers_failed message=' + e.message)
      }
    }
    this.readerSessionConfig = comic === undefined ? MOCK_LIBRARY_READER_SESSION : createReaderSessionConfigFromComic(comic, chapterId)
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
    bootstrapSourceRuntimeAppRegistry(getContext(this) as common.UIAbilityContext)
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
  TabIcon(title: string, idx: number) {
    KomaTabIcon({
      title: title,
      idx: idx,
      currentIndex: this.selectedTab,
    })
  }

  @Builder
  private AppDestination(name: string, param: Object) {
    if (name === RouteName.READER) {
      HdsNavDestination() {
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
      HdsNavDestination() {
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
      .titleBar(this.navDestTitleBarOpts('导入'))
    } else if (name === RouteName.MANGA_DETAIL) {
      HdsNavDestination() {
        MangaDetailPage({
          params: { mangaId: (param as Record<string, string>)?.mangaId, sourceId: (param as Record<string, string>)?.sourceId },
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          sourceRegistry: this.sourceRegistry,
          onBack: () => { this.appPathStack.pop(false) },
          onOpenReader: (mangaId: string, _chapterId?: string) => { void this.openReader(mangaId) },
          onLibraryChanged: () => { this.refreshLibrarySnapshot() }
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
    HdsNavigation(this.appPathStack) {
      HdsTabs({ controller: this.tabController, index: this.selectedTab }) {
        TabContent() {
          LibraryPage({
            libraryStore: this.libraryStore,
            libraryComics: this.libraryComics,
            libraryRevision: this.libraryRevision,
            presentationByComicId: this.presentationByComicId,
            sessionStore: this.readerSessionStore,
            onOpenReader: (comicId: ComicId) => {
              void this.openReader(comicId)
            },
            onImportRequested: () => {
              this.openImport()
            },
            onRemoveComicRequested: (comicId: ComicId) => {
              return this.handleRemoveComicRequested(comicId)
            }
          })
        }.tabBar(this.TabIcon(TabLabel.LIBRARY, TabIndex.LIBRARY))

        TabContent() {
          BrowsePage({
            sourceRegistry: this.sourceRegistry,
            libraryStore: this.libraryStore,
            libraryPersistenceService: this.ensureLibraryPersistenceService(),
            onLibraryChanged: () => {
              this.refreshLibrarySnapshot()
              this.selectedTab = TabIndex.LIBRARY
            }
          })
        }.tabBar(this.TabIcon(TabLabel.BROWSE, TabIndex.BROWSE))

        TabContent() {
          HistoryPage({
            libraryStore: this.libraryStore,
            active: this.selectedTab === TabIndex.HISTORY,
            onOpenReader: (comicId: ComicId, chapterId?: string) => {
              void this.openReader(comicId, chapterId)
            }
          })
        }.tabBar(this.TabIcon(TabLabel.HISTORY, TabIndex.HISTORY))

        TabContent() {
          SearchPage({
            libraryStore: this.libraryStore,
            libraryPersistenceService: this.ensureLibraryPersistenceService(),
            onLibraryChanged: () => {
              this.refreshLibrarySnapshot()
              this.selectedTab = TabIndex.LIBRARY
            }
          })
        }.tabBar(this.TabIcon(TabLabel.SEARCH, TabIndex.SEARCH))

        TabContent() {
          SettingsPage()
        }.tabBar(this.TabIcon(TabLabel.SETTINGS, TabIndex.SETTINGS))
      }
      .barOverlap(true)
      .barPosition(BarPosition.End)
      .barMode(BarMode.Fixed)
      .scrollable(false)
      .animationDuration(0)
      .barFloatingStyle({
        barBottomMargin: 16,
        adaptToHandedness: true,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      } as HdsTabsFloatingStyle)
      .onChange((index: number) => {
        this.selectedTab = index
      })
    }
    .titleBar(this.titleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: false,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
    })
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM],
    )
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .navDestination(this.AppDestination)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': this.tabTitles[this.selectedTab] }
    let content: Record<string, Object> = { 'title': titleInfo }
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

  private navDestTitleBarOpts(title?: string): Record<string, Object> {
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    let content: Record<string, Object> = {}
    if (title) {
      content['title'] = { 'mainTitle': title } as Record<string, Object>
    }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }

}
