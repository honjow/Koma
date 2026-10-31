import { connection } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { OfflineDownloadBatchRequest, resumeAutomaticDownloads } from './OfflineDownloadBatch'
import { OfflineDownloadRuntime } from './OfflineDownloadRuntime'
import { appReaderSessionStore } from './ReaderSessionStore'
import { drainPendingAutomaticChapters } from './LibraryAutomaticDownload'
import { BackupRestoreActivity } from './BackupRestoreActivity'

/** Queue/network events wake one execution owner; an active batch already observes newly queued chapters. */
export class AutomaticDownloadController {
  private request: OfflineDownloadBatchRequest
  private network?: connection.NetConnection
  private unsubscribe?: () => void
  private running?: Promise<void>
  private dirty: boolean = false
  private disposed: boolean = false

  constructor(request: OfflineDownloadBatchRequest) {
    this.request = request
    this.unsubscribe = OfflineDownloadRuntime.subscribe(request.context.filesDir, () => { this.wake() })
    const network = connection.createNetConnection()
    this.network = network
    network.on('netAvailable', () => { this.wake() })
    network.on('netCapabilitiesChange', () => { this.wake() })
    network.register((error: BusinessError): void => {
      if (error !== undefined && error !== null) DiagnosticLogger.exception('downloads', 'network_observer_failed', error)
    })
  }

  wake(): void {
    if (this.disposed || BackupRestoreActivity.isRestoring()) return
    this.dirty = true
    if (this.running !== undefined) return
    this.running = Promise.resolve().then(async (): Promise<void> => {
      while (this.dirty && !this.disposed) {
        this.dirty = false
        await BackupRestoreActivity.runWrite(async (): Promise<void> => {
          await drainPendingAutomaticChapters(this.request.context, this.request.library,
            appReaderSessionStore(this.request.context.filesDir))
          await resumeAutomaticDownloads(this.request)
        })
      }
    }).catch((error: Error): void => { DiagnosticLogger.exception('downloads', 'automatic_batch_failed', error) })
      .finally(() => { this.running = undefined })
  }

  dispose(): void {
    this.disposed = true
    this.unsubscribe?.()
    this.unsubscribe = undefined
    if (this.network !== undefined) {
      this.network.unregister((error: BusinessError): void => {
        if (error !== undefined && error !== null) DiagnosticLogger.exception('downloads', 'network_observer_stop_failed', error)
      })
      this.network = undefined
    }
  }
}
