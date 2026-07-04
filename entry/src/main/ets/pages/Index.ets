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
import { SettingsPage, SettingsPaneKey, settingsPaneTitle } from './SettingsPage'
import { ImportPage, LocalFolderImportPersistResult } from './ImportPage'
import { ReaderPage } from './ReaderPage'
import { MangaDetailPage } from './MangaDetailPage'
import { LibraryUpdateResultPage } from './LibraryUpdateResultPage'
import { LibraryCategoryManagementPage } from './LibraryCategoryManagementPage'
import { KomgaServerPage } from './KomgaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { DownloadsPage } from './DownloadsPage'
import { BackupManagementPage } from './BackupManagementPage'
import { TrackerSettingsPage } from './TrackerSettingsPage'
import { RouteName, TabIndex, tabLabel } from '../common/Constants'
import { RouterHelper } from '../common/RouterHelper'
import { KomaTabIcon } from '../components/KomaTabIcon'
import {
  LibraryPresentationByComicId,
  MOCK_LIBRARY_READER_SESSION,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import {
  Comic,
  ComicId,
  withComicAddedCategoryId,
  withComicCategoryIds,
  withComicRemovedCategoryId,
} from '../model/ComicModels'
import {
  LocalLibraryFolderScanResult,
  buildKnownLocalLibraryFolderSeriesFromComics,
  buildComicsFromLocalLibraryFolderScan,
} from '../model/LocalLibraryFolderContract'
import { LibraryStore } from '../model/LibraryStore'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
  assignComicCategoriesAndPersistLibraryStore,
  isRemovableLocalComic,
  removeComicAndPersistLibraryStore,
  updateComicCategoryMembershipAndPersistLibraryStore,
  upsertComicAndPersistLibraryStore,
  upsertLocalLibraryFolderScanAndPersistLibraryStore,
  upsertLocalLibraryFolderRescanAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
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
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { BackupService, BackupAutomaticRunResult } from '../model/BackupService'
import { TrackerPendingProgressDrainSummary, TrackerProgressSyncService } from '../model/TrackerProgressSyncService'

const readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
const seededLibraryStore: LibraryStore = createSeededLibraryStore()
const libraryPresentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
const sourceRuntimeRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry

interface SettingsPaneRouteParam {
  pane: string
}

@Entry
@ComponentV2
struct Index {
  @Local selectedTab: number = TabIndex.LIBRARY
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private readerOpen: boolean = false
  @Local private readerPageIndex: number = 0
  @Local private readerChromeVisible: boolean = true
  @Local private readerWebtoonMode: boolean = false
  @Local private readerSessionConfig: ReaderSessionConfig = MOCK_LIBRARY_READER_SESSION
  @Local private libraryRevision: number = 0
  @Local private libraryComics: Comic[] = seededLibraryStore.listComics()
  private tabController: HdsTabsController = new HdsTabsController()
  private readerSessionStore: ReaderSessionStore = readerSessionStore
  private libraryStore: LibraryStore = seededLibraryStore
  private presentationByComicId: LibraryPresentationByComicId = libraryPresentationByComicId
  private sourceRegistry: SourceRuntimeRegistry = sourceRuntimeRegistry
  private appPathStack: NavPathStack = new NavPathStack()
  private libraryPersistenceService?: LibraryStorePersistenceService
  private libraryPersistenceRestored: boolean = false
  private automaticBackupChecked: boolean = false
  private pendingTrackerProgressChecked: boolean = false

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

  private openSettingsPane(pane: SettingsPaneKey): void {
    const routeParam: SettingsPaneRouteParam = { pane: pane }
    this.appPathStack.pushPath({ name: RouteName.SETTINGS_PANE, param: routeParam })
  }

  private settingsPaneFromParam(param: Object): SettingsPaneKey {
    const pane = (param as Record<string, string>)?.pane
    if (pane === 'appearance' ||
      pane === 'library' ||
      pane === 'reader' ||
      pane === 'services' ||
      pane === 'downloads' ||
      pane === 'tracking' ||
      pane === 'backup' ||
      pane === 'storage' ||
      pane === 'about') {
      return pane
    }
    return 'root'
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

  private handleLocalFolderImportSucceeded(scanResult: LocalLibraryFolderScanResult, rootUri: string): LocalFolderImportPersistResult {
    const persistenceService = this.ensureLibraryPersistenceService()
    let importedCount = 0
    let checkedCount = scanResult.series.length
    let missingCount = 0
    if (persistenceService === undefined) {
      const comics = buildComicsFromLocalLibraryFolderScan(scanResult, rootUri)
      comics.forEach((comic: Comic) => {
        this.libraryStore.upsertComic(comic)
      })
      importedCount = comics.length
    } else {
      try {
        const previousKnownSeries = buildKnownLocalLibraryFolderSeriesFromComics(this.libraryStore.listComics())
        if (previousKnownSeries.length === 0) {
          importedCount = upsertLocalLibraryFolderScanAndPersistLibraryStore(
            this.libraryStore,
            persistenceService,
            scanResult,
            rootUri
          )
        } else {
          const result = upsertLocalLibraryFolderRescanAndPersistLibraryStore(
            this.libraryStore,
            persistenceService,
            previousKnownSeries,
            scanResult,
            rootUri
          )
          importedCount = result.upsertedCount
          checkedCount = result.summary.previousSeriesCount
          missingCount = result.summary.missingCount
          console.info('[Import] step=folder_rescan_persisted added=' + result.summary.addedCount +
            ' changed=' + result.summary.changedCount +
            ' missing=' + result.summary.missingCount +
            ' upserted=' + result.upsertedCount)
        }
      } catch (error) {
        const e = error as Error
        console.error('persist imported folder failed: ' + e.message)
        throw e
      }
    }
    if (importedCount > 0) {
      this.refreshLibrarySnapshot()
      this.selectedTab = 0
    }
    return {
      importedCount,
      checkedCount,
      missingCount,
    }
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
      this.cleanupRemovedComicDownloads(comicId)
      console.info('[library-remove] result removed=true persistence=unavailable')
      return true
    }
    try {
      if (removeComicAndPersistLibraryStore(this.libraryStore, persistenceService, comicId)) {
        this.refreshLibrarySnapshot()
        this.cleanupRemovedComicDownloads(comicId)
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

  private cleanupRemovedComicDownloads(comicId: ComicId): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      void new OfflineDownloadQueueStore(context.filesDir).deleteComicDownloads(comicId)
        .then((removedCount: number) => {
          console.info(`[library-remove] downloads_cleanup removed=${removedCount}`)
        })
        .catch((_error: Error) => {
          console.warn('[library-remove] downloads_cleanup_failed reason=delete_downloads')
        })
    } catch (_error) {
      console.warn('[library-remove] downloads_cleanup_failed reason=context_unavailable')
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

  private handleUpdateCategoryMembershipRequested(comicIds: ComicId[], categoryId: string, selected: boolean): boolean {
    const persistenceService = this.ensureLibraryPersistenceService()
    if (persistenceService === undefined) {
      comicIds.forEach((comicId: ComicId) => {
        const comic = this.libraryStore.getComic(comicId)
        if (comic !== undefined) {
          this.libraryStore.upsertComic(
            selected ? withComicAddedCategoryId(comic, categoryId) : withComicRemovedCategoryId(comic, categoryId)
          )
        }
      })
      this.refreshLibrarySnapshot()
      return comicIds.length > 0
    }
    try {
      const changedCount = updateComicCategoryMembershipAndPersistLibraryStore(
        this.libraryStore,
        persistenceService,
        comicIds,
        categoryId,
        selected
      )
      if (changedCount > 0) {
        this.refreshLibrarySnapshot()
      }
      return changedCount > 0
    } catch (error) {
      const e = error as Error
      console.error('persist category membership failed: ' + e.message)
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

  private triggerAutomaticBackup(context: common.UIAbilityContext): void {
    if (this.automaticBackupChecked) {
      return
    }
    this.automaticBackupChecked = true
    void new BackupService(context).runAutomaticLocalBackupIfDue()
      .then((result: BackupAutomaticRunResult) => {
        if (result.ran) {
          console.info(`[Backup] step=app_open_auto_backup deleted=${result.deletedCount}`)
        } else if (result.failureCode !== undefined) {
          console.error(`[Backup] step=app_open_auto_backup_failed code=${result.failureCode}`)
        }
      })
      .catch((_error: Error) => {
        console.error('[Backup] step=app_open_auto_backup_failed code=backup_auto_export_failed')
      })
  }

  private triggerPendingTrackerProgressSync(context: common.UIAbilityContext): void {
    if (this.pendingTrackerProgressChecked) {
      return
    }
    this.pendingTrackerProgressChecked = true
    void new TrackerProgressSyncService(context).retryPendingProgress(10)
      .then((summary: TrackerPendingProgressDrainSummary) => {
        if (summary.scannedCount > 0) {
          console.info('[TrackerSync] step=app_open_pending_progress scanned=' + summary.scannedCount +
            ' synced=' + summary.syncedCount +
            ' retained=' + summary.retainedCount +
            ' failed=' + summary.failedCount +
            ' skipped=' + summary.skippedCount)
        }
      })
      .catch((_error: Error) => {
        console.warn('[TrackerSync] step=app_open_pending_progress status=failed reason=provider_failed')
      })
  }

  aboutToAppear(): void {
    RouterHelper.setAppPathStack(this.appPathStack)
    RouterHelper.consumePendingLaunchRoute()
    const context = getContext(this) as common.UIAbilityContext
    configureSourceSettingsStore(context)
    bootstrapSourceRuntimeAppRegistry(context)
    if (!this.libraryPersistenceRestored) {
      this.libraryPersistenceRestored = true
      const persistenceService = this.ensureLibraryPersistenceService()
      if (persistenceService !== undefined) {
        try {
          persistenceService.restore()
          this.refreshLibrarySnapshot()
        } catch (error) {
          const e = error as Error
          console.error('restore library store failed: ' + e.message)
        }
      }
    }
    this.triggerAutomaticBackup(context)
    this.triggerPendingTrackerProgressSync(context)
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
          readerOpen: this.readerOpen!!,
          pageIndex: this.readerPageIndex!!,
          chromeVisible: this.readerChromeVisible!!,
          webtoonMode: this.readerWebtoonMode!!,
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
          },
          onLocalFolderImportSucceeded: (scanResult: LocalLibraryFolderScanResult, rootUri: string): LocalFolderImportPersistResult => {
            const result = this.handleLocalFolderImportSucceeded(scanResult, rootUri)
            if (result.importedCount > 0) {
              this.appPathStack.pop(false)
            }
            return result
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_import_title')))
    } else if (name === RouteName.MANGA_DETAIL) {
      HdsNavDestination() {
        MangaDetailPage({
          params: { mangaId: (param as Record<string, string>)?.mangaId, sourceId: (param as Record<string, string>)?.sourceId },
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          readerSessionStore: this.readerSessionStore,
          sourceRegistry: this.sourceRegistry,
          onBack: () => { this.appPathStack.pop(false) },
          onOpenReader: (mangaId: string, chapterId?: string) => { void this.openReader(mangaId, chapterId) },
          onOpenImportRequested: () => { this.openImport() },
          onLibraryChanged: () => { this.refreshLibrarySnapshot() }
        })
      }
      .hideTitleBar(true)
    } else if (name === RouteName.KOMGA_SERVER) {
      HdsNavDestination() {
        KomgaServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_komga_title')))
    } else if (name === RouteName.OPDS_SERVER) {
      HdsNavDestination() {
        OpdsServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_opds_title')))
    } else if (name === RouteName.WEBDAV_SERVER) {
      HdsNavDestination() {
        WebDavServerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_webdav_title')))
    } else if (name === RouteName.SOURCE_PACKAGE_MANAGER) {
      HdsNavDestination() {
        SourcePackageManagerPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_source_package_manager_title')))
    } else if (name === RouteName.SETTINGS_PANE) {
      HdsNavDestination() {
        SettingsPage({
          pane: this.settingsPaneFromParam(param),
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          sourceRegistry: this.sourceRegistry,
          onOpenSettingsPane: (nextPane: SettingsPaneKey) => {
            this.openSettingsPane(nextPane)
          },
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
          onOpenLibraryCategories: () => {
            this.openSettingsSecondary(RouteName.LIBRARY_CATEGORIES)
          },
          onOpenDownloads: () => {
            this.openSettingsSecondary(RouteName.DOWNLOADS)
          },
          onOpenBackupManagement: () => {
            this.openSettingsSecondary(RouteName.BACKUP_MANAGEMENT)
          },
          onOpenTrackerSettings: () => {
            this.openSettingsSecondary(RouteName.TRACKER_SETTINGS)
          },
          onOpenImportRequested: () => {
            this.openImport()
          },
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(settingsPaneTitle(this.settingsPaneFromParam(param))))
    } else if (name === RouteName.LIBRARY_UPDATE_RESULTS) {
      HdsNavDestination() {
        LibraryUpdateResultPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_library_update_results_title')))
    } else if (name === RouteName.LIBRARY_CATEGORIES) {
      HdsNavDestination() {
        LibraryCategoryManagementPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.ensureLibraryPersistenceService(),
          onLibraryChanged: () => {
            this.refreshLibrarySnapshot()
          }
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_library_categories_title')))
    } else if (name === RouteName.DOWNLOADS) {
      HdsNavDestination() {
        DownloadsPage({
          libraryStore: this.libraryStore,
        })
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_downloads_title')))
    } else if (name === RouteName.BACKUP_MANAGEMENT) {
      HdsNavDestination() {
        BackupManagementPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_backup_management_title')))
    } else if (name === RouteName.TRACKER_SETTINGS) {
      HdsNavDestination() {
        TrackerSettingsPage()
      }
      .titleBar(this.navDestTitleBarOpts(AppStrings.get('route_tracker_settings_title')))
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
    Stack() {
      if (this.languageState.effectiveLocale.length >= 0) {
        HdsNavigation(this.appPathStack) {
          HdsTabs({ controller: this.tabController, index: this.selectedTab }) {
            TabContent() {
              LibraryPage({
                libraryStore: this.libraryStore,
                libraryComics: this.libraryComics,
                libraryRevision: this.libraryRevision,
                presentationByComicId: this.presentationByComicId,
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
                },
                onUpdateCategoryMembershipRequested: (comicIds: ComicId[], categoryId: string, selected: boolean) => {
                  return this.handleUpdateCategoryMembershipRequested(comicIds, categoryId, selected)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.LIBRARY), TabIndex.LIBRARY))

            TabContent() {
              BrowsePage({
                sourceRegistry: this.sourceRegistry,
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                  this.selectedTab = TabIndex.LIBRARY
                },
                onOpenSourcePackageManager: () => {
                  this.openSettingsSecondary(RouteName.SOURCE_PACKAGE_MANAGER)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.BROWSE), TabIndex.BROWSE))

            TabContent() {
              HistoryPage({
                libraryStore: this.libraryStore,
                active: this.selectedTab === TabIndex.HISTORY,
                onOpenReader: (comicId: ComicId, chapterId?: string) => {
                  void this.openReader(comicId, chapterId)
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.HISTORY), TabIndex.HISTORY))

            TabContent() {
              SearchPage({
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                  this.selectedTab = TabIndex.LIBRARY
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.SEARCH), TabIndex.SEARCH))

            TabContent() {
              SettingsPage({
                pane: 'root',
                libraryStore: this.libraryStore,
                libraryPersistenceService: this.ensureLibraryPersistenceService(),
                sourceRegistry: this.sourceRegistry,
                onOpenSettingsPane: (pane: SettingsPaneKey) => {
                  this.openSettingsPane(pane)
                },
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
                onOpenLibraryCategories: () => {
                  this.openSettingsSecondary(RouteName.LIBRARY_CATEGORIES)
                },
                onOpenDownloads: () => {
                  this.openSettingsSecondary(RouteName.DOWNLOADS)
                },
                onOpenBackupManagement: () => {
                  this.openSettingsSecondary(RouteName.BACKUP_MANAGEMENT)
                },
                onOpenTrackerSettings: () => {
                  this.openSettingsSecondary(RouteName.TRACKER_SETTINGS)
                },
                onOpenImportRequested: () => {
                  this.openImport()
                },
                onLibraryChanged: () => {
                  this.refreshLibrarySnapshot()
                }
              })
            }.tabBar(this.TabIcon(tabLabel(TabIndex.SETTINGS), TabIndex.SETTINGS))
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private titleBarOptions(): Record<string, Object> {
    let titleInfo: Record<string, Object> = { 'mainTitle': tabLabel(this.selectedTab) }
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
