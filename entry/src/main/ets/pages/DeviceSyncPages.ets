import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { ThemeConstants } from '../theme/ThemeConstants'
import { komaDialogMaterial, komaToastOptions } from '../theme/KomaPopupOptions'
import { FormTitleActionState } from '../state/FormTitleActionState'
import { ReadingDirection } from '../model/ComicModels'
import { readerControlDirection, readerControlDirectionLabelKey } from '../model/ReaderControlChoices'
import { ReaderPageMode } from '../model/ReaderPreferencesStore'
import { appDeviceSync, DeviceSyncViewState } from '../deviceSync/DeviceSyncRuntime'
import { appHuaweiCloudSync, HuaweiCloudSyncView } from '../deviceSync/HuaweiCloudSync'
import { SyncGroup, SYNC_GROUPS } from '../deviceSync/DeviceSyncFacts'
import { SyncMergeChoice, SyncMergeConflict, SyncPreview, SyncPreviewGroup, SyncPreviewRemoval } from '../deviceSync/DeviceSyncEngine'
import { SyncConnectionDraft } from '../deviceSync/DeviceSyncWebDav'
import { SyncBlockedReading, SyncLocalValue } from '../deviceSync/DeviceSyncStorage'
import { SyncShelfRemoval } from '../deviceSync/DeviceSyncOwners'
import { syncKeyParts, SyncPositionValue, SyncReaderMode, SyncRecentValue, SyncSubscription, SyncWorkLabel } from '../deviceSync/DeviceSyncData'

function t(key: string): string {
  return AppStrings.get(key)
}

function groupKey(group: SyncGroup): string {
  return 'device_sync_group_' + group.replace(/-/g, '_')
}

function errorText(code: string): string {
  if (code === '') return ''
  // The engine keeps successful groups and retries failed groups independently.
  // Show the cause of the failure rather than asking the user to repeat the round.
  if (code.startsWith('sync_partial:')) {
    const cause = code.substring('sync_partial:'.length)
    return cause === '' ? t('device_sync_error_unknown') : errorText(cause)
  }
  if (code === 'sync_probe_cleanup_pending') return t('device_sync_error_cleanup_pending')
  if (code.startsWith('sync_probe_cleanup_')) {
    return t('device_sync_error_cleanup').replace('%s', errorText(code.substring('sync_probe_cleanup_'.length)))
  }
  if (code === 'sync_authentication_failed') return t('device_sync_error_auth')
  if (code === 'sync_permission_denied') return t('device_sync_error_permission')
  if (code === 'sync_directory_missing') return t('device_sync_error_directory_missing')
  if (code === 'sync_directory_parent_missing') return t('device_sync_error_parent_missing')
  if (code === 'sync_path_not_directory') return t('device_sync_error_not_directory')
  if (code === 'sync_not_webdav_directory' || code === 'sync_webdav_method_unsupported') return t('device_sync_error_not_webdav')
  if (code === 'sync_https_directory_required' || code === 'sync_invalid_directory') return t('device_sync_error_https')
  if (code === 'sync_directory_redirected') return t('device_sync_error_redirect')
  if (code === 'sync_tls_failed') return t('device_sync_error_tls')
  if (code === 'sync_network_failed' || code === 'sync_server_unavailable') return t('device_sync_error_network')
  if (code === 'sync_host_unresolved') return t('device_sync_error_dns')
  if (code === 'sync_network_timeout') return t('device_sync_error_timeout')
  if (code === 'sync_remote_locked') return t('device_sync_error_locked')
  if (code === 'sync_server_busy') return t('device_sync_error_busy')
  if (code === 'sync_request_too_large') return t('device_sync_error_request_size')
  if (code === 'sync_manifest_too_large' || code === 'sync_round_too_large' || code === 'sync_record_too_large') return t('device_sync_error_capacity')
  if (code === 'sync_response_invalid') return t('device_sync_error_response')
  if (code.startsWith('sync_server_http_')) return t('device_sync_error_http').replace('%s', code.substring('sync_server_http_'.length))
  if (code === 'sync_protocol_review_required') return t('device_sync_protocol_review')
  if (code === 'sync_service_disabled') return t('device_sync_paused_detail')
  if (code === 'sync_server_storage_full') return t('device_sync_error_storage')
  if (code === 'sync_update_required') return t('device_sync_error_upgrade')
  if (code === 'sync_preview_changed' || code === 'sync_remote_changed' || code === 'sync_review_required' ||
    code === 'sync_local_changed' || code === 'sync_remote_committed_locally_changed') return t('device_sync_error_review')
  if (code === 'sync_space_changed') return t('device_sync_error_space')
  if (code === 'sync_legacy_unavailable') return t('device_sync_legacy_unavailable')
  if (code === 'sync_remote_result_unknown') return t('device_sync_error_unknown_result')
  if (code === 'sync_catalog_limit') return t('device_sync_error_catalog_limit')
  if (code === 'sync_catalog_unavailable') return t('device_sync_error_catalog_unavailable')
  if (code === 'sync_public_work_unavailable') return t('device_sync_error_public_work')
  if (code === 'sync_reading_proof_pending') return t('device_sync_error_reading_proof_pending')
  if (code === 'sync_reading_local_change_pending') return t('device_sync_error_reading_local_change_pending')
  if (code === 'sync_maintenance_running') return t('device_sync_error_maintenance')
  if (code === 'sync_invalid_username' || code === 'sync_credentials_too_long') return t('device_sync_error_credentials')
  if (code === 'sync_select_contents') return t('device_sync_no_selection')
  if (code === 'sync_local_busy') return t('device_sync_error_local_busy')
  if (code === 'sync_local_reading_save_failed') return t('device_sync_error_reading_save')
  if (code === 'sync_local_rollback_pending') return t('device_sync_error_local_rollback')
  if (code === 'sync_local_recovery_required') return t('device_sync_error_local_recovery')
  if (code === 'sync_local_state_invalid' || code === 'sync_local_journal_invalid') return t('device_sync_error_local_state')
  if (code === 'sync_credential_missing' || code === 'sync_credential_read_failed') return t('device_sync_error_credential_read')
  if (code.startsWith('sync_local_') || code.startsWith('sync_credential_')) return t('device_sync_error_local')
  if (code === 'sync_shard_missing' || code === 'sync_pack_not_found' ||
    code === 'sync_legacy_archive_unavailable') return t('device_sync_error_file_missing') + '\n' + t('device_sync_error_report')
  if (code === 'sync_pack_incomplete' || code === 'sync_legacy_archive_incomplete') {
    return t('device_sync_error_file_incomplete') + '\n' + t('device_sync_error_report')
  }
  if (code.startsWith('sync_invalid_') || code === 'sync_pack_invalid' ||
    code === 'sync_legacy_archive_invalid') return t('device_sync_error_file_invalid') + '\n' + t('device_sync_error_report')
  if (code.startsWith('sync_shard_') || code === 'sync_pack_damaged' ||
    code === 'sync_legacy_archive_damaged') return t('device_sync_error_damaged') + '\n' + t('device_sync_error_report')
  return t('device_sync_error_unknown')
}

function stateText(state: DeviceSyncViewState): string {
  if (state.manualInProgress || state.transferInFlight || state.unresolvedCommit && state.busy) return t('device_sync_running')
  if (state.error !== '') return t('device_sync_failed')
  if (!state.ready) return t('device_sync_loading')
  if (!state.configured) return t('device_sync_unconfigured')
  if (state.unresolvedCommit) return t('device_sync_previous_interrupted')
  if (state.awaitingFirstMerge && !state.enabled) return t('device_sync_saved_pending')
  if (!state.enabled) return t('device_sync_paused')
  if (state.selected.length === 0) return t('device_sync_no_selection')
  if (state.requiresExplicitReview) return t('device_sync_review_required')
  if (!state.connected) return t('device_sync_waiting_first_run')
  if (!state.automatic) return t('device_sync_manual')
  return t('device_sync_connected')
}

function conflictValue(key: string, value: string): string {
  if (value === '') return t('device_sync_deleted')
  const parts = syncKeyParts(key)
  const kind = parts[0]
  if (kind === 'recent') {
    const recent = JSON.parse(value) as SyncRecentValue
    return [recent.title, recent.chapterTitle || recent.chapter].join(' · ')
  }
  if (kind === 'position') {
    const position = JSON.parse(value) as SyncPositionValue
    return (position.page + 1).toString() + ' / ' + position.total.toString()
  }
  if (kind === 'book') return (JSON.parse(value) as SyncWorkLabel).title ?? t('device_sync_deleted')
  if (kind === 'catalog') return (JSON.parse(value) as SyncSubscription).label || t('device_sync_group_source_subscriptions')
  if (kind === 'book-mode' || (kind === 'global' && parts[1] === 'mode')) {
    const mode = JSON.parse(value) as SyncReaderMode
    const direction = readerControlDirection({ pageMode: mode.mode as ReaderPageMode, readingDirection: mode.direction as ReadingDirection })
    const directionText = t(readerControlDirectionLabelKey(direction))
    if (direction === 'vertical_page' || direction === 'continuous') return directionText
    return t(mode.mode === 'double_page' ? 'reader_page_mode_double' : 'reader_page_mode_single') + ' · ' + directionText
  }
  if (kind === 'global' && parts[1] === 'image-fit') {
    const fit = JSON.parse(value) as string
    return t(fit === 'fit_width' ? 'reader_image_fit_width' : fit === 'fit_height' ? 'reader_image_fit_height' : 'reader_image_fit_screen')
  }
  if (value === 'true') return t('device_sync_value_on')
  if (value === 'false') return t('device_sync_value_off')
  const parsed = JSON.parse(value) as Object
  return typeof parsed === 'string' ? parsed : t('device_sync_changed_value')
}

function conflictTitle(conflict: SyncMergeConflict): string {
  const parts = syncKeyParts(conflict.key)
  if (conflict.label !== undefined && parts[0] !== 'book-mode') return conflict.label
  if (parts[0] === 'global') {
    if (parts[1] === 'animation') return t('reader_page_turn_animation_title')
    if (parts[1] === 'page-number') return t('reader_show_page_number_title')
    if (parts[1] === 'image-fit') return t('settings_row_reader_image_fit_title')
    return t('reader_settings_tab_mode')
  }
  if (parts[0] === 'book-mode') return conflict.label === undefined ? t('device_sync_book_reader_mode') :
    conflict.label + ' · ' + t('reader_settings_tab_mode')
  if (parts[0] === 'book' || parts[0] === 'recent') return conflictValue(conflict.key, conflict.local)
  if (parts[0] === 'bookmark') return t('chapter_bookmarks')
  if (parts[0] === 'category') return t('library_category_name_label')
  return t(groupKey(conflict.group))
}

function localChoiceTitle(conflict: SyncMergeConflict): string {
  if (conflict.retainLocalOnDelete) return t('device_sync_upload_local_setting')
  if (!conflict.deleted) return t('device_sync_keep_local')
  const kind = syncKeyParts(conflict.key)[0]
  if (kind === 'book') return t('device_sync_keep_on_shelf')
  if (kind === 'bookmark') return t('device_sync_restore_bookmark')
  if (kind === 'recent' || kind === 'position') return t('device_sync_restore_local_position')
  return t('device_sync_keep_local')
}

@ObservedV2
export class DeviceSyncWebDavChrome {
  readonly scroller: Scroller = new Scroller()
  readonly confirm: FormTitleActionState = new FormTitleActionState()
  @Trace busy: boolean = false
  @Trace actionVisible: boolean = false
  @Trace shownSeq: number = 0
}

export type DeviceSyncReviewReason = 'first' | 'scope' | 'restore' | 'differences' | 'pending' | 'recovery'

@ComponentV2
export struct DeviceSyncOverviewPage {
  @Param inModal: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Event onOpenWebDav: () => void = (): void => {}
  @Event onOpenHuaweiCloud: () => void = (): void => {}
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private cloud: HuaweiCloudSyncView = appHuaweiCloudSync.view

  private toggle(group: SyncGroup, value: boolean): void {
    const current = this.state.selected
    if (current.includes(group) === value) return
    try {
      appDeviceSync.setSelection(value ? current.concat(group) : current.filter((id: SyncGroup): boolean => id !== group))
    } catch (error) {
      this.state.selected = current.slice()
      DiagnosticLogger.exception('device-sync', 'save-selection-failed', error as Error)
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('device_sync_scope_save_failed') }))
    }
  }

  build() {
    SecondaryListScaffold({ inModal: this.inModal, scroller: this.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t('device_sync_webdav'), subtitle: stateText(this.state),
            action: (): void => { this.onOpenWebDav() } })
          if (this.cloud.available) {
            ListDivider()
            ConciseListRow({ title: t('device_sync_cloud_title'), subtitle: cloudStatus(this.cloud),
              action: (): void => { this.onOpenHuaweiCloud() } })
          }
        }
      }
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_contents') }) {
          ForEach(SYNC_GROUPS, (group: SyncGroup, index: number) => {
            if (index > 0) ListDivider()
            ConciseListRow({ title: t(groupKey(group)), subtitle: t(groupKey(group) + '_detail'),
              hasSwitch: true, showChevron: false, checked: this.state.selected.includes(group),
              isEnabled: this.state.ready,
              switchAction: (value: boolean): void => { this.toggle(group, value) } })
          }, (group: SyncGroup): string => group)
        }
      }
    }
  }
}

function cloudStatus(state: HuaweiCloudSyncView): string {
  if (state.busy || state.configuring) return t('device_sync_running')
  const parts = state.error.split(':')
  const reason = parts[0]
  const group = SYNC_GROUPS.find((value: SyncGroup): boolean => value === parts[1])
  if (group !== undefined && (reason === 'upload' || reason === 'download' || reason === 'partial')) {
    const description = reason === 'upload' ? 'device_sync_cloud_upload_group_failed' : reason === 'download' ?
      'device_sync_cloud_download_group_failed' : 'device_sync_cloud_partial_group_failed'
    return t(description).replace('%s', t(groupKey(group)))
  }
  switch (state.error) {
    case '2': return t('device_sync_cloud_network')
    case '3': return t('device_sync_cloud_system_disabled')
    case '4': return t('device_sync_cloud_other_device')
    case '5':
    case 'record_size': return t('device_sync_cloud_record_limit')
    case '6': return t('device_sync_cloud_space_full')
    case '7': return t('device_sync_cloud_network_policy')
    case '8': return t('device_sync_paused')
    case 'permission': return t('device_sync_cloud_denied')
    case 'empty': return t('device_sync_cloud_empty')
    case 'timeout': return t('device_sync_cloud_timeout')
    case 'upload': return t('device_sync_cloud_upload_failed')
    case 'download': return t('device_sync_cloud_download_failed')
    case 'partial': return t('device_sync_cloud_partial')
    case 'table_setup': return t('device_sync_cloud_table_setup')
    case 'record_format': return t('device_sync_cloud_incompatible_record')
    case 'sync_local_busy':
    case 'sync_local_changed': return t('device_sync_error_local_busy')
    case '': break
    default: return t('device_sync_cloud_failed')
  }
  if (!state.enabled) return t('device_sync_paused')
  if (state.lastSuccess === 0) return t('device_sync_waiting_first_run')
  return t('device_sync_last_success_time').replace('%s', new Date(state.lastSuccess).toLocaleString())
}

@ComponentV2
export struct DeviceSyncHuaweiCloudPage {
  @Param inModal: boolean = false
  @Param scroller: Scroller = new Scroller()
  @Local private cloud: HuaweiCloudSyncView = appHuaweiCloudSync.view
  @Local private state: DeviceSyncViewState = appDeviceSync.view

  private openSystemCloud(): void {
    void appHuaweiCloudSync.openSystemSettings().catch((error: Error): void => {
      DiagnosticLogger.exception('huawei-cloud-sync', 'open-settings-failed', error)
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('device_sync_cloud_open_failed') }))
    })
  }

  build() {
    SecondaryListScaffold({ inModal: this.inModal, scroller: this.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t('device_sync_enabled'), hasSwitch: true, showChevron: false,
            checked: this.cloud.enabled, isEnabled: this.cloud.available && !this.cloud.configuring,
            switchAction: (enabled: boolean): void => { void appHuaweiCloudSync.setEnabled(enabled) } })
          ListDivider()
          ConciseListRow({ title: t('device_sync_cloud_system'), action: (): void => { this.openSystemCloud() } })
        }
      }
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t('device_sync_now'), showChevron: false,
            isEnabled: this.cloud.enabled && !this.cloud.busy && !this.cloud.configuring &&
              (this.cloud.verificationOnly || this.state.selected.length > 0),
            action: (): void => { void appHuaweiCloudSync.sync() } })
        }
      }
      if (this.cloud.enabled || this.cloud.configuring || this.cloud.error !== '') {
        ListItem() {
          Text(this.cloud.enabled && !this.cloud.busy && !this.cloud.configuring && this.cloud.error === '' &&
            this.state.selected.length === 0 && !this.cloud.verificationOnly ?
            t('device_sync_choose_in_overview') : cloudStatus(this.cloud))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
            .width('100%')
        }
      }
    }
  }
}

@ComponentV2
export struct DeviceSyncWebDavPage {
  @Param inModal: boolean = false
  @Param chrome: DeviceSyncWebDavChrome = new DeviceSyncWebDavChrome()
  @Event onEditConnection: () => void = (): void => {}
  @Event onReview: (groups: SyncGroup[], reason: DeviceSyncReviewReason) => void =
    (_groups: SyncGroup[], _reason: DeviceSyncReviewReason): void => {}
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private connectionLabel: string = ''

  aboutToAppear(): void { this.refreshConnection() }

  @Monitor('chrome.shownSeq')
  private shown(): void { this.refreshConnection() }

  private refreshConnection(): void {
    appDeviceSync.refreshReviewItemsIfNeeded()
    if (!this.state.configured) { this.connectionLabel = ''; return }
    void appDeviceSync.draft().then((draft: SyncConnectionDraft | undefined): void => {
      this.connectionLabel = draft === undefined ? '' : draft.directory + (draft.username ? '\n' + draft.username : '')
    }).catch((): void => { this.connectionLabel = t('device_sync_error_local') })
  }

  private statusDetail(): string {
    if (this.state.manualInProgress || this.state.transferInFlight || this.state.unresolvedCommit && this.state.busy) {
      return t('device_sync_running')
    }
    if (this.state.error !== '') {
      const scope = this.state.errorGroup === undefined ? '' : t(groupKey(this.state.errorGroup)) + ' · '
      return t('device_sync_failed') + '\n' + scope + errorText(this.state.error)
    }
    if (this.state.unresolvedCommit) {
      return t('device_sync_previous_interrupted') + '\n' + t('device_sync_previous_resume_detail')
    }
    if (this.state.enabled && this.state.readingPending) return t('device_sync_error_reading_local_change_pending')
    if (this.state.requiresExplicitReview || !this.state.enabled || this.state.selected.length === 0 ||
      this.state.lastSuccess === 0) return stateText(this.state)
    return t('device_sync_last_success_time').replace('%s', new Date(this.state.lastSuccess).toLocaleString())
  }

  build() {
    SecondaryListScaffold({ inModal: this.inModal, scroller: this.chrome.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t('device_sync_enabled'), hasSwitch: true, checked: this.state.enabled,
            showChevron: false, isEnabled: this.state.ready && this.state.configured,
            subtitle: !this.state.configured ? t('device_sync_configure_first') : this.state.enabled ?
              t(this.state.automatic ? 'device_sync_auto' : 'device_sync_manual') : undefined,
            switchAction: (value: boolean): void => { appDeviceSync.setEnabled(value) } })
        }
      }
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_connection') }) {
          ConciseListRow({ title: t(this.state.configured ? 'device_sync_edit' : 'device_sync_configure'),
            subtitle: this.state.configured ? this.connectionLabel : t('device_sync_configure_detail'), subtitleMaxLines: 3,
            isEnabled: this.state.ready, action: (): void => { this.onEditConnection() } })
        }
      }
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t('device_sync_last_result'), subtitle: this.statusDetail(), subtitleMaxLines: 5, showChevron: false })
          ListDivider()
          ConciseListRow({ title: t('device_sync_now'), showChevron: false,
            subtitle: this.state.selected.length === 0 ? t('device_sync_choose_in_overview') : undefined,
            isEnabled: this.state.configured && this.state.enabled && this.state.selected.length > 0 &&
              !this.state.manualInProgress && !this.state.requiresExplicitReview,
            action: (): void => { void appDeviceSync.syncManually().catch((): void => {}) } })
          if (this.state.requiresExplicitReview && this.state.selected.length > 0) {
            ListDivider()
            ConciseListRow({ title: t('device_sync_review_restore_title'),
              action: (): void => { this.onReview(this.state.selected.slice(), 'restore') } })
          }
          if (this.state.shelfRemovals.length > 0 || this.state.blockedReadings.length > 0) {
            ListDivider()
            ConciseListRow({ title: t('device_sync_pending_items'),
              action: (): void => { this.onReview(this.state.selected.slice(), 'pending') } })
          }
        }
      }
    }
  }
}

@ComponentV2
export struct DeviceSyncConnectionPage {
  @Param inModal: boolean = false
  @Param chrome: DeviceSyncWebDavChrome = new DeviceSyncWebDavChrome()
  @Param titleAction: FormTitleActionState = new FormTitleActionState()
  @Event onSaved: () => void = (): void => {}
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private directory: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private tested: boolean = false
  @Local private loading: boolean = true
  @Local private testing: boolean = false
  @Local private error: string = ''
  private visible: boolean = false
  private original?: SyncConnectionDraft

  aboutToAppear(): void {
    this.visible = true
    this.chrome.actionVisible = true
    void appDeviceSync.draft().then((draft: SyncConnectionDraft | undefined): void => {
      if (!this.visible) return
      this.original = draft
      this.directory = draft?.directory ?? ''
      this.username = draft?.username ?? ''
      this.password = draft?.password ?? ''
      this.loading = false
      this.updateAction()
    }).catch((error: Error): void => { if (this.visible) { this.loading = false; this.error = error.message } })
  }

  aboutToDisappear(): void {
    this.visible = false
    this.chrome.confirm.enabled = false
    this.chrome.actionVisible = false
    appDeviceSync.cancelConnectionTest()
    this.password = ''
    this.original = undefined
  }

  @Monitor('state.busy')
  private busyChanged(): void { this.updateAction() }

  @Monitor('titleAction.requestSeq')
  private requested(): void { if (this.visible && this.chrome.confirm.enabled) void this.save() }

  private updateAction(): void {
    const changed = this.original === undefined || this.directory !== this.original.directory ||
      this.username !== this.original.username || this.password !== this.original.password
    this.chrome.confirm.enabled = this.visible && this.canEditDraft() && changed && this.directory.trim().length > 0
  }

  private canEditDraft(): boolean {
    return !this.loading && !this.testing && !this.chrome.busy
  }

  private changed(): void { this.tested = false; this.error = ''; this.updateAction() }

  private draft(): SyncConnectionDraft { return { directory: this.directory, username: this.username, password: this.password } }

  private async test(): Promise<void> {
    if (!this.canEditDraft()) return
    this.testing = true
    this.updateAction()
    this.tested = false
    this.error = ''
    try {
      await appDeviceSync.test(this.draft(), [])
      if (this.visible) this.tested = true
    } catch (error) { if (this.visible) this.error = (error as Error).message }
    finally { this.testing = false; this.updateAction() }
  }

  private async save(): Promise<void> {
    if (!this.canEditDraft()) return
    this.chrome.busy = true
    this.updateAction()
    this.error = ''
    try {
      await appDeviceSync.saveConfiguration(this.draft())
      if (this.visible) this.onSaved()
    } catch (error) { if (this.visible) this.error = (error as Error).message }
    finally { this.chrome.busy = false; this.updateAction() }
  }

  build() {
    SecondaryListScaffold({ inModal: this.inModal, scroller: this.chrome.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_connection'),
          subtitle: t(this.state.configured ? 'device_sync_save_replace_detail' : 'device_sync_save_detail') }) {
          Column({ space: ThemeConstants.SPACE_MD }) {
            KomaFormTextField({ label: t('device_sync_address'), placeholder: 'https://', value: this.directory,
              isEnabled: this.canEditDraft(), change: (value: string): void => { this.directory = value; this.changed() } })
            KomaFormTextField({ label: t('device_sync_user'), value: this.username, isEnabled: this.canEditDraft(),
              change: (value: string): void => { this.username = value; this.changed() } })
            KomaFormTextField({ label: t('device_sync_password'), value: this.password, isPassword: true,
              isEnabled: this.canEditDraft(), change: (value: string): void => { this.password = value; this.changed() } })
          }.width('100%').padding(ThemeConstants.SPACE_MD)
        }
      }
      ListItem() {
        GroupedListSection({ inModal: this.inModal }) {
          ConciseListRow({ title: t(this.testing ? 'device_sync_testing_draft' : this.tested ? 'device_sync_test_ok' : 'device_sync_test'),
            subtitle: t('device_sync_test_detail'), showChevron: false,
            isEnabled: this.canEditDraft() && this.directory.trim().length > 0,
            action: (): void => { void this.test() } })
        }
      }
      if (this.chrome.busy || this.error.length > 0) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal }) {
            ConciseListRow({ title: t(this.chrome.busy ? 'device_sync_saving' : 'device_sync_connection_failed'),
              subtitle: errorText(this.error), subtitleMaxLines: 6, showChevron: false })
          }
        }
      }
    }
  }
}

@ComponentV2
export struct DeviceSyncReviewPage {
  @Param inModal: boolean = false
  @Param chrome: DeviceSyncWebDavChrome = new DeviceSyncWebDavChrome()
  @Param titleAction: FormTitleActionState = new FormTitleActionState()
  @Param selected: SyncGroup[] = []
  @Param reason: DeviceSyncReviewReason = 'first'
  @Event onCompleted: () => void = (): void => {}
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private preview?: SyncPreview
  @Local private choices: SyncMergeChoice[] = []
  @Local private loading: boolean = false
  @Local private reviewError: boolean = false
  @Local private error: string = ''
  private visible: boolean = false
  private releaseAutomatic?: () => void

  aboutToAppear(): void {
    this.visible = true
    appDeviceSync.refreshReviewItemsIfNeeded()
    this.releaseAutomatic = appDeviceSync.holdAutomaticForReview()
    if (this.reason !== 'recovery' && this.reason !== 'pending') void this.load()
  }

  aboutToDisappear(): void {
    this.visible = false
    this.chrome.actionVisible = false
    this.chrome.confirm.enabled = false
    appDeviceSync.discard(this.preview?.token)
    this.releaseAutomatic?.()
    this.releaseAutomatic = undefined
    this.preview = undefined
    this.choices = []
  }

  @Monitor('titleAction.requestSeq')
  private requested(): void { if (this.visible && this.preview !== undefined && !this.state.busy) void this.commit() }

  @Monitor('state.busy')
  private busyChanged(): void { this.chrome.confirm.enabled = this.visible && this.preview !== undefined && !this.state.busy }

  private async load(): Promise<void> {
    this.loading = true
    this.reviewError = false
    this.error = ''
    try {
      await appDeviceSync.waitForCurrentTransfer()
      if (!this.visible) return
      const preview = await appDeviceSync.prepareSaved(this.selected)
      if (!this.visible) { appDeviceSync.discard(preview.token); return }
      this.preview = preview
      this.choices = []
      this.chrome.actionVisible = true
      this.chrome.confirm.enabled = !this.state.busy
    } catch (error) { if (this.visible) { this.error = (error as Error).message; this.reviewError = true } }
    finally { this.loading = false }
  }

  private async commit(): Promise<void> {
    const preview = this.preview
    if (preview === undefined) return
    this.chrome.busy = true
    this.error = ''
    try {
      await appDeviceSync.confirm(preview.token, this.choices)
      if (this.visible) this.onCompleted()
    } catch (error) {
      if (this.visible) { this.error = (error as Error).message; this.reviewError = true }
    } finally {
      this.preview = undefined
      this.chrome.actionVisible = false
      this.chrome.confirm.enabled = false
      this.chrome.busy = false
    }
  }

  private async recover(): Promise<void> {
    this.chrome.busy = true
    this.error = ''
    try { await appDeviceSync.recoverLastSync(); if (this.visible) this.onCompleted() }
    catch (error) { if (this.visible) this.error = (error as Error).message }
    finally { this.chrome.busy = false }
  }

  private itemAction(action: () => Promise<void>): void {
    this.error = ''
    this.reviewError = false
    void action().catch((error: Error): void => { if (this.visible) this.error = error.message })
  }

  private visibleRemovals(): SyncPreviewRemoval[] { return this.preview?.removals ?? [] }

  private removalTitle(item: SyncPreviewRemoval): string {
    if (item.label !== undefined) return item.label
    const parts = syncKeyParts(item.key)
    if (parts[0] === 'global') return conflictTitle({ group: item.group, key: item.key, local: item.value, remote: '', deleted: true })
    if (['member', 'position', 'read', 'bookmark'].includes(parts[0])) return parts.slice(1).join(' · ')
    return conflictValue(item.key, item.value)
  }

  private choice(conflict: SyncMergeConflict): SyncMergeChoice | undefined {
    return this.choices.find((item: SyncMergeChoice): boolean => item.group === conflict.group && item.key === conflict.key)
  }

  private choose(conflict: SyncMergeConflict, useLocal?: boolean, useBeforeRestore: boolean = false): void {
    const choices = this.choices.filter((choice: SyncMergeChoice): boolean => choice.group !== conflict.group || choice.key !== conflict.key)
    this.choices = useLocal === undefined ? choices :
      choices.concat({ group: conflict.group, key: conflict.key, useLocal, useBeforeRestore })
    if (this.preview !== undefined) {
      try { this.preview = appDeviceSync.previewChoices(this.preview.token, this.choices) }
      catch (error) {
        this.error = (error as Error).message
        this.reviewError = true
        this.preview = undefined
        this.chrome.confirm.enabled = false
        this.chrome.actionVisible = false
      }
    }
  }

  private choiceLabel(conflict: SyncMergeConflict): string {
    const current = this.choice(conflict)
    if (current?.useBeforeRestore) return t('device_sync_before_restore_short')
    if (current?.useLocal === true) return conflict.deleted ? localChoiceTitle(conflict) : t('device_sync_this_device')
    if (conflict.retainLocalOnDelete) return t('device_sync_keep_local_setting')
    if (conflict.deleted) return t('device_sync_apply_removal')
    return t(current === undefined ? 'device_sync_defer' : 'device_sync_other_device')
  }

  private summary(id: SyncGroup): string {
    const group = this.preview?.groups.find((item: SyncPreviewGroup): boolean => item.group === id)
    if (group === undefined) return ''
    const parts: string[] = []
    if (group.upload > 0) parts.push(t('device_sync_summary_upload').replace('%s', group.upload.toString()))
    if (group.download > 0) parts.push(t('device_sync_summary_download').replace('%s', group.download.toString()))
    if (group.remove > 0) parts.push(t('device_sync_summary_remove').replace('%s', group.remove.toString()))
    if ((group.retained ?? 0) > 0) parts.push(t('device_sync_summary_retained').replace('%s', (group.retained ?? 0).toString()))
    if ((group.deferred ?? 0) > 0) parts.push(t('device_sync_summary_defer').replace('%s', (group.deferred ?? 0).toString()))
    const outside = group.readingOutsideScope ?? 0
    if (outside > 0) parts.push(t('device_sync_reading_outside_scope').replace('%s', outside.toString()))
    if (group.group !== 'reading' && group.skipped > 0) parts.push(t('device_sync_summary_skip').replace('%s', group.skipped.toString()))
    return parts.length === 0 ? t('device_sync_summary_empty') : parts.join(' · ')
  }

  @Builder
  private ChoiceItem(title: string, checked: boolean, select: (action: () => void) => void, action: () => void) {
    MenuItem({ content: title })
      .selected(checked)
      .selectIcon(true)
      .onClick((): void => { select(action) })
  }

  @Builder
  private ConflictMenu(item: SyncMergeConflict, select: (action: () => void) => void) {
    Menu() {
      if (item.retainLocalOnDelete) {
        this.ChoiceItem(t('device_sync_keep_local_setting'), this.choice(item)?.useLocal !== true,
          select, (): void => { this.choose(item, false) })
        this.ChoiceItem(t('device_sync_upload_local_setting'), this.choice(item)?.useLocal === true,
          select, (): void => { this.choose(item, true) })
      } else {
        if (!item.deleted) {
          this.ChoiceItem(t('device_sync_defer'), this.choice(item) === undefined, select, (): void => { this.choose(item) })
        }
        this.ChoiceItem(localChoiceTitle(item), this.choice(item)?.useLocal === true &&
          this.choice(item)?.useBeforeRestore !== true, select, (): void => { this.choose(item, true) })
        this.ChoiceItem(t(item.deleted ? 'device_sync_apply_removal' : 'device_sync_keep_remote'),
          item.deleted ? this.choice(item)?.useLocal !== true : this.choice(item)?.useLocal === false,
          select, (): void => { this.choose(item, false) })
      }
    }
  }

  @Builder
  private Review(preview: SyncPreview) {
    ListItem() {
      GroupedListSection({ inModal: this.inModal }) {
        ConciseListRow({ title: t('device_sync_destination'), subtitle: preview.destination,
          subtitleMaxLines: 4, showChevron: false })
      }
    }
    ListItem() {
      GroupedListSection({ inModal: this.inModal, title: t('device_sync_review_contents'),
        subtitle: preview.groups.some((row: SyncPreviewGroup): boolean => row.group !== 'reading' && row.skipped > 0) ?
          t('device_sync_skipped_detail') : undefined }) {
        if (preview.migration) {
          ConciseListRow({ title: t('device_sync_migration_title'), subtitle: t('device_sync_migration_detail'),
            subtitleMaxLines: 8, showChevron: false })
          ListDivider()
        }
        ForEach(preview.groups, (row: SyncPreviewGroup, index: number) => {
          if (index > 0) ListDivider()
          ConciseListRow({ title: t(groupKey(row.group)), showChevron: false, subtitle: this.summary(row.group) })
        }, (row: SyncPreviewGroup): string => row.group)
        if (preview.categories.length > 0) {
          ListDivider()
          ConciseListRow({ title: t('device_sync_category_names'), subtitle: preview.categories.join('、'), subtitleMaxLines: 6, showChevron: false })
        }
        ListDivider()
        ConciseListRow({ title: t('device_sync_review_visibility'), subtitle: t('device_sync_visibility'), subtitleMaxLines: 8, showChevron: false })
        if (preview.earlierUnconfirmed > 0) {
          ListDivider()
          ConciseListRow({ title: t('device_sync_earlier_unconfirmed'),
            subtitle: t('device_sync_earlier_unconfirmed_detail').replace('%s', preview.earlierUnconfirmed.toString()),
            subtitleMaxLines: 5, showChevron: false })
        }
      }
    }
    if (this.visibleRemovals().length > 0) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_removals_title') }) {
          ForEach(this.visibleRemovals(), (item: SyncPreviewRemoval, index: number) => {
            if (index > 0) ListDivider()
            ConciseListRow({ title: this.removalTitle(item), subtitle: t(groupKey(item.group)) + ' · ' + t(item.target === 'remote' ? 'device_sync_other_device' : 'device_sync_this_device'),
              wrapTitle: true, subtitleMaxLines: 3, showChevron: false })
          }, (item: SyncPreviewRemoval): string => item.group + item.key + item.target)
        }
      }
    }
    if (preview.conflicts.length > 0) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_review_differences'),
          subtitle: t(preview.conflicts.some((item: SyncMergeConflict): boolean => item.retainLocalOnDelete === true) ?
            'device_sync_retained_setting_detail' : 'device_sync_review_differences_detail') }) {
          ForEach(preview.conflicts, (item: SyncMergeConflict, index: number) => {
            if (index > 0) ListDivider()
            ConciseListRow({ title: conflictTitle(item), wrapTitle: true, wrapTitleByWord: true, subtitleMaxLines: 6,
              subtitle: t('device_sync_this_device') + ' · ' + conflictValue(item.key, item.local) + '\n' +
                t('device_sync_other_device') + ' · ' + conflictValue(item.key, item.remote),
              trailingText: this.choiceLabel(item), trailingDropdown: true, dropdownMenuEnabled: true,
              isEnabled: !this.state.busy,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ConflictMenu(item, select) } })
          }, (item: SyncMergeConflict): string => item.group + item.key)
        }
      }
    }
    if (preview.beforeRestore.length > 0) {
      ListItem() {
        GroupedListSection({ inModal: this.inModal, title: t('device_sync_before_restore'), subtitle: t('device_sync_review_restore_detail') }) {
          ForEach(preview.beforeRestore, (item: SyncMergeConflict, index: number) => {
            if (index > 0) ListDivider()
            ConciseListRow({ title: conflictTitle(item), wrapTitle: true,
              subtitle: t('device_sync_before_restore_short') + ' · ' + conflictValue(item.key, item.local) + '\n' +
                t('device_sync_current_value') + ' · ' + conflictValue(item.key, item.remote), subtitleMaxLines: 6,
              hasSwitch: true, showChevron: false, isEnabled: !this.state.busy,
              checked: this.choice(item)?.useBeforeRestore === true,
              switchAction: (checked: boolean): void => { this.choose(item, checked ? true : undefined, true) } })
          }, (item: SyncMergeConflict): string => item.group + item.key)
        }
      }
    }
  }


  @Builder
  private PendingItems() {
      if (this.state.shelfRemovals.length > 0) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal, title: t('device_sync_shelf_removals') }) {
            ForEach(this.state.shelfRemovals, (item: SyncShelfRemoval, index: number) => {
              if (index > 0) ListDivider()
              ConciseListRow({ title: item.title, subtitle: t('device_sync_shelf_removal_detail'), subtitleMaxLines: 4, showChevron: false,
                isEnabled: !this.state.busy, action: (): void => { this.reviewShelfRemoval(item) } })
            }, (item: SyncShelfRemoval): string => item.id)
          }
        }
      }
      if (this.state.blockedReadings.length > 0) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal, title: t('device_sync_reading_results') }) {
            ForEach(this.state.blockedReadings, (item: SyncBlockedReading) => {
              ConciseListRow({ title: item.title || t('device_sync_group_reading'), showChevron: false,
                subtitle: t('device_sync_reading_retained').replace('%s', (item.capture.page + 1).toString()),
                isEnabled: this.state.enabled && !this.state.busy && !this.state.requiresExplicitReview, action: (): void => {
                  this.getUIContext().showAlertDialog({
                    title: t('device_sync_apply_reading'), message: t('device_sync_reading_retained_confirmation'),
                    systemMaterial: komaDialogMaterial(), primaryButton: { value: t('common_cancel'), action: (): void => {} },
                    secondaryButton: { value: t('common_confirm'), action: (): void => {
                      this.itemAction((): Promise<void> => appDeviceSync.recoverBlockedReading(item))
                    } },
                  })
                } })
            }, (item: SyncBlockedReading): string => item.capture.id)
          }
        }
      }

  }

  private reviewShelfRemoval(item: SyncShelfRemoval): void {
    void this.getUIContext().getPromptAction().showDialog({
      title: item.title, message: t('device_sync_shelf_removal_detail'), systemMaterial: komaDialogMaterial(),
      buttons: [
        { text: t('device_sync_remove_from_shelf'), color: $r('sys.color.font_emphasize') },
        { text: t('device_sync_keep_on_shelf'), color: $r('app.color.koma_accent') },
      ],
    }).then((result): void => {
      if (result.index >= 0 && result.index <= 1) {
        this.itemAction((): Promise<void> => appDeviceSync.resolveShelfRemoval(item, result.index === 1))
      }
    }).catch((): void => {})
  }

  build() {
    SecondaryListScaffold({ inModal: this.inModal, scroller: this.chrome.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.preview !== undefined) this.Review(this.preview)
      if (this.loading || this.error.length > 0 || this.state.unresolvedCommit) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal }) {
            ConciseListRow({ title: t(this.loading ? 'device_sync_preparing' : this.error.length > 0 ?
                'device_sync_failed' : 'device_sync_previous_interrupted'),
              subtitle: this.error.length > 0 ? errorText(this.error) :
                this.state.unresolvedCommit ? t('device_sync_previous_resume_detail') : '',
              subtitleMaxLines: 6, showChevron: false })
            if (!this.loading && this.preview === undefined && (this.state.unresolvedCommit || this.reviewError)) {
              ListDivider()
              ConciseListRow({ title: t(this.state.unresolvedCommit ? 'device_sync_continue_previous' : 'device_sync_preview'),
                showChevron: false,
                isEnabled: !this.state.busy && (this.state.enabled ||
                  (this.state.awaitingFirstMerge || this.state.requiresExplicitReview) && !this.state.unresolvedCommit),
                action: (): void => { if (this.state.unresolvedCommit) void this.recover(); else void this.load() } })
            }
          }
        }
      }
      if (this.reason === 'pending') this.PendingItems()
      if (this.reason === 'pending' && !this.state.enabled) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal }) {
            ConciseListRow({ title: t('device_sync_paused'), subtitle: t('device_sync_paused_review_detail'),
              subtitleMaxLines: 4, showChevron: false })
          }
        }
      }
      if (this.reason === 'pending' && !this.state.needsReview &&
        this.state.shelfRemovals.length === 0 && this.state.blockedReadings.length === 0) {
        ListItem() {
          GroupedListSection({ inModal: this.inModal }) {
            ConciseListRow({ title: t('device_sync_no_pending_items'), showChevron: false })
          }
        }
      }
    }
  }
}
