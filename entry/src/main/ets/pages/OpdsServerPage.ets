import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore, OpdsServerRecord, remoteServerDraftErrorKey } from '../model/RemoteServerStore'
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
      this.hasSavedConfig = await store.hasSavedConfiguration('opds')
      const saved = await store.loadOpds()
      if (saved === undefined) {
        if (this.hasSavedConfig) {
          this.setStatus('server_status_load_failed')
        }
        return
      }
      this.rootUrl = saved.server.rootUrl
     this.detectedVersion = saved.server.version === undefined ? '' : saved.server.version
      this.hasSavedBasicCredential = saved.server.credentialRef !== undefined &&
        saved.credential?.basicToken !== undefined && saved.credential.basicToken.length > 0
      console.info('[OPDS] step=settings_load configured=true')
    } catch (error) {
      void error
      this.setStatus('server_status_load_failed')
      console.error('[OPDS] step=settings_load_error reason=settings_load')
    } finally {
      this.loading = false
    }
  }

  private formBusy(): boolean {
    return this.loading || this.testing || this.removing
  }

  private draftEdited(): void {
    this.setStatus('')
    this.detectedVersion = ''
  }

  private async saveAndTest(): Promise<void> {
    if (this.formBusy()) {
      return
    }
    this.testing = true
    this.setStatus('')
    this.detectedVersion = ''
    try {
      const store = this.store()
      let record: OpdsServerRecord
      try {
        record = await store.saveOpds({
          rootUrl: this.rootUrl,
          username: this.username,
          password: this.password,
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
      console.info('[OPDS] step=test_connection_start')
      try {
        const catalog = await store.createOpdsClient(record).fetchCatalog()

        try {
          record = await store.saveOpds({
            rootUrl: this.rootUrl,
            username: this.username,
            password: this.password,
            preserveSavedCredentials: true,
            version: catalog.version,
          })
        } catch (error) {
          const key = remoteServerDraftErrorKey(error as Object)
          this.setStatus(key.length > 0 ? key : 'server_status_save_failed')
          return
        }
        this.detectedVersion = record.server.version === undefined ? '' : record.server.version
        this.setStatus('opds_status_success', [this.versionLabel(catalog.version), `${catalog.navigation.length}`, `${catalog.publications.length}`])
        this.showToast(s('opds_toast_success'))
        console.info(`[OPDS] step=test_connection_ok version=${catalog.version} navigation=${catalog.navigation.length} publications=${catalog.publications.length}`)
      } catch (error) {
        void error
        this.setStatus('opds_status_failed')
        console.error('[OPDS] step=test_connection_failed reason=connection_test')
        this.showToast(s('opds_toast_failed'))
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
      await this.store().clearOpds()
      this.rootUrl = ''
      this.username = ''
      this.password = ''
      this.detectedVersion = ''
      this.hasSavedConfig = false
      this.hasSavedBasicCredential = false
      this.setStatus('opds_status_removed')
      this.showToast(s('opds_toast_removed'))
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
        KomaFormTextField({ label: s('opds_label_catalog_url'), placeholder: 'https://demo.komga.org/opds/v2/catalog', value: this.rootUrl, isEnabled: !this.formBusy(), change: (value: string) => {
          if (!this.formBusy()) {
            this.rootUrl = value
            this.draftEdited()
          }
        } })
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

        Text(this.detectedVersion.length === 0
          ? s('opds_version_auto')
          : s('opds_version_value').replace('%s', this.versionLabel(this.detectedVersion)))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
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
