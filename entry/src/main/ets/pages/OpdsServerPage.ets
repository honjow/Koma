import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { OpdsVersion } from '../remote/OpdsModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct OpdsServerPage {
  @Local private rootUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private detectedVersion: string = ''
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
      const saved = await this.store().loadOpds()
      if (saved === undefined) {
        return
      }
      this.rootUrl = saved.server.rootUrl
      this.detectedVersion = saved.server.version === undefined ? '' : saved.server.version
      console.info('[OPDS] step=settings_load configured=true')
    } catch (error) {
      const e = error as Error
      this.statusText = e.message
      console.error('[OPDS] step=settings_load_error message=' + e.message)
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
      let record = await store.saveOpds({
        rootUrl: this.rootUrl,
        username: this.username,
        password: this.password,
      })
      console.info('[OPDS] step=test_connection_start')
      const catalog = await store.createOpdsClient(record).fetchCatalog()
      record = await store.saveOpds({
        rootUrl: this.rootUrl,
        username: this.username,
        password: this.password,
        version: catalog.version,
      })
      this.detectedVersion = record.server.version === undefined ? '' : record.server.version
      this.statusText = `连接成功，检测到 ${this.versionLabel(catalog.version)}，${catalog.navigation.length} 个目录 / ${catalog.publications.length} 个条目`
      console.info(`[OPDS] step=test_connection_ok version=${catalog.version} navigation=${catalog.navigation.length} publications=${catalog.publications.length}`)
      this.showToast('OPDS 连接成功')
    } catch (error) {
      const e = error as Error
      this.statusText = `连接失败：${e.message}`
      console.error('[OPDS] step=test_connection_failed message=' + e.message)
      this.showToast('OPDS 连接失败')
    } finally {
      this.testing = false
    }
  }

  private async clearServer(): Promise<void> {
    try {
      await this.store().clearOpds()
      this.rootUrl = ''
      this.username = ''
      this.password = ''
      this.detectedVersion = ''
      this.statusText = '已移除 OPDS 配置'
      this.showToast('已移除 OPDS')
    } catch (error) {
      const e = error as Error
      this.statusText = e.message
    }
  }

  private versionLabel(version: OpdsVersion | string): string {
    return version === OpdsVersion.OPDS_2 ? 'OPDS 2' : 'OPDS 1.x'
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
      KomaFormTextField({ label: 'Catalog URL', placeholder: 'https://demo.komga.org/opds/v2/catalog', value: this.rootUrl, change: (value: string) => {
        this.rootUrl = value
      } })
      KomaFormTextField({ label: '用户名', placeholder: '可留空', value: this.username, change: (value: string) => {
        this.username = value
      } })
      KomaFormTextField({ label: '密码', placeholder: '可留空', value: this.password, isPassword: true, change: (value: string) => {
        this.password = value
      } })

      Text(this.detectedVersion.length === 0 ? 'OPDS 版本：测试连接后自动检测' : `OPDS 版本：${this.versionLabel(this.detectedVersion)}`)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

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
