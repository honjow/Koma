import { common, Want } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaTranslationSettings, KomaTranslationSettingsSnapshot } from '../readerTranslation/KomaTranslationSettings'
import { KomaTranslationLlmSource } from '../readerTranslation/KomaTranslationLlmSource'
import { generateLlmSourceProfileId, LLM_SOURCE_TYPE_OPENAI_COMPATIBLE,
  LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL } from '../readerTranslation/model/LlmSourceProfile'
import { CodexOAuthDeviceSession } from '../readerTranslation/model/CodexOAuth'
import { LlmSourceSecretStore } from '../readerTranslation/services/LlmSourceSecretStore'
import { ExperimentalCodexOAuthService } from '../readerTranslation/services/ExperimentalCodexOAuthService'
import { ComicTranslationCodexUsageService, CodexUsageSnapshot,
  CodexUsageWindow } from '../readerTranslation/services/ComicTranslationCodexUsageService'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { komaMenuOptions } from '../theme/KomaPopupOptions'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaFormTextField } from './ui/KomaFormTextField'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaModalScaffold } from './KomaModalScaffold'

function t(key: string): string { return AppStrings.get(key) }

/** NextE's source list/detail responsibilities, backed by Koma's existing secure settings owner. */
@ComponentV2
export struct KomaTranslationSourcesContent {
  @Local private settings: KomaTranslationSettingsSnapshot = new KomaTranslationSettingsSnapshot()
  @Local private editing: KomaTranslationLlmSource = new KomaTranslationLlmSource()
  @Local private editorShown: boolean = false
  @Local private ready: boolean = false
  @Local private busy: boolean = false
  @Local private addMenuShown: boolean = false
  @Local private codexConnected: boolean = false
  @Local private codexAccountId: string = ''
  @Local private codexLoginBusy: boolean = false
  @Local private codexUserCode: string = ''
  @Local private codexVerificationUrl: string = ''
  @Local private codexUsage: CodexUsageSnapshot | null = null
  @Local private codexUsageRefreshing: boolean = false
  private active: boolean = false
  private editorLifetime: number = 0

  aboutToAppear(): void { this.active = true; void this.load() }
  aboutToDisappear(): void { this.active = false; this.editorLifetime += 1 }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async load(): Promise<void> {
    try {
      const value = await KomaTranslationSettings.load(this.context())
      value.llmSources.forEach((source: KomaTranslationLlmSource) => { source.codexTokens = '' })
      if (this.active) { this.settings = value; this.ready = true }
    } catch (_error) { if (this.active) this.toast('reader_translation_settings_load_failed') }
  }

  private toast(key: string): void {
    this.getUIContext().getPromptAction().showToast({ message: t(key) })
  }

  private open(source: KomaTranslationLlmSource | null, sourceType: string = LLM_SOURCE_TYPE_OPENAI_COMPATIBLE): void {
    if (this.busy) return
    this.editorLifetime += 1
    this.codexConnected = false
    this.codexAccountId = ''
    this.codexUserCode = ''
    this.codexVerificationUrl = ''
    this.codexUsage = null
    this.codexLoginBusy = false
    this.codexUsageRefreshing = false
    this.editing = source === null ? new KomaTranslationLlmSource() : source.copy()
    if (source === null) {
      this.editing.profile.sourceProfileId = generateLlmSourceProfileId()
      this.editing.profile.sourceType = sourceType
      this.editing.profile.displayName = t(sourceType === LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL ?
        'llm_source_type_codex' : 'llm_source_type_api')
      this.editing.profile.baseUrl = sourceType === LLM_SOURCE_TYPE_OPENAI_COMPATIBLE ? 'https://api.openai.com' : ''
      this.editing.profile.sourceRevision = 1
      this.editing.profile.createdAt = Date.now()
      this.editing.profile.updatedAt = this.editing.profile.createdAt
      this.editing.profile.capabilities.responses = true
      this.editing.profile.capabilities.imageInput = true
      this.editing.profile.capabilities.modelCatalog = true
      this.editing.profile.capabilities.chatCompletions = sourceType === LLM_SOURCE_TYPE_OPENAI_COMPATIBLE
      this.editing.profile.capabilities.usage = sourceType === LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL
    }
    this.editorShown = true
    if (this.isCodexSource()) void this.loadCodexAccount(this.editorLifetime)
  }

  private isCodexSource(): boolean {
    return this.editing.profile.sourceType === LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL
  }

  private closeEditor(): void {
    this.editorShown = false
    this.editorLifetime += 1
  }

  private editorCurrent(id: string, lifetime: number): boolean {
    return this.active && this.editorShown && this.editing.profile.sourceProfileId === id &&
      this.editorLifetime === lifetime
  }

  private async loadCodexAccount(lifetime: number): Promise<void> {
    const id = this.editing.profile.sourceProfileId
    try {
      const tokens = await LlmSourceSecretStore.readCodexTokens(this.context(), id)
      if (!this.editorCurrent(id, lifetime)) return
      this.codexConnected = tokens !== null
      this.codexAccountId = tokens?.accountId ?? ''
      if (tokens === null) return
      const cached = await ComicTranslationCodexUsageService.cachedSource(this.context(), id, tokens.accountId)
      if (!this.editorCurrent(id, lifetime)) return
      this.codexUsage = cached
      void this.refreshCodexUsage()
    } catch (error) {
      DiagnosticLogger.warn('llm-source', 'codex_account_load_failed', (error as Error).message)
    }
  }

  private codexStatusSubtitle(): string {
    if (this.codexLoginBusy) return this.codexUserCode.length > 0 ?
      AppStrings.format('comic_translation_codex_code', this.codexUserCode) : t('comic_translation_codex_requesting')
    return this.codexConnected ? (this.codexAccountId || t('comic_translation_codex_connected')) :
      t('comic_translation_codex_login_hint')
  }

  private copyCodexUserCode(): void {
    if (this.codexUserCode.length === 0) return
    try {
      pasteboard.getSystemPasteboard().setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.codexUserCode))
      this.toast('llm_source_codex_code_copied')
    } catch (_error) { this.toast('llm_source_codex_code_copy_failed') }
  }

  private openCodexLoginPage(): void {
    if (this.codexVerificationUrl.length === 0) return
    const want: Want = { action: 'ohos.want.action.viewData', uri: this.codexVerificationUrl }
    this.context().startAbility(want).catch(() => { this.toast('comic_translation_codex_open_failed') })
  }

  private async startCodexLogin(): Promise<void> {
    if (this.busy || this.codexLoginBusy) return
    const id = this.editing.profile.sourceProfileId
    const lifetime = this.editorLifetime
    if (!await this.saveSource(false) || !this.editorCurrent(id, lifetime)) return
    this.codexLoginBusy = true
    try {
      const session: CodexOAuthDeviceSession = await ExperimentalCodexOAuthService.requestDeviceCode()
      if (!this.editorCurrent(id, lifetime)) return
      this.codexUserCode = session.userCode
      this.codexVerificationUrl = session.verificationUrl
      this.openCodexLoginPage()
      await ExperimentalCodexOAuthService.completeSourceDeviceLogin(this.context(), id, session)
      if (!this.editorCurrent(id, lifetime)) return
      this.toast('comic_translation_codex_login_success')
      await this.load()
      await this.loadCodexAccount(lifetime)
    } catch (error) {
      DiagnosticLogger.warn('llm-source', 'codex_login_failed', (error as Error).message)
      if (this.editorCurrent(id, lifetime)) this.getUIContext().getPromptAction().showToast({
        message: AppStrings.format('comic_translation_codex_login_failed', DiagnosticLogger.errorSummary(error as Error)),
      })
    } finally {
      if (this.editorCurrent(id, lifetime)) {
        this.codexLoginBusy = false
        this.codexUserCode = ''
        this.codexVerificationUrl = ''
      }
    }
  }

  private codexAccountAction(): void {
    if (this.codexLoginBusy) { this.copyCodexUserCode(); return }
    if (!this.codexConnected) { void this.startCodexLogin(); return }
    this.getUIContext().showAlertDialog({
      title: t('comic_translation_codex_logout'), message: t('llm_source_codex_logout_confirm'),
      primaryButton: { value: t('common_cancel'), action: () => {} },
      secondaryButton: { value: t('comic_translation_codex_logout'), action: () => { void this.logoutCodex() } },
    })
  }

  private async logoutCodex(): Promise<void> {
    const id = this.editing.profile.sourceProfileId
    const lifetime = this.editorLifetime
    try {
      await LlmSourceSecretStore.clearCodexTokens(this.context(), id)
      await ComicTranslationCodexUsageService.clearCachedSource(this.context(), id)
      if (!this.editorCurrent(id, lifetime)) return
      this.codexConnected = false
      this.codexAccountId = ''
      this.codexUsage = null
      await this.load()
      this.toast('comic_translation_codex_logout_success')
    } catch (_error) { if (this.editorCurrent(id, lifetime)) this.toast('comic_translation_codex_logout_failed') }
  }

  private async refreshCodexUsage(): Promise<void> {
    if (!this.codexConnected || this.codexAccountId.length === 0 || this.codexUsageRefreshing) return
    const id = this.editing.profile.sourceProfileId
    const accountId = this.codexAccountId
    const lifetime = this.editorLifetime
    this.codexUsageRefreshing = true
    try {
      const value = await ComicTranslationCodexUsageService.fetchSource(this.context(), id)
      if (!this.editorCurrent(id, lifetime) || this.codexAccountId !== accountId) return
      this.codexUsage = value
      await ComicTranslationCodexUsageService.saveCachedSource(this.context(), id, accountId, value)
    } catch (error) {
      DiagnosticLogger.warn('llm-source', 'codex_usage_background_failed', (error as Error).message)
    } finally { if (this.editorCurrent(id, lifetime)) this.codexUsageRefreshing = false }
  }

  private usageText(): string {
    const values: string[] = []
    if (this.codexUsage?.fiveHour) values.push(this.usageWindowText('5H', this.codexUsage.fiveHour))
    if (this.codexUsage?.weekly) values.push(this.usageWindowText('7D', this.codexUsage.weekly))
    return values.join(' · ')
  }

  private usageWindowText(label: string, window: CodexUsageWindow): string {
    return `${label} ${Math.max(0, Math.min(100, Math.round(100 - window.usedPercent)))}%`
  }

  private edit(field: string, value: string): void {
    const source = this.editing.copy()
    if (field === 'name') source.profile.displayName = value
    if (field === 'url') source.profile.baseUrl = value.trim()
    if (field === 'key') source.apiKey = value.trim()
    this.editing = source
  }

  private capability(field: string, value: boolean): void {
    const source = this.editing.copy()
    if (field === 'responses') {
      source.profile.capabilities.responses = value
      source.profile.capabilities.imageInput = value
    }
    if (field === 'image-input') source.profile.capabilities.imageInput = value
    if (field === 'catalog') source.profile.capabilities.modelCatalog = value
    this.editing = source
  }

  private async saveSource(close: boolean = true): Promise<boolean> {
    if (this.busy) return false
    const id = this.editing.profile.sourceProfileId
    const lifetime = this.editorLifetime
    const source = this.editing.copy()
    this.busy = true
    try {
      const next = await KomaTranslationSettings.load(this.context())
      source.profile.displayName = source.profile.displayName.trim()
      const index = next.llmSources.findIndex((item: KomaTranslationLlmSource): boolean =>
        item.profile.sourceProfileId === source.profile.sourceProfileId)
      source.profile.updatedAt = Date.now()
      source.profile.sourceRevision = index < 0 ? 1 : next.llmSources[index].profile.sourceRevision + 1
      if (index < 0) next.llmSources.push(source)
      else next.llmSources[index] = source
      await KomaTranslationSettings.save(this.context(), next)
      await this.load()
      if (close && this.editorCurrent(id, lifetime)) this.closeEditor()
      return true
    } catch (_error) { if (this.editorCurrent(id, lifetime)) this.toast('reader_translation_settings_save_failed'); return false }
    finally { if (this.active) this.busy = false }
  }

  private confirmDelete(): void {
    this.getUIContext().showAlertDialog({
      title: t('llm_source_delete'), message: this.settings.sourceProfileId === this.editing.profile.sourceProfileId ?
        AppStrings.format('llm_source_delete_referenced', t('comic_translation_settings_title')) : t('llm_source_delete_confirm'),
      primaryButton: { value: t('common_cancel'), action: () => {} },
      secondaryButton: { value: t('common_delete'), action: () => { void this.deleteSource() } },
    })
  }

  private async deleteSource(): Promise<void> {
    if (this.busy) return
    const id = this.editing.profile.sourceProfileId
    const lifetime = this.editorLifetime
    this.busy = true
    try {
      const next = await KomaTranslationSettings.load(this.context())
      next.llmSources = next.llmSources.filter((source: KomaTranslationLlmSource): boolean =>
        source.profile.sourceProfileId !== id)
      // As in NextE, keep the missing binding explicit. Never silently use the first remaining source.
      await KomaTranslationSettings.save(this.context(), next)
      await ComicTranslationCodexUsageService.clearCachedSource(this.context(), id)
      await this.load()
      if (this.editorCurrent(id, lifetime)) this.closeEditor()
    } catch (_error) { if (this.editorCurrent(id, lifetime)) this.toast('reader_translation_settings_save_failed') }
    finally { if (this.active) this.busy = false }
  }

  @Builder
  private Editor() {
    KomaModalScaffold({ title: t('llm_source_detail_title'), onClose: () => { this.closeEditor() } }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
        GroupedListSection() {
          ConciseListRow({ title: t('llm_source_type'), showChevron: false,
            leadingIcon: this.isCodexSource() ? $r('sys.symbol.person') : $r('sys.symbol.cloud'),
            trailingText: t(this.isCodexSource() ? 'llm_source_type_codex' : 'llm_source_type_api') })
          ListDivider()
          Column({ space: ThemeConstants.SPACE_MD }) {
            KomaFormTextField({ label: t('llm_source_name'), value: this.editing.profile.displayName,
              isEnabled: !this.busy, change: (value: string) => { this.edit('name', value) } })
            if (!this.isCodexSource()) {
              KomaFormTextField({ label: t('llm_source_base_url'), value: this.editing.profile.baseUrl,
                isEnabled: !this.busy, change: (value: string) => { this.edit('url', value) } })
              KomaFormTextField({ label: t('llm_source_api_key'), value: this.editing.apiKey, isPassword: true,
                isEnabled: !this.busy, change: (value: string) => { this.edit('key', value) } })
            }
          }.padding(ThemeConstants.SPACE_MD)
        }
        if (this.isCodexSource()) {
          GroupedListSection() {
            ConciseListRow({ title: t(this.codexConnected ? 'llm_source_codex_account' : 'comic_translation_codex_login'),
              subtitle: this.codexStatusSubtitle(), wrapTitle: true, subtitleMaxLines: 2147483647,
              leadingIcon: $r('sys.symbol.person'), showChevron: false,
              trailingText: this.codexConnected ? t('comic_translation_codex_connected') :
                (this.codexLoginBusy && this.codexUserCode.length > 0 ? t('llm_source_codex_copy_code') : ''),
              isEnabled: !this.busy, action: () => { this.codexAccountAction() } })
            if (this.usageText().length > 0) {
              ListDivider()
              ConciseListRow({ title: t('comic_translation_codex_usage'), subtitle: this.usageText(),
                trailingText: this.codexUsage?.planType ?? '', showChevron: false,
                action: () => { void this.refreshCodexUsage() } })
            }
          }
          Text(t('comic_translation_codex_experimental_hint'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%')
        } else {
          GroupedListSection({ title: t('llm_sources_title') }) {
            ConciseListRow({ title: t('llm_source_support_manga'), hasSwitch: true, showChevron: false,
              isEnabled: !this.busy, checked: this.editing.profile.capabilities.responses,
              switchAction: (value: boolean) => { this.capability('responses', value) } })
            ListDivider()
            ConciseListRow({ title: t('llm_source_support_catalog'), hasSwitch: true, showChevron: false,
              isEnabled: !this.busy, checked: this.editing.profile.capabilities.modelCatalog,
              switchAction: (value: boolean) => { this.capability('catalog', value) } })
          }
          Text(t('llm_source_support_manga_hint'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%')
        }
        KomaActionButton({ label: t('common_save'), fullWidth: true, kind: 'primary', isEnabled: !this.busy && !this.codexLoginBusy,
          action: () => { void this.saveSource() } })
        if (this.settings.llmSources.some((source: KomaTranslationLlmSource): boolean =>
          source.profile.sourceProfileId === this.editing.profile.sourceProfileId)) {
          KomaActionButton({ label: t('common_delete'), fullWidth: true, isEnabled: !this.busy && !this.codexLoginBusy,
            action: () => { this.confirmDelete() } })
        }
      }.padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  private AddSourceMenu() {
    Menu() {
      MenuItem({ content: t('llm_source_type_api') }).onClick(() => {
        this.addMenuShown = false
        this.open(null, LLM_SOURCE_TYPE_OPENAI_COMPATIBLE)
      })
      MenuItem({ content: t('llm_source_type_codex') }).onClick(() => {
        this.addMenuShown = false
        this.open(null, LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL)
      })
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      GroupedListSection() {
        ForEach(this.settings.llmSources, (source: KomaTranslationLlmSource, index: number) => {
          if (index > 0) ListDivider()
          ConciseListRow({ title: source.profile.displayName,
            subtitle: source.profile.sourceType === LLM_SOURCE_TYPE_CODEX_OAUTH_EXPERIMENTAL ?
              t('llm_source_type_codex') : source.profile.baseUrl,
            isEnabled: this.ready && !this.busy, action: () => { this.open(source) } })
        }, (source: KomaTranslationLlmSource): string => source.profile.sourceProfileId)
      }
      KomaActionButton({ label: t('llm_source_add'), fullWidth: true, kind: 'primary',
        isEnabled: this.ready && !this.busy, action: () => { this.addMenuShown = true } })
        .bindMenu(this.addMenuShown, this.AddSourceMenu(), komaMenuOptions())
    }
    .bindSheet($$this.editorShown, this.Editor(), { height: SheetSize.LARGE, showClose: false })
  }
}
