import { common } from '@kit.AbilityKit'
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
  @Param chrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  private dialogId: number = -1
  private menu: KomaMenuController = new KomaMenuController()
  @Local private editingUrl: string = ''
  @Local private name: string = ''

  aboutToAppear(): void {
    void this.cache.prepare(this.context(), connectLanguageState().effectiveLocale)
      .then((): Promise<void> => this.refreshMetadata())
      .catch((): void => { this.error = AppStrings.get('source_catalog_subscription_read_failed') })
  }

  aboutToDisappear(): void { this.closeDialog(); this.menu.close() }

  @Monitor('chrome.requestId')
  private onCommand(): void {
    if (this.chrome.action === 'addSubscription') this.openAddDialog()
  }

  private openAddDialog(repository?: SourceIndexRepository): void {
    if (this.busy || this.dialogId >= 0) return
    this.editingUrl = repository?.url ?? ''
    this.url = repository?.url ?? ''
    this.name = repository?.customName ?? ''
    this.error = ''
    void this.getUIContext().getPromptAction().openCustomDialog({
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
      const addressChanged = this.editingUrl.length === 0 ||
        resolveIndexDocumentUrl(this.editingUrl) !== resolveIndexDocumentUrl(url)
      let metadata: SourceRepositoryMetadata | undefined
      if (addressChanged) {
        const result = await service.fetchIndex(url)
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
    } catch (_error) { this.error = AppStrings.get('source_catalog_subscription_save_failed') }
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

  private copy(repository: SourceIndexRepository): void {
    void pasteboard.getSystemPasteboard().setData(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, repository.url))
      .then((): void => { this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_subscription_copied') }) })
      .catch((): void => { this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_subscription_copy_failed') }) })
  }

  private openWebsite(repository: SourceIndexRepository): void {
    if (!repository.website) return
    void this.context().startAbility({ action: 'ohos.want.action.viewData', uri: repository.website })
      .catch((): void => { this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('manga_detail_open_browser_failed') }) })
  }

  private actions(repository: SourceIndexRepository): KomaMenuGroup[] {
    const items: KomaMenuAction[] = [
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

  @Builder
  private AddDialog() {
    KomaTextInputDialog({ title: AppStrings.get(this.editingUrl ? 'source_subscription_edit' : 'source_pkg_add_subscription'),
      label: AppStrings.get('source_pkg_index_url_label'),
      placeholder: AppStrings.get('source_pkg_index_url_placeholder'), value: this.url,
      secondaryLabel: AppStrings.get('source_subscription_name'),
      secondaryPlaceholder: AppStrings.get('source_subscription_name_hint'), secondaryValue: this.name,
      secondaryChange: (value: string): void => { this.name = value },
      error: this.error, busy: this.busy, confirmLabel: AppStrings.get(this.editingUrl ? 'common_save' : 'source_pkg_add_subscription'),
      confirmEnabled: isValidHttpUrl(this.url.trim()),
      change: (value: string): void => { this.url = value; this.error = '' },
      confirm: (): void => { void this.add() }, cancel: (): void => { this.closeDialog() } })
  }

  build() {
    PullRefreshListScaffold({ onRefresh: (): Promise<void> => this.refreshMetadata(), bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.repositories.length > 0) {
        ListItem() {
          GroupedListSection() {
            ForEach(this.repositories, (repository: SourceIndexRepository, index: number) => {
              ConciseListRow({ title: sourceRepositoryDisplayName(repository), wrapTitle: true, showChevron: false,
                subtitle: [sourceRepositoryDisplayName(repository) === repository.url ? '' : repository.url,
                  this.cache.sourceIndexFailures[repository.url] === undefined ? '' :
                    this.readFailure(this.cache.sourceIndexFailures[repository.url])].filter((value: string): boolean => value.length > 0).join('\n'),
                subtitleMaxLines: 3, action: (): void => { this.openAddDialog(repository) },
                suffixBuilderParam: () => { this.ActionsButton(repository, index) } })
              if (index + 1 < this.repositories.length) { ListDivider() }
            // These are persisted DTOs, not observed row models. A name arriving
            // after first paint must update both the text and action callbacks.
            }, (repository: SourceIndexRepository, index: number) => JSON.stringify([repository.url,
              repository.customName, repository.name, repository.website, index,
              this.cache.sourceIndexFailures[repository.url]]))
          }
        }
      } else {
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
