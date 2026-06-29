import { common } from '@kit.AbilityKit'
import { Chip, ChipSize } from '@kit.ArkUI'
import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
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
  Comic,
  ComicId,
  ComicSourceKind,
  CustomLibraryCategory,
  LibraryItem,
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
  LibraryFilterPreferences,
  LibraryFilterStore,
  LibrarySourceFilter,
} from '../model/LibraryFilterStore'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import { isRemovableLocalComic } from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter,
  InMemoryReaderSessionStore,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'

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
        Text('继续阅读')
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
  @Local private displayedComics: Comic[] = createSeededLibraryStore().listComics()
  @Local private displayedRevision: number = 0
  @Local private selectionMode: boolean = false
  @Local private selectedIds: Set<ComicId> = new Set<ComicId>()
  @Local private suppressOpenComicId: ComicId = ''
  @Local private sortBy: LibrarySortBy = 'lastRead'
  @Local private filterSource: LibrarySourceFilter = 'all'
  @Local private filterReadState: LibraryReadStateFilter = 'all'
  @Local private filterCategory: LibraryCategoryFilter = 'all'
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
    this.displayedComics = nextComics
    this.displayedRevision += 1
    this.removeMissingSelectedComics()
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
      this.applyCategoryDisplayStrategy(this.validCategoryFilter())
      this.refreshDisplayedSnapshotFromStore()
      console.info(
        `[Library] step=filter_restored sortBy=${this.sortBy} source=${this.filterSource} readState=${this.filterReadState} category=${this.filterCategory}`
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
      return '最近加入'
    }
    if (this.sortBy === 'title') {
      return '标题'
    }
    if (this.sortBy === 'source') {
      return '来源'
    }
    return '最近阅读'
  }

  private sourceLabel(): string {
    if (this.filterSource === 'local') {
      return '本地'
    }
    if (this.filterSource === 'komga') {
      return 'Komga'
    }
    if (this.filterSource === 'opds') {
      return 'OPDS'
    }
    if (this.filterSource === 'webdav') {
      return 'WebDAV'
    }
    if (this.filterSource === 'wasm') {
      return 'wasm'
    }
    return '全部来源'
  }

  private readStateLabel(): string {
    if (this.filterReadState === 'unread') {
      return '未读'
    }
    if (this.filterReadState === 'reading') {
      return '读过'
    }
    if (this.filterReadState === 'completed') {
      return '已完成'
    }
    return '全部状态'
  }

  private categoryLabel(): string {
    if (this.filterCategory === 'uncategorized') {
      return '未分类'
    }
    if (this.filterCategory === LIBRARY_CATEGORY_READ_LATER_ID) {
      return '稍后阅读'
    }
    if (this.filterCategory === LIBRARY_CATEGORY_FAVORITE_ID) {
      return '收藏'
    }
    const customCategory = this.libraryStore.listCustomCategories().find((category: CustomLibraryCategory): boolean => {
      return category.id === this.filterCategory
    })
    if (customCategory !== undefined) {
      return customCategory.name
    }
    return '全部分类'
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
        labels.push('收藏')
      } else if (categoryId === LIBRARY_CATEGORY_READ_LATER_ID) {
        labels.push('稍后阅读')
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
    if (!this.canRemoveComic(comicId)) {
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
    if (!this.canRemoveComic(comicId)) {
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
    if (!this.canRemoveComic(comicId)) {
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
      if (this.canRemoveComic(comic.id)) {
        nextSelectedIds.add(comic.id)
      }
    })
    this.selectedIds = nextSelectedIds
    this.selectionMode = this.selectedIds.size > 0
  }

  private selectedCount(): number {
    return this.selectedIds.size
  }

  private removeSelectedComics(): void {
    const comicIds = Array.from(this.selectedIds)
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

  private showBatchRemoveConfirmation(): void {
    const count = this.selectedCount()
    if (count === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '批量移出书架',
      message: `从书架中移出已选的 ${count} 本漫画？`,
      autoCancel: true,
      primaryButton: {
        value: '移出',
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeSelectedComics()
        },
      },
      secondaryButton: {
        value: '取消',
        action: () => {},
      },
    })
  }

  private showRemoveConfirmation(comic: ComicCoverInfo): void {
    if (!this.canRemoveComic(comic.id)) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: '移出书架',
      message: `从书架中移出《${comic.title}》？`,
      autoCancel: true,
      primaryButton: {
        value: '移出',
        fontColor: ThemeConstants.DANGER,
        action: () => {
          if (this.onRemoveComicRequested(comic.id)) {
            this.refreshDisplayedSnapshotFromStore()
          }
        },
      },
      secondaryButton: {
        value: '取消',
        action: () => {},
      },
    })
  }

  @Builder
  private ComicActionMenu(comic: ComicCoverInfo) {
    Menu() {
      if (this.canRemoveComic(comic.id)) {
        MenuItem({ content: '选择' })
          .onClick(() => {
            this.enterSelectionMode(comic.id)
          })
        MenuItem({ content: '移出书架' })
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
      MenuItem({ content: '最近阅读' })
        .onClick(() => {
          this.setSortBy('lastRead')
        })
      MenuItem({ content: '最近加入' })
        .onClick(() => {
          this.setSortBy('added')
        })
      MenuItem({ content: '标题' })
        .onClick(() => {
          this.setSortBy('title')
        })
      MenuItem({ content: '来源' })
        .onClick(() => {
          this.setSortBy('source')
        })
    }
  }

  @Builder
  private SourceMenu() {
    Menu() {
      MenuItem({ content: '全部' })
        .onClick(() => {
          this.setSourceFilter('all')
        })
      MenuItem({ content: '本地' })
        .onClick(() => {
          this.setSourceFilter('local')
        })
      MenuItem({ content: 'Komga' })
        .onClick(() => {
          this.setSourceFilter('komga')
        })
      MenuItem({ content: 'OPDS' })
        .onClick(() => {
          this.setSourceFilter('opds')
        })
      MenuItem({ content: 'WebDAV' })
        .onClick(() => {
          this.setSourceFilter('webdav')
        })
      MenuItem({ content: 'wasm' })
        .onClick(() => {
          this.setSourceFilter('wasm')
        })
    }
  }

  @Builder
  private ReadStateMenu() {
    Menu() {
      MenuItem({ content: '全部' })
        .onClick(() => {
          this.setReadStateFilter('all')
        })
      MenuItem({ content: '未读' })
        .onClick(() => {
          this.setReadStateFilter('unread')
        })
      MenuItem({ content: '读过' })
        .onClick(() => {
          this.setReadStateFilter('reading')
        })
      MenuItem({ content: '已完成' })
        .onClick(() => {
          this.setReadStateFilter('completed')
        })
    }
  }

  @Builder
  private CategoryMenu() {
    Menu() {
      MenuItem({ content: '全部' })
        .onClick(() => {
          this.setCategoryFilter('all')
        })
      MenuItem({ content: '未分类' })
        .onClick(() => {
          this.setCategoryFilter('uncategorized')
        })
      MenuItem({ content: '稍后阅读' })
        .onClick(() => {
          this.setCategoryFilter(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      MenuItem({ content: '收藏' })
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
      MenuItem({ content: '加入收藏' })
        .onClick(() => {
          this.addSelectedCategory(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      MenuItem({ content: '移出收藏' })
        .onClick(() => {
          this.removeSelectedCategory(LIBRARY_CATEGORY_FAVORITE_ID)
        })
      MenuItem({ content: '加入稍后' })
        .onClick(() => {
          this.addSelectedCategory(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      MenuItem({ content: '移出稍后' })
        .onClick(() => {
          this.removeSelectedCategory(LIBRARY_CATEGORY_READ_LATER_ID)
        })
      ForEach(this.libraryStore.listCustomCategories(), (category: CustomLibraryCategory) => {
        MenuItem({ content: `加入${category.name}` })
          .onClick(() => {
            this.addSelectedCategory(category.id)
          })
        MenuItem({ content: `移出${category.name}` })
          .onClick(() => {
            this.removeSelectedCategory(category.id)
          })
      }, (category: CustomLibraryCategory) => category.id)
      MenuItem({ content: '清除分类' })
        .onClick(() => {
          this.assignSelectedCategory(undefined)
        })
    }
  }


  @Builder
  private SortFilterBar() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Row() {
        Chip({
          label: {
            text: `排序 ${this.sortLabel()} ▾`,
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
    }
    .width('100%')
  }

  @Builder
  private EmptyLibrary() {
    KomaEmptyState({
      title: '还没有漫画',
      message: '导入本地 CBZ 或 ZIP 后会显示在书架中。',
      actionLabel: '导入',
      showAction: true,
      action: () => {
        this.onImportRequested()
      },
    })
  }

  @Builder
  private EmptyFilteredLibrary() {
    KomaEmptyState({
      title: '没有符合条件的漫画',
      message: '调整排序或筛选条件后再试。',
    })
  }

  @Builder
  private BatchActionBar() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text(`已选 ${this.selectedCount()}`)
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .layoutWeight(1)

      KomaActionButton({
        label: '全选',
        kind: 'secondary',
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.selectAllVisibleComics()
        },
      })

      KomaActionButton({
        label: '取消',
        kind: 'secondary',
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.exitSelectionMode()
        },
      })

      KomaActionButton({
        label: '分类 ▾',
        kind: 'primary',
        isEnabled: this.selectedCount() > 0,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
      })
        .bindMenu(this.BatchCategoryMenu())

      KomaActionButton({
        label: '删除',
        kind: 'danger',
        isEnabled: this.selectedCount() > 0,
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
                Button('…')
                  .width(ThemeConstants.TOUCH_TARGET_SM)
                  .height(ThemeConstants.TOUCH_TARGET_SM)
                  .borderRadius(ThemeConstants.RADIUS_CHIP)
                  .fontSize(ThemeConstants.FONT_SIZE_H3)
                  .fontColor(ThemeConstants.TEXT_PRIMARY)
                  .backgroundColor(ThemeConstants.CARD)
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
              Text('书架')
                .fontSize(ThemeConstants.FONT_SIZE_H3)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
              Blank()
              Text(`${this.viewModel().comics.length} 本`)
                .fontSize(ThemeConstants.FONT_SIZE_META)
                .fontColor(ThemeConstants.TEXT_SECONDARY)
              Button('+')
                .width(ThemeConstants.TOUCH_TARGET_SM)
                .height(ThemeConstants.TOUCH_TARGET_SM)
                .borderRadius(ThemeConstants.RADIUS_CHIP)
                .fontSize(ThemeConstants.FONT_SIZE_H2)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .backgroundColor(ThemeConstants.CARD)
                .margin({ left: 10 })
                .enabled(!this.selectionMode)
                .onClick(() => {
                  if (!this.selectionMode) {
                    this.onImportRequested()
                  }
                })
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
