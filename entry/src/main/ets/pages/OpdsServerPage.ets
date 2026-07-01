import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { OpdsVersion } from '../remote/OpdsModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct OpdsServerPage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private rootUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private detectedVersion: string = ''
  @Local private testing: boolean = false
  @Local private statusKey: string = ''
  @Local private statusArgs: string[] = []
  @Local private statusRawText: string = ''

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
      this.setRawStatus(e.message)
      console.error('[OPDS] step=settings_load_error message=' + e.message)
    }
  }

  private async saveAndTest(): Promise<void> {
    if (this.testing) {
      return
    }
    this.testing = true
    this.setStatus('server_status_testing')
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
      this.setStatus('opds_status_success', [
        this.versionLabel(catalog.version),
        `${catalog.navigation.length}`,
        `${catalog.publications.length}`,
      ])
      console.info(`[OPDS] step=test_connection_ok version=${catalog.version} navigation=${catalog.navigation.length} publications=${catalog.publications.length}`)
      this.showToast(s('opds_toast_success'))
    } catch (error) {
      const e = error as Error
      this.setStatus('opds_status_failed', [e.message])
      console.error('[OPDS] step=test_connection_failed message=' + e.message)
      this.showToast(s('opds_toast_failed'))
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
      this.setStatus('opds_status_removed')
      this.showToast(s('opds_toast_removed'))
    } catch (error) {
      const e = error as Error
      this.setRawStatus(e.message)
    }
  }

  private setStatus(key: string, args: string[] = []): void {
    this.statusKey = key
    this.statusArgs = args
    this.statusRawText = ''
  }

  private setRawStatus(message: string): void {
    this.statusKey = ''
    this.statusArgs = []
    this.statusRawText = message
  }

  private statusText(): string {
    if (this.statusRawText.length > 0) {
      return this.statusRawText
    }
    if (this.statusKey.length === 0) {
      return ''
    }
    let message = s(this.statusKey)
    this.statusArgs.forEach((arg: string) => {
      message = message.replace('%s', arg)
    })
    return message
  }

  private versionLabel(version: OpdsVersion | string): string {
    return version === OpdsVersion.OPDS_2 ? s('opds_version_2') : s('opds_version_1')
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
      KomaFormTextField({ label: s('opds_label_catalog_url'), placeholder: 'https://demo.komga.org/opds/v2/catalog', value: this.rootUrl, change: (value: string) => {
        this.rootUrl = value
      } })
      KomaFormTextField({ label: s('common_username'), placeholder: s('common_optional_placeholder'), value: this.username, change: (value: string) => {
        this.username = value
      } })
      KomaFormTextField({ label: s('common_password'), placeholder: s('common_optional_placeholder'), value: this.password, isPassword: true, change: (value: string) => {
        this.password = value
      } })

      Text(this.detectedVersion.length === 0
        ? s('opds_version_auto')
        : s('opds_version_value').replace('%s', this.versionLabel(this.detectedVersion)))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

      KomaActionButton({
        label: this.testing ? s('common_testing') : s('server_action_save_and_test'),
        kind: 'primary',
        fullWidth: true,
        isEnabled: !this.testing,
        action: () => {
          this.saveAndTest()
        },
      })
        .width('100%')

      KomaActionButton({
        label: s('server_action_remove_config'),
        kind: 'ghost',
        fullWidth: true,
        accentColor: ThemeConstants.TEXT_SECONDARY,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.clearServer()
        },
      })
        .width('100%')

      if (this.statusText().length > 0) {
        Text(this.statusText())
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
