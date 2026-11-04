import { komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { ImageRuleStore, subscriptionDocumentKind } from '../model/ImageRuleStore'
import { ImageRuleSubscription, imageRuleSubscriptionName } from '../model/ImageBannerRules'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { pasteboard } from '@kit.BasicServicesKit'
import { AppStrings } from '../i18n/AppStrings'
import { SourceIndexRepository, SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { isValidHttpUrl, resolveIndexDocumentUrl, sourceRepositoryDisplayName, SourceRepositoryMetadata } from '../sourceRuntime/SourceIndexMetadata'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { KomaMenuController, KomaMenuGroup, KomaMenuAction } from '../components/ui/KomaMenuController'
import { KomaTextInputDialog } from '../components/ui/KomaTextInputDialog'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { connectLanguageState } from '../state/LanguageState'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct SourceSubscriptionsPage {
  @Param embedded: boolean = false
  @Param chrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  @Local private ruleState: ImageRuleState = connectImageRuleState()
  @Local private ruleSubscriptions: ImageRuleSubscription[] = []
  private editingRuleUrl: string = ''
  private dialogId: number = -1
  private menu: KomaMenuController = new KomaMenuController()
  @Local private editingUrl: string = ''
  @Local private name: string = ''

  aboutToAppear(): void {
    void this.loadRules()
    void this.cache.prepare(this.context(), connectLanguageState().effectiveLocale)
      .then((): Promise<void> => this.refreshMetadata())
      .catch((): void => { this.error = AppStrings.get('source_catalog_subscription_read_failed') })
  }

  aboutToDisappear(): void { this.closeDialog(); this.menu.close() }

  @Monitor('ruleState.dataRevision')
  private rulesChanged(): void { void this.loadRules() }
  private async loadRules(): Promise<void> {
    try { this.ruleSubscriptions = await ImageRuleStore.forContext(this.context()).list() }
    catch (_error) { this.error = AppStrings.get('image_plugins_storage_failed') }
  }

  @Monitor('chrome.requestId')
  private onCommand(): void {
    if (this.chrome.action === 'addSubscription') this.openAddDialog()
  }

  private openAddDialog(repository?: SourceIndexRepository, rule?: ImageRuleSubscription): void {
    if (this.busy || this.dialogId >= 0) return
    this.editingUrl = repository?.url ?? ''
    this.editingRuleUrl = rule?.url ?? ''
    this.url = rule?.url ?? repository?.url ?? ''
    this.name = rule?.customName ?? repository?.customName ?? ''
    this.error = ''
    void this.getUIContext().getPromptAction().openCustomDialog({ systemMaterial: komaDialogMaterial(),
      builder: () => { this.AddDialog() }, alignment: DialogAlignment.Center, autoCancel: true,
      onWillDismiss: (action: DismissDialogAction): void => { if (!this.busy) action.dismiss() },
      onDidDisappear: (): void => { this.dialogId = -1; this.error = '' },
    }).then((id: number): void => { this.dialogId = id })
  }

  private closeDialog(): void {
    if (this.dialogId < 0) return
    const id = this.dialogId
    this.dialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }
  @Local private cache: SourcePackageManagerCache = appSourcePackageManagerCache
  @Local private url: string = ''
  @Local private busy: boolean = false
  @Local private error: string = ''

  private context(): common.UIAbilityContext { return getContext(this) as common.UIAbilityContext }

  private readFailure(reason?: string): string {
    const code = ['invalid_url', 'network_error', 'http_error', 'invalid_json', 'invalid_index_format'].includes(reason ?? '')
      ? reason! : 'unknown'
    return AppStrings.format('source_pkg_index_load_failed', AppStrings.get(`source_pkg_reason_${code}`))
  }

  private async add(): Promise<void> {
    if (this.busy || !isValidHttpUrl(this.url.trim())) return
    this.busy = true
    this.error = ''
    try {
      const service = new SourceIndexService(this.context())
      const url = this.url.trim()
      if (this.repositories.some((repository: SourceIndexRepository): boolean =>
        repository.url !== this.editingUrl && resolveIndexDocumentUrl(repository.url) === resolveIndexDocumentUrl(url))) {
        this.error = AppStrings.get('source_catalog_subscription_exists'); return
      }
      const ruleStore = ImageRuleStore.forContext(this.context())
      if (this.ruleSubscriptions.some((rule: ImageRuleSubscription): boolean => rule.url !== this.editingRuleUrl &&
        resolveIndexDocumentUrl(rule.url) === resolveIndexDocumentUrl(url))) {
        this.error = AppStrings.get('source_catalog_subscription_exists'); return
      }
      if (this.editingRuleUrl && resolveIndexDocumentUrl(this.editingRuleUrl) === resolveIndexDocumentUrl(url)) {
        await ruleStore.rename(this.editingRuleUrl, this.name)
        this.closeDialog(); return
      }
      const sameSource = this.editingUrl.length > 0 && resolveIndexDocumentUrl(this.editingUrl) === resolveIndexDocumentUrl(url)
      const document = sameSource ? undefined : await ruleStore.fetchDocument(url)
      const kind = document === undefined ? 'source' : await taskpool.execute(subscriptionDocumentKind, document) as string
      if (kind === 'image_rules') {
        if (this.editingUrl) { this.error = AppStrings.get('subscription_type_changed'); return }
        await ruleStore.add(url, this.name, document, this.editingRuleUrl || undefined)
        this.closeDialog(); return
      }
      if (this.editingRuleUrl) { this.error = AppStrings.get('subscription_type_changed'); return }
      if (kind !== 'source') { this.error = AppStrings.get('subscription_format_invalid'); return }
      const addressChanged = this.editingUrl.length === 0 ||
        resolveIndexDocumentUrl(this.editingUrl) !== resolveIndexDocumentUrl(url)
      let metadata: SourceRepositoryMetadata | undefined
      if (addressChanged) {
        const result = await service.fetchIndex(url, document)
        if (!result.ok) { this.error = this.readFailure(result.reasonCode); return }
        metadata = result.metadata ?? await service.fetchRepositoryMetadata(url)
      }
      const repositories = await service.saveRepository(url, this.name, metadata, this.editingUrl || undefined)
      const active = await service.loadSavedUrl()
      this.cache.rememberSavedIndex(active)
      this.cache.rememberSavedIndex(active, repositories)
      if (addressChanged) await this.cache.reloadSavedCatalog(this.context(), true)
      this.url = ''
      this.closeDialog()
    } catch (error) { this.error = (error as Error).message === 'image_rule_subscription_exists'
      ? AppStrings.get('source_catalog_subscription_exists') : AppStrings.get('source_catalog_subscription_save_failed') }
    finally { this.busy = false }
  }

  private async remove(repository: SourceIndexRepository): Promise<void> {
    if (this.busy) return
    this.busy = true
    this.error = ''
    try {
      const service = new SourceIndexService(this.context())
      const repositories = await service.removeSavedRepository(repository.url)
      const active = await service.loadSavedUrl()
      this.cache.rememberSavedIndex(active)
      this.cache.rememberSavedIndex(active, repositories)
      await this.cache.reloadSavedCatalog(this.context())
    } catch (_error) { this.error = AppStrings.get('source_pkg_saved_index_remove_failed') }
    finally { this.busy = false }
  }

  @Computed
  private get repositories(): SourceIndexRepository[] {
    void this.cache.revision
    return this.cache.sourceIndexRepositories
  }

  private async refreshMetadata(): Promise<void> {
    if (this.busy) return
    const service = new SourceIndexService(this.context())
    await Promise.all(this.repositories.map((repository: SourceIndexRepository): Promise<void> =>
      service.refreshRepositoryMetadata(repository)))
    const repositories = await service.loadSavedRepositories()
    this.cache.rememberSavedIndex(this.cache.sourceIndexUrl, repositories)
  }

  private async toggleSubscription(url: string, disabled: boolean, imagePlugin: boolean): Promise<void> {
    if (this.busy) return
    this.busy = true
    this.error = ''
    try {
      if (imagePlugin) {
        await ImageRuleStore.forContext(this.context()).setSubscriptionDisabled(url, disabled)
        await this.loadRules()
      } else {
        const service = new SourceIndexService(this.context())
        const repositories = await service.setSubscriptionDisabled(url, disabled)
        this.cache.rememberSavedIndex(this.cache.sourceIndexUrl, repositories)
        await this.cache.reloadSavedCatalog(this.context())
        if (!disabled) void this.cache.check(this.context())
      }
    } catch (_error) {
      this.error = AppStrings.get('source_catalog_subscription_save_failed')
    } finally { this.busy = false }
  }

  private toggleAction(url: string, disabled: boolean, imagePlugin: boolean): KomaMenuAction {
    return { label: AppStrings.get(disabled ? 'source_subscription_enable' : 'source_subscription_disable'),
      action: (): void => { void this.toggleSubscription(url, !disabled, imagePlugin) } }
  }

  private copy(repository: SourceIndexRepository): void {
    void pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, repository.url))
      .then((): void => { this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_subscription_copied') })) })
      .catch((): void => { this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_subscription_copy_failed') })) })
  }

  private openWebsite(repository: SourceIndexRepository): void {
    if (!repository.website) return
    void this.context().startAbility({ action: 'ohos.want.action.viewData', uri: repository.website })
      .catch((): void => { this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('manga_detail_open_browser_failed') })) })
  }

  private actions(repository: SourceIndexRepository): KomaMenuGroup[] {
    const items: KomaMenuAction[] = [
      this.toggleAction(repository.url, repository.disabled === true, false),
      { label: AppStrings.get('source_subscription_edit'), action: (): void => { this.openAddDialog(repository) } },
      { label: AppStrings.get('source_subscription_copy'), action: (): void => { this.copy(repository) } },
    ]
    if (repository.website) items.push({ label: AppStrings.get('source_subscription_website'),
      action: (): void => { this.openWebsite(repository) } })
    return [{ id: 'subscription', items }, { id: 'remove', items: [
      { label: AppStrings.get('source_subscription_remove'), action: (): void => { void this.remove(repository) } },
    ] }]
  }

  @Builder
  private ActionsButton(repository: SourceIndexRepository, index: number) {
    Row() {
    if (repository.disabled) {
      Text(AppStrings.get('source_subscription_disabled'))
        .fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(18).fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .id(`subscription-actions-${index}`)
    .width(44).height(44).backgroundColor(Color.Transparent).enabled(!this.busy)
    .accessibilityText(AppStrings.get('source_subscription_actions'))
    .onClick(() => {
      this.menu.open(this.getUIContext(), `subscription-actions-${index}`, () => this.actions(repository), (): void => {})
    })
    }
  }

  private ruleActions(rule: ImageRuleSubscription): KomaMenuGroup[] {
    const items: KomaMenuAction[] = [
      this.toggleAction(rule.url, rule.disabled === true, true),
      { label: AppStrings.get('source_subscription_edit'), action: (): void => { this.openAddDialog(undefined, rule) } },
      { label: AppStrings.get('source_subscription_copy'), action: (): void => { this.copy({ url: rule.url, lastUsedAt: 0 }) } },
    ]
    if (rule.website) items.push({ label: AppStrings.get('source_subscription_website'),
      action: (): void => { this.openWebsite({ url: rule.url, lastUsedAt: 0, website: rule.website }) } })
    return [{ id: 'subscription', items }, { id: 'remove', items: [{ label: AppStrings.get('source_subscription_remove'),
      action: (): void => {
        void ImageRuleStore.forContext(this.context()).remove(rule.url).catch((): void => {
          this.error = AppStrings.get('source_pkg_saved_index_remove_failed')
        })
      } }] }]
  }

  @Builder
  private RuleActionsButton(rule: ImageRuleSubscription, index: number) {
    Row() {
    if (rule.disabled) {
      Text(AppStrings.get('source_subscription_disabled'))
        .fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(18).fontColor([ThemeConstants.TEXT_SECONDARY])
    }.id(`rule-subscription-actions-${index}`).width(44).height(44).backgroundColor(Color.Transparent)
      .enabled(!this.busy)
      .accessibilityText(AppStrings.get('source_subscription_actions'))
      .onClick(() => { this.menu.open(this.getUIContext(), `rule-subscription-actions-${index}`, () => this.ruleActions(rule), (): void => {}) })
    }
  }

  @Builder
  private AddDialog() {
    KomaTextInputDialog({ title: AppStrings.get(this.editingUrl || this.editingRuleUrl ? 'source_subscription_edit' : 'source_pkg_add_subscription'),
      label: AppStrings.get('source_pkg_index_url_label'),
      placeholder: AppStrings.get('source_pkg_index_url_placeholder'), value: this.url,
      secondaryLabel: AppStrings.get('source_subscription_name'),
      secondaryPlaceholder: AppStrings.get('source_subscription_name_hint'), secondaryValue: this.name,
      secondaryChange: (value: string): void => { this.name = value },
      error: this.error, busy: this.busy, confirmLabel: AppStrings.get(this.editingUrl || this.editingRuleUrl ? 'common_save' : 'source_pkg_add_subscription'),
      confirmEnabled: isValidHttpUrl(this.url.trim()),
      change: (value: string): void => { this.url = value; this.error = '' },
      confirm: (): void => { void this.add() }, cancel: (): void => { this.closeDialog() } })
  }

  build() {
    PullRefreshListScaffold({ reserveTitleBar: !this.embedded, reserveSystemSafeArea: !this.embedded,
      surfaceColor: this.embedded ? Color.Transparent : ThemeConstants.BG_SUB,
      horizontalPadding: this.embedded ? 0 : ThemeConstants.SPACE_MD, onRefresh: async (): Promise<void> => {
      this.error = ''
      const store = ImageRuleStore.forContext(this.context())
      if (this.ruleState.readFailed) { await store.reload(); await this.loadRules() }
      if (this.repositories.length + this.ruleSubscriptions.length > 0 &&
        !this.repositories.some((item: SourceIndexRepository): boolean => !item.disabled) &&
        !this.ruleSubscriptions.some((item: ImageRuleSubscription): boolean => !item.disabled)) {
        this.error = AppStrings.get('source_subscription_none_enabled')
        return
      }
      await Promise.all([
        this.cache.check(this.context()).then((): Promise<void> => this.refreshMetadata())
          .catch((): void => { this.error = AppStrings.get('source_catalog_subscription_read_failed') }),
        store.checkUpdates().catch((): boolean => false),
      ])
    }, bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.repositories.length > 0) {
        ListItem() {
          GroupedListSection({ title: AppStrings.get('subscription_sources') }) {
            ForEach(this.repositories, (repository: SourceIndexRepository, index: number) => {
              ConciseListRow({ title: sourceRepositoryDisplayName(repository), wrapTitle: true, showChevron: false,
                subtitle: [sourceRepositoryDisplayName(repository) === repository.url ? '' : repository.url,
                  repository.disabled || this.cache.sourceIndexFailures[repository.url] === undefined ? '' :
                    this.readFailure(this.cache.sourceIndexFailures[repository.url])].filter((value: string): boolean => value.length > 0).join('\n'),
                subtitleMaxLines: 3, action: (): void => { this.openAddDialog(repository) },
                suffixBuilderParam: () => { this.ActionsButton(repository, index) } })
              if (index + 1 < this.repositories.length) { ListDivider() }
            // These are persisted DTOs, not observed row models. A name arriving
            // after first paint must update both the text and action callbacks.
            }, (repository: SourceIndexRepository, index: number) => JSON.stringify([repository.url,
              repository.customName, repository.name, repository.website, repository.disabled, index,
              this.cache.sourceIndexFailures[repository.url]]))
          }
        }
      }
      if (this.ruleSubscriptions.length > 0) {
        ListItem() {
          GroupedListSection({ title: AppStrings.get('subscription_image_rules') }) {
            ForEach(this.ruleSubscriptions, (rule: ImageRuleSubscription, index: number) => {
              ConciseListRow({ title: imageRuleSubscriptionName(rule), wrapTitle: true,
                subtitle: rule.url + (!rule.disabled && rule.lastError ? '\n' + AppStrings.get('image_rules_update_failed') : ''), subtitleMaxLines: 3,
                // Subscription rows edit their identity. Plugin management is owned
                // by the shared plugin list, not a second subscription destination.
                showChevron: false, action: (): void => { this.openAddDialog(undefined, rule) },
                suffixBuilderParam: () => { this.RuleActionsButton(rule, index) } })
              if (index + 1 < this.ruleSubscriptions.length) { ListDivider() }
            }, (rule: ImageRuleSubscription) => JSON.stringify([rule.url, rule.name, rule.customName, rule.disabled, rule.lastError, rule.website]))
          }
        }
      }
      if (this.repositories.length === 0 && this.ruleSubscriptions.length === 0) {
        ListItem() {
          Text(AppStrings.get('source_catalog_subscriptions_hint'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%').padding(ThemeConstants.SPACE_LG)
        }
      }
      if (this.error.length > 0 && this.dialogId < 0) {
        ListItem() { Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_MD) }
      }
    }
  }
}
