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
  OfflineDownloadQueueEntry,
  OfflineDownloadQueueStore,
} from '../model/OfflineDownloadQueueStore'
import { installReaderRemoteHeadersForComic } from '../model/ReaderPageSourceAdapter'

@Component
export struct DownloadsPage {
  libraryStore?: LibraryStore
  @State private entries: OfflineDownloadQueueEntry[] = []
  @State private busyKey: string = ''

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private queueStore(): OfflineDownloadQueueStore {
    return new OfflineDownloadQueueStore(this.context().filesDir)
  }

  private loadQueue(): void {
    this.entries = this.queueStore().load()
  }

  private rowKey(entry: OfflineDownloadQueueEntry): string {
    return `${entry.comicId}::${entry.chapterId}`
  }

  private rowTitle(entry: OfflineDownloadQueueEntry): string {
    if (entry.chapterTitle !== undefined && entry.chapterTitle.length > 0) {
      return entry.chapterTitle
    }
    return entry.chapterId
  }

  private rowSubtitle(entry: OfflineDownloadQueueEntry): string {
    const comicTitle = entry.comicTitle !== undefined && entry.comicTitle.length > 0 ? entry.comicTitle : entry.comicId
    return `${comicTitle} · ${this.formatStatus(entry.status)} · ${entry.downloadedPageCount}/${entry.pageCount} 页`
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

  private canRetry(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status === OfflineDownloadStatus.FAILED ||
      entry.status === OfflineDownloadStatus.PARTIAL
  }

  private canRemove(entry: OfflineDownloadQueueEntry): boolean {
    return entry.status !== OfflineDownloadStatus.DOWNLOADING && entry.status !== OfflineDownloadStatus.QUEUED
  }

  private retryDownload(entry: OfflineDownloadQueueEntry): void {
    if (!this.canRetry(entry) || this.busyKey.length > 0) {
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
      const e = error as Error
      console.warn('[Downloads] step=retry_failed message=' + e.message)
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
        console.warn('[Downloads] step=remove_failed message=' + error.message)
        this.showToast('移除失败')
      })
      .finally(() => {
        this.busyKey = ''
      })
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  aboutToAppear(): void {
    this.loadQueue()
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

        Text(this.formatStatus(entry.status))
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
            .enabled(this.busyKey.length === 0)
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
          ForEach(this.entries, (entry: OfflineDownloadQueueEntry) => {
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
