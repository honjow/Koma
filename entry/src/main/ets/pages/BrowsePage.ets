import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { SourceListItem } from '../components/SourceListItem'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
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
  private browseScroller: Scroller = new Scroller()
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

  private enabledRuntimeSources(): SourceRuntimeRegistryInstalledSourceSummary[] {
    return this.viewModel.sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.enabled)
  }

  private runtimeSourceSummary(source: SourceRuntimeRegistryInstalledSourceSummary): string {
    return `v${source.version} · ${this.viewModel.sourceLanguageBadge(source)}`
  }

  @Builder
  private EmptySources() {
    KomaEmptyState({
      title: s('browse_empty_title'),
      message: s('browse_empty_message'),
      actionLabel: s('browse_empty_action_manage_sources'),
      showAction: true,
      action: () => {
        this.onOpenSourcePackageManager()
      },
    })
  }

  @Builder
  private PrivateSourceListItems() {
    ListItem() {
      SectionHeader({ title: s('browse_private_sources_heading') })
    }
    ListItem() {
      GroupedListSection() {
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
        }, (entry: PrivateBrowseSourceEntry) => entry.key)
      }
    }
  }

  @Builder
  private RuntimeSourceListItems() {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_XS }) {
        SectionHeader({ title: s('browse_installed_sources_heading') })
        Text(s('browse_installed_sources_count').replace('%s', `${this.enabledRuntimeSources().length}`))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    ListItem() {
      GroupedListSection() {
        ForEach(this.enabledRuntimeSources(), (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) => {
          SourceListItem({
            source: source,
            subtitle: this.runtimeSourceSummary(source),
            languageBadge: this.viewModel.sourceLanguageBadge(source),
            showSearchButton: false,
            onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
              this.openSource(selected)
            },
            onSourceSearch: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
              this.openSourceSearch(selected)
            },
          })
          if (index + 1 < this.enabledRuntimeSources().length) {
            ListDivider({ leftMargin: ThemeConstants.SPACE_XL })
          }
        }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
      }
    }
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
    this.loadRemoteAvailability()
  }

  @Monitor('sourceRuntimeState.revision')
  private refreshInstalledSourceSummaries(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel.loadInstalledSources()
  }

  private async loadRemoteAvailability(reportFailure: boolean = false): Promise<void> {
    try {
      const store = new RemoteServerStore(getContext(this) as common.UIAbilityContext)
      const komgaConfigured = await store.loadKomga() !== undefined
      const kavitaConfigured = await store.loadKavita() !== undefined
      const opdsConfigured = await store.loadOpds() !== undefined
      const webDavConfigured = await store.loadWebDav() !== undefined
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
      if (reportFailure) {
        throw new Error('availability_load_failed')
      }
      this.komgaConfigured = false
      this.kavitaConfigured = false
      this.opdsConfigured = false
      this.webDavConfigured = false
      console.error('[Komga] step=browse_availability_failed code=availability_load_failed')
      console.error('[Kavita] step=browse_availability_failed code=availability_load_failed')
      console.error('[OPDS] step=browse_availability_failed code=availability_load_failed')
      console.error('[WebDAV] step=browse_availability_failed code=availability_load_failed')
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
      horizontalPadding: ThemeConstants.SPACE_XL,
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
      } else if (this.enabledRuntimeSources().length === 0 && !this.komgaConfigured && !this.kavitaConfigured && !this.opdsConfigured && !this.webDavConfigured) {
        ListItem() {
          this.EmptySources()
        }
      } else {
        if (this.configuredPrivateSourceEntries().length > 0) {
          this.PrivateSourceListItems()
        }
        if (this.enabledRuntimeSources().length > 0) {
          this.RuntimeSourceListItems()
        }
      }
    }
  }
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
