// Ported from NextE ReaderSuperResolutionModelsPage: file management is separate from selection.
import { common } from '@kit.AbilityKit'
import { ReaderSuperResolutionModel } from '../state/ReaderModeState'
import { ReaderSuperResolutionModelDefinition } from '../model/ReaderSuperResolutionModelRegistry'
import { ReaderSuperResolutionModelService } from '../model/ReaderSuperResolutionModelService'
import { ReaderPreferences, DEFAULT_READER_PREFERENCES, normalizeReaderPreferences } from '../model/ReaderPreferencesStore'
import { readerSuperResolutionModelLabel } from '../model/ReaderSuperResolutionPresentation'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

@ObservedV2
class ReaderSuperResolutionModelFileState {
  definition: ReaderSuperResolutionModelDefinition
  @Trace installed: boolean = false
  @Trace downloading: boolean = false
  @Trace remainingDownloadBytes: number = 0

  constructor(definition: ReaderSuperResolutionModelDefinition) {
    this.definition = definition
    this.remainingDownloadBytes = definition.downloadBytes()
  }
}

/** Local model-file management. Active-model selection remains in ReaderSettingsPage. */
@ComponentV2
export struct ReaderSuperResolutionModelsContent {
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Event onPreferencesChange: (next: ReaderPreferences) => void = (_next: ReaderPreferences) => {}
  @Event modelsChanged: () => void = () => {}
  private active: boolean = false
  private lifetime: number = 0
  @Local modelStates: ReaderSuperResolutionModelFileState[] = []
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.active = true
    this.lifetime += 1
    if (this.modelStates.length === 0) {
      const definitions: ReaderSuperResolutionModelDefinition[] =
        ReaderSuperResolutionModelService.userAvailableDefinitions()
      const states: ReaderSuperResolutionModelFileState[] = []
      for (let i: number = 0; i < definitions.length; i++) {
        states.push(new ReaderSuperResolutionModelFileState(definitions[i]))
      }
      this.modelStates = states
    }
    this.refreshInstallState()
    this.appendInstalledLegacyModels()
  }

  aboutToDisappear(): void { this.active = false; this.lifetime += 1 }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private toast(message: ResourceStr): void {
    this.getUIContext().getPromptAction().showToast({ message: message })
  }

  private async refreshInstallState(): Promise<void> {
    for (let i: number = 0; i < this.modelStates.length; i++) {
      this.modelStates[i].installed = await ReaderSuperResolutionModelService.isInstalled(
        this.context(),
        this.modelStates[i].definition.id,
      )
      this.modelStates[i].remainingDownloadBytes =
        ReaderSuperResolutionModelService.remainingDownloadBytes(
          this.context(),
          this.modelStates[i].definition.id,
        )
    }
  }

  private async appendInstalledLegacyModels(): Promise<void> {
    const definitions: ReaderSuperResolutionModelDefinition[] =
      ReaderSuperResolutionModelService.definitions()
    const states: ReaderSuperResolutionModelFileState[] = this.modelStates.slice()
    let changed: boolean = false
    for (let i: number = 0; i < definitions.length; i++) {
      const definition: ReaderSuperResolutionModelDefinition = definitions[i]
      if (!definition.legacyAvailableWhenInstalled ||
        this.hasModelState(definition.id)) {
        continue
      }
      const installed: boolean = await ReaderSuperResolutionModelService.isInstalled(
        this.context(),
        definition.id,
      )
      if (!installed) {
        continue
      }
      const state: ReaderSuperResolutionModelFileState =
        new ReaderSuperResolutionModelFileState(definition)
      state.installed = true
      state.remainingDownloadBytes = 0
      states.push(state)
      changed = true
    }
    if (changed) {
      this.modelStates = states
    }
  }

  private hasModelState(model: string): boolean {
    for (let i: number = 0; i < this.modelStates.length; i++) {
      if (this.modelStates[i].definition.id === model) {
        return true
      }
    }
    return false
  }

  private modelTitle(model: string): string { return readerSuperResolutionModelLabel(model) }
  private modelTitleText(model: string): string { return readerSuperResolutionModelLabel(model) }

  private selectModel(model: string): void {
    const next: ReaderPreferences = normalizeReaderPreferences(this.preferences)
    next.superResolutionModel = model
    if (model === ReaderSuperResolutionModel.NONE) next.superResolutionEnabled = false
    this.onPreferencesChange(next)
  }

  private notifyModelsChanged(): void {
    if (this.modelsChanged) {
      this.modelsChanged()
    }
  }

  private modelSubtitle(state: ReaderSuperResolutionModelFileState): string {
    const definition: ReaderSuperResolutionModelDefinition = state.definition
    const scope: string = AppStrings.get(definition.usageScopeStringKey)
    const performance: string = AppStrings.get(definition.performanceStringKey)
    const details: string = AppStrings.get(definition.detailsStringKey)
    if (definition.systemModel) {
      return `${scope} · ${performance}\n${details}`
    }
    const bytes: number = definition.downloadBytes()
    const size: string = bytes < 1024 * 1024
      ? `${Math.round(bytes / 1024)} KB`
      : `${Math.round(bytes / (1024 * 1024))} MB`
    return `${scope} · ${performance} · ${size}\n${details}`
  }

  private async downloadModel(state: ReaderSuperResolutionModelFileState): Promise<void> {
    if (state.definition.systemModel || state.installed || state.downloading) {
      return
    }
    const lifetime: number = this.lifetime
    state.downloading = true
    try {
      await ReaderSuperResolutionModelService.install(this.context(), state.definition.id)
      if (!this.active || lifetime !== this.lifetime) return
      state.installed = true
      state.remainingDownloadBytes = 0
      if (this.preferences.superResolutionModel === ReaderSuperResolutionModel.NONE) {
        this.selectModel(state.definition.id)
      }
      this.notifyModelsChanged()
      this.toast($r('app.string.settings_reader_super_resolution_model_downloaded'))
    } catch (_error) {
      if (this.active && lifetime === this.lifetime) this.toast($r('app.string.settings_reader_super_resolution_model_download_failed'))
    } finally {
      state.downloading = false
    }
  }

  private confirmRemoveModel(state: ReaderSuperResolutionModelFileState): void {
    if (state.definition.systemModel) {
      return
    }
    const message: string = AppStrings.get('settings_reader_super_resolution_model_delete_confirm')
      .replace('%s', this.modelTitleText(state.definition.id))
    this.getUIContext().showAlertDialog({
      message: message,
      primaryButton: {
        value: $r('app.string.common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.common_delete'),
        fontColor: Color.Red,
        action: () => {
          this.removeModel(state)
        },
      },
    })
  }

  private removeModel(state: ReaderSuperResolutionModelFileState): void {
    if (state.definition.systemModel || !state.installed || state.downloading) {
      return
    }
    ReaderSuperResolutionModelService.remove(this.context(), state.definition.id)
    state.installed = false
    state.remainingDownloadBytes = state.definition.downloadBytes()
    if (this.preferences.superResolutionModel === state.definition.id) {
      let replacement: string = ReaderSuperResolutionModel.NONE
      for (let i: number = 0; i < this.modelStates.length; i++) {
        if (this.modelStates[i].installed &&
          this.modelStates[i].definition.userAvailable) {
          replacement = this.modelStates[i].definition.id
          break
        }
      }
      this.selectModel(replacement)
    }
    if (!state.definition.userAvailable) {
      const visibleStates: ReaderSuperResolutionModelFileState[] = []
      for (let i: number = 0; i < this.modelStates.length; i++) {
        if (this.modelStates[i].definition.id !== state.definition.id) {
          visibleStates.push(this.modelStates[i])
        }
      }
      this.modelStates = visibleStates
    }
    this.notifyModelsChanged()
    this.toast($r('app.string.settings_reader_super_resolution_model_deleted'))
  }

  @Builder
  private ModelAction(state: ReaderSuperResolutionModelFileState) {
    if (state.definition.systemModel) {
      Text($r('app.string.settings_reader_super_resolution_system_ready'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .accessibilityText($r('app.string.settings_reader_super_resolution_system_ready'))
    } else if (state.downloading) {
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        LoadingProgress()
          .width(ThemeConstants.FONT_SIZE_TITLE)
          .height(ThemeConstants.FONT_SIZE_TITLE)
          .color(ThemeConstants.BRAND_PRIMARY)
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .enabled(false)
      .accessibilityText($r('app.string.settings_reader_super_resolution_model_downloading_short'))
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(state.installed
          ? $r('sys.symbol.trash')
          : $r('sys.symbol.arrow_down_to_line'))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontColor([state.installed ? Color.Red : ThemeConstants.BRAND_PRIMARY])
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .accessibilityText(state.installed
        ? $r('app.string.common_delete')
        : $r('app.string.settings_reader_super_resolution_model_download'))
      .onClick(() => {
        if (state.installed) {
          this.confirmRemoveModel(state)
        } else {
          this.downloadModel(state)
        }
      })
    }
  }

  @Builder
  private ModelRow(state: ReaderSuperResolutionModelFileState) {
    ConciseListRow({
      title: this.modelTitle(state.definition.id),
      subtitle: this.modelSubtitle(state),
      subtitleMaxLines: 6,
      showChevron: false,
      suffixPaddingRight: 0,
      suffixBuilderParam: () => {
        this.ModelAction(state)
      },
    })
  }

  @Builder
  private ModelFileList() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        GroupedListSection() {
          ForEach(
            this.modelStates,
            (state: ReaderSuperResolutionModelFileState, index: number) => {
              this.ModelRow(state)
              if (index < this.modelStates.length - 1) {
                ListDivider()
              }
            },
            (state: ReaderSuperResolutionModelFileState): string => state.definition.id,
          )
        }
        Text($r('app.string.settings_reader_super_resolution_tiling_limit_description'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_tertiary'))
          .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
  }

  build() { this.ModelFileList() }
}
