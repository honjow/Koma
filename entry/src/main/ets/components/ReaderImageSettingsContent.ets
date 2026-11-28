import { ReaderSettingOption } from './ReaderSettingOption'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { effectiveBannerFilter } from '../model/ImageBannerRules'
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
  @Param showPlugins: boolean = true
  @Param bookBannerOptions: boolean = false
  @Param cropControlsAvailable: boolean = true
  @Param enhancementControlsAvailable: boolean = true
  @Param trackModelChangesOnlyOnUserAction: boolean = false
  @Param favoriteKeys: string[] | undefined = undefined
  @Param onFavorite: ((key: string) => void) | undefined = undefined
  @Param modelsRevision: number = 0
  @Param searchTarget: string = ''
  @Event onSearchTargetArea: (area: Area) => void = (_area: Area) => {}
  @Event onPreferencesChange: (next: ReaderPreferences) => void = (_next: ReaderPreferences) => {}
  @Event onOpenPlugins: () => void = () => {}
  @Event onOpenModels: () => void = () => {}
  @Local private imageRules: ImageRuleState = connectImageRuleState()
  @Local private installedModels: string[] = []
  private active: boolean = false
  private lifetime: number = 0

  aboutToAppear(): void {
    this.active = true
    if (this.showPlugins) void ImageRuleStore.forContext(this.getUIContext().getHostContext() as common.UIAbilityContext).list()
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
      if (this.trackModelChangesOnlyOnUserAction || this.preferences.superResolutionModel !== model || installed.includes(model)) return
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

  private pluginUsageLabel(): string {
    if (this.bookBannerOptions && (this.preferences.bannerFilterOverride === undefined ||
      this.preferences.bannerFilterOverride === 'global')) return 'image_plugins_use_global'
    return effectiveBannerFilter(this.preferences.bannerFilter,
      this.bookBannerOptions ? this.preferences.bannerFilterOverride : undefined) === 'off' ?
      'image_plugins_disabled' : 'image_plugins_enabled'
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

  private reportSearchArea(key: string, area: Area): void {
    if (this.searchTarget === key) this.onSearchTargetArea(area)
  }

  private shownSettings(keys: string[]): string[] {
    return this.favoriteKeys === undefined ? keys : keys.filter((key: string): boolean => this.favoriteKeys?.includes(key) === true)
  }

  @Builder
  private ImageSetting(key: string) {
    if (key === 'image_plugins_title') {
      ConciseListRow({ title: t('image_plugins_title'), subtitle: t('image_plugins_manage_hint'), subtitleMaxLines: 3,
        trailingText: t(this.pluginUsageLabel()),
        action: (): void => { this.onOpenPlugins() } }).id('reader-image-plugins')
    } else if (key === 'settings_row_reader_trim_page_margins_title') {
      ConciseListRow({ title: t('settings_row_reader_trim_page_margins_title'), hasSwitch: true,
        checked: this.preferences.trimPageMarginsEnabled, showChevron: false,
        switchAction: (enabled: boolean) => {
          const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
          next.trimPageMarginsEnabled = enabled
          this.onPreferencesChange(next)
        } }).id('reader-image-trim-margins')
        .onAreaChange((_old: Area, area: Area) => { this.reportSearchArea('reader-trim-margins', area) })
    } else if (key === 'reader_crop_strength_title') {
      ConciseListRow({ title: t('reader_crop_strength_title'), trailingText: getReaderCropStrengthLabel(this.preferences.cropStrength),
        trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.preferences.trimPageMarginsEnabled,
        dropdownMenuBuilder: (select: (action: () => void) => void) => { this.CropStrengthMenu(select) } })
        .onAreaChange((_old: Area, area: Area) => { this.reportSearchArea('reader-crop-strength', area) })
    } else if (key === 'settings_reader_super_resolution') {
      ConciseListRow({ title: t('settings_reader_super_resolution'), hasSwitch: true,
        checked: this.preferences.superResolutionEnabled, showChevron: false,
        isEnabled: this.installedModels.length > 0,
        action: () => { this.enableEnhancement(!this.preferences.superResolutionEnabled) },
        switchAction: (enabled: boolean) => { this.enableEnhancement(enabled) } }).id('reader-image-enhancement')
        .onAreaChange((_old: Area, area: Area) => { this.reportSearchArea('reader-super-resolution', area) })
    } else if (key === 'settings_reader_super_resolution_model') {
      ConciseListRow({ title: t('settings_reader_super_resolution_model'),
        trailingText: this.installedModels.length === 0 ? t('settings_reader_super_resolution_models_none_installed') :
          readerSuperResolutionModelLabel(this.trackModelChangesOnlyOnUserAction &&
            !this.installedModels.includes(this.preferences.superResolutionModel) ? this.installedModels[0] :
            this.preferences.superResolutionModel),
        trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.installedModels.length > 0,
        dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ModelMenu(select) } }).id('reader-image-model')
        .onAreaChange((_old: Area, area: Area) => { this.reportSearchArea('reader-super-resolution-model', area) })
    } else if (key === 'settings_reader_super_resolution_models') {
      ConciseListRow({ title: t('settings_reader_super_resolution_models'), action: () => { this.onOpenModels() } }).id('reader-image-models')
    } else if (key === 'settings_reader_super_resolution_max_height') {
      ConciseListRow({ title: t('settings_reader_super_resolution_max_height'),
        subtitle: t('settings_reader_super_resolution_max_height_hint'), subtitleMaxLines: 3,
        trailingText: `${this.preferences.superResolutionMaxHeight}px`, trailingDropdown: true, dropdownMenuEnabled: true,
        isEnabled: this.preferences.superResolutionEnabled && this.preferences.superResolutionModel !== 'none',
        dropdownMenuBuilder: (select: (action: () => void) => void) => { this.MaxHeightMenu(select) } }).id('reader-image-max-height')
        .onAreaChange((_old: Area, area: Area) => { this.reportSearchArea('reader-super-resolution-max-height', area) })
    }
  }

  @Builder
  private ImageSection(title: string | undefined, keys: string[]) {
    if (this.shownSettings(keys).length > 0) {
      GroupedListSection({ title: title }) {
        ForEach(this.shownSettings(keys), (key: string, index: number) => {
          if (index > 0) {
            ListDivider()
          }
          ReaderSettingOption({ settingKey: key, onFavorite: this.onFavorite }) {
            this.ImageSetting(key)
          }
        }, (key: string, index: number): string => key + ':' + (index === 0 ? 'first' : 'rest'))
      }
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      if (this.showPlugins) {
        this.ImageSection(undefined, ['image_plugins_title'])
      }
      if (this.cropControlsAvailable) {
        this.ImageSection(t('settings_reader_group_crop'), ['settings_row_reader_trim_page_margins_title', 'reader_crop_strength_title'])
      }
      if (this.enhancementControlsAvailable) {
        this.ImageSection(t('settings_reader_group_image_enhancement'), ['settings_reader_super_resolution', 'settings_reader_super_resolution_model', 'settings_reader_super_resolution_models', 'settings_reader_super_resolution_max_height'])
      }
    }.width('100%')
  }
}
