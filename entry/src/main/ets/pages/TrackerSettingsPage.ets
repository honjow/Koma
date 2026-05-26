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

@Component
export struct TrackerSettingsPage {
  @State private accounts: TrackerAccount[] = DEFAULT_TRACKER_ACCOUNTS
  @State private secureStorageAvailable: boolean = false
  @State private authPreparationMessage: string = '安全存储未验证，追踪账号连接暂不可用'

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
      this.authPreparationMessage = !this.secureStorageAvailable ? '安全存储不可用，无法开始授权' : 'Provider 配置未完成，无法开始授权'
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
      return '安全存储不可用，无法保存授权'
    }
    if (status === 'provider_config_missing') {
      return 'Provider 配置未完成'
    }
    if (status === 'provider_unsupported') {
      return 'Provider 尚未开放连接'
    }
    if (status === 'pkce_unavailable') {
      return 'PKCE 不可用，无法开始授权'
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
    Column({ space: 8 }) {
      Text('追踪账号')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('当前只保存账号状态和公开资料。授权材料必须进入系统安全存储；安全存储未验证时不会把账号标记为已连接。')
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('app.color.koma_text_secondary'))
      Text(this.authPreparationMessage)
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private ProviderRow(provider: TrackerProviderConfig) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(provider.displayName)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
        Text(getTrackerAccountDetail(this.findAccount(provider), this.secureStorageAvailable))
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)

      Text(getTrackerAccountStatusLabel(this.findAccount(provider).status))
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))

      Button(this.connectActionLabel(provider))
        .height(32)
        .fontSize(12)
        .fontColor(this.canPrepareConnect(provider) ? Color.White : $r('app.color.koma_text_secondary'))
        .backgroundColor(this.canPrepareConnect(provider) ? $r('app.color.koma_accent') : '#00000000')
        .border({ width: 1, color: this.canPrepareConnect(provider) ? $r('app.color.koma_accent') : $r('app.color.koma_text_secondary') })
        .borderRadius(8)
        .enabled(this.canPrepareConnect(provider))
        .onClick(() => {
          this.prepareConnect(provider)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  private ProvidersCard() {
    Column() {
      ForEach(TRACKER_PROVIDER_CONFIGS, (provider: TrackerProviderConfig, index: number) => {
        this.ProviderRow(provider)
        if (index < TRACKER_PROVIDER_CONFIGS.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.koma_background'))
            .margin({ left: 16, right: 16 })
        }
      }, (provider: TrackerProviderConfig) => provider.providerId)
    }
    .width('100%')
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
