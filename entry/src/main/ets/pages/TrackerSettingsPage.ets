import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import {
  DEFAULT_TRACKER_ACCOUNTS,
  TRACKER_PROVIDER_CONFIGS,
  TrackerAccount,
  TrackerOAuthStartPreparation,
  TrackerPreferencesStore,
  TrackerProviderConfig,
  getTrackerAccountDetail,
  getTrackerAccountStatusLabel,
} from '../model/TrackerModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct TrackerSettingsPage {
  @Local private accounts: TrackerAccount[] = DEFAULT_TRACKER_ACCOUNTS
  @Local private secureStorageAvailable: boolean = false
  @Local private authPreparationMessage: string = s('tracker_message_secure_storage_unverified')

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private trackerPreferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context())
  }

  aboutToAppear(): void {
    void this.trackerPreferencesStore().load()
      .then((preferences) => {
        this.accounts = preferences.accounts
        console.info('[TrackerSettings] step=load accounts=' + preferences.accounts.length)
      })
      .catch((_error: Error) => {
        this.authPreparationMessage = s('tracker_message_load_failed')
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
      this.authPreparationMessage = !this.secureStorageAvailable
        ? s('tracker_message_connect_unavailable')
        : s('tracker_message_auth_unavailable')
      this.showToast(this.authPreparationMessage)
      return
    }
    void this.trackerPreferencesStore().prepareConnect(provider.providerId)
      .then((result: TrackerOAuthStartPreparation) => {
        this.authPreparationMessage = result.status === 'ready'
          ? s('tracker_message_auth_ready')
          : this.authPrepareStatusLabel(result.status)
        this.showToast(this.authPreparationMessage)
      })
      .catch((_error: Error) => {
        this.authPreparationMessage = s('tracker_message_auth_prepare_failed')
        this.showToast(this.authPreparationMessage)
      })
  }

  private authPrepareStatusLabel(status: string): string {
    if (status === 'secure_storage_unavailable') {
      return s('tracker_message_connect_unavailable')
    }
    if (status === 'provider_config_missing') {
      return s('tracker_message_auth_unavailable')
    }
    if (status === 'provider_unsupported') {
      return s('tracker_message_provider_unsupported')
    }
    if (status === 'pkce_unavailable') {
      return s('tracker_message_auth_unavailable')
    }
    return s('tracker_message_auth_prepare_failed')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
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
      Text(this.authPreparationMessage)
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
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(provider.displayName)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Text(getTrackerAccountDetail(this.findAccount(provider), this.secureStorageAvailable))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)

      Text(getTrackerAccountStatusLabel(this.findAccount(provider).status))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

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
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
