import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct KavitaServerPage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private baseUrl: string = ''
  @Local private apiKey: string = ''
  @Local private testing: boolean = false
  @Local private statusKey: string = ''
  @Local private statusArgs: string[] = []

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadSaved()
  }

  private async loadSaved(): Promise<void> {
    try {
      const saved = await this.store().loadKavita()
      if (saved === undefined) {
        return
      }
      this.baseUrl = saved.server.baseUrl
      this.apiKey = saved.credential.apiKey
      console.info('[Kavita] step=settings_load configured=true')
    } catch (error) {
      void error
      this.setStatus('server_status_load_failed')
      console.error('[Kavita] step=settings_load_error reason=settings_load')
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
      const record = await store.saveKavita({
        baseUrl: this.baseUrl,
        apiKey: this.apiKey,
      })
      console.info('[Kavita] step=test_connection_start')
      const libraries = await store.createKavitaClient(record).listLibraries()
      this.setStatus('kavita_status_success', [`${libraries.length}`])
      console.info(`[Kavita] step=test_connection_ok libraries=${libraries.length}`)
      this.showToast(s('kavita_toast_success'))
    } catch (error) {
      void error
      this.setStatus('kavita_status_failed')
      console.error('[Kavita] step=test_connection_failed reason=connection_test')
      this.showToast(s('kavita_toast_failed'))
    } finally {
      this.testing = false
    }
  }

  private async clearServer(): Promise<void> {
    try {
      await this.store().clearKavita()
      this.baseUrl = ''
      this.apiKey = ''
      this.setStatus('kavita_status_removed')
      this.showToast(s('kavita_toast_removed'))
    } catch (error) {
      void error
      this.setStatus('server_status_load_failed')
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
        KomaFormTextField({ label: s('common_server_url'), placeholder: 'https://kavita.example.com', value: this.baseUrl, change: (value: string) => {
          this.baseUrl = value
        } })

        KomaFormTextField({ label: s('kavita_label_api_key'), placeholder: s('kavita_placeholder_api_key'), value: this.apiKey, isPassword: true, change: (value: string) => {
          this.apiKey = value
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
        bottomPadding: ThemeConstants.SPACE_XL,
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
