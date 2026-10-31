import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { SourceIndexRepository, SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { isValidHttpUrl, resolveIndexDocumentUrl } from '../sourceRuntime/SourceIndexMetadata'
import { appSourcePackageManagerCache, SourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaFormTextField } from './ui/KomaFormTextField'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct SourceSubscriptionsContent {
  @Event onClose: () => void = () => {}
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

  build() {
    KomaModalScaffold({ title: AppStrings.get('source_pkg_index_url_heading'), onClose: this.onClose,
      confirmLabel: AppStrings.get('source_pkg_add_subscription'), confirmEnabled: !this.busy && isValidHttpUrl(this.url.trim()),
      onConfirm: (): void => { void this.add() }, contentHorizontalPadding: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        KomaFormTextField({ label: AppStrings.get('source_pkg_index_url_label'),
          placeholder: AppStrings.get('source_pkg_index_url_placeholder'), value: this.url,
          isEnabled: !this.busy, change: (value: string): void => { this.url = value; this.error = '' },
          submit: (): void => { void this.add() } })
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.error || AppStrings.get('source_catalog_subscriptions_hint'))
            .layoutWeight(1).fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
          LoadingProgress().width(24).height(24).color(ThemeConstants.BRAND_PRIMARY)
            .visibility(this.busy ? Visibility.Visible : Visibility.Hidden)
        }
        .width('100%').constraintSize({ minHeight: 24 })
        if (this.repositories.length > 0) {
          GroupedListSection({ title: AppStrings.get('source_pkg_saved_indexes_heading') }) {
            ForEach(this.repositories, (repository: SourceIndexRepository, index: number) => {
              ConciseListRow({ title: repository.url, wrapTitle: true, showChevron: false,
                subtitle: this.cache.sourceIndexFailures[repository.url] === undefined ? '' :
                  this.readFailure(this.cache.sourceIndexFailures[repository.url]),
                suffixBuilderParam: () => { this.RemoveButton(repository) } })
              if (index + 1 < this.repositories.length) { ListDivider() }
            }, (repository: SourceIndexRepository) => repository.url)
          }
        }
      }
      .width('100%')
    }
  }
}
