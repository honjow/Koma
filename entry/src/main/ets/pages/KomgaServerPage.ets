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
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_secondary'))
        .width('100%')
      TextInput({ placeholder, text: value })
        .type(password ? InputType.Password : InputType.Normal)
        .height(44)
        .fontSize(15)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(8)
        .onChange((next: string) => {
          onChange(next)
        })
    }
    .width('100%')
  }

  @Builder
  private AuthButton(label: string, kind: KomgaAuthKind) {
    Button(label)
      .height(36)
      .layoutWeight(1)
      .fontSize(13)
      .fontColor(this.authKind === kind ? Color.White : $r('app.color.koma_accent'))
      .backgroundColor(this.authKind === kind ? $r('app.color.koma_accent') : '#00000000')
      .border({ width: 1, color: $r('app.color.koma_accent') })
      .borderRadius(8)
      .onClick(() => {
        this.authKind = kind
      })
  }

  @Builder
  private FormCard() {
    Column({ space: 16 }) {
      this.Field('Server URL', 'https://demo.komga.org', this.baseUrl, false, (value: string) => {
        this.baseUrl = value
      })

      Row({ space: 8 }) {
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
        .height(44)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .enabled(!this.testing)
        .backgroundColor($r('app.color.koma_accent'))
        .borderRadius(8)
        .onClick(() => {
          this.saveAndTest()
        })

      Button('移除配置')
        .height(40)
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))
        .backgroundColor('#00000000')
        .border({ width: 1, color: '#338F837D' })
        .borderRadius(8)
        .onClick(() => {
          this.clearServer()
        })

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.koma_text_secondary'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 16,
        horizontalPadding: 20,
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
