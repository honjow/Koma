import { komaDialogMaterial, komaSheetOptions, komaToastOptions } from '../theme/KomaPopupOptions'
import { AppStrings } from '../i18n/AppStrings'
import { appSourceFilterPreferencesStore, SourceSearchPreset } from '../sourceRuntime/SourceFilterPreferencesStore'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaEmptyState } from './ui/KomaEmptyState'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaTextInputDialog } from './ui/KomaTextInputDialog'
import { sourceFilterSheetOptions } from './SourceFilterSheetOptions'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct SourceSearchPresetSheetHost {
  @Param sourceId: string = ''
  @Param query: string = ''
  @Param active: boolean = false
  @Param requestSeq: number = 0
  @Param viewModel: BrowseViewModel = new BrowseViewModel()
  @Event onApply: (query: string) => void = (_query: string) => {}
  @Local private presetsShown: boolean = false
  @Local private presets: SourceSearchPreset[] = []
  @Local private presetName: string = ''
  @Local private presetError: string = ''
  private presetDialogId: number = -1
  private presetDialogOpening: boolean = false
  private pendingPreset: SourceSearchPreset | undefined

  private presetToast(key: string): void {
    this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s(key) }))
  }

  @Monitor('requestSeq')
  private openPresets(): void {
    if (!this.active) return
    try {
      this.presets = appSourceFilterPreferencesStore.listSearchPresets(this.sourceId)
      this.presetsShown = true
    } catch (_error) { this.presetToast('source_search_preset_unavailable') }
  }

  @Monitor('active')
  private closeWhenInactive(): void {
    if (this.active) return
    this.pendingPreset = undefined
    this.presetsShown = false
    this.closePresetNameDialog()
  }

  private openPresetNameDialog(): void {
    if (this.presetDialogId >= 0 || this.presetDialogOpening) return
    this.presetDialogOpening = true
    this.presetName = ''
    this.presetError = ''
    void this.getUIContext().getPromptAction().openCustomDialog({ systemMaterial: komaDialogMaterial(),
      builder: (): void => { this.PresetNameDialog() }, alignment: DialogAlignment.Center, autoCancel: true,
      onDidDisappear: (): void => { this.presetDialogId = -1 },
    }).then((id: number): void => {
      this.presetDialogId = id
      if (!this.active) this.closePresetNameDialog()
    }).catch((): void => { this.presetToast('source_search_preset_unavailable') })
      .finally((): void => { this.presetDialogOpening = false })
  }

  private closePresetNameDialog(): void {
    if (this.presetDialogId < 0) return
    const id = this.presetDialogId
    this.presetDialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  private savePreset(): void {
    const name = this.presetName.trim()
    if (name.length === 0) return
    try {
      this.viewModel.saveSearchPreset(this.sourceId, name, this.query.trim())
      this.presets = appSourceFilterPreferencesStore.listSearchPresets(this.sourceId)
      this.closePresetNameDialog()
    } catch (error) {
      this.presetError = s((error as Error).message === 'duplicate_search_preset'
        ? 'source_search_preset_duplicate' : 'source_search_preset_unavailable')
    }
  }

  private finishPresetsDismiss(): void {
    const preset = this.pendingPreset
    this.pendingPreset = undefined
    if (preset === undefined || !this.active) return
    try {
      this.viewModel.applySearchPreset(preset)
      this.onApply(preset.query)
    } catch (_error) { this.presetToast('source_search_preset_unavailable') }
  }

  @Builder
  private PresetNameDialog() {
    KomaTextInputDialog({ title: s('source_search_preset_save'), label: s('source_search_preset_name'),
      placeholder: s('source_search_preset_name'), value: this.presetName, error: this.presetError,
      confirmLabel: s('common_save'), confirmEnabled: this.presetName.trim().length > 0,
      change: (name: string): void => { this.presetName = name; this.presetError = '' },
      confirm: (): void => { this.savePreset() }, cancel: (): void => { this.closePresetNameDialog() },
    })
  }

  @Builder
  private PresetsSheet() {
    KomaModalScaffold({ title: s('source_search_presets'), onClose: (): void => { this.presetsShown = false },
      additionalActions: [{ content: { label: s('source_search_preset_save'), icon: $r('sys.symbol.plus'),
        isEnabled: this.query.trim().length > 0 || this.viewModel.useSearchForFilters,
        action: (): void => { this.openPresetNameDialog() } } }],
    }) {
      ListItem() {
        if (this.presets.length === 0) {
          KomaEmptyState({ icon: $r('sys.symbol.bookmark'), title: s('source_search_preset_empty') })
        } else {
          GroupedListSection({ inModal: true }) {
            ForEach(this.presets, (preset: SourceSearchPreset, index: number) => {
              if (index > 0) ListDivider()
              ConciseListRow({ title: preset.name, subtitle: preset.query, showChevron: false,
                trailingIcon: $r('sys.symbol.trash'), trailingIconLabel: s('common_delete'),
                trailingIconAction: (): void => { this.removePreset(preset) }, action: (): void => {
                  this.pendingPreset = preset
                  this.presetsShown = false
                } })
            }, (preset: SourceSearchPreset): string => preset.name)
          }
        }
      }
    }
  }

  private removePreset(preset: SourceSearchPreset): void {
    try {
      appSourceFilterPreferencesStore.removeSearchPreset(this.sourceId, preset.name)
      this.presets = appSourceFilterPreferencesStore.listSearchPresets(this.sourceId)
    } catch (_error) { this.presetToast('source_search_preset_unavailable') }
  }

  build() {
    Column() {}
      .width(0)
      .height(0)
      .bindSheet($$this.presetsShown, this.PresetsSheet,
        komaSheetOptions(sourceFilterSheetOptions(() => { this.finishPresetsDismiss() })))
  }
}
