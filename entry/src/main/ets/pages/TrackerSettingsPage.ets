import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  DEFAULT_TRACKER_PROVIDER_CONNECTIONS,
  TrackerPreferencesStore,
  TrackerProviderConnection,
  getTrackerConnectionStatusLabel,
} from '../model/TrackerModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct TrackerSettingsPage {
  @State private connections: TrackerProviderConnection[] = DEFAULT_TRACKER_PROVIDER_CONNECTIONS

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private trackerPreferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context())
  }

  aboutToAppear(): void {
    void this.trackerPreferencesStore().load()
      .then((preferences) => {
        this.connections = preferences.connections
        console.info('[TrackerSettings] step=load connections=' + preferences.connections.length)
      })
      .catch((error: Error) => {
        console.warn('[TrackerSettings] step=load_failed message=' + error.message)
      })
  }

  @Builder
  private StatusCard() {
    Column({ space: 8 }) {
      Text('公共追踪账号同步尚未接入')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('当前页面仅保留本地占位状态，用于后续接入 AniList、MyAnimeList 等服务。这里不会要求登录，也不会保存账号授权数据。')
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private ProviderRow(connection: TrackerProviderConnection) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(connection.displayName)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
        Text('账号未连接')
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)

      Text(getTrackerConnectionStatusLabel(connection.status))
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  private ProvidersCard() {
    Column() {
      ForEach(this.connections, (connection: TrackerProviderConnection, index: number) => {
        this.ProviderRow(connection)
        if (index < this.connections.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.koma_background'))
            .margin({ left: 16, right: 16 })
        }
      }, (connection: TrackerProviderConnection) => connection.providerId)
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
