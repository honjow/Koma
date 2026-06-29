import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct WebDavServerPage {
  @State private baseUrl: string = ''
  @State private username: string = ''
  @State private password: string = ''
  @State private rootPath: string = ''
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
      const saved = await this.store().loadWebDav()
      if (saved === undefined) {
        return
      }
      this.baseUrl = saved.server.baseUrl
      this.rootPath = saved.server.rootPath === undefined ? '' : saved.server.rootPath
      console.info('[WebDAV] step=settings_load configured=true')
    } catch (error) {
      const e = error as Error
      this.statusText = e.message
      console.error('[WebDAV] step=settings_load_error message=' + e.message)
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
      const record = await store.saveWebDav({
        baseUrl: this.baseUrl,
        username: this.username,
        password: this.password,
        rootPath: this.rootPath,
      })
      console.info('[WebDAV] step=test_connection_start')
      const resources = await store.createWebDavClient(record).propfind([], 0)
      this.statusText = `连接成功，根目录可访问（${resources.length} 项属性）`
      console.info(`[WebDAV] step=test_connection_ok resources=${resources.length}`)
      this.showToast('WebDAV 连接成功')
    } catch (error) {
      const e = error as Error
      this.statusText = `连接失败：${e.message}`
      console.error('[WebDAV] step=test_connection_failed message=' + e.message)
      this.showToast('WebDAV 连接失败')
    } finally {
      this.testing = false
    }
  }

  private async clearServer(): Promise<void> {
    try {
      await this.store().clearWebDav()
      this.baseUrl = ''
      this.username = ''
      this.password = ''
      this.rootPath = ''
      this.statusText = '已移除 WebDAV 配置'
      this.showToast('已移除 WebDAV')
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
  private FormCard() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      this.Field('Server URL', 'https://test.webdav.org/', this.baseUrl, false, (value: string) => {
        this.baseUrl = value
      })
      this.Field('路径前缀', 'manga 或 remote.php/dav/files/user/manga', this.rootPath, false, (value: string) => {
        this.rootPath = value
      })
      this.Field('用户名', '可留空', this.username, false, (value: string) => {
        this.username = value
      })
      this.Field('密码', '可留空', this.password, true, (value: string) => {
        this.password = value
      })

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
