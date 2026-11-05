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
import { SyncMergeChoice, SyncMergeConflict, SyncPreview, SyncPreviewEffect, SyncPreviewGroup,
  SyncReadingDecision } from '../deviceSync/DeviceSyncEngine'
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
  if (state.requiresExplicitReview) return t('device_sync_review_required')
  if (state.error.length > 0) return t('device_sync_needs_attention')
  if (state.needsReview) return t('device_sync_differences_pending')
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
  if (parts[0] === 'bookmark') return t('chapter_bookmarks')
  if (parts[0] === 'category') return t('library_category_name_label')
  return t(groupKey(conflict.group))
}

function localChoiceTitle(conflict: SyncMergeConflict): string {
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
  @Trace reviewing: boolean = false
  @Trace cancelReviewSeq: number = 0

  back(busy: boolean): boolean {
    if (!this.reviewing) return false
    if (!busy) this.cancelReviewSeq++
    return true
  }
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
        GroupedListSection({ title: t('device_sync_contents'), subtitle: t('device_sync_supported_sources') }) {
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
                  isEnabled: !this.state.busy && !this.state.requiresExplicitReview, action: (): void => {
                    void appDeviceSync.chooseReadingDecision(item.key, value).catch((): void => {})
                  } })
              }, (value: string): string => value)
              ListDivider()
            }, (item: SyncReadingDecision): string => item.key)
            ForEach(this.state.blockedReadings, (item: SyncBlockedReading) => {
              ConciseListRow({ title: item.title || t('device_sync_group_reading'),
                subtitle: t('device_sync_reading_retained').replace('%s', (item.capture.page + 1).toString()),
                isEnabled: !this.state.busy && !this.state.requiresExplicitReview, action: (): void => {
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
  @Param chrome: DeviceSyncWebDavChrome = new DeviceSyncWebDavChrome()
  @Local private state: DeviceSyncViewState = appDeviceSync.view
  @Local private editing: boolean = false
  @Local private tested: boolean = false
  @Local private testingDraft: boolean = false
  @Local private draftError: string = ''
  @Local private directory: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private preview?: SyncPreview
  @Local private choices: SyncMergeChoice[] = []
  private visible: boolean = false

  @Monitor('chrome.confirm.requestSeq')
  private requestMerge(): void {
    if (this.visible && !this.state.busy) void this.commit()
  }

  @Monitor('chrome.cancelReviewSeq')
  private cancelReview(): void {
    this.discard()
    this.chrome.scroller.scrollEdge(Edge.Top)
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
    this.chrome.confirm.enabled = false
    this.chrome.reviewing = false
  }

  private edit(): void {
    this.discard()
    this.tested = false
    this.draftError = ''
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
    this.draftError = ''
    this.discard()
  }

  private isDraft(): boolean {
    const proposed = this.proposedSelection
    return this.editing || (proposed.length > 0 && (proposed.length !== this.state.selected.length ||
      proposed.some((group: SyncGroup): boolean => !this.state.selected.includes(group))))
  }

  private statusTitle(): string {
    if (!this.isDraft()) return stateText(this.state)
    if (!this.editing) return t('device_sync_scope_not_applied')
    // The active connection can keep syncing while the draft points elsewhere.
    if (this.testingDraft) return t('device_sync_testing_draft')
    if (this.draftError !== '') return t('device_sync_needs_attention')
    return t(this.state.connected ? 'device_sync_draft_not_applied' : 'device_sync_disconnected')
  }

  private async previewSaved(): Promise<void> {
    if (this.isDraft()) this.draftError = ''
    try {
      const draft = await appDeviceSync.draft()
      if (draft !== undefined) await this.makePreview(draft)
    } catch (error) {
      if (this.isDraft()) this.draftError = (error as Error).message
    }
  }

  private async makePreview(draft: SyncConnectionDraft): Promise<void> {
    const result = await appDeviceSync.prepare(draft, this.groups(), !this.isDraft())
    if (!this.visible) {
      appDeviceSync.discard(result.token)
      return
    }
    this.choices = []
    this.getUIContext().getFocusController().clearFocus()
    this.preview = result
    this.chrome.reviewing = true
    this.chrome.confirm.enabled = true
    this.chrome.scroller.scrollEdge(Edge.Top)
  }

  private async testConnection(): Promise<void> {
    const draft: SyncConnectionDraft = { directory: this.directory, username: this.username, password: this.password }
    this.discard()
    this.tested = false
    this.draftError = ''
    this.testingDraft = true
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
    } catch (error) {
      this.draftError = (error as Error).message
    } finally {
      this.testingDraft = false
    }
  }

  private choice(conflict: SyncMergeConflict): SyncMergeChoice | undefined {
    return this.choices.find((item: SyncMergeChoice): boolean => item.group === conflict.group && item.key === conflict.key)
  }

  private choose(conflict: SyncMergeConflict, useLocal?: boolean, useBeforeRestore: boolean = false): void {
    const choices = this.choices.filter((choice: SyncMergeChoice): boolean => choice.group !== conflict.group || choice.key !== conflict.key)
    this.choices = useLocal === undefined ? choices :
      choices.concat({ group: conflict.group, key: conflict.key, useLocal, useBeforeRestore })
  }

  private choiceLabel(conflict: SyncMergeConflict): string {
    const current = this.choice(conflict)
    if (current?.useBeforeRestore) return t('device_sync_before_restore_short')
    if (current?.useLocal === true) return conflict.deleted ? localChoiceTitle(conflict) : t('device_sync_this_device')
    if (conflict.deleted) return t('device_sync_apply_removal')
    return t(current === undefined ? 'device_sync_defer' : 'device_sync_other_device')
  }

  private summary(preview: SyncPreview, group: SyncPreviewGroup): string {
    let upload = group.upload
    let download = group.download
    let remove = group.remove
    let deferred = 0
    preview.conflicts.forEach((item: SyncMergeConflict): void => {
      if (item.group !== group.group) return
      const selected = this.choice(item)
      if (selected?.useLocal) upload++
      else if (item.deleted) remove++
      else if (selected !== undefined) download++
      else deferred++
    })
    group.dependent.forEach((effect: SyncPreviewEffect): void => {
      if (!effect.choices.every((key: string): boolean => this.choices.some((choice: SyncMergeChoice): boolean =>
        choice.group === group.group && choice.key === key))) return
      if (effect.action === 'upload') upload++
      else if (effect.action === 'download') download++
      else remove++
    })
    const parts: string[] = []
    if (upload > 0) parts.push(t('device_sync_summary_upload').replace('%s', upload.toString()))
    if (download > 0) parts.push(t('device_sync_summary_download').replace('%s', download.toString()))
    if (remove > 0) parts.push(t('device_sync_summary_remove').replace('%s', remove.toString()))
    if (deferred > 0) parts.push(t('device_sync_summary_defer').replace('%s', deferred.toString()))
    if (group.skipped > 0) parts.push(t('device_sync_summary_skip').replace('%s', group.skipped.toString()))
    return parts.length === 0 ? t('device_sync_summary_empty') : parts.join(' · ')
  }

  private async commit(): Promise<void> {
    const preview = this.preview
    if (preview === undefined) return
    try {
      await appDeviceSync.confirm(preview.token, this.choices, !this.isDraft())
      this.editing = false
      this.tested = false
      this.password = ''
    } catch (error) {
      if (this.isDraft()) this.draftError = (error as Error).message
    } finally {
      this.discard()
      this.chrome.scroller.scrollEdge(Edge.Top)
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
          this.draftError = ''
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
  private ChoiceItem(title: string, checked: boolean, select: (action: () => void) => void, action: () => void) {
    MenuItem({ content: title })
      .selected(checked)
      .selectIcon(true)
      .onClick((): void => { select(action) })
  }

  @Builder
  private ConflictMenu(item: SyncMergeConflict, select: (action: () => void) => void) {
    Menu() {
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

  @Builder
  private Review(preview: SyncPreview) {
    ListItem() {
      GroupedListSection({ title: t('device_sync_review_contents'),
        subtitle: preview.groups.some((row: SyncPreviewGroup): boolean => row.skipped > 0) ? t('device_sync_skipped_detail') : undefined }) {
        ForEach(preview.groups, (row: SyncPreviewGroup, index: number) => {
          if (index > 0) ListDivider()
          ConciseListRow({ title: t(groupKey(row.group)), showChevron: false, subtitle: this.summary(preview, row) })
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
    if (preview.conflicts.length > 0) {
      ListItem() {
        GroupedListSection({ title: t('device_sync_review_differences'), subtitle: t('device_sync_review_differences_detail') }) {
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
        GroupedListSection({ title: t('device_sync_before_restore'), subtitle: t('device_sync_review_restore_detail') }) {
          ForEach(preview.beforeRestore, (item: SyncMergeConflict, index: number) => {
            if (index > 0) ListDivider()
            ConciseListRow({ title: conflictValue(item.key, item.local), wrapTitle: true,
              subtitle: t('device_sync_current_value') + ' · ' + conflictValue(item.key, item.remote),
              hasSwitch: true, showChevron: false, isEnabled: !this.state.busy,
              checked: this.choice(item)?.useBeforeRestore === true,
              switchAction: (checked: boolean): void => { this.choose(item, checked ? true : undefined, true) } })
          }, (item: SyncMergeConflict): string => item.group + item.key)
        }
      }
    }
  }

  @Builder
  private Run() {
    GroupedListSection({ title: t('device_sync_run') }) {
      ConciseListRow({ title: t('device_sync_auto'), hasSwitch: true, checked: this.state.automatic,
        showChevron: false, isEnabled: !this.state.busy && !this.state.requiresExplicitReview,
        switchAction: (value: boolean): void => {
          if (value !== this.state.automatic) appDeviceSync.setAutomatic(value)
        } })
      if (!this.state.requiresExplicitReview) {
        ListDivider()
        ConciseListRow({ title: t('device_sync_now'),
          subtitle: this.state.selected.length === 0 ? t('device_sync_no_selection') : '',
          isEnabled: !this.state.busy && this.state.selected.length > 0,
          action: (): void => { void appDeviceSync.sync().catch((): void => {}) } })
      }
      if (this.state.needsReview || this.proposedSelection.length > 0) {
        ListDivider()
        ConciseListRow({ title: t(this.state.requiresExplicitReview ? 'device_sync_preview' : 'device_sync_review_differences'),
          isEnabled: !this.state.busy, action: (): void => { void this.previewSaved() } })
      }
    }
  }

  build() {
    SecondaryListScaffold({ scroller: this.chrome.scroller, bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.preview !== undefined) {
        this.Review(this.preview)
      } else {
        ListItem() { this.Connection() }
        if (this.state.connected && !this.editing) {
          ListItem() { this.Run() }
        }
        ListItem() {
          GroupedListSection({ title: t('device_sync_status') }) {
            ConciseListRow({ title: this.statusTitle(), subtitle: errorText(this.isDraft() ? this.draftError : this.state.error),
              showChevron: false })
            if (!this.isDraft() && this.state.lastSuccess > 0) {
              ListDivider()
              ConciseListRow({ title: t('device_sync_last_success'), subtitle: new Date(this.state.lastSuccess).toLocaleString(),
                showChevron: false })
            }
          }
        }
      }
    }
  }
}
