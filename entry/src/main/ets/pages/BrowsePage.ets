import { komaSheetOptions, komaToastOptions } from '../theme/KomaPopupOptions'
import { SourceCatalogFiltersContent } from '../components/SourceCatalogFiltersContent'
import { appSourceCatalogFilters, SourceCatalogFilterState } from '../state/SourceCatalogFilterState'
import { SourceCatalogPageChrome } from '../state/SourceCatalogPageChrome'
import { groupSourcesByLanguage, SourceCatalogFilters, SourceLanguageGroup, sourceCatalogLanguage, sourceMatchesCatalogFilters } from '../model/SourceCatalogPresentation'
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
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { RouterHelper } from '../common/RouterHelper'
import { common } from '@kit.AbilityKit'
import { AnimatorResult, FrameCallback } from '@kit.ArkUI'
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
  title: ResourceStr
  badge: ResourceStr
  detail: ResourceStr
  color: ResourceColor
}

interface BrowsePinMotion {
  languageHeights: Map<string, number>
  pinnedHeight: number | undefined
}

class BrowsePinLayoutReady extends FrameCallback {
  private readonly run: () => void

  constructor(run: () => void) {
    super()
    this.run = run
  }

  onIdle(_timeLeftInNano: number): void {
    this.run()
  }
}

@ComponentV2
struct BrowseSourceSectionContent {
  @BuilderParam content: () => void
  @Event onHeight: (height: number) => void = (_height: number): void => {}

  onMeasureSize(_geometry: GeometryInfo, children: Measurable[], constraint: ConstraintSizeOptions): SizeResult {
    return children[0].measure({
      minWidth: constraint.minWidth,
      maxWidth: constraint.maxWidth,
      minHeight: 0,
      maxHeight: Number.POSITIVE_INFINITY,
    })
  }

  onPlaceChildren(_geometry: GeometryInfo, children: Layoutable[]): void {
    children[0].layout({ x: 0, y: 0 })
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .onSizeChange((_before: SizeOptions, after: SizeOptions): void => {
      this.onHeight(after.height as number)
    })
  }
}

// The viewport clips a fully measured section. Animate its native height
// property; never put the HDS row additions/removals in an animateTo transaction.
@ComponentV2
struct BrowseSourceSectionExtent {
  @BuilderParam content: () => void
  @Param fromHeight: number | undefined = undefined
  @Param progress: number = 1
  @Local private naturalHeight: number = 0

  private get displayHeight(): number | undefined {
    if (this.fromHeight === undefined) return undefined
    return Math.max(0, this.fromHeight + (this.naturalHeight - this.fromHeight) * this.progress)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      BrowseSourceSectionContent({
        onHeight: (height: number): void => {
          if (height !== this.naturalHeight) this.naturalHeight = height
        },
      }) {
        this.content()
      }
    }
    .width('100%')
    .height(this.displayHeight)
    .clip(true)
  }
}

@ComponentV2
export struct BrowsePage {
  @Param chrome: SourceCatalogPageChrome = new SourceCatalogPageChrome()
  @Local private catalogFilters: SourceCatalogFilterState = appSourceCatalogFilters
  @Local private filtersShown: boolean = false
  @Local private pinMotion: BrowsePinMotion | undefined = undefined
  @Local private pinProgress: number = 1
  private pinAnimator: AnimatorResult | undefined = undefined

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

  private sectionId(language?: string): string {
    return language === undefined ? 'browse-pinned-extent' : `browse-language-extent:${language}`
  }

  private sectionHeight(language?: string): number | undefined {
    const context = this.getUIContext()
    if (context.getFrameNodeById(this.sectionId(language)) === null) return undefined
    const size = context.getComponentUtils().getRectangleById(this.sectionId(language)).size
    return size.width > 0 ? context.px2vp(size.height) : undefined
  }

  private finishPinMotion(): void {
    const animator = this.pinAnimator
    this.pinAnimator = undefined
    this.pinMotion = undefined
    this.pinProgress = 1
    animator?.cancel()
  }

  private toggleSourcePin(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    const id = source.sourceId
    const pinned = !this.catalogFilters.pinnedSourceIds.includes(id)
    const language = sourceCatalogLanguage(source.language)
    const languageHeights = new Map<string, number>()
    // Rapid taps can retarget several sections. Sample their current viewport
    // heights before replacing the previous animation, including empty slots.
    const languages = new Set(this.pinMotion?.languageHeights.keys())
    languages.add(language)
    languages.forEach((key: string): void => {
      const height = this.sectionHeight(key) ?? (this.sourcesInLanguage(key).length === 0 ? 0 : undefined)
      if (height !== undefined) languageHeights.set(key, height)
    })
    const pinnedHeight = this.sectionHeight() ?? (this.pinnedRuntimeSources.length === 0 ? 0 : undefined)
    this.finishPinMotion()
    const motion: BrowsePinMotion = { languageHeights, pinnedHeight }
    this.pinMotion = motion
    this.pinProgress = 0
    // Repartition synchronously with the old section extents still reserved.
    // Only the new row exists. The animator drives geometry, not list keys.
    void this.catalogFilters.setSourcePinned(id, pinned).catch((): void => {
      if (this.pinMotion === motion) this.finishPinMotion()
      if (this.active && this.navigationVisible) {
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s('browse_source_pin_save_failed') }))
      }
    })
    // Start after ArkUI lays out the new rows at the old heights, so the
    // destination row's first layout does not consume the animation.
    this.getUIContext().postFrameCallback(new BrowsePinLayoutReady((): void => {
      if (this.pinMotion === motion) this.playPinMotion()
    }))
  }

  private playPinMotion(): void {
    const animator = this.getUIContext().createAnimator({
      duration: 220, easing: 'ease-in-out', delay: 0, fill: 'none', direction: 'normal',
      iterations: 1, begin: 0, end: 1,
    })
    this.pinAnimator = animator
    animator.onFrame = (progress: number): void => {
      if (this.pinAnimator === animator) this.pinProgress = progress
    }
    animator.onFinish = (): void => {
      if (this.pinAnimator === animator) {
        this.pinAnimator = undefined
        this.finishPinMotion()
      }
    }
    animator.play()
  }

  @Computed
  private get sourceGroupLanguages(): string[] {
    const languages = Object.keys(this.sourcesByLanguage)
    const motion = this.pinMotion
    if (motion) {
      motion.languageHeights.forEach((_height: number, language: string): void => {
        if (!languages.includes(language)) languages.push(language)
      })
      languages.sort((left: string, right: string): number => {
        if (left === right) return 0
        if (right.length === 0) return -1
        if (left.length === 0) return 1
        return left < right ? -1 : 1
      })
    }
    return languages
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

  private configuredPrivateSourceEntries(): PrivateBrowseSourceEntry[] {
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
    return entries
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
    return sources.sort((left: SourceRuntimeRegistryInstalledSourceSummary, right: SourceRuntimeRegistryInstalledSourceSummary): number =>
      compareSourceNames(displayNames.get(left.sourceId) ?? left.displayName, left.sourceId,
        displayNames.get(right.sourceId) ?? right.displayName, right.sourceId))
  }

  @Builder
  private EmptySources() {
    KomaEmptyState({
      icon: $r('sys.symbol.compass'),
      title: s(this.catalogFilters.active ? 'source_catalog_no_matches' : 'browse_empty_title'),
      message: s(this.catalogFilters.active ? 'source_catalog_no_matches_hint' : 'browse_empty_message'),
      showAction: false,
    })
  }

  @Builder
  private PrivateSourceListItems() {
    ListItem() {
      GroupedListSection({ title: s('browse_private_sources_heading') }) {
        ForEach(this.configuredPrivateSourceEntries(), (entry: PrivateBrowseSourceEntry, index: number) => {
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
          if (index + 1 < this.configuredPrivateSourceEntries().length) {
            ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
          }
        }, (entry: PrivateBrowseSourceEntry) => JSON.stringify([entry.key, entry.title, entry.detail, entry.badge]))
      }
    }.padding({ bottom: ThemeConstants.SPACE_SM })
  }

  @Builder
  private RuntimeSourceRow(source: SourceRuntimeRegistryInstalledSourceSummary, pinned: boolean) {
    SourceListItem({ source, subtitle: `v${source.version}`, languageBadge: '',
      accentColor: ThemeConstants.SOURCE_WASM_COLOR, showSearchButton: false, showPinButton: this.catalogFilters.loaded, pinned,
      onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary): void => { this.openSource(selected) },
      onPinToggle: (): void => { this.toggleSourcePin(source) } })
  }

  @Builder
  private PinnedSourceListItems() {
    ListItem() {
      BrowseSourceSectionExtent({ fromHeight: this.pinMotion?.pinnedHeight, progress: this.pinProgress }) {
        if (this.pinnedRuntimeSources.length > 0) {
          GroupedListSection({ title: s('browse_pinned_sources_heading') }) {
            // ArkUI appends index to the effective key if the builder uses it.
            // Derive the divider from live group membership instead.
            ForEach(this.pinnedRuntimeSources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
              this.RuntimeSourceRow(source, true)
              if (this.sourceNeedsDivider(this.pinnedRuntimeSources, source.sourceId)) {
                ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
              }
            }, (source: SourceRuntimeRegistryInstalledSourceSummary) => JSON.stringify([source.sourceId, source.version,
              sourceDisplayName(source.sourceId, source.displayName)]))
          }
          Blank().height(ThemeConstants.SPACE_SM)
        }
      }
    }.id(this.sectionId())
  }

  @Builder
  private RuntimeSourceListItems() {
    ForEach(this.sourceGroupLanguages, (language: string) => {
      ListItem() {
        // Keep group identity by language, but read its members from the live
        // projection. A retained ForEach closure must not keep an old group DTO.
        BrowseSourceSectionExtent({
          fromHeight: this.pinMotion?.languageHeights.get(language),
          progress: this.pinMotion?.languageHeights.has(language) ? this.pinProgress : 1,
        }) {
          if (this.sourcesInLanguage(language).length > 0) {
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
            Blank().height(ThemeConstants.SPACE_SM)
          }
        }
      }.id(this.sectionId(language))
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
    this.finishPinMotion()
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
    const sourceMetadataReloaded = reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
    await this.loadRemoteAvailability(true)
    if (!sourceMetadataReloaded) {
      throw new Error('source_metadata_reload_failed')
    }
  }

  build() {
    Stack() {
    PullRefreshListScaffold({
      scroller: this.browseScroller,
      // Own the section gaps so a zero-height slot has no residual List.space.
      listSpace: 0,
      topPadding: ThemeConstants.SPACE_SM,
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
        }.padding({ bottom: ThemeConstants.SPACE_SM })
      } else if (this.enabledRuntimeSources.length === 0 && !this.komgaConfigured && !this.kavitaConfigured && !this.opdsConfigured && !this.webDavConfigured) {
        ListItem() {
          this.EmptySources()
        }.padding({ bottom: ThemeConstants.SPACE_SM })
      } else {
        this.PinnedSourceListItems()
        if (this.configuredPrivateSourceEntries().length > 0) {
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
