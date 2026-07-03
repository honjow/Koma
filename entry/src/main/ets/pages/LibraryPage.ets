import { common } from '@kit.AbilityKit'
import { Chip, ChipSize } from '@kit.ArkUI'
import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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
  LibrarySourceFilter,
} from '../model/LibraryFilterStore'
import { OfflineDownloadQueueEntry, OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
import { OfflineDownloadStatus } from '../model/OfflineDownloadStore'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import { isRemovableLocalComic } from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter,
  InMemoryReaderSessionStore,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'
import {
  AppFilesChapterReadStatePersistenceAdapter,
  ChapterReadStateStore,
} from '../model/ChapterReadStateStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
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
  @Event onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(ThemeConstants.SPACE_XXL)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
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
  @Local private sortBy: LibrarySortBy = 'lastRead'
  @Local private filterSource: LibrarySourceFilter = 'all'
  @Local private filterReadState: LibraryReadStateFilter = 'all'
  @Local private filterCategory: LibraryCategoryFilter = 'all'
  @Local private filterAvailability: LibraryAvailabilityFilter = 'all'
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  @Param presentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
  private sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Event onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  @Event onImportRequested: () => void = () => {}
  @Event onRemoveComicRequested: (comicId: ComicId) => boolean = (_comicId: ComicId) => false
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
      const e = error as Error
      console.info('[Library] step=progress_reload_failed reason=' + e.message)
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
    this.displayedComics = this.filterAvailabilityComics(this.filterPreciseSourceComics(nextComics))
    this.displayedRevision += 1
    this.removeMissingSelectedComics()
  }

  private filterAvailabilityComics(comics: Comic[]): Comic[] {
    if (this.filterAvailability === 'all') {
      return comics
    }
    const downloadedComicIds = this.downloadedComicIds()
    if (this.filterAvailability === 'downloaded') {
      return comics.filter((comic: Comic): boolean => downloadedComicIds.has(comic.id))
    }
    return comics.filter((comic: Comic): boolean => !downloadedComicIds.has(comic.id))
  }

  private downloadedComicIds(): Set<ComicId> {
    const comicIds = new Set<ComicId>()
    try {
      const context = getContext(this) as common.UIAbilityContext
      const entries = new OfflineDownloadQueueStore(context.filesDir).reconcileWithManifests()
      entries.forEach((entry: OfflineDownloadQueueEntry) => {
        if (entry.status === OfflineDownloadStatus.DOWNLOADED || entry.status === OfflineDownloadStatus.PARTIAL) {
          comicIds.add(entry.comicId)
        }
      })
    } catch (error) {
      const e = error as Error
      console.info('[Library] step=download_filter_load_failed reason=' + e.message)
    }
    return comicIds
  }

  private filterPreciseSourceComics(comics: Comic[]): Comic[] {
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
    if (this.filterSource === 'local') {
      return [ComicSourceKind.LOCAL_ARCHIVE, ComicSourceKind.LOCAL_FOLDER]
    }
    if (this.filterSource === 'private') {
      return [
        ComicSourceKind.PRIVATE_LIBRARY,
        ComicSourceKind.KOMGA_REMOTE,
        ComicSourceKind.OPDS_REMOTE,
        ComicSourceKind.WEBDAV_REMOTE,
      ]
    }
    if (this.filterSource === 'komga') {
      return [ComicSourceKind.KOMGA_REMOTE]
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
      this.filterSource = preferencesValue.source
      this.filterReadState = preferencesValue.readState
      this.filterCategory = preferencesValue.category
      this.filterAvailability = preferencesValue.availability
      this.applyCategoryDisplayStrategy(this.validCategoryFilter())
      this.refreshDisplayedSnapshotFromStore()
      console.info(
        `[Library] step=filter_restored sortBy=${this.sortBy} source=${this.filterSource} readState=${this.filterReadState} category=${this.filterCategory} availability=${this.filterAvailability}`
      )
    } catch (error) {
      const e = error as Error
      console.info('[Library] step=filter_restore_failed reason=' + e.message)
    }
  }

  private saveFilterPreferences(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const preferencesValue: LibraryFilterPreferences = {
        sortBy: this.sortBy,
        source: this.filterSource,
        readState: this.filterReadState,
        category: this.filterCategory,
        availability: this.filterAvailability,
      }
      void new LibraryFilterStore(context).save(preferencesValue)
    } catch (error) {
      const e = error as Error
      console.info('[Library] step=filter_save_failed reason=' + e.message)
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
    if (this.filterSource === 'local') {
      return s('library_source_local')
    }
    if (this.filterSource === 'private') {
      return s('library_source_private')
    }
    if (this.filterSource === 'komga') {
      return s('route_komga_title')
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
    if (this.filterAvailability === 'not_downloaded') {
      return s('library_availability_not_downloaded')
    }
    return s('library_availability_all')
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
        categoryLabels: sourceComic === undefined ? comic.categoryLabels : this.categoryLabelsForComic(sourceComic),
      }
    })
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
      this.onOpenReader(comicId)
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
    let removedCount = 0
    comicIds.forEach((comicId: ComicId) => {
      if (this.onRemoveComicRequested(comicId)) {
        removedCount += 1
      }
    })
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
      const e = error as Error
      console.info('[Library] step=batch_read_state_store_failed reason=' + e.message)
      return undefined
    }
  }

  private markSelectedReadState(isRead: boolean): void {
    const comicIds = Array.from(this.selectedIds)
    if (comicIds.length === 0) {
      return
    }
    const readStateStore = this.chapterReadStateStore()
    if (readStateStore === undefined) {
      return
    }
    let changedCount = 0
    comicIds.forEach((comicId: ComicId) => {
      const comic = this.libraryStore.getComic(comicId)
      if (comic === undefined || comic.chapters.length === 0) {
        return
      }
      comic.chapters.forEach((chapter: Chapter) => {
        if (readStateStore.mark(comic.id, chapter.id, isRead) !== undefined) {
          changedCount += 1
        }
      })
      if (isRead) {
        this.sessionStore.saveProgress(this.completedProgressForComic(comic))
      } else {
        this.sessionStore.removeProgress(comic.id)
      }
    })
    if (changedCount > 0) {
      console.info(`[Library] step=batch_read_state isRead=${isRead} comics=${comicIds.length} chapters=${changedCount}`)
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
      MenuItem({ content: s('route_opds_title') })
        .onClick(() => {
          this.setSourceFilter('opds')
        })
      MenuItem({ content: s('route_webdav_title') })
        .onClick(() => {
          this.setSourceFilter('webdav')
        })
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
      MenuItem({ content: s('library_availability_not_downloaded') })
        .onClick(() => {
          this.setAvailabilityFilter('not_downloaded')
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
      MenuItem({ content: s('library_batch_remove_favorite') })
        .onClick(() => {
          this.removeSelectedCategory(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      MenuItem({ content: s('library_batch_add_read_later') })
        .onClick(() => {
          this.addSelectedCategory(LIBRARY_CATEGORY_READ_LATER_ID)
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
    Flex({ wrap: FlexWrap.Wrap }) {
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
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
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
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
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
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
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
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .bindMenu(this.AvailabilityMenu())
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
      .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .bindMenu(this.CategoryMenu())
    }
    .width('100%')
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
  private LibraryGrid(comics: ComicCoverInfo[]) {
    Grid() {
      ForEach(comics, (comic: ComicCoverInfo) => {
        GridItem() {
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
                      this.onOpenReader(comic.id)
                    }
                  }))
            }
          }
          .width('100%')
        }
      }, (comic: ComicCoverInfo) => this.comicRenderKey(comic))
    }
    .width('100%')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(14)
    .rowsGap(22)
  }

  @Builder
  private LibraryGridEven(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
  }

  @Builder
  private LibraryGridOdd(comics: ComicCoverInfo[]) {
    this.LibraryGrid(comics)
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
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        if (this.hasLibraryContent()) {
          if (this.hasVisibleLibraryContent()) {
            ListItem() {
              ContinueReadingShelfCard({
                info: this.viewModel().continueReading,
                revision: this.displayedRevision,
                onOpenReader: (comicId: ComicId) => {
                  if (!this.selectionMode) {
                    this.onOpenReader(comicId)
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
              if (this.isEvenDisplayedRevision()) {
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
