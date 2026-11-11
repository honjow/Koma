import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common, wantAgent } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { notificationManager } from '@kit.NotificationKit'
import type { Want, WantAgent } from '@kit.AbilityKit'
import {
  KOMA_BUNDLE_NAME,
  KOMA_LAUNCH_ROUTE_DOWNLOADS,
  KOMA_LAUNCH_ROUTE_PARAM,
} from '../common/Constants'
import { AppStrings } from '../i18n/AppStrings'
import { loadDownloadNotificationPreferences } from './DownloadNotificationPreferences'

export type OfflineDownloadNotificationStatus = 'enabled' | 'disabled' | 'unavailable'

// NotificationFlagStatus.TYPE_CLOSE is 2. The NotificationKit namespace does
// not re-export that enum in this SDK, so keep the stable API value named here.
const NOTIFICATION_FLAG_CLOSE: number = 2

export type OfflineDownloadNotificationDispatchCode =
  'delivered' |
    'disabled' |
    'not_needed' |
    'publish_failed'

export interface OfflineDownloadNotificationDispatchResult {
  delivered: boolean
  code: OfflineDownloadNotificationDispatchCode
}

export interface OfflineDownloadNotificationLabels {
  comicTitle?: string
  chapterTitle?: string
}

export function getOfflineDownloadNotificationStatusLabel(status: OfflineDownloadNotificationStatus): string {
  if (status === 'enabled') {
    return AppStrings.get('download_notification_enabled')
  }
  if (status === 'disabled') {
    return AppStrings.get('common_off')
  }
  return AppStrings.get('download_notification_unavailable')
}

export async function getOfflineDownloadNotificationStatus(): Promise<OfflineDownloadNotificationStatus> {
  try {
    return await notificationManager.isNotificationEnabled() ? 'enabled' : 'disabled'
  } catch (error) {
    const businessError = error as BusinessError
    DiagnosticLogger.warn('offline_download_notification_store', 'query_download_notification_status_failed', '[OfflineDownloadNotificationStore] step=query_download_notification_status_failed code=' + businessError.code)
    return 'unavailable'
  }
}

export async function requestOfflineDownloadNotificationPermission(context: common.UIAbilityContext): Promise<OfflineDownloadNotificationStatus> {
  if (await getOfflineDownloadNotificationStatus() === 'enabled') {
    return 'enabled'
  }
  try {
    await notificationManager.requestEnableNotification(context)
  } catch (error) {
    const businessError = error as BusinessError
    DiagnosticLogger.warn('offline_download_notification_store', 'request_download_notification_permission_failed', '[OfflineDownloadNotificationStore] step=request_download_notification_permission_failed code=' + businessError.code)
  }
  return getOfflineDownloadNotificationStatus()
}

export async function cancelOfflineDownloadSummary(): Promise<void> {
  try { await notificationManager.cancel(4101, 'koma.downloads') }
  catch (error) {
    DiagnosticLogger.warn('offline_download_notification_store', 'cancel_download_notification_failed',
      '[OfflineDownloadNotificationStore] step=cancel_download_notification_failed code=' + (error as BusinessError).code)
  }
}

/** After a user has declined the system prompt, the platform requires its settings sheet. */
export async function openOfflineDownloadSystemSettings(context: common.UIAbilityContext): Promise<OfflineDownloadNotificationStatus> {
  try { await notificationManager.openNotificationSettings(context) }
  catch (error) {
    DiagnosticLogger.warn('offline_download_notification_store', 'open_notification_settings_failed',
      '[OfflineDownloadNotificationStore] step=open_notification_settings_failed code=' + (error as BusinessError).code)
  }
  return getOfflineDownloadNotificationStatus()
}

/** One result per drained queue, rather than one interrupting notification per chapter. */
export async function publishOfflineDownloadSummary(context: common.UIAbilityContext,
  completed: number, failed: number): Promise<OfflineDownloadNotificationDispatchResult> {
  if (completed === 0 && failed === 0) return { delivered: false, code: 'not_needed' }
  try {
    const settings = await loadDownloadNotificationPreferences(context)
    if (!settings.enabled || !await notificationManager.isNotificationEnabled()) {
      return { delivered: false, code: 'disabled' }
    }
    const request: notificationManager.NotificationRequest = {
      id: 4101,
      label: 'koma.downloads',
      notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
      // Flags only suppress alerts; channel and system notification settings remain authoritative.
      notificationFlags: {
        soundEnabled: settings.sound === 'silent' || settings.sound === 'vibrate' ? NOTIFICATION_FLAG_CLOSE : 0,
        vibrationEnabled: settings.sound === 'silent' || settings.sound === 'sound' ? NOTIFICATION_FLAG_CLOSE : 0,
      },
      isAlertOnce: false,
      wantAgent: await createOfflineDownloadWantAgent(),
      tapDismissed: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: AppStrings.get(failed > 0 ? 'download_notification_failed_title' : 'download_notification_complete_title'),
          text: AppStrings.format('download_notification_summary', completed, failed),
        },
      },
    }
    // A user can turn notifications off while the queue finishes or WantAgent is prepared.
    if (!(await loadDownloadNotificationPreferences(context)).enabled) return { delivered: false, code: 'disabled' }
    await notificationManager.publish(request)
    return { delivered: true, code: 'delivered' }
  } catch (error) {
    const businessError = error as BusinessError
    DiagnosticLogger.warn('offline_download_notification_store', 'publish_download_notification_failed', '[OfflineDownloadNotificationStore] step=publish_download_notification_failed code=' + businessError.code)
    return { delivered: false, code: 'publish_failed' }
  }
}

export async function createOfflineDownloadWantAgent(): Promise<WantAgent> {
  const parameters: Record<string, Object> = {}
  parameters[KOMA_LAUNCH_ROUTE_PARAM] = KOMA_LAUNCH_ROUTE_DOWNLOADS
  const launchWant: Want = {
    bundleName: KOMA_BUNDLE_NAME,
    abilityName: 'EntryAbility',
    parameters,
  }
  return wantAgent.getWantAgent({
    wants: [launchWant],
    actionType: wantAgent.OperationType.START_ABILITY,
    requestCode: 4101,
    wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
  })
}
