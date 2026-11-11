import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { GroupedListSection } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter } from '../model/SourceModels'
import { SourceFilterControls, SourceFilterControlValue, SourceFilterControlValues } from './SourceFilterControls'

@ComponentV2
export struct SourceFiltersSheetScaffold {
  @Param title: ResourceStr = ''
  @Param resetLabel: ResourceStr = ''
  @Param showReset: boolean = false
  @Param resetEnabled: boolean = true
  @Param filters: SourceFilter[] = []
  @Param values: SourceFilterControlValues = {}
  @Param optionsLoading: boolean = false
  @Event onClose: () => void = () => {}
  @Event onReset: () => void = () => {}
  @Event onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => void =
    (_filter: SourceFilter, _value: SourceFilterControlValue | undefined) => {}
  @Event onApplyText: (changes: Record<string, string>) => void = (_changes: Record<string, string>) => {}
  @Local private textDraft: Record<string, string> = {}

  private applyText(): void {
    if (!this.resetEnabled || Object.keys(this.textDraft).length === 0) return
    this.onApplyText(this.textDraft)
    this.textDraft = {}
    this.onClose()
  }

  build() {
    KomaModalScaffold({
      title: this.title,
      // Other controls keep their existing immediate apply behavior.
      confirmLabel: this.filters.some((filter: SourceFilter): boolean => filter.type === 'text')
        ? AppStrings.get('common_confirm') : undefined,
      confirmEnabled: this.resetEnabled && Object.keys(this.textDraft).length > 0,
      onConfirm: () => { this.applyText() },
      onClose: () => {
        this.textDraft = {}
        this.onClose()
      },
    }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
        GroupedListSection({ inModal: true }) {
          SourceFilterControls({
            filters: this.filters,
            values: this.values,
            busy: !this.resetEnabled,
            optionsLoading: this.optionsLoading,
            vertical: true,
            textDraft: this.textDraft,
            onTextDraftChange: (id: string, value: string) => {
              const next: Record<string, string> = {}
              Object.keys(this.textDraft).forEach((key: string) => { next[key] = this.textDraft[key] })
              next[id] = value
              this.textDraft = next
            },
            onTextSubmit: () => { this.applyText() },
            onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => {
              this.onFilterChange(filter, value)
            },
          })
        }
        if (this.showReset) {
          KomaActionButton({
            label: this.resetLabel,
            kind: 'ghost',
            compact: true,
            isEnabled: this.resetEnabled,
            action: () => {
              this.textDraft = {}
              this.onReset()
            },
          })
        }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    }
  }
}
