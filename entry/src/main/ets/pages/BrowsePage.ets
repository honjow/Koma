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

@ComponentV2
export struct BrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sourceRuntimeState: SourceRuntimeState = connectSourceRuntimeState()
  @Local private viewModel: BrowseViewModel = new BrowseViewModel()
  @Local private komgaConfigured: boolean = false
  @Local private kavitaConfigured: boolean = false
  @Local private opdsConfigured: boolean = false
  @Local private webDavConfigured: boolean = false
  @Param browseScroller: Scroller = new Scroller()
  @Param active: boolean = false
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
    return this.viewModel.sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.enabled)
      .sort((left: SourceRuntimeRegistryInstalledSourceSummary, right: SourceRuntimeRegistryInstalledSourceSummary): number =>
        compareSourceNames(resolveSourceLocalizedName(left.displayName, left.localizedNames, locale), left.sourceId,
          resolveSourceLocalizedName(right.displayName, right.localizedNames, locale), right.sourceId))
  }

  @Computed
  private get lastEnabledRuntimeSourceId(): string {
    const sources = this.enabledRuntimeSources
    return sources.length > 0 ? sources[sources.length - 1].sourceId : ''
  }

  private runtimeSourceSummary(source: SourceRuntimeRegistryInstalledSourceSummary): string {
    const language = this.viewModel.sourceLanguageBadge(source)
    return `v${source.version}` + (language.length > 0 ? ` · ${language}` : '')
  }

  @Builder
  private EmptySources() {
    KomaEmptyState({
      icon: $r('sys.symbol.compass'),
      title: s('browse_empty_title'),
      message: s('browse_empty_message'),
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
    }
  }

  @Builder
  private RuntimeSourceListItems() {
    ListItem() {
      GroupedListSection({
        title: s('browse_installed_sources_heading'),
        subtitle: s('browse_installed_sources_count').replace('%s', `${this.enabledRuntimeSources.length}`),
      }) {
        ForEach(this.enabledRuntimeSources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
          SourceListItem({
            source: source,
            subtitle: this.runtimeSourceSummary(source),
            languageBadge: this.viewModel.sourceLanguageBadge(source),
            accentColor: ThemeConstants.SOURCE_WASM_COLOR,
            showSearchButton: false,
            onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
              this.openSource(selected)
            },
            onSourceSearch: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
              this.openSourceSearch(selected)
            },
          })
          if (source.sourceId !== this.lastEnabledRuntimeSourceId) {
            ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
          }
        }, (source: SourceRuntimeRegistryInstalledSourceSummary) => JSON.stringify([source.sourceId, source.version,
          sourceDisplayName(source.sourceId, source.displayName)]))
      }
    }
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
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
  private refreshInstalledSourceSummaries(): void {
    // Registry publishers have already committed the live mutation. Reloading
    // every WASM here repeats disk work inside the reactive UI update.
    this.viewModel.loadInstalledSources()
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
    PullRefreshListScaffold({
      scroller: this.browseScroller,
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
      } else if (this.enabledRuntimeSources.length === 0 && !this.komgaConfigured && !this.kavitaConfigured && !this.opdsConfigured && !this.webDavConfigured) {
        ListItem() {
          this.EmptySources()
        }
      } else {
        if (this.configuredPrivateSourceEntries().length > 0) {
          this.PrivateSourceListItems()
        }
        if (this.enabledRuntimeSources.length > 0) {
          this.RuntimeSourceListItems()
        }
      }
    }
  }
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
