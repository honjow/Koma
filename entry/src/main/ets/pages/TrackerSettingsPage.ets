import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import {
  AssetStoreTrackerCredentialSecretStore,
  DEFAULT_TRACKER_ACCOUNTS,
  TrackerComicMappingSummary,
  TRACKER_PROVIDER_CONFIGS,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerOAuthStartPreparation,
  TrackerPreferencesStore,
  TrackerProviderConfig,
  getTrackerAccountDetail,
  getTrackerAccountStatusLabel,
  summarizeComicTrackerMappings,
} from '../model/TrackerModels'
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
  @Local private mappingSummary: TrackerComicMappingSummary = {
    total: 0,
    confirmed: 0,
    candidate: 0,
    stale: 0,
    rejected: 0,
    unmapped: 0,
  }
  @Local private secureStorageAvailable: boolean = false
  @Local private authPreparationMessageKey: string = 'tracker_message_secure_storage_unverified'
  private credentialSecretStore: TrackerCredentialSecretStore = new AssetStoreTrackerCredentialSecretStore()

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private trackerPreferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context(), this.credentialSecretStore)
  }

  aboutToAppear(): void {
    this.secureStorageAvailable = this.credentialSecretStore.isAvailable()
    void this.trackerPreferencesStore().load()
      .then((preferences) => {
        this.accounts = preferences.accounts
        this.mappingSummary = summarizeComicTrackerMappings(preferences.comicMappings)
        console.info('[TrackerSettings] step=load accounts=' + preferences.accounts.length + ' mappings=' + preferences.comicMappings.length)
      })
      .catch((_error: Error) => {
        this.authPreparationMessageKey = 'tracker_message_load_failed'
        console.warn('[TrackerSettings] step=load_failed reason=redacted')
      })
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

  private connectActionLabel(provider: TrackerProviderConfig): string {
    if (provider.supportStatus === 'unsupported') {
      return s('tracker_action_unsupported')
    }
    if (provider.supportStatus === 'planned') {
      return s('tracker_action_planned')
    }
    if (!this.secureStorageAvailable) {
      return s('tracker_action_secure_storage_unavailable')
    }
    if (provider.clientId === undefined || provider.redirectUri === undefined) {
      return s('tracker_action_needs_config')
    }
    return s('tracker_action_connect')
  }

  private canPrepareConnect(provider: TrackerProviderConfig): boolean {
    return provider.supportStatus === 'available' &&
      this.secureStorageAvailable &&
      provider.clientId !== undefined &&
      provider.redirectUri !== undefined
  }

  private prepareConnect(provider: TrackerProviderConfig): void {
    if (!this.canPrepareConnect(provider)) {
      this.authPreparationMessageKey = !this.secureStorageAvailable
        ? 'tracker_message_connect_unavailable'
        : 'tracker_message_auth_unavailable'
      this.showToast(s(this.authPreparationMessageKey))
      return
    }
    void this.trackerPreferencesStore().prepareConnect(provider.providerId)
      .then((result: TrackerOAuthStartPreparation) => {
        this.authPreparationMessageKey = result.status === 'ready'
          ? 'tracker_message_auth_ready'
          : this.authPrepareStatusKey(result.status)
        this.showToast(s(this.authPreparationMessageKey))
      })
      .catch((_error: Error) => {
        this.authPreparationMessageKey = 'tracker_message_auth_prepare_failed'
        this.showToast(s(this.authPreparationMessageKey))
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
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private mappingProgressText(): string {
    return s('tracker_mapping_progress')
      .replace('%s', `${this.mappingSummary.total}`)
      .replace('%s', `${this.mappingSummary.confirmed}`)
      .replace('%s', `${this.mappingSummary.candidate}`)
      .replace('%s', `${this.mappingSummary.stale + this.mappingSummary.rejected}`)
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
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ProvidersCard() {
    Column() {
      ForEach(TRACKER_PROVIDER_CONFIGS, (provider: TrackerProviderConfig, index: number) => {
        this.ProviderRow(provider)
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
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          this.StatusCard()
        }
        ListItem() {
          this.ProvidersCard()
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
