import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaFormTextField } from './ui/KomaFormTextField'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaTranslationSettings, KomaTranslationSettingsSnapshot, KomaTranslationSettingsState,
  connectKomaTranslationSettings } from '../readerTranslation/KomaTranslationSettings'
import { ComicTranslationModelService } from '../readerTranslation/services/ComicTranslationModelService'
import { ToriiFontCatalog, ToriiFontOption, ToriiTranslatorModel, ToriiTranslatorModelCatalog } from '../readerTranslation/settings/ComicVisualProviderSettings'
import { ToriiCreditsService, ToriiCreditsSnapshot } from '../readerTranslation/services/ToriiCreditsService'
import { MangaTranslatorUiSidecarConfig } from '../readerTranslation/services/MangaTranslatorUiSidecarBackend'
import { MangaTranslatorUiSidecarConnectionService } from '../readerTranslation/services/MangaTranslatorUiSidecarConnectionService'
import { KomaTranslationLlmSource } from '../readerTranslation/KomaTranslationLlmSource'
import { supportsMangaTranslation, LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL } from '../readerTranslation/model/LlmSourceProfile'
import { CodexOAuthTokenCodec } from '../readerTranslation/services/CodexOAuthTokenCodec'
import { ComicTranslationModelCatalogService } from '../readerTranslation/services/ComicTranslationModelCatalogService'
import { ToriiWholePageLiveEvaluationService, ToriiWholePageLiveEvaluationReport } from '../readerTranslation/services/ToriiWholePageLiveEvaluationService'
import { ComicTranslationLiveEvaluationService, ComicTranslationLiveEvaluationReport } from '../readerTranslation/services/ComicTranslationLiveEvaluationService'
import { KomaTranslationEvaluationContent } from './KomaTranslationEvaluationContent'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

function t(key: string): string { return AppStrings.get(key) }

/** Global translation configuration; reuse the same form and secure settings owner in either presentation. */
@ComponentV2
export struct KomaTranslationSettingsContent {
  @Param sheetPresentation: boolean = true
  @Event onClose: () => void = () => {}
  @Event onOpenSources: () => void = () => {}
  @Local private draft: KomaTranslationSettingsSnapshot = new KomaTranslationSettingsSnapshot()
  @Local private translationState: KomaTranslationSettingsState = connectKomaTranslationSettings()
  @Local private ready: boolean = false
  @Local private saving: boolean = false
  @Local private modelInstalled: boolean = false
  @Local private modelDownloading: boolean = false
  @Local private toriiCredits: ToriiCreditsSnapshot | null = null
  @Local private creditsRefreshing: boolean = false
  @Local private connectionRunning: boolean = false
  @Local private connectionMessage: string = ''
  @Local private modelOptions: string[] = []
  @Local private fetchingModels: boolean = false
  @Local private evaluationRunning: boolean = false
  @Local private evaluationReport: ComicTranslationLiveEvaluationReport | null = null
  @Local private toriiEvaluationReport: ToriiWholePageLiveEvaluationReport = new ToriiWholePageLiveEvaluationReport()
  @Local private evaluationShown: boolean = false
  private active: boolean = false
  private lifetime: number = 0
  private connectedCodexSources: Set<string> = new Set<string>()

  aboutToAppear(): void {
    this.active = true
    const lifetime = ++this.lifetime
    void this.load(lifetime)
  }

  aboutToDisappear(): void { this.active = false; this.lifetime += 1 }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  @Monitor('translationState.revision')
  private sourceProfilesChanged(): void {
    if (this.active && this.ready) void this.reloadSourceProfiles(this.lifetime)
  }

  private async reloadSourceProfiles(lifetime: number): Promise<void> {
    try {
      const current = await KomaTranslationSettings.load(this.context())
      if (!this.active || lifetime !== this.lifetime || current.revision !== this.translationState.revision) return
      const previousSource = this.draft.textSource()?.profile
      const next = this.draft.copy()
      this.connectedCodexSources.clear()
      current.llmSources.forEach((source: KomaTranslationLlmSource) => {
        if (CodexOAuthTokenCodec.parse(source.codexTokens) !== null) this.connectedCodexSources.add(source.profile.sourceProfileId)
        source.codexTokens = ''
      })
      next.llmSources = current.llmSources
      const nextSource = next.textSource()?.profile
      if (previousSource?.sourceRevision !== nextSource?.sourceRevision) this.modelOptions = []
      this.draft = next
    } catch (_error) { if (this.active && lifetime === this.lifetime) this.toast('reader_translation_settings_load_failed') }
  }

  private async load(lifetime: number): Promise<void> {
    try {
      const value = await KomaTranslationSettings.load(this.context())
      const installed = await ComicTranslationModelService.isInstalled(this.context())
      if (!this.active || lifetime !== this.lifetime) return
      this.connectedCodexSources.clear()
      value.llmSources.forEach((source: KomaTranslationLlmSource) => {
        if (CodexOAuthTokenCodec.parse(source.codexTokens) !== null) {
          this.connectedCodexSources.add(source.profile.sourceProfileId)
        }
        source.codexTokens = ''
      })
      this.draft = value
      this.modelInstalled = installed
      this.ready = true
      const cached = await ToriiCreditsService.cached(this.context(), value.toriiApiKey)
      if (!this.active || lifetime !== this.lifetime) return
      this.toriiCredits = cached
      if (this.active && lifetime === this.lifetime && value.route === 'torii_whole_page') void this.refreshCredits()
    } catch (_error) {
      if (this.active && lifetime === this.lifetime) this.toast('reader_translation_settings_load_failed')
    }
  }

  private toast(key: string): void {
    this.getUIContext().getPromptAction().showToast({ message: t(key) })
  }

  private draftTextConfigured(): boolean {
    const source = this.draft.textSource()
    if (source?.profile.sourceType !== LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL) return this.draft.textConfigured()
    return supportsMangaTranslation(source.profile, this.draft.multimodal) && this.draft.apiModel.length > 0 &&
      this.connectedCodexSources.has(source.profile.sourceProfileId)
  }

  private edit(key: string, value: string): void {
    const next = this.draft.copy()
    if (key === 'api-url') next.apiBaseUrl = value.trim()
    if (key === 'api-key') next.apiKey = value.trim()
    if (key === 'model') next.apiModel = value.trim()
    if (key === 'sidecar-url') next.sidecarUrl = value.trim()
    if (key === 'username') next.sidecarUsername = value.trim()
    if (key === 'password') next.sidecarPassword = value
    if (key === 'torii-key') { next.toriiApiKey = value.trim(); this.toriiCredits = null }
    if (key === 'route') next.route = value
    if (key === 'source-language') next.sourceLanguage = value
    if (key === 'target-language') next.targetLanguage = value
    if (key === 'torii-model') next.toriiModel = value
    if (key === 'torii-font') next.toriiFont = value
    if (key === 'reasoning') next.reasoningEffort = value
    if (key === 'detection') next.detectionProfile = value
    if (key === 'inpainting') next.inpaintingProfile = value
    if (key === 'target-language') next.toriiFont = ToriiFontCatalog.effectiveFontId(next.toriiFont, value)
    if (key === 'sidecar-url' || key === 'username' || key === 'password' || key === 'detection' || key === 'inpainting') this.connectionMessage = ''
    this.draft = next
    this.evaluationReport = null
    this.toriiEvaluationReport = new ToriiWholePageLiveEvaluationReport()
  }

  private manageModels(): void {
    if (!this.ready || this.modelDownloading) return
    this.getUIContext().showAlertDialog({
      title: t(this.modelInstalled ? 'comic_local_detector_remove_title' : 'comic_local_detector_install_title'),
      message: t(this.modelInstalled ? 'comic_local_detector_remove_message' : 'comic_local_detector_install_message'),
      primaryButton: { value: t('common_cancel'), action: () => {} },
      secondaryButton: {
        value: t(this.modelInstalled ? 'comic_local_detector_remove' : 'comic_local_detector_install'),
        action: () => {
          if (this.modelInstalled) {
            ComicTranslationModelService.remove(this.context())
            this.modelInstalled = false
            this.toast('comic_local_detector_removed')
          } else void this.downloadModels()
        },
      },
    })
  }

  private async refreshCredits(): Promise<void> {
    if (!this.ready || this.creditsRefreshing || this.draft.toriiApiKey.length === 0) return
    const lifetime = this.lifetime
    const key = this.draft.toriiApiKey
    this.creditsRefreshing = true
    try {
      const result = await ToriiCreditsService.fetch(key)
      if (this.active && lifetime === this.lifetime && key === this.draft.toriiApiKey) {
        this.toriiCredits = result
        await ToriiCreditsService.saveCached(this.context(), key, result)
      }
    } catch (error) {
      DiagnosticLogger.warn('comic-translation', 'torii_credits_failed', (error as Error).message)
      if (this.active && lifetime === this.lifetime && key === this.draft.toriiApiKey) this.toast('comic_torii_credits_failed')
    } finally {
      if (this.active && lifetime === this.lifetime) this.creditsRefreshing = false
    }
  }

  private openEvaluation(): void {
    if (this.evaluationRunning || !this.ready || this.saving) return
    if (this.draft.route === 'torii_whole_page' && this.toriiEvaluationReport.passed()) {
      this.evaluationShown = true
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('comic_translation_live_evaluation_title'), message: t('comic_translation_live_evaluation_confirm'),
      primaryButton: { value: t('common_cancel'), action: () => {} },
      secondaryButton: { value: t('comic_translation_live_evaluation_start'), action: () => { void this.runEvaluation() } },
    })
  }

  private async runEvaluation(): Promise<void> {
    const lifetime = this.lifetime
    this.evaluationRunning = true
    this.saving = true
    try {
      await KomaTranslationSettings.saveConfiguration(this.context(), this.draft)
      if (this.draft.route === 'torii_whole_page') {
        const report = await ToriiWholePageLiveEvaluationService.run(this.context())
        if (!this.active || lifetime !== this.lifetime) return
        this.toriiEvaluationReport = report
        if (report.passed()) this.evaluationShown = true
        else this.getUIContext().showAlertDialog({ title: t('comic_torii_live_evaluation_failed_short'),
          message: report.errorDetail || report.errorCode,
          primaryButton: { value: t('common_ok'), action: () => {} } })
        void this.refreshCredits()
      } else {
        const report = await ComicTranslationLiveEvaluationService.run(this.context())
        if (!this.active || lifetime !== this.lifetime) return
        this.evaluationReport = report
        this.toast(report.passed() ? 'comic_translation_live_evaluation_passed' : 'comic_translation_live_evaluation_not_passed')
      }
    } catch (_error) {
      if (this.active && lifetime === this.lifetime) this.toast('comic_translation_live_evaluation_not_passed')
    } finally {
      if (this.active && lifetime === this.lifetime) { this.evaluationRunning = false; this.saving = false }
    }
  }

  private evaluationSubtitle(): string {
    if (this.evaluationRunning) return t('comic_translation_live_evaluation_running')
    if (this.evaluationReport === null) return t('comic_translation_live_evaluation_hint')
    const report = this.evaluationReport
    const count = `${report.completedPages()}/2`
    return report.errorCode.length > 0 ? AppStrings.format('comic_translation_live_evaluation_failed', report.errorCode, count) :
      AppStrings.format('comic_translation_live_evaluation_result', count, `${report.matchedBlocks()}/${report.expectedBlocks()}`,
        `${(report.totalImageBytes / 1024).toFixed(0)} KB`, `${(report.elapsedMs() / 1000).toFixed(1)} s`)
  }

  @Builder
  private EvaluationSheet() {
    KomaTranslationEvaluationContent({ report: this.toriiEvaluationReport, onClose: () => { this.evaluationShown = false } })
  }

  private async checkConnection(): Promise<void> {
    if (this.connectionRunning || this.draft.sidecarUrl.length === 0) return
    const lifetime = this.lifetime
    const draft = this.draft.copy()
    const config = new MangaTranslatorUiSidecarConfig()
    config.baseUrl = draft.sidecarUrl
    config.username = draft.sidecarUsername
    config.password = draft.sidecarPassword
    config.applyProfile('auto', draft.detectionProfile, draft.inpaintingProfile)
    this.connectionRunning = true
    this.connectionMessage = t('comic_render_service_check_running')
    try {
      await MangaTranslatorUiSidecarConnectionService.check(config)
      if (this.active && lifetime === this.lifetime && draft.sidecarUrl === this.draft.sidecarUrl &&
        draft.sidecarUsername === this.draft.sidecarUsername && draft.sidecarPassword === this.draft.sidecarPassword) {
        this.connectionMessage = t('comic_render_service_check_success')
      }
    } catch (error) {
      if (this.active && lifetime === this.lifetime) this.connectionMessage =
        AppStrings.format('comic_render_service_check_failed', (error as Error).message)
    } finally {
      if (this.active && lifetime === this.lifetime) this.connectionRunning = false
    }
  }

  private async save(): Promise<void> {
    if (!this.ready || this.saving) return
    const lifetime = this.lifetime
    this.saving = true
    try {
      await KomaTranslationSettings.saveConfiguration(this.context(), this.draft)
      if (this.active && this.lifetime === lifetime) this.onClose()
    } catch (_error) {
      if (this.active && this.lifetime === lifetime) this.toast('reader_translation_settings_save_failed')
    } finally {
      if (this.active && this.lifetime === lifetime) this.saving = false
    }
  }

  private async openSources(): Promise<void> {
    if (!this.ready || this.saving) return
    this.saving = true
    try {
      await KomaTranslationSettings.saveConfiguration(this.context(), this.draft)
      if (this.active) this.onOpenSources()
    } catch (_error) { if (this.active) this.toast('reader_translation_settings_save_failed') }
    finally { if (this.active) this.saving = false }
  }

  private selectSource(id: string): void {
    if (this.draft.sourceProfileId === id) return
    const next = this.draft.copy()
    next.sourceProfileId = id
    next.apiModel = ''
    this.draft = next
    this.modelOptions = []
  }

  private compatibleSources(): KomaTranslationLlmSource[] {
    return this.draft.llmSources.filter((source: KomaTranslationLlmSource): boolean =>
      supportsMangaTranslation(source.profile, this.draft.multimodal))
  }

  private async fetchModels(): Promise<void> {
    if (!this.ready || this.fetchingModels || this.draft.sourceProfileId.length === 0) return
    this.fetchingModels = true
    const sourceId = this.draft.sourceProfileId
    const lifetime = this.lifetime
    try {
      const options = await ComicTranslationModelCatalogService.fetchSource(this.context(), sourceId)
      if (this.active && lifetime === this.lifetime && sourceId === this.draft.sourceProfileId) {
        this.modelOptions = options
        if (options.length === 0) this.toast('comment_translation_models_empty')
      }
    } catch (_error) {
      if (this.active && lifetime === this.lifetime) this.toast('reader_translation_model_catalog_failed')
    } finally { if (this.active && lifetime === this.lifetime) this.fetchingModels = false }
  }

  @Builder
  private SourceMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.compatibleSources(), (source: KomaTranslationLlmSource) => {
        MenuItem({ content: source.profile.displayName, symbolEndIcon: this.draft.sourceProfileId === source.profile.sourceProfileId
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.selectSource(source.profile.sourceProfileId) }) })
      }, (source: KomaTranslationLlmSource): string => source.profile.sourceProfileId)
    }
  }

  @Builder
  private ModelMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.modelOptions, (model: string) => {
        MenuItem({ content: model, symbolEndIcon: this.draft.apiModel === model
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('model', model) }) })
      }, (model: string): string => model)
    }
  }

  private async downloadModels(): Promise<void> {
    if (!this.ready || this.modelDownloading || this.modelInstalled) return
    const lifetime = this.lifetime
    this.modelDownloading = true
    try {
      await ComicTranslationModelService.install(this.context())
      if (this.active && this.lifetime === lifetime) {
        this.modelInstalled = await ComicTranslationModelService.isInstalled(this.context())
        this.toast('comic_local_detector_install_success')
      }
    } catch (_error) {
      if (this.active && this.lifetime === lifetime) this.toast('reader_translation_model_download_failed')
    } finally {
      if (this.active && this.lifetime === lifetime) this.modelDownloading = false
    }
  }

  private routeLabel(): string {
    if (this.draft.route === 'self_hosted') return t('comic_visual_route_self_hosted')
    if (this.draft.route === 'torii_whole_page') return t('comic_visual_route_torii')
    return t('comic_visual_route_local')
  }

  private languageLabel(language: string): string {
    return t('reader_translation_language_' + language.replace('-', '_'))
  }

  @Builder
  private RouteMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['local', 'self_hosted', 'torii_whole_page'], (route: string) => {
        MenuItem({ content: t(route === 'local' ? 'comic_visual_route_local' :
          route === 'self_hosted' ? 'comic_visual_route_self_hosted' : 'comic_visual_route_torii'),
          symbolEndIcon: this.draft.route === route ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('route', route) }) })
      })
    }
  }

  @Builder
  private LanguageMenu(source: boolean, select: (action: () => void) => void) {
    Menu() {
      ForEach(source ? ['auto', 'zh-CN', 'zh-TW', 'en', 'ja', 'ko', 'fr', 'de', 'es', 'pt', 'ru'] :
        ['zh-CN', 'zh-TW', 'en', 'ja', 'ko', 'fr', 'de', 'es', 'pt', 'ru'], (language: string) => {
        MenuItem({ content: this.languageLabel(language), symbolEndIcon:
          (source ? this.draft.sourceLanguage : this.draft.targetLanguage) === language
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit(source ? 'source-language' : 'target-language', language) }) })
      })
    }
  }

  @Builder
  private ToriiModelMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(ToriiTranslatorModelCatalog.all(), (model: ToriiTranslatorModel) => {
        MenuItem({ content: `${model.displayName} · ${model.baseCredits}+`, symbolEndIcon: this.draft.toriiModel === model.modelId
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('torii-model', model.modelId) }) })
      }, (model: ToriiTranslatorModel): string => model.modelId)
    }
  }

  @Builder
  private ToriiFontMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(ToriiFontCatalog.forTargetLanguage(this.draft.targetLanguage), (font: ToriiFontOption) => {
        MenuItem({ content: font.displayName, symbolEndIcon: this.draft.toriiFont === font.fontId
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('torii-font', font.fontId) }) })
      }, (font: ToriiFontOption): string => font.fontId)
    }
  }

  @Builder
  private ProfileMenu(field: string, select: (action: () => void) => void) {
    Menu() {
      ForEach(field === 'detection' ? ['high_recall', 'balanced'] : ['quality', 'fast'], (value: string) => {
        MenuItem({ content: t('comic_render_service_' + (field === 'detection' ? 'detection_' : 'inpainting_') + value),
          symbolEndIcon: (field === 'detection' ? this.draft.detectionProfile : this.draft.inpaintingProfile) === value
            ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit(field, value) }) })
      })
    }
  }

  @Builder
  private ReasoningMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['', 'none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'], (effort: string) => {
        MenuItem({ content: effort.length === 0 ? t('llm_reasoning_effort_model_default') : effort,
          symbolEndIcon: this.draft.reasoningEffort === effort ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('reasoning', effort) }) })
      })
    }
  }

  @Builder
  private SettingsForm() {
      Column({ space: ThemeConstants.SPACE_LG }) {
        GroupedListSection({ title: t('comic_translation_group_language') }) {
          ConciseListRow({ title: t('comic_visual_route'), trailingText: this.routeLabel(),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.RouteMenu(select) } })
          ListDivider()
          ConciseListRow({ title: t('reader_translation_source_language'), trailingText: this.languageLabel(this.draft.sourceLanguage),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.LanguageMenu(true, select) } })
          ListDivider()
          ConciseListRow({ title: t('reader_translation_target_language'), trailingText: this.languageLabel(this.draft.targetLanguage),
            trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.LanguageMenu(false, select) } })
        }
        if (this.draft.route === 'local') {
          GroupedListSection({ title: t('comic_local_detector_model') }) {
            ConciseListRow({ title: t('comic_local_detector_model'),
              subtitle: t('comic_local_detector_notice'),
              trailingText: this.modelDownloading ? t('comic_local_detector_downloading') :
                this.modelInstalled ? t('settings_reader_super_resolution_system_ready') : '',
              actionButtonText: t(this.modelInstalled ? 'comic_local_detector_remove' : 'comic_local_detector_install'),
              actionButtonEnabled: this.ready && !this.modelDownloading,
              actionButtonAction: (): void => { this.manageModels() }, showChevron: false })
          }
        }
        if (this.draft.route !== 'torii_whole_page') {
          GroupedListSection() {
            ConciseListRow({ title: t('llm_binding_source'),
              trailingText: this.draft.textSource()?.profile.displayName ?? t('llm_binding_not_configured'),
              trailingDropdown: this.compatibleSources().length > 0, dropdownMenuEnabled: this.compatibleSources().length > 0,
              isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.SourceMenu(select) },
              action: () => { if (this.compatibleSources().length === 0) void this.openSources() } })
            ListDivider()
            ConciseListRow({ title: t('llm_sources_title'), subtitle: t('llm_sources_hint'),
              isEnabled: this.ready && !this.saving,
              action: () => { void this.openSources() } })
            ListDivider()
            if (this.modelOptions.length === 0) {
              KomaFormTextField({ label: t('llm_binding_model'), value: this.draft.apiModel,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('model', value) } })
                .padding(ThemeConstants.SPACE_MD)
              ListDivider()
            }
            ConciseListRow({ title: t('llm_source_catalog'),
              trailingText: this.fetchingModels ? t('comment_translation_fetch_models_loading') : '', showChevron: false,
              isEnabled: this.ready && !this.saving && !this.fetchingModels &&
                (this.draft.textSource()?.profile.capabilities.modelCatalog ?? false),
              action: () => { void this.fetchModels() } })
            if (this.modelOptions.length > 0) {
              ListDivider()
              ConciseListRow({ title: t('llm_binding_model'), trailingText: this.draft.apiModel,
                trailingDropdown: true, dropdownMenuEnabled: true,
                dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ModelMenu(select) } })
            }
            ListDivider()
            ConciseListRow({ title: t('llm_reasoning_effort'), subtitle: t('llm_reasoning_effort_hint'),
              trailingText: this.draft.reasoningEffort || t('llm_reasoning_effort_model_default'),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ReasoningMenu(select) } })
            ListDivider()
            ConciseListRow({ title: t('comic_translation_multimodal_assist'),
              subtitle: t('comic_translation_multimodal_assist_notice'), hasSwitch: true, showChevron: false,
              checked: this.draft.multimodal, isEnabled: this.ready && !this.saving,
              switchAction: (value: boolean) => {
                const source = this.draft.textSource()
                if (value && source !== null && !supportsMangaTranslation(source.profile, true)) {
                  this.toast('comic_translation_multimodal_source_unsupported')
                } else { const next = this.draft.copy(); next.multimodal = value; this.draft = next }
              } })
          }
        }
        if (this.draft.route === 'self_hosted') {
          GroupedListSection({ title: t('comic_render_service_title') }) {
            Column({ space: ThemeConstants.SPACE_MD }) {
              KomaFormTextField({ label: t('comic_render_service_url'), value: this.draft.sidecarUrl,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('sidecar-url', value) } })
              KomaFormTextField({ label: t('comic_render_service_username'), value: this.draft.sidecarUsername,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('username', value) } })
              KomaFormTextField({ label: t('comic_render_service_password'), value: this.draft.sidecarPassword, isPassword: true,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('password', value) } })
            }.padding(ThemeConstants.SPACE_MD)
            ListDivider()
            ConciseListRow({ title: t('comic_render_service_detection'),
              trailingText: t('comic_render_service_detection_' + this.draft.detectionProfile),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ProfileMenu('detection', select) } })
            ListDivider()
            ConciseListRow({ title: t('comic_render_service_inpainting'),
              trailingText: t('comic_render_service_inpainting_' + this.draft.inpaintingProfile),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ProfileMenu('inpainting', select) } })
            ListDivider()
            ConciseListRow({ title: t('comic_render_service_check'),
              subtitle: this.connectionMessage || t('comic_render_service_check_hint'), subtitleMaxLines: 3,
              isEnabled: this.ready && !this.saving && !this.connectionRunning && this.draft.sidecarUrl.length > 0,
              showChevron: false, action: (): void => { void this.checkConnection() } })
          }
        }
        if (this.draft.route === 'torii_whole_page') {
          GroupedListSection({ title: t('comic_visual_route_torii') }) {
            KomaFormTextField({ label: t('comic_torii_api_key'), value: this.draft.toriiApiKey, isPassword: true,
              isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('torii-key', value) } })
              .padding(ThemeConstants.SPACE_MD)
            ListDivider()
            ConciseListRow({ title: t('comic_torii_model'),
              trailingText: ToriiTranslatorModelCatalog.find(this.draft.toriiModel)?.displayName ?? this.draft.toriiModel,
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ToriiModelMenu(select) } })
            ListDivider()
            ConciseListRow({ title: t('comic_torii_font'), trailingText: ToriiFontCatalog.displayName(this.draft.toriiFont),
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ToriiFontMenu(select) } })
            ListDivider()
            ConciseListRow({ title: t('comic_torii_available_credits'),
              trailingText: this.toriiCredits === null ? '' : this.toriiCredits.credits.toFixed(2).replace(/\.00$/, ''),
              isEnabled: this.ready && !this.creditsRefreshing && this.draft.toriiApiKey.length > 0,
              showChevron: false, action: (): void => { void this.refreshCredits() } })
          }
        }
        if (this.draft.route !== 'self_hosted') {
          GroupedListSection() {
            ConciseListRow({ title: t('comic_translation_live_evaluation_title'), subtitle: this.evaluationSubtitle(), subtitleMaxLines: 3,
              trailingText: this.draft.route === 'torii_whole_page' ?
                t(this.toriiEvaluationReport.passed() ? 'comic_torii_live_evaluation_view' : 'comic_torii_live_evaluation_pages') : '',
              isEnabled: this.ready && !this.saving && !this.evaluationRunning &&
                (this.draft.route === 'torii_whole_page' ? this.draft.toriiApiKey.length > 0 : this.draftTextConfigured()),
              showChevron: false, action: () => { this.openEvaluation() } })
          }
        }
        KomaActionButton({ label: t('common_save'), kind: 'primary', fullWidth: true,
          isEnabled: this.ready && !this.saving, action: (): void => { void this.save() } })
      }
      .width('100%')
      .bindSheet($$this.evaluationShown, this.EvaluationSheet(), { height: SheetSize.LARGE, showClose: false })
  }

  build() {
    if (this.sheetPresentation) {
      KomaModalScaffold({ title: t('comic_translation_settings_title'),
        modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'), onClose: (): void => { this.onClose() } }) {
        Column() { this.SettingsForm() }
          .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG,
            top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_LG })
      }
    } else {
      this.SettingsForm()
    }
  }
}
