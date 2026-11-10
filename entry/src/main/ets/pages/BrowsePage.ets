import { komaSheetOptions, komaToastOptions } from '../theme/KomaPopupOptions'
import { SourceCatalogFiltersContent } from '../components/SourceCatalogFiltersContent'
import { appSourceCatalogFilters, SourceCatalogFilterState } from '../state/SourceCatalogFilterState'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { groupSourcesByLanguage, SourceCatalogFilters, SourceLanguageGroup, sourceCatalogLanguage, sourceMatchesCatalogFilters, sourceMatchesCatalogSearch } from '../model/SourceCatalogPresentation'
import { sourceLanguageName } from '../sourceRuntime/SourceLanguagePresentation'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { compareSourceNames } from '../sourceRuntime/SourceListOrder'
import { resolveSourceLocalizedName } from '../sourceRuntime/SourceLocalizedNames'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { SourceListItem } from '../components/SourceListItem'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { appSourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { RouterHelper } from '../common/RouterHelper'
import { common } from '@kit.AbilityKit'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectSourceRuntimeState, SourceRuntimeState } from '../state/SourceRuntimeState'
import { reloadInstalledSourcePackages } from '../sourceRuntime/SourceRuntimeAppRegistry'

function s(name: string): string {
  return AppStrings.get(name)
}

type PrivateBrowseSourceKey = 'komga' | 'kavita' | 'webdav' | 'opds'

interface PrivateBrowseSourceEntry {
  key: PrivateBrowseSourceKey
  title: string
  badge: ResourceStr
  detail: ResourceStr
  color: ResourceColor
}

@ComponentV2
export struct BrowsePage {
  @Param chrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  @Local private catalogFilters: SourceCatalogFilterState = appSourceCatalogFilters
  @Local private filtersShown: boolean = false

  @Monitor('chrome.requestId')
  private onCatalogAction(): void {
    if (this.active && this.navigationVisible && this.chrome.action === 'filters') this.filtersShown = true
  }

  @Computed
  private get catalogLanguages(): string[] {
    return Array.from(new Set(this.viewModel.sources.map((source: SourceRuntimeRegistryInstalledSourceSummary): string =>
      sourceCatalogLanguage(source.language)))).sort()
  }

  @Computed
  private get sourcesByLanguage(): Record<string, SourceRuntimeRegistryInstalledSourceSummary[]> {
    const result: Record<string, SourceRuntimeRegistryInstalledSourceSummary[]> = {}
    const pinned = new Set(this.catalogFilters.pinnedSourceIds)
    groupSourcesByLanguage(this.enabledRuntimeSources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
      !pinned.has(source.sourceId)),
      (source: SourceRuntimeRegistryInstalledSourceSummary): string => source.language)
      .forEach((group: SourceLanguageGroup<SourceRuntimeRegistryInstalledSourceSummary>): void => {
        result[group.language] = group.items
      })
    return result
  }

  @Computed
  private get pinnedRuntimeSources(): SourceRuntimeRegistryInstalledSourceSummary[] {
    const byId = new Map<string, SourceRuntimeRegistryInstalledSourceSummary>()
    this.enabledRuntimeSources.forEach((source: SourceRuntimeRegistryInstalledSourceSummary): void => {
      byId.set(source.sourceId, source)
    })
    const sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
    this.catalogFilters.pinnedSourceIds.forEach((id: string): void => {
      const source = byId.get(id)
      if (source !== undefined) sources.push(source)
    })
    return sources
  }

  private toggleSourcePin(id: string): void {
    // animateTo can rebuild the list and remove the clicked HDS row before
    // its native click callback returns. Move the whole update to the next task.
    setTimeout((): void => {
      if (!this.active || !this.navigationVisible || !this.catalogFilters.loaded) return
      const pinned = !this.catalogFilters.pinnedSourceIds.includes(id)
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        void this.catalogFilters.setSourcePinned(id, pinned).catch((): void => {
          if (this.active && this.navigationVisible) {
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s('browse_source_pin_save_failed') }))
          }
        })
      })
    }, 0)
  }

  @Computed
  private get sourceGroupLanguages(): string[] {
    return Object.keys(this.sourcesByLanguage)
  }

  private sourcesInLanguage(language: string): SourceRuntimeRegistryInstalledSourceSummary[] {
    return this.sourcesByLanguage[language] ?? []
  }

  private sourceNeedsDivider(sources: SourceRuntimeRegistryInstalledSourceSummary[], sourceId: string): boolean {
    return sources[sources.length - 1]?.sourceId !== sourceId
  }

  @Builder
  private CatalogFilters() {
    SourceCatalogFiltersContent({ filters: this.catalogFilters, languages: this.catalogLanguages,
      onClose: (): void => { this.filtersShown = false } })
  }

  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sourceRuntimeState: SourceRuntimeState = connectSourceRuntimeState()
  @Local private viewModel: BrowseViewModel = new BrowseViewModel()
  @Local private komgaConfigured: boolean = false
  @Local private kavitaConfigured: boolean = false
  @Local private opdsConfigured: boolean = false
  @Local private webDavConfigured: boolean = false
  @Param browseScroller: Scroller = new Scroller()
  @Param active: boolean = false
  @Param navigationVisible: boolean = true
  private displayedSourceRevision: number = -1
  private availabilityEpoch: number = 0
  @Param sourceRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onOpenReader: (comicId: string, chapterId?: string) => void = () => {}
  @Event onOpenSourcePackageManager: () => void = () => {}
  @Event onOpenKomgaBrowse: () => void = () => {}
  @Event onOpenKavitaBrowse: () => void = () => {}
  @Event onOpenOpdsBrowse: () => void = () => {}
  @Event onOpenWebDavBrowse: () => void = () => {}

  private openSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    RouterHelper.pushSourceBrowse({ source: source })
  }

  private openSourceSearch(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    RouterHelper.pushSourceSearch({ source: source })
  }

  private openKomga(): void {
    this.onOpenKomgaBrowse()
  }

  private openKavita(): void {
    this.onOpenKavitaBrowse()
  }

  private openWebDav(): void {
    this.onOpenWebDavBrowse()
  }

  private openOpds(): void {
    this.onOpenOpdsBrowse()
  }

  @Computed
  private get configuredPrivateSourceEntries(): PrivateBrowseSourceEntry[] {
    const entries: PrivateBrowseSourceEntry[] = []
    if (this.komgaConfigured) {
      entries.push({
        key: 'komga',
        title: s('route_komga_title'),
        badge: s('browse_komga_tag'),
        detail: s('browse_komga_detail'),
        color: ThemeConstants.SOURCE_KOMGA_COLOR,
      })
    }
    if (this.kavitaConfigured) {
      entries.push({
        key: 'kavita',
        title: s('route_kavita_title'),
        badge: s('browse_kavita_tag'),
        detail: s('browse_kavita_detail'),
        color: ThemeConstants.SOURCE_KAVITA_COLOR,
      })
    }
    if (this.webDavConfigured) {
      entries.push({
        key: 'webdav',
        title: s('route_webdav_title'),
        badge: s('browse_webdav_tag'),
        detail: s('browse_webdav_detail'),
        color: ThemeConstants.SOURCE_WEBDAV_COLOR,
      })
    }
    if (this.opdsConfigured) {
      entries.push({
        key: 'opds',
        title: s('route_opds_title'),
        badge: s('browse_opds_tag'),
        detail: s('browse_opds_detail'),
        color: ThemeConstants.SOURCE_OPDS_COLOR,
      })
    }
    return entries.filter((entry: PrivateBrowseSourceEntry): boolean =>
      sourceMatchesCatalogSearch(this.chrome.search.query, entry.title, entry.title, undefined, entry.key))
  }

  private openPrivateSource(key: PrivateBrowseSourceKey): void {
    if (key === 'komga') {
      this.openKomga()
      return
    }
    if (key === 'kavita') {
      this.openKavita()
      return
    }
    if (key === 'webdav') {
      this.openWebDav()
      return
    }
    this.openOpds()
  }

  // Rows, their dividers and the heading share one derived order. Sorting in
  // each row's builder repeats the whole list's work during every refresh.
  @Computed
  private get enabledRuntimeSources(): SourceRuntimeRegistryInstalledSourceSummary[] {
    const locale = this.languageState.effectiveLocale
    const filters: SourceCatalogFilters = { languages: this.catalogFilters.languages, rating: this.catalogFilters.rating }
    const sources = this.viewModel.sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.enabled &&
      sourceMatchesCatalogFilters(source.language, source.nsfw, source.contentRating, filters))
    // A package update also invalidates this retained Browse projection. Resolve
    // names once per source, as in the manager's single-row refresh, rather than
    // revalidating localized metadata in every sort comparison. Keep this map
    // local so a locale or source change always computes the original order.
    const displayNames = new Map<string, string>()
    sources.forEach((source: SourceRuntimeRegistryInstalledSourceSummary): void => {
      displayNames.set(source.sourceId, resolveSourceLocalizedName(source.displayName, source.localizedNames, locale))
    })
    return sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
      sourceMatchesCatalogSearch(this.chrome.search.query, displayNames.get(source.sourceId) ?? source.displayName,
        source.displayName, source.localizedNames, source.sourceId))
      .sort((left: SourceRuntimeRegistryInstalledSourceSummary, right: SourceRuntimeRegistryInstalledSourceSummary): number =>
      compareSourceNames(displayNames.get(left.sourceId) ?? left.displayName, left.sourceId,
        displayNames.get(right.sourceId) ?? right.displayName, right.sourceId))
  }

  @Builder
  private EmptySources() {
    KomaEmptyState({
      icon: $r('sys.symbol.compass'),
      title: s(this.chrome.search.query.trim().length > 0 ? 'source_catalog_search_no_matches' :
        this.catalogFilters.active ? 'source_catalog_no_matches' : 'browse_empty_title'),
      message: s(this.chrome.search.query.trim().length > 0 ? 'source_catalog_search_hint' :
        this.catalogFilters.active ? 'source_catalog_no_matches_hint' : 'browse_empty_message'),
      showAction: false,
    })
  }

  @Builder
  private PrivateSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_private_sources_heading') }) {
        ForEach(this.configuredPrivateSourceEntries, (entry: PrivateBrowseSourceEntry, index: number) => {
          SourceListItem({
            title: entry.title,
            subtitle: entry.detail,
            badge: entry.badge,
            accentColor: entry.color,
            showSearchButton: false,
            onActivate: () => {
              this.openPrivateSource(entry.key)
            },
          })
          if (index + 1 < this.configuredPrivateSourceEntries.length) {
            ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
          }
        }, (entry: PrivateBrowseSourceEntry) => JSON.stringify([entry.key, entry.title, entry.detail, entry.badge]))
      }
    }
  }

  @Builder
  private RuntimeSourceRow(source: SourceRuntimeRegistryInstalledSourceSummary, pinned: boolean) {
    SourceListItem({ source, subtitle: `v${source.version}`, languageBadge: '',
      accentColor: ThemeConstants.SOURCE_WASM_COLOR, showSearchButton: false, showPinButton: this.catalogFilters.loaded, pinned,
      onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary): void => { this.openSource(selected) },
      onPinToggle: (id: string): void => { this.toggleSourcePin(id) } })
      .transition(TransitionEffect.IDENTITY)
  }

  @Builder
  private PinnedSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_pinned_sources_heading') }) {
        // Do not bind the row key to its position just to draw a divider.
        ForEach(this.pinnedRuntimeSources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
          this.RuntimeSourceRow(source, true)
          if (this.sourceNeedsDivider(this.pinnedRuntimeSources, source.sourceId)) {
            ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
          }
        }, (source: SourceRuntimeRegistryInstalledSourceSummary) => JSON.stringify([source.sourceId, source.version,
          sourceDisplayName(source.sourceId, source.displayName)]))
      }
    }.transition(TransitionEffect.IDENTITY)
  }

  @Builder
  private RuntimeSourceListItems() {
    ForEach(this.sourceGroupLanguages, (language: string) => {
      ListItem() {
        // Keep group identity by language, but read its members from the live
        // projection. A retained ForEach closure must not keep an old group DTO.
        GroupedListSection({ title: sourceLanguageName(language) || s('source_catalog_language_unknown'),
          subtitle: s('browse_installed_sources_count').replace('%s', `${this.sourcesInLanguage(language).length}`) }) {
          ForEach(this.sourcesInLanguage(language), (source: SourceRuntimeRegistryInstalledSourceSummary) => {
            this.RuntimeSourceRow(source, false)
            if (this.sourceNeedsDivider(this.sourcesInLanguage(language), source.sourceId)) {
              ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
            }
          }, (source: SourceRuntimeRegistryInstalledSourceSummary) => JSON.stringify([source.sourceId, source.version,
            sourceDisplayName(source.sourceId, source.displayName)]))
        }
      }.transition(TransitionEffect.IDENTITY)
    }, (language: string) => language)
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
    this.displayedSourceRevision = this.sourceRuntimeState.revision
    this.loadRemoteAvailability()
  }

  aboutToDisappear(): void {
    this.availabilityEpoch += 1
  }

  @Monitor('active')
  private onActiveChanged(): void {
    if (this.active) {
      void this.loadRemoteAvailability()
    }
  }

  @Monitor('sourceRuntimeState.revision', 'active', 'navigationVisible')
  private refreshInstalledSourceSummaries(): void {
    // Registry publishers have already committed the live mutation. Reloading
    // every WASM here repeats disk work inside the reactive UI update.
    // A retained Browse page is also hidden under the manager. Keep its current
    // rows there; consume the newest revision once it is visible again instead
    // of rebuilding all summaries inside each package's completion callback.
    // Active-tab remote availability remains a separate owner below.
    if (!this.active || !this.navigationVisible ||
      this.displayedSourceRevision === this.sourceRuntimeState.revision) return
    this.viewModel.loadInstalledSources()
    this.displayedSourceRevision = this.sourceRuntimeState.revision
  }

  private async loadRemoteAvailability(reportFailure: boolean = false): Promise<void> {
    const epoch = ++this.availabilityEpoch
    try {
      const store = new RemoteServerStore(getContext(this) as common.UIAbilityContext)
      const komgaConfigured = await store.loadKomga() !== undefined
      const kavitaConfigured = await store.loadKavita() !== undefined
      const opdsConfigured = await store.loadOpds() !== undefined
      const webDavConfigured = await store.loadWebDav() !== undefined
      if (epoch !== this.availabilityEpoch) return
      this.komgaConfigured = komgaConfigured
      this.kavitaConfigured = kavitaConfigured
      this.opdsConfigured = opdsConfigured
      this.webDavConfigured = webDavConfigured
      console.info(`[Komga] step=browse_availability configured=${this.komgaConfigured}`)
      console.info(`[Kavita] step=browse_availability configured=${this.kavitaConfigured}`)
      console.info(`[OPDS] step=browse_availability configured=${this.opdsConfigured}`)
      console.info(`[WebDAV] step=browse_availability configured=${this.webDavConfigured}`)
    } catch (error) {
      void error
      if (epoch !== this.availabilityEpoch) return
      if (reportFailure) {
        throw new Error('availability_load_failed')
      }
      this.komgaConfigured = false
      this.kavitaConfigured = false
      this.opdsConfigured = false
      this.webDavConfigured = false
      DiagnosticLogger.error('browse_page', 'browse_availability_failed', '[Komga] step=browse_availability_failed code=availability_load_failed')
      DiagnosticLogger.error('browse_page', 'browse_availability_failed', '[Kavita] step=browse_availability_failed code=availability_load_failed')
      DiagnosticLogger.error('browse_page', 'browse_availability_failed', '[OPDS] step=browse_availability_failed code=availability_load_failed')
      DiagnosticLogger.error('browse_page', 'browse_availability_failed', '[WebDAV] step=browse_availability_failed code=availability_load_failed')
    }
  }

  private async refreshSources(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext
    const sourceRevision = this.sourceRuntimeState.revision
    if (this.displayedSourceRevision !== sourceRevision) {
      const sourceMetadataReloaded = reloadInstalledSourcePackages(context)
      this.viewModel = new BrowseViewModel(this.sourceRegistry)
      this.viewModel.loadInstalledSources()
      this.displayedSourceRevision = sourceRevision
      if (!sourceMetadataReloaded) {
        throw new Error('source_metadata_reload_failed')
      }
    }
    await this.loadRemoteAvailability(true)
    await appSourcePackageManagerCache.prepare(context, connectLanguageState().effectiveLocale)
    await appSourcePackageManagerCache.check(context)
  }

  build() {
    Stack() {
    PullRefreshListScaffold({
      scroller: this.browseScroller,
      pinnedOverlayHeight: this.chrome.searchHeight,
      listSpace: ThemeConstants.SPACE_SM,
      bottomPadding: ThemeConstants.SPACE_XL,
      floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
      onRefresh: async () => {
        await this.refreshSources()
      },
    }) {
      if (this.viewModel.loadingSources) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width(ThemeConstants.LOADING_SIZE_LARGE)
              .height(ThemeConstants.LOADING_SIZE_LARGE)
              .color(ThemeConstants.BRAND_PRIMARY)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      } else if (this.enabledRuntimeSources.length === 0 && this.configuredPrivateSourceEntries.length === 0) {
        ListItem() {
          this.EmptySources()
        }
      } else {
        if (this.pinnedRuntimeSources.length > 0) {
          this.PinnedSourceListItems()
        }
        if (this.configuredPrivateSourceEntries.length > 0) {
          this.PrivateSourceListItems()
        }
        if (this.enabledRuntimeSources.length > 0) {
          this.RuntimeSourceListItems()
        }
      }
    }
    }
    .width('100%').height('100%')
    .bindSheet($$this.filtersShown, this.CatalogFilters, komaSheetOptions({
      detents: [SheetSize.MEDIUM, SheetSize.LARGE], showClose: false, enableFloatingDragBar: true,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      onDisappear: (): void => { this.filtersShown = false },
    }))
  }
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
