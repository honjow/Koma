import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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

@ComponentV2
export struct TrackerSettingsPage {
  @Local private accounts: TrackerAccount[] = DEFAULT_TRACKER_ACCOUNTS
  @Local private secureStorageAvailable: boolean = false
  @Local private authPreparationMessage: string = '安全存储未验证，追踪账号连接暂不可用'

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
        this.authPreparationMessage = '追踪账号状态读取失败'
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
      return '不支持'
    }
    if (provider.supportStatus === 'planned') {
      return '计划中'
    }
    if (!this.secureStorageAvailable) {
      return '安全存储不可用'
    }
    if (provider.clientId === undefined || provider.redirectUri === undefined) {
      return '待配置'
    }
    return '连接'
  }

  private canPrepareConnect(provider: TrackerProviderConfig): boolean {
    return provider.supportStatus === 'available' &&
      this.secureStorageAvailable &&
      provider.clientId !== undefined &&
      provider.redirectUri !== undefined
  }

  private prepareConnect(provider: TrackerProviderConfig): void {
    if (!this.canPrepareConnect(provider)) {
      this.authPreparationMessage = !this.secureStorageAvailable ? '账号连接暂不可用' : '当前版本暂不能开始授权'
      this.showToast(this.authPreparationMessage)
      return
    }
    void this.trackerPreferencesStore().prepareConnect(provider.providerId)
      .then((result: TrackerOAuthStartPreparation) => {
        this.authPreparationMessage = result.status === 'ready' ? '授权地址已准备' : this.authPrepareStatusLabel(result.status)
        this.showToast(this.authPreparationMessage)
      })
      .catch((_error: Error) => {
        this.authPreparationMessage = '授权准备失败'
        this.showToast(this.authPreparationMessage)
      })
  }

  private authPrepareStatusLabel(status: string): string {
    if (status === 'secure_storage_unavailable') {
      return '账号连接暂不可用'
    }
    if (status === 'provider_config_missing') {
      return '当前版本暂不能开始授权'
    }
    if (status === 'provider_unsupported') {
      return '当前服务暂不支持连接'
    }
    if (status === 'pkce_unavailable') {
      return '当前版本暂不能开始授权'
    }
    return '授权准备失败'
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
      Text('追踪账号')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text('当前只保存账号状态和公开资料。授权材料必须进入系统安全存储；安全存储未验证时不会把账号标记为已连接。')
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

      Button(this.connectActionLabel(provider))
        .height(ThemeConstants.ACTION_CHIP_HEIGHT)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(this.canPrepareConnect(provider) ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.TEXT_SECONDARY)
        .backgroundColor(this.canPrepareConnect(provider) ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
        .border({ width: 1, color: this.canPrepareConnect(provider) ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY })
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .enabled(this.canPrepareConnect(provider))
        .onClick(() => {
          this.prepareConnect(provider)
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
