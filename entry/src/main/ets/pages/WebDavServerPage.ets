import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct WebDavServerPage {
  @Local private baseUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private rootPath: string = ''
  @Local private testing: boolean = false
  @Local private statusText: string = ''

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
  private FormCard() {
    GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
      KomaFormTextField({ label: 'Server URL', placeholder: 'https://test.webdav.org/', value: this.baseUrl, change: (value: string) => {
        this.baseUrl = value
      } })
      KomaFormTextField({ label: '路径前缀', placeholder: 'manga 或 remote.php/dav/files/user/manga', value: this.rootPath, change: (value: string) => {
        this.rootPath = value
      } })
      KomaFormTextField({ label: '用户名', placeholder: '可留空', value: this.username, change: (value: string) => {
        this.username = value
      } })
      KomaFormTextField({ label: '密码', placeholder: '可留空', value: this.password, isPassword: true, change: (value: string) => {
        this.password = value
      } })

      KomaActionButton({
        label: this.testing ? '测试中...' : '保存并测试连接',
        kind: 'primary',
        fullWidth: true,
        isEnabled: !this.testing,
        action: () => {
          this.saveAndTest()
        },
      })
        .width('100%')

      KomaActionButton({
        label: '移除配置',
        kind: 'ghost',
        fullWidth: true,
        accentColor: ThemeConstants.TEXT_SECONDARY,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.clearServer()
        },
      })
        .width('100%')

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
      .width('100%')
    }
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
