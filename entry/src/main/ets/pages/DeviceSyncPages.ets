import { AppStrings } from '../i18n/AppStrings'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { ThemeConstants } from '../theme/ThemeConstants'
import { komaDialogMaterial } from '../theme/KomaPopupOptions'
import { FormTitleActionState } from '../state/FormTitleActionState'
import { ReadingDirection } from '../model/ComicModels'
import { readerControlDirection, readerControlDirectionLabelKey } from '../model/ReaderControlChoices'
import { ReaderPageMode } from '../model/ReaderPreferencesStore'
import { appDeviceSync, DeviceSyncViewState } from '../deviceSync/DeviceSyncRuntime'
import { SyncGroup, SYNC_GROUPS } from '../deviceSync/DeviceSyncFacts'
import { SyncMergeChoice, SyncMergeConflict, SyncPreview, SyncPreviewGroup, SyncReadingDecision } from '../deviceSync/DeviceSyncEngine'
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
  if (code === 'sync_authentication_failed') return t('device_sync_error_auth')
  if (code === 'sync_permission_denied' || code === 'sync_directory_missing') return t('device_sync_error_permission')
  if (code === 'sync_https_directory_required' || code === 'sync_directory_redirected') return t('device_sync_error_https')
  if (code === 'sync_tls_failed') return t('device_sync_error_tls')
  if (code === 'sync_network_failed' || code === 'sync_server_unavailable') return t('device_sync_error_network')
  if (code === 'sync_preconditions_unsupported') return t('device_sync_error_conditional')
  if (code === 'sync_server_storage_full') return t('device_sync_error_storage')
  if (code === 'sync_update_required') return t('device_sync_error_upgrade')
  if (code === 'sync_preview_changed' || code === 'sync_remote_changed' || code === 'sync_review_required' ||
    code === 'sync_local_changed' || code === 'sync_remote_committed_locally_changed') return t('device_sync_error_review')
  if (code === 'sync_space_changed') return t('device_sync_error_space')
  if (code === 'sync_remote_result_unknown') return t('device_sync_error_unknown_result')
  if (code === 'sync_catalog_limit') return t('device_sync_error_catalog_limit')
  if (code === 'sync_catalog_unavailable') return t('device_sync_error_catalog_unavailable')
  if (code === 'sync_public_work_unavailable') return t('device_sync_error_public_work')
  if (code === 'sync_reading_proof_pending') return t('device_sync_error_reading_proof_pending')
  if (code === 'sync_maintenance_running') return t('device_sync_error_maintenance')
  if (code === 'sync_invalid_username' || code === 'sync_credentials_too_long') return t('device_sync_error_credentials')
  if (code === 'sync_select_contents') return t('device_sync_no_selection')
  if (code.startsWith('sync_local_') || code.startsWith('sync_credential_')) return t('device_sync_error_local')
  if (code.startsWith('sync_invalid_') || code.startsWith('sync_shard_')) return t('device_sync_error_damaged')
  return t('device_sync_error_retry')
}

function stateText(state: DeviceSyncViewState): string {
  if (!state.ready) return t('device_sync_loading')
  if (state.busy) return t('device_sync_running')
  if (state.needsReview) return t('device_sync_review_required')
  if (state.error.length > 0) return t('device_sync_needs_attention')
  if (!state.connected) return t('device_sync_disconnected')
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
  if (kind === 'book') return (JSON.parse(value) as SyncWorkLabel).title
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
  if (parts[0] === 'global') {
    if (parts[1] === 'animation') return t('reader_page_turn_animation_title')
    if (parts[1] === 'page-number') return t('reader_show_page_number_title')
    if (parts[1] === 'image-fit') return t('settings_row_reader_image_fit_title')
    return t('reader_settings_tab_mode')
  }
  if (parts[0] === 'book-mode') return conflict.label === undefined ? t('device_sync_book_reader_mode') :
    conflict.label + ' · ' + t('reader_settings_tab_mode')
  if (parts[0] === 'book' || parts[0] === 'recent') return conflictValue(conflict.key, conflict.local)
  return t(groupKey(conflict.group))
}

@ComponentV2
export struct DeviceSyncOverviewPage {
  @Event onOpenWebDav: (groups: SyncGroup[]) => void = (_groups: SyncGroup[]): void => {}
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private scroller: Scroller = new Scroller()

  private toggle(group: SyncGroup, enable: boolean): void {
    const previous = this.state.selected
    if (previous.includes(group) === enable) return
    const next = enable ? previous.concat(group) : previous.filter((id: SyncGroup): boolean => id !== group)
    if (enable && this.state.connected) this.onOpenWebDav(next)
    else appDeviceSync.setSelection(next)
  }

  @Builder
  private DatasetRow(group: SyncGroup) {
    ConciseListRow({
      title: t(groupKey(group)), subtitle: t(groupKey(group) + '_detail'),
      hasSwitch: true, showChevron: false, checked: this.state.selected.includes(group),
      isEnabled: this.state.ready && (!this.state.busy || (this.state.connected && this.state.selected.includes(group))),
      switchAction: (checked: boolean): void => { this.toggle(group, checked) },
    })
  }

  build() {
    SecondaryListScaffold({ scroller: this.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection() {
          ConciseListRow({ title: t('device_sync_webdav'), subtitle: stateText(this.state),
            action: (): void => { this.onOpenWebDav([]) } })
        }
      }
      ListItem() {
        GroupedListSection({ title: t('device_sync_contents') }) {
          ForEach(SYNC_GROUPS, (group: SyncGroup, index: number) => {
            if (index > 0) ListDivider()
            this.DatasetRow(group)
          }, (group: SyncGroup): string => group)
        }
      }
      if (this.state.selected.includes('source-subscriptions') && this.state.subscriptions.length > 0) {
        ListItem() {
          GroupedListSection({ title: t('device_sync_received_subscriptions') }) {
            ForEach(this.state.subscriptions, (candidate: SyncLocalValue) => {
              ConciseListRow({ title: (JSON.parse(candidate.value) as SyncSubscription).label || t('device_sync_catalog'),
                subtitle: t('device_sync_catalog_accept'),
                isEnabled: !this.state.busy, action: (): void => {
                  this.getUIContext().showAlertDialog({
                    title: t('device_sync_catalog_accept'), message: (JSON.parse(candidate.value) as SyncSubscription).address,
                    systemMaterial: komaDialogMaterial(), primaryButton: { value: t('common_cancel'), action: (): void => {} },
                    secondaryButton: { value: t('common_confirm'), action: (): void => {
                      void appDeviceSync.acceptSubscription(candidate).catch((): void => {})
                    } },
                  })
                } })
            }, (candidate: SyncLocalValue): string => candidate.key)
          }
        }
      }
      if (this.state.shelfRemovals.length > 0) {
        ListItem() {
          GroupedListSection({ title: t('device_sync_shelf_removals') }) {
            ForEach(this.state.shelfRemovals, (item: SyncShelfRemoval, index: number) => {
              if (index > 0) ListDivider()
              ConciseListRow({ title: item.title, subtitle: t('device_sync_shelf_removal_detail'), subtitleMaxLines: 4,
                isEnabled: !this.state.busy, action: (): void => { this.reviewShelfRemoval(item) } })
            }, (item: SyncShelfRemoval): string => item.id)
          }
        }
      }
      if (this.state.readingDecisions.length > 0 || this.state.blockedReadings.length > 0) {
        ListItem() {
          GroupedListSection({ title: t('device_sync_reading_results') }) {
            ForEach(this.state.readingDecisions, (item: SyncReadingDecision) => {
              ConciseListRow({ title: item.title || t('device_sync_group_reading'), subtitle: t('device_sync_reading_conflict'), showChevron: false })
              ForEach(item.values, (value: string) => {
                ConciseListRow({ title: conflictValue(item.key, value), subtitle: t('device_sync_apply_reading'),
                  isEnabled: !this.state.busy && !this.state.needsReview, action: (): void => {
                    void appDeviceSync.chooseReadingDecision(item.key, value).catch((): void => {})
                  } })
              }, (value: string): string => value)
              ListDivider()
            }, (item: SyncReadingDecision): string => item.key)
            ForEach(this.state.blockedReadings, (item: SyncBlockedReading) => {
              ConciseListRow({ title: item.title || t('device_sync_group_reading'),
                subtitle: t('device_sync_reading_retained').replace('%s', (item.capture.page + 1).toString()),
                isEnabled: !this.state.busy && !this.state.needsReview, action: (): void => {
                  this.getUIContext().showAlertDialog({
                    title: t('device_sync_apply_reading'), message: t('device_sync_reading_retained_confirmation'),
                    systemMaterial: komaDialogMaterial(), primaryButton: { value: t('common_cancel'), action: (): void => {} },
                    secondaryButton: { value: t('common_confirm'), action: (): void => {
                      void appDeviceSync.recoverBlockedReading(item).catch((): void => {})
                    } },
                  })
                } })
            }, (item: SyncBlockedReading): string => item.capture.id)
          }
        }
      }
      if (this.state.error.length > 0) {
        ListItem() {
          GroupedListSection() {
            ConciseListRow({ title: t('device_sync_needs_attention'), subtitle: errorText(this.state.error),
              action: (): void => { this.onOpenWebDav([]) } })
          }
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
        void appDeviceSync.resolveShelfRemoval(item, result.index === 1).catch((): void => {})
      }
    }).catch((): void => {})
  }
}

@ComponentV2
export struct DeviceSyncWebDavPage {
  @Param proposedSelection: SyncGroup[] = []
  @Param titleAction: FormTitleActionState = new FormTitleActionState()
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private scroller: Scroller = new Scroller()
  @Local private editing: boolean = false
  @Local private tested: boolean = false
  @Local private directory: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private preview?: SyncPreview
  @Local private choices: SyncMergeChoice[] = []
  private visible: boolean = false

  @Monitor('titleAction.requestSeq')
  private requestMerge(): void {
    if (this.visible && !this.state.busy) void this.commit()
  }

  aboutToAppear(): void {
    this.visible = true
    this.editing = !this.state.connected
    if (this.state.connected && this.proposedSelection.length > 0) void this.previewSaved()
  }

  aboutToDisappear(): void {
    this.visible = false
    this.discard()
    this.password = ''
  }

  private groups(): SyncGroup[] {
    return this.proposedSelection.length === 0 ? this.state.selected.slice() : this.proposedSelection.slice()
  }

  private discard(): void {
    if (this.preview !== undefined) appDeviceSync.discard(this.preview.token)
    this.preview = undefined
    this.choices = []
    this.titleAction.enabled = false
  }

  private edit(): void {
    this.discard()
    this.tested = false
    this.editing = true
    void appDeviceSync.draft().then((draft: SyncConnectionDraft | undefined): void => {
      if (!this.visible || !this.editing || draft === undefined) return
      this.directory = draft.directory
      this.username = draft.username
      this.password = draft.password
    }).catch((): void => {})
  }

  private edited(): void {
    this.tested = false
    this.discard()
  }

  private async previewSaved(): Promise<void> {
    try {
      const draft = await appDeviceSync.draft()
      if (draft !== undefined) await this.makePreview(draft)
    } catch (_error) {
    }
  }

  private async makePreview(draft: SyncConnectionDraft): Promise<void> {
    const result = await appDeviceSync.prepare(draft, this.groups())
    if (!this.visible) {
      appDeviceSync.discard(result.token)
      return
    }
    this.choices = []
    this.preview = result
    this.titleAction.enabled = true
  }

  private async testConnection(): Promise<void> {
    const draft: SyncConnectionDraft = { directory: this.directory, username: this.username, password: this.password }
    this.discard()
    try {
      const recovered = await appDeviceSync.test(draft, this.groups())
      if (!this.visible) return
      if (recovered) {
        this.editing = false
        this.tested = false
        this.password = ''
        return
      }
      this.tested = true
      if (this.groups().length > 0) await this.makePreview(draft)
    } catch (_error) {
    }
  }

  private choose(conflict: SyncMergeConflict, useLocal: boolean): void {
    this.choices = this.choices.filter((choice: SyncMergeChoice): boolean =>
      choice.group !== conflict.group || choice.key !== conflict.key).concat({ group: conflict.group, key: conflict.key, useLocal })
  }

  private async commit(): Promise<void> {
    const preview = this.preview
    if (preview === undefined) return
    try {
      await appDeviceSync.confirm(preview.token, this.choices)
      this.editing = false
      this.tested = false
      this.password = ''
    } catch (_error) {
    } finally {
      this.discard()
    }
  }

  private disconnect(): void {
    this.getUIContext().showAlertDialog({
      title: t('device_sync_disconnect'), message: t('device_sync_disconnect_detail'),
      systemMaterial: komaDialogMaterial(),
      primaryButton: { value: t('common_cancel'), action: (): void => {} },
      secondaryButton: { value: t('device_sync_disconnect'), action: (): void => {
        this.discard()
        void appDeviceSync.disconnect().then((): void => {
          this.editing = true
          this.directory = ''
          this.username = ''
          this.password = ''
          this.tested = false
        }).catch((): void => {})
      } },
    })
  }

  @Builder
  private Connection() {
    GroupedListSection({ title: t('device_sync_connection') }) {
      if (this.editing) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          KomaFormTextField({ label: t('device_sync_address'), placeholder: 'https://', value: this.directory,
            isEnabled: !this.state.busy, change: (value: string): void => { this.directory = value; this.edited() } })
          KomaFormTextField({ label: t('device_sync_user'), value: this.username, isEnabled: !this.state.busy,
            change: (value: string): void => { this.username = value; this.edited() } })
          KomaFormTextField({ label: t('device_sync_password'), value: this.password, isPassword: true,
            isEnabled: !this.state.busy, change: (value: string): void => { this.password = value; this.edited() } })
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_MD)
        ListDivider()
        ConciseListRow({ title: t(this.tested ? 'device_sync_test_ok' : 'device_sync_test'),
          subtitle: t('device_sync_test_detail'), isEnabled: !this.state.busy && this.directory.trim().length > 0,
          action: (): void => { void this.testConnection() } })
        if (this.state.connected) {
          ListDivider()
          ConciseListRow({ title: t('common_cancel'), isEnabled: !this.state.busy,
            action: (): void => { this.editing = false; this.password = ''; this.discard() } })
        }
      } else {
        ConciseListRow({ title: t('device_sync_edit'), subtitle: stateText(this.state),
          isEnabled: !this.state.busy, action: (): void => { this.edit() } })
        ListDivider()
        ConciseListRow({ title: t('device_sync_disconnect'), action: (): void => { this.disconnect() } })
      }
    }
  }

  @Builder
  private Review(preview: SyncPreview) {
    GroupedListSection({ title: t('device_sync_preview') }) {
      ConciseListRow({ title: t('device_sync_preview_detail'), wrapTitle: true, wrapTitleByWord: true,
        subtitle: t('device_sync_visibility'), subtitleMaxLines: 8, showChevron: false })
      if (preview.earlierUnconfirmed > 0) {
        ListDivider()
        ConciseListRow({ title: t('device_sync_earlier_unconfirmed'),
          subtitle: t('device_sync_earlier_unconfirmed_detail').replace('%s', preview.earlierUnconfirmed.toString()),
          showChevron: false })
      }
      ForEach(preview.groups, (row: SyncPreviewGroup) => {
        ListDivider()
        ConciseListRow({ title: t(groupKey(row.group)), showChevron: false,
          subtitle: t('device_sync_counts').replace('%1', row.upload.toString()).replace('%2', row.download.toString())
            .replace('%3', row.remove.toString()).replace('%4', row.skipped.toString()) })
      }, (row: SyncPreviewGroup): string => row.group)
      if (preview.categories.length > 0) {
        ListDivider()
        ConciseListRow({ title: t('device_sync_category_names'), subtitle: preview.categories.join('、'), showChevron: false })
      }
      ForEach(preview.conflicts, (conflict: SyncMergeConflict) => {
        ListDivider()
        ConciseListRow({ title: conflictTitle(conflict), showChevron: false, wrapTitle: true, subtitleMaxLines: 6,
          subtitle: t('device_sync_this_device') + ' · ' + conflictValue(conflict.key, conflict.local) + '\n' +
            t('device_sync_other_device') + ' · ' + conflictValue(conflict.key, conflict.remote) })
        ConciseListRow({ title: t('device_sync_keep_local'), showChevron: false,
          isEnabled: !this.choices.some((choice: SyncMergeChoice): boolean => choice.key === conflict.key && choice.useLocal),
          action: (): void => { this.choose(conflict, true) } })
        ConciseListRow({ title: t('device_sync_keep_remote'), showChevron: false,
          isEnabled: !this.choices.some((choice: SyncMergeChoice): boolean => choice.key === conflict.key && !choice.useLocal),
          action: (): void => { this.choose(conflict, false) } })
      }, (conflict: SyncMergeConflict): string => conflict.group + conflict.key)
      if (preview.beforeRestore.length > 0) {
        ListDivider()
        ConciseListRow({ title: t('device_sync_before_restore'), subtitle: t('device_sync_before_restore_detail'), showChevron: false })
        ForEach(preview.beforeRestore, (item: SyncMergeConflict) => {
          ListDivider()
          ConciseListRow({ title: conflictValue(item.key, item.local), showChevron: false,
            subtitle: t('device_sync_current_value') + ' · ' + conflictValue(item.key, item.remote) })
          ConciseListRow({ title: t('device_sync_use_before_restore'), hasSwitch: true, showChevron: false,
            checked: this.choices.some((choice: SyncMergeChoice): boolean =>
              choice.key === item.key && choice.group === item.group && choice.useBeforeRestore === true),
            switchAction: (checked: boolean): void => {
              this.choices = this.choices.filter((choice: SyncMergeChoice): boolean =>
                choice.key !== item.key || choice.group !== item.group)
              if (checked) this.choices = this.choices.concat({ group: item.group, key: item.key, useLocal: true, useBeforeRestore: true })
            } })
        }, (item: SyncMergeConflict): string => item.group + item.key)
      }
      ListDivider()
      ConciseListRow({ title: t('common_cancel'), showChevron: false,
        isEnabled: !this.state.busy, action: (): void => { this.discard() } })
    }
  }

  @Builder
  private Run() {
    GroupedListSection({ title: t('device_sync_run') }) {
      ConciseListRow({ title: t('device_sync_auto'), hasSwitch: true, checked: this.state.automatic,
        showChevron: false, isEnabled: !this.state.busy && !this.state.needsReview,
        switchAction: (value: boolean): void => {
          if (value !== this.state.automatic) appDeviceSync.setAutomatic(value)
        } })
      ListDivider()
      if (this.state.needsReview || this.proposedSelection.length > 0) {
        ConciseListRow({ title: t('device_sync_preview'), isEnabled: !this.state.busy,
          action: (): void => { void this.previewSaved() } })
      } else {
        ConciseListRow({ title: t('device_sync_now'),
          subtitle: this.state.selected.length === 0 ? t('device_sync_no_selection') : '',
          isEnabled: !this.state.busy && this.state.selected.length > 0,
          action: (): void => { void appDeviceSync.sync().catch((): void => {}) } })
      }
    }
  }

  build() {
    SecondaryListScaffold({ scroller: this.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() { this.Connection() }
      if (this.preview !== undefined) {
        ListItem() { this.Review(this.preview) }
      } else if (this.state.connected && !this.editing) {
        ListItem() { this.Run() }
      }
      ListItem() {
        GroupedListSection({ title: t('device_sync_status') }) {
          ConciseListRow({ title: this.preview !== undefined && !this.state.busy && !this.state.connected ?
            t('device_sync_waiting_confirmation') : stateText(this.state),
            subtitle: errorText(this.state.error), showChevron: false })
          if (this.state.lastSuccess > 0) {
            ListDivider()
            ConciseListRow({ title: t('device_sync_last_success'), subtitle: new Date(this.state.lastSuccess).toLocaleString(),
              showChevron: false })
          }
        }
      }
    }
  }
}
