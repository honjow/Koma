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
import { GroupedListRowSurface, GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { ListDisclosureContent, ListDisclosureMotion } from '../components/ui/ListDisclosureContent'
import { WidePairDivider, WidePairRow, usesWideTwoColumnLayout } from '../components/ui/WideTwoColumn'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
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
import { RootNavigationState } from '../state/RootNavigationState'
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

interface BrowseLanguageRow {
  key: string
  language: string
  count: number
  sources: SourceRuntimeRegistryInstalledSourceSummary[]
  index: number
  first: boolean
  last: boolean
  leadingSpace: number
  disclosureRows?: BrowseLanguageRow[]
}

@ComponentV2
export struct BrowsePage {
  @Param chrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  @Local private catalogFilters: SourceCatalogFilterState = appSourceCatalogFilters
  @Local private languageMotion: ListDisclosureMotion = new ListDisclosureMotion()
  @Local private filtersShown: boolean = false
  @Local private browseSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()

  @Computed
  private get usesWideSourceRows(): boolean {
    // The page fills the main window. Share the settings home's width gate so
    // a wide window merges source rows and a narrow window keeps one per row.
    return usesWideTwoColumnLayout(this.browseSafeArea.windowWidthVp)
  }

  private runtimeSourceSignature(source: SourceRuntimeRegistryInstalledSourceSummary): string[] {
    return [source.sourceId, source.version, sourceDisplayName(source.sourceId, source.displayName)]
  }

  private privateSourceSignature(entry: PrivateBrowseSourceEntry): string[] {
    return [entry.key, entry.title, String(entry.detail), String(entry.badge)]
  }

  @Monitor('chrome.requestId')
  private onCatalogAction(): void {
    if (this.active && this.rootNavigation.visible && this.chrome.action === 'filters') this.filtersShown = true
  }

  @Computed
  private get catalogLanguages(): string[] {
    return Array.from(new Set(this.installedSources.map((source: SourceRuntimeRegistryInstalledSourceSummary): string =>
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
  private get enabledRuntimeSourcesById(): Map<string, SourceRuntimeRegistryInstalledSourceSummary> {
    const byId = new Map<string, SourceRuntimeRegistryInstalledSourceSummary>()
    this.enabledRuntimeSources.forEach((source: SourceRuntimeRegistryInstalledSourceSummary): void => {
      byId.set(source.sourceId, source)
    })
    return byId
  }

  private runtimeSourcesInOrder(ids: string[]): SourceRuntimeRegistryInstalledSourceSummary[] {
    const sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
    const byId = this.enabledRuntimeSourcesById
    ids.forEach((id: string): void => {
      const source = byId.get(id)
      if (source !== undefined) sources.push(source)
    })
    return sources
  }

  @Computed
  private get pinnedRuntimeSources(): SourceRuntimeRegistryInstalledSourceSummary[] {
    return this.runtimeSourcesInOrder(this.catalogFilters.pinnedSourceIds)
  }

  @Computed
  private get recentRuntimeSources(): SourceRuntimeRegistryInstalledSourceSummary[] {
    // This shortcut group shares the live catalog filters. Pins and language
    // groups continue to own their existing rows regardless of the last visit.
    return this.runtimeSourcesInOrder(this.catalogFilters.recentSourceIds)
  }

  private toggleSourcePin(id: string): void {
    // animateTo can rebuild the list and remove the clicked HDS row before
    // its native click callback returns. Move the whole update to the next task.
    setTimeout((): void => {
      if (!this.active || !this.rootNavigation.visible || !this.catalogFilters.loaded) return
      const pinned = !this.catalogFilters.pinnedSourceIds.includes(id)
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, (): void => {
        void this.catalogFilters.setSourcePinned(id, pinned).catch((): void => {
          if (this.active && this.rootNavigation.visible) {
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s('browse_source_pin_save_failed') }))
          }
        })
      })
    }, 0)
  }

  @Computed
  private get languageRows(): BrowseLanguageRow[] {
    const rows: BrowseLanguageRow[] = []
    const step = this.usesWideSourceRows ? 2 : 1
    const hasLeadingSection = this.recentRuntimeSources.length > 0 || this.pinnedRuntimeSources.length > 0 ||
      this.configuredPrivateSourceEntries.length > 0
    Object.keys(this.sourcesByLanguage).forEach((language: string): void => {
      const sources = this.sourcesByLanguage[language]
      const visibleCount = this.languageMotion.rowLimit(language,
        this.catalogFilters.languageGroupExpanded(language, this.chrome.search.query) !== false,
        Math.ceil(sources.length / step))
      const disclosureRows: BrowseLanguageRow[] | undefined = this.languageMotion.section === language ? [] : undefined
      rows.push({ key: 'language:' + language, language, count: sources.length, sources: [],
        index: 0, first: false, last: false,
        leadingSpace: hasLeadingSection || rows.length > 0 ? ThemeConstants.SPACE_SM : 0,
        disclosureRows })
      const cardRows = disclosureRows ?? rows
      for (let index = 0; index < visibleCount; index++) {
        const start = index * step
        const pair = sources.slice(start, start + step)
        cardRows.push({ key: language + ':' + this.pairRowKey(pair,
          (source: SourceRuntimeRegistryInstalledSourceSummary): string[] => this.runtimeSourceSignature(source)),
          language, count: sources.length, sources: pair, index,
          first: index === 0, last: start + step >= sources.length,
          leadingSpace: index === 0 ? ThemeConstants.SPACE_XS : 0 })
      }
    })
    return rows
  }

  private toggleLanguageGroup(language: string, count: number, headerBottom?: number): void {
    const expanded = this.catalogFilters.languageGroupExpanded(language, this.chrome.search.query)
    if (expanded === undefined) return
    this.languageMotion.run(this.getUIContext(), language, expanded,
      Math.ceil(count / (this.usesWideSourceRows ? 2 : 1)), headerBottom)
    void this.catalogFilters.toggleLanguageGroup(language).catch((): void => {
      DiagnosticLogger.warn('browse', 'save_language_disclosure', 'Could not save language group state')
    })
  }

  @Builder
  private CatalogFilters() {
    SourceCatalogFiltersContent({ filters: this.catalogFilters, languages: this.catalogLanguages,
      onClose: (): void => { this.filtersShown = false } })
  }

  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sourceRuntimeState: SourceRuntimeState = connectSourceRuntimeState()
  @Local private viewModel: BrowseViewModel = new BrowseViewModel()
  // Rows read this array instead of the view model's own @Trace field. @Local
  // tracks the view model reference, not mutations inside it, so an uninstall
  // that only rewrites viewModel.sources would leave the group count new but
  // the rows stale. Publishing the array here keeps both in one update.
  @Local private installedSources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  @Local private sourcesLoading: boolean = false
  @Local private komgaConfigured: boolean = false
  @Local private kavitaConfigured: boolean = false
  @Local private opdsConfigured: boolean = false
  @Local private webDavConfigured: boolean = false
  @Param browseScroller: Scroller = new Scroller()
  @Event onRootScroll: (offset: number, state: ScrollState) => void = (_offset: number, _state: ScrollState) => {}
  @Param active: boolean = false
  @Param rootNavigation: RootNavigationState = new RootNavigationState()
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
    const sources = this.installedSources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.enabled &&
      sourceMatchesCatalogFilters(source.language, source.nsfw, source.contentRating, filters))
    // A package update also invalidates this retained Browse projection. Resolve
    // names once per source, as in the manager's single-row refresh, rather than
    // revalidating localized metadata in every sort comparison. Keep this map
    // local so a locale or source change always computes the original order.
    const displayNames = new Map<string, string>()
    sources.forEach((source: SourceRuntimeRegistryInstalledSourceSummary): void => {
      displayNames.set(source.sourceId, resolveSourceLocalizedName(source.displayName, source.localizedNames, locale, source.presentation))
    })
    return sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
      sourceMatchesCatalogSearch(this.chrome.search.query, displayNames.get(source.sourceId) ?? source.displayName,
        source.displayName, source.localizedNames, source.sourceId, source.presentation))
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
  private PrivateSourceRow(entry: PrivateBrowseSourceEntry) {
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
  }

  @Builder
  private PrivateSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_private_sources_heading') }) {
        this.PrivateSourceRows()
      }
    }
    .padding({ top: this.recentRuntimeSources.length > 0 || this.pinnedRuntimeSources.length > 0 ?
      ThemeConstants.SPACE_SM : 0 })
  }

  @Builder
  private RuntimeSourceRow(source: SourceRuntimeRegistryInstalledSourceSummary, disclosureLanguage?: string) {
    SourceListItem({ source, subtitle: `v${source.version}`, languageBadge: '',
      accentColor: ThemeConstants.SOURCE_WASM_COLOR, showSearchButton: false, showPinButton: this.catalogFilters.loaded,
      pinned: this.catalogFilters.pinnedSourceIds.includes(source.sourceId),
      // Warm icons can still miss ArkUI's decoded cache when virtual rows are
      // recreated. Keep decoding off the UI thread during ordinary scrolling.
      allowSynchronousIconReload: disclosureLanguage !== undefined &&
        this.languageMotion.iconHandoffSection === disclosureLanguage,
      onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary): void => { this.openSource(selected) },
      onPinToggle: (id: string): void => { this.toggleSourcePin(id) } })
  }

  // Replace rows whose positions change without keeping their old paint alive.
  // The group still animates its height when a source moves across sections.
  private singleSourceRowKey(source: SourceRuntimeRegistryInstalledSourceSummary, index: number, count: number): string {
    return JSON.stringify([index, index + 1 < count, ...this.runtimeSourceSignature(source)])
  }

  @Builder
  private SingleRuntimeSourceRow(source: SourceRuntimeRegistryInstalledSourceSummary, showDivider: boolean,
    disclosureLanguage?: string) {
    Column() {
      this.RuntimeSourceRow(source, disclosureLanguage)
      if (showDivider) {
        ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
      }
    }
    .width('100%')
    .transition(TransitionEffect.IDENTITY)
  }

  // Row source for each merged group. The builders below take no data
  // argument on purpose: @Builder parameters pass by value, so a computed array
  // handed in as an argument keeps rendering its first-frame rows and pins,
  // removals and filter updates never reach the list.
  @Computed
  private get pinnedRowGroups(): SourceRuntimeRegistryInstalledSourceSummary[][] {
    return this.pairRows(this.pinnedRuntimeSources)
  }

  @Computed
  private get recentRowGroups(): SourceRuntimeRegistryInstalledSourceSummary[][] {
    return this.pairRows(this.recentRuntimeSources)
  }

  @Computed
  private get privateRowGroups(): PrivateBrowseSourceEntry[][] {
    return this.pairRows(this.configuredPrivateSourceEntries)
  }

  private pairRows<T>(items: T[]): T[][] {
    const rows: T[][] = []
    for (let index = 0; index < items.length; index += 2) {
      rows.push(items.slice(index, index + 2))
    }
    return rows
  }

  @Builder
  private PinnedSourceRows() {
    if (this.usesWideSourceRows) {
      ForEach(this.pinnedRowGroups, (row: SourceRuntimeRegistryInstalledSourceSummary[], index: number) => {
        WidePairRow({
          first: () => { this.RuntimeSourceRow(row[0]) },
          second: () => {
            if (row.length > 1) this.RuntimeSourceRow(row[1])
          },
        })
        if (index + 1 < this.pinnedRowGroups.length) {
          WidePairDivider({ leftMargin: ThemeConstants.SPACE_XL })
        }
      }, (row: SourceRuntimeRegistryInstalledSourceSummary[]) => this.pairRowKey(
        row, (source: SourceRuntimeRegistryInstalledSourceSummary): string[] => this.runtimeSourceSignature(source)))
    } else {
      ForEach(this.pinnedRuntimeSources, (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) => {
        this.SingleRuntimeSourceRow(source, index + 1 < this.pinnedRuntimeSources.length)
      }, (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) =>
        this.singleSourceRowKey(source, index, this.pinnedRuntimeSources.length))
    }
  }

  @Builder
  private RecentSourceRows() {
    if (this.usesWideSourceRows) {
      ForEach(this.recentRowGroups, (row: SourceRuntimeRegistryInstalledSourceSummary[], index: number) => {
        WidePairRow({
          first: () => { this.RuntimeSourceRow(row[0]) },
          second: () => {
            if (row.length > 1) this.RuntimeSourceRow(row[1])
          },
        })
        if (index + 1 < this.recentRowGroups.length) {
          WidePairDivider({ leftMargin: ThemeConstants.SPACE_XL })
        }
      }, (row: SourceRuntimeRegistryInstalledSourceSummary[]) => this.pairRowKey(
        row, (source: SourceRuntimeRegistryInstalledSourceSummary): string[] => this.runtimeSourceSignature(source)))
    } else {
      ForEach(this.recentRuntimeSources, (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) => {
        this.SingleRuntimeSourceRow(source, index + 1 < this.recentRuntimeSources.length)
      }, (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) =>
        this.singleSourceRowKey(source, index, this.recentRuntimeSources.length))
    }
  }

  @Builder
  private PrivateSourceRows() {
    if (this.usesWideSourceRows) {
      ForEach(this.privateRowGroups, (row: PrivateBrowseSourceEntry[], index: number) => {
        WidePairRow({
          first: () => { this.PrivateSourceRow(row[0]) },
          second: () => {
            if (row.length > 1) this.PrivateSourceRow(row[1])
          },
        })
        if (index + 1 < this.privateRowGroups.length) {
          WidePairDivider({ leftMargin: ThemeConstants.SPACE_XL })
        }
      }, (row: PrivateBrowseSourceEntry[]) => this.pairRowKey(
        row, (entry: PrivateBrowseSourceEntry): string[] => this.privateSourceSignature(entry)))
    } else {
      ForEach(this.configuredPrivateSourceEntries, (entry: PrivateBrowseSourceEntry, index: number) => {
        this.PrivateSourceRow(entry)
        if (index + 1 < this.configuredPrivateSourceEntries.length) {
          ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
        }
      }, (entry: PrivateBrowseSourceEntry) => JSON.stringify(this.privateSourceSignature(entry)))
    }
  }

  // One key per merged row covering both members, so a change in either cell
  // rebuilds that row the way the single-column keys already do.
  private pairRowKey<T>(row: T[], signature: (item: T) => string[]): string {
    return JSON.stringify(row.map((item: T): string[] => signature(item)))
  }

  @Builder
  private RecentSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_recent_sources_heading') }) {
        this.RecentSourceRows()
      }
    }.transition(TransitionEffect.IDENTITY)
  }

  @Builder
  private PinnedSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_pinned_sources_heading') }) {
        this.PinnedSourceRows()
      }
    }
    .padding({ top: this.recentRuntimeSources.length > 0 ? ThemeConstants.SPACE_SM : 0 })
    .transition(TransitionEffect.IDENTITY)
  }

  @Builder
  private LanguageCardRow(row: RepeatItem<BrowseLanguageRow>) {
    Column() {
      GroupedListRowSurface({ first: row.item.first, last: row.item.last }) {
        if (this.usesWideSourceRows) {
          WidePairRow({
            first: () => { this.RuntimeSourceRow(row.item.sources[0], row.item.language) },
            second: () => {
              if (row.item.sources.length > 1) this.RuntimeSourceRow(row.item.sources[1], row.item.language)
            },
          })
          if (!row.item.last) WidePairDivider({ leftMargin: ThemeConstants.SPACE_XL })
        } else {
          this.SingleRuntimeSourceRow(row.item.sources[0], !row.item.last, row.item.language)
        }
      }
    }
    .width('100%')
    .padding({ top: row.item.leadingSpace })
    .onSizeChange((_oldSize: SizeOptions, size: SizeOptions): void => {
      this.languageMotion.rememberHeight(row.item.language, row.item.index, Number(size.height))
    })
  }

  @Builder
  private LanguageDisclosureRows(row: RepeatItem<BrowseLanguageRow>) {
    Repeat<BrowseLanguageRow>(row.item.disclosureRows ?? [])
      .each((card: RepeatItem<BrowseLanguageRow>) => { this.LanguageCardRow(card) })
      .key((card: BrowseLanguageRow): string => card.key)
  }

  @Builder
  private RuntimeSourceListItems() {
    // Let the outer List own row prefetch. A surrounding ListItemGroup can
    // repeatedly create and evict the same offscreen Repeat children.
    Repeat<BrowseLanguageRow>(this.languageRows)
      .each((row: RepeatItem<BrowseLanguageRow>) => {
        ListItem() {
          if (row.item.sources.length === 0) {
            Column() {
              SectionHeader({ title: `${sourceLanguageName(row.item.language) || s('source_catalog_language_unknown')} (${row.item.count})`,
                expanded: this.catalogFilters.languageGroupExpanded(row.item.language, this.chrome.search.query),
                onToggle: (bottom?: number): void => { this.toggleLanguageGroup(row.item.language, row.item.count, bottom) } })
              if (row.item.disclosureRows !== undefined) {
                ListDisclosureContent({ progress: this.languageMotion.progress, heightBudget: this.languageMotion.heightBudget,
                  content: () => { this.LanguageDisclosureRows(row) } })
                .width('100%')
                .clip(true)
              }
            }
            .width('100%')
            .padding({ top: row.item.leadingSpace })
          } else {
            this.LanguageCardRow(row)
          }
        }
        .transition(TransitionEffect.IDENTITY)
      })
      .key((row: BrowseLanguageRow): string => row.key)
      // Keep node contents tied to their source pair after a group changes.
      .virtualScroll({ reusable: false })
  }

  // The page owns the published row array so one state write updates the
  // groups, their counts and their rows together.
  private reloadInstalledSources(): void {
    this.sourcesLoading = true
    this.viewModel.loadInstalledSources()
    this.installedSources = this.viewModel.sources
    this.sourcesLoading = this.viewModel.loadingSources
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.reloadInstalledSources()
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

  @Monitor('sourceRuntimeState.revision')
  private onSourceRevisionChanged(): void {
    // A commit that changes the installed set must reach this page even when it
    // is never covered: the source manager can be pushed on top of an already
    // active Browse tab, so `active` and `rootNavigation.visible` keep their
    // values and a monitor that waits for those to change would never run.
    // Only a hidden page defers: its rows are rebuilt when it becomes visible,
    // which is the same visible-state entry below.
    if (!this.active || !this.rootNavigation.visible) return
    this.refreshInstalledSourceSummaries()
  }

  @Monitor('active', 'rootNavigation.visible')
  private refreshInstalledSourceSummaries(): void {
    // Registry publishers have already committed the live mutation. Reloading
    // every WASM here repeats disk work inside the reactive UI update.
    // A retained Browse page is also hidden under the manager. Keep its current
    // rows there; consume the newest revision once it is visible again instead
    // of rebuilding all summaries inside each package's completion callback.
    if (!this.active || !this.rootNavigation.visible ||
      this.displayedSourceRevision === this.sourceRuntimeState.revision) return
    this.reloadInstalledSources()
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
      this.reloadInstalledSources()
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
      inertialSpring: true,
      onDidScroll: this.onRootScroll,
      onListAreaChange: (area: Area): void => { this.languageMotion.setViewport(area) },
      pinnedOverlayHeight: this.chrome.searchHeight,
      listSpace: 0,
      contentBoundarySpacing: ThemeConstants.SPACE_SM,
      bottomPadding: ThemeConstants.SPACE_XL,
      floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
      onRefresh: async () => {
        await this.refreshSources()
      },
    }) {
      if (this.sourcesLoading) {
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
        if (this.recentRuntimeSources.length > 0) {
          this.RecentSourceListItems()
        }
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
