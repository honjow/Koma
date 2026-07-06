import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Comic } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { canRunOfflineDownloadQueueNow, OfflineDownloadService } from '../model/OfflineDownloadService'
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadStatus,
  OfflineDownloadStore,
} from '../model/OfflineDownloadStore'
import {
  OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS,
  OfflineDownloadQueueEntry,
  OfflineDownloadQueuePreferences,
  OfflineDownloadQueueRecoverySummary,
  OfflineDownloadQueueSummary,
  OfflineDownloadQueueStore,
  summarizeOfflineDownloadQueue,
} from '../model/OfflineDownloadQueueStore'
import { installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'
import {
  SourceChapterPageHydrationResult,
  SourceChapterPageHydrator,
} from '../model/SourceChapterPageHydrator'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { RouterHelper } from '../common/RouterHelper'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'

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

@ComponentV2
export struct DownloadsPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param sourceRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
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
  @Event onOpenReader: (comicId: string, chapterId?: string) => void =
    (_comicId: string, _chapterId?: string) => {}
  @Event onLibraryChanged: () => void = () => {}

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private queueStore(): OfflineDownloadQueueStore {
    return new OfflineDownloadQueueStore(this.context().filesDir)
  }

  private loadQueue(reconcileManifests: boolean = true): void {
    const store = this.queueStore()
    this.entries = reconcileManifests ? store.reconcileWithManifests() : store.load()
    this.preferences = store.loadPreferences()
  }

  private rowKey(entry: OfflineDownloadQueueEntry): string {
    return `${entry.comicId}::${entry.chapterId}`
  }

  private visibleEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      if (this.filter === DownloadQueueFilter.ALL) {
        return true
      }
      if (this.filter === DownloadQueueFilter.FAILED) {
        return entry.status === OfflineDownloadStatus.FAILED ||
          entry.status === OfflineDownloadStatus.PARTIAL
      }
      if (this.filter === DownloadQueueFilter.DOWNLOADED) {
        return entry.status === OfflineDownloadStatus.DOWNLOADED
      }
      if (this.filter === DownloadQueueFilter.BLOCKED) {
        return entry.status === OfflineDownloadStatus.BLOCKED
      }
      if (this.filter === DownloadQueueFilter.DOWNLOADING) {
        return entry.status === OfflineDownloadStatus.DOWNLOADING
      }
      return entry.status === OfflineDownloadStatus.QUEUED
    })
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
    const comicTitle = entry.comicTitle !== undefined && entry.comicTitle.length > 0 ? entry.comicTitle : entry.comicId
    return s('downloads_row_subtitle')
      .replace('%s', comicTitle)
      .replace('%s', this.formatEntryStatus(entry))
      .replace('%s', `${entry.downloadedPageCount}`)
      .replace('%s', `${entry.pageCount}`)
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

  private formatEntryStatus(entry: OfflineDownloadQueueEntry): string {
    if (entry.failureReasonCode === 'paused') {
      return s('downloads_status_paused')
    }
    if (entry.failureReasonCode === 'wifi_only') {
      return s('downloads_status_waiting_wifi')
    }
    if (this.preferences.isPaused && entry.status === OfflineDownloadStatus.QUEUED) {
      return s('downloads_status_paused')
    }
    return this.formatStatus(entry.status)
  }

  private queueStateText(): string {
    const summary = summarizeOfflineDownloadQueue(this.entries)
    const state = this.preferences.isPaused
      ? s('downloads_queue_state_paused')
      : (!canRunOfflineDownloadQueueNow(this.preferences) ? s('downloads_status_waiting_wifi') :
        (summary.downloadingCount > 0 || this.busyKey.length > 0 ? s('downloads_queue_state_running') : s('downloads_queue_state_queued')))
    return s('downloads_queue_summary')
      .replace('%s', state)
      .replace('%s', `${summary.queuedCount}`)
      .replace('%s', `${summary.failedCount + summary.partialCount}`)
      .replace('%s', `${summary.blockedCount}`)
      .replace('%s', `${this.preferences.foregroundConcurrencyLimit}`)
  }

  private queueProgressText(): string {
    const summary: OfflineDownloadQueueSummary = summarizeOfflineDownloadQueue(this.entries)
    return s('downloads_queue_progress')
      .replace('%s', `${summary.downloadedPageCount}`)
      .replace('%s', `${summary.pageCount}`)
      .replace('%s', `${summary.totalCount}`)
      .replace('%s', `${summary.downloadedCount}`)
      .replace('%s', `${summary.partialCount}`)
  }

  private queuedEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.QUEUED
    })
  }

  private primaryQueueActionLabel(): string {
    if (this.preferences.isPaused) {
      return this.busyKey === 'batch-resume' ? s('downloads_action_resuming') : s('downloads_action_resume_queue')
    }
    if (this.busyKey.length > 0) {
      return s('downloads_action_pause_queue')
    }
    return this.queuedEntries().length > 0 ? s('downloads_action_start_queue') : s('downloads_action_pause_queue')
  }

  private primaryQueueActionKind(): 'primary' | 'ghost' {
    return this.preferences.isPaused || this.queuedEntries().length > 0 ? 'primary' : 'ghost'
  }

  private handlePrimaryQueueAction(): void {
    if (this.preferences.isPaused) {
      this.resumeQueuedDownloads()
      return
    }
    if (this.busyKey.length > 0) {
      this.pauseQueuedDownloads()
      return
    }
    if (this.queuedEntries().length > 0) {
      this.startQueuedDownloads()
      return
    }
    this.pauseQueuedDownloads()
  }

  private canRetry(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.FAILED ||
      entry.status === OfflineDownloadStatus.PARTIAL ||
      this.isRecoverableBlockedEntry(entry)
  }

  private isRecoverableBlockedEntry(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.BLOCKED &&
      (entry.failureReasonCode === 'pages_missing' ||
        entry.failureReasonCode === 'source_pages_failed' ||
        entry.failureReasonCode === 'source_lookup_failed' ||
        entry.failureReasonCode === 'source_not_installed' ||
        entry.failureReasonCode === 'source_disabled')
  }

  private canStartQueueWork(): boolean {
    if (this.preferences.isPaused) {
      this.showToast(s('downloads_toast_queue_paused'))
      return false
    }
    if (!canRunOfflineDownloadQueueNow(this.preferences)) {
      this.showToast(s('downloads_status_waiting_wifi'))
      return false
    }
    return true
  }

  private retryableEntries(): OfflineDownloadQueueEntry[] {
    return this.visibleEntries().filter((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
  }

  private removableSettledEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.DOWNLOADED ||
        entry.status === OfflineDownloadStatus.FAILED ||
        entry.status === OfflineDownloadStatus.PARTIAL ||
        entry.status === OfflineDownloadStatus.BLOCKED
    })
  }

  private canRemove(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status !== OfflineDownloadStatus.DOWNLOADING && entry.status !== OfflineDownloadStatus.QUEUED
  }

  private canRead(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.DOWNLOADED ||
      entry.status === OfflineDownloadStatus.PARTIAL
  }

  private hasReadableDownloadedManifest(entry: OfflineDownloadQueueEntry): boolean {
    try {
      const validation = new OfflineDownloadStore(this.context().filesDir)
        .validateDownloadedChapter(entry.comicId, entry.chapterId, { validateContentHash: false })
      return validation.manifest !== undefined &&
        validation.availablePageCount > 0 &&
        (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
          validation.status === OfflineDownloadedChapterStatus.PARTIAL)
    } catch (_error) {
      console.warn('[Downloads] step=read_manifest_validation_failed failed=true reason=download_manifest')
      return false
    }
  }

  private blockUnavailableEntry(entry: OfflineDownloadQueueEntry): void {
    const blocked = this.queueStore().upsert({
      comicId: entry.comicId,
      chapterId: entry.chapterId,
      comicTitle: entry.comicTitle,
      chapterTitle: entry.chapterTitle,
      status: OfflineDownloadStatus.BLOCKED,
      pageCount: entry.pageCount,
      downloadedPageCount: entry.downloadedPageCount,
      updatedAt: Date.now(),
      failureReasonCode: 'comic_missing',
    })
    this.entries = this.entries.map((item: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => {
      return this.rowKey(item) === this.rowKey(blocked) ? blocked : item
    })
  }

  private blockSourcePagesUnavailable(
    comic: Comic,
    entry: OfflineDownloadQueueEntry,
    reasonCode: string
  ): OfflineDownloadQueueEntry {
    const service = new OfflineDownloadService(
      new OfflineDownloadStore(this.context().filesDir),
      this.queueStore()
    )
    const manifest = service.blockChapterDownload(comic, entry.chapterId, reasonCode, {
      comicTitle: entry.comicTitle ?? comic.title,
      chapterTitle: entry.chapterTitle,
    })
    const blocked = this.queueStore().fromManifest(manifest, entry.comicTitle ?? comic.title, entry.chapterTitle)
    this.entries = this.entries.map((item: OfflineDownloadQueueEntry): OfflineDownloadQueueEntry => {
      return this.rowKey(item) === this.rowKey(blocked) ? blocked : item
    })
    return blocked
  }

  private openDownloadEntry(entry: OfflineDownloadQueueEntry): void {
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.blockUnavailableEntry(entry)
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    const sourceId = comic.sourceRuntimeId?.trim()
    const sourceMangaId = comic.remoteResourceId?.trim()
    if (sourceId !== undefined && sourceId.length > 0 && sourceMangaId !== undefined && sourceMangaId.length > 0) {
      RouterHelper.pushMangaDetail({ mangaId: sourceMangaId, sourceId })
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
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.blockUnavailableEntry(entry)
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    this.onOpenReader(entry.comicId, entry.chapterId)
  }

  private retryDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRetry(entry) || this.busyKey.length > 0) {
      return
    }
    if (!this.canStartQueueWork()) {
      return
    }
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.blockUnavailableEntry(entry)
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    this.busyKey = this.rowKey(entry)
    void this.runRetry(comic, entry)
  }

  private async runRetry(comic: Comic, entry: OfflineDownloadQueueEntry): Promise<void> {
    try {
      const hydration = await this.ensureSourcePagesForDownload(comic, entry.chapterId)
      if (!hydration.hydrated) {
        this.blockSourcePagesUnavailable(comic, entry, hydration.reasonCode ?? 'pages_missing')
        this.loadQueue(false)
        this.showToast(s('downloads_toast_retry_failed'))
        return
      }
      try {
        await installReaderRemoteHeadersForComic(this.context(), comic)
      } catch (_error) {
      }
      const service = new OfflineDownloadService(
        new OfflineDownloadStore(this.context().filesDir),
        this.queueStore()
      )
      await service.downloadChapter(comic, entry.chapterId, {
        comicTitle: entry.comicTitle ?? comic.title,
        chapterTitle: entry.chapterTitle,
      })
      this.loadQueue()
      this.showToast(s('downloads_toast_retried'))
    } catch (error) {
      void error
      console.warn('[Downloads] step=retry_failed failed=true reason=download_retry')
      this.showToast(s('downloads_toast_retry_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private removeDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRemove(entry) || this.busyKey.length > 0) {
      return
    }
    this.busyKey = this.rowKey(entry)
    void this.queueStore().deleteChapterDownload(entry.comicId, entry.chapterId)
      .then(() => {
        this.loadQueue()
        this.showToast(s('downloads_toast_removed'))
      })
      .catch((error: Error) => {
        void error
        console.warn('[Downloads] step=remove_failed failed=true reason=download_remove')
        this.showToast(s('downloads_toast_remove_failed'))
      })
      .finally(() => {
        this.busyKey = ''
      })
  }

  private confirmRemoveDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRemove(entry) || this.busyKey.length > 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('downloads_remove_title'),
      message: s('downloads_remove_message').replace('%s', this.rowTitle(entry)),
      autoCancel: true,
      primaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeDownload(entry)
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private retryFailedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    if (!this.canStartQueueWork()) {
      return
    }
    const targets = this.retryableEntries()
    if (targets.length === 0) {
      this.showToast(s('downloads_toast_no_retryable'))
      return
    }
    this.busyKey = 'batch-retry'
    void this.runRetryBatch(targets)
  }

  private async runRetryBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const retried = await this.runForegroundDownloadBatch(targets)
      this.loadQueue()
      this.showToast(retried > 0 ? s('downloads_toast_retried_failed') : s('downloads_toast_no_retryable'))
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_retry_failed failed=true reason=batch_retry')
      this.showToast(s('downloads_toast_batch_retry_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private pauseQueuedDownloads(): void {
    this.preferences = this.queueStore().pauseAllQueuedWork()
    this.loadQueue(false)
    this.showToast(s('downloads_toast_paused_queued'))
  }

  private startQueuedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    if (!this.canStartQueueWork()) {
      return
    }
    const targets = this.queuedEntries()
    if (targets.length === 0) {
      this.showToast(s('downloads_toast_no_queued'))
      return
    }
    this.busyKey = 'batch-start'
    void this.runStartBatch(targets)
  }

  private async runStartBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const started = await this.runForegroundDownloadBatch(targets)
      this.loadQueue()
      this.showToast(started > 0 ? s('downloads_toast_started_queued') : s('downloads_toast_no_queued'))
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_start_failed failed=true reason=batch_start')
      this.showToast(s('downloads_toast_start_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private resumeQueuedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.preferences = this.queueStore().resumeAllQueuedWork()
    if (!this.canStartQueueWork()) {
      return
    }
    const targets = this.queuedEntries()
    if (targets.length === 0) {
      this.loadQueue()
      this.showToast(s('downloads_toast_no_queued'))
      return
    }
    this.busyKey = 'batch-resume'
    void this.runResumeBatch(targets)
  }

  private async runResumeBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const resumed = await this.runForegroundDownloadBatch(targets)
      this.loadQueue()
      this.showToast(resumed > 0 ? s('downloads_toast_resumed_queued') : s('downloads_toast_no_resumable'))
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_resume_failed failed=true reason=batch_resume')
      this.showToast(s('downloads_toast_resume_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private setForegroundConcurrencyLimit(limit: number): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.preferences = this.queueStore().setForegroundConcurrencyLimit(limit)
    this.loadQueue()
  }

  private setWifiOnly(wifiOnly: boolean): void {
    if (this.busyKey.length > 0) {
      return
    }
    try {
      this.preferences = this.queueStore().setWifiOnly(wifiOnly)
      this.loadQueue(false)
    } catch (error) {
      void error
      console.warn('[Downloads] step=save_wifi_only_failed failed=true reason=queue_preference')
      this.showToast(s('settings_download_wifi_only_save_failed'))
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
      console.warn('[Downloads] step=rescan_failed failed=true reason=manifest_rescan')
      this.showToast(s('downloads_toast_rescan_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private async runForegroundDownloadBatch(targets: OfflineDownloadQueueEntry[]): Promise<number> {
    const concurrencyLimit = Math.max(1, Math.min(3, Math.floor(this.preferences.foregroundConcurrencyLimit)))
    let nextIndex = 0
    let completed = 0
    const worker = async (): Promise<void> => {
      while (nextIndex < targets.length && !this.queueStore().loadPreferences().isPaused) {
        const entry = targets[nextIndex]
        nextIndex += 1
        const comic = this.libraryStore?.getComic(entry.comicId)
        if (entry.status === OfflineDownloadStatus.BLOCKED && !this.isRecoverableBlockedEntry(entry)) {
          continue
        }
        if (comic === undefined) {
          this.blockUnavailableEntry(entry)
          continue
        }
        const hydration = await this.ensureSourcePagesForDownload(comic, entry.chapterId)
        if (!hydration.hydrated) {
          this.blockSourcePagesUnavailable(comic, entry, hydration.reasonCode ?? 'pages_missing')
          continue
        }
        try {
          await installReaderRemoteHeadersForComic(this.context(), comic)
        } catch (_error) {
        }
        const service = new OfflineDownloadService(
          new OfflineDownloadStore(this.context().filesDir),
          this.queueStore()
        )
        await service.downloadChapter(comic, entry.chapterId, {
          comicTitle: entry.comicTitle ?? comic.title,
          chapterTitle: entry.chapterTitle,
        })
        completed += 1
      }
    }
    const workers: Promise<void>[] = []
    for (let index = 0; index < concurrencyLimit && index < targets.length; index += 1) {
      workers.push(worker())
    }
    await Promise.all(workers)
    return completed
  }

  private async ensureSourcePagesForDownload(comic: Comic, chapterId: string): Promise<SourceChapterPageHydrationResult> {
    const sourceId = comic.sourceRuntimeId
    if (sourceId === undefined || sourceId.trim().length === 0 || this.libraryStore === undefined) {
      return { hydrated: true, pageCount: 0 }
    }
    const result = await new SourceChapterPageHydrator(
      this.libraryStore,
      this.sourceRegistry,
      this.libraryPersistenceService,
      () => {
        this.onLibraryChanged()
      },
    ).ensureChapterPages(comic.id, sourceId, chapterId)
    if (!result.hydrated) {
      console.warn(`[Downloads] step=source_pages_hydrate_unavailable reason=${result.reasonCode ?? 'unknown'}`)
    }
    return result
  }

  private removeCompletedFailedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    const targets = this.removableSettledEntries()
    if (targets.length === 0) {
      this.showToast(s('downloads_toast_no_cleanup'))
      return
    }
    this.busyKey = 'batch-remove'
    void this.runRemoveBatch(targets)
  }

  private confirmRemoveCompletedFailedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    const targets = this.removableSettledEntries()
    if (targets.length === 0) {
      this.showToast(s('downloads_toast_no_cleanup'))
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('downloads_cleanup_title'),
      message: s('downloads_cleanup_message').replace('%s', `${targets.length}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeCompletedFailedDownloads()
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private async runRemoveBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const store = this.queueStore()
      for (let index = 0; index < targets.length; index += 1) {
        const entry = targets[index]
        if (entry.status === OfflineDownloadStatus.DOWNLOADED ||
          entry.status === OfflineDownloadStatus.FAILED ||
          entry.status === OfflineDownloadStatus.PARTIAL ||
          entry.status === OfflineDownloadStatus.BLOCKED) {
          await store.deleteChapterDownload(entry.comicId, entry.chapterId)
        }
      }
      this.loadQueue()
      this.showToast(s('downloads_toast_cleanup_done'))
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_remove_failed failed=true reason=batch_remove')
      this.showToast(s('downloads_toast_cleanup_failed'))
    } finally {
      this.busyKey = ''
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  @Builder
  private ConcurrencyMenu() {
    Menu() {
      ForEach(OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS, (limit: number) => {
        MenuItem({ content: `${limit}` })
          .onClick(() => {
            this.setForegroundConcurrencyLimit(limit)
          })
      }, (limit: number) => `${limit}`)
    }
  }

  aboutToAppear(): void {
    this.loadQueue()
  }

  @Builder
  private FilterMenu() {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.ALL)
        })
      MenuItem({ content: s('downloads_filter_queued') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.QUEUED)
        })
      MenuItem({ content: s('downloads_filter_downloading') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADING)
        })
      MenuItem({ content: s('downloads_filter_failed') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.FAILED)
        })
      MenuItem({ content: s('downloads_filter_blocked') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.BLOCKED)
        })
      MenuItem({ content: s('downloads_filter_downloaded') })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADED)
        })
    }
  }

  @Builder
  private WifiOnlyControl() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: 2 }) {
        Text(s('settings_row_download_wifi_only_title'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(s('settings_row_download_wifi_only_detail'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.preferences.wifiOnly })
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .enabled(this.busyKey.length === 0)
        .onChange((isOn: boolean) => {
          this.setWifiOnly(isOn)
        })
    }
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private QueueControls() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.queueStateText())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.queueProgressText())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.WifiOnlyControl()

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaActionButton({
          label: s('downloads_filter_chip').replace('%s', this.filterLabel()),
          icon: $r('sys.symbol.chevron_down'),
          kind: this.filter === DownloadQueueFilter.ALL ? 'secondary' : 'primary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        })
          .bindMenu(this.FilterMenu(), {
            placement: Placement.BottomLeft,
          })

        KomaActionButton({
          label: s('downloads_concurrency_chip').replace('%s', `${this.preferences.foregroundConcurrencyLimit}`),
          icon: $r('sys.symbol.chevron_down'),
          kind: 'secondary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.busyKey.length === 0,
        })
          .bindMenu(this.ConcurrencyMenu(), {
            placement: Placement.BottomRight,
          })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaActionButton({
          label: this.primaryQueueActionLabel(),
          kind: this.primaryQueueActionKind(),
          isEnabled: !this.preferences.isPaused || this.busyKey.length === 0,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.handlePrimaryQueueAction()
          },
        })
        KomaActionButton({
          label: this.busyKey === 'batch-retry' ? s('common_retrying') : s('downloads_action_retry_failed'),
          kind: 'ghost',
          isEnabled: this.busyKey.length === 0 && !this.preferences.isPaused,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.retryFailedDownloads()
          },
        })
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaActionButton({
          label: this.busyKey === 'batch-remove' ? s('downloads_action_cleaning') : s('downloads_action_cleanup_finished_failed'),
          kind: 'ghost',
          isEnabled: this.busyKey.length === 0,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.confirmRemoveCompletedFailedDownloads()
          },
        })
        KomaActionButton({
          label: this.busyKey === 'rescan' ? s('downloads_action_rescanning') : s('downloads_action_rescan'),
          kind: 'ghost',
          isEnabled: this.busyKey.length === 0,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.rescanDownloads()
          },
        })
      }
      .width('100%')

      if (this.recoveryText.length > 0) {
        Text(this.recoveryText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
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
  private DownloadRow(entry: OfflineDownloadQueueEntry) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      ConciseListRow({
        title: this.rowTitle(entry),
        subtitle: this.rowDetailSubtitle(entry),
        subtitleMaxLines: this.blockedHelpText(entry).length > 0 ? 3 : 2,
        trailingText: this.formatEntryStatus(entry),
        showChevron: false,
        primaryColor: ThemeConstants.TEXT_PRIMARY,
        secondaryColor: ThemeConstants.TEXT_SECONDARY,
        action: () => {
          this.openDownloadEntry(entry)
        },
      })
      .width('100%')

      Row({ space: ThemeConstants.SPACE_MD }) {
        if (this.canRead(entry)) {
          KomaActionButton({
            label: s('common_read'),
            kind: 'primary',
            isEnabled: this.busyKey.length === 0,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.openDownloadedChapter(entry)
            },
          })
        }
        if (this.canRetry(entry)) {
          KomaActionButton({
            label: this.busyKey === this.rowKey(entry) ? s('common_retrying') : s('common_retry'),
            kind: 'primary',
            isEnabled: this.busyKey.length === 0 && !this.preferences.isPaused,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.retryDownload(entry)
            },
          })
        }
        if (this.canRemove(entry)) {
          KomaActionButton({
            label: s('common_remove'),
            kind: 'ghost',
            isEnabled: this.busyKey.length === 0,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.confirmRemoveDownload(entry)
            },
          })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_LG,
      bottom: ThemeConstants.SPACE_LG,
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          this.QueueControls()
        }
        if (this.entries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          if (this.visibleEntries().length === 0) {
            ListItem() {
              this.EmptyState(this.hasActiveFilter())
            }
          }
          ForEach(this.visibleEntries(), (entry: OfflineDownloadQueueEntry) => {
            ListItem() {
              this.DownloadRow(entry)
            }
          }, (entry: OfflineDownloadQueueEntry) => this.rowKey(entry))
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
