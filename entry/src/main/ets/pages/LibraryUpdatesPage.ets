import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { Chapter, Comic, ComicSourceKind } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { ChapterReadMutation, ReaderSessionStore } from '../model/ReaderSessionStore'
import { OfflineDownloadChapterBatch, OfflineDownloadQueueStore } from '../model/OfflineDownloadQueueStore'
import { OfflineDownloadService } from '../model/OfflineDownloadService'
import { ensureKomaContentStorageBase, komaRuntimeStorageKey } from '../model/KomaContentStorage'
import { LibraryUpdatesChrome } from '../state/LibraryUpdatesChrome'
import { komaDialogMaterial, komaToastOptions } from '../theme/KomaPopupOptions'
import { LibraryChapterUpdate, cachedLibraryChapterUpdates } from '../model/LibraryChapterUpdates'
import { cachedLibraryUpdateFailureDetails, LibraryUpdateFailureDetails,
  LibraryUpdateResultStore } from '../model/LibraryUpdateResultStore'
import { LibraryUpdateComicResult } from '../model/LibraryUpdateService'
import { libraryUpdateComicTitle, libraryUpdateFailureText } from '../model/LibraryUpdatePresentation'
import { connectLibraryUpdateState, LibraryUpdateState } from '../state/LibraryUpdateState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { PullRefreshController } from '../components/PullRefresh'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaModalScaffold, komaModalSheetOptions } from '../components/KomaModalScaffold'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { ThemeConstants } from '../theme/ThemeConstants'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

interface ChapterUpdateRow { comic: Comic; chapter: Chapter; discoveredAt: number }

function updateRowKey(row: ChapterUpdateRow): string {
  return JSON.stringify([row.comic.id, row.chapter.id])
}

function canDownloadUpdate(row: ChapterUpdateRow): boolean {
  return row.comic.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE && row.comic.sourceKind !== ComicSourceKind.LOCAL_FOLDER
}

@ComponentV2
export struct LibraryUpdatesPage {
  @Param @Require libraryStore: LibraryStore
  @Param @Require chrome: LibraryUpdatesChrome
  @Param libraryRevision: number = 0
  @Param readerSessionStore?: ReaderSessionStore = undefined
  @Param readerProgressRevision: number = 0
  @Event onOpenReader: (comicId: string, chapterId: string) => void = () => {}
  @Event onOpenComic: (comicId: string) => void = () => {}
  @Event onRefresh: () => Promise<void> = async () => {}
  @Event onReadingStateChanged: () => void = () => {}
  @Param refreshController: PullRefreshController = new PullRefreshController()
  @Local private refreshing: boolean = false
  @Local private updateState: LibraryUpdateState = connectLibraryUpdateState()
  @Local private language: LanguageState = connectLanguageState()
  @Local private records: LibraryChapterUpdate[] = cachedLibraryChapterUpdates() ?? []
  @Local private loading: boolean = cachedLibraryChapterUpdates() === undefined
  @Local private error: boolean = false
  @Local private failures: LibraryUpdateFailureDetails = cachedLibraryUpdateFailureDetails()
  @Local private openedFailures: LibraryUpdateFailureDetails = { results: [] }
  @Local private failuresShown: boolean = false
  @Local private visibleLimit: number = 80
  private loadRevision: number = 0

  aboutToAppear(): void { this.reload() }
  aboutToDisappear(): void { this.loadRevision += 1 }

  @Monitor('updateState.revision')
  private reload(): void {
    const revision = ++this.loadRevision
    const store = new LibraryUpdateResultStore(getContext(this) as common.UIAbilityContext)
    void store.loadChapterUpdates()
      .then((records: LibraryChapterUpdate[]): void => {
        if (revision !== this.loadRevision) return
        this.records = records; this.loading = false; this.error = false
      }).catch((): void => {
        if (revision !== this.loadRevision) return
        this.loading = false; this.error = true
      })
    void store.loadFailureDetails().then((failures: LibraryUpdateFailureDetails): void => {
      if (revision === this.loadRevision) this.failures = failures
    })
  }

  private day(value: number): string {
    return new Intl.DateTimeFormat(this.language.effectiveLocale,
      { year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(value))
  }

  @Computed
  private get rows(): ChapterUpdateRow[] {
    void this.libraryRevision
    const rows: ChapterUpdateRow[] = []
    const chaptersByComic = new Map<string, Map<string, Chapter>>()
    this.records.forEach((record: LibraryChapterUpdate): void => {
      const comic = this.libraryStore.getComic(record.comicId)
      if (comic !== undefined && !chaptersByComic.has(comic.id)) {
        const chapters = new Map<string, Chapter>()
        comic.chapters.forEach((chapter: Chapter): void => { chapters.set(chapter.id, chapter) })
        chaptersByComic.set(comic.id, chapters)
      }
      const chapter = chaptersByComic.get(record.comicId)?.get(record.chapterId)
      if (comic !== undefined && chapter !== undefined) rows.push({ comic, chapter, discoveredAt: record.discoveredAt })
    })
    return rows
  }

  @Computed
  private get rowsByDay(): Record<string, ChapterUpdateRow[]> {
    const groups: Record<string, ChapterUpdateRow[]> = {}
    this.filteredRows.slice(0, this.visibleLimit).forEach((row: ChapterUpdateRow): void => {
      const date = this.day(row.discoveredAt)
      if (groups[date] === undefined) groups[date] = []
      groups[date].push(row)
    })
    return groups
  }

  @Computed
  private get days(): string[] { return Object.keys(this.rowsByDay) }

  @Computed
  private get filteredRows(): ChapterUpdateRow[] {
    void this.readerProgressRevision
    return this.chrome.unreadOnly ? this.rows.filter((row: ChapterUpdateRow): boolean =>
      !this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id)) : this.rows
  }

  @Monitor('filteredRows', 'chrome.selectedKeys')
  private reconcileSelection(): void {
    const keys = this.chrome.selectedKeys
    const retained = new Set(this.filteredRows.map(updateRowKey).filter((key: string): boolean => keys.has(key)))
    if (retained.size !== keys.size) this.chrome.selectedKeys = retained
    this.chrome.allSelected = retained.size > 0 && retained.size === this.filteredRows.length
  }

  private toggleSelection(row: ChapterUpdateRow): void {
    if (this.chrome.busy) return
    this.chrome.selecting = true
    const keys = new Set(this.chrome.selectedKeys)
    const key = updateRowKey(row)
    if (keys.has(key)) keys.delete(key)
    else keys.add(key)
    this.chrome.selectedKeys = keys
  }

  @Monitor('chrome.requestRevision')
  private handleAction(): void {
    if (!this.chrome.selecting || this.chrome.busy) return
    if (this.chrome.action === 'toggleAll') {
      this.chrome.selectedKeys = new Set(this.chrome.allSelected ? [] : this.filteredRows.map(updateRowKey))
      return
    }
    const selected = this.filteredRows.filter((row: ChapterUpdateRow): boolean =>
      this.chrome.selectedKeys.has(updateRowKey(row)))
    if (selected.length === 0) return
    const downloading = this.chrome.action === 'download'
    const targets = downloading ? selected.filter(canDownloadUpdate) : selected.filter((row: ChapterUpdateRow): boolean =>
      !this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id))
    if (targets.length === 0) {
      this.toast(downloading ? 'manga_detail_no_matching_chapters' : 'manga_detail_no_markable_chapters')
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(), autoCancel: true,
      title: AppStrings.get(downloading ? 'manga_detail_action_download_chapter' : 'chapter_list_menu_mark_read'),
      message: AppStrings.get(downloading ? 'downloads_confirm_chapters' : 'manga_detail_mark_selected_read_confirm')
        .replace('%s', `${targets.length}`),
      primaryButton: { value: AppStrings.get('common_cancel'), action: () => {} },
      secondaryButton: { value: AppStrings.get('common_confirm'), action: () => {
        if (downloading) void this.downloadSelected(targets)
        else this.markSelectedRead(targets)
      } },
    })
  }

  private toast(key: string, count?: number): void {
    const message = AppStrings.get(key)
    this.getUIContext().getPromptAction().showToast(komaToastOptions({
      message: count === undefined ? message : message.replace('%s', `${count}`),
    }))
  }

  private markSelectedRead(targets: ChapterUpdateRow[]): void {
    const mutations: ChapterReadMutation[] = targets.filter((row: ChapterUpdateRow): boolean =>
      this.libraryStore.getComic(row.comic.id)?.chapters.some((chapter: Chapter): boolean =>
        chapter.id === row.chapter.id) === true && !this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id))
      .map((row: ChapterUpdateRow): ChapterReadMutation => ({ comicId: row.comic.id, chapterId: row.chapter.id, isRead: true }))
    if (mutations.length === 0) {
      this.toast('manga_detail_no_markable_chapters')
      return
    }
    const result = this.readerSessionStore?.commitChapterReadStates(mutations)
    if (result?.committed !== true) {
      this.toast('reader_progress_save_failed')
      return
    }
    this.chrome.exitSelection()
    this.onReadingStateChanged()
    this.toast('manga_detail_marked_count_read', result.changedCount)
  }

  private async downloadSelected(targets: ChapterUpdateRow[]): Promise<void> {
    if (this.chrome.busy) return
    this.chrome.busy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const root = await ensureKomaContentStorageBase(context)
      const key = komaRuntimeStorageKey(context)
      await OfflineDownloadService.ensureQueueInitialized(root, key)
      const chaptersByComic = new Map<string, string[]>()
      targets.forEach((row: ChapterUpdateRow): void => {
        const ids = chaptersByComic.get(row.comic.id) ?? []
        ids.push(row.chapter.id)
        chaptersByComic.set(row.comic.id, ids)
      })
      const queue = new OfflineDownloadQueueStore(root, key)
      const batches: OfflineDownloadChapterBatch[] = []
      chaptersByComic.forEach((chapterIds: string[], comicId: string): void => {
        const comic = this.libraryStore.getComic(comicId)
        if (comic !== undefined) batches.push({ comic, chapterIds })
      })
      const count = queue.requestChapterBatches(batches)
      if (count === 0) {
        this.toast('manga_detail_no_matching_chapters')
        return
      }
      this.chrome.exitSelection()
      this.toast('library_download_enqueued', count)
    } catch (error) {
      DiagnosticLogger.exception('library_updates', 'batch_download_failed', error as Error)
      this.toast('library_download_enqueue_failed')
    } finally {
      this.chrome.busy = false
    }
  }

  private isLastRow(day: string, row: ChapterUpdateRow): boolean {
    const rows = this.rowsByDay[day]
    const last = rows[rows.length - 1]
    return last.comic.id === row.comic.id && last.chapter.id === row.chapter.id
  }

  @Builder
  private Cover(row: ChapterUpdateRow) {
    Button({ type: ButtonType.Normal }) {
      CachedCoverImage({ uri: row.comic.coverUri ?? '', sourceRuntimeId: row.comic.sourceRuntimeId ?? '',
        sourceImageId: row.comic.remoteResourceId ?? row.comic.id, sourceMangaUrl: row.comic.sourcePath,
        sourceKind: row.comic.sourceKind, remoteServerId: row.comic.remoteServerId ?? '' })
        .width(44).height(60).borderRadius(ThemeConstants.RADIUS_COVER).clip(true)
    }.backgroundColor(Color.Transparent)
      // Match the grouped card's 12vp cover inset on both axes: the group
      // supplies 4vp, and the native row prefix already supplies 8vp at left.
      .margin({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .onClick(() => {
        if (this.chrome.selecting) this.toggleSelection(row)
        else this.onOpenComic(row.comic.id)
      })
  }

  @Builder
  private SelectionIndicator(row: ChapterUpdateRow) {
    Checkbox({ name: updateRowKey(row) })
      .select(this.chrome.selectedKeys.has(updateRowKey(row)))
      .selectedColor(ThemeConstants.BRAND_PRIMARY)
      .width(24).height(24)
      .accessibilityText(row.chapter.title)
      .onChange((checked: boolean) => {
        if (this.chrome.selecting && checked !== this.chrome.selectedKeys.has(updateRowKey(row))) this.toggleSelection(row)
      })
  }

  @Builder
  private UpdateRow(row: ChapterUpdateRow) {
    ConciseListRow({ title: row.comic.title, subtitle: row.chapter.title,
      trailingText: !this.chrome.selecting && this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id)
        ? AppStrings.get('chapter_list_filter_read') : '', showChevron: false,
      prefixBuilderParam: () => { this.Cover(row) },
      suffixBuilderParam: this.chrome.selecting ? (): void => { this.SelectionIndicator(row) } : undefined,
      action: (): void => {
        if (this.chrome.selecting) this.toggleSelection(row)
        else this.onOpenReader(row.comic.id, row.chapter.id)
      },
    })
    .priorityGesture(LongPressGesture({ duration: 350 }).onAction(() => {
      if (!this.chrome.selecting) this.toggleSelection(row)
    }))
  }

  @Builder
  private FailureSheet() {
    KomaModalScaffold({ title: AppStrings.get('library_update_failure_details'),
      onClose: (): void => { this.failuresShown = false } }) {
      if (this.openedFailures.checkFailureCode !== undefined) {
        ListItem() {
          GroupedListSection({ inModal: true }) {
            ConciseListRow({ title: libraryUpdateFailureText(this.openedFailures.checkFailureCode!),
              showChevron: false })
          }
        }
      } else {
        Repeat<LibraryUpdateComicResult>(this.openedFailures.results)
          .each((row: RepeatItem<LibraryUpdateComicResult>) => {
            ListItem() {
              GroupedListSection({ inModal: true }) {
                ConciseListRow({ title: libraryUpdateComicTitle(this.libraryStore.getComic(row.item.comicId)),
                  subtitle: libraryUpdateFailureText(row.item.message), showChevron: false })
              }
            }
          })
          .key((row: LibraryUpdateComicResult): string => row.comicId)
          .virtualScroll()
      }
    }
  }

  build() {
    if (this.language.effectiveLocale.length > 0 && this.readerProgressRevision >= 0) {
      Column() {
        PullRefreshListScaffold({ controller: this.refreshController, onRefresh: async (): Promise<void> => {
          this.refreshing = true
          try { await this.onRefresh(); this.reload() } finally { this.refreshing = false }
        },
          onReachEnd: (): void => { this.visibleLimit = Math.max(this.visibleLimit,
            Math.min(this.visibleLimit + 80, this.filteredRows.length)) },
          bottomPadding: ThemeConstants.SPACE_XL }) {
          if (this.updateState.busy && !this.refreshing) {
            ListItem() {
              Row({ space: ThemeConstants.SPACE_SM }) {
                Text(AppStrings.get('library_updates_checking')).fontColor(ThemeConstants.TEXT_SECONDARY)
              }.padding(ThemeConstants.SPACE_MD)
            }
          }
          if (!this.chrome.selecting &&
            (this.failures.results.length > 0 || this.failures.checkFailureCode !== undefined)) {
            ListItem() {
              GroupedListSection() {
                ConciseListRow({ title: this.failures.results.length > 0
                    ? AppStrings.format('library_update_failures_count', this.failures.results.length)
                    : AppStrings.get('library_updates_check_failed'),
                  action: (): void => {
                    this.openedFailures = this.failures
                    this.failuresShown = true
                  } })
              }
            }
          }
          // Refresh updates the saved snapshot in the background. Its activity
          // must not replace either existing rows or the confirmed empty state.
          if (this.filteredRows.length === 0) {
            ListItem() {
              if (this.loading) {
                LoadingProgress().width(32).height(32).color(ThemeConstants.BRAND_PRIMARY)
                  .visibility(this.refreshing ? Visibility.Hidden : Visibility.Visible)
              }
              else {
                KomaEmptyState({ icon: $r('sys.symbol.bell'),
                  title: AppStrings.get(this.error ? 'library_updates_load_failed' :
                    this.chrome.unreadOnly ? 'library_updates_unread_empty' : 'library_updates_empty'),
                  message: this.chrome.unreadOnly && !this.error ? '' : AppStrings.get('library_updates_empty_hint'),
                  showAction: this.error, actionLabel: AppStrings.get('common_retry'),
                  action: (): void => { this.reload() } })
              }
            }
          } else {
            ForEach(this.days, (day: string) => {
              ListItem() {
                GroupedListSection({ title: day }) {
                  ForEach(this.rowsByDay[day], (row: ChapterUpdateRow) => {
                    this.UpdateRow(row)
                    if (!this.isLastRow(day, row)) { ListDivider() }
                  }, (row: ChapterUpdateRow): string => JSON.stringify([row.comic.id, row.chapter.id,
                    row.comic.title, row.chapter.title, row.comic.coverUri,
                    this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id)]))
                }
              }
            }, (day: string): string => day)
          }
        }
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.failuresShown, this.FailureSheet, komaModalSheetOptions({
        height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE], showClose: false,
        enableOutsideInteractive: false, scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      }))
    }
  }
}
