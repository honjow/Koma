import { common } from '@kit.AbilityKit'
import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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
  LibraryItem,
  ReadingProgress,
  LIBRARY_CATEGORY_FAVORITE_ID,
  LIBRARY_CATEGORY_READ_LATER_ID,
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
import { StorageKeys } from '../constants/StorageKeys'
import { isRemovableLocalComic } from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter,
  InMemoryReaderSessionStore,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'

@Component
struct ContinueReadingShelfCard {
  @Prop info: ContinueReadingCardViewModel = {
    title: '',
    detail: '',
    progress: 0,
    color: '#16745F',
    comicId: '',
  }
  @Prop revision: number = 0
  onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}

  build() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(76)
      .height(102)
      .borderRadius(18)
      .backgroundColor(this.info.color)

      Column({ space: 8 }) {
        Text('继续阅读')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_accent'))
        Text(this.info.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.info.detail)
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: this.info.progress, total: 100, type: ProgressType.Linear })
          .height(4)
          .color($r('app.color.koma_accent'))
          .backgroundColor('#1FE66A3A')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.onOpenReader(this.info.comicId)
    })
  }
}

@Component
export struct LibraryPage {
  libraryStore: LibraryStore = createSeededLibraryStore()
  @Prop @Watch('syncDisplayedSnapshotFromProps') libraryComics: Comic[] = createSeededLibraryStore().listComics()
  @Prop @Watch('syncDisplayedSnapshotFromProps') libraryRevision: number = 0
  @State private displayedComics: Comic[] = createSeededLibraryStore().listComics()
  @State private displayedRevision: number = 0
  @State private selectionMode: boolean = false
  @State private selectedIds: Set<ComicId> = new Set<ComicId>()
  @State private suppressOpenComicId: ComicId = ''
  @State private sortBy: LibrarySortBy = 'lastRead'
  @State private filterSource: LibrarySourceFilter = 'all'
  @State private filterReadState: LibraryReadStateFilter = 'all'
  @State private filterCategory: LibraryCategoryFilter = 'all'
  @StorageProp(StorageKeys.REMOTE_PROGRESS_SYNC_REV) @Watch('onRemoteProgressSyncRevChanged') remoteProgressSyncRev: number = 0
  presentationByComicId: LibraryPresentationByComicId = createMockLibraryPresentationMap()
  sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  onOpenReader: (comicId: ComicId) => void = (_comicId: ComicId) => {}
  onImportRequested: () => void = () => {}
  onRemoveComicRequested: (comicId: ComicId) => boolean = (_comicId: ComicId) => false
  onAssignCategoriesRequested: (comicIds: ComicId[], categoryIds?: string[]) => boolean =
    (_comicIds: ComicId[], _categoryIds?: string[]) => false
  private longPressTimer: number = 0
  private longPressComicId: ComicId = ''

  private syncDisplayedSnapshotFromProps(): void {
    this.refreshDisplayedSnapshotFromStore()
    this.displayedRevision = this.libraryRevision
    this.removeMissingSelectedComics()
  }

  private onRemoteProgressSyncRevChanged(): void {
    void this.remoteProgressSyncRev
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
      filterCategoryId: this.filterCategory,
    }
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
    this.refreshDisplayedSnapshotFromStore()
    this.saveFilterPreferences()
    console.info(`[Library] step=filter_changed category=${category}`)
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
    return '全部分类'
  }

  private viewModel(): LibraryViewModel {
    return createLibraryViewModelFromComics(this.displayedComics, this.sessionStore, this.presentationByComicId)
  }

  private gridComics(): ComicCoverInfo[] {
    return this.viewModel().comics.map((comic: ComicCoverInfo): ComicCoverInfo => {
      return {
        id: comic.id,
        title: comic.title,
        subtitle: comic.subtitle,
        progressText: comic.progressText,
        coverColor: comic.coverColor,
        accentColor: comic.accentColor,
        pageCount: comic.pageCount,
        coverUri: comic.coverUri,
      }
    })
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
        fontColor: $r('app.color.koma_danger'),
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
        fontColor: $r('app.color.koma_danger'),
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
          .contentFontColor($r('app.color.koma_danger'))
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
    }
  }


  @Builder
  private SortFilterBar() {
    Row({ space: 8 }) {
      Button(`排序 ${this.sortLabel()} ▾`)
        .height(34)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.sortBy !== 'lastRead' ? Color.White : $r('app.color.koma_text_primary'))
        .backgroundColor(this.sortBy !== 'lastRead' ? $r('app.color.koma_accent') : $r('app.color.koma_card'))
        .bindMenu(this.SortMenu())
      Button(`${this.sourceLabel()} ▾`)
        .height(34)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.filterSource !== 'all' ? Color.White : $r('app.color.koma_text_primary'))
        .backgroundColor(this.filterSource !== 'all' ? $r('app.color.koma_accent') : $r('app.color.koma_card'))
        .bindMenu(this.SourceMenu())
      Button(`${this.readStateLabel()} ▾`)
        .height(34)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.filterReadState !== 'all' ? Color.White : $r('app.color.koma_text_primary'))
        .backgroundColor(this.filterReadState !== 'all' ? $r('app.color.koma_accent') : $r('app.color.koma_card'))
        .bindMenu(this.ReadStateMenu())
      Button(`${this.categoryLabel()} ▾`)
        .height(34)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(13)
        .fontColor(this.filterCategory !== 'all' ? Color.White : $r('app.color.koma_text_primary'))
        .backgroundColor(this.filterCategory !== 'all' ? $r('app.color.koma_accent') : $r('app.color.koma_card'))
        .bindMenu(this.CategoryMenu())
    }
    .width('100%')
  }

  @Builder
  private EmptyLibrary() {
    Column({ space: 12 }) {
      Text('还没有漫画')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('导入本地 CBZ 或 ZIP 后会显示在书架中。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
      Button('导入')
        .height(40)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .fontSize(15)
        .backgroundColor($r('app.color.koma_accent'))
        .onClick(() => {
          this.onImportRequested()
        })
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private EmptyFilteredLibrary() {
    Column({ space: 10 }) {
      Text('没有符合条件的漫画')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('调整排序或筛选条件后再试。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private BatchActionBar() {
    Row({ space: 10 }) {
      Text(`已选 ${this.selectedCount()}`)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
        .layoutWeight(1)

      Button('全选')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#0F000000')
        .onClick(() => {
          this.selectAllVisibleComics()
        })

      Button('取消')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#0F000000')
        .onClick(() => {
          this.exitSelectionMode()
        })

      Button('稍后阅读')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_accent'))
        .enabled(this.selectedCount() > 0)
        .onClick(() => {
          this.assignSelectedCategory([LIBRARY_CATEGORY_READ_LATER_ID])
        })

      Button('收藏')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_accent'))
        .enabled(this.selectedCount() > 0)
        .onClick(() => {
          this.assignSelectedCategory([LIBRARY_CATEGORY_FAVORITE_ID])
        })

      Button('清除分类')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .backgroundColor('#0F000000')
        .enabled(this.selectedCount() > 0)
        .onClick(() => {
          this.assignSelectedCategory(undefined)
        })

      Button('删除')
        .height(36)
        .padding({ left: 12, right: 12 })
        .borderRadius(8)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_danger'))
        .enabled(this.selectedCount() > 0)
        .onClick(() => {
          this.showBatchRemoveConfirmation()
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
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
                  .width(32)
                  .height(32)
                  .borderRadius(8)
                  .fontSize(20)
                  .fontColor($r('app.color.koma_text_primary'))
                  .backgroundColor($r('app.color.koma_card'))
                  .margin({ top: 8, right: 8 })
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
        listSpace: 20,
        horizontalPadding: 20,
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
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.koma_text_primary'))
              Blank()
              Text(`${this.viewModel().comics.length} 本`)
                .fontSize(13)
                .fontColor($r('app.color.koma_text_secondary'))
              Button('+')
                .width(36)
                .height(36)
                .borderRadius(8)
                .fontSize(22)
                .fontColor($r('app.color.koma_text_primary'))
                .backgroundColor($r('app.color.koma_card'))
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
