import { AdvancedDialogV2Button, ColorMetrics, CustomContentDialogV2 } from '@kit.ArkUI'
import { connectTrackerBrowserAuthorization, TrackerBrowserAuthorizationState } from '../state/TrackerBrowserAuthorizationState'
import { SettingsPage } from './SettingsPage'
import { TRACKER_BRAND_IMAGES } from '../components/TrackerBrandIcons'
import { komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { TrackerDirectConnectionService, DirectTrackerProviderId } from '../model/TrackerDirectConnectionService'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import {
  AssetStoreTrackerCredentialSecretStore,
  DEFAULT_TRACKER_ACCOUNTS,
  TRACKER_APP_CALLBACK_URI,
  TRACKER_PROVIDER_CONFIGS,
  TRACKER_REMOTE_PROVIDER_IDS,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferencesStore,
  TrackerPreferences,
  TrackerProviderConfig,
  TrackerProviderId,
  TrackerProviderOAuthConfig,
  getConfiguredTrackerProviderConfig,
  getTrackerAccountDetail,
  getTrackerAccountStatusLabel,
  getTrackerProviderOAuthConfig,
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
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct TrackerSettingsPage {
  @Param providerId: string = ''
  @Param searchTarget: string = ''
  @Param preferencesRestoreRevision: number = 0
  private settingsScroller: Scroller = new Scroller()
  @Param refreshRevision: number = 0
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private browserAuthorization: TrackerBrowserAuthorizationState = connectTrackerBrowserAuthorization()
  @Local private accounts: TrackerAccount[] = DEFAULT_TRACKER_ACCOUNTS
  @Local private providerOAuthConfigs: TrackerProviderOAuthConfig[] = []
  @Local private pendingSummary: TrackerPendingProgressSummary = {
    totalCount: 0,
    anilistCount: 0,
    myAnimeListCount: 0,
    completedCount: 0,
    failedAttemptCount: 0,
  }
  @Local private busyProviderId: string = ''
  @Local private refreshingProviderId: string = ''
  @Local private pendingRetryBusy: boolean = false
  @Local private pendingClearBusy: boolean = false
  @Local private secureStorageAvailable: boolean = false
  @Local private authPreparationMessageKey: string = 'tracker_message_loading'
  @Local private loading: boolean = true
  private loadInFlight: boolean = false
  private active: boolean = false
  @Local private preparedAuthorizationUrl: string = ''
  @Local private preparedAuthorizationProviderId: string = ''
  // Direct-login secrets live only in this form. The connection service puts the
  // verified token in AssetStore; neither password nor token enters preferences.
  @Local private directUsername: string = ''
  @Local private directSecret: string = ''
  private providerDialogId: number = -1
  private providerDialogShown: boolean = false
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
    this.active = true
    void this.reloadSettings()
  }

  aboutToDisappear(): void {
    this.active = false
    this.closeProviderDialog()
    this.clearDirectCredentials()
  }

  private clearDirectCredentials(): void {
    this.directUsername = ''
    this.directSecret = ''
  }

  private isDirectProvider(provider: TrackerProviderConfig): boolean {
    return provider.authentication === 'token' || provider.authentication === 'password'
  }

  @Monitor('refreshRevision')
  private onRefreshRevision(): void {
    if (this.providerId.length === 0) {
      void this.reloadSettings()
    }
  }

  @Monitor('browserAuthorization.revision')
  private onBrowserAuthorization(): void {
    const providerId = this.browserAuthorization.providerId
    if (this.providerId.length > 0 && this.providerId !== providerId) return
    if (this.preparedAuthorizationProviderId === providerId) {
      this.preparedAuthorizationUrl = ''
    }
    this.showToast(s(this.browserAuthorization.connected ? 'tracker_callback_connected' : 'tracker_callback_failed'))
    void this.reloadSettings()
  }

  private applyPreferences(preferences: TrackerPreferences): void {
    this.accounts = preferences.accounts
    this.providerOAuthConfigs = preferences.providerOAuthConfigs
  }

  private async reloadSettings(): Promise<void> {
    if (this.loadInFlight) {
      return
    }
    this.loadInFlight = true
    this.loading = true
    this.authPreparationMessageKey = 'tracker_message_loading'
    this.secureStorageAvailable = this.credentialSecretStore.isAvailable()
    try {
      const preferences = await this.trackerPreferencesStore().load()
      this.applyPreferences(preferences)
      this.authPreparationMessageKey = this.secureStorageAvailable ? '' : 'tracker_message_connect_unavailable'
      console.info('[TrackerSettings] step=load accounts=' + preferences.accounts.length + ' mappings=' + preferences.comicMappings.length)
    } catch (_error) {
      this.authPreparationMessageKey = 'tracker_message_load_failed'
      this.showToast(s(this.authPreparationMessageKey))
      DiagnosticLogger.warn('tracker_settings_page', 'load_failed', '[TrackerSettings] step=load_failed reason=redacted')
    } finally {
      this.loading = false
      this.loadInFlight = false
    }
    this.loadPendingProgressSummary()
  }

  private visibleProviders(): TrackerProviderConfig[] {
    return TRACKER_PROVIDER_CONFIGS.filter((provider: TrackerProviderConfig): boolean => {
      if (this.providerId.length > 0) {
        return provider.providerId === this.providerId
      }
      const account = this.findAccount(provider)
      return provider.supportStatus === 'available' || account.status !== 'disconnected' ||
        account.credentialAccountKey !== undefined || account.profile !== undefined ||
        account.connectedAt !== undefined || account.lastSyncAt !== undefined || account.statusReason !== undefined ||
        this.providerOAuthConfig(provider) !== undefined
    })
  }

  private providerAccountDetail(provider: TrackerProviderConfig): string {
    if (provider.supportStatus === 'unsupported') {
      return s('tracker_action_unsupported')
    }
    if (provider.supportStatus === 'planned') {
      return s('tracker_action_planned')
    }
    const account = this.findAccount(provider)
    return (account.status === 'disconnected' || account.status === 'auth_pending') && this.secureStorageAvailable ? '' :
      getTrackerAccountDetail(account, this.secureStorageAvailable)
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

  private canPrepareConnect(provider: TrackerProviderConfig): boolean {
    const configuredProvider = this.configuredProvider(provider)
    if (this.loading || this.busyProviderId.length > 0 || this.refreshingProviderId.length > 0 ||
      provider.supportStatus !== 'available' || !this.secureStorageAvailable) return false
    if (this.isDirectProvider(provider)) {
      return (provider.authentication === 'token' ? this.directSecret.trim().length : this.directSecret.length) > 0 &&
        (provider.authentication !== 'password' || this.directUsername.trim().length > 0)
    }
    return configuredProvider.clientId !== undefined && configuredProvider.redirectUri === TRACKER_APP_CALLBACK_URI &&
      (provider.providerId !== 'bangumi' || configuredProvider.clientSecret !== undefined)
  }

  private canDisconnectProvider(provider: TrackerProviderConfig): boolean {
    const account = this.findAccount(provider)
    // A pending browser session (or a failed first attempt) is not a linked account.
    return account.status !== 'disconnected' && account.status !== 'auth_pending' &&
      (account.status !== 'error' || this.isDirectProvider(provider) || account.connectedAt !== undefined) &&
      (account.credentialAccountKey === undefined || this.secureStorageAvailable)
  }

  private canRefreshProvider(provider: TrackerProviderConfig): boolean {
    const account = this.findAccount(provider)
    return this.secureStorageAvailable &&
      !this.loading && this.busyProviderId.length === 0 &&
      this.refreshingProviderId.length === 0 &&
      provider.supportStatus === 'available' &&
      TRACKER_REMOTE_PROVIDER_IDS.includes(provider.providerId) &&
      this.canDisconnectProvider(provider) &&
      account.credentialAccountKey !== undefined
  }

  private confirmDisconnectAccount(provider: TrackerProviderConfig): void {
    if (!this.canDisconnectProvider(provider) || this.busyProviderId.length > 0 || this.refreshingProviderId.length > 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: AppStrings.format('tracker_disconnect_confirm_title', provider.displayName),
      message: s('tracker_disconnect_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('tracker_action_disconnect'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.disconnectAccount(provider)
        },
      },
    })
  }

  private async connectDirectProvider(providerId: DirectTrackerProviderId, username: string, secret: string): Promise<void> {
    if (this.loading || this.busyProviderId.length > 0 || !this.secureStorageAvailable) return
    this.busyProviderId = providerId
    try {
      const result = await new TrackerDirectConnectionService(this.context()).connect(providerId, username, secret)
      if (result.preferences !== undefined) this.applyPreferences(result.preferences)
      if (result.ok) this.closeProviderDialog()
      this.showToast(s(result.ok ? 'tracker_callback_connected' : 'tracker_detail_connect_failed'))
    } catch (_) {
      this.showToast(s('tracker_detail_connect_failed'))
    } finally { this.busyProviderId = '' }
  }

  private prepareConnect(provider: TrackerProviderConfig): void {
    if ((this.providerId.length > 0 && provider.providerId !== this.providerId) || this.canDisconnectProvider(provider)) return
    if (this.isDirectProvider(provider)) {
      if (this.canPrepareConnect(provider)) {
        void this.connectDirectProvider(provider.providerId as DirectTrackerProviderId, this.directUsername, this.directSecret)
      }
      return
    }
    if (!this.canPrepareConnect(provider)) {
      this.preparedAuthorizationUrl = ''
      this.authPreparationMessageKey = !this.secureStorageAvailable
        ? 'tracker_message_connect_unavailable'
        : 'tracker_message_auth_unavailable'
      this.showToast(s(this.authPreparationMessageKey))
      return
    }
    // Retrying AniList after the browser stalls starts a new authorization session.
    if (provider.providerId !== 'anilist' && this.preparedAuthorizationUrl.length > 0 &&
      this.preparedAuthorizationProviderId === provider.providerId && this.findAccount(provider).status === 'auth_pending') {
      void this.openTrackerWebsite(this.preparedAuthorizationUrl)
      return
    }
    void this.startBrowserAuthorization(provider)
  }

  private async startBrowserAuthorization(provider: TrackerProviderConfig): Promise<void> {
    this.busyProviderId = provider.providerId
    try {
      const store = this.trackerPreferencesStore()
      const result = await store.prepareConnect(provider.providerId)
      if (result.status !== 'ready' || result.authorizationUrl === undefined) {
        DiagnosticLogger.warn('tracker', 'browser_prepare_failed',
          '[Tracker] provider=' + provider.providerId + ' status=' + result.status)
        this.authPreparationMessageKey = this.authPrepareStatusKey(result.status)
        this.showToast(s(this.authPreparationMessageKey))
        return
      }
      this.applyPreferences(await store.load())
      this.preparedAuthorizationProviderId = result.providerId
      this.preparedAuthorizationUrl = result.authorizationUrl
      this.authPreparationMessageKey = ''
      if (this.active && (this.providerId.length === 0 || this.providerId === result.providerId)) {
        await this.openTrackerWebsite(result.authorizationUrl)
      }
    } catch (_error) {
      DiagnosticLogger.warn('tracker', 'browser_prepare_failed',
        '[Tracker] provider=' + provider.providerId + ' status=unexpected_error')
      this.authPreparationMessageKey = 'tracker_message_auth_prepare_failed'
      this.showToast(s(this.authPreparationMessageKey))
    } finally {
      this.busyProviderId = ''
    }
  }

  private openProvider(provider: TrackerProviderConfig): void {
    if (this.loading || this.busyProviderId.length > 0 || this.providerDialogShown) return
    if (this.canDisconnectProvider(provider)) {
      this.confirmDisconnectAccount(provider)
    } else if (this.isDirectProvider(provider) && this.secureStorageAvailable && provider.supportStatus === 'available') {
      this.openProviderDialog(provider)
    } else {
      this.prepareConnect(provider)
    }
  }

  private openProviderDialog(provider: TrackerProviderConfig): void {
    this.clearDirectCredentials()
    this.providerDialogShown = true
    const prompt = this.getUIContext().getPromptAction()
    void prompt.openCustomDialog({
      systemMaterial: komaDialogMaterial(),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      builder: () => { this.ProviderDialog(provider) },
      onWillDismiss: (action: DismissDialogAction): void => {
        if (this.busyProviderId.length === 0 && this.refreshingProviderId.length === 0) action.dismiss()
      },
      onDidDisappear: (): void => {
        this.providerDialogId = -1
        this.providerDialogShown = false
        this.clearDirectCredentials()
      },
    }).then((id: number): void => {
      if (this.providerDialogShown && this.active) this.providerDialogId = id
      else prompt.closeCustomDialog(id)
    }).catch((): void => {
      this.providerDialogShown = false
      this.clearDirectCredentials()
    })
  }

  private closeProviderDialog(): void {
    this.clearDirectCredentials()
    this.providerDialogShown = false
    if (this.providerDialogId < 0) return
    const id = this.providerDialogId
    this.providerDialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  private async openTrackerWebsite(url: string): Promise<void> {
    try {
      await this.context().startAbility({ action: 'ohos.want.action.viewData', uri: url })
    } catch (_error) {
      this.showToast(s('tracker_browser_open_failed'))
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
        DiagnosticLogger.warn('tracker_settings_page', 'account_refresh_failed', '[TrackerSettings] step=account_refresh_failed reason=redacted')
        this.showToast(s('tracker_refresh_failed'))
      })
      .finally(() => {
        this.refreshingProviderId = ''
      })
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
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_err) {
    }
  }

  private loadPendingProgressSummary(): void {
    void this.pendingSyncStore().loadPendingProgress()
      .then((entries) => {
        this.pendingSummary = summarizeTrackerPendingProgress(entries)
        console.info('[TrackerSync] step=settings_pending_loaded total=' + this.pendingSummary.totalCount)
      })
      .catch((_error: Error) => {
        this.pendingSummary = summarizeTrackerPendingProgress([])
        DiagnosticLogger.warn('tracker_settings_page', 'settings_pending_load_failed', '[TrackerSync] step=settings_pending_load_failed reason=redacted')
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
        DiagnosticLogger.warn('tracker_settings_page', 'settings_pending_retry_failed', '[TrackerSync] step=settings_pending_retry_failed reason=redacted')
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
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('tracker_pending_clear_confirm_title'),
      message: s('tracker_pending_clear_confirm_message'),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearPendingProgressNow()
        },
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
        DiagnosticLogger.warn('tracker_settings_page', 'settings_pending_clear_failed', '[TrackerSync] step=settings_pending_clear_failed reason=redacted')
        this.showToast(s('tracker_pending_clear_failed'))
      })
      .finally(() => {
        this.pendingClearBusy = false
      })
  }

  @Builder
  private ProviderNavigationRow(provider: TrackerProviderConfig) {
    ConciseListRow({
      title: provider.displayName,
      leadingImage: TRACKER_BRAND_IMAGES[provider.providerId],
      leadingImageSize: ThemeConstants.SOURCE_LIST_ICON_SIZE,
      leadingImageRadius: ThemeConstants.SOURCE_LIST_ICON_RADIUS,
      subtitle: this.providerAccountDetail(provider),
      suffixBuilderParam: () => { this.ProviderStatusActions(provider) },
      showChevron: false,
      isEnabled: !this.loading,
      action: () => {
        this.openProvider(provider)
      },
    })
  }

  @Builder
  private ProviderStatusActions(provider: TrackerProviderConfig) {
    if (this.canDisconnectProvider(provider)) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        KomaIconButton({
          icon: $r('sys.symbol.arrow_clockwise'),
          isEnabled: this.canRefreshProvider(provider),
          action: () => { this.refreshAccount(provider) },
        })
          .accessibilityText(s('tracker_action_refresh'))
        KomaIconButton({
          icon: $r('sys.symbol.checkmark_circle'),
          iconSize: 24,
          accentColor: ThemeConstants.BRAND_PRIMARY,
          isEnabled: this.busyProviderId.length === 0 && this.refreshingProviderId.length === 0,
          action: () => { this.confirmDisconnectAccount(provider) },
        })
          .accessibilityText(s('tracker_action_disconnect'))
      }
    } else {
      Text(getTrackerAccountStatusLabel(this.findAccount(provider).status))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
  }

  @Builder
  private ProviderDialog(provider: TrackerProviderConfig) {
    CustomContentDialogV2({
      primaryTitle: provider.displayName,
      contentBuilder: () => { this.ProviderDirectConnectionForm(provider) },
      buttons: [
        new AdvancedDialogV2Button({
          content: s('common_cancel'),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          enabled: this.busyProviderId.length === 0,
          action: () => { this.closeProviderDialog() },
        }),
        new AdvancedDialogV2Button({
          content: s('tracker_action_connect'),
          fontColor: ColorMetrics.resourceColor(ThemeConstants.BRAND_PRIMARY),
          buttonStyle: ButtonStyleMode.TEXTUAL,
          enabled: this.canPrepareConnect(provider),
          action: () => { this.prepareConnect(provider) },
        }),
      ],
    })
  }

  @Builder
  private ProviderDirectConnectionForm(provider: TrackerProviderConfig) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (provider.authentication === 'password') {
        KomaFormTextField({
          label: s(provider.providerId === 'kitsu' ? 'tracker_account_email' : 'common_username'),
          value: this.directUsername,
          isEnabled: !this.loading && this.busyProviderId.length === 0,
          change: (value: string) => { this.directUsername = value },
        })
      }
      KomaFormTextField({
        label: s(provider.authentication === 'token' ? 'tracker_personal_access_token' : 'common_password'),
        value: this.directSecret,
        isPassword: true,
        isEnabled: !this.loading && this.busyProviderId.length === 0,
        change: (value: string) => { this.directSecret = value },
        submit: () => { this.prepareConnect(provider) },
      })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_MD })
  }

  @Builder
  private ProvidersCard() {
    GroupedListSection() {
      ForEach(this.visibleProviders(), (provider: TrackerProviderConfig, index: number) => {
        this.ProviderNavigationRow(provider)
        if (index < this.visibleProviders().length - 1) {
          ListDivider()
        }
      }, (provider: TrackerProviderConfig) => provider.providerId)
    }
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

  build() {
    Column() {
      SecondaryListScaffold({
        scroller: this.settingsScroller,
        listSpace: ThemeConstants.SPACE_MD,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          this.ProvidersCard()
        }
        if (this.providerId.length === 0) {
          ListItem() {
            SettingsPage({ pane: 'tracking', embeddedTracking: true, scroller: this.settingsScroller,
              searchTarget: this.searchTarget, preferencesRestoreRevision: this.preferencesRestoreRevision })
          }
        }
        if (this.providerId.length === 0 && this.pendingSummary.totalCount > 0) {
          ListItem() {
            this.PendingProgressCard()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
