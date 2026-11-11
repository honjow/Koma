import { sourceChapterOrderFor } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { canMigrateLibraryComic } from '../model/SourceMangaMigration'
import { komaMenuOptions, komaSheetOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { libraryUnreadBadgeOptions } from '../components/LibraryUnreadBadge'
import { LibrarySortMenuItems, librarySortLabel, librarySortSummary } from '../components/LibrarySortMenu'
import { cachedLibraryChapterUpdateTimes } from '../model/LibraryChapterUpdates'
import { firstReaderChapter } from '../model/ReaderChapterSequence'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'
import { KomaMenuController, KomaMenuAction as LibraryTitleMenuItem, komaTitleMoreIcon } from '../components/ui/KomaMenuController'
import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { PullRefresh } from '../components/PullRefresh'
import { CachedCoverImage, cachedCoverFailureKey } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaModalScaffold, komaModalSheetOptions } from '../components/KomaModalScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'
import { gridFallbackContainerWidth } from '../utils/GridColumns'
import { libraryCoverGridColumnCount, libraryCoverGridGap } from '../utils/LibraryCoverLayout'
import {
  ContinueReadingCardViewModel,
  LibraryComicPresentation,
  LibraryPresentationByComicId,
  LibraryViewModel,
  createLibraryViewModelFromComics,
} from '../model/MockLibraryData'
import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  CustomLibraryCategory,
  LibraryItem,
  ReadingProgress,
  normalizeCategoryIds,
} from '../model/ComicModels'
import {
  LibraryCategoryFilter,
  LibraryCategoryDisplayStrategy,
  InMemoryLibraryStore,
  LibraryListOptions,
  LibraryReadStateFilter,
  LibrarySortBy,
  LibrarySortDirection,
  librarySortDirection,
  LibraryStore,
} from '../model/LibraryStore'
import {
  LibraryAvailabilityFilter,
  effectiveLibraryDefaultSort,
  LibraryDefaultSortPreference,
  LibraryFilterPreferences,
  LibraryFilterStore,
  LibraryFilterPreferenceChanges,
  LibraryListDensity,
  LibraryMetadataStatusFilter,
  libraryRuntimeIdFromSourceFilter,
  libraryRuntimeSourceFilter,
  libraryServerIdFromSourceFilter,
  libraryServerSourceFilter,
  LibrarySourceFilter,
  LibraryViewMode,
} from '../model/LibraryFilterStore'
import { OfflineDownloadQueueEntry, OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
import { OfflineDownloadStatus } from '../model/OfflineDownloadStore'
import { OfflineDownloadRuntime } from '../model/OfflineDownloadRuntime'
import { TrackerPreferencesStore, ComicTrackerMapping } from '../model/TrackerModels'
import { LibrarySmartCategory, comicMatchesSmartCategory } from '../model/LibrarySmartCategory'
import { LibraryBatchDownloadPlan, LibraryBatchDownloadQueue } from '../model/LibraryBatchDownloadQueue'
import {
  ensureKomaContentStorageBase,
  komaContentStorageBase,
  komaRuntimeStorageKey,
} from '../model/KomaContentStorage'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import {
  isRemovableLocalComic,
  isRemovableShelfComic,
  LibraryStorePersistenceService,
  setCategoryDisplayStrategyAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import {
  InMemoryReaderSessionStore,
  ReaderSessionStore,
  ChapterReadMutation,
} from '../model/ReaderSessionStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'

function s(name: string): string {
  return AppStrings.get(name)
}

interface LibraryServerSourceFilterOption {
  filter: LibrarySourceFilter
  title: string
}

type CategoryCheckState = 'none' | 'mixed' | 'all'

interface LibraryCategoryChoice {
  id: string
  name: string
  initial: CategoryCheckState
}

interface LibraryGridProjection {
  comics: ComicCoverInfo[]
  byId: Map<ComicId, ComicCoverInfo>
  indexById: Map<ComicId, number>
}

interface LibraryComicBuilderParams {
  comic: ComicCoverInfo
}

interface LibraryCheckboxBuilderParams {
  comic: ComicCoverInfo
  onCover: boolean
}

/**
 * `displayedComics` is a projection that depends on both the injected library
 * store and persisted filters. Keep the two unresolved states separate so an
 * empty array is never presented as a confirmed empty or filtered library.
 */
enum LibraryProjectionState {
  PENDING,
  READY,
}

@ComponentV2
struct ContinueReadingShelfCard {
  @Param compactList: boolean = false
  @Param info: ContinueReadingCardViewModel = {
    title: '',
    detail: '',
    progress: 0,
    color: ThemeConstants.SOURCE_LOCAL_COLOR,
    comicId: '',
  }
  // The library snapshot uses this existing revision bridge to keep its
  // continue-reading content reactive. It is not part of cover identity.
  @Param revision: number = 0
  @Local private failedCoverUri: string = ''
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}

  private shouldShowCover(): boolean {
    const coverUri = this.info.coverUri ?? ''
    return coverUri.length > 0 && this.failedCoverUri !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(
      this.info.coverUri,
      this.info.sourceRuntimeId,
      this.info.sourceImageId ?? this.info.comicId,
      this.info.sourceKind,
      this.info.remoteServerId,
      this.info.sourceMangaUrl,
    )
  }

  build() {
    Row({ space: this.compactList ? ThemeConstants.SPACE_SM : ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.book'))
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .fontColor([ThemeConstants.TEXT_TERTIARY])
        if (this.shouldShowCover()) {
          CachedCoverImage({
            uri: this.info.coverUri ?? '',
            objectFit: ImageFit.Cover,
            sourceRuntimeId: this.info.sourceRuntimeId ?? '',
            sourceImageId: this.info.sourceImageId ?? this.info.comicId,
            sourceKind: this.info.sourceKind,
            remoteServerId: this.info.remoteServerId ?? '',
            sourceMangaUrl: this.info.sourceMangaUrl ?? '',
            decodeMaxEdge: 256,
            onError: () => {
              this.failedCoverUri = this.coverFailureKey()
            },
          })
        }
      }
      .width(76)
      .height(102)
      .borderRadius(ThemeConstants.RADIUS_COVER)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(s('library_continue_reading'))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
        Text(this.info.title)
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.info.detail)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: this.info.progress, total: 100, type: ProgressType.Linear })
          .height(4)
          .color(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(ThemeConstants.SOFT_TINT)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(this.compactList ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.onOpenReader(this.info.comicId)
    })
  }
}

export interface LibraryTitleBarPresentation {
  selectionMode: boolean
  batchDownloadBusy: boolean
  selectedCount: number
  menuItems: Record<string, Object>[]
  cancelSelection: () => void
}

@ComponentV2
export struct LibraryPage {
  @Param libraryStore: LibraryStore = new InMemoryLibraryStore()
  @Param libraryComics: Comic[] = []
  @Param libraryRevision: number = 0
  @Param libraryPreferencesRevision: number = 0
  @Param readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param readerProgressRevision: number = 0
  @Param active: boolean = true
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private displayedComics: Comic[] = []
  @Local private displayedRevision: number = 0
  @Local private projectionState: LibraryProjectionState = LibraryProjectionState.READY
  @Local private selectionMode: boolean = false
  @Local private selectedIds: Set<ComicId> = new Set<ComicId>()
  @Local private batchDownloadBusy: boolean = false
  @Local private suppressOpenComicId: ComicId = ''
  @Local private sortBy: LibrarySortBy = 'lastRead'
  @Local private sortDirection: LibrarySortDirection = 'desc'
  @Local private followsDefaultSort: boolean = false
  @Local private hasCategoryContents: boolean = false
  private defaultSort: LibraryDefaultSortPreference = { sortBy: 'lastRead', sortDirection: 'desc', sortConfigured: false }
  @Local private viewMode: LibraryViewMode = 'grid'
  @Local private listDensity: LibraryListDensity = 'standard'
  @Local private showLibraryBadges: boolean = true
  @Local private filterSource: LibrarySourceFilter = 'all'
  @Local private filterReadState: LibraryReadStateFilter = 'all'
  @Local private filterCategory: LibraryCategoryFilter = 'all'
  private smartSubscriptions: (() => void)[] = []
  @Local private filterAvailability: LibraryAvailabilityFilter = 'all'
  @Local private filterMetadataStatus: LibraryMetadataStatusFilter = 'all'
  @Local private containerWidth: number = gridFallbackContainerWidth()
  @Local private layoutSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param libraryScroller: Scroller = new Scroller()
  @Event onRootScroll: (offset: number, state: ScrollState) => void = (_offset: number, _state: ScrollState) => {}
  private activeFilterCount(): number {
    let count = 0
    if (this.filterSource !== 'all') {
      count += 1
    }
    if (this.filterReadState !== 'all') {
      count += 1
    }
    if (this.filterAvailability !== 'all') {
      count += 1
    }
    if (this.filterMetadataStatus !== 'all') {
      count += 1
    }
    return count
  }

  private filtersButtonLabel(): string {
    const count = this.activeFilterCount()
    return count > 0 ? `${s('common_filter')} · ${count}` : s('common_filter')
  }

  private closeFilterSheet(): void {
    this.filtersShown = false
  }

  @Local private filtersShown: boolean = false
  @Local private categoryEditorShown: boolean = false
  @Local private categoryChoices: LibraryCategoryChoice[] = []
  @Local private categoryChecks: Map<string, CategoryCheckState> = new Map<string, CategoryCheckState>()
  private categoryEditComicIds: ComicId[] = []
  private titleMenu: KomaMenuController = new KomaMenuController()
  @Local private comicActionMenuKey: string = ''
  @Local private failedCoverUris: string[] = []
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  private filterPreferencesRestoreEpoch: number = 0
  private filterPreferencesMutationRevision: number = 0
  @Param presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
  @Param sourceRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onOpenMangaDetail: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}
  @Event onProgressStoreReloadRequested: () => void = () => {}
  @Event onRefresh: () => Promise<void> = async () => {}
  @Local private scrollEnabled: boolean = true
  @Event onImportRequested: () => void = () => {}
  @Event onSearchRequested: () => void = () => {}
  @Event onMigrationRequested: (comicIds: string[]) => void = () => {}
  @Event onOpenDownloadsRequested: () => void = () => {}
  @Event onOpenUpdatesRequested: () => void = () => {}
  @Event onOpenCategoriesRequested: () => void = () => {}
  @Event onTitleBarChange: (presentation: LibraryTitleBarPresentation) => void =
    (_presentation: LibraryTitleBarPresentation) => {}
  @Event onRemoveComicRequested: (comicId: ComicId) => boolean = (_comicId: ComicId) => false
  @Event onRemoveComicsRequested: (comicIds: ComicId[]) => number = (_comicIds: ComicId[]) => 0
  @Event onEditCategoriesRequested: (comicIds: ComicId[], added: string[], removed: string[]) => void =
    (_comicIds: ComicId[], _added: string[], _removed: string[]) => {}

  @Monitor('selectionMode', 'selectedIds', 'viewMode', 'displayedRevision', 'batchDownloadBusy', 'languageState.effectiveLocale')
  private publishTitleBar(): void {
    const items: Record<string, Object>[] = this.selectionMode ? [
      this.titleMenuItem(s('library_action_select_all'), $r('sys.symbol.checkmark_square'),
        () => { this.selectAllVisibleComics() }, this.hasVisibleLibraryContent()),
      this.titleMenuItem(s('library_action_categories'), $r('sys.symbol.folder'),
        () => { this.openCategoryEditor() }, this.selectedCount() > 0, 'library-title-categories'),
      this.titleMenuItem(s('migration_title'), $r('sys.symbol.arrow_right'), () => {
        const ids = Array.from(this.selectedIds)
        this.exitSelectionMode()
        this.onMigrationRequested(ids)
      }, this.selectedCount() > 0 && Array.from(this.selectedIds).every((id: string): boolean =>
        canMigrateLibraryComic(this.libraryStore.getComic(id)))),
      this.titleMenuItem(s('library_batch_mark_read'), $r('sys.symbol.book'),
        () => { this.markSelectedReadState(true) }, this.selectedCount() > 0),
      this.titleMenuItem(s('library_batch_mark_unread'), $r('sys.symbol.book'),
        () => { this.markSelectedReadState(false) }, this.selectedCount() > 0),
      this.titleMenuItem(s('common_remove'), $r('sys.symbol.trash'),
        () => { this.showBatchRemoveConfirmation() }, this.selectedRemovableCount() > 0),
      this.titleMenuItem(s('library_download_unread'), $r('sys.symbol.arrow_down_to_line'),
        () => { void this.confirmSelectedComicsDownload(true) }, this.selectedCount() > 0 && !this.batchDownloadBusy),
      this.titleMenuItem(s('library_download_all'), $r('sys.symbol.arrow_down_to_line'),
        () => { void this.confirmSelectedComicsDownload(false) }, this.selectedCount() > 0 && !this.batchDownloadBusy),
    ] : [
      this.titleMenuItem(s('tab_search'), $r('sys.symbol.magnifyingglass'),
        () => { this.onSearchRequested() }),
      this.titleMenuItem(s('library_updates_title'), $r('sys.symbol.bell'),
        () => { this.onOpenUpdatesRequested() }, true, 'library-title-updates'),
      this.titleMenuItem(s('common_more_actions'), komaTitleMoreIcon(),
        () => { this.openTitleMenu('more') }, true, 'library-title-more'),
    ]
    this.onTitleBarChange({
      selectionMode: this.selectionMode,
      batchDownloadBusy: this.batchDownloadBusy,
      selectedCount: this.selectedCount(),
      menuItems: items,
      cancelSelection: () => {
        if (this.categoryEditorShown) this.categoryEditorShown = false
        else this.exitSelectionMode()
      },
    })
  }

  private titleMenuItem(label: string, icon: Resource, action: () => void,
    isEnabled: boolean = true, componentId: string = ''): Record<string, Object> {
    const content: Record<string, Object> = { 'label': label, 'icon': icon, 'action': action, 'isEnabled': isEnabled }
    if (componentId.length > 0) {
      content['componentId'] = componentId
    }
    const item: Record<string, Object> = { 'content': content }
    return item
  }

  private closeTitleMenu(): void { this.titleMenu.close() }

  private openTitleMenu(key: string): void {
    this.titleMenu.open(this.getUIContext(), `library-title-${key}`,
      () => [{ id: key, items: this.titleMenuItems(key) }], () => { this.showToast(s('common_unavailable')) })
  }

  @Monitor('libraryComics', 'libraryRevision')
  private syncDisplayedSnapshotFromProps(): void {
    if (!this.active) return
    this.refreshDisplayedSnapshotFromStore()
    this.displayedRevision = this.libraryRevision
    this.removeMissingSelectedComics()
  }

  @Monitor('active')
  private onActiveChanged(): void {
    if (!this.active) return
    this.refreshDisplayedSnapshotFromStore()
  }

  @Monitor('remoteProgress.syncRevision')
  private onRemoteProgressSyncRevChanged(): void {
    void this.remoteProgress.syncRevision
    this.onProgressStoreReloadRequested()
  }

  @Monitor('readerSessionStore', 'readerProgressRevision')
  private onReaderProgressSnapshotChanged(): void {
    if (!this.active) return
    void this.readerProgressRevision
    this.refreshDisplayedSnapshotFromStore()
  }

  @Monitor('libraryPreferencesRevision')
  private onLibraryPreferencesChanged(): void {
    this.beginFilterPreferencesRestore()
  }

  private refreshDisplayedSnapshotFromStore(): void {
    const progressByComicId = this.progressByComicId()
    const category = this.validCategoryFilter()
    const strategy = this.libraryStore.getCategoryDisplayStrategy(this.filterCategory)
    this.applyCategorySort(strategy)
    const items = this.libraryStore.listLibraryItems(progressByComicId, this.currentListOptions(category))
    const nextComics: Comic[] = []
    items.forEach((item: LibraryItem) => {
      const comic = this.libraryStore.getComic(item.comicId)
      if (comic !== undefined) {
        nextComics.push(comic)
      }
    })
    const categoryComics = this.filterSmartCategoryComics(nextComics)
    this.hasCategoryContents = categoryComics.length > 0
    const sourceKinds = this.sourceKindsForFilter()
    const scopedComics = categoryComics.filter((comic: Comic): boolean => {
      if (sourceKinds !== undefined && !sourceKinds.includes(comic.sourceKind)) return false
      return this.filterReadState === 'all' || this.readerSessionStore.comicReadingState(comic) === this.filterReadState
    })
    this.displayedComics = this.filterMetadataStatusComics(
      this.filterAvailabilityComics(this.filterPreciseSourceComics(scopedComics)))
    this.displayedRevision += 1
    this.removeMissingSelectedComics()
  }

  private isProjectionPending(): boolean {
    return this.projectionState === LibraryProjectionState.PENDING
  }

  private selectedSmartCategory(): LibrarySmartCategory | undefined {
    return this.libraryStore.listSmartCategories().find((category: LibrarySmartCategory): boolean => category.id === this.filterCategory)
  }

  private filterSmartCategoryComics(comics: Comic[]): Comic[] {
    const group = this.selectedSmartCategory()
    if (group === undefined) return comics
    const tracked = new Set<string>()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (group.filters.some((filter): boolean => filter.method === 'tracking')) {
      new TrackerPreferencesStore(context).mappingSnapshot().forEach((mapping: ComicTrackerMapping): void => {
        if (mapping.mappingState === 'confirmed' && mapping.userConfirmed) tracked.add(mapping.comicId)
      })
    }
    const downloaded = group.filters.some((filter): boolean => filter.method === 'downloaded')
      ? new Set<string>(this.downloadedComicAvailability(comics).keys()) : new Set<string>()
    return comics.filter((comic: Comic): boolean => comicMatchesSmartCategory(comic, group,
      { reader: this.readerSessionStore, downloaded, tracked }))
  }

  private markFilterPreferencesMutation(): void {
    this.filterPreferencesMutationRevision += 1
  }

  private filterMetadataStatusComics(comics: Comic[]): Comic[] {
    if (this.filterMetadataStatus === 'all') {
      return comics
    }
    return comics.filter((comic: Comic): boolean =>
      (comic.sourceMetadata?.status ?? comic.localMetadata?.status ?? 'unknown') === this.filterMetadataStatus)
  }

  private filterAvailabilityComics(comics: Comic[]): Comic[] {
    if (this.filterAvailability === 'all') {
      return comics
    }
    const downloadedComics = this.downloadedComicAvailability(comics)
    if (this.filterAvailability === 'downloaded') {
      return comics.filter((comic: Comic): boolean => downloadedComics.has(comic.id))
    }
    if (this.filterAvailability === 'fully_downloaded') {
      return comics.filter((comic: Comic): boolean => downloadedComics.get(comic.id) === OfflineDownloadStatus.DOWNLOADED)
    }
    if (this.filterAvailability === 'partially_downloaded') {
      return comics.filter((comic: Comic): boolean => downloadedComics.get(comic.id) === OfflineDownloadStatus.PARTIAL)
    }
    return comics.filter((comic: Comic): boolean => !downloadedComics.has(comic.id))
  }

  private downloadedComicAvailability(comics: Comic[]): Map<ComicId, OfflineDownloadStatus> {
    const comicAvailability = new Map<ComicId, OfflineDownloadStatus>()
    try {
      const context = getContext(this) as common.UIAbilityContext
      // Startup reconciliation already validates manifests off the UI thread. Filtering uses the
      // durable queue projection instead of restating every downloaded manifest while the shelf moves.
      const entries = new OfflineDownloadQueueStore(komaContentStorageBase(context), komaRuntimeStorageKey(context)).load()
      const entriesByComicId = new Map<ComicId, OfflineDownloadQueueEntry[]>()
      entries.forEach((entry: OfflineDownloadQueueEntry) => {
        if (entry.status !== OfflineDownloadStatus.DOWNLOADED) {
          return
        }
        const existing = entriesByComicId.get(entry.comicId) ?? []
        existing.push(entry)
        entriesByComicId.set(entry.comicId, existing)
      })
      comics.forEach((comic: Comic) => {
        const chapterIds = new Set<string>()
        comic.chapters.forEach((chapter: Chapter) => {
          if (chapter.id.trim().length > 0) {
            chapterIds.add(chapter.id)
          }
        })
        if (chapterIds.size === 0) {
          return
        }
        const downloadedChapterIds = new Set<string>()
        const chapterEntries = entriesByComicId.get(comic.id) ?? []
        for (let index = 0; index < chapterEntries.length; index += 1) {
          const entry = chapterEntries[index]
          if (!chapterIds.has(entry.chapterId)) {
            continue
          }
          downloadedChapterIds.add(entry.chapterId)
        }
        if (downloadedChapterIds.size === 0) {
          return
        }
        if (downloadedChapterIds.size === chapterIds.size) {
          comicAvailability.set(comic.id, OfflineDownloadStatus.DOWNLOADED)
          return
        }
        comicAvailability.set(comic.id, OfflineDownloadStatus.PARTIAL)
      })
    } catch (error) {
      void error
      console.info('[Library] step=download_filter_load_failed reason=download_filter')
    }
    return comicAvailability
  }

  private filterPreciseSourceComics(comics: Comic[]): Comic[] {
    const serverId = libraryServerIdFromSourceFilter(this.filterSource)
    if (serverId !== undefined) {
      return comics.filter((comic: Comic): boolean => comic.remoteServerId === serverId)
    }
    const sourceId = libraryRuntimeIdFromSourceFilter(this.filterSource)
    if (sourceId !== undefined) {
      return comics.filter((comic: Comic): boolean => comic.sourceRuntimeId === sourceId)
    }
    if (this.filterSource === 'source_package') {
      return comics.filter((comic: Comic): boolean => this.isSourcePackageComic(comic))
    }
    if (this.filterSource === 'private') {
      return comics.filter((comic: Comic): boolean => this.isPrivateLibraryComic(comic))
    }
    return comics
  }

  private isSourcePackageComic(comic: Comic): boolean {
    return comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY &&
      comic.sourceRuntimeId !== undefined &&
      comic.sourceRuntimeId.trim().length > 0
  }

  private isPrivateLibraryComic(comic: Comic): boolean {
    if (this.isSourcePackageComic(comic)) {
      return false
    }
    return comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY ||
      comic.sourceKind === ComicSourceKind.KOMGA_REMOTE ||
      comic.sourceKind === ComicSourceKind.KAVITA_REMOTE ||
      comic.sourceKind === ComicSourceKind.OPDS_REMOTE ||
      comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE
  }

  private progressByComicId(): Map<ComicId, ReadingProgress> {
    const progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
    this.libraryStore.listComics().forEach((comic: Comic) => {
      const progress = this.readerSessionStore.getComicProgress(comic)
      if (progress !== undefined) {
        progressByComicId.set(comic.id, progress)
      }
    })
    return progressByComicId
  }

  private currentListOptions(category: LibraryCategoryFilter): LibraryListOptions {
    return {
      readerSessionStore: this.readerSessionStore,
      sortBy: this.sortBy,
      sortDirection: this.sortDirection,
      chapterUpdateTimes: this.sortBy === 'lastUpdate' ? cachedLibraryChapterUpdateTimes() : undefined,
      sourceSortName: this.sortBy === 'source' ? (comic: Comic): string => this.librarySourceSortName(comic) : undefined,
      filterCategoryId: category,
    }
  }

  private validCategoryFilter(): LibraryCategoryFilter {
    if (this.selectedSmartCategory() !== undefined) return 'all'
    if (this.filterCategory === 'all') return 'all'
    const categoryExists = this.libraryStore.listCustomCategories().some((category: CustomLibraryCategory): boolean => {
      return category.id === this.filterCategory
    })
    if (categoryExists) {
      return this.filterCategory
    }
    this.filterCategory = 'all'
    this.markFilterPreferencesMutation()
    this.saveFilterPreferences({ category: 'all' })
    console.info('[Library] step=category_filter_reset reason=missing_category')
    return 'all'
  }

  private sourceKindsForFilter(): ComicSourceKind[] | undefined {
    if (this.filterSource === 'all') {
      return undefined
    }
    if (libraryServerIdFromSourceFilter(this.filterSource) !== undefined) {
      return [
        ComicSourceKind.PRIVATE_LIBRARY,
        ComicSourceKind.KOMGA_REMOTE,
        ComicSourceKind.KAVITA_REMOTE,
        ComicSourceKind.OPDS_REMOTE,
        ComicSourceKind.WEBDAV_REMOTE,
      ]
    }
    if (libraryRuntimeIdFromSourceFilter(this.filterSource) !== undefined) {
      return [ComicSourceKind.PRIVATE_LIBRARY]
    }
    if (this.filterSource === 'local') {
      return [ComicSourceKind.LOCAL_ARCHIVE, ComicSourceKind.LOCAL_FOLDER]
    }
    if (this.filterSource === 'private') {
      return [
        ComicSourceKind.PRIVATE_LIBRARY,
        ComicSourceKind.KOMGA_REMOTE,
        ComicSourceKind.KAVITA_REMOTE,
        ComicSourceKind.OPDS_REMOTE,
        ComicSourceKind.WEBDAV_REMOTE,
      ]
    }
    if (this.filterSource === 'komga') {
      return [ComicSourceKind.KOMGA_REMOTE]
    }
    if (this.filterSource === 'kavita') {
      return [ComicSourceKind.KAVITA_REMOTE]
    }
    if (this.filterSource === 'opds') {
      return [ComicSourceKind.OPDS_REMOTE]
    }
    if (this.filterSource === 'webdav') {
      return [ComicSourceKind.WEBDAV_REMOTE]
    }
    return [ComicSourceKind.PRIVATE_LIBRARY]
  }

  private beginFilterPreferencesRestore(): void {
    this.filterPreferencesRestoreEpoch += 1
    const restoreEpoch = this.filterPreferencesRestoreEpoch
    const mutationRevision = this.filterPreferencesMutationRevision
    void this.restoreFilterPreferences(restoreEpoch, mutationRevision)
  }

  private async restoreFilterPreferences(restoreEpoch: number, mutationRevision: number): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const preferencesValue = await new LibraryFilterStore(context).load()
      if (restoreEpoch !== this.filterPreferencesRestoreEpoch ||
        mutationRevision !== this.filterPreferencesMutationRevision) {
        console.info('[Library] step=filter_restore_discarded reason=state_changed')
        return
      }
      this.applyFilterPreferences(preferencesValue)
    } catch (error) {
      void error
      console.info('[Library] step=filter_restore_failed reason=filter_restore')
    } finally {
      if (restoreEpoch === this.filterPreferencesRestoreEpoch) {
        // Compute the current projection before exposing it. This covers the
        // persisted snapshot, a user mutation that won the race, and default
        // filters after an unavailable preferences store.
        this.refreshDisplayedSnapshotFromStore()
        this.projectionState = LibraryProjectionState.READY
      }
    }
  }

  private saveFilterPreferences(changes: LibraryFilterPreferenceChanges): void {
    const revision = this.filterPreferencesMutationRevision
    const restoreEpoch = this.filterPreferencesRestoreEpoch
    try {
      const context = getContext(this) as common.UIAbilityContext
      void new LibraryFilterStore(context).update(changes)
        .then((value: LibraryFilterPreferences) => {
          if (revision !== this.filterPreferencesMutationRevision || restoreEpoch !== this.filterPreferencesRestoreEpoch) return
          this.applyFilterPreferences(value)
          this.refreshDisplayedSnapshotFromStore()
        })
        .catch(() => {
          console.info('[Library] step=filter_save_failed reason=filter_save')
          if (revision === this.filterPreferencesMutationRevision && restoreEpoch === this.filterPreferencesRestoreEpoch) {
            void this.recoverFilterPreferencesAfterSave()
          }
        })
    } catch (_error) {
      console.info('[Library] step=filter_save_failed reason=filter_save')
      void this.recoverFilterPreferencesAfterSave()
    }
  }

  private setSortBy(sortBy: LibrarySortBy, sortDirection: LibrarySortDirection): void {
    if (!this.followsDefaultSort && this.sortBy === sortBy && this.sortDirection === sortDirection) {
      return
    }
    if (this.filterCategory !== 'all') {
      this.saveCategorySort(sortBy, sortDirection, false)
      return
    }
    this.markFilterPreferencesMutation()
    this.defaultSort = { sortBy, sortDirection, sortConfigured: true }
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ sortBy, sortDirection })
  }

  private saveCategorySort(sortBy: LibrarySortBy, sortDirection: LibrarySortDirection, followsDefaultSort: boolean): void {
    const persistence = this.libraryPersistenceService
    if (persistence === undefined) {
      this.showToast(s('library_category_display_save_failed'))
      return
    }
    const strategy = this.libraryStore.getCategoryDisplayStrategy(this.filterCategory)
    try {
      setCategoryDisplayStrategyAndPersistLibraryStore(this.libraryStore, persistence, {
        categoryId: this.filterCategory, sortBy, sortDirection, followsDefaultSort,
        readState: strategy?.readState ?? 'all',
        updatedAt: Date.now(),
      })
      this.refreshDisplayedSnapshotFromStore()
    } catch (_error) {
      this.showToast(s('library_category_display_save_failed'))
    }
  }

  private setViewMode(viewMode: LibraryViewMode): void {
    if (this.viewMode === viewMode) {
      return
    }
    this.markFilterPreferencesMutation()
    this.viewMode = viewMode
    this.saveFilterPreferences({ viewMode })
  }

  private setSourceFilter(source: LibrarySourceFilter): void {
    if (this.filterSource === source) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterSource = source
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ source })
    console.info(`[Library] step=filter_changed source=${source} readState=${this.filterReadState}`)
  }

  private setReadStateFilter(readState: LibraryReadStateFilter): void {
    if (this.filterReadState === readState) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterReadState = readState
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ readState })
    console.info(`[Library] step=filter_changed source=${this.filterSource} readState=${readState}`)
  }

  private setCategoryFilter(category: LibraryCategoryFilter): void {
    if (this.filterCategory === category) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterCategory = category
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ category })
    console.info(`[Library] step=filter_changed category=${category}`)
  }

  private setAvailabilityFilter(availability: LibraryAvailabilityFilter): void {
    if (this.filterAvailability === availability) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterAvailability = availability
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ availability })
    console.info(`[Library] step=filter_changed availability=${availability}`)
  }

  private setMetadataStatusFilter(metadataStatus: LibraryMetadataStatusFilter): void {
    if (this.filterMetadataStatus === metadataStatus) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterMetadataStatus = metadataStatus
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ metadataStatus })
    console.info(`[Library] step=filter_changed metadataStatus=${metadataStatus}`)
  }

  private hasActiveFilters(): boolean {
    return this.activeFilterCount() > 0
  }

  private resetFilters(): void {
    if (!this.hasActiveFilters()) {
      return
    }
    this.markFilterPreferencesMutation()
    this.filterSource = 'all'
    this.filterReadState = 'all'
    this.filterAvailability = 'all'
    this.filterMetadataStatus = 'all'
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences({ source: 'all', readState: 'all', availability: 'all', metadataStatus: 'all' })
    console.info('[Library] step=filters_reset')
  }

  private applyCategorySort(strategy?: LibraryCategoryDisplayStrategy): void {
    const isCategory = this.filterCategory !== 'all'
    this.followsDefaultSort = isCategory && (strategy === undefined || strategy.followsDefaultSort === true)
    if (isCategory && strategy !== undefined && !this.followsDefaultSort) {
      this.sortBy = strategy.sortBy
      this.sortDirection = librarySortDirection(strategy.sortBy, strategy.sortDirection)
    } else {
      const sort = effectiveLibraryDefaultSort(this.defaultSort, this.libraryStore)
      this.sortBy = sort.sortBy
      this.sortDirection = sort.sortDirection
    }
  }

  private sourceLabel(): string {
    const runtimeLabel = this.runtimeSourceLabel()
    if (runtimeLabel !== undefined) {
      return runtimeLabel
    }
    const serverLabel = this.serverSourceLabel()
    if (serverLabel !== undefined) {
      return serverLabel
    }
    if (this.filterSource === 'local') {
      return s('library_source_local')
    }
    if (this.filterSource === 'private') {
      return s('library_source_private')
    }
    if (this.filterSource === 'komga') {
      return s('route_komga_title')
    }
    if (this.filterSource === 'kavita') {
      return s('route_kavita_title')
    }
    if (this.filterSource === 'opds') {
      return s('route_opds_title')
    }
    if (this.filterSource === 'webdav') {
      return s('route_webdav_title')
    }
    if (this.filterSource === 'source_package') {
      return s('library_source_package')
    }
    return s('library_source_all')
  }

  private serverSourceLabel(): string | undefined {
    const serverId = libraryServerIdFromSourceFilter(this.filterSource)
    if (serverId === undefined) {
      return undefined
    }
    const option = this.privateServerFilterOptions().find((item: LibraryServerSourceFilterOption): boolean => {
      return item.filter === this.filterSource
    })
    return option === undefined ? s('library_source_private_server') : option.title
  }

  private runtimeSourceLabel(): string | undefined {
    const sourceId = libraryRuntimeIdFromSourceFilter(this.filterSource)
    if (sourceId === undefined) {
      return undefined
    }
    const option = this.runtimeSourceFilterOptions().find((item: LibraryServerSourceFilterOption): boolean => {
      return item.filter === this.filterSource
    })
    return option === undefined ? s('library_source_package') : option.title
  }

  private readStateLabel(readState: LibraryReadStateFilter = this.filterReadState): string {
    if (readState === 'unread') {
      return s('library_read_state_unread')
    }
    if (readState === 'reading') {
      return s('library_read_state_reading')
    }
    if (readState === 'completed') {
      return s('library_read_state_completed')
    }
    return s('library_read_state_all')
  }

  private categoryLabel(): string {
    // Category names can change while this shelf stays mounted.
    void this.displayedRevision
    const smart = this.selectedSmartCategory()
    if (smart !== undefined) return smart.name
    const customCategory = this.libraryStore.listCustomCategories().find((category: CustomLibraryCategory): boolean => {
      return category.id === this.filterCategory
    })
    if (customCategory !== undefined) {
      return customCategory.name
    }
    return s('common_all')
  }

  private availabilityLabel(): string {
    if (this.filterAvailability === 'downloaded') {
      return s('library_availability_downloaded')
    }
    if (this.filterAvailability === 'fully_downloaded') {
      return s('library_availability_fully_downloaded')
    }
    if (this.filterAvailability === 'partially_downloaded') {
      return s('library_availability_partially_downloaded')
    }
    if (this.filterAvailability === 'not_downloaded') {
      return s('library_availability_not_downloaded')
    }
    return s('library_availability_all')
  }

  private metadataStatusLabel(): string {
    if (this.filterMetadataStatus === 'ongoing') {
      return s('manga_status_ongoing')
    }
    if (this.filterMetadataStatus === 'completed') {
      return s('manga_status_completed')
    }
    if (this.filterMetadataStatus === 'hiatus') {
      return s('manga_status_hiatus')
    }
    if (this.filterMetadataStatus === 'cancelled') {
      return s('manga_status_cancelled')
    }
    if (this.filterMetadataStatus === 'unknown') {
      return s('manga_status_unknown')
    }
    return s('library_metadata_status_all')
  }

  @Computed
  private get displayedLibraryViewModel(): LibraryViewModel {
    // Keep the shelf projection tied to the snapshots that can change it. The
    // previous helper rebuilt every card and scanned the whole library once per
    // caller, including repeated calls from the same build pass.
    void this.displayedRevision
    void this.readerProgressRevision
    void this.languageState.effectiveLocale
    return createLibraryViewModelFromComics(this.displayedComics, this.readerSessionStore, this.presentationByComicId)
  }

  @Computed
  private get continueReadingCard(): ContinueReadingCardViewModel {
    // This card intentionally considers the complete shelf, not the filtered
    // projection. Cache that independent scan across header/layout builders.
    void this.libraryRevision
    void this.readerProgressRevision
    void this.languageState.effectiveLocale
    return createLibraryViewModelFromComics(
      this.libraryStore.listComics(),
      this.readerSessionStore,
      this.presentationByComicId,
    ).continueReading
  }

  private viewModel(): LibraryViewModel {
    return this.displayedLibraryViewModel
  }

  private continueReading(): ContinueReadingCardViewModel {
    return this.continueReadingCard
  }

  private hasContinueReading(): boolean {
    return this.continueReadingCard.comicId.length > 0
  }

  private gridComics(): ComicCoverInfo[] {
    return this.viewModel().comics.map((comic: ComicCoverInfo): ComicCoverInfo => {
      const sourceComic = this.libraryStore.getComic(comic.id)
      return {
        id: comic.id,
        title: comic.title,
        subtitle: comic.subtitle,
        unreadChapterCount: comic.unreadChapterCount,
        coverColor: comic.coverColor,
        accentColor: comic.accentColor,
        pageCount: comic.pageCount,
        coverUri: comic.coverUri,
        sourceRuntimeId: comic.sourceRuntimeId,
        sourceMangaUrl: comic.sourceMangaUrl ?? sourceComic?.sourcePath,
        sourceImageId: comic.sourceImageId ?? sourceComic?.remoteResourceId ?? comic.id,
        sourceKind: comic.sourceKind ?? sourceComic?.sourceKind,
        remoteServerId: comic.remoteServerId ?? sourceComic?.remoteServerId,
        categoryLabels: this.showLibraryBadges ?
          (sourceComic === undefined ? comic.categoryLabels : this.categoryLabelsForComic(sourceComic)) :
          [],
      }
    })
  }

  private listRowSubtitle(comic: ComicCoverInfo): string {
    if (comic.categoryLabels !== undefined && comic.categoryLabels.length > 0) {
      return [comic.subtitle].concat(comic.categoryLabels).filter((label: string): boolean => label !== '').join(' · ')
    }
    return comic.subtitle
  }

  @Computed
  private get gridProjection(): LibraryGridProjection {
    // The stores are not observed objects; these existing revisions invalidate
    // same-ID progress/metadata alongside the observed displayed array.
    void this.displayedRevision
    void this.readerProgressRevision
    void this.languageState.effectiveLocale
    const comics = this.gridComics()
    const byId = new Map<ComicId, ComicCoverInfo>()
    const indexById = new Map<ComicId, number>()
    comics.forEach((comic: ComicCoverInfo, index: number) => {
      byId.set(comic.id, comic)
      indexById.set(comic.id, index)
    })
    return { comics: comics, byId: byId, indexById: indexById }
  }

  private currentGridComic(original: ComicCoverInfo): ComicCoverInfo {
    // A removed cell can finish unbinding with its real prior identity.
    return this.gridProjection.byId.get(original.id) ?? original
  }

  private libraryViewportWidth(): number {
    return this.layoutSafeArea.windowWidthVp > 0 ? this.layoutSafeArea.windowWidthVp : this.containerWidth
  }

  private libraryGridColumnCount(): number {
    const measured = this.libraryViewportWidth() > 0
      ? this.libraryViewportWidth()
      : gridFallbackContainerWidth()
    return libraryCoverGridColumnCount(measured, this.listDensity)
  }

 private libraryGridColumnGap(): number {
    return libraryCoverGridGap(this.listDensity)
  }

  private libraryHorizontalInset(): number {
    return this.libraryGridColumnGap()
  }

  private libraryGridRowGap(): number {
    if (this.listDensity === 'compact') {
      return ThemeConstants.SPACE_LG
    }
    if (this.listDensity === 'comfortable') {
      return ThemeConstants.SPACE_XXL
    }
    return ThemeConstants.SPACE_LG
  }

  private libraryGridRowIndexes(comics: ComicCoverInfo[]): number[] {
    const rows: number[] = []
    const columnCount = this.libraryGridColumnCount()
    const rowCount = Math.ceil(comics.length / columnCount)
    for (let index = 0; index < rowCount; index += 1) {
      rows.push(index)
    }
    return rows
  }

  private libraryGridRowComics(comics: ComicCoverInfo[], rowIndex: number): ComicCoverInfo[] {
    const columnCount = this.libraryGridColumnCount()
    const start = rowIndex * columnCount
    return comics.slice(start, start + columnCount)
  }

  private libraryGridMissingCells(rowComics: ComicCoverInfo[]): number[] {
    const cells: number[] = []
    const missing = Math.max(0, this.libraryGridColumnCount() - rowComics.length)
    for (let index = 0; index < missing; index += 1) {
      cells.push(index)
    }
    return cells
  }

 private libraryListSpace(): number {
    if (this.listDensity === 'compact') {
      return ThemeConstants.SPACE_XS
    }
    if (this.listDensity === 'comfortable') {
      return ThemeConstants.SPACE_SM
    }
    return ThemeConstants.SPACE_XS
  }

  private libraryListCoverWidth(): number {
    if (this.listDensity === 'compact') {
      return 42
    }
    if (this.listDensity === 'comfortable') {
      return 56
    }
    return 48
  }

  private libraryListCoverHeight(): number {
    if (this.listDensity === 'compact') {
      return 60
    }
    if (this.listDensity === 'comfortable') {
      return 78
    }
    return 68
  }

  private categoryLabelsForComic(comic: Comic): string[] {
    const labels: string[] = []
    const customCategories = this.libraryStore.listCustomCategories()
    normalizeCategoryIds(comic.categoryIds).forEach((categoryId: string) => {
      const customCategory = customCategories.find((category: CustomLibraryCategory): boolean => category.id === categoryId)
      if (customCategory !== undefined) labels.push(customCategory.name)
    })
    return labels
  }

  private privateServerFilterOptions(): LibraryServerSourceFilterOption[] {
    const seenFilters: string[] = []
    const options: LibraryServerSourceFilterOption[] = []
    this.libraryStore.listComics().forEach((comic: Comic) => {
      if (!this.isPrivateLibraryComic(comic) || comic.remoteServerId === undefined) {
        return
      }
      const serverId = comic.remoteServerId.trim()
      if (serverId.length === 0) {
        return
      }
      const filter = libraryServerSourceFilter(serverId)
      if (seenFilters.includes(filter)) {
        return
      }
      seenFilters.push(filter)
      options.push({
        filter,
        title: this.privateServerFilterTitle(comic),
      })
    })
    return options
  }

  private runtimeSourceFilterOptions(): LibraryServerSourceFilterOption[] {
    const summaries = this.sourceRegistry.listInstalledSourceSummaries()
    const seenFilters: string[] = []
    const options: LibraryServerSourceFilterOption[] = []
    this.libraryStore.listComics().forEach((comic: Comic) => {
      if (!this.isSourcePackageComic(comic) || comic.sourceRuntimeId === undefined) {
        return
      }
      const sourceId = comic.sourceRuntimeId.trim()
      if (sourceId.length === 0) {
        return
      }
      const filter = libraryRuntimeSourceFilter(sourceId)
      if (seenFilters.includes(filter)) {
        return
      }
      const summary = summaries.find((item: SourceRuntimeRegistryInstalledSourceSummary): boolean => {
        return item.sourceId === sourceId
      })
      seenFilters.push(filter)
      options.push({
        filter,
        title: sourceDisplayName(sourceId, summary?.displayName ?? s('library_source_package')),
      })
    })
    return options
  }

  private privateServerFilterTitle(comic: Comic): string {
    if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
      return s('library_source_server').replace('%s', s('route_komga_title'))
    }
    if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
      return s('library_source_server').replace('%s', s('route_kavita_title'))
    }
    if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
      return s('library_source_server').replace('%s', s('route_opds_title'))
    }
    if (comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
      return s('library_source_server').replace('%s', s('route_webdav_title'))
    }
    return s('library_source_private_server')
  }

  private librarySourceSortName(comic: Comic): string {
    if (comic.sourceRuntimeId) {
      return sourceDisplayName(comic.sourceRuntimeId, comic.sourceMetadata?.sourceName ?? comic.sourceRuntimeId)
    }
    if (comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY) return s('library_source_private')
    if (this.isPrivateLibraryComic(comic)) return this.privateServerFilterTitle(comic)
    return s('library_source_local')
  }

  private hasLibraryContent(): boolean {
    return this.displayedRevision >= 0 && this.libraryStore.listComics().length > 0
  }

  private hasVisibleLibraryContent(): boolean {
    return this.displayedRevision >= 0 && this.displayedComics.length > 0
  }

  private canRemoveComic(comicId: ComicId): boolean {
    return this.displayedRevision >= 0 && isRemovableLocalComic(this.libraryStore.getComic(comicId))
  }

  private canSelectComic(comicId: ComicId): boolean {
    return this.displayedRevision >= 0 && this.libraryStore.getComic(comicId) !== undefined
  }

  private comicRenderKey(comic: ComicCoverInfo): string {
    return comic.id
  }

  private listRowRenderKey(comic: ComicCoverInfo): string {
    return `list:${comic.id}`
  }

  private removeMissingSelectedComics(): void {
    if (this.selectedIds.size === 0) {
      return
    }
    const availableIds = new Set<ComicId>(this.displayedComics.map((comic: Comic): ComicId => comic.id))
    const nextSelectedIds = new Set<ComicId>()
    this.selectedIds.forEach((comicId: ComicId) => {
      if (availableIds.has(comicId)) {
        nextSelectedIds.add(comicId)
      }
    })
    this.selectedIds = nextSelectedIds
  }

  private beginSelectionMode(): void {
    this.comicActionMenuKey = ''
    this.closeTitleMenu()
    this.selectedIds = new Set<ComicId>()
    this.selectionMode = true
  }

  private enterSelectionMode(comicId: ComicId): void {
    if (!this.canSelectComic(comicId)) {
      return
    }
    const nextSelectedIds = new Set<ComicId>()
    nextSelectedIds.add(comicId)
    this.selectedIds = nextSelectedIds
    this.selectionMode = true
    this.comicActionMenuKey = ''
    this.closeTitleMenu()
    this.suppressOpenComicId = comicId
  }

  private exitSelectionMode(): void {
    this.suppressOpenComicId = ''
    this.closeTitleMenu()
    this.comicActionMenuKey = ''
    this.selectedIds = new Set<ComicId>()
    this.selectionMode = false
  }

  private isComicSelected(comicId: ComicId): boolean {
    return this.selectedIds.has(comicId)
  }

  private handleComicClick(comicId: ComicId): void {
    if (this.suppressOpenComicId === comicId) {
      this.suppressOpenComicId = ''
      return
    }
    if (this.selectionMode) {
      this.toggleSelection(comicId)
    } else {
      this.openComicDetailFromLibrary(comicId)
    }
  }

  private openComicDetailFromLibrary(comicId: ComicId): void {
    if (this.libraryStore.getComic(comicId) === undefined) {
      this.showToast(s('common_unavailable'))
      return
    }
    this.onOpenMangaDetail(comicId)
  }

  private readerChapterIdForComic(comic: Comic): string | undefined {
    const progress = this.readerSessionStore.getComicProgress(comic)
    if (progress !== undefined && comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
      return progress.chapterId
    }
    return firstReaderChapter(comic.chapters, sourceChapterOrderFor(comic.sourceRuntimeId),
      (id: string): boolean => this.readerSessionStore.isChapterRead(comic.id, id))?.id
  }

  private openComicFromLibrary(comicId: ComicId): void {
    const comic = this.libraryStore.getComic(comicId)
    if (comic === undefined) {
      this.showToast(s('common_unavailable'))
      return
    }
    const chapterId = this.readerChapterIdForComic(comic)
    this.onOpenReader(comicId, chapterId)
  }

  private handleComicTouch(comicId: ComicId, event: TouchEvent): void {
    if (!this.canSelectComic(comicId)) {
      return
    }
    if (event.type === TouchType.Down) {
      this.suppressOpenComicId = ''
    }
  }

  private toggleSelection(comicId: ComicId): void {
    this.setComicSelected(comicId, !this.isComicSelected(comicId))
  }

  private setComicSelected(comicId: ComicId, selected: boolean): void {
    if (!this.selectionMode || !this.canSelectComic(comicId) || this.isComicSelected(comicId) === selected) {
      return
    }
    const nextSelectedIds = new Set<ComicId>(this.selectedIds)
    if (selected) {
      nextSelectedIds.add(comicId)
    } else {
      nextSelectedIds.delete(comicId)
    }
    this.selectedIds = nextSelectedIds
  }

  private selectAllVisibleComics(): void {
    const nextSelectedIds = new Set<ComicId>()
    this.gridComics().forEach((comic: ComicCoverInfo) => {
      if (this.canSelectComic(comic.id)) {
        nextSelectedIds.add(comic.id)
      }
    })
    this.selectedIds = nextSelectedIds
  }

  private selectedCount(): number {
    return this.selectedIds.size
  }

  private selectedRemovableCount(): number {
    return this.selectedRemovableIds().length
  }

  private selectedRemovableIds(): ComicId[] {
    return this.displayedRevision < 0 ? [] : Array.from(this.selectedIds).filter((comicId: ComicId): boolean =>
      isRemovableShelfComic(this.libraryStore.getComic(comicId)))
  }

  private removeSelectedComics(): void {
    const comicIds = this.selectedRemovableIds()
    if (comicIds.length === 0) {
      return
    }
    console.info(`[Library] step=batch_remove count=${comicIds.length}`)
    const removedCount = this.onRemoveComicsRequested(comicIds)
    this.exitSelectionMode()
    if (removedCount > 0) {
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private openCategoryEditor(): void {
    const comics = Array.from(this.selectedIds)
      .map((id: ComicId): Comic | undefined => this.libraryStore.getComic(id))
      .filter((comic: Comic | undefined): boolean => comic !== undefined) as Comic[]
    if (comics.length === 0) return
    this.categoryEditComicIds = comics.map((comic: Comic): ComicId => comic.id)
    this.categoryChoices = this.libraryStore.listCustomCategories().map((category: CustomLibraryCategory): LibraryCategoryChoice => {
      const count = comics.filter((comic: Comic): boolean => normalizeCategoryIds(comic.categoryIds).includes(category.id)).length
      return { id: category.id, name: category.name, initial: count === 0 ? 'none' : count === comics.length ? 'all' : 'mixed' }
    })
    this.categoryChecks = new Map<string, CategoryCheckState>()
    this.categoryEditorShown = true
  }

  private categoryCheck(choice: LibraryCategoryChoice): CategoryCheckState {
    return this.categoryChecks.get(choice.id) ?? choice.initial
  }

  private toggleCategoryCheck(choice: LibraryCategoryChoice): void {
    const current = this.categoryCheck(choice)
    const next = current === 'all' ? 'none' : current === 'none' && choice.initial === 'mixed' ? 'mixed' : 'all'
    const checks = new Map<string, CategoryCheckState>(this.categoryChecks)
    if (next === choice.initial) checks.delete(choice.id)
    else checks.set(choice.id, next)
    this.categoryChecks = checks
  }

  private saveCategoryEditor(): void {
    const added: string[] = []
    const removed: string[] = []
    this.categoryChecks.forEach((state: CategoryCheckState, id: string): void => {
      if (state === 'all') added.push(id)
      else if (state === 'none') removed.push(id)
    })
    try {
      this.onEditCategoriesRequested(this.categoryEditComicIds, added, removed)
      this.categoryEditorShown = false
      this.exitSelectionMode()
    } catch (_error) {
      this.showToast(s('library_category_save_failed'))
    }
  }

  @Builder
  private CategoryEditor() {
    KomaModalScaffold({
      title: s('library_action_categories'),
      confirmLabel: this.categoryChoices.length > 0 ? s('common_save') : undefined,
      confirmEnabled: this.categoryChecks.size > 0,
      onConfirm: (): void => { this.saveCategoryEditor() },
      onClose: (): void => { this.categoryEditorShown = false },
    }) {
      ListItem() {
        GroupedListSection({ inModal: true }) {
          if (this.categoryChoices.length === 0) {
            ConciseListRow({ title: s('settings_row_library_categories_title'), leadingIcon: $r('sys.symbol.plus'),
              action: (): void => {
                this.categoryEditorShown = false
                this.onOpenCategoriesRequested()
              } })
          } else {
            ForEach(this.categoryChoices, (choice: LibraryCategoryChoice, index: number) => {
              ConciseListRow({
                title: choice.name,
                wrapTitle: true,
                showChevron: false,
                trailingIcon: this.categoryCheck(choice) === 'all' ? $r('sys.symbol.checkmark') :
                  this.categoryCheck(choice) === 'mixed' ? $r('sys.symbol.minus') : undefined,
                trailingIconColor: ThemeConstants.BRAND_PRIMARY,
                trailingIconLabel: this.categoryCheck(choice) === 'mixed' ? s('library_category_partial_selection') :
                  s('library_category_selection_checked'),
                trailingIconAction: (): void => { this.toggleCategoryCheck(choice) },
                action: (): void => { this.toggleCategoryCheck(choice) },
              })
              if (index < this.categoryChoices.length - 1) ListDivider()
            }, (choice: LibraryCategoryChoice): string => choice.id)
          }
        }
      }
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (error) {
      void error
    }
  }

  private markSelectedReadState(isRead: boolean): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    const mutations: ChapterReadMutation[] = []
    comicIds.forEach((comicId: ComicId) => {
      const comic = this.libraryStore.getComic(comicId)
      if (comic === undefined || comic.chapters.length === 0) {
        return
      }
      comic.chapters.forEach((chapter: Chapter) => {
        mutations.push({
          comicId: comic.id,
          chapterId: chapter.id,
          isRead,
        })
      })
    })
    if (mutations.length === 0) {
      this.showToast(s('library_batch_read_state_no_chapters'))
      return
    }
    const result = this.readerSessionStore.commitChapterReadStates(mutations)
    if (!result.committed) {
      this.showToast(s('reader_progress_save_failed'))
      return
    }
    const changedCount = result.changedCount
    this.onProgressStoreReloadRequested()
    if (changedCount > 0) {
      console.info(`[Library] step=batch_read_state isRead=${isRead} comics=${comicIds.length} chapters=${changedCount}`)
      this.showToast(isRead ? s('library_batch_marked_read') : s('library_batch_marked_unread'))
      this.exitSelectionMode()
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private showBatchRemoveConfirmation(): void {
    const count = this.selectedRemovableCount()
    if (count === 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('library_batch_remove_title'),
      message: s('library_batch_remove_message').replace('%s', `${count}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeSelectedComics()
        },
      },
    })
  }

  private batchDownloadMessage(plan: LibraryBatchDownloadPlan): string {
    const lines: string[] = [
      s('library_download_current_directory').replace('%s', `${plan.comicCount}`)
        .replace('%s', `${plan.matchedChapterCount}`).replace('%s', `${plan.targets.length}`),
    ]
    if (plan.downloadedCount > 0 || plan.existingCount > 0) {
      lines.push(s('library_download_preserved_counts').replace('%s', `${plan.downloadedCount}`)
        .replace('%s', `${plan.existingCount}`))
    }
    if (plan.unavailableComicCount > 0) {
      lines.push(s('library_download_unavailable_comics').replace('%s', `${plan.unavailableComicCount}`))
    }
    return lines.join('\n\n')
  }

  private async confirmSelectedComicsDownload(unreadOnly: boolean): Promise<void> {
    if (this.batchDownloadBusy || this.selectedIds.size === 0) {
      return
    }
    this.batchDownloadBusy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const storageBase = await ensureKomaContentStorageBase(context)
      const queue = new LibraryBatchDownloadQueue(storageBase, this.libraryStore, this.readerSessionStore,
        komaRuntimeStorageKey(context))
      const plan = queue.prepare(Array.from(this.selectedIds), unreadOnly)
      const title = s(unreadOnly ? 'library_download_unread' : 'library_download_all')
      const message = this.batchDownloadMessage(plan)
      if (plan.targets.length === 0) {
        this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
          title, message, autoCancel: true,
          confirm: { value: s('common_confirm'), action: () => {} },
        })
        return
      }
      this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
        title, message, autoCancel: true,
        primaryButton: { value: s('common_cancel'), action: () => {} },
        secondaryButton: {
          value: s('manga_detail_action_download_chapter'),
          action: () => { void this.enqueueSelectedComicsDownload(queue, plan, unreadOnly) },
        },
      })
    } catch (_error) {
      this.showToast(s('library_download_enqueue_failed'))
    } finally {
      this.batchDownloadBusy = false
    }
  }

  private async enqueueSelectedComicsDownload(queue: LibraryBatchDownloadQueue,
    plan: LibraryBatchDownloadPlan, unreadOnly: boolean): Promise<void> {
    if (this.batchDownloadBusy) {
      return
    }
    this.batchDownloadBusy = true
    try {
      const count = await queue.enqueue(plan.targets, unreadOnly, true)
      this.showToast(s('library_download_enqueued').replace('%s', `${count}`))
      this.exitSelectionMode()
    } catch (_error) {
      this.showToast(s('library_download_enqueue_failed'))
    } finally {
      this.batchDownloadBusy = false
    }
  }

  private showRemoveConfirmation(comic: ComicCoverInfo): void {
    if (!this.canRemoveComic(comic.id)) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('library_remove_title'),
      message: s('library_remove_message').replace('%s', comic.title),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          if (this.onRemoveComicRequested(comic.id)) {
            this.refreshDisplayedSnapshotFromStore()
          }
        },
      },
    })
  }

  @Builder
  private ComicActionMenu(params: LibraryComicBuilderParams) {
    Menu() {
      if (this.canSelectComic(params.comic.id)) {
        MenuItem({ content: s('common_select') })
          .onClick(() => {
            this.enterSelectionMode(params.comic.id)
          })
      }
      if (this.canRemoveComic(params.comic.id)) {
        MenuItem({ content: s('library_action_remove_from_library') })
          .contentFontColor(ThemeConstants.DANGER)
          .onClick(() => {
            this.showRemoveConfirmation(params.comic)
          })
      }
    }
  }

  @Builder
  private SortMenu() {
    Menu() {
      LibrarySortMenuItems(this.sortBy, this.sortDirection, (sortBy: LibrarySortBy, direction: LibrarySortDirection): void => {
        this.setSortBy(sortBy, direction)
      }, this.filterCategory === 'all' ? undefined : (): void => {
        if (!this.followsDefaultSort) this.saveCategorySort(this.sortBy, this.sortDirection, true)
      }, this.followsDefaultSort)
    }
  }

  @Builder
  private SourceMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          select(() => { this.setSourceFilter('all') })
        })
      MenuItem({ content: s('library_source_local') })
        .onClick(() => {
          select(() => { this.setSourceFilter('local') })
        })
      MenuItem({ content: s('library_source_private') })
        .onClick(() => {
          select(() => { this.setSourceFilter('private') })
        })
      MenuItem({ content: s('route_komga_title') })
        .onClick(() => {
          select(() => { this.setSourceFilter('komga') })
        })
      MenuItem({ content: s('route_kavita_title') })
        .onClick(() => {
          select(() => { this.setSourceFilter('kavita') })
        })
      MenuItem({ content: s('route_opds_title') })
        .onClick(() => {
          select(() => { this.setSourceFilter('opds') })
        })
      MenuItem({ content: s('route_webdav_title') })
        .onClick(() => {
          select(() => { this.setSourceFilter('webdav') })
        })
      ForEach(this.privateServerFilterOptions(), (option: LibraryServerSourceFilterOption) => {
        MenuItem({ content: option.title })
          .onClick(() => {
            select(() => { this.setSourceFilter(option.filter) })
          })
      }, (option: LibraryServerSourceFilterOption) => option.filter)
      ForEach(this.runtimeSourceFilterOptions(), (option: LibraryServerSourceFilterOption) => {
        MenuItem({ content: option.title })
          .onClick(() => {
            select(() => { this.setSourceFilter(option.filter) })
          })
      }, (option: LibraryServerSourceFilterOption) => option.filter)
      MenuItem({ content: s('library_source_package') })
        .onClick(() => {
          select(() => { this.setSourceFilter('source_package') })
        })
    }
  }

  @Builder
  private ReadStateMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          select(() => { this.setReadStateFilter('all') })
        })
      MenuItem({ content: s('library_read_state_unread') })
        .onClick(() => {
          select(() => { this.setReadStateFilter('unread') })
        })
      MenuItem({ content: s('library_read_state_reading') })
        .onClick(() => {
          select(() => { this.setReadStateFilter('reading') })
        })
      MenuItem({ content: s('library_read_state_completed') })
        .onClick(() => {
          select(() => { this.setReadStateFilter('completed') })
        })
    }
  }

  @Builder
  private AvailabilityMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          select(() => { this.setAvailabilityFilter('all') })
        })
      MenuItem({ content: s('library_availability_downloaded') })
        .onClick(() => {
          select(() => { this.setAvailabilityFilter('downloaded') })
        })
      MenuItem({ content: s('library_availability_fully_downloaded') })
        .onClick(() => {
          select(() => { this.setAvailabilityFilter('fully_downloaded') })
        })
      MenuItem({ content: s('library_availability_partially_downloaded') })
        .onClick(() => {
          select(() => { this.setAvailabilityFilter('partially_downloaded') })
        })
      MenuItem({ content: s('library_availability_not_downloaded') })
        .onClick(() => {
          select(() => { this.setAvailabilityFilter('not_downloaded') })
        })
    }
  }

  @Builder
  private MetadataStatusMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('all') })
        })
      MenuItem({ content: s('manga_status_ongoing') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('ongoing') })
        })
      MenuItem({ content: s('manga_status_completed') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('completed') })
        })
      MenuItem({ content: s('manga_status_hiatus') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('hiatus') })
        })
      MenuItem({ content: s('manga_status_cancelled') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('cancelled') })
        })
      MenuItem({ content: s('manga_status_unknown') })
        .onClick(() => {
          select(() => { this.setMetadataStatusFilter('unknown') })
        })
    }
  }

  @Builder
  private CategoryMenu() {
    Menu() {
      MenuItemGroup() {
        this.CategoryMenuItem('all', s('common_all'))
        ForEach(this.libraryStore.listCustomCategories(), (category: CustomLibraryCategory) => {
          this.CategoryMenuItem(category.id, category.name)
        }, (category: CustomLibraryCategory) => category.id)
      }
      if (this.libraryStore.listSmartCategories().length > 0) {
        MenuItemGroup() {
          ForEach(this.libraryStore.listSmartCategories(), (category: LibrarySmartCategory) => {
            this.CategoryMenuItem(category.id, category.name)
          }, (category: LibrarySmartCategory) => category.id)
        }
      }
      MenuItemGroup() {
        MenuItem({ content: s('settings_row_library_categories_title'), startIcon: $r('sys.symbol.folder') })
          .onClick((): void => { this.onOpenCategoriesRequested() })
      }
    }
  }

  @Builder
  private CategoryMenuItem(categoryId: string, title: string) {
    MenuItem({ content: title })
      .selected(this.filterCategory === categoryId)
      .selectIcon(true)
      .onClick(() => { this.setCategoryFilter(categoryId) })
  }

  private titleMenuItems(key: string): LibraryTitleMenuItem[] {
    if (key === 'more') {
      // Moving the original layout entry must preserve its own choice menu.
      // HDS's automatic overflow is flat, so use the shared native MenuItem
      // submenu rather than promoting layout values to application actions.
      return [
        { label: s('settings_row_library_view_mode_title'), children: this.titleMenuItems('layout'), action: () => {} },
        { label: s('route_import_title'), action: () => { this.onImportRequested() } },
        { label: s('route_downloads_title'), action: () => { this.onOpenDownloadsRequested() } },
        { label: s('common_select'), isEnabled: this.hasVisibleLibraryContent(),
          action: () => { this.beginSelectionMode() } },
      ]
    }
    if (key === 'layout') {
      return [
        { label: s('library_view_mode_grid'), selected: this.viewMode === 'grid',
          action: () => { this.setViewMode('grid') } },
        { label: s('library_view_mode_list'), selected: this.viewMode === 'list',
          action: () => { this.setViewMode('list') } },
      ]
    }
    return []
  }


  @Builder
  private SortSelector() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(librarySortLabel(this.sortBy))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .flexShrink(1)
      Text(this.sortDirection === 'asc' ? '↑' : '↓')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .flexShrink(0)
        .accessibilityLevel('no')
    }
    .height(ThemeConstants.BUTTON_HEIGHT)
    .padding({ right: ThemeConstants.SPACE_SM })
    .backgroundColor(Color.Transparent)
    .alignItems(VerticalAlign.Center)
    .accessibilityText(librarySortSummary(this.sortBy, this.sortDirection))
  }

  @Builder
  private CategorySelector() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.categoryLabel())
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 'calc(100% - 20vp)' })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
    }
    .height(ThemeConstants.BUTTON_HEIGHT)
    .padding({ right: ThemeConstants.SPACE_SM })
    .accessibilityText(this.categoryLabel())
    .accessibilityDescription(s('library_category_switch'))
    .bindMenu(this.CategoryMenu(), komaMenuOptions({ placement: Placement.BottomLeft }))
  }

  @Builder
  private LibraryFiltersSheet() {
    KomaModalScaffold({
      title: s('common_filter'),
      onClose: () => {
        this.closeFilterSheet()
      },
    }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
          GroupedListSection({ inModal: true }) {
            ConciseListRow({
              title: s('library_filter_source_title'),
              trailingText: this.sourceLabel(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: (select: (action: () => void) => void) => {
                this.SourceMenu(select)
              },
            })
            ListDivider()
            ConciseListRow({
              title: s('library_filter_read_state_title'),
              trailingText: this.readStateLabel(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: (select: (action: () => void) => void) => {
                this.ReadStateMenu(select)
              },
            })
            ListDivider()
            ConciseListRow({
              title: s('library_filter_availability_title'),
              trailingText: this.availabilityLabel(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: (select: (action: () => void) => void) => {
                this.AvailabilityMenu(select)
              },
            })
            ListDivider()
            ConciseListRow({
              title: s('library_filter_metadata_title'),
              trailingText: this.metadataStatusLabel(),
              trailingDropdown: true,
              dropdownMenuEnabled: true,
              dropdownMenuBuilder: (select: (action: () => void) => void) => {
                this.MetadataStatusMenu(select)
              },
            })
          }

          if (this.hasActiveFilters()) {
            KomaActionButton({
              label: s('common_reset'),
              kind: 'ghost',
              compact: true,
              action: () => {
                this.resetFilters()
              },
            })
          }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    }
  }

  @Builder
  private SortFilterBar() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      // The spacer takes the available width. The menu anchors to the inner
      // button, whose bounds stop at the disclosure glyph.
      Row() {
        this.CategorySelector()
      }
      .layoutWeight(1)

      Row() {
        this.SortSelector()
      }
      .constraintSize({ maxWidth: '53%' })
      .bindMenu(this.SortMenu(), komaMenuOptions())

      Row() {
        KomaActionButton({
          label: this.filtersButtonLabel(),
          kind: 'ghost',
          compact: true,
          controlHeight: ThemeConstants.BUTTON_HEIGHT,
          accentColor: ThemeConstants.TEXT_PRIMARY,
          action: () => {
            this.filtersShown = true
          },
        })
      }
      .bindSheet($$this.filtersShown, this.LibraryFiltersSheet, komaSheetOptions({
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        onDisappear: () => {
          this.closeFilterSheet()
        },
      }))
    }
    .width('100%')
  }

  @Builder
  private LibraryViewControls() {
    this.SortFilterBar()
  }

  @Builder
  private EmptyLibrary() {
    KomaEmptyState({
      icon: $r('sys.symbol.book'),
      title: s('library_empty_title'),
      message: s('library_empty_message'),
      showAction: false,
    })
  }

  @Builder
  private LibraryProjectionLoading() {
    Row() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyFilteredLibrary() {
    KomaEmptyState({
      title: s('library_filtered_empty_title'),
      message: this.hasActiveFilters() ? s('library_filtered_empty_message') : s('library_category_read_state_empty'),
      actionLabel: s('common_reset'),
      showAction: this.hasActiveFilters(),
      action: () => {
        this.resetFilters()
      },
    })
  }

  @Builder
  private EmptyCategory() {
    KomaEmptyState({
      title: AppStrings.format('library_category_empty_shelf', this.categoryLabel()),
      showAction: false,
    })
  }


  @Builder
  private ComicSelectionCheckbox(params: LibraryCheckboxBuilderParams) {
    Stack({ alignContent: Alignment.Center }) {
      Checkbox({ name: params.comic.id })
        .select(this.isComicSelected(params.comic.id))
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .unselectedColor(ThemeConstants.TEXT_SECONDARY)
        .width(24)
        .height(24)
        .margin(0)
        .backgroundColor(ThemeConstants.CARD)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .responseRegion({ x: -6, y: -6, width: 36, height: 36 })
        .accessibilityText(params.comic.title)
        .onChange((selected: boolean) => {
          this.setComicSelected(params.comic.id, selected)
        })
    }
    .width(ThemeConstants.TOUCH_TARGET_SM)
    .height(ThemeConstants.TOUCH_TARGET_SM)
    .margin({ top: params.onCover ? ThemeConstants.SPACE_SM : 0, right: ThemeConstants.SPACE_SM })
  }

  @Builder
  private LibraryGridCell(params: LibraryComicBuilderParams) {
    Stack({ alignContent: Alignment.TopEnd }) {
      ComicCoverCard({
        comic: params.comic,
        title: params.comic.title,
        subtitle: params.comic.subtitle,
        coverColor: params.comic.coverColor,
        accentColor: params.comic.accentColor,
        categoryLabels: params.comic.categoryLabels ?? [],
        selected: this.isComicSelected(params.comic.id),
      })
        .onTouch((event: TouchEvent) => {
          this.handleComicTouch(params.comic.id, event)
        })
        .priorityGesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
            .onAction(() => {
              this.enterSelectionMode(params.comic.id)
            }),
          TapGesture()
            .onAction(() => {
              this.handleComicClick(params.comic.id)
            })
        ))

      if (this.selectionMode) {
        this.ComicSelectionCheckbox({ comic: params.comic, onCover: true })
      } else if (this.canRemoveComic(params.comic.id)) {
        KomaIconButton({
          icon: $r('sys.symbol.ellipsis_circle'),
          kind: 'secondary',
          controlSize: ThemeConstants.TOUCH_TARGET_SM,
          iconSize: ThemeConstants.FONT_SIZE_H3,
          action: () => {
            this.comicActionMenuKey = `grid:${params.comic.id}`
          },
        })
          .margin({ top: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          .bindMenu(this.comicActionMenuKey === `grid:${params.comic.id}`, this.ComicActionMenu({ comic: params.comic }), komaMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: () => {
              if (this.comicActionMenuKey === `grid:${params.comic.id}`) {
                this.comicActionMenuKey = ''
              }
            },
          }))
      }
    }
    .width('100%')
  }

  private libraryGridColumnsTemplate(): string {
    const columns: string[] = []
    for (let index = 0; index < this.libraryGridColumnCount(); index += 1) columns.push('1fr')
    return columns.join(' ')
  }

  private libraryGridLayoutOptions(): GridLayoutOptions {
    const headerCount = this.hasContinueReading() ? 3 : 2
    const irregularIndexes: number[] = []
    for (let index = 0; index < headerCount; index += 1) irregularIndexes.push(index)
    irregularIndexes.push(headerCount + this.gridProjection.comics.length)
    return { regularSize: [1, 1], irregularIndexes: irregularIndexes }
  }

  private libraryGridCellBottomPadding(comicId: ComicId): number {
    const index = this.gridProjection.indexById.get(comicId) ?? 0
    const count = this.libraryGridColumnCount()
    const lastRowStart = Math.floor((this.gridProjection.comics.length - 1) / count) * count
    return index >= lastRowStart ? ThemeConstants.SPACE_LG : this.libraryGridRowGap()
  }

  @Builder
  private LibraryContinueReadingCard(compactList: boolean = false) {
    ContinueReadingShelfCard({
      compactList: compactList,
      info: this.continueReading(),
      revision: this.displayedRevision,
      onOpenReader: (comicId: ComicId) => {
        if (!this.selectionMode) this.openComicFromLibrary(comicId)
      },
    })
  }

  @Builder
  private LibraryGrid() {
    // One scrolling owner and one keyed parent for every cover, including during rotation.
    Grid(this.libraryScroller, this.libraryGridLayoutOptions()) {
      GridItem() {
        Column() {
          Blank().height(this.layoutSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
        }.width('100%')
      }
      .padding({ bottom: ThemeConstants.SPACE_LG })
      .clip(false)

      if (this.hasContinueReading()) {
        GridItem() { this.LibraryContinueReadingCard() }
          .padding({ bottom: ThemeConstants.SPACE_LG })
          .clip(false)
      }

      GridItem() { this.LibraryViewControls() }
        .padding({ bottom: ThemeConstants.SPACE_LG })
        .clip(false)

      ForEach(this.gridProjection.comics, (comic: ComicCoverInfo) => {
        GridItem() {
          this.LibraryGridCell({ comic: this.currentGridComic(comic) })
        }
        .padding({ bottom: this.libraryGridCellBottomPadding(comic.id) })
        .clip(false)
      }, (comic: ComicCoverInfo) => this.comicRenderKey(comic))

      GridItem() {
        Column() {
          Blank().height(this.layoutSafeArea.bottomAvoidHeight + ThemeConstants.SPACE_XL +
            ThemeConstants.FLOATING_TAB_BAR_CLEARANCE + Math.max(0, this.layoutSafeArea.keyboardHeight))
        }.width('100%')
      }.clip(false)
    }
    // Retain all existing density rules, including the standard 480vp threshold.
    .columnsTemplate(this.libraryGridColumnsTemplate())
    .columnsGap(this.libraryGridColumnGap())
    .rowsGap(0)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: this.libraryHorizontalInset(), right: this.libraryHorizontalInset() })
    .clipContent(ContentClipMode.CONTENT_ONLY)
    .enableScrollInteraction(this.scrollEnabled)
    .edgeEffect(EdgeEffect.None)
    .onDidScroll((_offset: number, state: ScrollState) => {
      this.onRootScroll(this.libraryScroller.currentOffset().yOffset, state)
    })
  }

  private shouldShowCoverUri(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
    sourceMangaUrl?: string,
  ): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(
      cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl),
    ) < 0
  }

  private markCoverUriFailed(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
    sourceMangaUrl?: string,
  ): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl)
    if (normalized.length > 0 && this.failedCoverUris.indexOf(failureKey) < 0) {
      this.failedCoverUris = this.failedCoverUris.concat([failureKey])
    }
  }

  private sourceImageIdForComic(comic: ComicCoverInfo): string {
    return comic.sourceImageId ?? comic.id
  }

  @Builder
  private LibraryListCover(comic: ComicCoverInfo) {
    Badge(libraryUnreadBadgeOptions(comic.unreadChapterCount, comic.accentColor)) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.shouldShowCoverUri(
          comic.coverUri,
          comic.sourceRuntimeId,
          this.sourceImageIdForComic(comic),
          comic.sourceKind,
          comic.remoteServerId,
          comic.sourceMangaUrl,
        )) {
          CachedCoverImage({
            uri: comic.coverUri ?? '',
            objectFit: ImageFit.Cover,
            sourceRuntimeId: comic.sourceRuntimeId ?? '',
            sourceImageId: this.sourceImageIdForComic(comic),
            sourceKind: comic.sourceKind,
            remoteServerId: comic.remoteServerId ?? '',
            sourceMangaUrl: comic.sourceMangaUrl ?? '',
            onError: () => {
              this.markCoverUriFailed(
                comic.coverUri,
                comic.sourceRuntimeId,
                this.sourceImageIdForComic(comic),
                comic.sourceKind,
                comic.remoteServerId,
                comic.sourceMangaUrl,
              )
            },
          })
        } else {
          SymbolGlyph($r('sys.symbol.book'))
            .fontSize(ThemeConstants.FONT_SIZE_H2)
            .fontColor([ThemeConstants.TEXT_TERTIARY])
        }
      }
      .width(this.libraryListCoverWidth())
      .height(this.libraryListCoverHeight())
      .borderRadius(ThemeConstants.RADIUS_COVER)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
    }
  }

  @Builder
  private LibraryList() {
    Column({ space: this.libraryListSpace() }) {
      ForEach(this.gridProjection.comics, (comic: ComicCoverInfo) => {
        Row({ space: ThemeConstants.SPACE_SM }) {
          ConciseListRow({
            title: comic.title,
            subtitle: this.listRowSubtitle(comic),
            showChevron: false,
            prefixActsAsLeading: true,
            isEnabled: !this.selectionMode || this.canSelectComic(comic.id),
            action: () => {
              this.handleComicClick(comic.id)
            },
            prefixBuilderParam: () => {
              this.LibraryListCover(this.currentGridComic(comic))
            },
          })
            .layoutWeight(1)
            .onTouch((event: TouchEvent) => {
              this.handleComicTouch(comic.id, event)
            })
            .priorityGesture(GestureGroup(GestureMode.Exclusive,
              LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
                .onAction(() => {
                  this.enterSelectionMode(comic.id)
                }),
              TapGesture()
                .onAction(() => {
                  this.handleComicClick(comic.id)
                })
            ))

          if (this.selectionMode) {
            this.ComicSelectionCheckbox({ comic: comic, onCover: false })
          } else if (this.canRemoveComic(comic.id)) {
            KomaIconButton({
              icon: $r('sys.symbol.ellipsis_circle'),
              kind: 'secondary',
              controlSize: ThemeConstants.TOUCH_TARGET_SM,
              iconSize: ThemeConstants.FONT_SIZE_H3,
              action: () => {
                this.comicActionMenuKey = `list:${comic.id}`
              },
            })
              .margin({ right: ThemeConstants.SPACE_SM })
              .bindMenu(this.comicActionMenuKey === `list:${comic.id}`, this.ComicActionMenu({ comic: comic }), komaMenuOptions({
                placement: Placement.BottomRight,
                onDisappear: () => {
                  if (this.comicActionMenuKey === `list:${comic.id}`) {
                    this.comicActionMenuKey = ''
                  }
                },
              }))
          }
        }
        .width('100%')
        .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
        .backgroundColor(this.isComicSelected(comic.id) ? ThemeConstants.SOFT_TINT : ThemeConstants.CARD)
        .alignItems(VerticalAlign.Center)
      }, (comic: ComicCoverInfo) => this.listRowRenderKey(comic))
    }
    .width('100%')
  }

  private applyFilterPreferences(preferencesValue: LibraryFilterPreferences): void {
    this.defaultSort = preferencesValue
    this.viewMode = preferencesValue.viewMode
    this.listDensity = preferencesValue.listDensity
    this.showLibraryBadges = preferencesValue.showBadges
    this.filterSource = preferencesValue.source
    this.filterReadState = preferencesValue.readState
    this.filterCategory = preferencesValue.category
    this.filterAvailability = preferencesValue.availability
    this.filterMetadataStatus = preferencesValue.metadataStatus
    console.info(
      `[Library] step=filter_restored sortBy=${this.sortBy} viewMode=${this.viewMode} listDensity=${this.listDensity} showBadges=${this.showLibraryBadges} source=${this.filterSource} readState=${this.filterReadState} category=${this.filterCategory} availability=${this.filterAvailability} metadataStatus=${this.filterMetadataStatus}`
    )
  }

  private async recoverFilterPreferencesAfterSave(): Promise<void> {
    const revision = this.filterPreferencesMutationRevision
    const restoreEpoch = this.filterPreferencesRestoreEpoch
    try {
      const context = getContext(this) as common.UIAbilityContext
      const value = await new LibraryFilterStore(context).load()
      if (revision !== this.filterPreferencesMutationRevision || restoreEpoch !== this.filterPreferencesRestoreEpoch) return
      this.applyFilterPreferences(value)
      this.refreshDisplayedSnapshotFromStore()
    } catch (_error) {
      console.info('[Library] step=filter_restore_failed reason=filter_save_recovery')
    }
  }

  private restoreInitialFilterPreferences(): void {
    this.filterPreferencesRestoreEpoch += 1
    try {
      const context = getContext(this) as common.UIAbilityContext
      this.applyFilterPreferences(new LibraryFilterStore(context).loadSync())
    } catch (error) {
      void error
      // Keep the existing asynchronous recovery if the initial read fails.
      this.beginFilterPreferencesRestore()
    }
  }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const refreshSmart = (): void => { if (this.selectedSmartCategory() !== undefined) this.refreshDisplayedSnapshotFromStore() }
    this.smartSubscriptions = [OfflineDownloadRuntime.subscribe(context.filesDir, refreshSmart),
      new TrackerPreferencesStore(context).subscribeMappings(refreshSmart)]
    this.restoreInitialFilterPreferences()
    this.syncDisplayedSnapshotFromProps()
    this.publishTitleBar()
  }

  aboutToDisappear(): void {
    this.smartSubscriptions.forEach((unsubscribe: () => void): void => { unsubscribe() })
    this.smartSubscriptions = []
    this.closeTitleMenu()
  }

  onBackPress(): boolean {
    if (this.categoryEditorShown) {
      this.categoryEditorShown = false
      return true
    }
    if (this.selectionMode) {
      this.exitSelectionMode()
      return true
    }
    return false
  }

  @Builder
  private LibraryListSurface() {
      SecondaryListScaffold({
        scroller: this.libraryScroller,
        onDidScroll: this.onRootScroll,
        scrollEnabled: this.scrollEnabled,
        alwaysEnableEdgeSpring: false,
        listSpace: this.viewMode === 'list' ? ThemeConstants.SPACE_SM : ThemeConstants.SPACE_LG,
        horizontalPadding: this.viewMode === 'list' ? ThemeConstants.SPACE_MD : this.libraryHorizontalInset(),
        bottomPadding: ThemeConstants.SPACE_XL,
        floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
      }) {
        if (this.isProjectionPending()) {
          ListItem() {
            this.LibraryProjectionLoading()
          }
        } else if (this.hasLibraryContent()) {
          if (this.hasContinueReading()) {
            ListItem() {
              this.LibraryContinueReadingCard(this.viewMode === 'list')
            }
          }

          ListItem() {
            this.LibraryViewControls()
          }

          if (this.hasVisibleLibraryContent()) {
            ListItem() {
              this.LibraryList()
            }
          } else if (!this.hasCategoryContents && this.filterCategory !== 'all') {
            ListItem() {
              this.EmptyCategory()
            }
          } else {
            ListItem() {
              this.EmptyFilteredLibrary()
            }
          }
        } else {
          ListItem() {
            this.CategorySelector()
          }
          ListItem() {
            if (this.filterCategory === 'all') {
              this.EmptyLibrary()
            } else {
              this.EmptyCategory()
            }
          }
        }
      }
  }

  build() {
    Column() {
      PullRefresh({
        scroller: this.libraryScroller,
        indicatorTop: this.layoutSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2,
        onRefresh: async (): Promise<void> => { await this.onRefresh() },
        onScrollEnableChange: (enabled: boolean): void => { this.scrollEnabled = enabled },
      }) {
        if (this.viewMode !== 'list' && !this.isProjectionPending() &&
          this.hasLibraryContent() && this.hasVisibleLibraryContent()) {
          this.LibraryGrid()
        } else {
          this.LibraryListSurface()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .bindSheet($$this.categoryEditorShown, this.CategoryEditor, komaModalSheetOptions({
      height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false, enableOutsideInteractive: false, scrollSizeMode: ScrollSizeMode.CONTINUOUS,
    }))
    .onAreaChange((_old: Area, next: Area) => {
      this.containerWidth = next.width as number
    })
  }
}
