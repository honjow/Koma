import { common } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import {
  AssetStoreTrackerCredentialSecretStore,
  ComicTrackerMapping,
  DEFAULT_TRACKER_ACCOUNTS,
  TrackerComicMappingSummary,
  TRACKER_PROVIDER_CONFIGS,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerOAuthStartPreparation,
  TrackerPreferencesStore,
  TrackerProviderConfig,
  TrackerProviderId,
  TrackerProviderOAuthConfig,
  getConfiguredTrackerProviderConfig,
  getTrackerAccountDetail,
  getTrackerAccountStatusLabel,
  getTrackerProviderOAuthConfig,
  summarizeComicTrackerMappings,
} from '../model/TrackerModels'
import {
  summarizeTrackerPendingProgress,
  TrackerPendingProgressSummary,
  TrackerPendingSyncStore,
} from '../model/TrackerPendingSyncStore'
import {
  TrackerPendingProgressDrainSummary,
  TrackerProgressSyncService,
} from '../model/TrackerProgressSyncService'
import {
  TrackerAccountRefreshService,
  TrackerAccountRefreshSummary,
} from '../model/TrackerAccountRefreshService'
import {
  TrackerOAuthCompletionReason,
  TrackerOAuthCompletionService,
} from '../model/TrackerOAuthCompletionService'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct TrackerSettingsPage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private accounts: TrackerAccount[] = DEFAULT_TRACKER_ACCOUNTS
  @Local private providerOAuthConfigs: TrackerProviderOAuthConfig[] = []
  @Local private mappingSummary: TrackerComicMappingSummary = {
    total: 0,
    confirmed: 0,
    candidate: 0,
    stale: 0,
    rejected: 0,
    unmapped: 0,
  }
  @Local private mappings: ComicTrackerMapping[] = []
  @Local private pendingSummary: TrackerPendingProgressSummary = {
    totalCount: 0,
    anilistCount: 0,
    myAnimeListCount: 0,
    completedCount: 0,
    failedAttemptCount: 0,
  }
  @Local private busyMappingKey: string = ''
  @Local private busyProviderId: string = ''
  @Local private refreshingProviderId: string = ''
  @Local private pendingRetryBusy: boolean = false
  @Local private pendingClearBusy: boolean = false
  @Local private secureStorageAvailable: boolean = false
  @Local private authPreparationMessageKey: string = 'tracker_message_secure_storage_unverified'
  @Local private preparedAuthorizationUrl: string = ''
  @Local private oauthCallbackUris: Record<string, string> = {}
  @Local private completingProviderId: string = ''
  private credentialSecretStore: TrackerCredentialSecretStore = new AssetStoreTrackerCredentialSecretStore()

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private trackerPreferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context(), this.credentialSecretStore)
  }

  private pendingSyncStore(): TrackerPendingSyncStore {
    return new TrackerPendingSyncStore(this.context())
  }

  aboutToAppear(): void {
    this.secureStorageAvailable = this.credentialSecretStore.isAvailable()
    void this.trackerPreferencesStore().load()
      .then((preferences) => {
        this.accounts = preferences.accounts
        this.providerOAuthConfigs = preferences.providerOAuthConfigs
        this.mappings = preferences.comicMappings
        this.mappingSummary = summarizeComicTrackerMappings(preferences.comicMappings)
        console.info('[TrackerSettings] step=load accounts=' + preferences.accounts.length + ' mappings=' + preferences.comicMappings.length)
      })
      .catch((_error: Error) => {
        this.authPreparationMessageKey = 'tracker_message_load_failed'
        console.warn('[TrackerSettings] step=load_failed reason=redacted')
      })
    this.loadPendingProgressSummary()
  }

  private findAccount(provider: TrackerProviderConfig): TrackerAccount {
    const account = this.accounts.find((item: TrackerAccount): boolean => {
      return item.providerId === provider.providerId
    })
    if (account !== undefined) {
      return account
    }
    return {
      providerId: provider.providerId,
      status: 'disconnected',
    }
  }

  private providerDisplayName(providerId: string): string {
    const provider = TRACKER_PROVIDER_CONFIGS.find((item: TrackerProviderConfig): boolean => item.providerId === providerId)
    return provider?.displayName ?? providerId
  }

  private configuredProvider(provider: TrackerProviderConfig): TrackerProviderConfig {
    return getConfiguredTrackerProviderConfig(provider.providerId, this.providerOAuthConfigs) ?? provider
  }

  private providerOAuthConfig(provider: TrackerProviderConfig): TrackerProviderOAuthConfig | undefined {
    return getTrackerProviderOAuthConfig(provider.providerId, this.providerOAuthConfigs)
  }

  private providerClientId(provider: TrackerProviderConfig): string {
    return this.providerOAuthConfig(provider)?.clientId ?? ''
  }

  private providerRedirectUri(provider: TrackerProviderConfig): string {
    return this.providerOAuthConfig(provider)?.redirectUri ?? ''
  }

  private setProviderClientId(provider: TrackerProviderConfig, value: string): void {
    this.upsertProviderOAuthConfig(provider, value, this.providerRedirectUri(provider))
  }

  private setProviderRedirectUri(provider: TrackerProviderConfig, value: string): void {
    this.upsertProviderOAuthConfig(provider, this.providerClientId(provider), value)
  }

  private providerOAuthCallbackUri(provider: TrackerProviderConfig): string {
    return this.oauthCallbackUris[provider.providerId] ?? ''
  }

  private setProviderOAuthCallbackUri(provider: TrackerProviderConfig, value: string): void {
    const next: Record<string, string> = {}
    Object.keys(this.oauthCallbackUris).forEach((key: string) => {
      next[key] = this.oauthCallbackUris[key]
    })
    next[provider.providerId] = value
    this.oauthCallbackUris = next
  }

  private upsertProviderOAuthConfig(provider: TrackerProviderConfig, clientId: string, redirectUri: string): void {
    const next = this.providerOAuthConfigs.filter((config: TrackerProviderOAuthConfig): boolean => {
      return config.providerId !== provider.providerId
    })
    next.push({ providerId: provider.providerId, clientId, redirectUri })
    this.providerOAuthConfigs = next
    this.preparedAuthorizationUrl = ''
  }

  private connectActionLabel(provider: TrackerProviderConfig): string {
    const configuredProvider = this.configuredProvider(provider)
    if (provider.supportStatus === 'unsupported') {
      return s('tracker_action_unsupported')
    }
    if (provider.supportStatus === 'planned') {
      return s('tracker_action_planned')
    }
    if (!this.secureStorageAvailable) {
      return s('tracker_action_secure_storage_unavailable')
    }
    if (configuredProvider.clientId === undefined || configuredProvider.redirectUri === undefined) {
      return s('tracker_action_needs_config')
    }
    return s('tracker_action_connect')
  }

  private canPrepareConnect(provider: TrackerProviderConfig): boolean {
    const configuredProvider = this.configuredProvider(provider)
    return provider.supportStatus === 'available' &&
      this.secureStorageAvailable &&
      configuredProvider.clientId !== undefined &&
      configuredProvider.redirectUri !== undefined
  }

  private canDisconnectProvider(provider: TrackerProviderConfig): boolean {
    const account = this.findAccount(provider)
    return account.status !== 'disconnected' &&
      (account.credentialAccountKey === undefined || this.secureStorageAvailable)
  }

  private canRefreshProvider(provider: TrackerProviderConfig): boolean {
    const account = this.findAccount(provider)
    return this.secureStorageAvailable &&
      this.refreshingProviderId.length === 0 &&
      provider.supportStatus === 'available' &&
      (provider.providerId === 'anilist' || provider.providerId === 'myanimelist') &&
      account.credentialAccountKey !== undefined
  }

  private canCompleteOAuthCallback(provider: TrackerProviderConfig): boolean {
    const account = this.findAccount(provider)
    return this.secureStorageAvailable &&
      this.completingProviderId.length === 0 &&
      account.status === 'auth_pending' &&
      account.credentialAccountKey !== undefined &&
      this.providerOAuthCallbackUri(provider).trim().length > 0
  }

  private confirmDisconnectAccount(provider: TrackerProviderConfig): void {
    if (!this.canDisconnectProvider(provider) || this.busyProviderId.length > 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('tracker_disconnect_confirm_title'),
      message: AppStrings.format('tracker_disconnect_confirm_message', provider.displayName),
      autoCancel: true,
      primaryButton: {
        value: s('tracker_action_disconnect'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.disconnectAccount(provider)
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private prepareConnect(provider: TrackerProviderConfig): void {
    if (!this.canPrepareConnect(provider)) {
      this.preparedAuthorizationUrl = ''
      this.authPreparationMessageKey = !this.secureStorageAvailable
        ? 'tracker_message_connect_unavailable'
        : 'tracker_message_auth_unavailable'
      this.showToast(s(this.authPreparationMessageKey))
      return
    }
    void this.saveProviderOAuthConfig(provider, false)
      .then((saved: boolean) => {
        if (!saved) {
          this.preparedAuthorizationUrl = ''
          this.authPreparationMessageKey = 'tracker_message_auth_prepare_failed'
          this.showToast(s(this.authPreparationMessageKey))
          return undefined
        }
        return this.trackerPreferencesStore().prepareConnect(provider.providerId)
      })
      .then((result: TrackerOAuthStartPreparation | undefined) => {
        if (result === undefined) {
          return
        }
        this.preparedAuthorizationUrl = result.status === 'ready'
          ? result.authorizationUrl ?? ''
          : ''
        this.authPreparationMessageKey = result.status === 'ready'
          ? 'tracker_message_auth_ready'
          : this.authPrepareStatusKey(result.status)
        this.showToast(s(this.authPreparationMessageKey))
      })
      .catch((_error: Error) => {
        this.preparedAuthorizationUrl = ''
        this.authPreparationMessageKey = 'tracker_message_auth_prepare_failed'
        this.showToast(s(this.authPreparationMessageKey))
      })
  }

  private async saveProviderOAuthConfig(provider: TrackerProviderConfig, showSuccessToast: boolean = true): Promise<boolean> {
    try {
      const preferences = await this.trackerPreferencesStore().saveProviderOAuthConfig(
        provider.providerId,
        this.providerClientId(provider),
        this.providerRedirectUri(provider),
      )
      this.providerOAuthConfigs = preferences.providerOAuthConfigs
      if (showSuccessToast) {
        this.showToast(s('tracker_oauth_config_saved'))
      }
      return true
    } catch (_error) {
      this.showToast(s('tracker_oauth_config_save_failed'))
      return false
    }
  }

  private disconnectAccount(provider: TrackerProviderConfig): void {
    if (!this.canDisconnectProvider(provider) || this.busyProviderId.length > 0) {
      return
    }
    this.busyProviderId = provider.providerId
    void this.trackerPreferencesStore().disconnectAccount(provider.providerId)
      .then(async (preferences) => {
        this.accounts = preferences.accounts
        this.providerOAuthConfigs = preferences.providerOAuthConfigs
        const account = this.findAccount(provider)
        if (account.status === 'disconnected') {
          await this.pendingSyncStore().removeProgressForProvider(provider.providerId)
          this.loadPendingProgressSummary()
          this.showToast(s('tracker_message_disconnected'))
        } else {
          this.showToast(s('tracker_message_disconnect_failed'))
        }
      })
      .catch((_error: Error) => {
        this.showToast(s('tracker_message_disconnect_failed'))
      })
      .finally(() => {
        this.busyProviderId = ''
      })
  }

  private refreshAccount(provider: TrackerProviderConfig): void {
    if (!this.canRefreshProvider(provider)) {
      this.showToast(s('tracker_refresh_unavailable'))
      return
    }
    this.refreshingProviderId = provider.providerId
    void new TrackerAccountRefreshService(this.context(), {
      secretStore: this.credentialSecretStore,
    }).refreshAccounts(provider.providerId)
      .then((summary: TrackerAccountRefreshSummary) => {
        this.accounts = summary.preferences.accounts
        this.providerOAuthConfigs = summary.preferences.providerOAuthConfigs
        this.mappings = summary.preferences.comicMappings
        this.mappingSummary = summarizeComicTrackerMappings(summary.preferences.comicMappings)
        console.info(`[TrackerSettings] step=account_refresh provider=${provider.providerId} refreshed=${summary.refreshedCount} skipped=${summary.skippedCount} failed=${summary.failedCount}`)
        if (summary.refreshedCount > 0) {
          this.showToast(s('tracker_refresh_done'))
        } else if (summary.failedCount > 0) {
          this.showToast(s('tracker_refresh_failed'))
        } else {
          this.showToast(s('tracker_refresh_unavailable'))
        }
      })
      .catch((_error: Error) => {
        console.warn('[TrackerSettings] step=account_refresh_failed reason=redacted')
        this.showToast(s('tracker_refresh_failed'))
      })
      .finally(() => {
        this.refreshingProviderId = ''
      })
  }

  private completeOAuthCallback(provider: TrackerProviderConfig): void {
    if (!this.canCompleteOAuthCallback(provider)) {
      this.showToast(s('tracker_callback_unavailable'))
      return
    }
    this.completingProviderId = provider.providerId
    void new TrackerOAuthCompletionService(this.context(), {
      secretStore: this.credentialSecretStore,
    }).completeCallback(provider.providerId as TrackerProviderId, this.providerOAuthCallbackUri(provider).trim())
      .then((result) => {
        this.accounts = result.preferences.accounts
        this.providerOAuthConfigs = result.preferences.providerOAuthConfigs
        this.mappings = result.preferences.comicMappings
        this.mappingSummary = summarizeComicTrackerMappings(result.preferences.comicMappings)
        if (result.status === 'connected') {
          this.preparedAuthorizationUrl = ''
          this.setProviderOAuthCallbackUri(provider, '')
          this.showToast(s('tracker_callback_connected'))
        } else {
          this.showToast(s(this.oauthCompletionReasonKey(result.reason)))
        }
      })
      .catch((_error: Error) => {
        this.showToast(s('tracker_callback_failed'))
      })
      .finally(() => {
        this.completingProviderId = ''
      })
  }

  private oauthCompletionReasonKey(reason: TrackerOAuthCompletionReason | undefined): string {
    if (reason === 'account_missing') {
      return 'tracker_callback_account_missing'
    }
    if (reason === 'invalid_callback' || reason === 'state_mismatch' ||
      reason === 'provider_error' || reason === 'missing_code') {
      return 'tracker_callback_invalid'
    }
    if (reason === 'provider_config_missing' || reason === 'verifier_missing') {
      return 'tracker_callback_unavailable'
    }
    if (reason === 'credential_store_failed') {
      return 'tracker_callback_storage_failed'
    }
    return 'tracker_callback_failed'
  }

  private authPrepareStatusKey(status: string): string {
    if (status === 'secure_storage_unavailable') {
      return 'tracker_message_connect_unavailable'
    }
    if (status === 'provider_config_missing') {
      return 'tracker_message_auth_unavailable'
    }
    if (status === 'provider_unsupported') {
      return 'tracker_message_provider_unsupported'
    }
    if (status === 'pkce_unavailable') {
      return 'tracker_message_auth_unavailable'
    }
    return 'tracker_message_auth_prepare_failed'
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private copyPreparedAuthorizationUrl(): void {
    if (this.preparedAuthorizationUrl.length === 0) {
      return
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.preparedAuthorizationUrl)
    void pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.showToast(s('tracker_auth_url_copied'))
      })
      .catch((_error: Error) => {
        this.showToast(s('tracker_auth_url_copy_failed'))
      })
  }

  private loadPendingProgressSummary(): void {
    void this.pendingSyncStore().loadPendingProgress()
      .then((entries) => {
        this.pendingSummary = summarizeTrackerPendingProgress(entries)
        console.info('[TrackerSync] step=settings_pending_loaded total=' + this.pendingSummary.totalCount)
      })
      .catch((_error: Error) => {
        this.pendingSummary = summarizeTrackerPendingProgress([])
        console.warn('[TrackerSync] step=settings_pending_load_failed reason=redacted')
      })
  }

  private pendingProgressText(): string {
    if (this.pendingSummary.totalCount === 0) {
      return s('tracker_pending_empty')
    }
    return s('tracker_pending_summary')
      .replace('%s', `${this.pendingSummary.totalCount}`)
      .replace('%s', `${this.pendingSummary.completedCount}`)
      .replace('%s', `${this.pendingSummary.failedAttemptCount}`)
  }

  private retryPendingProgressNow(): void {
    if (this.pendingRetryBusy || this.pendingClearBusy || this.pendingSummary.totalCount === 0) {
      return
    }
    this.pendingRetryBusy = true
    void new TrackerProgressSyncService(this.context()).retryPendingProgress(20, Date.now(), true)
      .then((summary: TrackerPendingProgressDrainSummary) => {
        console.info(`[TrackerSync] step=settings_pending_retry scanned=${summary.scannedCount} synced=${summary.syncedCount} retained=${summary.retainedCount} failed=${summary.failedCount} skipped=${summary.skippedCount}`)
        this.showToast(s('tracker_pending_retry_done')
          .replace('%s', `${summary.syncedCount}`)
          .replace('%s', `${summary.retainedCount}`))
        this.loadPendingProgressSummary()
      })
      .catch((_error: Error) => {
        console.warn('[TrackerSync] step=settings_pending_retry_failed reason=redacted')
        this.showToast(s('tracker_pending_retry_failed'))
      })
      .finally(() => {
        this.pendingRetryBusy = false
      })
  }

  private confirmClearPendingProgress(): void {
    if (this.pendingClearBusy || this.pendingRetryBusy || this.pendingSummary.totalCount === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('tracker_pending_clear_confirm_title'),
      message: s('tracker_pending_clear_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearPendingProgressNow()
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private clearPendingProgressNow(): void {
    if (this.pendingClearBusy || this.pendingRetryBusy || this.pendingSummary.totalCount === 0) {
      return
    }
    this.pendingClearBusy = true
    void this.pendingSyncStore().clear()
      .then(() => {
        console.info('[TrackerSync] step=settings_pending_clear cleared=true')
        this.showToast(s('tracker_pending_clear_done'))
        this.loadPendingProgressSummary()
      })
      .catch((_error: Error) => {
        console.warn('[TrackerSync] step=settings_pending_clear_failed reason=redacted')
        this.showToast(s('tracker_pending_clear_failed'))
      })
      .finally(() => {
        this.pendingClearBusy = false
      })
  }

  private mappingProgressText(): string {
    return s('tracker_mapping_progress')
      .replace('%s', `${this.mappingSummary.total}`)
      .replace('%s', `${this.mappingSummary.confirmed}`)
      .replace('%s', `${this.mappingSummary.candidate}`)
      .replace('%s', `${this.mappingSummary.stale + this.mappingSummary.rejected}`)
  }

  private mappingKey(mapping: ComicTrackerMapping): string {
    return `${mapping.comicId}:${mapping.providerId}`
  }

  private mappingTitle(mapping: ComicTrackerMapping): string {
    if (mapping.providerTitle !== undefined && mapping.providerTitle.length > 0) {
      return mapping.providerTitle
    }
    return mapping.providerTitleId
  }

  private mappingStatusLabel(mapping: ComicTrackerMapping): string {
    if (mapping.mappingState === 'confirmed') {
      return s('tracker_mapping_status_confirmed')
    }
    if (mapping.mappingState === 'candidate') {
      return s('tracker_mapping_status_candidate')
    }
    if (mapping.mappingState === 'stale') {
      return s('tracker_mapping_status_stale')
    }
    if (mapping.mappingState === 'rejected') {
      return s('tracker_mapping_status_rejected')
    }
    return s('tracker_mapping_status_unmapped')
  }

  private mappingSubtitle(mapping: ComicTrackerMapping): string {
    const confidence = mapping.confidence === undefined
      ? ''
      : ` · ${Math.round(mapping.confidence * 100)}%`
    return `${this.providerDisplayName(mapping.providerId)} · ${this.mappingStatusLabel(mapping)}${confidence}`
  }

  private canReviewMapping(mapping: ComicTrackerMapping): boolean {
    return mapping.mappingState === 'candidate' || mapping.mappingState === 'stale'
  }

  private updateMappingReview(mapping: ComicTrackerMapping, confirmed: boolean): void {
    if (!this.canReviewMapping(mapping) || this.busyMappingKey.length > 0) {
      return
    }
    this.busyMappingKey = this.mappingKey(mapping)
    const store = this.trackerPreferencesStore()
    const task = confirmed
      ? store.confirmComicMapping(mapping.comicId, mapping.providerId)
      : store.rejectComicMapping(mapping.comicId, mapping.providerId)
    void task
      .then((preferences) => {
        this.accounts = preferences.accounts
        this.providerOAuthConfigs = preferences.providerOAuthConfigs
        this.mappings = preferences.comicMappings
        this.mappingSummary = summarizeComicTrackerMappings(preferences.comicMappings)
        this.showToast(s(confirmed ? 'tracker_mapping_confirmed' : 'tracker_mapping_rejected'))
      })
      .catch((_error: Error) => {
        this.showToast(s('tracker_mapping_update_failed'))
      })
      .finally(() => {
        this.busyMappingKey = ''
      })
  }

  @Builder
  private StatusCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(s('tracker_status_title'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(s('tracker_status_message'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(s(this.authPreparationMessageKey))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      if (this.preparedAuthorizationUrl.length > 0) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Text(s('tracker_auth_url_ready_detail'))
            .layoutWeight(1)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
          KomaActionButton({
            label: s('tracker_auth_url_copy'),
            kind: 'secondary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.copyPreparedAuthorizationUrl()
            },
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private ProviderRow(provider: TrackerProviderConfig) {
    ConciseListRow({
      title: provider.displayName,
      subtitle: getTrackerAccountDetail(this.findAccount(provider), this.secureStorageAvailable),
      showChevron: false,
      suffixPaddingRight: 0,
      suffixBuilderParam: () => {
        this.ProviderSuffix(provider)
      },
      action: () => {
        this.prepareConnect(provider)
      },
    })
  }

  @Builder
  private ProviderSuffix(provider: TrackerProviderConfig) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Text(getTrackerAccountStatusLabel(this.findAccount(provider).status))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.canDisconnectProvider(provider)) {
        KomaActionButton({
          label: this.refreshingProviderId === provider.providerId ? s('common_checking') : s('tracker_action_refresh'),
          kind: 'secondary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.canRefreshProvider(provider),
          action: () => {
            this.refreshAccount(provider)
          },
        })
        KomaActionButton({
          label: s('tracker_action_disconnect'),
          kind: 'danger',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.busyProviderId.length === 0,
          action: () => {
            this.confirmDisconnectAccount(provider)
          },
        })
      } else {
        KomaActionButton({
          label: this.connectActionLabel(provider),
          kind: this.canPrepareConnect(provider) ? 'primary' : 'secondary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.canPrepareConnect(provider),
          accentColor: this.canPrepareConnect(provider) ? undefined : ThemeConstants.TEXT_SECONDARY,
          action: () => {
            this.prepareConnect(provider)
          },
        })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ProviderOAuthConfigForm(provider: TrackerProviderConfig) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(s('tracker_oauth_config_title'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      KomaFormTextField({
        label: s('tracker_oauth_client_id_label'),
        placeholder: s('tracker_oauth_client_id_placeholder'),
        value: this.providerClientId(provider),
        change: (value: string) => {
          this.setProviderClientId(provider, value)
        },
      })
      KomaFormTextField({
        label: s('tracker_oauth_redirect_uri_label'),
        placeholder: s('tracker_oauth_redirect_uri_placeholder'),
        value: this.providerRedirectUri(provider),
        change: (value: string) => {
          this.setProviderRedirectUri(provider, value)
        },
      })
      Row() {
        Blank()
        KomaActionButton({
          label: s('common_save'),
          kind: 'secondary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            void this.saveProviderOAuthConfig(provider)
          },
        })
      }
      .width('100%')

      if (this.findAccount(provider).status === 'auth_pending') {
        KomaFormTextField({
          label: s('tracker_callback_uri_label'),
          placeholder: s('tracker_callback_uri_placeholder'),
          value: this.providerOAuthCallbackUri(provider),
          change: (value: string) => {
            this.setProviderOAuthCallbackUri(provider, value)
          },
        })
        Row() {
          Blank()
          KomaActionButton({
            label: this.completingProviderId === provider.providerId ? s('common_checking') : s('tracker_callback_complete'),
            kind: 'primary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: this.canCompleteOAuthCallback(provider),
            action: () => {
              this.completeOAuthCallback(provider)
            },
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_MD })
  }

  @Builder
  private ProvidersCard() {
    Column() {
      ForEach(TRACKER_PROVIDER_CONFIGS, (provider: TrackerProviderConfig, index: number) => {
        this.ProviderRow(provider)
        if (provider.supportStatus === 'available') {
          this.ProviderOAuthConfigForm(provider)
        }
        if (index < TRACKER_PROVIDER_CONFIGS.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color(ThemeConstants.DIVIDER)
            .margin({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
        }
      }, (provider: TrackerProviderConfig) => provider.providerId)
    }
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private PendingProgressCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(s('tracker_pending_title'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
          Text(s('tracker_pending_message'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Row({ space: ThemeConstants.SPACE_SM }) {
          KomaActionButton({
            label: this.pendingRetryBusy ? s('common_retrying') : s('common_retry'),
            kind: 'secondary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: this.pendingSummary.totalCount > 0 && !this.pendingRetryBusy && !this.pendingClearBusy,
            action: () => {
              this.retryPendingProgressNow()
            },
          })
          KomaActionButton({
            label: s('common_clear'),
            kind: 'danger',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: this.pendingSummary.totalCount > 0 && !this.pendingRetryBusy && !this.pendingClearBusy,
            action: () => {
              this.confirmClearPendingProgress()
            },
          })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      Text(this.pendingProgressText())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private MappingSummaryCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(s('tracker_mapping_title'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(s('tracker_mapping_message'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(this.mappingProgressText())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      if (this.mappings.length === 0) {
        Text(s('tracker_mapping_empty'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      } else {
        Column() {
          ForEach(this.mappings, (mapping: ComicTrackerMapping, index: number) => {
            this.MappingRow(mapping)
            if (index < this.mappings.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color(ThemeConstants.DIVIDER)
            }
          }, (mapping: ComicTrackerMapping) => this.mappingKey(mapping))
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private MappingRow(mapping: ComicTrackerMapping) {
    ConciseListRow({
      title: this.mappingTitle(mapping),
      subtitle: this.mappingSubtitle(mapping),
      showChevron: false,
      suffixPaddingRight: 0,
      suffixBuilderParam: () => {
        if (this.canReviewMapping(mapping)) {
          this.MappingReviewActions(mapping)
        }
      },
    })
  }

  @Builder
  private MappingReviewActions(mapping: ComicTrackerMapping) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      KomaActionButton({
        label: s('tracker_mapping_confirm'),
        kind: 'primary',
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        isEnabled: this.busyMappingKey.length === 0,
        action: () => {
          this.updateMappingReview(mapping, true)
        },
      })
      KomaActionButton({
        label: s('tracker_mapping_reject'),
        kind: 'secondary',
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        isEnabled: this.busyMappingKey.length === 0,
        action: () => {
          this.updateMappingReview(mapping, false)
        },
      })
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          this.StatusCard()
        }
        ListItem() {
          this.ProvidersCard()
        }
        ListItem() {
          this.PendingProgressCard()
        }
        ListItem() {
          this.MappingSummaryCard()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
