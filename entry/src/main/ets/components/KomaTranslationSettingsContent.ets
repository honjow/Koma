import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaFormTextField } from './ui/KomaFormTextField'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaTranslationSettings, KomaTranslationSettingsSnapshot } from '../readerTranslation/KomaTranslationSettings'
import { ComicTranslationModelService } from '../readerTranslation/services/ComicTranslationModelService'
import { ToriiTranslatorModel, ToriiTranslatorModelCatalog } from '../readerTranslation/settings/ComicVisualProviderSettings'

function t(key: string): string { return AppStrings.get(key) }

/** Adopted translation configuration inside the existing reader sheet, using Koma's form rows. */
@ComponentV2
export struct KomaTranslationSettingsContent {
  @Event onClose: () => void = () => {}
  @Local private draft: KomaTranslationSettingsSnapshot = new KomaTranslationSettingsSnapshot()
  @Local private ready: boolean = false
  @Local private saving: boolean = false
  @Local private modelInstalled: boolean = false
  @Local private modelDownloading: boolean = false
  private active: boolean = false
  private lifetime: number = 0

  aboutToAppear(): void {
    this.active = true
    const lifetime = ++this.lifetime
    void this.load(lifetime)
  }

  aboutToDisappear(): void { this.active = false; this.lifetime += 1 }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async load(lifetime: number): Promise<void> {
    try {
      const value = await KomaTranslationSettings.load(this.context())
      const installed = await ComicTranslationModelService.isInstalled(this.context())
      if (!this.active || lifetime !== this.lifetime) return
      this.draft = value
      this.modelInstalled = installed
      this.ready = true
    } catch (_error) {
      if (this.active && lifetime === this.lifetime) this.toast('reader_translation_settings_load_failed')
    }
  }

  private toast(key: string): void {
    this.getUIContext().getPromptAction().showToast({ message: t(key) })
  }

  private edit(key: string, value: string): void {
    const next = this.draft.copy()
    if (key === 'api-url') next.apiBaseUrl = value.trim()
    if (key === 'api-key') next.apiKey = value.trim()
    if (key === 'model') next.apiModel = value.trim()
    if (key === 'sidecar-url') next.sidecarUrl = value.trim()
    if (key === 'username') next.sidecarUsername = value.trim()
    if (key === 'password') next.sidecarPassword = value
    if (key === 'torii-key') next.toriiApiKey = value.trim()
    if (key === 'route') next.route = value
    if (key === 'source-language') next.sourceLanguage = value
    if (key === 'target-language') next.targetLanguage = value
    if (key === 'torii-model') next.toriiModel = value
    this.draft = next
  }

  private async save(): Promise<void> {
    if (!this.ready || this.saving) return
    const lifetime = this.lifetime
    this.saving = true
    try {
      await KomaTranslationSettings.save(this.context(), this.draft)
      if (this.active && this.lifetime === lifetime) this.onClose()
    } catch (_error) {
      if (this.active && this.lifetime === lifetime) this.toast('reader_translation_settings_save_failed')
    } finally {
      if (this.active && this.lifetime === lifetime) this.saving = false
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
        MenuItem({ content: model.displayName, symbolEndIcon: this.draft.toriiModel === model.modelId
          ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select(() => { this.edit('torii-model', model.modelId) }) })
      }, (model: ToriiTranslatorModel): string => model.modelId)
    }
  }

  build() {
    KomaModalScaffold({ title: t('comic_translation_settings_title'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'), onClose: (): void => { this.onClose() } }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        GroupedListSection() {
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
          GroupedListSection() {
            ConciseListRow({ title: t('comic_local_detector_model'),
              subtitle: t('comic_local_detector_notice'),
              trailingText: this.modelDownloading ? t('comic_local_detector_downloading') :
                this.modelInstalled ? t('settings_reader_super_resolution_system_ready') : '',
              actionButtonText: this.modelInstalled ? '' : t('comic_local_detector_install'),
              actionButtonEnabled: this.ready && !this.modelDownloading,
              actionButtonAction: (): void => { void this.downloadModels() }, showChevron: false })
          }
        }
        if (this.draft.route !== 'torii_whole_page') {
          GroupedListSection({ title: t('llm_source_type_api') }) {
            Column({ space: ThemeConstants.SPACE_MD }) {
              KomaFormTextField({ label: t('llm_source_base_url'), value: this.draft.apiBaseUrl,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('api-url', value) } })
              KomaFormTextField({ label: t('llm_source_api_key'), value: this.draft.apiKey, isPassword: true,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('api-key', value) } })
              KomaFormTextField({ label: t('llm_binding_model'), value: this.draft.apiModel,
                isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('model', value) } })
            }.padding(ThemeConstants.SPACE_MD)
            ListDivider()
            ConciseListRow({ title: t('comic_translation_multimodal_assist'),
              subtitle: t('comic_translation_multimodal_assist_notice'), hasSwitch: true, showChevron: false,
              checked: this.draft.multimodal, isEnabled: this.ready && !this.saving,
              switchAction: (value: boolean) => { const next = this.draft.copy(); next.multimodal = value; this.draft = next } })
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
          }
        }
        if (this.draft.route === 'torii_whole_page') {
          GroupedListSection() {
            KomaFormTextField({ label: t('comic_torii_api_key'), value: this.draft.toriiApiKey, isPassword: true,
              isEnabled: this.ready && !this.saving, change: (value: string) => { this.edit('torii-key', value) } })
              .padding(ThemeConstants.SPACE_MD)
            ListDivider()
            ConciseListRow({ title: t('comic_torii_model'),
              trailingText: ToriiTranslatorModelCatalog.find(this.draft.toriiModel)?.displayName ?? this.draft.toriiModel,
              trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.ready && !this.saving,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ToriiModelMenu(select) } })
          }
        }
        KomaActionButton({ label: t('common_save'), kind: 'primary', fullWidth: true,
          isEnabled: this.ready && !this.saving, action: (): void => { void this.save() } })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG,
        top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_LG })
    }
  }
}
