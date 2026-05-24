import { SourceListItem } from '../components/SourceListItem'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceBrowsePage } from './SourceBrowsePage'
import { SourceSearchPage } from './SourceSearchPage'
import { SourceManga } from '../model/SourceModels'
import { RouterHelper } from '../common/RouterHelper'

const SOURCE_BROWSE_ROUTE_NAME: string = 'SourceBrowsePage'
const SOURCE_SEARCH_ROUTE_NAME: string = 'SourceSearchPage'

interface SourceRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
}

@Component
export struct BrowsePage {
  @State private viewModel: BrowseViewModel = new BrowseViewModel()
  @State private refreshingSources: boolean = false
  sourceRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
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

  @Builder
  private EmptySources() {
    Column({ space: 10 }) {
      Text('未安装任何源')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('导入本地源包后，可以在这里浏览源内漫画。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private SourceList() {
    List({ space: 10 }) {
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
    .width('100%')
    .layoutWeight(1)
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
      .hideTitleBar(true)
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
      .hideTitleBar(true)
    }
  }

  aboutToAppear(): void {
    this.viewModel = new BrowseViewModel(this.sourceRegistry)
    this.viewModel.loadInstalledSources()
  }

  private refreshSources(): void {
    this.refreshingSources = true
    this.viewModel.loadInstalledSources()
    this.refreshingSources = false
  }

  build() {
    Navigation(this.browsePathStack) {
      Refresh({ refreshing: $$this.refreshingSources }) {
        Column({ space: 18 }) {
          Column({ space: 4 }) {
            Text('浏览')
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Text(this.viewModel.sources.length > 0 ? `${this.viewModel.sources.length} 个已安装源` : '自定义源')
              .fontSize(14)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.viewModel.loadingSources) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color($r('app.color.koma_accent'))
          } else if (this.viewModel.sources.length === 0) {
            this.EmptySources()
          } else {
            this.SourceList()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, bottom: 28 })
        .backgroundColor($r('app.color.koma_background'))
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
}

export function createBrowseViewModel(registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()): BrowseViewModel {
  return new BrowseViewModel(registry)
}
