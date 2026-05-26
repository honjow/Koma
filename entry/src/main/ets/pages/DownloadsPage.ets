import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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
  OfflineDownloadQueueStore,
} from '../model/OfflineDownloadQueueStore'
import { installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'

enum DownloadQueueFilter {
  ALL = 'all',
  QUEUED = 'queued',
  DOWNLOADING = 'downloading',
  FAILED = 'failed',
  BLOCKED = 'blocked',
  DOWNLOADED = 'downloaded',
}

@Component
export struct DownloadsPage {
  libraryStore?: LibraryStore
  @State private entries: OfflineDownloadQueueEntry[] = []
  @State private preferences: OfflineDownloadQueuePreferences = {
    foregroundConcurrencyLimit: 1,
    isPaused: false,
  }
  @State private busyKey: string = ''
  @State private filter: DownloadQueueFilter = DownloadQueueFilter.ALL

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private queueStore(): OfflineDownloadQueueStore {
    return new OfflineDownloadQueueStore(this.context().filesDir)
  }

  private loadQueue(): void {
    const store = this.queueStore()
    this.entries = store.load()
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
      return 'queued'
    }
    if (this.filter === DownloadQueueFilter.DOWNLOADING) {
      return 'downloading'
    }
    if (this.filter === DownloadQueueFilter.FAILED) {
      return 'failed'
    }
    if (this.filter === DownloadQueueFilter.BLOCKED) {
      return 'blocked'
    }
    if (this.filter === DownloadQueueFilter.DOWNLOADED) {
      return 'downloaded'
    }
    return 'all'
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
    return `${comicTitle} · ${this.formatEntryStatus(entry)} · ${entry.downloadedPageCount}/${entry.pageCount} 页`
  }

  private blockedHelpText(entry: OfflineDownloadQueueEntry): string {
    if (entry.status === OfflineDownloadStatus.BLOCKED && entry.failureReasonCode === 'pages_missing') {
      return '缺少章节页数据，请打开漫画详情页后重试下载。'
    }
    if (entry.status === OfflineDownloadStatus.BLOCKED) {
      return '该任务暂不可在下载管理中重试。'
    }
    return ''
  }

  private formatStatus(status: OfflineDownloadStatus): string {
    if (status === OfflineDownloadStatus.QUEUED) {
      return 'queued'
    }
    if (status === OfflineDownloadStatus.DOWNLOADING) {
      return 'downloading'
    }
    if (status === OfflineDownloadStatus.DOWNLOADED) {
      return 'downloaded'
    }
    if (status === OfflineDownloadStatus.PARTIAL) {
      return 'partial'
    }
    if (status === OfflineDownloadStatus.FAILED) {
      return 'failed'
    }
    if (status === OfflineDownloadStatus.BLOCKED) {
      return 'blocked'
    }
    return 'failed'
  }

  private formatEntryStatus(entry: OfflineDownloadQueueEntry): string {
    if (entry.failureReasonCode === 'paused') {
      return 'paused'
    }
    if (this.preferences.isPaused && entry.status === OfflineDownloadStatus.QUEUED) {
      return 'paused'
    }
    return this.formatStatus(entry.status)
  }

  private queueStateText(): string {
    const running = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.DOWNLOADING
    }).length
    const queued = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.QUEUED
    }).length
    const failed = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.FAILED || entry.status === OfflineDownloadStatus.PARTIAL
    }).length
    const blocked = this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.BLOCKED
    }).length
    const state = this.preferences.isPaused ? 'paused' : (running > 0 || this.busyKey.length > 0 ? 'running' : 'queued')
    return `${state} · queued ${queued} · failed ${failed} · blocked ${blocked} · concurrency ${this.preferences.foregroundConcurrencyLimit}`
  }

  private queuedEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.QUEUED
    })
  }

  private canRetry(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.FAILED ||
      entry.status === OfflineDownloadStatus.PARTIAL
  }

  private retryableEntries(): OfflineDownloadQueueEntry[] {
    return this.visibleEntries().filter((entry: OfflineDownloadQueueEntry): boolean => this.canRetry(entry))
  }

  private removableCompletedFailedEntries(): OfflineDownloadQueueEntry[] {
    return this.entries.filter((entry: OfflineDownloadQueueEntry): boolean => {
      return entry.status === OfflineDownloadStatus.DOWNLOADED ||
        entry.status === OfflineDownloadStatus.FAILED ||
        entry.status === OfflineDownloadStatus.PARTIAL
    })
  }

  private canRemove(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status !== OfflineDownloadStatus.DOWNLOADING && entry.status !== OfflineDownloadStatus.QUEUED
  }

  private retryDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRetry(entry) || this.busyKey.length > 0) {
      return
    }
    if (this.preferences.isPaused) {
      this.showToast('队列已暂停')
      return
    }
    const comic = this.libraryStore?.getComic(entry.comicId)
    if (comic === undefined) {
      this.showToast('下载条目不可用')
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
      this.showToast('已重新下载')
    } catch (error) {
      void error
      console.warn('[Downloads] step=retry_failed failed=true reason=download_retry')
      this.showToast('重新下载失败')
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
        this.showToast('已移除下载')
      })
      .catch((error: Error) => {
        void error
        console.warn('[Downloads] step=remove_failed failed=true reason=download_remove')
        this.showToast('移除失败')
      })
      .finally(() => {
        this.busyKey = ''
      })
  }

  private retryFailedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    if (this.preferences.isPaused) {
      this.showToast('队列已暂停')
      return
    }
    const targets = this.retryableEntries()
    if (targets.length === 0) {
      this.showToast('没有可重试任务')
      return
    }
    this.busyKey = 'batch-retry'
    void this.runRetryBatch(targets)
  }

  private async runRetryBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const retried = await this.runForegroundDownloadBatch(targets)
      this.loadQueue()
      this.showToast(retried > 0 ? '已重试失败任务' : '没有可重试任务')
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_retry_failed failed=true reason=batch_retry')
      this.showToast('批量重试失败')
    } finally {
      this.busyKey = ''
    }
  }

  private pauseQueuedDownloads(): void {
    this.preferences = this.queueStore().pauseAllQueuedWork()
    this.loadQueue()
    this.showToast('已暂停排队任务')
  }

  private resumeQueuedDownloads(): void {
    if (this.busyKey.length > 0) {
      return
    }
    this.preferences = this.queueStore().resumeAllQueuedWork()
    const targets = this.queuedEntries()
    if (targets.length === 0) {
      this.loadQueue()
      this.showToast('没有排队任务')
      return
    }
    this.busyKey = 'batch-resume'
    void this.runResumeBatch(targets)
  }

  private async runResumeBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const resumed = await this.runForegroundDownloadBatch(targets)
      this.loadQueue()
      this.showToast(resumed > 0 ? '已继续排队任务' : '没有可继续任务')
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_resume_failed failed=true reason=batch_resume')
      this.showToast('继续队列失败')
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

  private async runForegroundDownloadBatch(targets: OfflineDownloadQueueEntry[]): Promise<number> {
    const concurrencyLimit = Math.max(1, Math.min(3, Math.floor(this.preferences.foregroundConcurrencyLimit)))
    let nextIndex = 0
    let completed = 0
    const worker = async (): Promise<void> => {
      while (nextIndex < targets.length && !this.queueStore().loadPreferences().isPaused) {
        const entry = targets[nextIndex]
        nextIndex += 1
        const comic = this.libraryStore?.getComic(entry.comicId)
        if (comic === undefined || entry.status === OfflineDownloadStatus.BLOCKED) {
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
    const targets = this.removableCompletedFailedEntries()
    if (targets.length === 0) {
      this.showToast('没有可清理任务')
      return
    }
    this.busyKey = 'batch-remove'
    void this.runRemoveBatch(targets)
  }

  private async runRemoveBatch(targets: OfflineDownloadQueueEntry[]): Promise<void> {
    try {
      const store = this.queueStore()
      for (let index = 0; index < targets.length; index += 1) {
        const entry = targets[index]
        if (entry.status === OfflineDownloadStatus.DOWNLOADED ||
          entry.status === OfflineDownloadStatus.FAILED ||
          entry.status === OfflineDownloadStatus.PARTIAL) {
          await store.deleteChapterDownload(entry.comicId, entry.chapterId)
        }
      }
      this.loadQueue()
      this.showToast('已清理完成和失败任务')
    } catch (error) {
      void error
      console.warn('[Downloads] step=batch_remove_failed failed=true reason=batch_remove')
      this.showToast('批量清理失败')
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
      MenuItem({ content: '全部' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.ALL)
        })
      MenuItem({ content: 'queued' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.QUEUED)
        })
      MenuItem({ content: 'downloading' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADING)
        })
      MenuItem({ content: 'failed' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.FAILED)
        })
      MenuItem({ content: 'blocked' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.BLOCKED)
        })
      MenuItem({ content: 'downloaded' })
        .onClick(() => {
          this.setFilter(DownloadQueueFilter.DOWNLOADED)
        })
    }
  }

  @Builder
  private QueueControls() {
    Column({ space: 8 }) {
      Text(this.queueStateText())
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.koma_text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Button(`状态 ${this.filterLabel()} ▾`)
          .height(34)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor(this.filter !== DownloadQueueFilter.ALL ? Color.White : $r('app.color.koma_text_primary'))
          .backgroundColor(this.filter !== DownloadQueueFilter.ALL ? $r('app.color.koma_accent') : $r('app.color.koma_card'))
          .bindMenu(this.FilterMenu())
        Button(`并发 ${this.preferences.foregroundConcurrencyLimit} ▾`)
          .height(34)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_primary'))
          .backgroundColor($r('app.color.koma_card'))
          .enabled(this.busyKey.length === 0)
          .bindMenu(this.ConcurrencyMenu())
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      Row({ space: 8 }) {
        Button(this.preferences.isPaused ? (this.busyKey === 'batch-resume' ? '继续中' : '继续队列') : '暂停队列')
          .height(34)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor(this.preferences.isPaused ? Color.White : $r('app.color.koma_text_secondary'))
          .backgroundColor(this.preferences.isPaused ? $r('app.color.koma_accent') : '#00000000')
          .enabled(!this.preferences.isPaused || this.busyKey.length === 0)
          .onClick(() => {
            if (this.preferences.isPaused) {
              this.resumeQueuedDownloads()
            } else {
              this.pauseQueuedDownloads()
            }
          })
        Button(this.busyKey === 'batch-retry' ? '重试中' : '重试失败')
          .height(34)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor($r('app.color.koma_accent'))
          .backgroundColor('#00000000')
          .enabled(this.busyKey.length === 0 && !this.preferences.isPaused)
          .onClick(() => {
            this.retryFailedDownloads()
          })
        Button(this.busyKey === 'batch-remove' ? '清理中' : '清理完成/失败')
          .height(34)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
          .backgroundColor('#00000000')
          .enabled(this.busyKey.length === 0)
          .onClick(() => {
            this.removeCompletedFailedDownloads()
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private EmptyState() {
    Column({ space: 8 }) {
      Text('暂无下载任务')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('从漫画详情页选择章节下载后会显示在这里。')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 28, bottom: 28 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private DownloadRow(entry: OfflineDownloadQueueEntry) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.rowTitle(entry))
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.rowSubtitle(entry))
            .width('100%')
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.blockedHelpText(entry).length > 0) {
            Text(this.blockedHelpText(entry))
              .width('100%')
              .fontSize(12)
              .fontColor($r('app.color.koma_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.formatEntryStatus(entry))
          .fontSize(12)
          .fontColor($r('app.color.koma_accent'))
      }
      .width('100%')

      Row({ space: 10 }) {
        if (this.canRetry(entry)) {
          Button(this.busyKey === this.rowKey(entry) ? '重试中' : '重试')
            .height(32)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.koma_accent'))
            .enabled(this.busyKey.length === 0 && !this.preferences.isPaused)
            .onClick(() => {
              this.retryDownload(entry)
            })
        }
        if (this.canRemove(entry)) {
          Button('移除')
            .height(32)
            .padding({ left: 12, right: 12 })
            .borderRadius(8)
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
            .backgroundColor('#00000000')
            .enabled(this.busyKey.length === 0)
            .onClick(() => {
              this.removeDownload(entry)
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        if (this.entries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          ListItem() {
            this.QueueControls()
          }
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
