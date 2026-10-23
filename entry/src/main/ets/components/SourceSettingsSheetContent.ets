import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceSettingDescriptor, SourceSettingOption, SourceSettingValue, SourceSettingsRecord,
  appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaFormTextField } from './ui/KomaFormTextField'

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

  aboutToAppear(): void {
    this.settingDraft = this.initialDraft
  }

  private saveSettings(): void {
    if (this.settingsSourceId.length === 0) {
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
    const nextDraft: SourceSettingsRecord = {}
    Object.keys(this.settingDraft).forEach((key: string) => {
      nextDraft[key] = this.settingDraft[key]
    })
    nextDraft[id] = value
    this.settingDraft = nextDraft
  }

  private settingStringValue(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    return typeof value === 'string' ? value : ''
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
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
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
      if (descriptor.sensitive || !descriptor.supported) {
        ConciseListRow({
          title: descriptor.label,
          trailingText: descriptor.sensitive ? t('source_pkg_login_required') : t('source_pkg_unsupported'),
          showChevron: false,
        })
      } else if (descriptor.kind === 'boolean') {
        ConciseListRow({
          title: descriptor.label,
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
          trailingText: this.settingMultiSelectLabel(descriptor),
          trailingDropdown: true,
          dropdownMenuEnabled: true,
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
        KomaFormTextField({
          label: descriptor.label,
          value: this.settingStringValue(descriptor),
          change: (value: string) => {
            this.updateSettingValue(descriptor.id, value)
          },
        })
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
