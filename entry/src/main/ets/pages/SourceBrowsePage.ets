import { MangaGridItem } from '../components/MangaGridItem'
import { StorageKeys } from '../constants/StorageKeys'
import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'
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
    enabled: true,
    language: '',
    nsfw: false,
    status: 'staged',
    capabilities: [],
  }
  @ObjectLink viewModel: BrowseViewModel
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => void = (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}
  onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private topContentInset(): number {
    return this.topH + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.bottomH + ThemeConstants.FLOAT_BAR_HEIGHT + 20
  }

  private bottomFloatingTabViewportClearance(): number {
    return this.bottomContentInset()
  }

  @Builder
  private SectionHeader(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Blank()
      Text(`${count} 本`)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
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
    .columnsGap(ThemeConstants.SPACE_LG)
    .rowsGap(ThemeConstants.SPACE_XL)
    .cachedCount(12)
  }

  aboutToAppear(): void {
    void this.viewModel.loadBrowseHome(this.source)
  }

  build() {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_LG }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(this.source.displayName)
              .fontSize(ThemeConstants.FONT_SIZE_H1)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`v${this.source.version}`)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('搜索')
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY)
            .onClick(() => {
              this.onSearchRequested(this.source)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.viewModel.loadingBrowse && this.viewModel.popularManga.length === 0 && this.viewModel.latestManga.length === 0) {
          LoadingProgress()
            .width(ThemeConstants.LOADING_SIZE_LARGE)
            .height(ThemeConstants.LOADING_SIZE_LARGE)
            .color(ThemeConstants.BRAND_PRIMARY)
        } else if (this.viewModel.errorMessage.length > 0) {
          Text(this.viewModel.errorMessage)
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.DANGER)
            .padding(ThemeConstants.SPACE_LG)
            .borderRadius(ThemeConstants.RADIUS_CARD)
            .backgroundColor(ThemeConstants.CARD)
        } else {
          this.SectionHeader('热门', this.viewModel.popularManga.length)
          this.MangaGrid(this.viewModel.popularManga)

          this.SectionHeader('最新', this.viewModel.latestManga.length)
          this.MangaGrid(this.viewModel.latestManga)

          if (this.viewModel.hasMoreBrowse) {
            Button(this.viewModel.loadingBrowse ? '加载中...' : '加载更多')
              .height(ThemeConstants.BUTTON_HEIGHT)
              .width('100%')
              .borderRadius(ThemeConstants.RADIUS_CHIP)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .backgroundColor(ThemeConstants.CARD)
              .onClick(() => {
                void this.viewModel.loadMoreBrowse()
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
    .padding({ bottom: this.bottomFloatingTabViewportClearance() })
    .clipContent(ContentClipMode.CONTENT_ONLY)
    .backgroundColor(ThemeConstants.BG_PRIMARY)
    .onReachEnd(() => {
      void this.viewModel.loadMoreBrowse()
    })
  }
}
