import {
  BlurStrategy,
  hdsMaterial,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceListItem } from '../components/SourceListItem'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
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
  sourceRegistry: SourceRuntimeRegistry = appSourceRuntimeRegistry
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
  private SourceListItems() {
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
      .title('搜索')
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
        Column() {
          SecondaryListScaffold({
            listSpace: 18,
            horizontalPadding: 20,
            bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
          }) {
            if (this.viewModel.loadingSources) {
              ListItem() {
                Row() {
                  LoadingProgress()
                    .width(36)
                    .height(36)
                    .color($r('app.color.koma_accent'))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
              }
            } else if (this.viewModel.sources.length === 0) {
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
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
