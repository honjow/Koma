import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../../i18n/AppStrings'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { SettingsFieldDescriptor, SettingsFieldOption, SettingsFieldValue } from '../../model/SettingsFormFields'
import { ConciseListRow } from './ConciseListRow'
import { KomaFormTextField } from './KomaFormTextField'

function t(name: string): string { return AppStrings.get(name) }

/** Shared native field renderer; each consumer retains validation, drafts and persistence. */
@ComponentV2
export struct SettingsFieldRow {
  @Param descriptor: SettingsFieldDescriptor = { id: '', label: '', kind: 'string', supported: true, sensitive: false }
  @Param value: SettingsFieldValue | undefined = undefined
  @Param errorMessage: string | undefined = undefined
  @Event onChange: (value: SettingsFieldValue) => void = () => {}
  private updateSettingValue(_id: string, value: SettingsFieldValue): void { this.onChange(value) }
  private settingStringValue(descriptor: SettingsFieldDescriptor): string {
    const value = this.value
    return typeof value === 'string' ? value : ''
  }

  private settingBooleanValue(descriptor: SettingsFieldDescriptor): boolean {
    return this.value === true
  }

  private settingNumberValue(descriptor: SettingsFieldDescriptor): number {
    const value = this.value
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    if (typeof descriptor.defaultValue === 'number' && Number.isFinite(descriptor.defaultValue)) {
      return this.normalizeRangeSetting(descriptor, descriptor.defaultValue)
    }
    return this.normalizeRangeSetting(descriptor, descriptor.minValue ?? 0)
  }

  private settingSelectLabel(descriptor: SettingsFieldDescriptor): string {
    const value = this.value
    const selected = typeof value === 'string' ? value : ''
    const option = descriptor.options?.find((item) => item.id === selected)
    return option?.label ?? (selected.length > 0 ? selected : t('source_pkg_not_selected'))
  }

  private settingMultiSelectValue(descriptor: SettingsFieldDescriptor): string[] {
    const value = this.value
    return Array.isArray(value) ? value : []
  }

  private settingMultiSelectLabel(descriptor: SettingsFieldDescriptor): string {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.length === 0) {
      return t('source_pkg_not_selected')
    }
    const labels: string[] = []
    selected.forEach((id: string) => {
      const option = descriptor.options?.find((item: SettingsFieldOption): boolean => item.id === id)
      labels.push(option?.label ?? id)
    })
    return labels.join(' / ')
  }

  private setSelectSetting(descriptor: SettingsFieldDescriptor, optionId: string): void {
    this.updateSettingValue(descriptor.id, optionId)
  }

  private toggleMultiSelectSetting(descriptor: SettingsFieldDescriptor, optionId: string): void {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.includes(optionId)) {
      this.updateSettingValue(descriptor.id, selected.filter((id: string): boolean => id !== optionId))
      return
    }
    const next = selected.slice()
    next.push(optionId)
    this.updateSettingValue(descriptor.id, next)
  }

  private rangeStep(descriptor: SettingsFieldDescriptor): number {
    return descriptor.step !== undefined && descriptor.step > 0 ? descriptor.step : 1
  }

  private rangeMin(descriptor: SettingsFieldDescriptor): number {
    return descriptor.minValue ?? 0
  }

  private rangeMax(descriptor: SettingsFieldDescriptor): number {
    const minValue = this.rangeMin(descriptor)
    const step = this.rangeStep(descriptor)
    const fallbackMax = Math.max(minValue + step, this.settingNumberValue(descriptor), minValue + step * 10)
    const maxValue = descriptor.maxValue ?? fallbackMax
    return maxValue > minValue ? maxValue : minValue + step
  }

  private normalizeRangeSetting(descriptor: SettingsFieldDescriptor, value: number): number {
    let next = Number.isFinite(value) ? value : 0
    if (descriptor.minValue !== undefined && next < descriptor.minValue) {
      next = descriptor.minValue
    }
    if (descriptor.maxValue !== undefined && next > descriptor.maxValue) {
      next = descriptor.maxValue
    }
    return next
  }

  private setRangeSetting(descriptor: SettingsFieldDescriptor, value: number): void {
    const next = this.normalizeRangeSetting(descriptor, value)
    this.updateSettingValue(descriptor.id, next)
  }

  @Builder
  private SettingSelectMenu(
    descriptor: SettingsFieldDescriptor,
    select: (action: () => void) => void,
  ) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SettingsFieldOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingStringValue(descriptor) === option.id ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            select(() => {
              this.setSelectSetting(descriptor, option.id)
            })
          })
      }, (option: SettingsFieldOption) => option.id)
    }
  }

  @Builder
  private SettingMultiSelectMenu(descriptor: SettingsFieldDescriptor) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SettingsFieldOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingMultiSelectValue(descriptor).includes(option.id) ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            this.toggleMultiSelectSetting(descriptor, option.id)
          })
      }, (option: SettingsFieldOption) => option.id)
    }
  }

  @Builder
  private SettingRangeRow(descriptor: SettingsFieldDescriptor) {
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
  private SettingRow(descriptor: SettingsFieldDescriptor) {
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
            validationError: this.errorMessage,
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

  build() { this.SettingRow(this.descriptor) }
}
