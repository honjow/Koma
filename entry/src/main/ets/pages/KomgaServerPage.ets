import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { KomgaAuthKind } from '../remote/KomgaModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct KomgaServerPage {
  @State private baseUrl: string = ''
  @State private authKind: KomgaAuthKind = KomgaAuthKind.BASIC
  @State private apiKey: string = ''
  @State private username: string = ''
  @State private password: string = ''
  @State private testing: boolean = false
  @State private statusText: string = ''

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadSaved()
  }

  private async loadSaved(): Promise<void> {
    try {
      const saved = await this.store().loadKomga()
      if (saved === undefined) {
        return
      }
      this.baseUrl = saved.server.baseUrl
      this.authKind = saved.server.authKind
      this.apiKey = saved.credential?.apiKey === undefined ? '' : saved.credential.apiKey
      console.info('[Komga] step=settings_load configured=true')
    } catch (error) {
      const e = error as Error
      this.statusText = e.message
      console.error('[Komga] step=settings_load_error message=' + e.message)
    }
  }

  private async saveAndTest(): Promise<void> {
    if (this.testing) {
      return
    }
    this.testing = true
    this.statusText = '正在测试连接...'
    try {
      const store = this.store()
      const record = await store.saveKomga({
        baseUrl: this.baseUrl,
        authKind: this.authKind,
        apiKey: this.apiKey,
        username: this.username,
        password: this.password,
      })
      console.info('[Komga] step=test_connection_start')
      const libraries = await store.createKomgaClient(record).listLibraries()
      this.statusText = `连接成功，发现 ${libraries.length} 个库`
      console.info(`[Komga] step=test_connection_ok libraries=${libraries.length}`)
      this.showToast('Komga 连接成功')
    } catch (error) {
      const e = error as Error
      this.statusText = `连接失败：${e.message}`
      console.error('[Komga] step=test_connection_failed message=' + e.message)
      this.showToast('Komga 连接失败')
    } finally {
      this.testing = false
    }
  }

  private async clearServer(): Promise<void> {
    try {
      await this.store().clearKomga()
      this.baseUrl = ''
      this.apiKey = ''
      this.username = ''
      this.password = ''
      this.statusText = '已移除 Komga 配置'
      this.showToast('已移除 Komga')
    } catch (error) {
      const e = error as Error
      this.statusText = e.message
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_err) {
    }
  }

  @Builder
  private Field(label: string, placeholder: string, value: string, password: boolean = false, onChange: (value: string) => void) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .width('100%')
      TextInput({ placeholder, text: value })
        .type(password ? InputType.Password : InputType.Normal)
        .height(ThemeConstants.BUTTON_HEIGHT)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .backgroundColor(ThemeConstants.BG_SUB)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .onChange((next: string) => {
          onChange(next)
        })
    }
    .width('100%')
  }

  @Builder
  private AuthButton(label: string, kind: KomgaAuthKind) {
    Button(label)
      .height(ThemeConstants.ACTION_CHIP_HEIGHT)
      .layoutWeight(1)
      .fontSize(ThemeConstants.FONT_SIZE_META)
      .fontColor(this.authKind === kind ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.BRAND_PRIMARY)
      .backgroundColor(this.authKind === kind ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
      .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
      .borderRadius(ThemeConstants.RADIUS_CHIP)
      .onClick(() => {
        this.authKind = kind
      })
  }

  @Builder
  private FormCard() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      this.Field('Server URL', 'https://demo.komga.org', this.baseUrl, false, (value: string) => {
        this.baseUrl = value
      })

      Row({ space: ThemeConstants.SPACE_SM }) {
        this.AuthButton('Basic', KomgaAuthKind.BASIC)
        this.AuthButton('API key', KomgaAuthKind.API_KEY)
        this.AuthButton('无认证', KomgaAuthKind.NONE)
      }
      .width('100%')

      if (this.authKind === KomgaAuthKind.API_KEY) {
        this.Field('API key', 'X-API-Key', this.apiKey, true, (value: string) => {
          this.apiKey = value
        })
      } else if (this.authKind === KomgaAuthKind.BASIC) {
        this.Field('用户名', 'demo@komga.org', this.username, false, (value: string) => {
          this.username = value
        })
        this.Field('密码', 'komga-demo', this.password, true, (value: string) => {
          this.password = value
        })
      }

      Button(this.testing ? '测试中...' : '保存并测试连接')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .enabled(!this.testing)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .onClick(() => {
          this.saveAndTest()
        })

      Button('移除配置')
        .height(ThemeConstants.ACTION_CHIP_HEIGHT)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: ThemeConstants.DIVIDER })
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .onClick(() => {
          this.clearServer()
        })

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
        includeKeyboardPadding: true,
      }) {
        ListItem() {
          this.FormCard()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
