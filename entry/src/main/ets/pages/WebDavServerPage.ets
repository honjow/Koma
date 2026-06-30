import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct WebDavServerPage {
  @Local private baseUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private rootPath: string = ''
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
      const saved = await this.store().loadWebDav()
      if (saved === undefined) {
        return
      }
      this.baseUrl = saved.server.baseUrl
      this.rootPath = saved.server.rootPath === undefined ? '' : saved.server.rootPath
      console.info('[WebDAV] step=settings_load configured=true')
    } catch (error) {
      const e = error as Error
      this.setRawStatus(e.message)
      console.error('[WebDAV] step=settings_load_error message=' + e.message)
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
      const record = await store.saveWebDav({
        baseUrl: this.baseUrl,
        username: this.username,
        password: this.password,
        rootPath: this.rootPath,
      })
      console.info('[WebDAV] step=test_connection_start')
      const resources = await store.createWebDavClient(record).propfind([], 0)
      this.setStatus('webdav_status_success', [`${resources.length}`])
      console.info(`[WebDAV] step=test_connection_ok resources=${resources.length}`)
      this.showToast(s('webdav_toast_success'))
    } catch (error) {
      const e = error as Error
      this.setStatus('webdav_status_failed', [e.message])
      console.error('[WebDAV] step=test_connection_failed message=' + e.message)
      this.showToast(s('webdav_toast_failed'))
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
      this.setStatus('webdav_status_removed')
      this.showToast(s('webdav_toast_removed'))
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
      KomaFormTextField({ label: s('common_server_url'), placeholder: 'https://test.webdav.org/', value: this.baseUrl, change: (value: string) => {
        this.baseUrl = value
      } })
      KomaFormTextField({ label: s('webdav_label_root_path'), placeholder: s('webdav_placeholder_root_path'), value: this.rootPath, change: (value: string) => {
        this.rootPath = value
      } })
      KomaFormTextField({ label: s('common_username'), placeholder: s('common_optional_placeholder'), value: this.username, change: (value: string) => {
        this.username = value
      } })
      KomaFormTextField({ label: s('common_password'), placeholder: s('common_optional_placeholder'), value: this.password, isPassword: true, change: (value: string) => {
        this.password = value
      } })

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
