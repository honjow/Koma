import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { OpdsVersion } from '../remote/OpdsModels'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct OpdsServerPage {
  @State private rootUrl: string = ''
  @State private username: string = ''
  @State private password: string = ''
  @State private detectedVersion: string = ''
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
  private FormCard() {
    Column({ space: 16 }) {
      this.Field('Catalog URL', 'https://demo.komga.org/opds/v2/catalog', this.rootUrl, false, (value: string) => {
        this.rootUrl = value
      })
      this.Field('用户名', '可留空', this.username, false, (value: string) => {
        this.username = value
      })
      this.Field('密码', '可留空', this.password, true, (value: string) => {
        this.password = value
      })

      Text(this.detectedVersion.length === 0 ? 'OPDS 版本：测试连接后自动检测' : `OPDS 版本：${this.versionLabel(this.detectedVersion)}`)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))

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
