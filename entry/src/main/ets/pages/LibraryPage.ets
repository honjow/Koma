import { canMigrateLibraryComic } from '../model/SourceMangaMigration'
import { komaMenuOptions, komaSheetOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { libraryUnreadBadgeOptions } from '../components/LibraryUnreadBadge'
import { LibrarySortMenuItems, librarySortLabel, librarySortSummary } from '../components/LibrarySortMenu'
import { cachedLibraryChapterUpdateTimes } from '../model/LibraryChapterUpdates'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'
import { privateLibraryCategoryIds, showLibraryComic } from '../model/LibraryPrivacyVisibility'
import { connectLibraryPrivacyState, LibraryPrivacyAuthResult, LibraryPrivacyState, libraryPrivacyAuthMessage } from '../state/LibraryPrivacyState'
import { FrameCallback, SymbolGlyphModifier } from '@kit.ArkUI'
import { KomaMenuController, KomaMenuAction as LibraryTitleMenuItem, komaTitleMoreIcon } from '../components/ui/KomaMenuController'
import { COMIC_COVER_ASPECT_RATIO, ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { PullRefresh, PullRefreshController } from '../components/PullRefresh'
import { CachedCoverImage, cachedCoverFailureKey, coverDecodeEdgeForDisplay } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { RootNavigationState } from '../state/RootNavigationState'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaModalScaffold } from '../components/KomaModalScaffold'
import { LibraryCategoryChoice, LibraryCategoryPicker, libraryCategoryPickerSheetOptions } from '../components/LibraryCategoryPicker'
import { ThemeConstants } from '../theme/ThemeConstants'
import { gridFallbackContainerWidth } from '../utils/GridColumns'
import { libraryCoverGridColumnCount, libraryCoverGridGap } from '../utils/LibraryCoverLayout'
import { LibraryCoverGridAdjustment } from '../state/LibraryCoverGridAdjustment'
import { connectLibraryCoverLayout, LibraryCoverLayoutState } from '../state/LibraryCoverLayoutState'
import {
  ContinueReadingCardViewModel,
  LibraryComicPresentation,
  LibraryPresentationByComicId,
  createLibraryComicCard,
} from '../model/MockLibraryData'
import {
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
  compareShelfTime,
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
  ReadingPresentationChange,
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

interface LibraryCardCache {
  cards: Map<ComicId, LibraryCachedCard>
  categoryNames: Map<string, string>
}

interface LibraryCachedCard {
  comic: Comic
  card: ComicCoverInfo
}

interface LibraryCategoryProjection {
  sortBy: LibrarySortBy
  sortDirection: LibrarySortDirection
  libraryStore: LibraryStore
  libraryRevision: number
  readerSessionStore: ReaderSessionStore
  readerProgressRevision: number
  readingProgress: Map<ComicId, ReadingProgress>
  all: Comic[]
  categories: Map<string, Comic[]>
}

class LibraryGridFrame extends FrameCallback {
  private publish: () => void

  constructor(publish: () => void) {
    super()
    this.publish = publish
  }

  onFrame(_timestamp: number): void { this.publish() }
  onIdle(_timeLeft: number): void {}
}

@ObservedV2
class LibraryGridRows implements IDataSource {
  @Trace private firstRow: Comic[] = []
  @Trace private secondRow: Comic[] = []
  @Trace private rows: Comic[] = []
  @Trace private secondRowPending: boolean = false
  private snapshot: Comic[] | undefined = undefined
  private listeners: DataChangeListener[] = []

  totalCount(): number { return this.firstRow.length + this.secondRow.length + this.rows.length }
  getData(index: number): number { return index }
  comicAt(index: number): Comic | undefined {
    if (index < this.firstRow.length) return this.firstRow[index]
    const remainingIndex = index - this.firstRow.length
    if (remainingIndex < this.secondRow.length) return this.secondRow[remainingIndex]
    return this.rows[remainingIndex - this.secondRow.length]
  }

  isPublished(index: number): boolean {
    return !this.secondRowPending || index < this.firstRow.length
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener)
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((value: DataChangeListener): boolean => value !== listener)
  }

  update(comics: Comic[]): void {
    if (this.snapshot === comics) return
    const previousCount = this.totalCount()
    // Key enumeration reads only the positions. The instantiated card nodes
    // subscribe to the new array. No observable row is created for each key.
    this.snapshot = comics
    if (this.firstRow.length > 0) this.firstRow = comics.slice(0, this.firstRow.length)
    if (this.secondRow.length > 0) {
      this.secondRow = comics.slice(this.firstRow.length, this.firstRow.length + this.secondRow.length)
    }
    this.rows = comics.slice(this.firstRow.length + this.secondRow.length)
    this.secondRowPending = false
    this.notifyCountChange(previousCount)
  }

  startCategory(comics: Comic[], columns: number): void {
    const previousCount = this.totalCount()
    // Keep the already mounted second row out of sight while its new data
    // waits for the next frame. Deleting it here would destroy those cards.
    const retainedSecondRow: Comic[] = []
    const end = Math.min(columns * 2, previousCount, comics.length)
    for (let index = columns; index < end; index++) {
      const comic = this.comicAt(index)
      if (comic !== undefined) retainedSecondRow.push(comic)
    }
    this.snapshot = undefined
    this.firstRow = comics.slice(0, columns)
    this.secondRow = retainedSecondRow
    this.rows = []
    this.secondRowPending = retainedSecondRow.length > 0
    this.notifyCountChange(previousCount)
  }

  publishSecondRow(comics: Comic[], columns: number): void {
    const previousCount = this.totalCount()
    this.secondRow = comics.slice(columns, columns * 2)
    this.secondRowPending = false
    this.notifyCountChange(previousCount)
  }

  finishCategory(comics: Comic[], columns: number): void {
    const previousCount = this.totalCount()
    this.snapshot = comics
    this.rows = comics.slice(columns * 2)
    this.notifyCountChange(previousCount)
  }

  private notifyCountChange(previousCount: number): void {
    const count = this.totalCount()
    if (count === previousCount) return
    // Positional keys are stable. A staged size change only adds or removes
    // the tail; the observed row data refreshes the slots that stay mounted.
    const operation: DataOperation = count > previousCount
      ? { type: DataOperationType.ADD, index: previousCount, count: count - previousCount }
      : { type: DataOperationType.DELETE, index: count, count: previousCount - count }
    this.listeners.forEach((listener: DataChangeListener): void => { listener.onDatasetChange([operation]) })
  }
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

const CONTINUE_READING_COVER_HEIGHT = 102

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
            coverOwnerId: this.info.comicId,
            objectFit: ImageFit.Cover,
            sourceRuntimeId: this.info.sourceRuntimeId ?? '',
            sourceImageId: this.info.sourceImageId ?? this.info.comicId,
            sourceKind: this.info.sourceKind,
            remoteServerId: this.info.remoteServerId ?? '',
            sourceMangaUrl: this.info.sourceMangaUrl ?? '',
            decodeMaxEdge: coverDecodeEdgeForDisplay(CONTINUE_READING_COVER_HEIGHT, 256),
            onError: () => {
              this.failedCoverUri = this.coverFailureKey()
            },
          })
        }
      }
      .width(76)
      .height(CONTINUE_READING_COVER_HEIGHT)
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
  @Param libraryRevision: number = 0
  @Param libraryPreferencesRevision: number = 0
  @Param readerSessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param readerProgressRevision: number = 0
  @Param readingPresentationChange?: ReadingPresentationChange = undefined
  @Param shelfReadingProgress: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
  @Param continueReadingCard: ContinueReadingCardViewModel = { title: '', detail: '', progress: 0, color: '', comicId: '' }
  @Param scopedContinueReadingCard: ContinueReadingCardViewModel | undefined = undefined
  @Param active: boolean = true
  @Param rootNavigation: RootNavigationState = new RootNavigationState()
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private displayedComics: Comic[] = []
  @Local private displayedRevision: number = 0
  private gridRows: LibraryGridRows = new LibraryGridRows()
  private pendingGridCategory: Comic[] | undefined = undefined
  @Local private privacy: LibraryPrivacyState = connectLibraryPrivacyState()
  private categoryRequest: number = 0
  private gridUpdateGeneration: number = 0
  private shelfCategoryProjection?: LibraryCategoryProjection
  private displayedLibraryStore?: LibraryStore
  private displayedLibraryRevision: number = -1
  private displayedProgressRevision: number = -1
  private displayedReadingProgress?: Map<ComicId, ReadingProgress>
  private displayedSessionStore?: ReaderSessionStore
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
  @Local private showContinueReadingCard: boolean = true
  @Local private filterSource: LibrarySourceFilter = 'all'
  @Local private filterReadState: LibraryReadStateFilter = 'all'
  @Local private filterCategory: LibraryCategoryFilter = 'all'
  private smartSubscriptions: (() => void)[] = []
  @Local private filterAvailability: LibraryAvailabilityFilter = 'all'
  @Local private filterMetadataStatus: LibraryMetadataStatusFilter = 'all'
  @Local private containerWidth: number = gridFallbackContainerWidth()
  @Local private coverLayout: LibraryCoverLayoutState = connectLibraryCoverLayout()
  @Local private gridAdjustment: LibraryCoverGridAdjustment = new LibraryCoverGridAdjustment()
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
  @Event onContinueReading: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  @Event onProgressStoreReloadRequested: () => void = () => {}
  @Event onReadingStateChanged: (comicIds: string[]) => void = () => {}
  @Event onRefresh: () => Promise<void> = async () => {}
  @Local private scrollEnabled: boolean = true
  @Local private pullRefreshController: PullRefreshController = new PullRefreshController()
  @Local private coverGridScrolling: boolean = false
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

  @Monitor('displayedRevision')
  private updateSelectionTitleBar(): void {
    if (this.selectionMode) this.publishTitleBar()
  }

  @Monitor('selectionMode', 'selectedIds', 'viewMode', 'batchDownloadBusy', 'languageState.effectiveLocale')
  private publishTitleBar(): void {
    const items: Record<string, Object>[] = this.selectionMode ? [
      this.titleMenuItem(s('library_action_select_all'), $r('sys.symbol.checkmark_square'),
        () => { this.selectAllVisibleComics() }, this.hasVisibleLibraryContent),
      this.titleMenuItem(s('library_action_categories'), $r('sys.symbol.folder'),
        () => { this.openCategoryEditor() }, this.selectedCount() > 0, 'library-title-categories'),
      this.titleMenuItem(s('migration_title'), $r('sys.symbol.arrow_right'), () => {
        const ids = Array.from(this.selectedIds)
        this.exitSelectionMode()
        this.onMigrationRequested(ids)
      }, this.selectedCount() > 0 && Array.from(this.selectedIds).every((id: string): boolean =>
        canMigrateLibraryComic(this.libraryStore.getComicSummary(id)))),
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

  // Mihon links publish shelf and progress together. Project that committed
  // state once when the shelf is visible, including when returning to it.
  @Monitor('libraryStore', 'libraryRevision', 'readerSessionStore', 'readerProgressRevision', 'shelfReadingProgress',
    'active', 'rootNavigation.visible')
  private syncDisplayedSnapshotFromProps(): void {
    if (!this.active || !this.rootNavigation.visible) return
    const sameShelf = this.displayedLibraryStore === this.libraryStore && this.displayedLibraryRevision === this.libraryRevision &&
      this.displayedSessionStore === this.readerSessionStore
    if (sameShelf && !this.usesLiveShelfFiltersOrSort()) {
      if (this.displayedProgressRevision === this.readerProgressRevision &&
        this.displayedReadingProgress === this.shelfReadingProgress) return
      if (this.applyWorkReadingChange()) return
    }
    this.refreshDisplayedSnapshotFromStore()
  }

  /** Progress alone changes neither category membership nor static filters. */
  private applyWorkReadingChange(): boolean {
    const change = this.readingPresentationChange
    if (change?.revision !== this.readerProgressRevision || this.displayedProgressRevision + 1 !== change.revision ||
      change.comicIds.length !== 1 || this.filterReadState !== 'all' || this.sortBy === 'unreadCount' ||
      this.selectedSmartCategory()?.filters.some(filter => filter.method === 'hasUnread' || filter.method === 'started') === true) {
      return false
    }
    const id = change.comicIds[0]
    const summary = this.libraryStore.getComicSummary(id)
    if (summary !== undefined) this.prepareShelfReadingFacts([summary])
    const positions = this.shelfReadingProgress
    const updatedAt = positions.get(id)?.updatedAt
    if (this.sortBy === 'lastRead' && this.displayedReadingProgress?.get(id)?.updatedAt !== updatedAt) {
      const index = this.displayedComics.findIndex((comic: Comic): boolean => comic.id === id)
      if (index >= 0) {
        const work = this.displayedComics[index]
        const next = this.displayedComics.slice()
        next.splice(index, 1)
        let lower = 0
        let upper = next.length
        while (lower < upper) {
          const mid = Math.floor((lower + upper) / 2)
          const other = next[mid]
          const order = compareShelfTime(updatedAt, positions.get(other.id)?.updatedAt, this.sortDirection) ||
            (other.createdAt - work.createdAt) || work.sortTitle.localeCompare(other.sortTitle)
          if (order === 0) return false
          if (order < 0) upper = mid
          else lower = mid + 1
        }
        if (lower !== index) {
          next.splice(lower, 0, work)
          this.displayedComics = next
          this.displayedRevision += 1
        }
      }
    }
    this.displayedProgressRevision = this.readerProgressRevision
    this.displayedReadingProgress = positions
    return true
  }

  private usesLiveShelfFiltersOrSort(): boolean {
    // Downloads, tracking mappings and source identities can change while
    // another page is open without advancing the shelf or progress revisions.
    return this.filterAvailability !== 'all' || this.sortBy === 'source' || this.sortBy === 'lastUpdate' ||
      (this.filterCategory !== 'all' && (this.selectedSmartCategory()?.filters.some(filter =>
        filter.method === 'downloaded' || filter.method === 'tracking') ?? false))
  }

  @Monitor('remoteProgress.syncRevision')
  private onRemoteProgressSyncRevChanged(): void {
    void this.remoteProgress.syncRevision
    this.onProgressStoreReloadRequested()
  }

  @Monitor('libraryPreferencesRevision')
  private onLibraryPreferencesChanged(): void {
    this.beginFilterPreferencesRestore()
  }

  @Computed
  private get privateCategoryIds(): Set<string> {
    void this.libraryRevision
    return privateLibraryCategoryIds(this.libraryStore.listCustomCategories())
  }

  @Monitor('privacy.unlocked', 'privacy.categoryId')
  private refreshPrivacyProjection(): void {
    if (!this.privacy.unlocked && this.privateCategoryIds.has(this.filterCategory)) {
      this.categoryEditorShown = false
      this.exitSelectionMode()
    }
    this.refreshDisplayedSnapshotFromStore()
  }

  @Monitor('privacy.presenting')
  private refreshResumedPrivacyProjection(): void {
    if (this.privacy.visibleCategoryId === this.filterCategory) this.refreshDisplayedSnapshotFromStore()
  }

  private refreshDisplayedSnapshotFromStore(): void {
    const category = this.validCategoryFilter()
    const strategy = this.libraryStore.getCategoryDisplayStrategy(this.filterCategory)
    this.applyCategorySort(strategy)
    const scoped = this.libraryStore.listShelfSummaries(category)
    this.prepareShelfReadingFacts(scoped)
    const nextComics = this.orderedCategoryComics(category)
    const privateIds = this.privateCategoryIds
    const visibleScope = this.privacy.visibleCategoryId === category ? category : ''
    const visibleComics = privateIds.size === 0 ? nextComics :
      nextComics.filter((comic: Comic): boolean => showLibraryComic(comic, privateIds, visibleScope))
    const categoryComics = this.filterSmartCategoryComics(visibleComics)
    this.hasCategoryContents = categoryComics.length > 0
    const sourceKinds = this.sourceKindsForFilter()
    const scopedComics = sourceKinds === undefined && this.filterReadState === 'all' ? categoryComics :
      categoryComics.filter((comic: Comic): boolean => {
      if (sourceKinds !== undefined && !sourceKinds.includes(comic.sourceKind)) return false
      return this.filterReadState === 'all' || this.readerSessionStore.comicReadingState(comic) === this.filterReadState
    })
    this.displayedComics = this.filterMetadataStatusComics(
      this.filterAvailabilityComics(this.filterPreciseSourceComics(scopedComics)))
    this.displayedLibraryStore = this.libraryStore
    this.displayedLibraryRevision = this.libraryRevision
    this.displayedProgressRevision = this.readerProgressRevision
    this.displayedReadingProgress = this.shelfReadingProgress
    this.displayedSessionStore = this.readerSessionStore
    this.displayedRevision += 1
    this.removeMissingSelectedComics()
  }

  private prepareShelfReadingFacts(comics: Comic[]): void {
    if (this.readerSessionStore.prepareShelfReadingFacts(comics)) return
    // Incognito and a failed projection read use the active work's actual state.
    for (const comic of comics) {
      if (comic.chapterCatalogDeferred !== true) continue
      this.libraryStore.getComic(comic.id)
      this.readerSessionStore.prepareWorkChapterStates(comic.id)
    }
  }

  private orderedShelfComics(category: LibraryCategoryFilter): Comic[] {
    const items = this.libraryStore.listLibraryItems(this.shelfReadingProgress, this.currentListOptions(category))
    const comics: Comic[] = []
    items.forEach((item: LibraryItem) => {
      const comic = this.libraryStore.getComicSummary(item.comicId)
      if (comic !== undefined) comics.push(comic)
    })
    return comics
  }

  private orderedCategoryComics(category: LibraryCategoryFilter): Comic[] {
    // Live source names and chapter-update times need to be read on each refresh.
    if (this.sortBy === 'source' || this.sortBy === 'lastUpdate' || this.sortBy === 'unreadCount' ||
      this.sortBy === 'latestChapter') return this.orderedShelfComics(category)

    const cached = this.shelfCategoryProjection
    const readingProgress = this.shelfReadingProgress
    // Categories with the same sort take a subsequence of one ordered shelf.
    // Menu actions publish synchronously, before ArkUI would refresh a @Computed cache.
    if (cached !== undefined && cached.sortBy === this.sortBy && cached.sortDirection === this.sortDirection &&
      cached.libraryStore === this.libraryStore && cached.libraryRevision === this.libraryRevision &&
      cached.readerSessionStore === this.readerSessionStore && cached.readerProgressRevision === this.readerProgressRevision &&
      cached.readingProgress === readingProgress) {
      return category === 'all' ? cached.all : cached.categories.get(category) ?? []
    }

    if (category !== 'all') return this.orderedShelfComics(category)
    const all = this.orderedShelfComics('all')
    const categories = new Map<string, Comic[]>()
    all.forEach((comic: Comic): void => {
      normalizeCategoryIds(comic.categoryIds).forEach((id: string): void => {
        const members = categories.get(id)
        if (members === undefined) categories.set(id, [comic])
        else members.push(comic)
      })
    })
    this.shelfCategoryProjection = {
      sortBy: this.sortBy,
      sortDirection: this.sortDirection,
      libraryStore: this.libraryStore,
      libraryRevision: this.libraryRevision,
      readerSessionStore: this.readerSessionStore,
      readerProgressRevision: this.readerProgressRevision,
      readingProgress,
      all,
      categories,
    }
    return category === 'all' ? all : categories.get(category) ?? []
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
        const chapterEntries = entriesByComicId.get(comic.id)
        if (chapterEntries === undefined) return
        const chapterIds = new Set<string>(this.libraryStore.listComicChapterIds(comic.id)
          .filter((id: string): boolean => id.trim().length > 0))
        if (chapterIds.size === 0) {
          return
        }
        const downloadedChapterIds = new Set<string>()
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
    if (this.privateCategoryIds.has(this.filterCategory) && this.privacy.categoryId !== this.filterCategory) {
      this.filterCategory = 'all'
      return 'all'
    }
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
          if (this.applyFilterPreferences(value)) this.refreshDisplayedSnapshotFromStore()
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

  private async setCategoryFilter(category: LibraryCategoryFilter): Promise<void> {
    const request = ++this.categoryRequest
    const isPrivate = this.privateCategoryIds.has(category)
    if (isPrivate) {
      const result = await this.privacy.openCategory(this.getUIContext().getHostContext() as common.UIAbilityContext, category,
        (): boolean => request === this.categoryRequest && this.active && this.rootNavigation.visible &&
          this.privateCategoryIds.has(category))
      if (request !== this.categoryRequest || result !== LibraryPrivacyAuthResult.SUCCESS) {
        const message = libraryPrivacyAuthMessage(result)
        if (request === this.categoryRequest && message.length > 0) this.showToast(message)
        return
      }
    } else {
      this.privacy.leaveCategory()
    }
    if (this.filterCategory === category) {
      return
    }
    this.markFilterPreferencesMutation()
    this.coverGridScrolling = false
    this.filterCategory = category
    this.refreshDisplayedSnapshotFromStore()
    if (this.viewMode !== 'list' && this.displayedComics.length > this.libraryGridColumnCount()) {
      this.pendingGridCategory = this.displayedComics
    }
    if (!isPrivate) this.saveFilterPreferences({ category })
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

  private listRowSubtitle(comic: ComicCoverInfo): string {
    if (comic.categoryLabels !== undefined && comic.categoryLabels.length > 0) {
      return [comic.subtitle].concat(comic.categoryLabels).filter((label: string): boolean => label !== '').join(' · ')
    }
    return comic.subtitle
  }

  @Computed
  private get libraryCardCache(): LibraryCardCache {
    void this.libraryRevision
    void this.languageState.effectiveLocale
    void this.presentationByComicId
    const categoryNames = new Map<string, string>()
    if (this.showLibraryBadges) {
      this.libraryStore.listCustomCategories().forEach((category: CustomLibraryCategory): void => {
        categoryNames.set(category.id, category.name)
      })
    }
    return { cards: new Map<ComicId, LibraryCachedCard>(), categoryNames }
  }

  private cardForComic(fallback: Comic): ComicCoverInfo {
    // A retained row can be drawn before the shelf reprojects. Resolve its
    // current record first so a redraw cannot cache old metadata for its ID.
    const comic = this.libraryStore.getComicSummary(fallback.id) ?? fallback
    const cache = this.libraryCardCache
    const existing = cache.cards.get(comic.id)
    if (existing?.comic === comic) return existing.card
    const labels: string[] = []
    if (cache.categoryNames.size > 0) {
      normalizeCategoryIds(comic.categoryIds).forEach((id: string): void => {
        const name = cache.categoryNames.get(id)
        if (name !== undefined) labels.push(name)
      })
    }
    const row = createLibraryComicCard(comic, this.presentationByComicId.get(comic.id), labels)
    cache.cards.set(comic.id, { comic, card: row })
    return row
  }

  @Computed
  private get displayedCards(): ComicCoverInfo[] {
    void this.displayedRevision
    void this.libraryRevision
    return this.displayedComics.map((comic: Comic): ComicCoverInfo => this.cardForComic(comic))
  }

  private gridCardForComic(comic: Comic): ComicCoverInfo {
    // Lazy grid cells project the current record when the UI actually needs
    // it. A retained cell after a shelf edit still resolves by comic ID.
    void this.libraryRevision
    return this.cardForComic(comic)
  }

  private publishedGridComicId(index: number): ComicId | undefined {
    return this.gridRows.isPublished(index) ? this.gridRows.comicAt(index)?.id : undefined
  }

  private retainGridComic(index: number, comic: Comic): () => Comic {
    return (): Comic => {
      // A lazy slot can still receive a redraw or menu dismissal after the
      // data source drops its index. Keep its last bound work through teardown.
      comic = this.gridRows.comicAt(index) ?? comic
      return comic
    }
  }

  @Monitor('displayedRevision', 'viewMode')
  private updateGridRows(): void {
    const generation = ++this.gridUpdateGeneration
    const comics = this.displayedComics
    const publishInBatches = this.pendingGridCategory === comics
    this.pendingGridCategory = undefined
    if (this.viewMode === 'list') return
    if (!publishInBatches) {
      this.gridRows.update(comics)
      return
    }

    // Each pass attaches only the next row of the new category. Earlier slots
    // keep their content and keys, including when the lazy tail is attached.
    const columns = this.libraryGridColumnCount()
    const ui = this.getUIContext()
    this.gridRows.startCategory(comics, columns)
    const isCurrent = (): boolean => this.gridUpdateGeneration === generation && this.displayedComics === comics
    const addSecondRow = (): void => {
      if (!isCurrent()) return
      this.gridRows.publishSecondRow(comics, columns)
      if (comics.length <= columns * 2) {
        this.gridRows.finishCategory(comics, columns)
        return
      }
      ui.postFrameCallback(new LibraryGridFrame((): void => {
        if (isCurrent()) this.gridRows.finishCategory(comics, columns)
      }))
    }
    // A callback posted from a tap can run before that tap's first layout.
    // Queue the next row from that frame so the first row can paint alone.
    ui.postFrameCallback(new LibraryGridFrame((): void => {
      if (isCurrent()) ui.postFrameCallback(new LibraryGridFrame(addSecondRow))
    }))
  }

  private unreadForCover(comicId: ComicId): number | undefined {
    void this.readerProgressRevision
    const comic = this.libraryStore.getComicSummary(comicId)
    return comic === undefined ? undefined : this.readerSessionStore.unreadChapterCount(comic)
  }

  private libraryViewportWidth(): number {
    return this.layoutSafeArea.windowWidthVp > 0 ? this.layoutSafeArea.windowWidthVp : this.containerWidth
  }

  private libraryGridColumnCount(): number {
    const measured = this.libraryViewportWidth() > 0
      ? this.libraryViewportWidth()
      : gridFallbackContainerWidth()
    return libraryCoverGridColumnCount(measured, this.listDensity,
      this.gridAdjustment.width(this.coverLayout.gridColumnWidth))
  }

  private libraryGridCoverDecodeEdge(): number {
    const columns = this.libraryGridColumnCount()
    const gap = this.libraryGridColumnGap()
    const available = this.libraryViewportWidth() - 2 * this.libraryHorizontalInset() - (columns - 1) * gap
    return coverDecodeEdgeForDisplay(available / columns / COMIC_COVER_ASPECT_RATIO)
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

  private privateServerFilterOptions(): LibraryServerSourceFilterOption[] {
    const seenFilters: string[] = []
    const options: LibraryServerSourceFilterOption[] = []
    this.libraryStore.listComicSummaries().forEach((comic: Comic) => {
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
    this.libraryStore.listComicSummaries().forEach((comic: Comic) => {
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

  // Keep the scroll surface subscribed to emptiness, separate from the
  // category contents that update the virtual rows inside it.
  @Computed
  private get hasLibraryContent(): boolean {
    return this.displayedRevision >= 0 && this.libraryStore.hasComics()
  }

  @Computed
  private get hasVisibleLibraryContent(): boolean {
    return this.displayedRevision >= 0 && this.displayedComics.length > 0
  }

  private canRemoveComic(comicId: ComicId): boolean {
    // A category change doesn't change which actions a comic supports.
    void this.libraryRevision
    return isRemovableLocalComic(this.libraryStore.getComicSummary(comicId))
  }

  private canSelectComic(comicId: ComicId): boolean {
    const comic = this.libraryStore.getComicSummary(comicId)
    return this.displayedRevision >= 0 && comic !== undefined &&
      showLibraryComic(comic, this.privateCategoryIds, this.privacy.visibleCategoryId)
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
    if (this.libraryStore.getComicSummary(comicId) === undefined) {
      this.showToast(s('common_unavailable'))
      return
    }
    this.onOpenMangaDetail(comicId)
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
    this.displayedComics.forEach((comic: Comic) => {
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
      isRemovableShelfComic(this.libraryStore.getComicSummary(comicId)))
  }

  private async verifyShelfRemoval(ids: ComicId[]): Promise<boolean> {
    if (ids.every((id: ComicId): boolean => showLibraryComic(this.libraryStore.getComicSummary(id), this.privateCategoryIds))) return true
    const result = await this.privacy.verify(this.getUIContext().getHostContext() as common.UIAbilityContext)
    const message = libraryPrivacyAuthMessage(result)
    if (message.length > 0) this.showToast(message)
    return result === LibraryPrivacyAuthResult.SUCCESS && this.active && this.rootNavigation.visible &&
      ids.every((id: ComicId): boolean => this.canSelectComic(id))
  }

  private async removeSelectedComics(): Promise<void> {
    const comicIds = this.selectedRemovableIds()
    if (comicIds.length === 0) {
      return
    }
    if (!await this.verifyShelfRemoval(comicIds)) return
    console.info(`[Library] step=batch_remove count=${comicIds.length}`)
    const removedCount = this.onRemoveComicsRequested(comicIds)
    this.exitSelectionMode()
    if (removedCount > 0) {
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private openCategoryEditor(): void {
    const comics = Array.from(this.selectedIds)
      .map((id: ComicId): Comic | undefined => this.libraryStore.getComicSummary(id))
      .filter((comic: Comic | undefined): boolean => comic !== undefined) as Comic[]
    if (comics.length === 0) return
    this.categoryEditComicIds = comics.map((comic: Comic): ComicId => comic.id)
    this.categoryChoices = this.libraryStore.listCustomCategories().map((category: CustomLibraryCategory): LibraryCategoryChoice => {
      const count = comics.filter((comic: Comic): boolean => normalizeCategoryIds(comic.categoryIds).includes(category.id)).length
      return { id: category.id, name: category.name, initial: count === 0 ? 'none' : count === comics.length ? 'all' : 'mixed' }
    })
    this.categoryEditorShown = true
  }

  private async saveCategoryEditor(added: string[], removed: string[]): Promise<void> {
    const selected = this.categoryEditComicIds
    if (removed.some((id: string): boolean => this.privateCategoryIds.has(id))) {
      const result = await this.privacy.verify(this.getUIContext().getHostContext() as common.UIAbilityContext)
      const message = libraryPrivacyAuthMessage(result)
      if (message.length > 0) this.showToast(message)
      if (result !== LibraryPrivacyAuthResult.SUCCESS || !this.categoryEditorShown || selected !== this.categoryEditComicIds) return
    }
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
    LibraryCategoryPicker({
      title: s('library_action_categories'),
      confirmLabel: s('common_save'),
      choices: this.categoryChoices,
      onConfirm: (added: string[], removed: string[]): void => { void this.saveCategoryEditor(added, removed) },
      onClose: (): void => { this.categoryEditorShown = false },
      onManageCategories: (): void => {
        this.categoryEditorShown = false
        this.onOpenCategoriesRequested()
      },
    })
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
    for (const comicId of comicIds) {
      for (const chapterId of this.libraryStore.listComicChapterIds(comicId)) {
        mutations.push({ comicId, chapterId, isRead })
      }
    }
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
    if (changedCount > 0) {
      this.onReadingStateChanged(Array.from(new Set(mutations.map((row: ChapterReadMutation): string => row.comicId))))
      console.info(`[Library] step=batch_read_state isRead=${isRead} comics=${comicIds.length} chapters=${changedCount}`)
      this.showToast(isRead ? s('library_batch_marked_read') : s('library_batch_marked_unread'))
      this.exitSelectionMode()
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
          void this.removeSelectedComics()
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
          void this.verifyShelfRemoval([comic.id]).then((confirmed: boolean): void => {
            if (confirmed && this.onRemoveComicRequested(comic.id)) this.refreshDisplayedSnapshotFromStore()
          })
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
          this.CategoryMenuItem(category.id, category.name, category.isPrivate === true)
        }, (category: CustomLibraryCategory) => category.id + ':' + category.name + ':' +
          (category.isPrivate === true ? 'private' : 'public'))
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
  private CategoryMenuItem(categoryId: string, title: string, isPrivate: boolean = false) {
    MenuItem({ content: title,
      symbolStartIcon: isPrivate ? new SymbolGlyphModifier($r('sys.symbol.lock')) : undefined })
      .selected(this.filterCategory === categoryId)
      .selectIcon(true)
      .onClick(() => { void this.setCategoryFilter(categoryId) })
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
        { label: s('common_select'), isEnabled: this.hasVisibleLibraryContent,
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
  private CategorySelector() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.categoryLabel())
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 'calc(100% - 20vp)' })
      if (this.privateCategoryIds.has(this.filterCategory)) {
        SymbolGlyph($r('sys.symbol.lock'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor([ThemeConstants.TEXT_TERTIARY])
      }
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
    Row({ space: ThemeConstants.SPACE_XS }) {
      // The spacer takes the available width. The menu anchors to the inner
      // button, whose bounds stop at the disclosure glyph.
      Row() {
        this.CategorySelector()
      }
      .layoutWeight(1)

      // Use the same button component and insets for both pressed surfaces.
      KomaActionButton({
        label: librarySortLabel(this.sortBy),
        trailingContent: this.sortDirection === 'asc' ? '↑' : '↓',
        accessibilityLabel: librarySortSummary(this.sortBy, this.sortDirection),
        kind: 'ghost',
        horizontalPadding: ThemeConstants.SPACE_SM,
        maxWidth: '53%',
        accentColor: ThemeConstants.TEXT_PRIMARY,
        menuBuilder: () => { this.SortMenu() },
      })

      Row() {
        KomaActionButton({
          label: this.filtersButtonLabel(),
          // Keep the active count with the label so the funnel always comes last.
          trailingContent: $r('sys.symbol.funnel'),
          kind: 'ghost',
          horizontalPadding: ThemeConstants.SPACE_SM,
          accentColor: this.hasActiveFilters() ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_PRIMARY,
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
  private LibraryGridCell(index: number, readComic: () => Comic) {
    Stack({ alignContent: Alignment.TopEnd }) {
      ComicCoverCard({
        comic: this.gridCardForComic(readComic()),
        unreadBadgeCount: this.unreadForCover(readComic().id),
        selected: this.isComicSelected(readComic().id),
        reuseAcrossWorks: true,
        coverDecodeMaxEdge: this.libraryGridCoverDecodeEdge(),
      })
        .onTouch((event: TouchEvent) => {
          const comicId = this.publishedGridComicId(index)
          if (comicId !== undefined) this.handleComicTouch(comicId, event)
        })
        .priorityGesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
            .onAction(() => {
              const comicId = this.publishedGridComicId(index)
              if (comicId !== undefined) this.enterSelectionMode(comicId)
            }),
          TapGesture()
            .onAction(() => {
              const comicId = this.publishedGridComicId(index)
              if (comicId !== undefined) this.handleComicClick(comicId)
            })
        ))

      if (this.selectionMode) {
        this.ComicSelectionCheckbox({ comic: this.gridCardForComic(readComic()), onCover: true })
      } else if (this.canRemoveComic(readComic().id)) {
        KomaIconButton({
          icon: $r('sys.symbol.ellipsis_circle'),
          kind: 'secondary',
          controlSize: ThemeConstants.TOUCH_TARGET_SM,
          iconSize: ThemeConstants.FONT_SIZE_H3,
          action: () => {
            const comicId = this.publishedGridComicId(index)
            if (comicId !== undefined) this.comicActionMenuKey = `grid:${comicId}`
          },
        })
          .margin({ top: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          .bindMenu(this.comicActionMenuKey === `grid:${readComic().id}`,
            this.ComicActionMenu({ comic: this.gridCardForComic(readComic()) }), komaMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: () => {
              if (this.comicActionMenuKey === `grid:${readComic().id}`) {
                this.comicActionMenuKey = ''
              }
            },
          }))
      }
    }
    .width('100%')
  }

  @Builder
  private LibraryContinueReadingCard(compactList: boolean = false) {
    ContinueReadingShelfCard({
      compactList: compactList,
      info: this.visibleContinueReadingCard(),
      onOpenReader: (comicId: ComicId) => {
        if (!this.selectionMode) this.onContinueReading(comicId)
      },
    })
  }

  private visibleContinueReadingCard(): ContinueReadingCardViewModel {
    const scope = this.privacy.visibleCategoryId
    const scoped = this.scopedContinueReadingCard
    if (scope.length > 0 && scope === this.filterCategory && scoped !== undefined &&
      showLibraryComic(this.libraryStore.getComicSummary(scoped.comicId), this.privateCategoryIds, scope)) return scoped
    return this.continueReadingCard
  }

  private canShowContinueReading(): boolean {
    if (!this.showContinueReadingCard) return false
    const comic = this.libraryStore.getComicSummary(this.visibleContinueReadingCard().comicId)
    const scope = this.privacy.visibleCategoryId
    return comic !== undefined && showLibraryComic(comic, this.privateCategoryIds, scope === this.filterCategory ? scope : '')
  }

  private lockedCategoryWorks(): boolean {
    return this.privateCategoryIds.has(this.filterCategory) && this.privacy.visibleCategoryId !== this.filterCategory
  }

  @Builder
  private LibraryUnlockWorks() {
    Row() {
      KomaIconButton({
        icon: $r('sys.symbol.lock'),
        accessibilityLabel: s('library_privacy_unlock'),
        kind: 'secondary',
        controlSize: 48,
        iconSize: 32,
        isEnabled: this.privacy.presenting && !this.privacy.authenticating,
        action: (): void => { void this.setCategoryFilter(this.filterCategory) },
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 80, bottom: ThemeConstants.SPACE_XXL })
  }

  @Builder
  private LibraryGridHeader() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      Blank()
        .height(this.layoutSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
        .width('100%')
      if (this.canShowContinueReading()) {
        this.LibraryContinueReadingCard()
      }
      this.LibraryViewControls()
    }
    .width('100%')
    .padding({ bottom: ThemeConstants.SPACE_LG })
  }

  @Builder
  private LibraryGridFooter() {
    Column() {
      if (this.lockedCategoryWorks()) this.LibraryUnlockWorks()
      Blank()
        .height(this.layoutSafeArea.bottomAvoidHeight + ThemeConstants.SPACE_XL +
          ThemeConstants.SPACE_LG - this.libraryGridRowGap() +
          ThemeConstants.FLOATING_TAB_BAR_CLEARANCE + Math.max(0, this.layoutSafeArea.keyboardHeight))
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private LibraryGrid() {
    // Heading and tail span the whole width independently of item count.
    // Category switches update only the keyed virtual rows inside that group.
    List({ space: 0, scroller: this.libraryScroller }) {
      ListItemGroup({ header: this.LibraryGridHeader(), footer: this.LibraryGridFooter() }) {
        if (!this.lockedCategoryWorks()) {
          LazyForEach(this.gridRows, (index: number) => {
            ListItem() {
              if (this.gridRows.comicAt(index) !== undefined && this.canSelectComic(this.gridRows.comicAt(index)!.id)) {
                this.LibraryGridCell(index, this.retainGridComic(index, this.gridRows.comicAt(index) as Comic))
              }
            }
            .visibility(this.gridRows.isPublished(index) ? Visibility.Visible : Visibility.Hidden)
            .padding({ bottom: this.libraryGridRowGap() })
            .clip(false)
          }, (index: number): string => `${index}`)
        }
      }
      .clip(false)
    }
    .lanes(this.libraryGridColumnCount(), this.libraryGridColumnGap())
    // Only retain a neighboring row while scrolling. A settled category
    // switch should rebind the visible slots, not a prefetched screen.
    .cachedCount(this.coverGridScrolling ? 1 : 0)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .padding({ left: this.libraryHorizontalInset(), right: this.libraryHorizontalInset() })
    .clipContent(ContentClipMode.CONTENT_ONLY)
    .enableScrollInteraction(this.scrollEnabled)
    .edgeEffect(this.pullRefreshController.nativeSpringEnabled ? EdgeEffect.Spring : EdgeEffect.None, {
      alwaysEnabled: true,
    })
    .gesture(PinchGesture({ fingers: 2 })
      .onActionStart((): void => {
        this.gridAdjustment.beginPinch(this.libraryViewportWidth(), this.listDensity, this.coverLayout.gridColumnWidth)
      })
      .onActionUpdate((event: GestureEvent): void => { this.gridAdjustment.updatePinch(event.scale, this.getUIContext()) })
      .onActionEnd((): void => { this.gridAdjustment.endPinch(this.getUIContext()) })
      .onActionCancel((): void => { this.gridAdjustment.cancelPinch() }))
    .onScrollStart(() => { this.coverGridScrolling = true })
    .onScrollStop(() => { this.coverGridScrolling = false })
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
  private LibraryListCover(row: RepeatItem<ComicCoverInfo>) {
    Badge(libraryUnreadBadgeOptions(this.unreadForCover(row.item.id), row.item.accentColor)) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.shouldShowCoverUri(
          row.item.coverUri,
          row.item.sourceRuntimeId,
          this.sourceImageIdForComic(row.item),
          row.item.sourceKind,
          row.item.remoteServerId,
          row.item.sourceMangaUrl,
        )) {
          CachedCoverImage({
            uri: row.item.coverUri ?? '',
            decodeMaxEdge: coverDecodeEdgeForDisplay(this.libraryListCoverHeight()),
            coverOwnerId: row.item.id,
            objectFit: ImageFit.Cover,
            sourceRuntimeId: row.item.sourceRuntimeId ?? '',
            sourceImageId: this.sourceImageIdForComic(row.item),
            sourceKind: row.item.sourceKind,
            remoteServerId: row.item.remoteServerId ?? '',
            sourceMangaUrl: row.item.sourceMangaUrl ?? '',
            onError: () => {
              this.markCoverUriFailed(
                row.item.coverUri,
                row.item.sourceRuntimeId,
                this.sourceImageIdForComic(row.item),
                row.item.sourceKind,
                row.item.remoteServerId,
                row.item.sourceMangaUrl,
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
    ListItemGroup({ space: this.libraryListSpace() }) {
      Repeat<ComicCoverInfo>(this.displayedCards)
        .each((row: RepeatItem<ComicCoverInfo>) => {
          ListItem() {
            // A virtual row must keep the live item when ArkUI reuses its node.
            if (this.canSelectComic(row.item.id)) this.LibraryListRow(row)
          }
        })
        .key((comic: ComicCoverInfo): string => `list:${comic.id}`)
        .virtualScroll()
    }
    .width('100%')
  }

  @Builder
  private LibraryListRow(row: RepeatItem<ComicCoverInfo>) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      ConciseListRow({
        title: row.item.title,
        subtitle: this.listRowSubtitle(row.item),
        showChevron: false,
        prefixActsAsLeading: true,
        isEnabled: !this.selectionMode || this.canSelectComic(row.item.id),
        action: () => {
          this.handleComicClick(row.item.id)
        },
        prefixBuilderParam: () => {
          this.LibraryListCover(row)
        },
      })
        .layoutWeight(1)
        .onTouch((event: TouchEvent) => {
          this.handleComicTouch(row.item.id, event)
        })
        .priorityGesture(GestureGroup(GestureMode.Exclusive,
          LongPressGesture({ fingers: 1, repeat: false, duration: 500 })
            .onAction(() => {
              this.enterSelectionMode(row.item.id)
            }),
          TapGesture()
            .onAction(() => {
              this.handleComicClick(row.item.id)
            })
        ))

      if (this.selectionMode) {
        this.ComicSelectionCheckbox({ comic: row.item, onCover: false })
      } else if (this.canRemoveComic(row.item.id)) {
        KomaIconButton({
          icon: $r('sys.symbol.ellipsis_circle'),
          kind: 'secondary',
          controlSize: ThemeConstants.TOUCH_TARGET_SM,
          iconSize: ThemeConstants.FONT_SIZE_H3,
          action: () => {
            this.comicActionMenuKey = `list:${row.item.id}`
          },
        })
          .margin({ right: ThemeConstants.SPACE_SM })
          .bindMenu(this.comicActionMenuKey === `list:${row.item.id}`, this.ComicActionMenu({ comic: row.item }), komaMenuOptions({
            placement: Placement.BottomRight,
            onDisappear: () => {
              if (this.comicActionMenuKey === `list:${row.item.id}`) {
                this.comicActionMenuKey = ''
              }
            },
          }))
      }
    }
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
    .backgroundColor(this.isComicSelected(row.item.id) ? ThemeConstants.SOFT_TINT : ThemeConstants.CARD)
    .alignItems(VerticalAlign.Center)
  }

  private applyFilterPreferences(preferencesValue: LibraryFilterPreferences): boolean {
    // A restored preference never grants access to a private category.
    const category = this.privacy.categoryId.length > 0 ? this.privacy.categoryId :
      this.privateCategoryIds.has(preferencesValue.category) ? 'all' : preferencesValue.category
    const projectionChanged = this.defaultSort.sortBy !== preferencesValue.sortBy ||
      this.defaultSort.sortDirection !== preferencesValue.sortDirection ||
      this.defaultSort.sortConfigured !== preferencesValue.sortConfigured ||
      this.filterSource !== preferencesValue.source || this.filterReadState !== preferencesValue.readState ||
      this.filterCategory !== category || this.filterAvailability !== preferencesValue.availability ||
      this.filterMetadataStatus !== preferencesValue.metadataStatus
    this.defaultSort = preferencesValue
    this.viewMode = preferencesValue.viewMode
    this.listDensity = preferencesValue.listDensity
    this.showLibraryBadges = preferencesValue.showBadges
    this.showContinueReadingCard = preferencesValue.showContinueReadingCard
    this.filterSource = preferencesValue.source
    this.filterReadState = preferencesValue.readState
    this.filterCategory = category
    this.filterAvailability = preferencesValue.availability
    this.filterMetadataStatus = preferencesValue.metadataStatus
    console.info(
      `[Library] step=filter_restored sortBy=${this.sortBy} viewMode=${this.viewMode} listDensity=${this.listDensity} showBadges=${this.showLibraryBadges} source=${this.filterSource} readState=${this.filterReadState} category=${this.filterCategory} availability=${this.filterAvailability} metadataStatus=${this.filterMetadataStatus}`
    )
    return projectionChanged
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
    this.smartSubscriptions = [OfflineDownloadRuntime.subscribe(komaRuntimeStorageKey(context), (signal) => {
      if (signal !== 'change' || !this.active || !this.rootNavigation.visible) return
      // Completion and removal can change membership without a shelf edit.
      // A page-by-page progress notification cannot change availability.
      if (this.filterAvailability !== 'all') this.refreshDisplayedSnapshotFromStore()
      else refreshSmart()
    }),
      new TrackerPreferencesStore(context).subscribeMappings(refreshSmart)]
    this.restoreInitialFilterPreferences()
    this.syncDisplayedSnapshotFromProps()
    this.updateGridRows()
    this.publishTitleBar()
  }

  aboutToDisappear(): void {
    this.gridUpdateGeneration++
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
        alwaysEnableEdgeSpring: this.pullRefreshController.nativeSpringEnabled,
        listSpace: this.viewMode === 'list' ? ThemeConstants.SPACE_SM : ThemeConstants.SPACE_LG,
        horizontalPadding: this.viewMode === 'list' ? ThemeConstants.SPACE_MD : this.libraryHorizontalInset(),
        bottomPadding: ThemeConstants.SPACE_XL,
        floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
      }) {
        if (!this.lockedCategoryWorks() && this.isProjectionPending()) {
          ListItem() {
            this.LibraryProjectionLoading()
          }
        } else if (this.hasLibraryContent) {
          if (this.canShowContinueReading()) {
            ListItem() {
              this.LibraryContinueReadingCard(this.viewMode === 'list')
            }
          }

          ListItem() {
            this.LibraryViewControls()
          }

          if (this.lockedCategoryWorks()) {
            ListItem() {
              this.LibraryUnlockWorks()
            }
          } else if (this.hasVisibleLibraryContent) {
            this.LibraryList()
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
            if (this.lockedCategoryWorks()) {
              this.LibraryUnlockWorks()
            } else if (this.filterCategory === 'all') {
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
        controller: this.pullRefreshController,
        indicatorTop: this.layoutSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2,
        onRefresh: async (): Promise<void> => { await this.onRefresh() },
        onScrollEnableChange: (enabled: boolean): void => { this.scrollEnabled = enabled },
      }) {
        // Keep the same shelf header and scroller when removing private rows.
        if (this.viewMode !== 'list' && this.hasLibraryContent &&
          (this.lockedCategoryWorks() || !this.isProjectionPending() && this.hasVisibleLibraryContent)) {
          this.LibraryGrid()
        } else {
          this.LibraryListSurface()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .bindSheet($$this.categoryEditorShown, this.CategoryEditor, libraryCategoryPickerSheetOptions())
    .onAreaChange((_old: Area, next: Area) => {
      this.containerWidth = next.width as number
    })
  }
}
