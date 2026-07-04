import {
  BlurStrategy,
  hdsMaterial,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceListItem } from '../components/SourceListItem'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceBrowsePage } from './SourceBrowsePage'
import { SourceSearchPage } from './SourceSearchPage'
import { SourceManga } from '../model/SourceModels'
import { RouterHelper } from '../common/RouterHelper'
import { common } from '@kit.AbilityKit'
import { RemoteServerStore } from '../model/RemoteServerStore'
import { KomgaSeriesPage } from './KomgaSeriesPage'
import { KavitaBrowsePage } from './KavitaBrowsePage'
import { OpdsBrowsePage } from './OpdsBrowsePage'
import { WebDavBrowsePage } from './WebDavBrowsePage'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

const SOURCE_BROWSE_ROUTE_NAME: string = 'SourceBrowsePage'
const SOURCE_SEARCH_ROUTE_NAME: string = 'SourceSearchPage'
const KOMGA_ROUTE_NAME: string = 'KomgaSeriesPage'
const KAVITA_ROUTE_NAME: string = 'KavitaBrowsePage'
const OPDS_ROUTE_NAME: string = 'OpdsBrowsePage'
const WEBDAV_ROUTE_NAME: string = 'WebDavBrowsePage'

function s(name: string): string {
  return AppStrings.get(name)
}

interface SourceRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
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
  @Event onOpenSourcePackageManager: () => void = () => {}
  private browsePathStack: NavPathStack = new NavPathStack()

  private openSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.browsePathStack.pushPath({
      name: SOURCE_BROWSE_ROUTE_NAME,
      param: { source: source } as SourceRouteParam,
    })
  }

  private openSourceSearch(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.browsePathStack.pushPath({
      name: SOURCE_SEARCH_ROUTE_NAME,
      param: { source: source } as SourceRouteParam,
    })
  }

  private openKomga(): void {
    this.browsePathStack.pushPath({ name: KOMGA_ROUTE_NAME })
  }

  private openKavita(): void {
    this.browsePathStack.pushPath({ name: KAVITA_ROUTE_NAME })
  }

  private openWebDav(): void {
    this.browsePathStack.pushPath({ name: WEBDAV_ROUTE_NAME })
  }

  private openOpds(): void {
    this.browsePathStack.pushPath({ name: OPDS_ROUTE_NAME })
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
    if (this.komgaConfigured) {
      ListItem() {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('K')
              .fontSize(ThemeConstants.FONT_SIZE_H3)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_ON_BRAND)
          }
          .width(ThemeConstants.SOURCE_ICON_SIZE)
          .height(ThemeConstants.SOURCE_ICON_SIZE)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor(ThemeConstants.SOURCE_KOMGA_COLOR)

          Column({ space: ThemeConstants.SPACE_XS }) {
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text('Komga')
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .layoutWeight(1)
              Text(s('browse_komga_tag'))
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.BRAND_PRIMARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(ThemeConstants.RADIUS_CHIP)
                .backgroundColor(ThemeConstants.SOFT_TINT)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text(s('browse_komga_detail'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_MD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor(ThemeConstants.CARD)
        .onClick(() => {
          this.openKomga()
        })
      }
    }
    if (this.kavitaConfigured) {
      ListItem() {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('K')
              .fontSize(ThemeConstants.FONT_SIZE_H3)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_ON_BRAND)
          }
          .width(ThemeConstants.SOURCE_ICON_SIZE)
          .height(ThemeConstants.SOURCE_ICON_SIZE)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor(ThemeConstants.SOURCE_KAVITA_COLOR)

          Column({ space: ThemeConstants.SPACE_XS }) {
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text(s('route_kavita_title'))
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .layoutWeight(1)
              Text(s('browse_kavita_tag'))
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.BRAND_PRIMARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(ThemeConstants.RADIUS_CHIP)
                .backgroundColor(ThemeConstants.SOFT_TINT)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text(s('browse_kavita_detail'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_MD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor(ThemeConstants.CARD)
        .onClick(() => {
          this.openKavita()
        })
      }
    }
    if (this.webDavConfigured) {
      ListItem() {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('W')
              .fontSize(ThemeConstants.FONT_SIZE_H3)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_ON_BRAND)
          }
          .width(ThemeConstants.SOURCE_ICON_SIZE)
          .height(ThemeConstants.SOURCE_ICON_SIZE)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor(ThemeConstants.SOURCE_WEBDAV_COLOR)

          Column({ space: ThemeConstants.SPACE_XS }) {
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text('WebDAV')
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .layoutWeight(1)
              Text(s('browse_webdav_tag'))
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.BRAND_PRIMARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(ThemeConstants.RADIUS_CHIP)
                .backgroundColor(ThemeConstants.SOFT_TINT)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text(s('browse_webdav_detail'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_MD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor(ThemeConstants.CARD)
        .onClick(() => {
          this.openWebDav()
        })
      }
    }
    if (this.opdsConfigured) {
      ListItem() {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('O')
              .fontSize(ThemeConstants.FONT_SIZE_H3)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_ON_BRAND)
          }
          .width(ThemeConstants.SOURCE_ICON_SIZE)
          .height(ThemeConstants.SOURCE_ICON_SIZE)
          .borderRadius(ThemeConstants.RADIUS_ROUND)
          .backgroundColor(ThemeConstants.SOURCE_OPDS_COLOR)

          Column({ space: ThemeConstants.SPACE_XS }) {
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text('OPDS')
                .fontSize(ThemeConstants.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .layoutWeight(1)
              Text(s('browse_opds_tag'))
                .fontSize(ThemeConstants.FONT_SIZE_TAG)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.BRAND_PRIMARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(ThemeConstants.RADIUS_CHIP)
                .backgroundColor(ThemeConstants.SOFT_TINT)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text(s('browse_opds_detail'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_MD)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor(ThemeConstants.CARD)
        .onClick(() => {
          this.openOpds()
        })
      }
    }
    ForEach(this.viewModel.sources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
      ListItem() {
        SourceListItem({
          source: source,
          languageBadge: this.viewModel.sourceLanguageBadge(source),
          onSourceTap: (selected: SourceRuntimeRegistryInstalledSourceSummary) => {
            this.openSource(selected)
          },
        })
      }
    }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
  }

  @Builder
  private BrowseDestination(name: string, param: Object) {
    if (name === SOURCE_BROWSE_ROUTE_NAME) {
      NavDestination() {
        SourceBrowsePage({
          source: (param as SourceRouteParam).source,
          viewModel: this.viewModel,
          onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => {
            this.openSourceSearch(source)
          },
          onMangaTap: (manga: SourceManga) => {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId })
          },
        })
      }
      .title((param as SourceRouteParam).source.displayName)
    } else if (name === SOURCE_SEARCH_ROUTE_NAME) {
      NavDestination() {
        SourceSearchPage({
          source: (param as SourceRouteParam).source,
          viewModel: this.viewModel,
          onMangaTap: (manga: SourceManga) => {
            RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId })
          },
        })
      }
      .title(s('tab_search'))
    } else if (name === KOMGA_ROUTE_NAME) {
      NavDestination() {
        KomgaSeriesPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.libraryPersistenceService,
          onLibraryChanged: () => {
            this.onLibraryChanged()
          }
        })
      }
      .title(s('route_komga_title'))
    } else if (name === KAVITA_ROUTE_NAME) {
      NavDestination() {
        KavitaBrowsePage()
      }
      .title(s('route_kavita_title'))
    } else if (name === WEBDAV_ROUTE_NAME) {
      NavDestination() {
        WebDavBrowsePage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.libraryPersistenceService,
          onLibraryChanged: () => {
            this.onLibraryChanged()
          }
        })
      }
      .title(s('route_webdav_title'))
    } else if (name === OPDS_ROUTE_NAME) {
      NavDestination() {
        OpdsBrowsePage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.libraryPersistenceService,
          onLibraryChanged: () => {
            this.onLibraryChanged()
          }
        })
      }
      .title(s('route_opds_title'))
    }
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
    Navigation(this.browsePathStack) {
      Refresh({ refreshing: $$this.refreshingSources }) {
        Column() {
          SecondaryListScaffold({
            listSpace: ThemeConstants.SPACE_LG,
            horizontalPadding: ThemeConstants.SPACE_XL,
            bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
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
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.BrowseDestination)
  }

  private navDestTitleBarOpts(title: string): Record<string, Object> {
    let mat: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    let scrollOpts: Record<string, Object> = {
      'enableScrollEffect': true,
      'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    let style: Record<string, Object> = {
      'systemMaterialEffect': mat,
      'scrollEffectOpts': scrollOpts,
    }
    let titleInfo: Record<string, Object> = { 'mainTitle': title }
    let content: Record<string, Object> = { 'title': titleInfo }
    return {
      'avoidLayoutSafeArea': true,
      'enableComponentSafeArea': false,
      'blurStrategy': BlurStrategy.ENABLE,
      'content': content,
      'style': style,
    }
  }
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
