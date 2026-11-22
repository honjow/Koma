import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { AppStrings } from '../i18n/AppStrings'
import { Comic } from '../model/ComicModels'
import { discardUncommittedComicCover, prepareComicCoverEnhancementInput, stageEnhancedComicCover } from '../model/ComicPersonalization'
import { ReaderSuperResolutionModelDefinition } from '../model/ReaderSuperResolutionModelRegistry'
import { ReaderSuperResolutionModelService } from '../model/ReaderSuperResolutionModelService'
import { readerSuperResolutionModelLabel } from '../model/ReaderSuperResolutionPresentation'
import { COVER_ENHANCEMENT_MAX_INPUT_EDGE, ReaderSuperResolutionService, ReaderSuperResolutionTaskState } from '../model/ReaderSuperResolutionService'
import { ReaderSuperResolutionModel } from '../state/ReaderModeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { CachedCoverImage, resolveComicCoverArtwork } from './CachedCoverImage'
import { ConciseListRow } from './ui/ConciseListRow'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaSegmentedControl } from './ui/KomaSegmentedControl'

interface CoverModelOption {
  definition: ReaderSuperResolutionModelDefinition
  installed: boolean
}

function s(key: string): string { return AppStrings.get(key) }

const COMPARE_HEIGHT = ThemeConstants.BUTTON_HEIGHT + 2 * ThemeConstants.SPACE_XS
const MODEL_ROW_HEIGHT = 48
const STATUS_HEIGHT = ThemeConstants.BUTTON_HEIGHT

export function coverEnhancementPreviewHeight(viewportHeight: number): number {
  return Math.round(Math.min(232, Math.max(112, viewportHeight * 0.30)))
}

export function coverEnhancementSheetHeight(viewportHeight: number, bottomInset: number, canUndo: boolean): number {
  const rows = coverEnhancementPreviewHeight(viewportHeight) + COMPARE_HEIGHT + MODEL_ROW_HEIGHT +
    STATUS_HEIGHT + ThemeConstants.BUTTON_HEIGHT + (canUndo ? ThemeConstants.BUTTON_HEIGHT : 0)
  const gaps = ThemeConstants.SPACE_MD * (canUndo ? 5 : 4)
  const chrome = ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_LG + ThemeConstants.SPACE_MD + bottomInset
  return Math.min(rows + gaps + chrome, Math.floor(viewportHeight * 0.88))
}


@ComponentV2
export struct ComicCoverEnhancementSheet {
  @Param @Require comic: Comic
  @Param baseCover: string = ''
  @Param sourceImageId: string = ''
  @Param previewHeight: number = 232
  @Param active: boolean = true
  @Event onClose: () => void = () => {}
  @Event onApply: (cover: string | undefined, model: string | undefined) => boolean =
    (_cover: string | undefined, _model: string | undefined): boolean => false

  @Local private models: CoverModelOption[] = []
  @Local private selected: string = ''
  @Local private loadingModels: boolean = true
  @Local private busy: boolean = false
  @Local private stage: string = ''
  @Local private runningActionLabel: string = ''
  @Local private downloadedBytes: number = 0
  @Local private error: string = ''
  @Local private candidate: string = ''
  @Local private showingEnhanced: boolean = false
  private alive: boolean = false
  private generation: number = 0
  private stopObservingDownload?: () => void
  private readonly ownerKey: string = 'cover:' + util.generateRandomUUID()

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  aboutToAppear(): void {
    this.alive = true
    this.showingEnhanced = this.comic.enhancedCoverUri !== undefined
    void this.loadModels()
  }

  aboutToDisappear(): void {
    this.alive = false
    this.cancel()
  }

  @Monitor('active')
  private visibilityChanged(): void {
    if (!this.active) this.cancel()
  }

  private cancel(): void {
    this.generation++
    this.downloadedBytes = 0
    ReaderSuperResolutionService.releaseOwner(this.ownerKey)
    this.stopObservingDownload?.()
    this.stopObservingDownload = undefined
    this.discardCandidate()
    this.busy = false
    this.stage = ''
  }

  private discardCandidate(): void {
    const candidate = this.candidate
    this.candidate = ''
    if (candidate.length > 0) void discardUncommittedComicCover(this.context(), candidate)
  }

  private async loadModels(): Promise<void> {
    try {
      const context = this.context()
      const models: CoverModelOption[] = []
      for (const definition of ReaderSuperResolutionModelService.definitions()) {
        if (!definition.userAvailable && !definition.legacyAvailableWhenInstalled) continue
        const installed = await ReaderSuperResolutionModelService.isInstalled(context, definition.id)
        if (!this.alive || !this.active) return
        if (definition.userAvailable || installed) models.push({ definition, installed })
      }
      models.sort((a: CoverModelOption, b: CoverModelOption): number => Number(b.installed) - Number(a.installed))
      this.models = models
      const saved = models.find((option: CoverModelOption): boolean => option.definition.id === this.comic.enhancedCoverModel)
      this.selected = saved?.definition.id ??
        models.find((option: CoverModelOption): boolean => option.installed)?.definition.id ??
        ReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X
    } catch (error) {
      if (this.alive && this.active) {
        DiagnosticLogger.exception('cover-enhancement', 'model_list_failed', error as Error)
        this.error = s('cover_sr_failed')
      }
    } finally {
      if (this.alive && this.active) this.loadingModels = false
    }
  }

  private modelLabel(model: string): string {
    return model === ReaderSuperResolutionModel.SYSTEM_CORE_VISION
      ? s('cover_sr_system') : readerSuperResolutionModelLabel(model)
  }

  private optionLabel(option: CoverModelOption): string {
    const name = this.modelLabel(option.definition.id)
    if (option.definition.systemModel) return name
    return name + ' · ' + (option.installed ? s('cover_sr_installed') :
      s('cover_sr_model_size').replace('%s', (option.definition.downloadBytes() / 1048576).toFixed(1)))
  }

  private selectModel(model: string): void {
    if (model === this.selected || this.busy) return
    this.discardCandidate()
    this.selected = model
    this.error = ''
    this.showingEnhanced = this.comic.enhancedCoverUri !== undefined
  }

  private async createPreview(): Promise<void> {
    const option = this.models.find((value: CoverModelOption): boolean => value.definition.id === this.selected)
    if (!this.alive || !this.active || this.busy || option === undefined || this.baseCover.length === 0) return
    const context = this.context()
    const generation = ++this.generation
    const current = (): boolean => this.alive && this.active && generation === this.generation
    const model = option.definition.id
    this.error = ''
    this.discardCandidate()
    this.showingEnhanced = this.comic.enhancedCoverUri !== undefined
    this.runningActionLabel = this.actionLabel()
    this.busy = true
    let inputPath = ''
    let completedPath = ''
    try {
      if (!option.installed) {
        this.stage = s('cover_sr_model_downloading')
        this.downloadedBytes = 0
        const stopObserving = ReaderSuperResolutionModelService.observeDownload(context, model, (bytes: number): void => {
          if (current()) this.downloadedBytes = bytes
        })
        this.stopObservingDownload = stopObserving
        try { await ReaderSuperResolutionModelService.install(context, model) } finally {
          stopObserving()
          if (current()) this.stopObservingDownload = undefined
        }
        if (!current()) return
        this.models = this.models.map((value: CoverModelOption): CoverModelOption =>
          value.definition.id === model ? { definition: value.definition, installed: true } : value)
      }
      this.downloadedBytes = 0
      this.stage = s('cover_sr_original_loading')
      const uri = await resolveComicCoverArtwork(context, this.baseCover, this.comic.sourceRuntimeId ?? '',
        this.sourceImageId, this.comic.sourceKind, this.comic.remoteServerId ?? '', this.comic.sourcePath)
      if (!current()) return
      if (!uri.startsWith('/') && !uri.startsWith('file://')) throw new Error('cover_unreadable')
      inputPath = context.cacheDir + '/cover-sr-' + util.generateRandomUUID()
      await prepareComicCoverEnhancementInput(uri, inputPath, COVER_ENHANCEMENT_MAX_INPUT_EDGE)
      if (!current()) return
      const result = await ReaderSuperResolutionService.processCover(context, inputPath, 'cover:' + this.comic.id,
        model, (state: ReaderSuperResolutionTaskState): void => {
          if (current()) this.stage = s(state === ReaderSuperResolutionTaskState.QUEUED ? 'cover_sr_queued' : 'cover_sr_processing')
        }, this.ownerKey, current)
      if (!current()) return
      if (!result.applied) {
        this.error = s(result.reason === 'height_limit' || result.reason === 'pixel_limit' ? 'cover_sr_size_limit' : 'cover_sr_failed')
        DiagnosticLogger.warn('cover-enhancement', 'preview_unavailable', 'model=' + model + ' reason=' + result.reason)
        return
      }
      completedPath = await stageEnhancedComicCover(context, result.filePath)
      if (!current()) return
      this.candidate = completedPath
      completedPath = ''
      this.showingEnhanced = true
      DiagnosticLogger.info('cover-enhancement', 'preview_ready',
        'model=' + model + ' backend=' + result.backend + ' elapsedMs=' + result.elapsedMs)
    } catch (error) {
      if (current()) {
        DiagnosticLogger.exception('cover-enhancement', 'preview_failed', error as Error)
        this.error = s(this.stage === s('cover_sr_model_downloading') ?
          'settings_reader_super_resolution_model_download_failed' : 'cover_sr_failed')
      }
    } finally {
      if (inputPath.length > 0) await fs.unlink(inputPath).catch((): void => {})
      if (completedPath.length > 0) await discardUncommittedComicCover(context, completedPath)
      if (current()) {
        this.busy = false
        this.downloadedBytes = 0
        this.stage = ''
      }
    }
  }

  private apply(): void {
    if (this.candidate.length === 0 || this.busy || !this.active) return
    if (this.onApply(this.candidate, this.selected)) {
      this.candidate = ''
      this.onClose()
    } else {
      this.error = s('manga_personalization_failed')
    }
  }

  private undo(): void {
    if (this.busy || !this.active) return
    if (this.onApply(undefined, undefined)) this.onClose()
    else this.error = s('manga_personalization_failed')
  }

  private actionLabel(): string {
    const option = this.models.find((value: CoverModelOption): boolean => value.definition.id === this.selected)
    if (option !== undefined && !option.installed) return s('cover_sr_download_and_start')
    return s(this.comic.enhancedCoverUri === undefined ? 'cover_sr_start' : 'cover_sr_again')
  }

  private hasEnhancedPreview(): boolean {
    return this.candidate.length > 0 || this.comic.enhancedCoverUri !== undefined
  }

  private previewUri(): string {
    if (!this.showingEnhanced) return this.baseCover
    return this.candidate.length > 0 ? this.candidate : this.comic.enhancedCoverUri ?? this.baseCover
  }

  @Builder
  private ModelMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.models, (option: CoverModelOption) => {
        MenuItem({ content: this.optionLabel(option), symbolEndIcon: this.selected === option.definition.id ?
          new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.selectModel(option.definition.id) }) })
      }, (option: CoverModelOption): string => option.definition.id)
    }
  }

  build() {
    KomaModalScaffold({ title: s('cover_sr_title'), onClose: this.onClose }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Column() {
            CachedCoverImage({
              uri: this.previewUri(),
              objectFit: ImageFit.Contain,
              coverOwnerId: this.comic.id,
              sourceRuntimeId: this.comic.sourceRuntimeId ?? '',
              sourceImageId: this.sourceImageId,
              sourceKind: this.comic.sourceKind,
              remoteServerId: this.comic.remoteServerId ?? '',
              sourceMangaUrl: this.comic.sourcePath,
              decodeMaxEdge: 960,
            })
          }.width('100%').height(this.previewHeight)
          // Preserve geometry across idle, queued, processing, failure and preview.
          Column() {
            KomaSegmentedControl({ labels: [s('cover_sr_original'), s('cover_sr_enhanced')],
              selectedIndex: this.showingEnhanced ? 1 : 0,
              select: (index: number): void => { this.showingEnhanced = index === 1 } })
              .visibility(this.hasEnhancedPreview() ? Visibility.Visible : Visibility.Hidden)
          }.width('100%').height(COMPARE_HEIGHT)
          ConciseListRow({
            title: s('settings_reader_super_resolution_model'),
            trailingText: this.selected.length > 0 ? this.modelLabel(this.selected) : s('common_loading'),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy && !this.loadingModels,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ModelMenu(select) },
          }).height(MODEL_ROW_HEIGHT).id('cover-sr-model')
          Row({ space: ThemeConstants.SPACE_SM }) {
            if (this.busy) {
              LoadingProgress().width(22).height(22).color(ThemeConstants.BRAND_PRIMARY)
            }
            Text(this.error.length > 0 ? this.error : this.downloadedBytes > 0
              ? this.stage + ' ' + (this.downloadedBytes / 1048576).toFixed(1) + ' MB' : this.stage)
              .layoutWeight(1).fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2)
            if (this.busy) {
              Button(s('common_cancel'), { buttonStyle: ButtonStyleMode.TEXTUAL })
                .height(STATUS_HEIGHT).fontColor(ThemeConstants.BRAND_PRIMARY)
                .onClick(() => this.cancel()).id('cover-sr-cancel')
            }
          }.width('100%').height(STATUS_HEIGHT)
          Button(this.busy ? this.runningActionLabel : this.candidate.length > 0 ? s('cover_sr_apply') : this.actionLabel())
            .type(ButtonType.Capsule).width('100%').height(ThemeConstants.BUTTON_HEIGHT)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY).fontColor(ThemeConstants.TEXT_ON_BRAND)
            .enabled(!this.busy && !this.loadingModels && this.models.length > 0 && this.baseCover.length > 0)
            .onClick((): void => {
              if (this.busy) return
              if (this.candidate.length > 0) this.apply()
              else void this.createPreview()
            })
            .id('cover-sr-primary')
          if (this.comic.enhancedCoverUri !== undefined) {
            Button(s('cover_sr_undo'), { buttonStyle: ButtonStyleMode.TEXTUAL })
              .width('100%').height(ThemeConstants.BUTTON_HEIGHT).fontColor(ThemeConstants.BRAND_PRIMARY)
              .enabled(!this.busy).onClick(() => this.undo()).id('cover-sr-undo')
          }
        }.width('100%').padding({ bottom: ThemeConstants.SPACE_LG })
      }
    }
  }
}
