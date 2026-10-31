import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { SourceIndexRepository, SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { isValidHttpUrl, resolveIndexDocumentUrl } from '../sourceRuntime/SourceIndexMetadata'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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

  aboutToAppear(): void {
    void this.cache.prepare(this.context(), connectLanguageState().effectiveLocale)
      .catch((): void => { this.error = AppStrings.get('source_catalog_subscription_read_failed') })
  }

  aboutToDisappear(): void { this.closeDialog() }

  @Monitor('chrome.requestId')
  private onCommand(): void {
    if (this.chrome.action === 'addSubscription') this.openAddDialog()
  }

  private openAddDialog(): void {
    if (this.busy || this.dialogId >= 0) return
    this.url = ''
    this.error = ''
    void this.getUIContext().getPromptAction().openCustomDialog({
      builder: () => { this.AddDialog() }, alignment: DialogAlignment.Center, autoCancel: true,
      onWillDismiss: (action: DismissDialogAction): void => { if (!this.busy) action.dismiss() },
      onDidDisappear: (): void => { this.dialogId = -1 },
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
        resolveIndexDocumentUrl(repository.url) === resolveIndexDocumentUrl(url))) {
        this.error = AppStrings.get('source_catalog_subscription_exists'); return
      }
      const result = await service.fetchIndex(url)
      if (!result.ok) { this.error = this.readFailure(result.reasonCode); return }
      await service.saveUrl(url)
      this.cache.rememberSavedIndex(url)
      this.cache.rememberSavedIndex(url, await service.loadSavedRepositories())
      await this.cache.reloadSavedCatalog(this.context(), true)
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

  @Builder
  private RemoveButton(repository: SourceIndexRepository) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.trash')).fontSize(18).fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width(44).height(44).backgroundColor(Color.Transparent).enabled(!this.busy)
    .accessibilityText(AppStrings.get('source_pkg_saved_index_remove'))
    .onClick(() => { void this.remove(repository) })
  }

  @Builder
  private AddDialog() {
    KomaTextInputDialog({ title: AppStrings.get('source_pkg_add_subscription'),
      label: AppStrings.get('source_pkg_index_url_label'),
      placeholder: AppStrings.get('source_pkg_index_url_placeholder'), value: this.url,
      error: this.error, busy: this.busy, confirmLabel: AppStrings.get('source_pkg_add_subscription'),
      confirmEnabled: isValidHttpUrl(this.url.trim()),
      change: (value: string): void => { this.url = value; this.error = '' },
      confirm: (): void => { void this.add() }, cancel: (): void => { this.closeDialog() } })
  }

  build() {
    SecondaryListScaffold({ bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.repositories.length > 0) {
        ListItem() {
          GroupedListSection() {
            ForEach(this.repositories, (repository: SourceIndexRepository, index: number) => {
              ConciseListRow({ title: repository.url, wrapTitle: true, showChevron: false,
                subtitle: this.cache.sourceIndexFailures[repository.url] === undefined ? '' :
                  this.readFailure(this.cache.sourceIndexFailures[repository.url]),
                suffixBuilderParam: () => { this.RemoveButton(repository) } })
              if (index + 1 < this.repositories.length) { ListDivider() }
            }, (repository: SourceIndexRepository) => repository.url)
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
