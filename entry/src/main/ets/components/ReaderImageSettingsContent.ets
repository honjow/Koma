import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderPreferences, DEFAULT_READER_PREFERENCES, normalizeReaderPreferences, getReaderCropStrengthLabel } from '../model/ReaderPreferencesStore'
import { ReaderSuperResolutionModelService } from '../model/ReaderSuperResolutionModelService'
import { readerSuperResolutionModelLabel } from '../model/ReaderSuperResolutionPresentation'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

function t(key: string): string { return AppStrings.get(key) }

/** NextE ReaderSettingsPage's crop/enhancement controls, shared by global and in-reader settings.
 * Keep model selection, model-file management and enabling separate. An unavailable selection
 * falls back to the first installed model, without enabling processing or starting a download.
 * The user explicitly requested this NextE behavior; do not replace it with a download picker.
 */
@ComponentV2
export struct ReaderImageSettingsContent {
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Param cropControlsAvailable: boolean = true
  @Param enhancementControlsAvailable: boolean = true
  @Param modelsRevision: number = 0
  @Event onPreferencesChange: (next: ReaderPreferences) => void = (_next: ReaderPreferences) => {}
  @Event onOpenModels: () => void = () => {}
  @Local private installedModels: string[] = []
  private active: boolean = false
  private lifetime: number = 0

  aboutToAppear(): void {
    this.active = true
    this.refreshModels()
  }

  aboutToDisappear(): void { this.active = false; this.lifetime += 1 }

  @Monitor('modelsRevision')
  private modelsChanged(): void { this.refreshModels() }

  private refreshModels(): void {
    if (!this.enhancementControlsAvailable) return
    const lifetime: number = ++this.lifetime
    const model: string = this.preferences.superResolutionModel
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    void ReaderSuperResolutionModelService.installedModels(context).then((installed: string[]) => {
      if (!this.active || lifetime !== this.lifetime) return
      this.installedModels = installed
      if (this.preferences.superResolutionModel !== model || installed.includes(model)) return
      const replacement: string = installed.length > 0 ? installed[0] : 'none'
      if (model !== replacement || (replacement === 'none' && this.preferences.superResolutionEnabled)) {
        this.selectModel(replacement)
      }
    })
  }

  private selectModel(model: string): void {
    const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
    next.superResolutionModel = model
    if (model === 'none') next.superResolutionEnabled = false
    this.onPreferencesChange(next)
  }

  private enableEnhancement(enabled: boolean): void {
    if (enabled && this.installedModels.length === 0) return
    const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
    // Model availability and the toggle use the same installed list, as in NextE.
    if (enabled && !this.installedModels.includes(next.superResolutionModel)) {
      next.superResolutionModel = this.installedModels[0]
    }
    next.superResolutionEnabled = enabled
    this.onPreferencesChange(next)
  }

  @Builder
  private CropStrengthMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['conservative', 'standard', 'strong'], (strength: string) => {
        MenuItem({ content: getReaderCropStrengthLabel(strength), symbolEndIcon:
          this.preferences.cropStrength === strength ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => {
            const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
            next.cropStrength = strength
            this.onPreferencesChange(next)
          }) })
      })
    }
  }

  @Builder
  private ModelMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.installedModels, (model: string) => {
        MenuItem({ content: readerSuperResolutionModelLabel(model), symbolEndIcon:
          this.preferences.superResolutionModel === model ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.selectModel(model) }) })
      }, (model: string): string => model)
    }
  }

  @Builder
  private MaxHeightMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach([1000, 1500, 2000], (height: number) => {
        MenuItem({ content: `${height}px`, symbolEndIcon:
          this.preferences.superResolutionMaxHeight === height ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => {
            const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
            next.superResolutionMaxHeight = height
            this.onPreferencesChange(next)
          }) })
      })
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      if (this.cropControlsAvailable) {
        GroupedListSection({ title: t('settings_reader_group_crop') }) {
          ConciseListRow({ title: t('settings_row_reader_trim_page_margins_title'), hasSwitch: true,
            checked: this.preferences.trimPageMarginsEnabled, showChevron: false,
            switchAction: (enabled: boolean) => {
              const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
              next.trimPageMarginsEnabled = enabled
              this.onPreferencesChange(next)
            } }).id('reader-image-trim-margins')
          ListDivider()
          ConciseListRow({ title: t('reader_crop_strength_title'), trailingText: getReaderCropStrengthLabel(this.preferences.cropStrength),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.trimPageMarginsEnabled,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.CropStrengthMenu(select) } })
        }
      }
      if (this.enhancementControlsAvailable) {
        GroupedListSection({ title: t('settings_reader_group_image_enhancement') }) {
          ConciseListRow({ title: t('settings_reader_super_resolution'), hasSwitch: true,
            checked: this.preferences.superResolutionEnabled, showChevron: false,
            isEnabled: this.installedModels.length > 0,
            action: () => { this.enableEnhancement(!this.preferences.superResolutionEnabled) },
            switchAction: (enabled: boolean) => { this.enableEnhancement(enabled) } }).id('reader-image-enhancement')
          ListDivider()
          ConciseListRow({ title: t('settings_reader_super_resolution_model'),
            trailingText: this.installedModels.length === 0 ? t('settings_reader_super_resolution_models_none_installed') :
              readerSuperResolutionModelLabel(this.preferences.superResolutionModel),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.installedModels.length > 0,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ModelMenu(select) } }).id('reader-image-model')
          ListDivider()
          ConciseListRow({ title: t('settings_reader_super_resolution_models'), action: () => { this.onOpenModels() } }).id('reader-image-models')
          ListDivider()
          ConciseListRow({ title: t('settings_reader_super_resolution_max_height'),
            subtitle: t('settings_reader_super_resolution_max_height_hint'), subtitleMaxLines: 3,
            trailingText: `${this.preferences.superResolutionMaxHeight}px`, trailingDropdown: true, dropdownMenuEnabled: true,
            isEnabled: this.preferences.superResolutionEnabled && this.preferences.superResolutionModel !== 'none',
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.MaxHeightMenu(select) } }).id('reader-image-max-height')
        }
      }
    }.width('100%')
  }
}
