import { common } from '@kit.AbilityKit'
import { KeyboardAvoidMode } from '@kit.ArkUI'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { HistorySyncController, historySyncController } from '../historySync/HistorySyncController'
import { HistorySyncConfig } from '../historySync/WebDavHistorySync'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState } from '../state/LanguageState'
import { komaToastOptions } from '../theme/KomaPopupOptions'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct HistorySyncSettingsPage {
  @Local private sync: HistorySyncController = historySyncController
  @Local private syncEnabled: boolean = false
  @Local private directoryUrl: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private hydrated: boolean = false
  @Local private testing: boolean = false
  @Local private testStatus: string = ''
  @Local private saveStatus: string = ''
  private open: boolean = false
  private saveTimer: number = -1
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.open = true
    this.sync.startEditing()
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    void this.load()
  }

  aboutToDisappear(): void {
    this.open = false
    this.clearSaveTimer()
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET)
    if (this.hydrated) void this.save().finally((): void => { this.sync.finishEditing() })
    else this.sync.finishEditing()
  }

  private async load(): Promise<void> {
    await this.sync.initialize()
    if (!this.open || !this.sync.ready) return
    const config = this.sync.current()
    this.syncEnabled = config.enabled
    this.directoryUrl = config.directoryUrl
    this.username = config.username
    this.password = config.password
    this.hydrated = true
  }

  private clearSaveTimer(): void {
    if (this.saveTimer >= 0) clearTimeout(this.saveTimer)
    this.saveTimer = -1
  }

  private async save(): Promise<boolean> {
    const value: HistorySyncConfig = { enabled: this.syncEnabled, directoryUrl: this.directoryUrl,
      username: this.username, password: this.password }
    try {
      await this.sync.save(value)
      this.saveStatus = ''
      return true
    } catch (error) {
      this.saveStatus = (error as Error).message
      if (!this.open) this.toast(this.errorText(this.saveStatus))
      return false
    }
  }

  private changed(): void {
    this.testStatus = ''
    this.saveStatus = ''
    this.clearSaveTimer()
    this.saveTimer = setTimeout((): void => {
      this.saveTimer = -1
      void this.save()
    }, 500)
  }

  private async toggle(value: boolean): Promise<void> {
    if (this.syncEnabled === value || !this.hydrated || this.sync.busy) return
    this.syncEnabled = value
    this.clearSaveTimer()
    if (!await this.save() && this.syncEnabled === value) this.syncEnabled = this.sync.current().enabled
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast(komaToastOptions({ message }))
  }

  private async run(test: boolean): Promise<void> {
    if (this.sync.busy || this.testing || !this.hydrated || this.directoryUrl.trim().length === 0) return
    this.clearSaveTimer()
    this.testing = test
    try {
      if (!await this.save()) return
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const result = await this.sync.run(context, test)
      if (result === 'cancelled' || !this.open) return
      if (test) this.testStatus = result
      this.toast(result === 'ok' ? AppStrings.get(test ? 'history_sync_test_success' : 'history_sync_success') : this.errorText(result))
    } finally {
      this.testing = false
    }
  }

  private errorText(code: string): string {
    if (code === 'url') return AppStrings.get('history_sync_invalid_url')
    if (code === 'conditions' || code === 'cleanup') return AppStrings.get('history_sync_conditions')
    if (code === 'data' || code === 'size') return AppStrings.get('history_sync_invalid_data')
    if (code === 'conflict') return AppStrings.get('history_sync_conflict')
    if (code === 'config-size') return AppStrings.get('history_sync_config_size')
    if (code === 'storage') return AppStrings.get('history_sync_storage')
    if (code === 'http-401' || code === 'http-403') return AppStrings.get('history_sync_auth')
    if (code.startsWith('http-')) return AppStrings.format('history_sync_http', code.substring(5))
    return AppStrings.get('history_sync_network')
  }

  private syncSubtitle(): string {
    if (this.saveStatus.length > 0) return this.errorText(this.saveStatus)
    if (this.sync.busy && !this.testing) return AppStrings.get('history_sync_running')
    if (!this.syncEnabled) return AppStrings.get('history_sync_disabled')
    if (this.directoryUrl.trim().length === 0) return AppStrings.get('history_sync_address_required')
    if (this.sync.status === 'ok') {
      const locale = connectLanguageState().effectiveLocale
      const time = new Intl.DateTimeFormat(locale, {
        year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false,
      }).format(new Date(this.sync.lastSuccessAt))
      return AppStrings.format('history_sync_last', time)
    }
    if (this.sync.status.length > 0) return this.errorText(this.sync.status)
    return AppStrings.get('history_sync_never')
  }

  private testSubtitle(): string {
    if (this.testing) return AppStrings.get('history_sync_testing')
    if (this.testStatus === 'ok') return AppStrings.get('history_sync_test_success')
    return this.testStatus.length === 0 ? AppStrings.get('history_sync_test_hint') : this.errorText(this.testStatus)
  }

  @Builder
  private ProgressSuffix(test: boolean) {
    if ((test && this.testing) || (!test && this.sync.busy && !this.testing)) {
      LoadingProgress()
        .width(22)
        .height(22)
        .color(ThemeConstants.BRAND_PRIMARY)
    }
  }

  build() {
    SecondaryListScaffold({ scroller: this.scroller }) {
      if (this.hydrated) {
        ListItem() {
          GroupedListSection() {
            ConciseListRow({ title: AppStrings.get('history_sync_webdav'),
              subtitle: AppStrings.get('history_sync_scope'), leadingIcon: $r('sys.symbol.externaldrive'),
              hasSwitch: true, checked: this.syncEnabled, showChevron: false, isEnabled: !this.sync.busy && !this.testing,
              switchAction: (value: boolean): void => { void this.toggle(value) } })
            ListDivider()
            ConciseListRow({ title: AppStrings.get('history_sync_now'), subtitle: this.syncSubtitle(),
              leadingIcon: $r('sys.symbol.arrow_clockwise'), showChevron: false,
              isEnabled: this.syncEnabled && this.directoryUrl.trim().length > 0 && !this.sync.busy && !this.testing,
              action: (): void => { void this.run(false) }, suffixBuilderParam: () => { this.ProgressSuffix(false) } })
            ListDivider()
            ConciseListRow({ title: AppStrings.get('history_sync_test'), subtitle: this.testSubtitle(),
              leadingIcon: $r('sys.symbol.link'), showChevron: false,
              isEnabled: this.directoryUrl.trim().length > 0 && !this.sync.busy && !this.testing,
              action: (): void => { void this.run(true) }, suffixBuilderParam: () => { this.ProgressSuffix(true) } })
          }
        }
        ListItem() {
          GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
            Column({ space: ThemeConstants.SPACE_LG }) {
              KomaFormTextField({ label: AppStrings.get('history_sync_address'), placeholder: 'https://example.com/dav/',
                value: this.directoryUrl, isEnabled: !this.sync.busy && !this.testing,
                change: (value: string): void => { this.directoryUrl = value; this.changed() } })
              KomaFormTextField({ label: AppStrings.get('common_username'), value: this.username,
                placeholder: AppStrings.get('history_sync_optional'), isEnabled: !this.sync.busy && !this.testing,
                change: (value: string): void => { this.username = value; this.changed() } })
              KomaFormTextField({ label: AppStrings.get('common_password'), value: this.password, isPassword: true,
                placeholder: AppStrings.get('history_sync_optional'), isEnabled: !this.sync.busy && !this.testing,
                change: (value: string): void => { this.password = value; this.changed() } })
            }
            .width('100%')
          }
        }
      } else {
        ListItem() {
          GroupedListSection() {
            if (this.sync.loadFailed) {
              ConciseListRow({ title: AppStrings.get('history_sync_storage'), subtitle: AppStrings.get('history_sync_retry'),
                action: (): void => { void this.load() }, showChevron: false })
            } else {
              ConciseListRow({ title: AppStrings.get('history_sync_loading'), showChevron: false,
                suffixBuilderParam: () => { LoadingProgress().width(22).height(22) } })
            }
          }
        }
      }
    }
  }
}
