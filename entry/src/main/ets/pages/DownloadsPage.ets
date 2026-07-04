import { common } from '@kit.AbilityKit'
import { Chip, ChipSize } from '@kit.ArkUI'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { Comic } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { OfflineDownloadService } from '../model/OfflineDownloadService'
import {
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

  private blockedHelpText(entry: OfflineDownloadQueueEntry): string {
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'pages_missing') {
      return s('downloads_blocked_pages_missing')
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
      : (summary.downloadingCount > 0 || this.busyKey.length > 0 ? s('downloads_queue_state_running') : s('downloads_queue_state_queued'))
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
      entry.status === OfflineDownloadStatus.PARTIAL
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

  private openDownloadEntry(entry: OfflineDownloadQueueEntry): void {
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.blockUnavailableEntry(entry)
      this.showToast(s('downloads_toast_entry_unavailable'))
      return
    }
    RouterHelper.pushMangaDetail({ mangaId: entry.comicId })
  }

  private retryDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRetry(entry) || this.busyKey.length > 0) {
      return
    }
    if (this.preferences.isPaused) {
      this.showToast(s('downloads_toast_queue_paused'))
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
    if (this.preferences.isPaused) {
      this.showToast(s('downloads_toast_queue_paused'))
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
    if (this.preferences.isPaused) {
      this.showToast(s('downloads_toast_queue_paused'))
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
        if (entry.status === OfflineDownloadStatus.BLOCKED) {
          continue
        }
        if (comic === undefined) {
          this.blockUnavailableEntry(entry)
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

      Row() {
        Row() {
          Chip({
            label: {
              text: s('downloads_filter_chip').replace('%s', this.filterLabel()),
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
              activatedFontColor: ThemeConstants.TEXT_ON_BRAND,
            },
            activated: this.filter !== DownloadQueueFilter.ALL,
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            activatedBackgroundColor: ThemeConstants.BRAND_PRIMARY,
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
          .bindMenu(this.FilterMenu())
        Row() {
          Chip({
            label: {
              text: s('downloads_concurrency_chip').replace('%s', `${this.preferences.foregroundConcurrencyLimit}`),
              fontSize: ThemeConstants.FONT_SIZE_TAG,
              fontColor: ThemeConstants.TEXT_PRIMARY,
            },
            activated: false,
            size: ChipSize.SMALL,
            backgroundColor: $r('sys.color.ohos_id_color_button_normal'),
            borderRadius: ThemeConstants.RADIUS_ROUND,
            allowClose: false,
          })
        }
          .enabled(this.busyKey.length === 0)
          .bindMenu(this.ConcurrencyMenu())
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
  private EmptyState() {
    KomaEmptyState({
      title: s('downloads_empty_title'),
      message: s('downloads_empty_message'),
    })
  }

  @Builder
  private DownloadRow(entry: OfflineDownloadQueueEntry) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.rowTitle(entry))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.rowSubtitle(entry))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.blockedHelpText(entry).length > 0) {
            Text(this.blockedHelpText(entry))
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.formatEntryStatus(entry))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
      .width('100%')
      .onClick(() => {
        this.openDownloadEntry(entry)
      })

      Row({ space: ThemeConstants.SPACE_MD }) {
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
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
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
              this.EmptyState()
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
