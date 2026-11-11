import { ChapterArchiveActions, CHAPTER_ARCHIVE_SAVE_FAILED } from '../model/ChapterArchiveExport'
import { komaMenuOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaMenuChip } from '../components/ui/KomaMenuChip'
import { ThemeConstants } from '../theme/ThemeConstants'
import { LibraryStore } from '../model/LibraryStore'
import { downloadBlockedReason, OfflineDownloadService, OfflineDownloadWaitReason } from '../model/OfflineDownloadService'
import { DownloadsChrome } from '../state/DownloadsChrome'
import { appSourceRuntimeRegistry, sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { sourceRuntimeEntryEnabled } from '../sourceRuntime/SourceRuntimeRegistry'
import { Chapter } from '../model/ComicModels'
import { OfflineDownloadRuntime } from '../model/OfflineDownloadRuntime'
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadStatus,
  OfflineDownloadStore,
} from '../model/OfflineDownloadStore'
import {
  OfflineDownloadQueueEntry,
  OfflineDownloadQueuePreferences,
  OfflineDownloadQueueRecoverySummary,
  OfflineDownloadQueueSnapshot,
  OfflineDownloadQueueSummary,
  OfflineDownloadQueueStore,
  summarizeOfflineDownloadQueue,
  isOfflineDownloadTaskPending,
  isOfflineDownloadTaskRetryable,
  offlineDownloadTaskKey,
} from '../model/OfflineDownloadQueueStore'
import {
  ensureKomaContentStorageBase,
  komaContentStorageBase,
  komaRuntimeStorageKey,
} from '../model/KomaContentStorage'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { RouterHelper, SourcePackageManagerRouteParam } from '../common/RouterHelper'
import { RouteName } from '../common/Constants'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { WorkArchiveSheet } from '../components/WorkArchiveSheet'
import { komaModalSheetOptions } from '../components/KomaModalScaffold'

function s(name: string): string {
  return AppStrings.get(name)
}

const DOWNLOAD_LIST_TRANSITION_MS: number = 220

function filterRowTransition(): TransitionEffect {
  // A removed row must release its pixels before another row appears in the same slot.
  return TransitionEffect.asymmetric(TransitionEffect.OPACITY, TransitionEffect.IDENTITY)
}

enum DownloadQueueFilter {
  ALL = 'all',
  QUEUED = 'queued',
  DOWNLOADING = 'downloading',
  FAILED = 'failed',
  BLOCKED = 'blocked',
  DOWNLOADED = 'downloaded',
}

interface DownloadComicGroup {
  comicId: string
  title: string
  entries: OfflineDownloadQueueEntry[]
}

@ComponentV2
export struct DownloadsPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param chrome: DownloadsChrome = new DownloadsChrome()
  @Local private expandedGroups: Set<string> = new Set<string>()
  @Local private archiveShown: boolean = false
  @Local private archiveGroup?: DownloadComicGroup = undefined
  @Local private selection: Set<string> = new Set<string>()
  @Local private waitReason: OfflineDownloadWaitReason | undefined = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private entries: OfflineDownloadQueueEntry[] = []
  @Local private preferences: OfflineDownloadQueuePreferences = {
    foregroundConcurrencyLimit: 1,
    isPaused: false,
    wifiOnly: false,
  }
  @Local private busyKey: string = ''
  @Local private filter: DownloadQueueFilter = DownloadQueueFilter.ALL
  @Local private recoveryText: string = ''
  @Local private actionMenuKey: string = ''
  private unsubscribeQueue: (() => void) | undefined = undefined
  private queueVisible: boolean = false
  private queueRefreshTimer: number = -1
  private queueScrolling: boolean = false
  private queueRefreshPending: boolean = false
  @Event onOpenReader: (comicId: string, chapterId: string) => void =
    (_comicId: string, _chapterId: string) => {}

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private queueStore(): OfflineDownloadQueueStore {
    const context = this.context()
    return new OfflineDownloadQueueStore(komaContentStorageBase(context), komaRuntimeStorageKey(context))
  }

  private async initializeQueue(): Promise<void> {
    try {
      const context = this.context()
      const storageBase = await ensureKomaContentStorageBase(context)
      await OfflineDownloadService.ensureQueueInitialized(storageBase, komaRuntimeStorageKey(context))
      if (this.queueVisible) {
        this.loadQueue()
      }
    } catch (error) {
      const e = error as Error
      DiagnosticLogger.warn('downloads_page', 'deferred_reconcile_failed', DiagnosticLogger.errorSummary(e))
    } finally {
      if (this.busyKey === 'initialize') {
        this.busyKey = ''
        this.syncChrome()
      }
    }
  }

  private loadQueue(): void {
    try {
      const store = this.queueStore()
      const snapshot: OfflineDownloadQueueSnapshot = store.loadSnapshot()
      this.entries = snapshot.entries
      this.preferences = snapshot.preferences
      this.waitReason = downloadBlockedReason(snapshot.preferences)
      this.syncChrome()
    } catch (_error) {
      DiagnosticLogger.warn('downloads_page', 'load_queue_failed', '[Downloads] step=load_queue_failed code=queue_read_failed')
    }
  }

  private rowKey(entry: OfflineDownloadQueueEntry): string {
    return offlineDownloadTaskKey(entry)
  }

  private chapterArchives: ChapterArchiveActions = new ChapterArchiveActions()
  @Local private chapterArchiveBusy: boolean = false

  private async exportChapter(key: string, share: boolean): Promise<void> {
    const entry = this.entryForKey(key)
    if (entry === undefined || this.chapterArchiveBusy) return
    this.chapterArchiveBusy = true
    try {
      await this.chapterArchives.perform(this.context(), entry.comicId, entry.chapterId,
        entry.comicTitle ?? this.libraryStore?.getComic(entry.comicId)?.title ?? '', entry.chapterTitle ?? entry.chapterId,
        share, () => this.queueVisible)
    } catch (error) {
      DiagnosticLogger.exception('downloads', 'archive_export_failed', error as Error)
      if (this.queueVisible) this.showToast(s(
        (error as Error).message === CHAPTER_ARCHIVE_SAVE_FAILED ? CHAPTER_ARCHIVE_SAVE_FAILED : 'chapter_archive_failed'))
    } finally { this.chapterArchiveBusy = false }
  }

  private entryForKey(key: string): OfflineDownloadQueueEntry | undefined {
    return this.entriesByKey.get(key)
  }

  private moveDownload(key: string, toTop: boolean, wholeComic: boolean): void {
    const entry = this.entryForKey(key)
    if (entry === undefined) return
    try {
      this.queueStore().move(entry.comicId, entry.chapterId, toTop, wholeComic)
      this.loadQueue()
    } catch (error) {
      DiagnosticLogger.exception('downloads', 'queue_reorder_failed', error as Error)
      this.showToast(s('downloads_reorder_failed'))
    }
  }

  private visibleEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.matchesFilter(entry, this.filter))
  }

  @Computed
  private get visibleEntryList(): OfflineDownloadQueueEntry[] {
    return this.visibleEntries()
  }

  @Computed
  private get entriesByKey(): Map<string, OfflineDownloadQueueEntry> {
    const entries: Map<string, OfflineDownloadQueueEntry> = new Map()
    this.entries.forEach((entry: OfflineDownloadQueueEntry): void => { entries.set(this.rowKey(entry), entry) })
    return entries
  }

  private matchesFilter(entry: OfflineDownloadQueueEntry, filter: DownloadQueueFilter): boolean {
    if (filter === DownloadQueueFilter.ALL) {
      return true
    }
    if (filter === DownloadQueueFilter.FAILED) {
      return entry.status === OfflineDownloadStatus.FAILED ||
        (entry.status === OfflineDownloadStatus.PARTIAL && !isOfflineDownloadTaskPending(entry))
    }
    if (filter === DownloadQueueFilter.DOWNLOADED) {
      return entry.status === OfflineDownloadStatus.DOWNLOADED
    }
    if (filter === DownloadQueueFilter.BLOCKED) {
      return entry.status === OfflineDownloadStatus.BLOCKED
    }
    if (filter === DownloadQueueFilter.DOWNLOADING) {
      return entry.status === OfflineDownloadStatus.DOWNLOADING
    }
    return isOfflineDownloadTaskPending(entry) && entry.status !== OfflineDownloadStatus.DOWNLOADING
  }

  private shouldShowFilter(filter: DownloadQueueFilter): boolean {
    return filter === DownloadQueueFilter.ALL || filter === this.filter ||
      this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.matchesFilter(entry, filter))
  }

  private groupedEntries(completed: boolean): DownloadComicGroup[] {
    const groups: DownloadComicGroup[] = []
    const groupsByComicId: Map<string, DownloadComicGroup> = new Map()
    this.visibleEntryList.filter((entry: OfflineDownloadQueueEntry): boolean =>
      this.canRead(entry) === completed).forEach((entry: OfflineDownloadQueueEntry): void => {
      const existing = groupsByComicId.get(entry.comicId)
      if (existing !== undefined) {
        existing.entries.push(entry)
        return
      }
      const group: DownloadComicGroup = {
        comicId: entry.comicId,
        title: entry.comicTitle !== undefined && entry.comicTitle.trim().length > 0
          ? entry.comicTitle
          : (this.libraryStore?.getComic(entry.comicId)?.title ?? entry.comicId),
        entries: [entry],
      }
      groups.push(group)
      groupsByComicId.set(entry.comicId, group)
    })
    return groups
  }

  @Computed
  private get activeDownloadGroups(): DownloadComicGroup[] {
    return this.groupedEntries(false)
  }

  @Computed
  private get completedDownloadGroups(): DownloadComicGroup[] {
    return this.groupedEntries(true)
  }

  private filterLabel(): string {
    if (this.filter === DownloadQueueFilter.QUEUED) {
      return s('downloads_filter_queued')
    }
    if (this.filter === DownloadQueueFilter.DOWNLOADING) {
      return s('downloads_filter_downloading')
    }
    if (this.filter === DownloadQueueFilter.FAILED) {
      return s('downloads_filter_failed')
    }
    if (this.filter === DownloadQueueFilter.BLOCKED) {
      return s('downloads_filter_blocked')
    }
    if (this.filter === DownloadQueueFilter.DOWNLOADED) {
      return s('downloads_filter_downloaded')
    }
    return s('common_all')
  }

  private setFilter(filter: DownloadQueueFilter): void {
    this.animateListChange((): void => {
      if (this.filter === filter) return
      this.filter = filter
      this.syncChrome()
    })
  }

  private animateListChange(update: () => void): void {
    // Do not relayout rows while their native menu click is still being delivered.
    setTimeout((): void => {
      if (!this.queueVisible) return
      this.getUIContext().animateTo({ duration: DOWNLOAD_LIST_TRANSITION_MS, curve: Curve.FastOutSlowIn }, update)
    }, 0)
  }

  private hasActiveFilter(): boolean {
    return this.filter !== DownloadQueueFilter.ALL
  }

  private resetFilter(): void {
    this.setFilter(DownloadQueueFilter.ALL)
  }

  private rowTitle(entry: OfflineDownloadQueueEntry): string {
    if (entry.chapterTitle !== undefined && entry.chapterTitle.length > 0) {
      return entry.chapterTitle
    }
    return entry.chapterId
  }

  private rowSubtitle(entry: OfflineDownloadQueueEntry): string {
    const progress = s('downloads_page_progress')
      .replace('%s', `${entry.downloadedPageCount}`)
      .replace('%s', `${entry.pageCount}`)
    if (entry.pageCount <= 0) return this.formatEntryStatus(entry)
    if (entry.status === OfflineDownloadStatus.DOWNLOADED) {
      return progress
    }
    return `${progress} · ${this.formatEntryStatus(entry)}`
  }

  private rowDetailSubtitle(entry: OfflineDownloadQueueEntry): string {
    const blocked = this.blockedHelpText(entry)
    if (blocked.length === 0) {
      return this.rowSubtitle(entry)
    }
    return `${this.rowSubtitle(entry)}\n${blocked}`
  }

  private taskNeedsAttention(entry: OfflineDownloadQueueEntry): boolean {
    return !entry.canceling && !this.canRead(entry) && !isOfflineDownloadTaskPending(entry)
  }

  private taskPrerequisite(entry: OfflineDownloadQueueEntry): string {
    if (!this.taskNeedsAttention(entry)) return ''
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) return 'comic_missing'
    if (!comic.chapters.some((chapter: Chapter): boolean => chapter.id === entry.chapterId)) return 'chapter_missing'
    if (comic.sourceRuntimeId !== undefined) {
      const source = appSourceRuntimeRegistry.lookup(comic.sourceRuntimeId).entry
      if (source === undefined) return 'source_not_installed'
      if (!sourceRuntimeEntryEnabled(source)) return 'source_disabled'
    }
    return ''
  }

  private taskFailureReason(entry: OfflineDownloadQueueEntry): string {
    const prerequisite = this.taskPrerequisite(entry)
    if (prerequisite.length > 0) return prerequisite
    const reason = entry.failureReasonCode ?? ''
    if (reason === 'comic_missing' || reason === 'chapter_missing' ||
      reason === 'source_not_installed' || reason === 'source_disabled') return ''
    return reason
  }

  private blockedHelpText(entry: OfflineDownloadQueueEntry): string {
    const reason = this.taskFailureReason(entry)
    if (reason === 'pages_missing') {
      return s('downloads_blocked_pages_missing')
    }
    if (reason === 'source_pages_failed') {
      return s('downloads_blocked_source_pages_failed')
    }
    if (reason === 'source_lookup_failed') {
      return s('downloads_blocked_source_lookup_failed')
    }
    if (reason === 'source_disabled') {
      return s('downloads_blocked_source_disabled')
    }
    if (reason === 'cancel_cleanup_failed') return s('downloads_cancel_cleanup_failed')
    if (reason === 'source_login_required') return s('downloads_source_login_required')
    if (reason === 'source_not_installed') {
      return s('downloads_blocked_source_not_installed')
    }
    if (reason === 'chapter_missing') {
      return s('downloads_blocked_chapter_missing')
    }
    if (reason === 'comic_missing') {
      return s('downloads_blocked_comic_missing')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && !isOfflineDownloadTaskRetryable(entry)) {
      return s('downloads_blocked_unretryable')
    }
    return ''
  }

  private formatStatus(status: OfflineDownloadStatus): string {
    if (status === OfflineDownloadStatus.QUEUED) {
      return s('downloads_status_queued')
    }
    if (status === OfflineDownloadStatus.DOWNLOADING) {
      return s('downloads_status_downloading')
    }
    if (status === OfflineDownloadStatus.DOWNLOADED) {
      return s('downloads_status_downloaded')
    }
    if (status === OfflineDownloadStatus.PARTIAL) {
      return s('downloads_status_partial')
    }
    if (status === OfflineDownloadStatus.FAILED) {
      return s('downloads_status_failed')
    }
    if (status === OfflineDownloadStatus.BLOCKED) {
      return s('downloads_status_blocked')
    }
    return s('downloads_status_failed')
  }

  private isPausedDownload(entry: OfflineDownloadQueueEntry): boolean {
    return isOfflineDownloadTaskPending(entry) && (entry.pausedByUser === true || this.preferences.isPaused)
  }

  private formatEntryStatus(entry: OfflineDownloadQueueEntry): string {
    if (entry.canceling) return s('downloads_status_canceling')
    if (this.isPausedDownload(entry)) return s('downloads_status_paused')
    if (isOfflineDownloadTaskPending(entry)) {
      if (this.waitReason === 'offline') return s('downloads_status_waiting_network')
      if (this.waitReason === 'wifi_only') return s('downloads_status_waiting_wifi')
      if (entry.status !== OfflineDownloadStatus.DOWNLOADING) return s('downloads_status_queued')
    }
    return this.formatStatus(entry.status)
  }

  private queueOverviewTitle(): string {
    const count = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => !this.canRead(entry)).length
    return count > 0 ? s('downloads_tasks_count').replace('%s', String(count)) : s('downloads_tasks_section')
  }

  private queueOverviewSubtitle(): string {
    const summary = summarizeOfflineDownloadQueue(this.entries)
    const runnable = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      isOfflineDownloadTaskPending(entry) && !entry.pausedByUser)
    const paused = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.isPausedDownload(entry)).length
    if (runnable.length > 0 && this.waitReason === 'offline') return s('downloads_status_waiting_network')
    if (runnable.length > 0 && this.waitReason === 'wifi_only') return s('downloads_status_waiting_wifi')
    if (runnable.length > 0 && !this.preferences.isPaused && summary.downloadingCount > 0) {
      const next = runnable.find((entry: OfflineDownloadQueueEntry): boolean =>
        entry.automatic === true && entry.status !== OfflineDownloadStatus.DOWNLOADING)
      if (next !== undefined) return s('downloads_overview_next').replace('%s', this.rowTitle(next))
      return s('downloads_overview_downloading').replace('%s', String(summary.downloadingCount))
    }
    if (paused > 0 && (runnable.length === 0 || this.preferences.isPaused)) {
      return s('downloads_overview_paused').replace('%s', String(paused))
    }
    if (runnable.length > 0) return s('downloads_overview_queued').replace('%s', String(runnable.length))
    const attention = this.cleanupEntries(false).length
    if (attention > 0) return s('downloads_overview_attention').replace('%s', String(attention))
    return this.entries.some((entry: OfflineDownloadQueueEntry): boolean => entry.canceling === true) ?
      s('downloads_status_canceling') : s('downloads_no_pending_tasks')
  }

  @Computed
  private get queueOverviewText(): string[] {
    return [this.queueOverviewTitle(), this.queueOverviewSubtitle()]
  }

  private groupSource(group: DownloadComicGroup): string {
    const comic = this.libraryStore?.getComic(group.comicId)
    const label = comic?.sourceMetadata?.sourceName ?? group.entries[0]?.sourceName ?? ''
    return comic?.sourceRuntimeId === undefined ? label : sourceDisplayName(comic.sourceRuntimeId, label)
  }

  private groupSubtitle(group: DownloadComicGroup, completed: boolean): string {
    const entries = this.visibleGroupEntries(group.comicId, completed)
    const active = entries.find((entry: OfflineDownloadQueueEntry): boolean =>
      entry.status === OfflineDownloadStatus.DOWNLOADING && !entry.canceling)
    const source = this.groupSource(group)
    const count = s('downloads_chapters_count').replace('%s', String(entries.length))
    const labels: string[] = source.length > 0 ? [source, count] : [count]
    if (!completed && entries.length > 0) {
      const entry = active ?? entries[0]
      const prerequisite = this.taskPrerequisite(entry)
      labels.push(active !== undefined ? this.rowTitle(entry) + ' · ' + this.rowSubtitle(entry) :
        prerequisite === 'comic_missing' ? s('downloads_group_comic_missing') : this.formatEntryStatus(entry))
    }
    return labels.join(' · ')
  }

  private primaryQueueActionLabel(): string {
    if (this.busyKey === 'initialize') return ''
    const pending = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      isOfflineDownloadTaskPending(entry) && !entry.pausedByUser)
    if (this.preferences.isPaused) return 'downloads_action_resume_queue'
    if (pending.length === 0) return ''
    return pending.some((entry: OfflineDownloadQueueEntry): boolean =>
      entry.automatic === true || entry.status === OfflineDownloadStatus.DOWNLOADING) ?
      'downloads_action_pause_all' : 'downloads_action_start_queue'
  }

  private handlePrimaryQueueAction(): void {
    if (!OfflineDownloadRuntime.isInitialized(this.context().filesDir) || this.busyKey.length > 0) return
    if (this.primaryQueueActionLabel() === 'downloads_action_pause_all') {
      this.pauseQueuedDownloads()
    } else if (this.primaryQueueActionLabel().length > 0) {
      void this.startPendingDownloads()
    }
  }

  private canRetry(entry: OfflineDownloadQueueEntry): boolean {
    return isOfflineDownloadTaskRetryable(entry) && this.taskPrerequisite(entry).length === 0
  }

  private canCancel(entry: OfflineDownloadQueueEntry): boolean {
    return !entry.canceling && !this.canRead(entry)
  }

  private canPause(entry: OfflineDownloadQueueEntry): boolean {
    return isOfflineDownloadTaskPending(entry) && !entry.pausedByUser
  }

  private canResume(entry: OfflineDownloadQueueEntry): boolean {
    return isOfflineDownloadTaskPending(entry) && entry.pausedByUser === true
  }

  private canMove(entry: OfflineDownloadQueueEntry): boolean {
    return isOfflineDownloadTaskPending(entry) && entry.status !== OfflineDownloadStatus.DOWNLOADING
  }

  private syncChrome(): void {
    const chrome = this.chrome
    const visible = this.visibleEntries()
    const selected = visible.filter((entry: OfflineDownloadQueueEntry): boolean => this.selection.has(this.rowKey(entry)))
    chrome.queueAction = this.primaryQueueActionLabel()
    chrome.hasTasks = this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.canCancel(entry))
    chrome.hasRetryable = this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
    chrome.hasFailures = this.cleanupEntries(false).length > 0
    chrome.hasDownloaded = this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.canRead(entry))
    chrome.hasVisible = visible.length > 0
    chrome.selectedCount = selected.length
    chrome.allSelected = visible.length > 0 && visible.length === selected.length
    chrome.canPauseSelected = selected.some((entry: OfflineDownloadQueueEntry): boolean => this.canPause(entry))
    chrome.canResumeSelected = selected.some((entry: OfflineDownloadQueueEntry): boolean => this.canResume(entry))
    chrome.canCancelSelected = selected.some((entry: OfflineDownloadQueueEntry): boolean => this.canCancel(entry))
    chrome.canRetrySelected = selected.some((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
    chrome.canDeleteSelected = selected.some((entry: OfflineDownloadQueueEntry): boolean => this.canRead(entry))
  }

  private toggleSelected(key: string): void {
    const keys = new Set<string>(this.selection)
    if (keys.has(key)) keys.delete(key)
    else keys.add(key)
    this.selection = keys
    this.syncChrome()
  }

  @Monitor('chrome.requestRevision')
  private onTitleCommand(): void {
    if (this.busyKey === 'initialize') return
    const selected = this.visibleEntries().filter((entry: OfflineDownloadQueueEntry): boolean =>
      this.selection.has(this.rowKey(entry)))
    switch (this.chrome.command) {
      case 'queue': this.handlePrimaryQueueAction(); break
      case 'cancelAll': this.confirmCancel(this.entries, s('downloads_cancel_all_tasks')); break
      case 'retryAll': this.retryDownloads(this.entries); break
      case 'clearFailed': this.confirmCancel(this.cleanupEntries(false), s('downloads_clear_failed')); break
      case 'deleteDownloaded': this.confirmDelete(this.cleanupEntries(true), s('downloads_delete_completed')); break
      case 'rescan': this.rescanDownloads(); break
      case 'select': this.chrome.selecting = true; break
      case 'exitSelection':
        this.chrome.selecting = false
        this.selection = new Set<string>()
        this.syncChrome()
        break
      case 'toggleAll':
        this.selection = new Set<string>(this.chrome.allSelected ? [] :
          this.visibleEntries().map((entry: OfflineDownloadQueueEntry): string => this.rowKey(entry)))
        this.syncChrome()
        break
      case 'pauseSelected': this.setPaused(selected, true); break
      case 'resumeSelected': this.setPaused(selected, false); break
      case 'cancelSelected': this.confirmCancel(selected, s('downloads_cancel_selected')); break
      case 'retrySelected': this.retryDownloads(selected); break
      case 'deleteSelected': this.confirmDelete(selected, s('downloads_action_delete_files')); break
    }
  }

  private canRead(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.DOWNLOADED
  }

  private cleanupEntries(completed: boolean): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      completed ? this.canRead(entry) : this.canCancel(entry) && !isOfflineDownloadTaskPending(entry))
  }

  private hasReadableDownloadedManifest(entry: OfflineDownloadQueueEntry): boolean {
    try {
      const context = this.context()
      const validation = new OfflineDownloadStore(komaContentStorageBase(context), komaRuntimeStorageKey(context))
        .validateDownloadedChapter(entry.comicId, entry.chapterId, { validateContentHash: false })
      return validation.manifest !== undefined &&
        validation.availablePageCount > 0 &&
        validation.status === OfflineDownloadedChapterStatus.DOWNLOADED
    } catch (_error) {
      DiagnosticLogger.warn('downloads_page', 'read_manifest_validation_failed', '[Downloads] step=read_manifest_validation_failed failed=true reason=download_manifest')
      return false
    }
  }

  private openDownloadEntry(entry: OfflineDownloadQueueEntry): void {
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    const sourceId = comic.sourceRuntimeId?.trim()
    const sourceMangaId = comic.remoteResourceId?.trim()
    if (sourceId !== undefined && sourceId.length > 0 && sourceMangaId !== undefined && sourceMangaId.length > 0) {
      RouterHelper.pushMangaDetail({
        mangaId: sourceMangaId,
        sourceId,
        initialManga: {
          id: sourceMangaId,
          sourceId,
          title: comic.title,
          coverUrl: comic.coverUri,
          url: comic.sourcePath,
        },
      })
      return
    }
    RouterHelper.pushMangaDetail({ mangaId: entry.comicId })
  }

  private openDownloadedChapter(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRead(entry)) {
      return
    }
    if (!this.hasReadableDownloadedManifest(entry)) {
      this.loadQueue()
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    this.onOpenReader(entry.comicId, entry.chapterId)
  }

  private retryDownloads(entries: OfflineDownloadQueueEntry[]): void {
    try {
      const count = this.queueStore().retryTasks(entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry)))
      this.loadQueue()
      this.showToast(count === 0 ? s('downloads_toast_no_retryable') :
        this.waitReason === 'paused' ? s('downloads_status_paused') :
          this.waitReason === 'offline' ? s('downloads_status_waiting_network') :
            this.waitReason === 'wifi_only' ? s('downloads_status_waiting_wifi') :
              s('library_download_enqueued').replace('%s', String(count)))
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'retry_enqueue_failed', error as Error)
      this.showToast(s('downloads_toast_retry_failed'))
    }
  }

  private setPaused(targets: OfflineDownloadQueueEntry[], paused: boolean): void {
    try {
      this.queueStore().setTasksPaused(targets, paused)
      this.loadQueue()
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'queue_pause_scope_failed', error as Error)
      this.showToast(s('downloads_control_failed'))
    }
  }

  private confirmCancel(entries: OfflineDownloadQueueEntry[], title: string): void {
    const targets = entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.canCancel(entry))
    if (targets.length === 0) return
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(), title,
      message: s('downloads_cancel_tasks_confirm').replace('%s', String(targets.length)), autoCancel: true,
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: { value: s('common_confirm'), fontColor: ThemeConstants.DANGER,
        action: () => { void this.cancelTasks(targets) } },
    })
  }

  private async cancelTasks(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const pending = this.queueStore().cancelTasks(targets)
      this.loadQueue()
      const removed = await pending
      this.loadQueue()
      this.showToast(s('downloads_tasks_canceled_count').replace('%s', String(removed)))
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'queue_cancel_failed', error as Error)
      this.showToast(s('downloads_control_failed'))
    }
  }

  private pauseQueuedDownloads(): void {
    try {
      this.preferences = this.queueStore().pauseAllQueuedWork()
      this.loadQueue()
      this.showToast(s('downloads_status_paused'))
    } catch (_error) {
      DiagnosticLogger.warn('downloads_page', 'pause_queue_failed', '[Downloads] step=pause_queue_failed code=queue_commit_failed')
    }
  }

  private async startPendingDownloads(): Promise<void> {
    this.busyKey = 'resume'
    try {
      await OfflineDownloadRuntime.waitForPausedExecutions(this.context().filesDir)
      const queue = this.queueStore()
      queue.startStagedWork()
      this.preferences = queue.resumeAllQueuedWork()
      this.loadQueue()
      // Resume is a structural queue change; wake the automatic execution owner.
      OfflineDownloadRuntime.publish(this.context().filesDir)
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'queue_resume_failed', error as Error)
      this.showToast(s('downloads_toast_resume_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private formatRecoverySummary(summary: OfflineDownloadQueueRecoverySummary): string {
    return s('downloads_toast_rescan_done')
      .replace('%s', `${summary.scannedCount}`)
      .replace('%s', `${summary.restoredCount}`)
      .replace('%s', `${summary.updatedCount}`)
      .replace('%s', `${summary.failedCount + summary.partialCount}`)
  }

  private rescanDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.busyKey = 'rescan'
    void this.runRescanDownloads()
  }

  private async runRescanDownloads(): Promise<void> {
    try {
      const summary = await this.queueStore().recoverFromManifests()
      this.loadQueue()
      this.recoveryText = this.formatRecoverySummary(summary)
      this.showToast(this.recoveryText)
    } catch (error) {
      void error
      DiagnosticLogger.warn('downloads_page', 'rescan_failed', '[Downloads] step=rescan_failed failed=true reason=manifest_rescan')
      this.showToast(s('downloads_toast_rescan_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private confirmDelete(entries: OfflineDownloadQueueEntry[], title: string): void {
    const targets = entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.canRead(entry))
    if (targets.length === 0) return
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(), title,
      message: s('downloads_delete_completed_confirm').replace('%s', String(targets.length)), autoCancel: true,
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: { value: s('common_confirm'), fontColor: ThemeConstants.DANGER,
        action: () => { void this.deleteDownloads(targets) } },
    })
  }

  private async deleteDownloads(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const store = this.queueStore()
      const allowed = new Set<string>(store.load().filter((entry: OfflineDownloadQueueEntry): boolean =>
        this.canRead(entry)).map((entry: OfflineDownloadQueueEntry): string => this.rowKey(entry)))
      for (const entry of targets) {
        if (allowed.has(this.rowKey(entry))) await store.deleteChapterDownload(entry.comicId, entry.chapterId)
      }
      this.showToast(s('downloads_toast_removed'))
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'batch_remove_failed', error as Error)
      this.showToast(s('downloads_toast_cleanup_failed'))
    } finally {
      this.loadQueue()
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_error) {
    }
  }

  private entryStatusIcon(entry: OfflineDownloadQueueEntry): Resource {
    if (this.isPausedDownload(entry)) {
      return $r('sys.symbol.pause')
    }
    if (entry.status === OfflineDownloadStatus.DOWNLOADED) {
      return $r('sys.symbol.checkmark_circle')
    }
    if (entry.status === OfflineDownloadStatus.DOWNLOADING) {
      return $r('sys.symbol.arrow_down_to_line')
    }
    if (entry.status === OfflineDownloadStatus.QUEUED) {
      return $r('sys.symbol.clock')
    }
    return $r('sys.symbol.exclamationmark_triangle')
  }

  private entryStatusColor(entry: OfflineDownloadQueueEntry): ResourceColor {
    if (this.isPausedDownload(entry)) {
      return ThemeConstants.STATUS_MUTED
    }
    if (entry.status === OfflineDownloadStatus.DOWNLOADED) {
      return ThemeConstants.STATUS_SUCCESS
    }
    if (entry.status === OfflineDownloadStatus.DOWNLOADING) {
      return ThemeConstants.BRAND_PRIMARY
    }
    if (entry.status === OfflineDownloadStatus.QUEUED) {
      return ThemeConstants.STATUS_MUTED
    }
    if (entry.status === OfflineDownloadStatus.FAILED || entry.status === OfflineDownloadStatus.BLOCKED) {
      return ThemeConstants.STATUS_DANGER
    }
    return ThemeConstants.STATUS_WARNING
  }

  private entryProgressValue(entry: OfflineDownloadQueueEntry): number {
    if (entry.pageCount <= 0) {
      return 0
    }
    return Math.max(0, Math.min(100, entry.downloadedPageCount / entry.pageCount * 100))
  }

  private shouldShowEntryProgress(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.DOWNLOADING ||
      entry.status === OfflineDownloadStatus.PARTIAL ||
      (entry.status === OfflineDownloadStatus.FAILED && entry.downloadedPageCount > 0)
  }

  private openDownloadRow(entry: OfflineDownloadQueueEntry): void {
    if (this.chrome.selecting) {
      this.toggleSelected(this.rowKey(entry))
      return
    }
    if (this.canRead(entry)) {
      this.openDownloadedChapter(entry)
      return
    }
    this.actionMenuKey = `row:${this.rowKey(entry)}`
  }

  private closeActionMenu(): void {
    this.actionMenuKey = ''
  }

  @Builder
  private FilterMenu() {
    Menu() {
      MenuItem({
        content: s('common_all'),
        symbolEndIcon: this.filter === DownloadQueueFilter.ALL
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
          : undefined,
      }).onClick(() => {
        this.setFilter(DownloadQueueFilter.ALL)
      })
      if (this.shouldShowFilter(DownloadQueueFilter.DOWNLOADING)) {
        MenuItem({
          content: s('downloads_filter_downloading'),
          symbolEndIcon: this.filter === DownloadQueueFilter.DOWNLOADING
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADING)
        })
      }
      if (this.shouldShowFilter(DownloadQueueFilter.QUEUED)) {
        MenuItem({
          content: s('downloads_filter_queued'),
          symbolEndIcon: this.filter === DownloadQueueFilter.QUEUED
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick(() => {
          this.setFilter(DownloadQueueFilter.QUEUED)
        })
      }
      if (this.shouldShowFilter(DownloadQueueFilter.DOWNLOADED)) {
        MenuItem({
          content: s('downloads_filter_downloaded'),
          symbolEndIcon: this.filter === DownloadQueueFilter.DOWNLOADED
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADED)
        })
      }
      if (this.shouldShowFilter(DownloadQueueFilter.FAILED)) {
        MenuItem({
          content: s('downloads_filter_failed'),
          symbolEndIcon: this.filter === DownloadQueueFilter.FAILED
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick(() => {
          this.setFilter(DownloadQueueFilter.FAILED)
        })
      }
      if (this.shouldShowFilter(DownloadQueueFilter.BLOCKED)) {
        MenuItem({
          content: s('downloads_filter_blocked'),
          symbolEndIcon: this.filter === DownloadQueueFilter.BLOCKED
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark'))
            : undefined,
        }).onClick(() => {
          this.setFilter(DownloadQueueFilter.BLOCKED)
        })
      }
    }
  }

  aboutToAppear(): void {
    this.queueVisible = true
    this.unsubscribeQueue?.()
    this.unsubscribeQueue = OfflineDownloadRuntime.subscribe(this.context().filesDir, (signal) => {
      this.scheduleQueueRefresh(signal === 'change')
    })
    this.loadQueue()
    if (!OfflineDownloadRuntime.isInitialized(this.context().filesDir)) {
      this.busyKey = 'initialize'
    }
    void this.initializeQueue()
  }

  aboutToDisappear(): void {
    this.queueVisible = false
    this.queueScrolling = false
    this.queueRefreshPending = false
    if (this.queueRefreshTimer >= 0) {
      clearTimeout(this.queueRefreshTimer)
      this.queueRefreshTimer = -1
    }
    this.unsubscribeQueue?.()
    this.unsubscribeQueue = undefined
  }

  private scheduleQueueRefresh(structural: boolean = false): void {
    if (this.queueScrolling && !structural) {
      this.queueRefreshPending = true
      return
    }
    if (!this.queueVisible || this.queueRefreshTimer >= 0) return
    this.queueRefreshTimer = setTimeout((): void => {
      this.queueRefreshTimer = -1
      if (this.queueVisible) {
        this.loadQueue()
      }
    }, 200)
  }

  private onQueueDidScroll(state: ScrollState): void {
    const scrolling: boolean = state !== ScrollState.Idle
    this.queueScrolling = scrolling
    if (!scrolling && this.queueRefreshPending) {
      this.queueRefreshPending = false
      this.scheduleQueueRefresh()
    }
  }

  @Builder
  private QueueHeader() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.arrow_down_to_line'))
            .fontSize(ThemeConstants.FONT_SIZE_H2)
            .fontColor([ThemeConstants.BRAND_PRIMARY])
        }
        .width(48)
        .height(48)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(ThemeConstants.SOFT_TINT)

        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.queueOverviewText[0])
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.queueOverviewText[1])
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaMenuChip({
          label: s('downloads_filter_chip').replace('%s', this.filterLabel()),
          active: this.hasActiveFilter(),
        })
          .onClick(() => {
            this.actionMenuKey = 'filter'
          })
          .bindMenu(this.actionMenuKey === 'filter', this.FilterMenu(), komaMenuOptions({
            placement: Placement.BottomLeft,
            onDisappear: () => {
              if (this.actionMenuKey === 'filter') {
                this.closeActionMenu()
              }
            },
          }))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private EmptyState(filtered: boolean = false) {
    KomaEmptyState({
      title: filtered ? s('downloads_filtered_empty_title') : s('downloads_empty_title'),
      message: filtered ? s('downloads_filtered_empty_message') : s('downloads_empty_message'),
      actionLabel: s('common_reset'),
      showAction: filtered,
      action: () => {
        this.resetFilter()
      },
    })
  }

  private recoveryLabel(entry: OfflineDownloadQueueEntry): string {
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic?.sourceRuntimeId === undefined) return ''
    const reason = this.taskFailureReason(entry)
    if (reason === 'source_not_installed' || reason === 'source_lookup_failed') {
      return 'device_sync_find_source'
    }
    if (reason === 'source_disabled' || reason === 'source_login_required') {
      return 'downloads_source_settings'
    }
    return ''
  }

  private recoverSource(entry: OfflineDownloadQueueEntry): void {
    const comic = this.libraryStore?.getComic(entry.comicId)
    const sourceId = comic?.sourceRuntimeId
    if (sourceId === undefined) return
    if (this.recoveryLabel(entry) === 'device_sync_find_source') {
      const param: SourcePackageManagerRouteParam = { settingsSourceId: '', recoverySourceId: sourceId,
        recoverySourceName: sourceDisplayName(sourceId, comic?.sourceMetadata?.sourceName ?? entry.sourceName ?? sourceId),
        chrome: new SourceCatalogPageChrome() }
      RouterHelper.getAppPathStack()?.pushPath({ name: RouteName.SOURCE_PACKAGE_MANAGER, param })
    } else {
      RouterHelper.pushSourceSettings(sourceId)
    }
  }

  @Builder
  private DownloadRowMenu(key: string) {
    if (this.entryForKey(key) !== undefined) {
      Menu() {
        if (this.libraryStore?.getComic(this.entryForKey(key)!.comicId) !== undefined) {
          MenuItem({ content: s('downloads_view_work') })
            .onClick(() => { this.openDownloadEntry(this.entryForKey(key)!) })
        }
        if (this.recoveryLabel(this.entryForKey(key)!).length > 0) {
          MenuItem({ content: s(this.recoveryLabel(this.entryForKey(key)!)) })
            .onClick(() => { this.recoverSource(this.entryForKey(key)!) })
        }
        if (this.canPause(this.entryForKey(key)!)) {
          MenuItem({ content: s('downloads_pause_chapter') })
            .onClick(() => { this.setPaused([this.entryForKey(key)!], true) })
        }
        if (this.canResume(this.entryForKey(key)!)) {
          MenuItem({ content: s('downloads_resume_chapter') })
            .onClick(() => { this.setPaused([this.entryForKey(key)!], false) })
        }
        if (this.canMove(this.entryForKey(key)!)) {
          MenuItem({ content: s('downloads_move_top') }).onClick(() => { this.moveDownload(key, true, false) })
          MenuItem({ content: s('downloads_move_bottom') }).onClick(() => { this.moveDownload(key, false, false) })
        }
        if (this.canRetry(this.entryForKey(key)!)) {
          MenuItem({ content: s('common_retry') }).onClick(() => { this.retryDownloads([this.entryForKey(key)!]) })
        }
        if (this.canRead(this.entryForKey(key)!)) {
          MenuItem({ content: s('chapter_export_cbz') }).enabled(!this.chapterArchiveBusy)
            .onClick(() => { void this.exportChapter(key, false) })
          MenuItem({ content: s('chapter_share_cbz') }).enabled(!this.chapterArchiveBusy)
            .onClick(() => { void this.exportChapter(key, true) })
          MenuItem({ content: s('downloads_action_delete_files') })
            .onClick(() => { this.confirmDelete([this.entryForKey(key)!], s('downloads_action_delete_files')) })
        } else if (this.canCancel(this.entryForKey(key)!)) {
          MenuItem({ content: s('downloads_cancel_task') })
            .onClick(() => { this.confirmCancel([this.entryForKey(key)!], s('downloads_cancel_task')) })
        }
      }
    }
  }

  @Computed
  private get comicEntries(): Map<string, OfflineDownloadQueueEntry[]> {
    const groups = new Map<string, OfflineDownloadQueueEntry[]>()
    for (const entry of this.entries) {
      const existing = groups.get(entry.comicId)
      if (existing === undefined) groups.set(entry.comicId, [entry])
      else existing.push(entry)
    }
    return groups
  }

  private fullGroup(comicId: string, completed: boolean): OfflineDownloadQueueEntry[] {
    return (this.comicEntries.get(comicId) ?? []).filter((entry: OfflineDownloadQueueEntry): boolean =>
      this.canRead(entry) === completed)
  }

  private visibleGroupEntries(comicId: string, completed: boolean): OfflineDownloadQueueEntry[] {
    // The card retains its identity when changing filters; read current members
    // rather than the ForEach item's previous snapshot.
    return this.fullGroup(comicId, completed).filter((entry: OfflineDownloadQueueEntry): boolean =>
      this.matchesFilter(entry, this.filter))
  }

  private groupKey(group: DownloadComicGroup, completed: boolean): string {
    return (completed ? 'local:' : 'tasks:') + group.comicId
  }

  private toggleGroup(group: DownloadComicGroup, completed: boolean, openOnly: boolean = false): void {
    const key = this.groupKey(group, completed)
    this.animateListChange((): void => {
      const expanded = new Set<string>(this.expandedGroups)
      if (openOnly) expanded.add(key)
      else if (expanded.has(key)) expanded.delete(key)
      else expanded.add(key)
      this.expandedGroups = expanded
    })
  }

  private groupCanPause(group: DownloadComicGroup): boolean {
    return this.fullGroup(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean => this.canPause(entry))
  }

  private groupCanResume(group: DownloadComicGroup): boolean {
    return this.fullGroup(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean => this.canResume(entry))
  }

  private groupCanMove(group: DownloadComicGroup): boolean {
    return this.fullGroup(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean => this.canMove(entry))
  }

  private groupCanRetry(group: DownloadComicGroup): boolean {
    return this.fullGroup(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
  }

  private groupCanCancel(group: DownloadComicGroup): boolean {
    return this.fullGroup(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean => this.canCancel(entry))
  }

  private groupRecoveryEntry(group: DownloadComicGroup): OfflineDownloadQueueEntry | undefined {
    return this.fullGroup(group.comicId, false).find((entry: OfflineDownloadQueueEntry): boolean =>
      this.taskNeedsAttention(entry) && this.recoveryLabel(entry).length > 0)
  }

  private groupCanExplain(group: DownloadComicGroup): boolean {
    return this.visibleGroupEntries(group.comicId, false).some((entry: OfflineDownloadQueueEntry): boolean =>
      this.taskNeedsAttention(entry) && !this.canRetry(entry))
  }

  private openGroupWork(group: DownloadComicGroup, completed: boolean): void {
    const entry = this.fullGroup(group.comicId, completed)[0]
    if (entry !== undefined) this.openDownloadEntry(entry)
  }

  private moveGroup(group: DownloadComicGroup, toTop: boolean): void {
    const entry = this.fullGroup(group.comicId, false).find((item: OfflineDownloadQueueEntry): boolean =>
      this.canMove(item))
    if (entry !== undefined) this.moveDownload(this.rowKey(entry), toTop, true)
  }

  private openWorkArchive(group: DownloadComicGroup): void {
    this.archiveGroup = { comicId: group.comicId, title: group.title, entries: this.fullGroup(group.comicId, true) }
    this.archiveShown = this.archiveGroup.entries.length > 0
  }

  @Builder
  private ArchiveSheet() {
    if (this.archiveGroup !== undefined) {
      WorkArchiveSheet({ comicId: this.archiveGroup.comicId, comicTitle: this.archiveGroup.title,
        entries: this.archiveGroup.entries, comic: this.libraryStore?.getComic(this.archiveGroup.comicId),
        onClose: () => { this.archiveShown = false } })
    }
  }

  @Builder
  private GroupMenu(group: DownloadComicGroup, completed: boolean) {
    Menu() {
      if (this.libraryStore?.getComic(group.comicId) !== undefined) {
        MenuItem({ content: s('downloads_view_work') }).onClick(() => { this.openGroupWork(group, completed) })
      }
      if (completed) {
        MenuItem({ content: s('chapter_export_cbz') }).onClick(() => { this.openWorkArchive(group) })
        MenuItem({ content: s('downloads_action_delete_files') }).onClick(() => {
          this.confirmDelete(this.fullGroup(group.comicId, true), s('downloads_action_delete_files'))
        })
      } else {
        if (this.groupRecoveryEntry(group) !== undefined) {
          MenuItem({ content: s(this.recoveryLabel(this.groupRecoveryEntry(group)!)) }).onClick(() => {
            const entry = this.groupRecoveryEntry(group)
            if (entry !== undefined) this.recoverSource(entry)
          })
        }
        if (this.groupCanExplain(group) && !this.expandedGroups.has(this.groupKey(group, completed))) {
          MenuItem({ content: s('downloads_group_view_reason') }).onClick(() => { this.toggleGroup(group, completed, true) })
        }
        if (this.groupCanPause(group)) {
          MenuItem({ content: s('downloads_pause_group') }).onClick(() => { this.setPaused(this.fullGroup(group.comicId, false), true) })
        }
        if (this.groupCanResume(group)) {
          MenuItem({ content: s('downloads_resume_group') }).onClick(() => { this.setPaused(this.fullGroup(group.comicId, false), false) })
        }
        if (this.groupCanRetry(group)) {
          MenuItem({ content: s('downloads_action_retry_failed') }).onClick(() => { this.retryDownloads(this.fullGroup(group.comicId, false)) })
        }
        if (this.groupCanMove(group)) {
          MenuItem({ content: s('downloads_move_top') }).onClick(() => { this.moveGroup(group, true) })
          MenuItem({ content: s('downloads_move_bottom') }).onClick(() => { this.moveGroup(group, false) })
        }
        if (this.groupCanCancel(group)) {
          MenuItem({ content: s('downloads_cancel_group') }).onClick(() => {
            this.confirmCancel(this.fullGroup(group.comicId, false), s('downloads_cancel_group'))
          })
        }
      }
    }
  }

  @Builder
  private DownloadCover(comicId: string) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(ThemeConstants.FONT_SIZE_H2)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
      if ((this.libraryStore?.getComic(comicId)?.coverUri ?? '').length > 0) {
        CachedCoverImage({
          uri: this.libraryStore?.getComic(comicId)?.coverUri ?? '',
          objectFit: ImageFit.Cover,
          sourceRuntimeId: this.libraryStore?.getComic(comicId)?.sourceRuntimeId ?? '',
          sourceImageId: this.libraryStore?.getComic(comicId)?.remoteResourceId ?? comicId,
          sourceKind: this.libraryStore?.getComic(comicId)?.sourceKind,
          remoteServerId: this.libraryStore?.getComic(comicId)?.remoteServerId ?? '',
          sourceMangaUrl: this.libraryStore?.getComic(comicId)?.sourcePath ?? '',
          decodeMaxEdge: 192,
        })
      }
    }
    .width(ThemeConstants.LIST_COVER_WIDTH)
    .height(ThemeConstants.LIST_COVER_HEIGHT)
    .borderRadius(ThemeConstants.RADIUS_COVER)
    .clip(true)
    .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
  }

  @Builder
  private DownloadStatusIcon(key: string) {
    if (this.entryForKey(key) !== undefined) {
      SymbolGlyph(this.entryStatusIcon(this.entryForKey(key)!))
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontColor([this.entryStatusColor(this.entryForKey(key)!)])
    }
  }

  @Builder
  private DownloadChapterRow(key: string) {
    if (this.entryForKey(key) !== undefined) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          this.DownloadStatusIcon(key)

          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(this.rowTitle(this.entryForKey(key)!))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.rowDetailSubtitle(this.entryForKey(key)!))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(this.entryStatusColor(this.entryForKey(key)!))
              .maxLines(this.blockedHelpText(this.entryForKey(key)!).length > 0 ? 2 : 1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.shouldShowEntryProgress(this.entryForKey(key)!)) {
              Progress({ value: this.entryProgressValue(this.entryForKey(key)!), total: 100, type: ProgressType.Linear })
                .width('100%')
                .height(3)
                .color(this.entryStatusColor(this.entryForKey(key)!))
                .backgroundColor(ThemeConstants.SOFT_TINT)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          const entry = this.entryForKey(key)
          if (entry !== undefined) {
            this.openDownloadRow(entry)
          }
        })

        if (this.chrome.selecting) {
          SymbolGlyph(this.selection.has(key) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontColor([this.selection.has(key) ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_TERTIARY])
            .onClick(() => { this.toggleSelected(key) })
        } else if (!this.entryForKey(key)!.canceling) {
          KomaIconButton({
            icon: $r('sys.symbol.ellipsis_circle'),
            kind: 'ghost',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
            accentColor: ThemeConstants.TEXT_SECONDARY,
            action: () => {
              this.actionMenuKey = `row:${key}`
            },
          })
            .bindMenu(this.actionMenuKey === `row:${key}`, this.DownloadRowMenu(key), komaMenuOptions({
              placement: Placement.BottomRight,
              onDisappear: () => {
                if (this.actionMenuKey === `row:${key}`) {
                  this.closeActionMenu()
                }
              },
            }))
        }
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_LG,
        right: ThemeConstants.SPACE_LG,
        top: ThemeConstants.SPACE_MD,
        bottom: ThemeConstants.SPACE_MD,
      })
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private DownloadGroup(group: DownloadComicGroup, completed: boolean) {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          this.DownloadCover(group.comicId)
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(group.title)
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.groupSubtitle(group, completed))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
            .rotate({ angle: this.expandedGroups.has(this.groupKey(group, completed)) ? 180 : 0 })
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)
        .onClick(() => { this.toggleGroup(group, completed) })
        if (!this.chrome.selecting && (completed || this.groupCanCancel(group))) {
          KomaIconButton({
            icon: $r('sys.symbol.ellipsis_circle'),
            kind: 'ghost',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
            action: () => { this.actionMenuKey = this.groupKey(group, completed) },
          })
            .bindMenu(this.actionMenuKey === this.groupKey(group, completed), this.GroupMenu(group, completed),
              komaMenuOptions({ placement: Placement.BottomRight, onDisappear: () => {
                if (this.actionMenuKey === this.groupKey(group, completed)) this.closeActionMenu()
              } }))
        }
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .alignItems(VerticalAlign.Center)
      if (this.expandedGroups.has(this.groupKey(group, completed))) {
        Column() {
          Divider()
            .strokeWidth(0.5)
            .color(ThemeConstants.DIVIDER)
            .margin({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
          ForEach(this.visibleGroupEntries(group.comicId, completed), (entry: OfflineDownloadQueueEntry) => {
            this.DownloadChapterRow(this.rowKey(entry))
          }, (entry: OfflineDownloadQueueEntry) => this.rowKey(entry))
        }.width('100%').transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .clip(true)
  }

  @Builder
  private DownloadSectionTitle(label: string) {
    Text(label)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(ThemeConstants.TEXT_SECONDARY)
      .width('100%')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        bottomPadding: ThemeConstants.SPACE_XL,
        onDidScroll: (_offset: number, state: ScrollState): void => {
          this.onQueueDidScroll(state)
        },
      }) {
        if (this.entries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          ListItem() {
            this.QueueHeader()
          }
          if (this.visibleEntryList.length === 0) {
            ListItem() {
              this.EmptyState(this.hasActiveFilter())
            }.transition(filterRowTransition())
          }
          if (this.activeDownloadGroups.length > 0) {
            ListItem() { this.DownloadSectionTitle(s('downloads_tasks_section')) }
              .transition(filterRowTransition())
            ForEach(this.activeDownloadGroups, (group: DownloadComicGroup) => {
              ListItem() { this.DownloadGroup(group, false) }
                .transition(filterRowTransition())
            }, (group: DownloadComicGroup) => group.comicId)
          }
          if (this.completedDownloadGroups.length > 0) {
            ListItem() { this.DownloadSectionTitle(s('downloads_local_section')) }
              .transition(filterRowTransition())
            ForEach(this.completedDownloadGroups, (group: DownloadComicGroup) => {
              ListItem() { this.DownloadGroup(group, true) }
                .transition(filterRowTransition())
            }, (group: DownloadComicGroup) => group.comicId)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .bindSheet($$this.archiveShown, this.ArchiveSheet, komaModalSheetOptions({
      height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false, enableOutsideInteractive: false, scrollSizeMode: ScrollSizeMode.CONTINUOUS,
    }))
  }
}
