import { common } from '@kit.AbilityKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AppStrings } from '../i18n/AppStrings'
import { createOfflineDownloadWantAgent } from './OfflineDownloadNotificationStore'
import { OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'

/** One data-transfer task owns all native download callers and their shared concurrency slots. */
export class BackgroundDownloadOwner {
  private static count: number = 0
  private static mutation: Promise<void> = Promise.resolve()
  private static notification?: backgroundTaskManager.ContinuousTaskNotification
  private static write: Promise<void> = Promise.resolve()
  private static lastProgressAt: number = 0
  private static cancel?: (info: backgroundTaskManager.ContinuousTaskCancelInfo) => void

  private static change(operation: () => Promise<void>): Promise<void> {
    const next = BackgroundDownloadOwner.mutation.then(operation)
    BackgroundDownloadOwner.mutation = next.catch(() => {})
    return next
  }

  static async run<T>(context: common.UIAbilityContext | undefined, operation: () => Promise<T>): Promise<T> {
    if (context === undefined) return operation()
    await BackgroundDownloadOwner.change(async (): Promise<void> => {
      BackgroundDownloadOwner.count += 1
      if (BackgroundDownloadOwner.count !== 1) return
      try {
        BackgroundDownloadOwner.notification = await backgroundTaskManager.startBackgroundRunning(
          context, ['dataTransfer'], await createOfflineDownloadWantAgent())
        const cancel = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
          const task = BackgroundDownloadOwner.notification
          if (task === undefined || (task.continuousTaskId !== undefined && info.id !== task.continuousTaskId)) return
          BackgroundDownloadOwner.notification = undefined
          try { new OfflineDownloadQueueStore(context.filesDir).pauseAllQueuedWork() }
          catch (error) { DiagnosticLogger.exception('downloads', 'background_cancel_pause_failed', error as Error) }
        }
        BackgroundDownloadOwner.cancel = cancel
        backgroundTaskManager.on('continuousTaskCancel', cancel)
      } catch (error) {
        DiagnosticLogger.exception('downloads', 'background_task_start_failed', error as Error)
      }
    })
    try { return await operation() }
    finally {
      await BackgroundDownloadOwner.change(async (): Promise<void> => {
        BackgroundDownloadOwner.count -= 1
        if (BackgroundDownloadOwner.count !== 0) return
        const notification = BackgroundDownloadOwner.notification
        // A final page may still be publishing progress. Keep its notification alive until that
        // update settles, then end the transfer task; otherwise publish races a deleted live view.
        await BackgroundDownloadOwner.write
        BackgroundDownloadOwner.notification = undefined
        if (BackgroundDownloadOwner.cancel !== undefined) {
          try { backgroundTaskManager.off('continuousTaskCancel', BackgroundDownloadOwner.cancel) }
          catch (error) { DiagnosticLogger.exception('downloads', 'background_cancel_unsubscribe_failed', error as Error) }
          BackgroundDownloadOwner.cancel = undefined
        }
        if (notification !== undefined) {
          try { await backgroundTaskManager.stopBackgroundRunning(context) }
          catch (error) { DiagnosticLogger.exception('downloads', 'background_task_stop_failed', error as Error) }
        }
      })
    }
  }

  static progress(title: string, completed: number, total: number): void {
    const task = BackgroundDownloadOwner.notification
    if (task === undefined || total <= 0) return
    if (Date.now() - BackgroundDownloadOwner.lastProgressAt < 500 && completed < total) return
    BackgroundDownloadOwner.lastProgressAt = Date.now()
    const request: notificationManager.NotificationRequest = {
      id: task.notificationId,
      notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
      content: { notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
        systemLiveView: { typeCode: 8, title: AppStrings.get('downloads_title'), text: title } },
      template: { name: 'downloadTemplate', data: { title, fileName: title,
        progressValue: Math.floor(completed * 100 / total) } },
    }
    BackgroundDownloadOwner.write = BackgroundDownloadOwner.write.then(async (): Promise<void> => {
      if (BackgroundDownloadOwner.notification !== task) return
      await notificationManager.publish(request)
    }).catch((error: Error): void => { DiagnosticLogger.exception('downloads', 'background_progress_failed', error) })
  }
}
