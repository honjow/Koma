import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceSettingDescriptor, SourceSettingOption, SourceSettingValue, SourceSettingsRecord,
  appSourceSettingsStore, sourceSettingValidationError } from '../sourceRuntime/SourceSettingsStore'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaFormTextField } from './ui/KomaFormTextField'
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
  @Event onSaved: (cleared: boolean) => void = () => {}
  @Event onClose: () => void = () => {}
  @Local private settingDraft: SourceSettingsRecord = {}
  @Local private regexErrors: Record<string, string> = {}
  @Local private regexCheckPending: boolean = false
  private regexCheckToken: number = 0
  private regexCheckRunning: boolean = false
  private regexCheckFailed: boolean = false
  private regexCheckDescriptor: SourceSettingDescriptor | undefined = undefined
  private regexCheckValue: string = ''
  private regexValidatedSourceId: string = ''
  private regexValidatedStoreRevision: string = ''

  aboutToAppear(): void {
    this.settingDraft = this.initialDraft
    const descriptor = this.settingDescriptors.find((item: SourceSettingDescriptor): boolean =>
      item.supported && !item.sensitive && item.validation?.kind === 'java_regex')
    if (descriptor !== undefined) this.queueRegexCheck(descriptor, this.settingStringValue(descriptor))
  }

  aboutToDisappear(): void {
    // Do not save a stale draft when native validation finishes after dismissal.
    this.regexCheckToken += 1
    this.regexCheckValue = ''
    this.regexCheckPending = false
  }

  private saveSettings(): void {
    if (this.settingsSourceId.length === 0 || this.hasInvalidSettings() || this.regexCheckPending) {
      return
    }
    if (this.regexCheckFailed) {
      DiagnosticLogger.warn('source_settings', 'java_regex', 'reason=execution_failed')
      this.getUIContext().getPromptAction().showToast({ message: t('source_pkg_reason_runtime_response_not_ok') })
      return
    }
    if (this.regexCheckDescriptor !== undefined &&
      (this.regexValidatedSourceId !== this.settingsSourceId ||
        this.regexValidatedStoreRevision !== appSourceSettingsStore.revisionForSource(this.settingsSourceId))) {
      DiagnosticLogger.warn('source_settings', 'java_regex', 'reason=stale_draft')
      this.getUIContext().getPromptAction().showToast({ message: t('source_pkg_reason_runtime_response_not_ok') })
      return
    }
    appSourceSettingsStore.saveForSource(this.settingsSourceId, this.settingDraft, this.settingDescriptors)
    this.getUIContext().getPromptAction().showToast({ message: t('source_pkg_settings_saved') })
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
    this.getUIContext().getPromptAction().showToast({ message: t('source_pkg_settings_cleared') })
    this.onSaved(true)
    this.onClose()
  }

  private confirmClearSavedSettings(): void {
    if (this.settingsSourceId.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('source_pkg_clear_settings_title'),
      message: tf('source_pkg_clear_settings_message', sourceDisplayName(this.settingsSourceId, this.settingsSourceName)),
      autoCancel: true,
      primaryButton: {
        value: t('source_pkg_clear_settings'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearSavedSettings()
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
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

  private settingBooleanValue(descriptor: SourceSettingDescriptor): boolean {
    return this.settingDraft[descriptor.id] === true
  }

  private settingNumberValue(descriptor: SourceSettingDescriptor): number {
    const value = this.settingDraft[descriptor.id]
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    if (typeof descriptor.defaultValue === 'number' && Number.isFinite(descriptor.defaultValue)) {
      return this.normalizeRangeSetting(descriptor, descriptor.defaultValue)
    }
    return this.normalizeRangeSetting(descriptor, descriptor.minValue ?? 0)
  }

  private settingSelectLabel(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    const selected = typeof value === 'string' ? value : ''
    const option = descriptor.options?.find((item) => item.id === selected)
    return option?.label ?? (selected.length > 0 ? selected : t('source_pkg_not_selected'))
  }

  private settingMultiSelectValue(descriptor: SourceSettingDescriptor): string[] {
    const value = this.settingDraft[descriptor.id]
    return Array.isArray(value) ? value : []
  }

  private settingMultiSelectLabel(descriptor: SourceSettingDescriptor): string {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.length === 0) {
      return t('source_pkg_not_selected')
    }
    const labels: string[] = []
    selected.forEach((id: string) => {
      const option = descriptor.options?.find((item: SourceSettingOption): boolean => item.id === id)
      labels.push(option?.label ?? id)
    })
    return labels.join(' / ')
  }

  private setSelectSetting(descriptor: SourceSettingDescriptor, optionId: string): void {
    this.updateSettingValue(descriptor.id, optionId)
  }

  private toggleMultiSelectSetting(descriptor: SourceSettingDescriptor, optionId: string): void {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.includes(optionId)) {
      this.updateSettingValue(descriptor.id, selected.filter((id: string): boolean => id !== optionId))
      return
    }
    const next = selected.slice()
    next.push(optionId)
    this.updateSettingValue(descriptor.id, next)
  }

  private rangeStep(descriptor: SourceSettingDescriptor): number {
    return descriptor.step !== undefined && descriptor.step > 0 ? descriptor.step : 1
  }

  private rangeMin(descriptor: SourceSettingDescriptor): number {
    return descriptor.minValue ?? 0
  }

  private rangeMax(descriptor: SourceSettingDescriptor): number {
    const minValue = this.rangeMin(descriptor)
    const step = this.rangeStep(descriptor)
    const fallbackMax = Math.max(minValue + step, this.settingNumberValue(descriptor), minValue + step * 10)
    const maxValue = descriptor.maxValue ?? fallbackMax
    return maxValue > minValue ? maxValue : minValue + step
  }

  private normalizeRangeSetting(descriptor: SourceSettingDescriptor, value: number): number {
    let next = Number.isFinite(value) ? value : 0
    if (descriptor.minValue !== undefined && next < descriptor.minValue) {
      next = descriptor.minValue
    }
    if (descriptor.maxValue !== undefined && next > descriptor.maxValue) {
      next = descriptor.maxValue
    }
    return next
  }

  private setRangeSetting(descriptor: SourceSettingDescriptor, value: number): void {
    const next = this.normalizeRangeSetting(descriptor, value)
    this.updateSettingValue(descriptor.id, next)
  }

  @Builder
  private SettingSelectMenu(
    descriptor: SourceSettingDescriptor,
    select: (action: () => void) => void,
  ) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SourceSettingOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingStringValue(descriptor) === option.id ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            select(() => {
              this.setSelectSetting(descriptor, option.id)
            })
          })
      }, (option: SourceSettingOption) => option.id)
    }
  }

  @Builder
  private SettingMultiSelectMenu(descriptor: SourceSettingDescriptor) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SourceSettingOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingMultiSelectValue(descriptor).includes(option.id) ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            this.toggleMultiSelectSetting(descriptor, option.id)
          })
      }, (option: SourceSettingOption) => option.id)
    }
  }

  @Builder
  private SettingRangeRow(descriptor: SourceSettingDescriptor) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(descriptor.label)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2147483647)
          .textOverflow({ overflow: TextOverflow.Clip })
        if ((descriptor.description?.length ?? 0) > 0) {
          Text(descriptor.description ?? '')
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        Text(`${this.settingNumberValue(descriptor)}`)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Slider({
        value: this.settingNumberValue(descriptor),
        min: this.rangeMin(descriptor),
        max: this.rangeMax(descriptor),
        step: this.rangeStep(descriptor),
      })
        .width('100%')
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .onChange((value: number) => {
          this.setRangeSetting(descriptor, value)
        })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SettingRow(descriptor: SourceSettingDescriptor) {
    Column() {
      // Source-provided labels and instructions must remain readable regardless
      // of setting kind; the native row and its actions still own the layout.
      if (descriptor.sensitive || !descriptor.supported) {
        ConciseListRow({
          title: descriptor.label,
          wrapTitle: true,
          wrapTitleByWord: true,
          subtitle: descriptor.description ?? '',
          subtitleMaxLines: 2147483647,
          trailingText: descriptor.sensitive ? t('source_pkg_login_required') : t('source_pkg_unsupported'),
          showChevron: false,
        })
      } else if (descriptor.kind === 'boolean') {
        ConciseListRow({
          title: descriptor.label,
          wrapTitle: true,
          wrapTitleByWord: true,
          subtitle: descriptor.description ?? '',
          subtitleMaxLines: 2147483647,
          showChevron: false,
          hasSwitch: true,
          checked: this.settingBooleanValue(descriptor),
          switchAction: (isOn: boolean) => {
            this.updateSettingValue(descriptor.id, isOn)
          },
        })
      } else if (descriptor.kind === 'select') {
        ConciseListRow({
          title: descriptor.label,
          wrapTitle: true,
          wrapTitleByWord: true,
          subtitle: descriptor.description ?? '',
          subtitleMaxLines: 2147483647,
          trailingText: this.settingSelectLabel(descriptor),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
          dropdownMenuBuilder: (select: (action: () => void) => void) => {
            this.SettingSelectMenu(descriptor, select)
          },
        })
      } else if (descriptor.kind === 'multiselect') {
        ConciseListRow({
          title: descriptor.label,
          wrapTitle: true,
          wrapTitleByWord: true,
          // Keep the explanation after learned choices appear as well. An
          // empty learned set still has no working dropdown.
          subtitle: descriptor.description ?? '',
          subtitleMaxLines: 2147483647,
          trailingText: this.settingMultiSelectLabel(descriptor),
          showChevron: false,
          trailingDropdown: (descriptor.options?.length ?? 0) > 0,
          dropdownMenuEnabled: (descriptor.options?.length ?? 0) > 0,
          dropdownMenuBuilder: (_select: (action: () => void) => void) => {
            // Multi-select stays open while options are toggled. The row still
            // owns the anchor and dismissal state through ConciseListRow.
            this.SettingMultiSelectMenu(descriptor)
          },
        })
      } else if (descriptor.kind === 'range') {
        this.SettingRangeRow(descriptor)
      } else if (descriptor.kind === 'group') {
        ConciseListRow({
          title: descriptor.label,
          subtitle: (descriptor.children ?? []).join(' / '),
          showChevron: false,
        })
      } else {
        Column({ space: ThemeConstants.SPACE_XS }) {
          KomaFormTextField({
            label: descriptor.label,
            wrapLabel: true,
            value: this.settingStringValue(descriptor),
            validationError: this.settingValidationError(descriptor),
            change: (value: string) => {
              this.updateSettingValue(descriptor.id, value)
            },
          })
          // Source-defined input syntax must remain readable after entering a
          // value; a placeholder would hide it and truncate longer instructions.
          if ((descriptor.description?.length ?? 0) > 0) {
            Text(descriptor.description ?? '')
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
        }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      }
    }
    .width('100%')
  }

  build() {
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
      if (this.settingDescriptors.length === 0) {
        Text(t('source_pkg_no_settings'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      } else {
        GroupedListSection({ inset: ThemeConstants.SPACE_SM }) {
          ForEach(this.settingDescriptors, (descriptor: SourceSettingDescriptor, index: number) => {
            this.SettingRow(descriptor)
            if (index < this.settingDescriptors.length - 1) {
              ListDivider()
            }
          }, (descriptor: SourceSettingDescriptor) => descriptor.id)
        }
      }

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
      Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
  }

}
