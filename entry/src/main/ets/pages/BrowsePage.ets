import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceListItem } from '../components/SourceListItem'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
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

function s(name: string): string {
  return AppStrings.get(name)
}

type PrivateBrowseSourceKey = 'komga' | 'kavita' | 'webdav' | 'opds'

interface PrivateBrowseSourceEntry {
  key: PrivateBrowseSourceKey
  title: ResourceStr
  badge: ResourceStr
  detail: ResourceStr
  initial: string
  color: ResourceColor
}

@ComponentV2
export struct BrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private viewModel: BrowseViewModel = new BrowseViewModel()
  @Local private refreshingSources: boolean = false
  @Local private komgaConfigured: boolean = false
  @Local private kavitaConfigured: boolean = false
  @Local private opdsConfigured: boolean = false
  @Local private webDavConfigured: boolean = false
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
        initial: 'K',
        color: ThemeConstants.SOURCE_KOMGA_COLOR,
      })
    }
    if (this.kavitaConfigured) {
      entries.push({
        key: 'kavita',
        title: s('route_kavita_title'),
        badge: s('browse_kavita_tag'),
        detail: s('browse_kavita_detail'),
        initial: 'K',
        color: ThemeConstants.SOURCE_KAVITA_COLOR,
      })
    }
    if (this.webDavConfigured) {
      entries.push({
        key: 'webdav',
        title: s('route_webdav_title'),
        badge: s('browse_webdav_tag'),
        detail: s('browse_webdav_detail'),
        initial: 'W',
        color: ThemeConstants.SOURCE_WEBDAV_COLOR,
      })
    }
    if (this.opdsConfigured) {
      entries.push({
        key: 'opds',
        title: s('route_opds_title'),
        badge: s('browse_opds_tag'),
        detail: s('browse_opds_detail'),
        initial: 'O',
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
  private SourceListItems() {
    ForEach(this.configuredPrivateSourceEntries(), (entry: PrivateBrowseSourceEntry) => {
      ListItem() {
        SourceListItem({
          title: entry.title,
          subtitle: entry.detail,
          badge: entry.badge,
          initial: entry.initial,
          accentColor: entry.color,
          showSearchButton: false,
          onActivate: () => {
            this.openPrivateSource(entry.key)
          },
        })
      }
    }, (entry: PrivateBrowseSourceEntry) => entry.key)

    ForEach(this.viewModel.sources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
      ListItem() {
        SourceListItem({
          source: source,
          languageBadge: this.viewModel.sourceLanguageBadge(source),
          onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
            this.openSource(selected)
          },
          onSourceSearch: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
            this.openSourceSearch(selected)
          },
        })
      }
    }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
  }

  aboutToAppear(): void {
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
    this.loadRemoteAvailability()
  }

  private async loadRemoteAvailability(): Promise<void> {
    try {
      const store = new RemoteServerStore(getContext(this) as common.UIAbilityContext)
      this.komgaConfigured = await store.loadKomga() !== undefined
      this.kavitaConfigured = await store.loadKavita() !== undefined
      this.opdsConfigured = await store.loadOpds() !== undefined
      this.webDavConfigured = await store.loadWebDav() !== undefined
      console.info(`[Komga] step=browse_availability configured=${this.komgaConfigured}`)
      console.info(`[Kavita] step=browse_availability configured=${this.kavitaConfigured}`)
      console.info(`[OPDS] step=browse_availability configured=${this.opdsConfigured}`)
      console.info(`[WebDAV] step=browse_availability configured=${this.webDavConfigured}`)
    } catch (error) {
      void error
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

  private refreshSources(): void {
    this.refreshingSources = true
    this.viewModel.loadInstalledSources()
    this.loadRemoteAvailability()
    this.refreshingSources = false
  }

  build() {
    Refresh({ refreshing: $$this.refreshingSources }) {
      Column() {
        SecondaryListScaffold({
          listSpace: ThemeConstants.SPACE_LG,
          horizontalPadding: ThemeConstants.SPACE_XL,
          bottomPadding: ThemeConstants.SPACE_XL,
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
          } else if (this.viewModel.sources.length === 0 && !this.komgaConfigured && !this.kavitaConfigured && !this.opdsConfigured && !this.webDavConfigured) {
            ListItem() {
              this.EmptySources()
            }
          } else {
            this.SourceListItems()
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
    .onRefreshing(() => {
      this.refreshSources()
    })
  }
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
