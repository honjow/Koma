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
import { LibraryUpdateResultPage } from './LibraryUpdateResultPage'
import { KomgaServerPage } from './KomgaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { DownloadsPage } from './DownloadsPage'
import { RouteName, TabIndex, TabLabel } from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
import { KomaTabIcon } from '../components/KomaTabIcon'
import {
  LibraryPresentationByComicId,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import { Comic, ComicId, withComicCategoryIds } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
  assignComicCategoriesAndPersistLibraryStore,
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
import { configureSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'

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

  private openSettingsSecondary(routeName: string): void {
    this.appPathStack.pushPath({ name: routeName })
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

  private handleAssignCategoriesRequested(comicIds: ComicId[], categoryIds?: string[]): boolean {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      comicIds.forEach((comicId: ComicId) => {
        const comic = this.libraryStore.getComic(comicId)
        if (comic !== undefined) {
          this.libraryStore.upsertComic(withComicCategoryIds(comic, categoryIds))
        }
      })
      this.refreshLibrarySnapshot()
      return comicIds.length > 0
    }
    try {
      const changedCount = assignComicCategoriesAndPersistLibraryStore(
        this.libraryStore,
        persistenceService,
        comicIds,
        categoryIds
      )
      if (changedCount > 0) {
        this.refreshLibrarySnapshot()
      }
      return changedCount > 0
    } catch (error) {
      const e = error as Error
      console.error('persist category assignment failed: ' + e.message)
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
    const context = getContext(this) as common.UIAbilityContext
    configureSourceSettingsStore(context)
    bootstrapSourceRuntimeAppRegistry(context)
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
          onOpenReader: (mangaId: string, chapterId?: string) => { void this.openReader(mangaId, chapterId) },
          onLibraryChanged: () => { this.refreshLibrarySnapshot() }
        })
      }
      .hideTitleBar(true)
    } else if (name === RouteName.KOMGA_SERVER) {
      HdsNavDestination() {
        KomgaServerPage()
      }
      .titleBar(this.navDestTitleBarOpts('Komga'))
    } else if (name === RouteName.OPDS_SERVER) {
      HdsNavDestination() {
        OpdsServerPage()
      }
      .titleBar(this.navDestTitleBarOpts('OPDS'))
    } else if (name === RouteName.WEBDAV_SERVER) {
      HdsNavDestination() {
        WebDavServerPage()
      }
      .titleBar(this.navDestTitleBarOpts('WebDAV'))
    } else if (name === RouteName.SOURCE_PACKAGE_MANAGER) {
      HdsNavDestination() {
        SourcePackageManagerPage()
      }
      .titleBar(this.navDestTitleBarOpts('源包管理'))
    } else if (name === RouteName.LIBRARY_UPDATE_RESULTS) {
      HdsNavDestination() {
        LibraryUpdateResultPage()
      }
      .titleBar(this.navDestTitleBarOpts('书架更新详情'))
    } else if (name === RouteName.DOWNLOADS) {
      HdsNavDestination() {
        DownloadsPage({
          libraryStore: this.libraryStore,
        })
      }
      .titleBar(this.navDestTitleBarOpts('下载管理'))
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
            },
            onAssignCategoriesRequested: (comicIds: ComicId[], categoryIds?: string[]) => {
              return this.handleAssignCategoriesRequested(comicIds, categoryIds)
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
          SettingsPage({
            libraryStore: this.libraryStore,
            libraryPersistenceService: this.ensureLibraryPersistenceService(),
            sourceRegistry: this.sourceRegistry,
            onOpenKomgaSettings: () => {
              this.openSettingsSecondary(RouteName.KOMGA_SERVER)
            },
            onOpenOpdsSettings: () => {
              this.openSettingsSecondary(RouteName.OPDS_SERVER)
            },
            onOpenWebDavSettings: () => {
              this.openSettingsSecondary(RouteName.WEBDAV_SERVER)
            },
            onOpenSourcePackageManager: () => {
              this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
            },
            onOpenLibraryUpdateResults: () => {
              this.openSettingsSecondary(RouteName.LIBRARY_UPDATE_RESULTS)
            },
            onOpenDownloads: () => {
              this.openSettingsSecondary(RouteName.DOWNLOADS)
            },
            onLibraryChanged: () => {
              this.refreshLibrarySnapshot()
            }
          })
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
