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
import {
  OfflineChapterDownloadManifest,
  OfflineDownloadStatus,
} from './OfflineDownloadStore'

export type OfflineDownloadNotificationStatus = 'enabled' | 'unavailable'

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

function firstNonEmpty(left: string | undefined, right: string): string {
  if (left !== undefined && left.trim().length > 0) {
    return left.trim()
  }
  return right
}

export function getOfflineDownloadNotificationStatusLabel(status: OfflineDownloadNotificationStatus): string {
  return status === 'enabled'
    ? AppStrings.get('download_notification_enabled')
    : AppStrings.get('download_notification_unavailable')
}

export async function getOfflineDownloadNotificationStatus(): Promise<OfflineDownloadNotificationStatus> {
  try {
    return await notificationManager.isNotificationEnabled() ? 'enabled' : 'unavailable'
  } catch (error) {
    const businessError = error as BusinessError
    console.warn('[OfflineDownloadNotificationStore] step=query_download_notification_status_failed code=' + businessError.code)
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
    console.warn('[OfflineDownloadNotificationStore] step=request_download_notification_permission_failed code=' + businessError.code)
  }
  return getOfflineDownloadNotificationStatus()
}

export async function publishOfflineDownloadNotification(
  manifest: OfflineChapterDownloadManifest,
  labels?: OfflineDownloadNotificationLabels,
): Promise<OfflineDownloadNotificationDispatchResult> {
  if (manifest.status === OfflineDownloadStatus.DOWNLOADED) {
    return publishOfflineDownloadNotificationText(
      AppStrings.get('download_notification_complete_title'),
      AppStrings.format(
        'download_notification_complete_text',
        firstNonEmpty(labels?.chapterTitle, manifest.chapterId),
        firstNonEmpty(labels?.comicTitle, manifest.comicId),
        manifest.downloadedPageCount,
        manifest.pageCount,
      ),
      manifest.updatedAt,
    )
  }
  if (manifest.status === OfflineDownloadStatus.FAILED ||
    manifest.status === OfflineDownloadStatus.PARTIAL ||
    manifest.status === OfflineDownloadStatus.BLOCKED) {
    return publishOfflineDownloadNotificationText(
      AppStrings.get('download_notification_failed_title'),
      AppStrings.format(
        'download_notification_failed_text',
        firstNonEmpty(labels?.chapterTitle, manifest.chapterId),
        firstNonEmpty(labels?.comicTitle, manifest.comicId),
        manifest.failureReasonCode ?? manifest.status,
      ),
      manifest.updatedAt,
    )
  }
  return { delivered: false, code: 'not_needed' }
}

async function publishOfflineDownloadNotificationText(
  title: string,
  text: string,
  updatedAt: number,
): Promise<OfflineDownloadNotificationDispatchResult> {
  try {
    const enabled = await notificationManager.isNotificationEnabled()
    if (!enabled) {
      return { delivered: false, code: 'disabled' }
    }
    const request: notificationManager.NotificationRequest = {
      id: 4101,
      label: 'koma.downloads',
      appMessageId: `koma.download.${updatedAt}`,
      notificationSlotType: notificationManager.SlotType.CONTENT_INFORMATION,
      wantAgent: await createOfflineDownloadWantAgent(),
      tapDismissed: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title,
          text,
        },
      },
    }
    await notificationManager.publish(request)
    return { delivered: true, code: 'delivered' }
  } catch (error) {
    const businessError = error as BusinessError
    console.warn('[OfflineDownloadNotificationStore] step=publish_download_notification_failed code=' + businessError.code)
    return { delivered: false, code: 'publish_failed' }
  }
}

async function createOfflineDownloadWantAgent(): Promise<WantAgent> {
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
