import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaSegmentedControl } from '../components/ui/KomaSegmentedControl'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { KomgaAuthKind } from '../remote/KomgaModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct KomgaServerPage {
  @Local private baseUrl: string = ''
  @Local private authKind: KomgaAuthKind = KomgaAuthKind.BASIC
  @Local private apiKey: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
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

  private authIndex(): number {
    if (this.authKind === KomgaAuthKind.API_KEY) {
      return 1
    }
    if (this.authKind === KomgaAuthKind.NONE) {
      return 2
    }
    return 0
  }

  private setAuthIndex(index: number): void {
    if (index === 1) {
      this.authKind = KomgaAuthKind.API_KEY
    } else if (index === 2) {
      this.authKind = KomgaAuthKind.NONE
    } else {
      this.authKind = KomgaAuthKind.BASIC
    }
  }

  @Builder
  private FormCard() {
    GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
      KomaFormTextField({ label: 'Server URL', placeholder: 'https://demo.komga.org', value: this.baseUrl, change: (value: string) => {
        this.baseUrl = value
      } })

      KomaSegmentedControl({
        labels: ['Basic', 'API key', '无认证'],
        selectedIndex: this.authIndex(),
        select: (index: number) => {
          this.setAuthIndex(index)
        },
      })

      if (this.authKind === KomgaAuthKind.API_KEY) {
        KomaFormTextField({ label: 'API key', placeholder: 'X-API-Key', value: this.apiKey, isPassword: true, change: (value: string) => {
          this.apiKey = value
        } })
      } else if (this.authKind === KomgaAuthKind.BASIC) {
        KomaFormTextField({ label: '用户名', placeholder: 'demo@komga.org', value: this.username, change: (value: string) => {
          this.username = value
        } })
        KomaFormTextField({ label: '密码', placeholder: 'komga-demo', value: this.password, isPassword: true, change: (value: string) => {
          this.password = value
        } })
      }

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
