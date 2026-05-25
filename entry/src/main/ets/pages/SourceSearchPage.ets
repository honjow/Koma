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
    Column({ space: 8 }) {
      Text(this.query.trim().length === 0 ? '输入关键词搜索' : '没有找到结果')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text(this.query.trim().length === 0 ? '搜索当前源内的漫画。' : '换个关键词再试。')
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
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
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('搜索')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text(this.source.displayName)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Search({ value: this.query, placeholder: '搜索漫画' })
          .width('100%')
          .height(42)
          .backgroundColor($r('app.color.koma_card'))
          .placeholderColor($r('app.color.koma_text_secondary'))
          .textFont({ size: 15, weight: FontWeight.Regular })
          .onChange((value: string) => {
            this.scheduleSearch(value)
          })
          .onSubmit((value: string) => {
            this.scheduleSearch(value)
          })

        if (this.viewModel.loadingSearch) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.koma_accent'))
        } else if (this.viewModel.errorMessage.length > 0) {
          Text(this.viewModel.errorMessage)
            .width('100%')
            .fontSize(14)
            .fontColor($r('app.color.koma_danger'))
            .padding(16)
            .borderRadius(8)
            .backgroundColor($r('app.color.koma_card'))
        } else if (this.viewModel.searchResults.length === 0) {
          this.EmptySearch()
        } else {
          this.ResultsGrid(this.viewModel.searchResults)
          if (this.viewModel.hasMoreSearch) {
            Button('加载更多')
              .height(42)
              .width('100%')
              .borderRadius(8)
              .fontSize(14)
              .fontColor($r('app.color.koma_accent'))
              .backgroundColor($r('app.color.koma_card'))
              .onClick(() => {
                void this.viewModel.loadMoreSearch()
              })
          }
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.topContentInset(), bottom: this.bottomContentInset() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.koma_background'))
    .onReachEnd(() => {
      void this.viewModel.loadMoreSearch()
    })
  }
}
