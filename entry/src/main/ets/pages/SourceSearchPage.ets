import { MangaGridItem } from '../components/MangaGridItem'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct SourceSearchPage {
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
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private query: string = ''
  private searchTimer: number = 0
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private topContentInset(): number {
    return this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.safeArea.bottomAvoidHeight + ThemeConstants.FLOAT_BAR_HEIGHT + 20
  }

  private scheduleSearch(value: string): void {
    this.query = value
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.source)
      return
    }
    this.searchTimer = setTimeout(() => {
      void this.viewModel.runSearch(this.source, this.query)
      this.searchTimer = 0
    }, 300)
  }

  private rerunSearchIfReady(): void {
    if (this.query.trim().length > 0) {
      void this.viewModel.runSearch(this.source, this.query)
    }
  }

  private setSearchFilterValue(filter: SourceFilter, value: SourceFilterControlValue | undefined): void {
    if (this.viewModel.setSearchFilterValue(filter.id, value)) {
      this.rerunSearchIfReady()
    }
  }

  @Builder
  private RuntimeFilterControls() {
    SourceFilterControls({
      filters: this.viewModel.filters,
      values: this.viewModel.browseFilterValues,
      busy: this.viewModel.loadingSearch,
      onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => {
        this.setSearchFilterValue(filter, value)
      },
      onReset: () => {
        this.viewModel.resetSearchFilters()
        this.rerunSearchIfReady()
      },
    })
  }

  @Builder
  private EmptySearch() {
    KomaEmptyState({
      title: this.query.trim().length === 0 ? s('source_search_empty_idle_title') : s('source_search_empty_results_title'),
      message: this.query.trim().length === 0 ? s('source_search_empty_idle_message') : s('source_search_empty_results_message'),
    })
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

  aboutToAppear(): void {
    void this.viewModel.ensureSearchFilters(this.source)
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Scroll() {
        Column({ space: ThemeConstants.SPACE_LG }) {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(s('tab_search'))
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

          Search({ value: this.query, placeholder: s('source_search_placeholder') })
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

          this.RuntimeFilterControls()

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
              KomaActionButton({
                label: s('common_load_more'),
                kind: 'secondary',
                fill: true,
                action: () => {
                  void this.viewModel.loadMoreSearch()
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
      .backgroundColor(ThemeConstants.BG_SUB)
      .onReachEnd(() => {
        void this.viewModel.loadMoreSearch()
      })
    }
  }
}
