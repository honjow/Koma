import { ChapterArchiveActions } from '../model/ChapterArchiveExport'
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
import { canRunOfflineDownloadQueueNow, OfflineDownloadService } from '../model/OfflineDownloadService'
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
} from '../model/OfflineDownloadQueueStore'
import {
  ensureKomaContentStorageBase,
  komaContentStorageBase,
  komaRuntimeStorageKey,
} from '../model/KomaContentStorage'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { RouterHelper } from '../common/RouterHelper'

function s(name: string): string {
  return AppStrings.get(name)
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
      }
    }
  }

  private loadQueue(): void {
    try {
      const store = this.queueStore()
      const snapshot: OfflineDownloadQueueSnapshot = store.loadSnapshot()
      this.entries = snapshot.entries
      this.preferences = snapshot.preferences
    } catch (_error) {
      DiagnosticLogger.warn('downloads_page', 'load_queue_failed', '[Downloads] step=load_queue_failed code=queue_read_failed')
    }
  }

  private rowKey(entry: OfflineDownloadQueueEntry): string {
    return `${entry.comicId}::${entry.chapterId}`
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
      if (this.queueVisible) this.showToast(s('chapter_archive_failed'))
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
        (entry.status === OfflineDownloadStatus.PARTIAL && !this.canCancel(entry))
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
    return entry.status === OfflineDownloadStatus.QUEUED ||
      (entry.status === OfflineDownloadStatus.PARTIAL && this.canCancel(entry))
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
    this.filter = filter
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

  private blockedHelpText(entry: OfflineDownloadQueueEntry): string {
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'pages_missing') {
      return s('downloads_blocked_pages_missing')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'source_pages_failed') {
      return s('downloads_blocked_source_pages_failed')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'source_lookup_failed') {
      return s('downloads_blocked_source_lookup_failed')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'source_disabled') {
      return s('downloads_blocked_source_disabled')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'source_not_installed') {
      return s('downloads_blocked_source_not_installed')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'chapter_missing') {
      return s('downloads_blocked_chapter_missing')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'comic_missing') {
      return s('downloads_blocked_comic_missing')
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED) {
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

  private isPausedDownload(status: OfflineDownloadStatus, reason?: string): boolean {
    return reason === 'paused' &&
      (status === OfflineDownloadStatus.QUEUED || status === OfflineDownloadStatus.PARTIAL)
  }

  private formatEntryStatus(entry: OfflineDownloadQueueEntry): string {
    if (this.isPausedDownload(entry.status, entry.failureReasonCode)) {
      return s('downloads_status_paused')
    }
    if (entry.status === OfflineDownloadStatus.QUEUED || entry.status === OfflineDownloadStatus.PARTIAL) {
      if (this.preferences.isPaused && (entry.status === OfflineDownloadStatus.QUEUED ||
        entry.failureReasonCode === 'wifi_only')) return s('downloads_status_paused')
      if (entry.failureReasonCode === 'wifi_only' || (entry.status === OfflineDownloadStatus.QUEUED &&
        !canRunOfflineDownloadQueueNow(this.preferences))) return s('downloads_status_waiting_wifi')
    }
    return this.formatStatus(entry.status)
  }

  private queueOverviewTitle(): string {
    const count = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => !this.canRead(entry)).length
    return count > 0 ? s('downloads_tasks_count').replace('%s', `${count}`) : s('downloads_tasks_section')
  }

  private queueOverviewSubtitle(): string {
    const summary: OfflineDownloadQueueSummary = summarizeOfflineDownloadQueue(this.entries)
    const pausedPartialCount = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      entry.status === OfflineDownloadStatus.PARTIAL && this.isPausedDownload(entry.status, entry.failureReasonCode)).length
    const pausedCount = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      this.isPausedDownload(entry.status, entry.failureReasonCode) ||
        (this.preferences.isPaused && entry.status === OfflineDownloadStatus.QUEUED)).length
    const attentionCount = summary.failedCount + summary.partialCount + summary.blockedCount - pausedPartialCount
    if (pausedCount > 0) {
      return s('downloads_overview_paused').replace('%s', `${pausedCount}`)
    }
    if (summary.queuedCount > 0 && !canRunOfflineDownloadQueueNow(this.preferences)) {
      return s('downloads_status_waiting_wifi')
    }
    if (summary.downloadingCount > 0) {
      return s('downloads_overview_downloading').replace('%s', `${Math.max(1, summary.downloadingCount)}`)
    }
    if (attentionCount > 0) {
      return s('downloads_overview_attention').replace('%s', `${attentionCount}`)
    }
    if (summary.queuedCount > 0) {
      return s('downloads_overview_queued').replace('%s', `${summary.queuedCount}`)
    }
    return s('downloads_no_pending_tasks')
  }

  @Computed
  private get queueOverviewText(): string[] {
    return [this.queueOverviewTitle(), this.queueOverviewSubtitle()]
  }

  private groupSubtitle(group: DownloadComicGroup): string {
    return s('downloads_chapters_count').replace('%s', `${group.entries.length}`)
  }

  private shouldShowPrimaryQueueAction(): boolean {
    return this.preferences.isPaused ||
      this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.canCancel(entry))
  }

  private hasStagedEntries(): boolean {
    return this.entries.some((entry: OfflineDownloadQueueEntry): boolean => entry.automatic !== true &&
      (entry.status === OfflineDownloadStatus.QUEUED ||
        (entry.status === OfflineDownloadStatus.PARTIAL && this.canCancel(entry))))
  }

  private shouldStartStagedEntries(): boolean {
    return this.hasStagedEntries() && !this.entries.some((entry: OfflineDownloadQueueEntry): boolean =>
      (entry.automatic === true && this.canCancel(entry)) || entry.status === OfflineDownloadStatus.DOWNLOADING)
  }

  private primaryQueueActionLabel(): string {
    if (this.preferences.isPaused) {
      return this.busyKey === 'resume' ? s('downloads_action_resuming') : s('downloads_action_resume_queue')
    }
    return this.shouldStartStagedEntries() ? s('downloads_action_start_queue') : s('downloads_action_pause_queue')
  }

  private primaryQueueActionKind(): 'primary' | 'ghost' {
    return this.preferences.isPaused || this.shouldStartStagedEntries() ? 'primary' : 'ghost'
  }

  private handlePrimaryQueueAction(): void {
    if (!OfflineDownloadRuntime.isInitialized(this.context().filesDir) || this.busyKey.length > 0) return
    if (this.preferences.isPaused || this.shouldStartStagedEntries()) {
      void this.startPendingDownloads()
    } else {
      this.pauseQueuedDownloads()
    }
  }

  private canRetry(entry: OfflineDownloadQueueEntry): boolean {
    return this.libraryStore?.getComic(entry.comicId) !== undefined && !this.canCancel(entry) &&
      (entry.status === OfflineDownloadStatus.FAILED || entry.status === OfflineDownloadStatus.PARTIAL ||
        this.isRecoverableBlockedEntry(entry))
  }

  private isRecoverableBlockedEntry(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.BLOCKED &&
      (entry.failureReasonCode === 'pages_missing' ||
        entry.failureReasonCode === 'source_pages_failed' ||
        entry.failureReasonCode === 'source_lookup_failed' ||
        entry.failureReasonCode === 'source_not_installed' ||
        entry.failureReasonCode === 'source_disabled')
  }

  private retryableEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
  }

  private canCancel(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.QUEUED || entry.status === OfflineDownloadStatus.DOWNLOADING ||
      this.isPausedDownload(entry.status, entry.failureReasonCode) || entry.failureReasonCode === 'wifi_only'
  }

  private canRead(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.DOWNLOADED
  }

  private cleanupEntries(completed: boolean): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean =>
      completed ? this.canRead(entry) : !this.canRead(entry) && !this.canCancel(entry))
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

  private retryDownloads(targets: OfflineDownloadQueueEntry[]): void {
    if (this.busyKey.length > 0) return
    let count = 0
    try {
      const queue = this.queueStore()
      const chaptersByComic = new Map<string, string[]>()
      targets.forEach((entry: OfflineDownloadQueueEntry) => {
        const ids = chaptersByComic.get(entry.comicId) ?? []
        ids.push(entry.chapterId)
        chaptersByComic.set(entry.comicId, ids)
      })
      chaptersByComic.forEach((ids: string[], comicId: string) => {
        const comic = this.libraryStore?.getComic(comicId)
        if (comic !== undefined) count += queue.requestChapters(comic, ids)
      })
      this.showToast(count === 0 ? s('downloads_toast_no_retryable') :
        this.preferences.isPaused ? s('downloads_status_paused') :
          !canRunOfflineDownloadQueueNow(this.preferences) ? s('downloads_status_waiting_wifi') :
            s('library_download_enqueued').replace('%s', `${count}`))
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'retry_enqueue_failed', error as Error)
      this.showToast(s('downloads_toast_retry_failed'))
    }
  }

  private removeDownload(entry: OfflineDownloadQueueEntry): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.busyKey = this.rowKey(entry)
    void this.queueStore().deleteChapterDownload(entry.comicId, entry.chapterId)
      .then(() => {
        this.loadQueue()
        this.showToast(s(this.canCancel(entry) ? 'downloads_task_canceled' : 'downloads_toast_removed'))
      })
      .catch((error: Error) => {
        void error
        DiagnosticLogger.warn('downloads_page', 'remove_failed', '[Downloads] step=remove_failed failed=true reason=download_remove')
        this.showToast(s('downloads_toast_remove_failed'))
      })
      .finally(() => {
        this.busyKey = ''
      })
  }

  private confirmRemoveDownload(entry: OfflineDownloadQueueEntry): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s(this.canCancel(entry) ? 'downloads_cancel_task' : 'downloads_remove_title'),
      message: s(this.canCancel(entry) ? 'downloads_cancel_message' : 'downloads_remove_message')
        .replace('%s', this.rowTitle(entry)),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeDownload(entry)
        },
      },
    })
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

  private confirmCleanup(completed: boolean): void {
    if (this.busyKey.length > 0) return
    const targets = this.cleanupEntries(completed)
    if (targets.length === 0) return
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s(completed ? 'downloads_delete_completed' : 'downloads_clear_failed'),
      message: s(completed ? 'downloads_delete_completed_confirm' : 'downloads_clear_failed_confirm')
        .replace('%s', `${targets.length}`),
      autoCancel: true,
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: { value: s('common_confirm'), fontColor: ThemeConstants.DANGER,
        action: () => { void this.runRemoveBatch(targets, completed) } },
    })
  }

  private async runRemoveBatch(targets: OfflineDownloadQueueEntry[], completed: boolean): Promise<void> {
    if (this.busyKey.length > 0) return
    this.busyKey = 'cleanup'
    try {
      const allowed = new Set(this.cleanupEntries(completed).map((entry: OfflineDownloadQueueEntry): string => this.rowKey(entry)))
      const store = this.queueStore()
      for (const entry of targets) {
        if (allowed.has(this.rowKey(entry))) await store.deleteChapterDownload(entry.comicId, entry.chapterId)
      }
      this.loadQueue()
      this.showToast(s('downloads_toast_removed'))
    } catch (error) {
      DiagnosticLogger.exception('downloads_page', 'batch_remove_failed', error as Error)
      this.showToast(s('downloads_toast_cleanup_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_error) {
    }
  }

  private entryStatusIcon(entry: OfflineDownloadQueueEntry): Resource {
    if (this.isPausedDownload(entry.status, entry.failureReasonCode)) {
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
    if (this.isPausedDownload(entry.status, entry.failureReasonCode)) {
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
    if (this.canRead(entry)) {
      this.openDownloadedChapter(entry)
      return
    }
    this.actionMenuKey = this.rowKey(entry)
  }

  private closeActionMenu(): void {
    this.actionMenuKey = ''
  }

  @Builder
  private QueueMoreMenu() {
    Menu() {
      MenuItem({ content: s('downloads_action_retry_failed') })
        .enabled(this.busyKey.length === 0 && this.retryableEntries().length > 0)
        .onClick(() => { this.retryDownloads(this.retryableEntries()) })
      MenuItem({ content: s('downloads_clear_failed') })
        .enabled(this.busyKey.length === 0 && this.cleanupEntries(false).length > 0)
        .onClick(() => { this.confirmCleanup(false) })
      MenuItem({ content: s('downloads_delete_completed') })
        .enabled(this.busyKey.length === 0 && this.cleanupEntries(true).length > 0)
        .onClick(() => { this.confirmCleanup(true) })
      MenuItem({ content: s('downloads_action_rescan') })
        .enabled(this.busyKey.length === 0)
        .onClick(() => {
          this.rescanDownloads()
        })
    }
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
    this.unsubscribeQueue = OfflineDownloadRuntime.subscribe(this.context().filesDir, () => {
      this.scheduleQueueRefresh()
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

  private scheduleQueueRefresh(): void {
    if (this.queueScrolling) {
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

        Row({ space: ThemeConstants.SPACE_XS }) {
          if (this.shouldShowPrimaryQueueAction()) {
            KomaActionButton({
              label: this.primaryQueueActionLabel(),
              kind: this.primaryQueueActionKind(),
              isEnabled: this.busyKey !== 'initialize' && (!this.preferences.isPaused || this.busyKey.length === 0),
              compact: true,
              controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
              action: () => {
                this.handlePrimaryQueueAction()
              },
            })
          }
          KomaIconButton({
            icon: $r('sys.symbol.ellipsis_circle'),
            kind: 'secondary',
            controlSize: ThemeConstants.TOUCH_TARGET_SM,
            iconSize: ThemeConstants.FONT_SIZE_H3,
            action: () => {
              this.actionMenuKey = 'queue'
            },
          })
            .bindMenu(this.actionMenuKey === 'queue', this.QueueMoreMenu(), komaMenuOptions({
              placement: Placement.BottomRight,
              onDisappear: () => {
                if (this.actionMenuKey === 'queue') {
                  this.closeActionMenu()
                }
              },
            }))
        }
        .alignItems(VerticalAlign.Center)
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

  @Builder
  private DownloadRowMenu(key: string) {
    if (this.entryForKey(key) !== undefined) {
      Menu() {
        if (this.libraryStore?.getComic(this.entryForKey(key)!.comicId) !== undefined) {
          MenuItem({ content: s('downloads_action_open_manga') })
          .onClick(() => {
            const entry = this.entryForKey(key)
            if (entry !== undefined) {
              this.openDownloadEntry(entry)
            }
          })
        }
        if (this.canCancel(this.entryForKey(key)!)) {
          MenuItem({ content: s('downloads_move_top') }).onClick(() => { this.moveDownload(key, true, false) })
          MenuItem({ content: s('downloads_move_bottom') }).onClick(() => { this.moveDownload(key, false, false) })
          MenuItem({ content: s('downloads_move_book_top') }).onClick(() => { this.moveDownload(key, true, true) })
          MenuItem({ content: s('downloads_move_book_bottom') }).onClick(() => { this.moveDownload(key, false, true) })
        } else if (this.canRead(this.entryForKey(key)!)) {
          MenuItem({ content: s('chapter_export_cbz') }).enabled(!this.chapterArchiveBusy)
            .onClick(() => { void this.exportChapter(key, false) })
          MenuItem({ content: s('chapter_share_cbz') }).enabled(!this.chapterArchiveBusy)
            .onClick(() => { void this.exportChapter(key, true) })
        }
        if (this.canRetry(this.entryForKey(key)!)) {
          MenuItem({ content: this.busyKey === this.rowKey(this.entryForKey(key)!) ? s('common_retrying') : s('common_retry') })
            .enabled(this.busyKey.length === 0)
            .onClick(() => {
              const entry = this.entryForKey(key)
              if (entry !== undefined) {
                this.retryDownloads([entry])
              }
            })
        }
        MenuItem({ content: s(this.canRead(this.entryForKey(key)!) ? 'downloads_action_delete_files' :
          this.canCancel(this.entryForKey(key)!) ? 'downloads_cancel_task' : 'downloads_clear_task') })
            .enabled(this.busyKey.length === 0)
            .onClick(() => {
              const entry = this.entryForKey(key)
              if (entry !== undefined) {
                this.confirmRemoveDownload(entry)
              }
            })
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
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_LG,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_MD,
        bottom: ThemeConstants.SPACE_MD,
      })
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private DownloadGroup(group: DownloadComicGroup, completed: boolean) {
    Column() {
        Row({ space: ThemeConstants.SPACE_MD }) {
          this.DownloadCover(group.comicId)
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(group.title)
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.groupSubtitle(group))
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
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          if (this.libraryStore?.getComic(group.comicId) !== undefined) this.openDownloadEntry(group.entries[0])
        })

        Divider()
          .strokeWidth(0.5)
          .color(ThemeConstants.DIVIDER)
          .margin({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })

        ForEach(group.entries, (entry: OfflineDownloadQueueEntry) => {
          this.DownloadChapterRow(this.rowKey(entry))
        }, (entry: OfflineDownloadQueueEntry) => this.rowKey(entry))
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
            }
          }
          if (this.activeDownloadGroups.length > 0) {
            ListItem() { this.DownloadSectionTitle(s('downloads_tasks_section')) }
            ForEach(this.activeDownloadGroups, (group: DownloadComicGroup) => {
              ListItem() { this.DownloadGroup(group, false) }
            }, (group: DownloadComicGroup) => group.comicId)
          }
          if (this.completedDownloadGroups.length > 0) {
            ListItem() { this.DownloadSectionTitle(s('downloads_local_section')) }
            ForEach(this.completedDownloadGroups, (group: DownloadComicGroup) => {
              ListItem() { this.DownloadGroup(group, true) }
            }, (group: DownloadComicGroup) => group.comicId)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
