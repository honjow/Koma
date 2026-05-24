import { MangaGridItem } from '../components/MangaGridItem'
import { SourceManga } from '../model/SourceModels'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

@Component
export struct SourceBrowsePage {
  @Prop source: SourceRuntimeRegistryInstalledSourceSummary = {
    sourceId: '',
    displayName: '',
    version: '',
    wasmByteCount: 0,
    importStatus: 'staged',
    networkEnabled: false,
    httpEnabled: false,
  }
  @ObjectLink viewModel: BrowseViewModel
  onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => void = (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}
  onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  @Builder
  private SectionHeader(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Blank()
      Text(`${count} 本`)
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
  }

  @Builder
  private MangaGrid(manga: SourceManga[]) {
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
    .cachedCount(12)
  }

  aboutToAppear(): void {
    void this.viewModel.loadBrowseHome(this.source)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Column({ space: 4 }) {
            Text(this.source.displayName)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`v${this.source.version}`)
              .fontSize(14)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('搜索')
            .height(40)
            .padding({ left: 14, right: 14 })
            .borderRadius(8)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.koma_accent'))
            .onClick(() => {
              this.onSearchRequested(this.source)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.viewModel.loadingBrowse && this.viewModel.popularManga.length === 0 && this.viewModel.latestManga.length === 0) {
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
        } else {
          this.SectionHeader('热门', this.viewModel.popularManga.length)
          this.MangaGrid(this.viewModel.popularManga)

          this.SectionHeader('最新', this.viewModel.latestManga.length)
          this.MangaGrid(this.viewModel.latestManga)

          if (this.viewModel.hasMoreBrowse) {
            Button(this.viewModel.loadingBrowse ? '加载中...' : '加载更多')
              .height(42)
              .width('100%')
              .borderRadius(8)
              .fontSize(14)
              .fontColor($r('app.color.koma_accent'))
              .backgroundColor($r('app.color.koma_card'))
              .onClick(() => {
                void this.viewModel.loadMoreBrowse()
              })
          }
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.koma_background'))
    .onReachEnd(() => {
      void this.viewModel.loadMoreBrowse()
    })
  }
}
