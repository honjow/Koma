import { common } from '@kit.AbilityKit'
import { Chip, ChipSize } from '@kit.ArkUI'
import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { CachedCoverImage, cachedCoverFailureKey } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  ContinueReadingCardViewModel,
  LibraryPresentationByComicId,
  LibraryViewModel,
  createLibraryViewModelFromComics,
  createMockLibraryPresentationMap,
  createSeededLibraryStore,
} from '../model/MockLibraryData'
import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  CustomLibraryCategory,
  LibraryItem,
  Page,
  ReadingProgress,
  LIBRARY_CATEGORY_FAVORITE_ID,
  LIBRARY_CATEGORY_READ_LATER_ID,
  normalizeCategoryIds,
} from '../model/ComicModels'
import {
  LibraryCategoryFilter,
  LibraryListOptions,
  LibraryReadStateFilter,
  LibrarySortBy,
  LibraryStore,
} from '../model/LibraryStore'
import {
  LibraryAvailabilityFilter,
  LibraryFilterPreferences,
  LibraryFilterStore,
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
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import {
  isRemovableLocalComic,
  LibraryStorePersistenceService,
} from '../model/LibraryPersistence'
import { SourceChapterPageHydrator } from '../model/SourceChapterPageHydrator'
import {
  AppFilesReaderSessionPersistenceAdapter,
  InMemoryReaderSessionStore,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'
import {
  AppFilesChapterReadStatePersistenceAdapter,
  ChapterReadStateMutation,
  ChapterReadStateStore,
} from '../model/ChapterReadStateStore'
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

@ComponentV2
struct ContinueReadingShelfCard {
  @Param info: ContinueReadingCardViewModel = {
    title: '',
    detail: '',
    progress: 0,
    color: ThemeConstants.SOURCE_LOCAL_COLOR,
    comicId: '',
  }
  @Param revision: number = 0
  @Local private failedCoverUri: string = ''
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}

  private shouldShowCover(): boolean {
    const coverUri = this.info.coverUri ?? ''
    return coverUri.length > 0 && this.failedCoverUri !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(this.info.coverUri, this.info.sourceRuntimeId, this.info.sourceImageId ?? this.info.comicId)
  }

  private isRemoteSourceCover(): boolean {
    const coverUri = this.info.coverUri?.toLocaleLowerCase() ?? ''
    const sourceRuntimeId = this.info.sourceRuntimeId?.trim() ?? ''
    return sourceRuntimeId.length > 0 && (coverUri.startsWith('http://') || coverUri.startsWith('https://'))
  }

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(ThemeConstants.SPACE_XXL)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
        if (this.shouldShowCover()) {
          if (this.isRemoteSourceCover()) {
            CachedCoverImage({
              uri: this.info.coverUri ?? '',
              objectFit: ImageFit.Cover,
              sourceRuntimeId: this.info.sourceRuntimeId ?? '',
              sourceImageId: this.info.sourceImageId ?? this.info.comicId,
              onError: () => {
                this.failedCoverUri = this.coverFailureKey()
              },
            })
          } else {
            Image(this.info.coverUri ?? '')
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .interpolation(ImageInterpolation.Medium)
              .onError(() => {
                this.failedCoverUri = this.coverFailureKey()
              })
          }
        }
      }
      .width(76)
      .height(102)
      .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
      .backgroundColor(this.info.color)

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
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.onOpenReader(this.info.comicId)
    })
  }
}

@ComponentV2
export struct LibraryPage {
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryComics: Comic[] = createSeededLibraryStore().listComics()
  @Param libraryRevision: number = 0
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private displayedComics: Comic[] = createSeededLibraryStore().listComics()
  @Local private displayedRevision: number = 0
  @Local private selectionMode: boolean = false
  @Local private selectedIds: Set<ComicId> = new Set<ComicId>()
  @Local private suppressOpenComicId: ComicId = ''
  @Local private openingComicId: ComicId = ''
  @Local private sortBy: LibrarySortBy = 'lastRead'
  @Local private viewMode: LibraryViewMode = 'grid'
  @Local private listDensity: LibraryListDensity = 'standard'
  @Local private showLibraryBadges: boolean = true
  @Local private filterSource: LibrarySourceFilter = 'all'
  @Local private filterReadState: LibraryReadStateFilter = 'all'
  @Local private filterCategory: LibraryCategoryFilter = 'all'
  @Local private filterAvailability: LibraryAvailabilityFilter = 'all'
  @Local private filterMetadataStatus: LibraryMetadataStatusFilter = 'all'
  @Local private failedCoverUris: string[] = []
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  @Param presentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
  @Param sourceRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  private sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}
  @Event onImportRequested: () => void = () => {}
  @Event onRemoveComicRequested: (comicId: ComicId) => boolean = (_comicId: ComicId) => false
  @Event onRemoveComicsRequested: (comicIds: ComicId[]) => number = (_comicIds: ComicId[]) => 0
  @Event onAssignCategoriesRequested: (comicIds: ComicId[], categoryIds?: string[]) => boolean =
    (_comicIds: ComicId[], _categoryIds?: string[]) => false
  @Event onUpdateCategoryMembershipRequested: (comicIds: ComicId[], categoryId: string, selected: boolean) => boolean =
    (_comicIds: ComicId[], _categoryId: string, _selected: boolean) => false
  private longPressTimer: number = 0
  private longPressComicId: ComicId = ''

  @Monitor('libraryComics', 'libraryRevision')
  private syncDisplayedSnapshotFromProps(): void {
    this.refreshDisplayedSnapshotFromStore()
    this.displayedRevision = this.libraryRevision
    this.removeMissingSelectedComics()
  }

  @Monitor('remoteProgress.syncRevision')
  private onRemoteProgressSyncRevChanged(): void {
    void this.remoteProgress.syncRevision
    this.reloadPersistentSessionStore('bootstrap_sync')
  }

  private reloadPersistentSessionStore(reason: string): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        return
      }
      this.sessionStore = new PersistentReaderSessionStore(
        new AppFilesReaderSessionPersistenceAdapter(context.filesDir)
      )
      this.refreshDisplayedSnapshotFromStore()
      console.info(`[Library] step=progress_reload reason=${reason}`)
    } catch (error) {
      void error
      console.info('[Library] step=progress_reload_failed reason=session_store')
    }
  }

  private refreshDisplayedSnapshotFromStore(): void {
    const progressByComicId = this.progressByComicId()
    const items = this.libraryStore.listLibraryItems(progressByComicId, this.currentListOptions())
    const nextComics: Comic[] = []
    items.forEach((item: LibraryItem) => {
      const comic = this.libraryStore.getComic(item.comicId)
      if (comic !== undefined) {
        nextComics.push(comic)
      }
    })
    this.displayedComics = this.filterMetadataStatusComics(
      this.filterAvailabilityComics(this.filterPreciseSourceComics(nextComics))
    )
    this.displayedRevision += 1
    this.removeMissingSelectedComics()
  }

  private filterMetadataStatusComics(comics: Comic[]): Comic[] {
    if (this.filterMetadataStatus === 'all') {
      return comics
    }
    if (this.filterMetadataStatus === 'unknown') {
      return comics.filter((comic: Comic): boolean => comic.localMetadata?.status === undefined)
    }
    return comics.filter((comic: Comic): boolean => comic.localMetadata?.status === this.filterMetadataStatus)
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
      const entries = new OfflineDownloadQueueStore(context.filesDir).loadReconciledSnapshot()
      const entriesByComicId = new Map<ComicId, OfflineDownloadQueueEntry[]>()
      entries.forEach((entry: OfflineDownloadQueueEntry) => {
        if (entry.status !== OfflineDownloadStatus.DOWNLOADED && entry.status !== OfflineDownloadStatus.PARTIAL) {
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
          if (entry.status === OfflineDownloadStatus.PARTIAL) {
            comicAvailability.set(comic.id, OfflineDownloadStatus.PARTIAL)
            return
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
      const progress = this.sessionStore.getProgress(comic.id)
      if (progress !== undefined) {
        progressByComicId.set(comic.id, progress)
      }
    })
    return progressByComicId
  }

  private currentListOptions(): LibraryListOptions {
    return {
      sortBy: this.sortBy,
      filterSource: this.sourceKindsForFilter(),
      filterReadState: this.filterReadState,
      filterCategoryId: this.validCategoryFilter(),
    }
  }

  private validCategoryFilter(): LibraryCategoryFilter {
    if (
      this.filterCategory === 'all' ||
      this.filterCategory === 'uncategorized' ||
      this.filterCategory === LIBRARY_CATEGORY_READ_LATER_ID ||
      this.filterCategory === LIBRARY_CATEGORY_FAVORITE_ID
    ) {
      return this.filterCategory
    }
    const categoryExists = this.libraryStore.listCustomCategories().some((category: CustomLibraryCategory): boolean => {
      return category.id === this.filterCategory
    })
    if (categoryExists) {
      return this.filterCategory
    }
    this.filterCategory = 'all'
    this.saveFilterPreferences()
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

  private async restoreFilterPreferences(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const preferencesValue = await new LibraryFilterStore(context).load()
      this.sortBy = preferencesValue.sortBy
      this.viewMode = preferencesValue.viewMode
      this.listDensity = preferencesValue.listDensity
      this.showLibraryBadges = preferencesValue.showBadges
      this.filterSource = preferencesValue.source
      this.filterReadState = preferencesValue.readState
      this.filterCategory = preferencesValue.category
      this.filterAvailability = preferencesValue.availability
      this.filterMetadataStatus = preferencesValue.metadataStatus
      this.applyCategoryDisplayStrategy(this.validCategoryFilter())
      this.refreshDisplayedSnapshotFromStore()
      console.info(
        `[Library] step=filter_restored sortBy=${this.sortBy} viewMode=${this.viewMode} listDensity=${this.listDensity} showBadges=${this.showLibraryBadges} source=${this.filterSource} readState=${this.filterReadState} category=${this.filterCategory} availability=${this.filterAvailability} metadataStatus=${this.filterMetadataStatus}`
      )
    } catch (error) {
      void error
      console.info('[Library] step=filter_restore_failed reason=filter_restore')
    }
  }

  private saveFilterPreferences(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const preferencesValue: LibraryFilterPreferences = {
        sortBy: this.sortBy,
        viewMode: this.viewMode,
        listDensity: this.listDensity,
        showBadges: this.showLibraryBadges,
        source: this.filterSource,
        readState: this.filterReadState,
        category: this.filterCategory,
        availability: this.filterAvailability,
        metadataStatus: this.filterMetadataStatus,
      }
      void new LibraryFilterStore(context).save(preferencesValue)
    } catch (error) {
      void error
      console.info('[Library] step=filter_save_failed reason=filter_save')
    }
  }

  private setSortBy(sortBy: LibrarySortBy): void {
    if (this.sortBy === sortBy) {
      return
    }
    this.sortBy = sortBy
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=sort_changed sortBy=${sortBy}`)
  }

  private setSourceFilter(source: LibrarySourceFilter): void {
    if (this.filterSource === source) {
      return
    }
    this.filterSource = source
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed source=${source} readState=${this.filterReadState}`)
  }

  private setReadStateFilter(readState: LibraryReadStateFilter): void {
    if (this.filterReadState === readState) {
      return
    }
    this.filterReadState = readState
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed source=${this.filterSource} readState=${readState}`)
  }

  private setCategoryFilter(category: LibraryCategoryFilter): void {
    if (this.filterCategory === category) {
      return
    }
    this.filterCategory = category
    this.applyCategoryDisplayStrategy(category)
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed category=${category}`)
  }

  private setAvailabilityFilter(availability: LibraryAvailabilityFilter): void {
    if (this.filterAvailability === availability) {
      return
    }
    this.filterAvailability = availability
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed availability=${availability}`)
  }

  private setMetadataStatusFilter(metadataStatus: LibraryMetadataStatusFilter): void {
    if (this.filterMetadataStatus === metadataStatus) {
      return
    }
    this.filterMetadataStatus = metadataStatus
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed metadataStatus=${metadataStatus}`)
  }

  private hasActiveFilters(): boolean {
    return this.sortBy !== 'lastRead' ||
      this.filterSource !== 'all' ||
      this.filterReadState !== 'all' ||
      this.filterCategory !== 'all' ||
      this.filterAvailability !== 'all' ||
      this.filterMetadataStatus !== 'all'
  }

  private resetFilters(): void {
    if (!this.hasActiveFilters()) {
      return
    }
    this.sortBy = 'lastRead'
    this.filterSource = 'all'
    this.filterReadState = 'all'
    this.filterCategory = 'all'
    this.filterAvailability = 'all'
    this.filterMetadataStatus = 'all'
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info('[Library] step=filters_reset')
  }

  private applyCategoryDisplayStrategy(category: LibraryCategoryFilter): void {
    const strategy = this.libraryStore.getCategoryDisplayStrategy(category)
    if (strategy === undefined) {
      return
    }
    this.sortBy = strategy.sortBy
    this.filterReadState = strategy.readState
  }

  private sortLabel(): string {
    if (this.sortBy === 'added') {
      return s('library_sort_added')
    }
    if (this.sortBy === 'title') {
      return s('library_sort_title')
    }
    if (this.sortBy === 'source') {
      return s('library_sort_source')
    }
    return s('library_sort_last_read')
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

  private readStateLabel(): string {
    if (this.filterReadState === 'unread') {
      return s('library_read_state_unread')
    }
    if (this.filterReadState === 'reading') {
      return s('library_read_state_reading')
    }
    if (this.filterReadState === 'completed') {
      return s('library_read_state_completed')
    }
    return s('library_read_state_all')
  }

  private categoryLabel(): string {
    if (this.filterCategory === 'uncategorized') {
      return s('library_category_uncategorized')
    }
    if (this.filterCategory === LIBRARY_CATEGORY_READ_LATER_ID) {
      return s('library_category_read_later')
    }
    if (this.filterCategory === LIBRARY_CATEGORY_FAVORITE_ID) {
      return s('library_category_favorite')
    }
    const customCategory = this.libraryStore.listCustomCategories().find((category: CustomLibraryCategory): boolean => {
      return category.id === this.filterCategory
    })
    if (customCategory !== undefined) {
      return customCategory.name
    }
    return s('library_category_all')
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

  private viewModel(): LibraryViewModel {
    return createLibraryViewModelFromComics(this.displayedComics, this.sessionStore, this.presentationByComicId)
  }

  private gridComics(): ComicCoverInfo[] {
    return this.viewModel().comics.map((comic: ComicCoverInfo): ComicCoverInfo => {
      const sourceComic = this.libraryStore.getComic(comic.id)
      return {
        id: comic.id,
        title: comic.title,
        subtitle: comic.subtitle,
        progressText: comic.progressText,
        coverColor: comic.coverColor,
        accentColor: comic.accentColor,
        pageCount: comic.pageCount,
        coverUri: comic.coverUri,
        sourceRuntimeId: comic.sourceRuntimeId,
        sourceImageId: comic.sourceImageId ?? sourceComic?.remoteResourceId ?? comic.id,
        categoryLabels: this.showLibraryBadges ?
          (sourceComic === undefined ? comic.categoryLabels : this.categoryLabelsForComic(sourceComic)) :
          [],
      }
    })
  }

  private listRowSubtitle(comic: ComicCoverInfo): string {
    if (comic.categoryLabels !== undefined && comic.categoryLabels.length > 0) {
      return `${comic.subtitle} · ${comic.categoryLabels.join(' · ')}`
    }
    return comic.subtitle
  }

  private libraryGridColumnCount(): number {
    if (this.listDensity === 'compact') {
      return 4
    }
    if (this.listDensity === 'comfortable') {
      return 2
    }
    return 3
  }

  private libraryGridColumnGap(): number {
    if (this.listDensity === 'compact') {
      return ThemeConstants.SPACE_SM
    }
    if (this.listDensity === 'comfortable') {
      return ThemeConstants.SPACE_XL
    }
    return ThemeConstants.SPACE_LG
  }

  private libraryGridRowGap(): number {
    if (this.listDensity === 'compact') {
      return ThemeConstants.SPACE_LG
    }
    if (this.listDensity === 'comfortable') {
      return ThemeConstants.SPACE_XXL
    }
    return ThemeConstants.SPACE_XL
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
      return ThemeConstants.SPACE_MD
    }
    return ThemeConstants.SPACE_SM
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
      if (categoryId === LIBRARY_CATEGORY_FAVORITE_ID) {
        labels.push(s('library_category_favorite'))
      } else if (categoryId === LIBRARY_CATEGORY_READ_LATER_ID) {
        labels.push(s('library_category_read_later'))
      } else {
        const customCategory = customCategories.find((category: CustomLibraryCategory): boolean => {
          return category.id === categoryId
        })
        if (customCategory !== undefined) {
          labels.push(customCategory.name)
        }
      }
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
        title: summary?.displayName ?? s('library_source_package'),
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
    return `${this.displayedRevision}:${comic.id}`
  }

  private listRowRenderKey(comic: ComicCoverInfo): string {
    return `${this.displayedRevision}:list:${comic.id}`
  }

  private isEvenDisplayedRevision(): boolean {
    return this.displayedRevision % 2 === 0
  }

  private removeMissingSelectedComics(): void {
    if (this.selectedIds.size === 0) {
      this.selectionMode = false
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
    this.selectionMode = this.selectedIds.size > 0
  }

  private enterSelectionMode(comicId: ComicId): void {
    if (!this.canSelectComic(comicId)) {
      return
    }
    const nextSelectedIds = new Set<ComicId>()
    nextSelectedIds.add(comicId)
    this.selectedIds = nextSelectedIds
    this.selectionMode = true
    this.suppressOpenComicId = comicId
  }

  private exitSelectionMode(): void {
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
      void this.openComicFromLibrary(comicId)
    }
  }

  private readerChapterIdForComic(comic: Comic): string | undefined {
    const progress = this.sessionStore.getProgress(comic.id)
    if (progress !== undefined && comic.chapters.some((chapter: Chapter): boolean => chapter.id === progress.chapterId)) {
      return progress.chapterId
    }
    return comic.chapters.length === 0 ? undefined : comic.chapters[0].id
  }

  private chapterNeedsSourcePages(comic: Comic, chapterId: string | undefined): boolean {
    if (chapterId === undefined ||
      comic.sourceKind !== ComicSourceKind.PRIVATE_LIBRARY ||
      comic.sourceRuntimeId === undefined ||
      comic.sourceRuntimeId.trim().length === 0) {
      return false
    }
    const chapter = comic.chapters.find((item: Chapter): boolean => item.id === chapterId)
    return chapter !== undefined && chapter.pages.length === 0
  }

  private logSourceReaderPagesUnavailable(reasonCode?: string): void {
    if (reasonCode === 'pages_missing') {
      console.warn('[Library] step=source_reader_pages_unavailable failed=true reason=pages_missing')
      return
    }
    if (reasonCode === 'chapter_missing') {
      console.warn('[Library] step=source_reader_pages_unavailable failed=true reason=chapter_missing')
      return
    }
    if (reasonCode === 'source_missing') {
      console.warn('[Library] step=source_reader_pages_unavailable failed=true reason=source_missing')
      return
    }
    console.warn('[Library] step=source_reader_pages_unavailable failed=true reason=source_pages_unavailable')
  }

  private async openComicFromLibrary(comicId: ComicId): Promise<void> {
    if (this.openingComicId === comicId) {
      return
    }
    const comic = this.libraryStore.getComic(comicId)
    if (comic === undefined) {
      this.showToast(s('common_unavailable'))
      return
    }
    const chapterId = this.readerChapterIdForComic(comic)
    if (!this.chapterNeedsSourcePages(comic, chapterId)) {
      this.onOpenReader(comicId, chapterId)
      return
    }
    this.openingComicId = comicId
    this.showToast(s('source_pkg_loading'))
    try {
      const result = await new SourceChapterPageHydrator(
        this.libraryStore,
        this.sourceRegistry,
        this.libraryPersistenceService,
        () => {
          this.refreshDisplayedSnapshotFromStore()
        },
      ).ensureChapterPages(comicId, comic.sourceRuntimeId, chapterId as string)
      if (!result.hydrated) {
        this.logSourceReaderPagesUnavailable(result.reasonCode)
        this.showToast(s('manga_detail_chapter_pages_load_failed'))
        return
      }
      this.onOpenReader(comicId, chapterId)
    } catch (_error) {
      this.logSourceReaderPagesUnavailable('source_pages_lookup')
      this.showToast(s('manga_detail_chapter_pages_load_failed'))
    } finally {
      this.openingComicId = ''
    }
  }

  private clearLongPressTimer(): void {
    if (this.longPressTimer > 0) {
      clearTimeout(this.longPressTimer)
      this.longPressTimer = 0
    }
    this.longPressComicId = ''
  }

  private handleComicTouch(comicId: ComicId, event: TouchEvent): void {
    if (!this.canSelectComic(comicId)) {
      return
    }
    if (event.type === TouchType.Down) {
      this.clearLongPressTimer()
      this.longPressComicId = comicId
      this.longPressTimer = setTimeout(() => {
        if (this.longPressComicId === comicId) {
          this.enterSelectionMode(comicId)
        }
        this.longPressTimer = 0
      }, 500)
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.clearLongPressTimer()
    }
  }

  private toggleSelection(comicId: ComicId): void {
    if (!this.canSelectComic(comicId)) {
      return
    }
    const nextSelectedIds = new Set<ComicId>(this.selectedIds)
    if (nextSelectedIds.has(comicId)) {
      nextSelectedIds.delete(comicId)
    } else {
      nextSelectedIds.add(comicId)
    }
    this.selectedIds = nextSelectedIds
    this.selectionMode = this.selectedIds.size > 0
  }

  private selectAllVisibleComics(): void {
    const nextSelectedIds = new Set<ComicId>()
    this.gridComics().forEach((comic: ComicCoverInfo) => {
      if (this.canSelectComic(comic.id)) {
        nextSelectedIds.add(comic.id)
      }
    })
    this.selectedIds = nextSelectedIds
    this.selectionMode = this.selectedIds.size > 0
  }

  private selectedCount(): number {
    return this.selectedIds.size
  }

  private selectedRemovableCount(): number {
    return Array.from(this.selectedIds).filter((comicId: ComicId): boolean => this.canRemoveComic(comicId)).length
  }

  private removeSelectedComics(): void {
    const comicIds = Array.from(this.selectedIds).filter((comicId: ComicId): boolean => this.canRemoveComic(comicId))
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

  private assignSelectedCategory(categoryIds?: string[]): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    if (this.onAssignCategoriesRequested(comicIds, categoryIds)) {
      this.exitSelectionMode()
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private addSelectedCategory(categoryId: string): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    if (this.onUpdateCategoryMembershipRequested(comicIds, categoryId, true)) {
      this.exitSelectionMode()
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private removeSelectedCategory(categoryId: string): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    if (this.onUpdateCategoryMembershipRequested(comicIds, categoryId, false)) {
      this.exitSelectionMode()
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private chapterReadStateStore(): ChapterReadStateStore | undefined {
    try {
      const context = getContext(this) as common.UIAbilityContext
      return new ChapterReadStateStore(new AppFilesChapterReadStatePersistenceAdapter(context.filesDir))
    } catch (error) {
      void error
      console.info('[Library] step=batch_read_state_store_failed reason=read_state_store')
      return undefined
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (error) {
      void error
    }
  }

  private markSelectedReadState(isRead: boolean): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    const readStateStore = this.chapterReadStateStore()
    if (readStateStore === undefined) {
      this.showToast(s('library_batch_read_state_unavailable'))
      return
    }
    const mutations: ChapterReadStateMutation[] = []
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
      if (isRead) {
        this.sessionStore.saveProgress(this.completedProgressForComic(comic))
      } else {
        this.sessionStore.removeProgress(comic.id)
      }
    })
    if (mutations.length === 0) {
      this.showToast(s('library_batch_read_state_no_chapters'))
      return
    }
    const changedCount = readStateStore.markMany(mutations)
    if (changedCount > 0) {
      console.info(`[Library] step=batch_read_state isRead=${isRead} comics=${comicIds.length} chapters=${changedCount}`)
      this.showToast(isRead ? s('library_batch_marked_read') : s('library_batch_marked_unread'))
      this.exitSelectionMode()
      this.refreshDisplayedSnapshotFromStore()
    }
  }

  private completedProgressForComic(comic: Comic): ReadingProgress {
    const chapter = comic.chapters[comic.chapters.length - 1]
    const pages = chapter.pages.slice().sort((left: Page, right: Page): number => left.index - right.index)
    const totalPages = chapter.pageCount > 0 ? chapter.pageCount : pages.length
    const pageIndex = totalPages > 0 ? totalPages - 1 : 0
    const pageId = pages.length > 0 ? pages[pages.length - 1].id : undefined
    const progress: ReadingProgress = {
      comicId: comic.id,
      chapterId: chapter.id,
      pageIndex,
      totalPages,
      progressRatio: totalPages > 0 ? 1 : 0,
      completed: true,
      updatedAt: Date.now(),
    }
    if (pageId !== undefined) {
      progress.pageId = pageId
    }
    return progress
  }

  private showBatchRemoveConfirmation(): void {
    const count = this.selectedRemovableCount()
    if (count === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('library_batch_remove_title'),
      message: s('library_batch_remove_message').replace('%s', `${count}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeSelectedComics()
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private showRemoveConfirmation(comic: ComicCoverInfo): void {
    if (!this.canRemoveComic(comic.id)) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('library_remove_title'),
      message: s('library_remove_message').replace('%s', comic.title),
      autoCancel: true,
      primaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          if (this.onRemoveComicRequested(comic.id)) {
            this.refreshDisplayedSnapshotFromStore()
          }
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  @Builder
  private ComicActionMenu(comic: ComicCoverInfo) {
    Menu() {
      if (this.canSelectComic(comic.id)) {
        MenuItem({ content: s('common_select') })
          .onClick(() => {
            this.enterSelectionMode(comic.id)
          })
      }
      if (this.canRemoveComic(comic.id)) {
        MenuItem({ content: s('library_action_remove_from_library') })
          .contentFontColor(ThemeConstants.DANGER)
          .onClick(() => {
            this.showRemoveConfirmation(comic)
          })
      }
    }
  }

  @Builder
  private SortMenu() {
    Menu() {
      MenuItem({ content: s('library_sort_last_read') })
        .onClick(() => {
          this.setSortBy('lastRead')
        })
      MenuItem({ content: s('library_sort_added') })
        .onClick(() => {
          this.setSortBy('added')
        })
      MenuItem({ content: s('library_sort_title') })
        .onClick(() => {
          this.setSortBy('title')
        })
      MenuItem({ content: s('library_sort_source') })
        .onClick(() => {
          this.setSortBy('source')
        })
    }
  }

  @Builder
  private SourceMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setSourceFilter('all')
        })
      MenuItem({ content: s('library_source_local') })
        .onClick(() => {
          this.setSourceFilter('local')
        })
      MenuItem({ content: s('library_source_private') })
        .onClick(() => {
          this.setSourceFilter('private')
        })
      MenuItem({ content: s('route_komga_title') })
        .onClick(() => {
          this.setSourceFilter('komga')
        })
      MenuItem({ content: s('route_kavita_title') })
        .onClick(() => {
          this.setSourceFilter('kavita')
        })
      MenuItem({ content: s('route_opds_title') })
        .onClick(() => {
          this.setSourceFilter('opds')
        })
      MenuItem({ content: s('route_webdav_title') })
        .onClick(() => {
          this.setSourceFilter('webdav')
        })
      ForEach(this.privateServerFilterOptions(), (option: LibraryServerSourceFilterOption) => {
        MenuItem({ content: option.title })
          .onClick(() => {
            this.setSourceFilter(option.filter)
          })
      }, (option: LibraryServerSourceFilterOption) => option.filter)
      ForEach(this.runtimeSourceFilterOptions(), (option: LibraryServerSourceFilterOption) => {
        MenuItem({ content: option.title })
          .onClick(() => {
            this.setSourceFilter(option.filter)
          })
      }, (option: LibraryServerSourceFilterOption) => option.filter)
      MenuItem({ content: s('library_source_package') })
        .onClick(() => {
          this.setSourceFilter('source_package')
        })
    }
  }

  @Builder
  private ReadStateMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setReadStateFilter('all')
        })
      MenuItem({ content: s('library_read_state_unread') })
        .onClick(() => {
          this.setReadStateFilter('unread')
        })
      MenuItem({ content: s('library_read_state_reading') })
        .onClick(() => {
          this.setReadStateFilter('reading')
        })
      MenuItem({ content: s('library_read_state_completed') })
        .onClick(() => {
          this.setReadStateFilter('completed')
        })
    }
  }

  @Builder
  private AvailabilityMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setAvailabilityFilter('all')
        })
      MenuItem({ content: s('library_availability_downloaded') })
        .onClick(() => {
          this.setAvailabilityFilter('downloaded')
        })
      MenuItem({ content: s('library_availability_fully_downloaded') })
        .onClick(() => {
          this.setAvailabilityFilter('fully_downloaded')
        })
      MenuItem({ content: s('library_availability_partially_downloaded') })
        .onClick(() => {
          this.setAvailabilityFilter('partially_downloaded')
        })
      MenuItem({ content: s('library_availability_not_downloaded') })
        .onClick(() => {
          this.setAvailabilityFilter('not_downloaded')
        })
    }
  }

  @Builder
  private MetadataStatusMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setMetadataStatusFilter('all')
        })
      MenuItem({ content: s('manga_status_ongoing') })
        .onClick(() => {
          this.setMetadataStatusFilter('ongoing')
        })
      MenuItem({ content: s('manga_status_completed') })
        .onClick(() => {
          this.setMetadataStatusFilter('completed')
        })
      MenuItem({ content: s('manga_status_hiatus') })
        .onClick(() => {
          this.setMetadataStatusFilter('hiatus')
        })
      MenuItem({ content: s('manga_status_cancelled') })
        .onClick(() => {
          this.setMetadataStatusFilter('cancelled')
        })
      MenuItem({ content: s('manga_status_unknown') })
        .onClick(() => {
          this.setMetadataStatusFilter('unknown')
        })
    }
  }

  @Builder
  private CategoryMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setCategoryFilter('all')
        })
      MenuItem({ content: s('library_category_uncategorized') })
        .onClick(() => {
          this.setCategoryFilter('uncategorized')
        })
      MenuItem({ content: s('library_category_read_later') })
        .onClick(() => {
          this.setCategoryFilter(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      MenuItem({ content: s('library_category_favorite') })
        .onClick(() => {
          this.setCategoryFilter(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      ForEach(this.libraryStore.listCustomCategories(), (category: CustomLibraryCategory) => {
        MenuItem({ content: category.name })
          .onClick(() => {
            this.setCategoryFilter(category.id)
          })
      }, (category: CustomLibraryCategory) => category.id)
    }
  }

  @Builder
  private BatchCategoryMenu() {
    Menu() {
      MenuItem({ content: s('library_batch_add_favorite') })
        .onClick(() => {
          this.addSelectedCategory(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      MenuItem({ content: s('library_batch_move_favorite') })
        .onClick(() => {
          this.assignSelectedCategory([LIBRARY_CATEGORY_FAVORITE_ID])
        })
      MenuItem({ content: s('library_batch_remove_favorite') })
        .onClick(() => {
          this.removeSelectedCategory(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      MenuItem({ content: s('library_batch_add_read_later') })
        .onClick(() => {
          this.addSelectedCategory(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      MenuItem({ content: s('library_batch_move_read_later') })
        .onClick(() => {
          this.assignSelectedCategory([LIBRARY_CATEGORY_READ_LATER_ID])
        })
      MenuItem({ content: s('library_batch_remove_read_later') })
        .onClick(() => {
          this.removeSelectedCategory(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      ForEach(this.libraryStore.listCustomCategories(), (category: CustomLibraryCategory) => {
        MenuItem({ content: s('library_batch_add_category').replace('%s', category.name) })
          .onClick(() => {
            this.addSelectedCategory(category.id)
          })
        MenuItem({ content: s('library_batch_move_category').replace('%s', category.name) })
          .onClick(() => {
            this.assignSelectedCategory([category.id])
          })
        MenuItem({ content: s('library_batch_remove_category').replace('%s', category.name) })
          .onClick(() => {
            this.removeSelectedCategory(category.id)
          })
      }, (category: CustomLibraryCategory) => category.id)
      MenuItem({ content: s('library_batch_clear_categories') })
        .onClick(() => {
          this.assignSelectedCategory(undefined)
        })
    }
  }

  @Builder
  private BatchReadStateMenu() {
    Menu() {
      MenuItem({ content: s('library_batch_mark_read') })
        .onClick(() => {
          this.markSelectedReadState(true)
        })
      MenuItem({ content: s('library_batch_mark_unread') })
        .onClick(() => {
          this.markSelectedReadState(false)
        })
    }
  }


  @Builder
  private SortFilterBar() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Row() {
          Chip({
            label: {
              text: s('library_sort_chip').replace('%s', this.sortLabel()),
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.sortBy !== 'lastRead',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.SortMenu())
        Row() {
          Chip({
            label: {
              text: `${this.sourceLabel()} ▾`,
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filterSource !== 'all',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.SourceMenu())
        Row() {
          Chip({
            label: {
              text: `${this.readStateLabel()} ▾`,
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filterReadState !== 'all',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.ReadStateMenu())
        Row() {
          Chip({
            label: {
              text: `${this.availabilityLabel()} ▾`,
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filterAvailability !== 'all',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.AvailabilityMenu())
        Row() {
          Chip({
            label: {
              text: `${this.metadataStatusLabel()} ▾`,
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filterMetadataStatus !== 'all',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.MetadataStatusMenu())
        Row() {
          Chip({
            label: {
              text: `${this.categoryLabel()} ▾`,
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filterCategory !== 'all',
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
        .bindMenu(this.CategoryMenu())
        if (this.hasActiveFilters()) {
          KomaActionButton({
            label: s('common_reset'),
            kind: 'ghost',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.resetFilters()
            },
          })
        }
      }
      .width('auto')
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private EmptyLibrary() {
    KomaEmptyState({
      title: s('library_empty_title'),
      message: s('library_empty_message'),
      actionLabel: s('route_import_title'),
      showAction: true,
      action: () => {
        this.onImportRequested()
      },
    })
  }

  @Builder
  private EmptyFilteredLibrary() {
    KomaEmptyState({
      title: s('library_filtered_empty_title'),
      message: s('library_filtered_empty_message'),
      actionLabel: s('common_reset'),
      showAction: true,
      action: () => {
        this.resetFilters()
      },
    })
  }

  @Builder
  private BatchActionBar() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text(s('library_selected_count').replace('%s', `${this.selectedCount()}`))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .layoutWeight(1)

      KomaActionButton({
        label: s('library_action_select_all'),
        kind: 'secondary',
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.selectAllVisibleComics()
        },
      })

      KomaActionButton({
        label: s('common_cancel'),
        kind: 'secondary',
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.exitSelectionMode()
        },
      })

      KomaActionButton({
        label: `${s('library_action_categories')} ▾`,
        kind: 'primary',
        isEnabled: this.selectedCount() > 0,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
      })
        .bindMenu(this.BatchCategoryMenu())

      KomaActionButton({
        label: `${s('library_category_read_state_title')} ▾`,
        kind: 'secondary',
        isEnabled: this.selectedCount() > 0,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
      })
        .bindMenu(this.BatchReadStateMenu())

      KomaActionButton({
        label: s('common_remove'),
        kind: 'danger',
        isEnabled: this.selectedRemovableCount() > 0,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.showBatchRemoveConfirmation()
        },
      })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private LibraryGridCell(comic: ComicCoverInfo) {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.canRemoveComic(comic.id)) {
        ComicCoverCard({
          comic: comic,
          title: comic.title,
          subtitle: comic.subtitle,
          progressText: comic.progressText,
          coverColor: comic.coverColor,
          accentColor: comic.accentColor,
          categoryLabels: comic.categoryLabels ?? [],
          selected: this.isComicSelected(comic.id),
        })
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

        if (!this.selectionMode) {
          KomaIconButton({
            icon: $r('sys.symbol.more'),
            kind: 'secondary',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
          })
            .margin({ top: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
            .bindMenu(this.ComicActionMenu(comic))
        }
      } else {
        ComicCoverCard({
          comic: comic,
          title: comic.title,
          subtitle: comic.subtitle,
          progressText: comic.progressText,
          coverColor: comic.coverColor,
          accentColor: comic.accentColor,
          categoryLabels: comic.categoryLabels ?? [],
          selected: false,
        })
          .gesture(TapGesture()
            .onAction(() => {
              if (!this.selectionMode) {
                void this.openComicFromLibrary(comic.id)
              }
            }))
      }
    }
    .width('100%')
  }

  @Builder
  private LibraryGrid(comics: ComicCoverInfo[]) {
    Column({ space: this.libraryGridRowGap() }) {
      ForEach(this.libraryGridRowIndexes(comics), (rowIndex: number) => {
        Row({ space: this.libraryGridColumnGap() }) {
          ForEach(this.libraryGridRowComics(comics, rowIndex), (comic: ComicCoverInfo) => {
            Column() {
              this.LibraryGridCell(comic)
            }
            .layoutWeight(1)
          }, (comic: ComicCoverInfo) => this.comicRenderKey(comic))

          ForEach(this.libraryGridMissingCells(this.libraryGridRowComics(comics, rowIndex)), (_index: number) => {
            Blank()
              .layoutWeight(1)
          }, (index: number) => `blank-${rowIndex}-${index}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (rowIndex: number) => `row-${rowIndex}`)
    }
    .width('100%')
  }

  @Builder
  private LibraryGridEven(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
  }

  @Builder
  private LibraryGridOdd(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
  }

  private shouldShowCoverUri(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId)) < 0
  }

  private markCoverUriFailed(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId)
    if (normalized.length > 0 && this.failedCoverUris.indexOf(failureKey) < 0) {
      this.failedCoverUris = this.failedCoverUris.concat([failureKey])
    }
  }

  private isSourceAwareCover(comic: ComicCoverInfo): boolean {
    const sourceRuntimeId = comic.sourceRuntimeId?.trim() ?? ''
    const coverUri = comic.coverUri?.toLocaleLowerCase() ?? ''
    return sourceRuntimeId.length > 0 && (coverUri.startsWith('http://') || coverUri.startsWith('https://'))
  }

  private sourceImageIdForComic(comic: ComicCoverInfo): string {
    return comic.sourceImageId ?? comic.id
  }

  @Builder
  private LibraryListCover(comic: ComicCoverInfo) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldShowCoverUri(comic.coverUri, comic.sourceRuntimeId, this.sourceImageIdForComic(comic))) {
        if (this.isSourceAwareCover(comic)) {
          CachedCoverImage({
            uri: comic.coverUri ?? '',
            objectFit: ImageFit.Cover,
            sourceRuntimeId: comic.sourceRuntimeId ?? '',
            sourceImageId: this.sourceImageIdForComic(comic),
            onError: () => {
              this.markCoverUriFailed(comic.coverUri, comic.sourceRuntimeId, this.sourceImageIdForComic(comic))
            },
          })
        } else {
          Image(comic.coverUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .interpolation(ImageInterpolation.Medium)
            .onError(() => {
              this.markCoverUriFailed(comic.coverUri, comic.sourceRuntimeId, this.sourceImageIdForComic(comic))
            })
        }
      } else {
        Text('K')
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
    }
    .width(this.libraryListCoverWidth())
    .height(this.libraryListCoverHeight())
    .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
    .clip(true)
    .backgroundColor(comic.coverColor)
  }

  @Builder
  private LibraryList(comics: ComicCoverInfo[]) {
    Column({ space: this.libraryListSpace() }) {
      ForEach(comics, (comic: ComicCoverInfo) => {
        Stack({ alignContent: Alignment.TopEnd }) {
          ConciseListRow({
            title: comic.title,
            subtitle: this.listRowSubtitle(comic),
            trailingText: comic.progressText,
            showChevron: false,
            isEnabled: !this.selectionMode || this.canSelectComic(comic.id),
            action: () => {
              this.handleComicClick(comic.id)
            },
            prefixBuilderParam: () => {
              this.LibraryListCover(comic)
            },
          })
            .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
            .borderRadius(ThemeConstants.LIST_ROW_RADIUS)
            .backgroundColor(this.isComicSelected(comic.id) ? ThemeConstants.SOFT_TINT : ThemeConstants.CARD)
            .onTouch((event: TouchEvent) => {
              this.handleComicTouch(comic.id, event)
            })

          if (!this.selectionMode && this.canRemoveComic(comic.id)) {
            KomaIconButton({
              icon: $r('sys.symbol.more'),
              kind: 'secondary',
              controlSize: ThemeConstants.TOUCH_TARGET_SM,
              iconSize: ThemeConstants.FONT_SIZE_H3,
            })
              .margin({ top: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
              .bindMenu(this.ComicActionMenu(comic))
          }
        }
        .width('100%')
      }, (comic: ComicCoverInfo) => this.listRowRenderKey(comic))
    }
    .width('100%')
  }

  aboutToAppear(): void {
    this.syncDisplayedSnapshotFromProps()
    this.reloadPersistentSessionStore('appear')
    void this.restoreFilterPreferences()
  }

  onBackPress(): boolean {
    if (this.selectionMode) {
      this.exitSelectionMode()
      return true
    }
    return false
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.hasLibraryContent()) {
          if (this.hasVisibleLibraryContent()) {
            ListItem() {
              ContinueReadingShelfCard({
                info: this.viewModel().continueReading,
                revision: this.displayedRevision,
                onOpenReader: (comicId: ComicId) => {
                  if (!this.selectionMode) {
                    void this.openComicFromLibrary(comicId)
                  }
                },
              })
            }
          }

          if (this.selectionMode) {
            ListItem() {
              this.BatchActionBar()
            }
          }

          ListItem() {
            Row() {
              Text(s('tab_library'))
                .fontSize(ThemeConstants.FONT_SIZE_H3)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
              Blank()
              Text(s('library_count_books').replace('%s', `${this.viewModel().comics.length}`))
                .fontSize(ThemeConstants.FONT_SIZE_META)
                .fontColor(ThemeConstants.TEXT_SECONDARY)
              KomaIconButton({
                icon: $r('sys.symbol.plus'),
                kind: 'secondary',
                controlSize: ThemeConstants.TOUCH_TARGET_SM,
                iconSize: ThemeConstants.FONT_SIZE_H2,
                isEnabled: !this.selectionMode,
                action: () => {
                  if (!this.selectionMode) {
                    this.onImportRequested()
                  }
                },
              })
                .margin({ left: 10 })
            }
            .width('100%')
          }

          ListItem() {
            this.SortFilterBar()
          }

          if (this.hasVisibleLibraryContent()) {
            ListItem() {
              if (this.viewMode === 'list') {
                this.LibraryList(this.gridComics())
              } else if (this.isEvenDisplayedRevision()) {
                this.LibraryGridEven(this.gridComics())
              } else {
                this.LibraryGridOdd(this.gridComics())
              }
            }
          } else {
            ListItem() {
              this.EmptyFilteredLibrary()
            }
          }
        } else {
          ListItem() {
            this.EmptyLibrary()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
