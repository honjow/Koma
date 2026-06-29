import { MangaGridItem } from '../components/MangaGridItem'
import { StorageKeys } from '../constants/StorageKeys'
import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

@Component
export struct SourceSearchPage {
  @Prop source: SourceRuntimeRegistryInstalledSourceSummary = {
    sourceId: '',
    displayName: '',
    version: '',
    wasmByteCount: 0,
    importStatus: 'staged',
    networkEnabled: false,
    httpEnabled: false,
    enabled: true,
    language: '',
    nsfw: false,
    status: 'staged',
    capabilities: [],
  }
  @ObjectLink viewModel: BrowseViewModel
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @State private query: string = ''
  private searchTimer: number = 0
  onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private topContentInset(): number {
    return this.topH + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.bottomH + ThemeConstants.FLOAT_BAR_HEIGHT + 20
  }

  private scheduleSearch(value: string): void {
    this.query = value
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    this.searchTimer = setTimeout(() => {
      void this.viewModel.runSearch(this.source, this.query)
      this.searchTimer = 0
    }, 300)
  }

  @Builder
  private EmptySearch() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.query.trim().length === 0 ? '输入关键词搜索' : '没有找到结果')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(this.query.trim().length === 0 ? '搜索当前源内的漫画。' : '换个关键词再试。')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_XL)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ResultsGrid(manga: SourceManga[]) {
    Grid() {
      ForEach(manga, (item: SourceManga) => {
        GridItem() {
          MangaGridItem({
            manga: item,
            onMangaTap: (selected: SourceManga) => {
              this.onMangaTap(selected)
            },
          })
        }
      }, (item: SourceManga) => `${item.sourceId}:${item.id}`)
    }
    .width('100%')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(14)
    .rowsGap(22)
  }

  aboutToDisappear(): void {
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  build() {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_LG }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text('搜索')
            .fontSize(ThemeConstants.FONT_SIZE_H1)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
          Text(this.source.displayName)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Search({ value: this.query, placeholder: '搜索漫画' })
          .width('100%')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .backgroundColor(ThemeConstants.CARD)
          .placeholderColor(ThemeConstants.TEXT_SECONDARY)
          .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
          .onChange((value: string) => {
            this.scheduleSearch(value)
          })
          .onSubmit((value: string) => {
            this.scheduleSearch(value)
          })

        if (this.viewModel.loadingSearch) {
          LoadingProgress()
            .width(ThemeConstants.SPACE_XXL)
            .height(ThemeConstants.SPACE_XXL)
            .color(ThemeConstants.BRAND_PRIMARY)
        } else if (this.viewModel.errorMessage.length > 0) {
          Text(this.viewModel.errorMessage)
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.DANGER)
            .padding(ThemeConstants.SPACE_LG)
            .borderRadius(ThemeConstants.RADIUS_CARD)
            .backgroundColor(ThemeConstants.CARD)
        } else if (this.viewModel.searchResults.length === 0) {
          this.EmptySearch()
        } else {
          this.ResultsGrid(this.viewModel.searchResults)
          if (this.viewModel.hasMoreSearch) {
            Button('加载更多')
              .height(ThemeConstants.BUTTON_HEIGHT)
              .width('100%')
              .borderRadius(ThemeConstants.RADIUS_CHIP)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .backgroundColor(ThemeConstants.CARD)
              .onClick(() => {
                void this.viewModel.loadMoreSearch()
              })
          }
        }
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_XL,
        right: ThemeConstants.SPACE_XL,
        top: this.topContentInset(),
        bottom: this.bottomContentInset(),
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .onReachEnd(() => {
      void this.viewModel.loadMoreSearch()
    })
  }
}
