import { MangaGridItem } from '../components/MangaGridItem'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { SourceManga } from '../model/SourceModels'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

@ComponentV2
export struct SourceBrowsePage {
  @Param source: SourceRuntimeRegistryInstalledSourceSummary = {
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
  @Param viewModel: BrowseViewModel = new BrowseViewModel()
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Event onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => void =
    (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private topContentInset(): number {
    return this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.safeArea.bottomAvoidHeight + ThemeConstants.FLOAT_BAR_HEIGHT + 20
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

          KomaActionButton({
            label: '搜索',
            kind: 'primary',
            action: () => {
              this.onSearchRequested(this.source)
            },
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
            KomaActionButton({
              label: this.viewModel.loadingBrowse ? '加载中...' : '加载更多',
              kind: 'secondary',
              fill: true,
              isEnabled: !this.viewModel.loadingBrowse,
              action: () => {
                void this.viewModel.loadMoreBrowse()
              },
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
