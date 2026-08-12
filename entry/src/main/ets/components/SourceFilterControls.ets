import { SymbolGlyphModifier } from '@kit.ArkUI'
import { KomaActionButton } from './ui/KomaActionButton'
import { ConciseListRow } from './ui/ConciseListRow'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'

export type SourceFilterControlValue = string | number | boolean | string[]
export type SourceFilterControlValues = Record<string, SourceFilterControlValue>

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct SourceFilterControls {
  @Param filters: SourceFilter[] = []
  @Param values: SourceFilterControlValues = {}
  @Param busy: boolean = false
  @Param vertical: boolean = false
  @Local private activeFilterMenuId: string = ''
  @Local private pendingTextFilters: Record<string, string> = {}
  @Event onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => void =
    (_filter: SourceFilter, _value: SourceFilterControlValue | undefined) => {}
  @Event onReset: () => void = () => {}

  private filterRequestKey(filter: SourceFilter): string {
    return filter.id.startsWith('filter:') ? filter.id.substring('filter:'.length) : filter.id
  }

  private currentFilterValue(filter: SourceFilter): SourceFilterControlValue | undefined {
    return this.values[this.filterRequestKey(filter)]
  }

  private filterOptionValue(filter: SourceFilter, index: number): string {
    const optionIds = filter.optionIds ?? []
    const options = filter.options ?? []
    const raw = optionIds[index] ?? options[index] ?? ''
    const keyPrefix = `${this.filterRequestKey(filter)}:`
    return raw.startsWith(keyPrefix) ? raw.substring(keyPrefix.length) : raw
  }

  private filterButtonLabel(filter: SourceFilter): string {
    const value = this.currentFilterValue(filter)
    if (value === undefined) {
      return filter.name
    }
    if (Array.isArray(value)) {
      if (value.length === 0) {
        return filter.name
      }
      const labels: string[] = []
      value.forEach((item: string) => {
        labels.push(this.filterOptionLabel(filter, item))
      })
      return `${filter.name}: ${labels.join(' / ')}`
    }
    return `${filter.name}: ${this.filterOptionLabel(filter, `${value}`)}`
  }

  private filterOptionLabel(filter: SourceFilter, valueText: string): string {
    const optionIds = filter.optionIds ?? []
    const options = filter.options ?? []
    for (let index = 0; index < optionIds.length || index < options.length; index += 1) {
      if (this.filterOptionValue(filter, index) === valueText) {
        return options[index] ?? valueText
      }
    }
    return valueText
  }

  private pendingTextFilterValue(filter: SourceFilter): string {
    const key = this.filterRequestKey(filter)
    const pending = this.pendingTextFilters[key]
    if (pending !== undefined) {
      return pending
    }
    const value = this.currentFilterValue(filter)
    return typeof value === 'string' ? value : ''
  }

  private setPendingTextFilterValue(filter: SourceFilter, value: string): void {
    const key = this.filterRequestKey(filter)
    const next: Record<string, string> = {}
    Object.keys(this.pendingTextFilters).forEach((itemKey: string) => {
      next[itemKey] = this.pendingTextFilters[itemKey]
    })
    next[key] = value
    this.pendingTextFilters = next
  }

  private multiSelectFilterValue(filter: SourceFilter): string[] {
    const value = this.currentFilterValue(filter)
    return Array.isArray(value) ? value : []
  }

  private isFilterOptionSelected(filter: SourceFilter, index: number): boolean {
    const optionValue = this.filterOptionValue(filter, index)
    const value = this.currentFilterValue(filter)
    if (Array.isArray(value)) {
      return value.includes(optionValue)
    }
    return `${value ?? ''}` === optionValue
  }

  private toggleMultiSelectFilter(filter: SourceFilter, index: number): void {
    const optionValue = this.filterOptionValue(filter, index)
    const selected = this.multiSelectFilterValue(filter)
    if (selected.includes(optionValue)) {
      this.onFilterChange(filter, selected.filter((item: string): boolean => item !== optionValue))
      return
    }
    const next = selected.slice()
    next.push(optionValue)
    this.onFilterChange(filter, next)
  }

  private rangeStep(filter: SourceFilter): number {
    return filter.step !== undefined && filter.step > 0 ? filter.step : 1
  }

  private rangeMin(filter: SourceFilter): number {
    return filter.minValue ?? 0
  }

  private rangeMax(filter: SourceFilter): number {
    const minValue = this.rangeMin(filter)
    const step = this.rangeStep(filter)
    const value = this.rangeValue(filter)
    const fallbackMax = Math.max(minValue + step, value, minValue + step * 10)
    const maxValue = filter.maxValue ?? fallbackMax
    return maxValue > minValue ? maxValue : minValue + step
  }

  private rangeValue(filter: SourceFilter): number {
    const value = this.currentFilterValue(filter)
    if (typeof value === 'number' && Number.isFinite(value)) {
      return this.normalizeRangeValue(filter, value)
    }
    if (typeof filter.value === 'number' && Number.isFinite(filter.value)) {
      return this.normalizeRangeValue(filter, filter.value)
    }
    return this.normalizeRangeValue(filter, this.rangeMin(filter))
  }

  private normalizeRangeValue(filter: SourceFilter, value: number): number {
    let next = Number.isFinite(value) ? value : this.rangeMin(filter)
    if (filter.minValue !== undefined && next < filter.minValue) {
      next = filter.minValue
    }
    if (filter.maxValue !== undefined && next > filter.maxValue) {
      next = filter.maxValue
    }
    return next
  }

  private setRangeFilter(filter: SourceFilter, value: number): void {
    this.onFilterChange(filter, this.normalizeRangeValue(filter, value))
  }

  private filterSelectionLabel(filter: SourceFilter): string {
    const value = this.currentFilterValue(filter)
    if (value === undefined) {
      return s('common_all')
    }
    if (Array.isArray(value)) {
      if (value.length === 0) {
        return s('common_all')
      }
      const labels: string[] = []
      value.forEach((item: string) => {
        labels.push(this.filterOptionLabel(filter, item))
      })
      return labels.join(' / ')
    }
    return this.filterOptionLabel(filter, `${value}`)
  }

  private hasActiveFilters(): boolean {
    return this.filters.some((filter: SourceFilter): boolean => {
      const value = this.currentFilterValue(filter)
      return value !== undefined && (!Array.isArray(value) || value.length > 0)
    })
  }

  @Builder
  private FilterOptionMenu(filter: SourceFilter) {
    Menu() {
      MenuItem({ content: s('common_all') })
        .onClick(() => {
          this.activeFilterMenuId = ''
          this.onFilterChange(filter, undefined)
        })
      ForEach(filter.options ?? [], (option: string, index: number) => {
        MenuItem({
          content: option,
          symbolEndIcon: this.isFilterOptionSelected(filter, index) ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            if (filter.type === 'multiselect') {
              this.toggleMultiSelectFilter(filter, index)
            } else {
              this.activeFilterMenuId = ''
              this.onFilterChange(filter, this.filterOptionValue(filter, index))
            }
          })
      }, (option: string, index: number) => `${filter.id}:${index}:${option}`)
    }
  }

  @Builder
  private VerticalFilterRow(filter: SourceFilter) {
    if (filter.type === 'check') {
      ConciseListRow({
        title: filter.name,
        hasSwitch: true,
        checked: this.currentFilterValue(filter) === true,
        showChevron: false,
        switchAction: (isOn: boolean) => {
          this.onFilterChange(filter, isOn ? true : undefined)
        },
      })
    } else if (filter.type === 'text') {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(filter.name)
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        TextInput({
          placeholder: filter.name,
          text: this.pendingTextFilterValue(filter),
        })
          .width('100%')
          .height(ThemeConstants.INPUT_HEIGHT)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onChange((value: string) => {
            this.setPendingTextFilterValue(filter, value)
          })
          .onSubmit(() => {
            const value = this.pendingTextFilterValue(filter).trim()
            this.onFilterChange(filter, value.length > 0 ? value : undefined)
          })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_MD)
    } else if (filter.type === 'range') {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row() {
          Text(filter.name)
            .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(`${this.rangeValue(filter)}`)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        Slider({
          value: this.rangeValue(filter),
          min: this.rangeMin(filter),
          max: this.rangeMax(filter),
          step: this.rangeStep(filter),
        })
          .width('100%')
          .selectedColor(ThemeConstants.BRAND_PRIMARY)
          .onChange((value: number) => {
            this.setRangeFilter(filter, value)
          })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_MD)
    } else if ((filter.options ?? []).length > 0) {
      Column() {
        ConciseListRow({
          title: filter.name,
          trailingText: this.filterSelectionLabel(filter),
          trailingDropdown: true,
          action: () => {
            this.activeFilterMenuId = filter.id
          },
        })
      }
      .bindMenu(this.activeFilterMenuId === filter.id, this.FilterOptionMenu(filter), {
        placement: Placement.BottomLeft,
        onDisappear: () => {
          this.activeFilterMenuId = ''
        },
      })
    }
  }

  @Builder
  private VerticalControls() {
    Column() {
      ForEach(this.filters, (filter: SourceFilter, index: number) => {
        this.VerticalFilterRow(filter)
        if (index < this.filters.length - 1) {
          Divider()
            .strokeWidth(0.5)
            .color(ThemeConstants.DIVIDER)
            .margin({ left: ThemeConstants.SPACE_LG })
        }
      }, (filter: SourceFilter) => filter.id)
    }
    .width('100%')
  }

  build() {
    if (this.filters.length > 0) {
      if (this.vertical) {
        this.VerticalControls()
      } else {
        Scroll() {
        Row({ space: ThemeConstants.SPACE_SM }) {
          ForEach(this.filters, (filter: SourceFilter) => {
            if (filter.type === 'check') {
              Row({ space: ThemeConstants.SPACE_SM }) {
                Text(filter.name)
                  .fontSize(ThemeConstants.FONT_SIZE_TAG)
                  .fontColor(ThemeConstants.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Toggle({ type: ToggleType.Switch, isOn: this.currentFilterValue(filter) === true })
                  .selectedColor(ThemeConstants.BRAND_PRIMARY)
                  .onChange((isOn: boolean) => {
                    this.onFilterChange(filter, isOn ? true : undefined)
                  })
              }
              .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
              .height(ThemeConstants.ACTION_CHIP_HEIGHT)
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor(ThemeConstants.CARD)
            } else if (filter.type === 'text') {
              TextInput({
                placeholder: filter.name,
                text: this.pendingTextFilterValue(filter),
              })
                .width(180)
                .height(ThemeConstants.ACTION_CHIP_HEIGHT)
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .backgroundColor(ThemeConstants.CARD)
                .borderRadius(ThemeConstants.RADIUS_ROUND)
                .onChange((value: string) => {
                  this.setPendingTextFilterValue(filter, value)
                })
                .onSubmit(() => {
                  const value = this.pendingTextFilterValue(filter).trim()
                  this.onFilterChange(filter, value.length > 0 ? value : undefined)
                })
            } else if (filter.type === 'range') {
              Column({ space: ThemeConstants.SPACE_XS }) {
                Row({ space: ThemeConstants.SPACE_SM }) {
                  Text(filter.name)
                    .fontSize(ThemeConstants.FONT_SIZE_TAG)
                    .fontColor(ThemeConstants.TEXT_PRIMARY)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(`${this.rangeValue(filter)}`)
                    .fontSize(ThemeConstants.FONT_SIZE_META)
                    .fontColor(ThemeConstants.TEXT_SECONDARY)
                }
                .width('100%')

                Slider({
                  value: this.rangeValue(filter),
                  min: this.rangeMin(filter),
                  max: this.rangeMax(filter),
                  step: this.rangeStep(filter),
                })
                  .width('100%')
                  .selectedColor(ThemeConstants.BRAND_PRIMARY)
                  .onChange((value: number) => {
                    this.setRangeFilter(filter, value)
                  })
              }
              .width(200)
              .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
              .height(ThemeConstants.ACTION_CHIP_HEIGHT * 2)
              .borderRadius(ThemeConstants.RADIUS_CHIP)
              .backgroundColor(ThemeConstants.CARD)
            } else if ((filter.options ?? []).length > 0) {
              KomaActionButton({
                label: this.filterButtonLabel(filter),
                kind: this.currentFilterValue(filter) === undefined ? 'secondary' : 'primary',
                compact: true,
                controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
                action: () => {
                  this.activeFilterMenuId = filter.id
                },
              })
                .bindMenu(this.activeFilterMenuId === filter.id, this.FilterOptionMenu(filter), {
                  placement: Placement.BottomLeft,
                  onDisappear: () => {
                    this.activeFilterMenuId = ''
                  },
                })
            }
          }, (filter: SourceFilter) => filter.id)
          KomaActionButton({
            label: s('common_reset'),
            kind: 'secondary',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: !this.busy,
            action: () => {
              this.pendingTextFilters = {}
              this.onReset()
            },
          })
        }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
    }
  }
}
