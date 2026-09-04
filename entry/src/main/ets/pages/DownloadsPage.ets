import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaMenuChip } from '../components/ui/KomaMenuChip'
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

@Concurrent
function reconcileOfflineDownloadQueueTask(filesDir: string): OfflineDownloadQueueEntry[] {
  return new OfflineDownloadQueueStore(filesDir).reconcileWithManifests()
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
  @Local private actionMenuKey: string = ''
  private deferredReconcileTimer: number = 0
  private reconcileRequestId: number = 0
  @Event onOpenReader: (comicId: string, chapterId?: string) => void =
    (_comicId: string, _chapterId?: string) => {}
  @Event onLibraryChanged: () => void = () => {}

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private queueStore(): OfflineDownloadQueueStore {
    return new OfflineDownloadQueueStore(this.context().filesDir)
  }

  private clearDeferredReconcileTimer(): void {
    if (this.deferredReconcileTimer !== 0) {
      clearTimeout(this.deferredReconcileTimer)
      this.deferredReconcileTimer = 0
    }
    this.reconcileRequestId += 1
  }

  private scheduleDeferredReconcile(): void {
    this.clearDeferredReconcileTimer()
    const requestId = this.reconcileRequestId
    this.deferredReconcileTimer = setTimeout(() => {
      this.deferredReconcileTimer = 0
      void this.runDeferredReconcile(requestId)
    }, 0)
  }

  private async runDeferredReconcile(requestId: number): Promise<void> {
    const filesDir = this.context().filesDir
    try {
      const task: taskpool.Task = new taskpool.Task(reconcileOfflineDownloadQueueTask, filesDir)
      const entries = await taskpool.execute(task) as OfflineDownloadQueueEntry[]
      if (requestId !== this.reconcileRequestId) {
        return
      }
      this.entries = entries
    } catch (error) {
      const e = error as Error
      console.warn('[Downloads] step=deferred_reconcile_failed code=' + e.message)
    }
  }

  private loadQueue(reconcileManifests: boolean = true): void {
    this.clearDeferredReconcileTimer()
    const store = this.queueStore()
    this.entries = reconcileManifests ? store.reconcileWithManifests() : store.load()
    this.preferences = store.loadPreferences()
  }

  private rowKey(entry: OfflineDownloadQueueEntry): string {
    return `${entry.comicId}::${entry.chapterId}`
  }

  private visibleEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => this.matchesFilter(entry, this.filter))
  }

  private matchesFilter(entry: OfflineDownloadQueueEntry, filter: DownloadQueueFilter): boolean {
    if (filter === DownloadQueueFilter.ALL) {
      return true
    }
    if (filter === DownloadQueueFilter.FAILED) {
      return entry.status === OfflineDownloadStatus.FAILED || entry.status === OfflineDownloadStatus.PARTIAL
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
    return entry.status === OfflineDownloadStatus.QUEUED
  }

  private shouldShowFilter(filter: DownloadQueueFilter): boolean {
    return filter === DownloadQueueFilter.ALL || filter === this.filter ||
      this.entries.some((entry: OfflineDownloadQueueEntry): boolean => this.matchesFilter(entry, filter))
  }

  private visibleGroups(): DownloadComicGroup[] {
    const groups: DownloadComicGroup[] = []
    this.visibleEntries().forEach((entry: OfflineDownloadQueueEntry): void => {
      const existing = groups.find((group: DownloadComicGroup): boolean => group.comicId === entry.comicId)
      if (existing !== undefined) {
        existing.entries.push(entry)
        return
      }
      groups.push({
        comicId: entry.comicId,
        title: entry.comicTitle !== undefined && entry.comicTitle.trim().length > 0
          ? entry.comicTitle
          : (this.libraryStore?.getComic(entry.comicId)?.title ?? entry.comicId),
        entries: [entry],
      })
    })
    return groups
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

  private queueOverviewTitle(): string {
    const summary: OfflineDownloadQueueSummary = summarizeOfflineDownloadQueue(this.entries)
    return s('downloads_overview_summary')
      .replace('%s', `${summary.totalCount}`)
      .replace('%s', `${summary.downloadedPageCount}`)
      .replace('%s', `${summary.pageCount}`)
  }

  private queueOverviewSubtitle(): string {
    const summary: OfflineDownloadQueueSummary = summarizeOfflineDownloadQueue(this.entries)
    const attentionCount = summary.failedCount + summary.partialCount + summary.blockedCount
    if (this.preferences.isPaused && summary.queuedCount > 0) {
      return s('downloads_overview_paused').replace('%s', `${summary.queuedCount}`)
    }
    if (summary.queuedCount > 0 && !canRunOfflineDownloadQueueNow(this.preferences)) {
      return s('downloads_status_waiting_wifi')
    }
    if (summary.downloadingCount > 0 || this.busyKey.startsWith('batch-')) {
      return s('downloads_overview_downloading').replace('%s', `${Math.max(1, summary.downloadingCount)}`)
    }
    if (attentionCount > 0) {
      return s('downloads_overview_attention').replace('%s', `${attentionCount}`)
    }
    if (summary.queuedCount > 0) {
      return s('downloads_overview_queued').replace('%s', `${summary.queuedCount}`)
    }
    return s('downloads_overview_ready')
  }

  private groupSubtitle(group: DownloadComicGroup): string {
    let downloadedPages = 0
    let pageCount = 0
    group.entries.forEach((entry: OfflineDownloadQueueEntry): void => {
      downloadedPages += entry.downloadedPageCount
      pageCount += entry.pageCount
    })
    return s('downloads_group_summary')
      .replace('%s', `${group.entries.length}`)
      .replace('%s', `${downloadedPages}`)
      .replace('%s', `${pageCount}`)
  }

  private shouldShowPrimaryQueueAction(): boolean {
    const summary = summarizeOfflineDownloadQueue(this.entries)
    return this.preferences.isPaused || summary.queuedCount > 0 || summary.downloadingCount > 0 ||
      this.busyKey.startsWith('batch-')
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

  private entryStatusIcon(entry: OfflineDownloadQueueEntry): Resource {
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
    this.openDownloadEntry(entry)
  }

  private rowMenuKey(entry: OfflineDownloadQueueEntry): string {
    return `row:${this.rowKey(entry)}`
  }

  private closeActionMenu(): void {
    this.actionMenuKey = ''
  }

  @Builder
  private QueueMoreMenu() {
    Menu() {
      MenuItem({ content: s('downloads_action_retry_failed') })
        .enabled(this.busyKey.length === 0 && !this.preferences.isPaused)
        .onClick(() => {
          this.retryFailedDownloads()
        })
      MenuItem({ content: s('downloads_action_cleanup_finished_failed') })
        .enabled(this.busyKey.length === 0)
        .onClick(() => {
          this.confirmRemoveCompletedFailedDownloads()
        })
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
    // Render the parsed queue snapshot on the first frame; per-entry manifest
    // reconciliation runs off the UI thread so entry no longer blocks for seconds.
    this.entries = this.queueStore().load()
    this.preferences = this.queueStore().loadPreferences()
    this.scheduleDeferredReconcile()
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
          Text(this.queueOverviewTitle())
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.queueOverviewSubtitle())
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
              isEnabled: !this.preferences.isPaused || this.busyKey.length === 0,
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
            .bindMenu(this.actionMenuKey === 'queue', this.QueueMoreMenu(), {
              placement: Placement.BottomRight,
              onDisappear: () => {
                if (this.actionMenuKey === 'queue') {
                  this.closeActionMenu()
                }
              },
            })
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
          .bindMenu(this.actionMenuKey === 'filter', this.FilterMenu(), {
            placement: Placement.BottomLeft,
            onDisappear: () => {
              if (this.actionMenuKey === 'filter') {
                this.closeActionMenu()
              }
            },
          })
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
  private DownloadRowMenu(entry: OfflineDownloadQueueEntry) {
    Menu() {
      MenuItem({ content: s('downloads_action_open_manga') })
        .onClick(() => {
          this.openDownloadEntry(entry)
        })
      if (this.canRetry(entry)) {
        MenuItem({ content: this.busyKey === this.rowKey(entry) ? s('common_retrying') : s('common_retry') })
          .enabled(this.busyKey.length === 0 && !this.preferences.isPaused)
          .onClick(() => {
            this.retryDownload(entry)
          })
      }
      if (this.canRemove(entry)) {
        MenuItem({ content: s('downloads_action_delete_files') })
          .enabled(this.busyKey.length === 0)
          .onClick(() => {
            this.confirmRemoveDownload(entry)
          })
      }
    }
  }

  @Builder
  private DownloadCover(group: DownloadComicGroup) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(ThemeConstants.FONT_SIZE_H2)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
      if ((this.libraryStore?.getComic(group.comicId)?.coverUri ?? '').length > 0) {
        CachedCoverImage({
          uri: this.libraryStore?.getComic(group.comicId)?.coverUri ?? '',
          objectFit: ImageFit.Cover,
          sourceRuntimeId: this.libraryStore?.getComic(group.comicId)?.sourceRuntimeId ?? '',
          sourceImageId: this.libraryStore?.getComic(group.comicId)?.remoteResourceId ?? group.comicId,
          sourceKind: this.libraryStore?.getComic(group.comicId)?.sourceKind,
          remoteServerId: this.libraryStore?.getComic(group.comicId)?.remoteServerId ?? '',
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
  private DownloadStatusIcon(entry: OfflineDownloadQueueEntry) {
    SymbolGlyph(this.entryStatusIcon(entry))
      .fontSize(ThemeConstants.FONT_SIZE_H3)
      .fontColor([this.entryStatusColor(entry)])
  }

  @Builder
  private DownloadChapterRow(entry: OfflineDownloadQueueEntry) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        this.DownloadStatusIcon(entry)

        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.rowTitle(entry))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.rowDetailSubtitle(entry))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(this.entryStatusColor(entry))
            .maxLines(this.blockedHelpText(entry).length > 0 ? 2 : 1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.shouldShowEntryProgress(entry)) {
            Progress({ value: this.entryProgressValue(entry), total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(3)
              .color(this.entryStatusColor(entry))
              .backgroundColor(ThemeConstants.SOFT_TINT)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openDownloadRow(entry)
      })

      KomaIconButton({
        icon: $r('sys.symbol.ellipsis_circle'),
        kind: 'ghost',
        controlSize: ThemeConstants.TOUCH_TARGET_SM,
        iconSize: ThemeConstants.FONT_SIZE_H3,
        accentColor: ThemeConstants.TEXT_SECONDARY,
        action: () => {
          this.actionMenuKey = this.rowMenuKey(entry)
        },
      })
        .bindMenu(this.actionMenuKey === this.rowMenuKey(entry), this.DownloadRowMenu(entry), {
          placement: Placement.BottomRight,
          onDisappear: () => {
            if (this.actionMenuKey === this.rowMenuKey(entry)) {
              this.closeActionMenu()
            }
          },
        })
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

  @Builder
  private DownloadGroup(group: DownloadComicGroup) {
    Column() {
      Row({ space: ThemeConstants.SPACE_MD }) {
        this.DownloadCover(group)
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
        if (group.entries.length > 0) {
          this.openDownloadEntry(group.entries[0])
        }
      })

      Divider()
        .strokeWidth(0.5)
        .color(ThemeConstants.DIVIDER)
        .margin({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })

      ForEach(group.entries, (entry: OfflineDownloadQueueEntry) => {
        this.DownloadChapterRow(entry)
      }, (entry: OfflineDownloadQueueEntry) => this.rowKey(entry))
    }
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .clip(true)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.entries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          ListItem() {
            this.QueueHeader()
          }
          if (this.visibleEntries().length === 0) {
            ListItem() {
              this.EmptyState(this.hasActiveFilter())
            }
          }
          ForEach(this.visibleGroups(), (group: DownloadComicGroup) => {
            ListItem() {
              this.DownloadGroup(group)
            }
          }, (group: DownloadComicGroup) => group.comicId)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
