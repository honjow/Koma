import { komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceAuthenticationRequest } from '../sourceRuntime/SourceAuthenticationService'
import { SourceSettingDescriptor, SourceSettingOption, SourceSettingValue, SourceSettingsRecord,
  appSourceSettingsStore, sourceSettingIsVisible, sourceSettingValidationError } from '../sourceRuntime/SourceSettingsStore'
import { KomaModalScaffold } from './KomaModalScaffold'
import { SourceAuthenticationSheetHost } from './SourceAuthenticationSheetHost'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'
import { SettingsFieldRow } from './ui/SettingsFieldRow'
import { NativeSourceRuntime } from '../sourceRuntime/NativeSourceRuntime'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

function t(name: string): string { return AppStrings.get(name) }
function tf(name: string, ...args: Array<string | number>): string { return AppStrings.format(name, ...args) }

export function sourceSettingsDraft(descriptors: SourceSettingDescriptor[], saved: SourceSettingsRecord): SourceSettingsRecord {
  const draft: SourceSettingsRecord = {}
  descriptors.forEach((descriptor: SourceSettingDescriptor) => {
    if (!descriptor.supported || descriptor.sensitive) return
    const value = saved[descriptor.id]
    if (value !== undefined) draft[descriptor.id] = value
    else if (descriptor.defaultValue !== undefined) draft[descriptor.id] = descriptor.defaultValue
  })
  return draft
}

/** The same form is used by the manager and the current source route. */
@ComponentV2
export struct SourceSettingsSheetContent {
  @Param settingsSourceId: string = ''
  @Param settingsSourceName: string = ''
  @Param settingDescriptors: SourceSettingDescriptor[] = []
  @Param initialDraft: SourceSettingsRecord = {}
  @Param authenticationAvailable: boolean = false
  @Param active: boolean = false
  @Event onSaved: (cleared: boolean) => void = () => {}
  @Event onClose: () => void = () => {}
  @Event onAuthenticationChanged: () => void = () => {}
  @Local private settingDraft: SourceSettingsRecord = {}
  @Local private authentication: SourceAuthenticationRequest | null = null
  @Local private regexErrors: Record<string, string> = {}
  @Local private regexCheckPending: boolean = false
  private regexCheckToken: number = 0
  private regexCheckRunning: boolean = false
  private regexCheckFailed: boolean = false
  private regexCheckDescriptor: SourceSettingDescriptor | undefined = undefined
  private regexCheckValue: string = ''
  private regexValidatedSourceId: string = ''
  private regexValidatedStoreRevision: string = ''
  private mounted: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    this.settingDraft = this.initialDraft
    const descriptor = this.settingDescriptors.find((item: SourceSettingDescriptor): boolean =>
      item.supported && !item.sensitive && item.validation?.kind === 'java_regex')
    if (descriptor !== undefined) this.queueRegexCheck(descriptor, this.settingStringValue(descriptor))
  }

  aboutToDisappear(): void {
    this.mounted = false
    // Do not save a stale draft when native validation finishes after dismissal.
    this.regexCheckToken += 1
    this.regexCheckValue = ''
    this.regexCheckPending = false
  }

  private openAuthentication(): void {
    if (!this.mounted || !this.active || !this.authenticationAvailable || this.authentication !== null) return
    const sourceId = this.settingsSourceId
    const request: SourceAuthenticationRequest = new SourceAuthenticationRequest(sourceId,
      (): boolean => this.mounted && this.active && this.settingsSourceId === sourceId && this.authentication === request,
      async (): Promise<void> => { if (this.authentication === request) this.authentication = null },
      (): void => { if (this.authentication === request) this.authentication = null })
    this.authentication = request
  }

  private saveSettings(): void {
    if (this.settingsSourceId.length === 0 || this.hasInvalidSettings() || this.regexCheckPending) {
      return
    }
    if (this.regexCheckFailed) {
      DiagnosticLogger.warn('source_settings', 'java_regex', 'reason=execution_failed')
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('source_pkg_reason_runtime_response_not_ok') }))
      return
    }
    if (this.regexCheckDescriptor !== undefined &&
      (this.regexValidatedSourceId !== this.settingsSourceId ||
        this.regexValidatedStoreRevision !== appSourceSettingsStore.revisionForSource(this.settingsSourceId))) {
      DiagnosticLogger.warn('source_settings', 'java_regex', 'reason=stale_draft')
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('source_pkg_reason_runtime_response_not_ok') }))
      return
    }
    appSourceSettingsStore.saveForSource(this.settingsSourceId, this.settingDraft, this.settingDescriptors)
    this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('source_pkg_settings_saved') }))
    this.onSaved(false)
    this.onClose()
  }

  private clearSavedSettings(): void {
    if (this.settingsSourceId.length === 0) {
      return
    }
    this.regexCheckToken += 1
    this.regexCheckValue = ''
    this.regexCheckPending = false
    appSourceSettingsStore.removeSource(this.settingsSourceId)
    this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: t('source_pkg_settings_cleared') }))
    this.onSaved(true)
    this.onClose()
  }

  private confirmClearSavedSettings(): void {
    if (this.settingsSourceId.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: t('source_pkg_clear_settings_title'),
      message: tf('source_pkg_clear_settings_message', sourceDisplayName(this.settingsSourceId, this.settingsSourceName)),
      autoCancel: true,
      primaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: t('source_pkg_clear_settings'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearSavedSettings()
        },
      },
    })
  }

  private updateSettingValue(id: string, value: SourceSettingValue): void {
    if (this.regexErrors[id] !== undefined) this.setRegexError(id, '')
    const nextDraft: SourceSettingsRecord = {}
    Object.keys(this.settingDraft).forEach((key: string) => {
      nextDraft[key] = this.settingDraft[key]
    })
    nextDraft[id] = value
    this.settingDraft = nextDraft
    const descriptor = this.settingDescriptors.find((item: SourceSettingDescriptor): boolean => item.id === id)
    if (descriptor?.validation?.kind === 'java_regex' && typeof value === 'string') {
      this.queueRegexCheck(descriptor, value)
    }
  }

  private queueRegexCheck(descriptor: SourceSettingDescriptor, value: string): void {
    this.regexCheckToken += 1
    this.regexCheckDescriptor = descriptor
    this.regexCheckValue = value
    this.regexCheckFailed = false
    this.regexCheckPending = value.length > 0
    this.regexValidatedSourceId = this.settingsSourceId
    this.regexValidatedStoreRevision = appSourceSettingsStore.revisionForSource(this.settingsSourceId)
    if (value.length > 0 && !this.regexCheckRunning) this.validateRegexDraft()
  }

  private async validateRegexDraft(): Promise<void> {
    this.regexCheckRunning = true
    try {
      while (this.regexCheckValue.length > 0 && this.regexCheckDescriptor !== undefined) {
        const descriptor = this.regexCheckDescriptor
        const value = this.regexCheckValue
        const token = this.regexCheckToken
        const sourceId = this.settingsSourceId
        const storeRevision = appSourceSettingsStore.revisionForSource(sourceId)
        try {
          const result = await NativeSourceRuntime.javaRegex(value, [])
          if (token !== this.regexCheckToken) continue
          if (sourceId !== this.settingsSourceId || storeRevision !== appSourceSettingsStore.revisionForSource(sourceId)) {
            this.regexCheckFailed = true
            this.regexCheckPending = false
            return
          }
          this.regexCheckFailed = !result.ok
          this.regexValidatedSourceId = sourceId
          this.regexValidatedStoreRevision = storeRevision
          if (result.ok && !result.data.valid) this.setRegexError(descriptor.id, descriptor.validation?.message ?? '')
        } catch (_error) {
          if (token !== this.regexCheckToken) continue
          if (sourceId !== this.settingsSourceId || storeRevision !== appSourceSettingsStore.revisionForSource(sourceId)) {
            this.regexCheckFailed = true
            this.regexCheckPending = false
            return
          }
          this.regexCheckFailed = true
        }
        if (token === this.regexCheckToken) { this.regexCheckPending = false; return }
      }
    } finally {
      this.regexCheckRunning = false
    }
  }

  private setRegexError(id: string, message: string): void {
    const errors: Record<string, string> = {}
    Object.keys(this.regexErrors).forEach((key: string) => {
      if (key !== id) errors[key] = this.regexErrors[key]
    })
    if (message.length > 0) errors[id] = message
    this.regexErrors = errors
  }

  private settingStringValue(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    return typeof value === 'string' ? value : ''
  }

  private settingValidationError(descriptor: SourceSettingDescriptor): string | undefined {
    if (descriptor.validation?.kind === 'java_regex') return this.regexErrors[descriptor.id]
    const error = sourceSettingValidationError(descriptor, this.settingDraft[descriptor.id])
    if (error === undefined) return undefined
    return descriptor.validation?.kind === 'uuid_list' ? t('source_pkg_invalid_uuid_list') : error
  }

  private hasInvalidSettings(): boolean {
    return this.settingDescriptors.some((descriptor: SourceSettingDescriptor): boolean =>
      descriptor.supported && !descriptor.sensitive && this.settingValidationError(descriptor) !== undefined)
  }

  @Computed
  private get visibleDescriptors(): SourceSettingDescriptor[] {
    // Only the presentation changes. Keep hidden preferences in the draft and on disk.
    return this.settingDescriptors.filter((descriptor: SourceSettingDescriptor): boolean =>
      sourceSettingIsVisible(descriptor, this.settingDraft))
  }


  @Builder
  private SettingsContent() {
    KomaModalScaffold({
      title: t('source_pkg_settings_title'),
      subtitle: sourceDisplayName(this.settingsSourceId, this.settingsSourceName),
      onClose: () => {
        this.regexCheckToken += 1
        this.regexCheckValue = ''
        this.regexCheckPending = false
        this.onClose()
      },
    }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
      if (this.authenticationAvailable) {
        GroupedListSection({ inset: ThemeConstants.SPACE_SM }) {
          ConciseListRow({ title: t('source_account_settings'), leadingIcon: $r('sys.symbol.person'),
            action: () => { this.openAuthentication() } })
        }
      }
      if (this.visibleDescriptors.length === 0 && (!this.authenticationAvailable || this.settingDescriptors.length > 0)) {
        Text(t('source_pkg_no_settings'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      } else if (this.visibleDescriptors.length > 0) {
        GroupedListSection({ inset: ThemeConstants.SPACE_SM }) {
          ForEach(this.visibleDescriptors, (descriptor: SourceSettingDescriptor, index: number) => {
            SettingsFieldRow({ descriptor, value: this.settingDraft[descriptor.id],
              errorMessage: this.settingValidationError(descriptor),
              onChange: (value: SourceSettingValue): void => { this.updateSettingValue(descriptor.id, value) } })
            if (index < this.visibleDescriptors.length - 1) {
              ListDivider()
            }
          }, (descriptor: SourceSettingDescriptor) => descriptor.id)
        }
      }

      if (!this.authenticationAvailable || this.settingDescriptors.length > 0) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        KomaActionButton({
          label: t('source_pkg_save_settings'),
          kind: 'primary',
          fullWidth: true,
          isEnabled: !this.hasInvalidSettings() && !this.regexCheckPending,
          action: () => {
            this.saveSettings()
          },
        })
        KomaActionButton({
          label: t('source_pkg_clear_settings'),
          kind: 'ghost',
          fullWidth: true,
          accentColor: ThemeConstants.DANGER,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.confirmClearSavedSettings()
          },
        })
      }
      .width('100%')
      }
      Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    }
  }

  build() {
    if (this.authentication !== null) {
      // Keep the draft in this owner while authentication uses the same sheet and the saved settings snapshot.
      SourceAuthenticationSheetHost({ request: this.authentication, active: this.active, inSettings: true,
        onAuthenticationChanged: () => { this.onAuthenticationChanged() } })
    } else {
      this.SettingsContent()
    }
  }
}
