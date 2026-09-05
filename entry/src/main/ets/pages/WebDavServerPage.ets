import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore, WebDavServerRecord, remoteServerDraftErrorKey } from '../model/RemoteServerStore'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct WebDavServerPage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private baseUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private rootPath: string = ''
  @Local private testing: boolean = false
  @Local private loading: boolean = true
  @Local private removing: boolean = false
  @Local private hasSavedConfig: boolean = false
  @Local private hasSavedBasicCredential: boolean = false
  @Local private statusKey: string = ''
  @Local private statusArgs: string[] = []

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadSaved()
  }

  private async loadSaved(): Promise<void> {
    this.loading = true
    try {
      const store = this.store()
      this.hasSavedConfig = await store.hasSavedConfiguration('webdav')
      const saved = await store.loadWebDav()
      if (saved === undefined) {
        if (this.hasSavedConfig) {
          this.setStatus('server_status_load_failed')
        }
        return
      }
      this.baseUrl = saved.server.baseUrl
     this.rootPath = saved.server.rootPath === undefined ? '' : saved.server.rootPath
      this.hasSavedBasicCredential = saved.server.credentialRef !== undefined &&
        saved.credential?.basicToken !== undefined && saved.credential.basicToken.length > 0
      console.info('[WebDAV] step=settings_load configured=true')
    } catch (error) {
      void error
      this.setStatus('server_status_load_failed')
      console.error('[WebDAV] step=settings_load_error reason=settings_load')
    } finally {
      this.loading = false
    }
  }

  private formBusy(): boolean {
    return this.loading || this.testing || this.removing
  }

  private draftEdited(): void {
    this.setStatus('')
  }

  private async saveAndTest(): Promise<void> {
    if (this.formBusy()) {
      return
    }
    this.testing = true
    this.setStatus('')
    try {
      const store = this.store()
      let record: WebDavServerRecord
      try {
        record = await store.saveWebDav({
          baseUrl: this.baseUrl,
          username: this.username,
          password: this.password,
          rootPath: this.rootPath,
          preserveSavedCredentials: true,
        })
        this.hasSavedConfig = true
        this.hasSavedBasicCredential = record.server.credentialRef !== undefined
      } catch (error) {
        const key = remoteServerDraftErrorKey(error as Object)
        this.setStatus(key.length > 0 ? key : 'server_status_save_failed')
        return
      }
      this.setStatus('server_status_testing')
      console.info('[WebDAV] step=test_connection_start')
      try {
        const resources = await store.createWebDavClient(record).propfind([], 0)

        this.setStatus('webdav_status_success', [`${resources.length}`])
        this.showToast(s('webdav_toast_success'))
        console.info(`[WebDAV] step=test_connection_ok resources=${resources.length}`)
      } catch (error) {
        void error
        this.setStatus('webdav_status_failed')
        console.error('[WebDAV] step=test_connection_failed reason=connection_test')
        this.showToast(s('webdav_toast_failed'))
      }
    } finally {
      this.testing = false
    }
  }

  private async clearServer(): Promise<void> {
    if (this.formBusy() || !this.hasSavedConfig) {
      return
    }
    this.removing = true
    try {
      await this.store().clearWebDav()
      this.baseUrl = ''
      this.username = ''
      this.password = ''
      this.rootPath = ''
      this.hasSavedConfig = false
      this.hasSavedBasicCredential = false
      this.setStatus('webdav_status_removed')
      this.showToast(s('webdav_toast_removed'))
    } catch (error) {
      void error
      this.setStatus('server_status_remove_failed')
    } finally {
      this.removing = false
    }
  }

  private setStatus(key: string, args: string[] = []): void {
    this.statusKey = key
    this.statusArgs = args
  }

  private statusText(): string {
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
        KomaFormTextField({ label: s('common_server_url'), placeholder: 'https://test.webdav.org/', value: this.baseUrl, isEnabled: !this.formBusy(), change: (value: string) => {
          if (!this.formBusy()) {
            this.baseUrl = value
            this.draftEdited()
          }
        } })
        KomaFormTextField({ label: s('webdav_label_root_path'), placeholder: s('webdav_placeholder_root_path'), value: this.rootPath, isEnabled: !this.formBusy(), change: (value: string) => {
          if (!this.formBusy()) {
            this.rootPath = value
            this.draftEdited()
          }
        } })
        Text(s('webdav_root_path_help'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        KomaFormTextField({ label: s('common_username'), placeholder: s('common_optional_placeholder'), value: this.username, isEnabled: !this.formBusy(), change: (value: string) => {
          if (!this.formBusy()) {
            this.username = value
            this.draftEdited()
          }
        } })
        KomaFormTextField({ label: s('common_password'), placeholder: s('common_optional_placeholder'), value: this.password, isEnabled: !this.formBusy(), isPassword: true, change: (value: string) => {
          if (!this.formBusy()) {
            this.password = value
            this.draftEdited()
          }
        } })
        if (this.hasSavedBasicCredential) {
          Text(s('server_saved_credentials_hint'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      .width('100%')
    }
  }

  @Builder
  private FormActions() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      KomaActionButton({
        label: this.testing ? s('common_testing') : s('server_action_save_and_test'),
        kind: 'primary',
        fullWidth: true,
        isEnabled: !this.formBusy(),
        action: () => {
          this.saveAndTest()
        },
      })

      if (this.statusText().length > 0) {
        Text(this.statusText())
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }

      if (this.hasSavedConfig) {
        KomaActionButton({
          label: s('server_action_remove_config'),
          isEnabled: !this.formBusy(),
          kind: 'ghost',
          fullWidth: true,
          accentColor: ThemeConstants.DANGER,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.clearServer()
          },
        })
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        includeKeyboardPadding: true,
      }) {
        ListItem() {
          this.FormCard()
        }
        ListItem() {
          this.FormActions()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
