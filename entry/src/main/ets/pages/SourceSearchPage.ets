import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
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
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private query: string = ''
  @Local private filtersShown: boolean = false
  private searchTimer: number = 0
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private currentSource(): SourceRuntimeRegistryInstalledSourceSummary {
    return this.viewModel.sourceSummaryForId(this.source.sourceId) ?? this.source
  }

  private clearPendingSearchTimer(): void {
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  private scheduleSearch(value: string): void {
    this.query = value
    this.clearPendingSearchTimer()
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.currentSource())
      return
    }
    this.searchTimer = setTimeout(() => {
      void this.viewModel.runSearch(this.currentSource(), this.query)
      this.searchTimer = 0
    }, 300)
  }

  private submitSearch(value: string): void {
    this.query = value
    this.clearPendingSearchTimer()
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.currentSource())
      return
    }
    void this.viewModel.runSearch(this.currentSource(), value)
  }

  private rerunSearchIfReady(): void {
    if (this.query.trim().length > 0) {
      void this.viewModel.runSearch(this.currentSource(), this.query)
    }
  }

  private retrySearch(): void {
    this.clearPendingSearchTimer()
    if (this.query.trim().length === 0) {
      return
    }
    void this.viewModel.runSearch(this.currentSource(), this.query)
  }

  private setSearchFilterValue(filter: SourceFilter, value: SourceFilterControlValue | undefined): void {
    if (this.viewModel.setSearchFilterValue(filter.id, value)) {
      this.rerunSearchIfReady()
    }
  }

  private hasActiveSearchFilters(): boolean {
    return this.viewModel.hasSearchFilterChanges()
  }

  private hasRuntimeFilters(): boolean {
    return this.viewModel.filters.length > 0
  }

  private isFilteredEmptySearch(): boolean {
    return this.query.trim().length > 0 && this.hasActiveSearchFilters()
  }

  private resetSearchFilters(): void {
    this.viewModel.resetSearchFilters()
    this.rerunSearchIfReady()
  }

  private openFilters(): void {
    this.filtersShown = true
  }

  private closeFilters(): void {
    this.filtersShown = false
  }

  private searchPlaceholder(): string {
    const sourceName = this.currentSource().displayName
    return sourceName.length > 0 ? `${s('source_search_placeholder')} · ${sourceName}` : s('source_search_placeholder')
  }

  private emptySearchTitle(): string {
    if (this.query.trim().length === 0) {
      return s('source_search_empty_idle_title')
    }
    return this.isFilteredEmptySearch() ? s('source_search_filtered_empty_title') : s('source_search_empty_results_title')
  }

  private emptySearchMessage(): string {
    if (this.query.trim().length === 0) {
      return s('source_search_empty_idle_message')
    }
    return this.isFilteredEmptySearch() ? s('source_search_filtered_empty_message') : s('source_search_empty_results_message')
  }

  @Builder
  private RuntimeFilterControls() {
    SourceFilterControls({
      filters: this.viewModel.filters,
      values: this.viewModel.searchFilterValues,
      busy: this.viewModel.loadingSearch,
      vertical: true,
      onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => {
        this.setSearchFilterValue(filter, value)
      },
      onReset: () => {
        this.resetSearchFilters()
      },
    })
  }

  @Builder
  private EmptySearch() {
    KomaEmptyState({
      title: this.emptySearchTitle(),
      message: this.emptySearchMessage(),
      actionLabel: s('common_reset'),
      showAction: this.isFilteredEmptySearch(),
      action: () => {
        this.resetSearchFilters()
      },
    })
  }

  @Builder
  private SearchErrorState() {
    KomaEmptyState({
      title: s('source_search_error_title'),
      message: this.viewModel.errorMessage,
      actionLabel: s('common_retry'),
      showAction: this.query.trim().length > 0,
      action: () => {
        this.retrySearch()
      },
    })
  }

  @Builder
  private ResultsGrid(manga: SourceManga[]) {
    SourceMangaGrid({
      manga,
      columnCount: ThemeConstants.SOURCE_RESULT_GRID_COLUMN_COUNT,
      onMangaTap: (selected: SourceManga) => {
        this.onMangaTap(selected)
      },
    })
  }

  @Builder
  private SearchFiltersSheet() {
    Column() {
      Row() {
        Text(s('common_filter'))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([ThemeConstants.TEXT_PRIMARY])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(s('common_close'))
        .onClick(() => {
          this.closeFilters()
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_SM })

      Divider().strokeWidth(0.5).color(ThemeConstants.DIVIDER)

      Scroll() {
        Column({ space: ThemeConstants.SPACE_LG }) {
          GroupedListSection() {
            this.RuntimeFilterControls()
          }
          if (this.hasActiveSearchFilters()) {
            KomaActionButton({
              label: s('common_reset'),
              kind: 'ghost',
              compact: true,
              isEnabled: !this.viewModel.loadingSearch,
              action: () => {
                this.resetSearchFilters()
              },
            })
          }
          Blank().height(ThemeConstants.SPACE_XL)
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }

  aboutToDisappear(): void {
    this.clearPendingSearchTimer()
  }

  aboutToAppear(): void {
    this.viewModel.loadInstalledSources()
    void this.viewModel.ensureSearchFilters(this.currentSource())
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        reserveTitleBar: true,
        onReachEnd: () => {
          void this.viewModel.loadMoreSearch()
        },
      }) {
        ListItem() {
          Search({ value: this.query, placeholder: this.searchPlaceholder() })
            .width('100%')
            .height(ThemeConstants.INPUT_HEIGHT)
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .placeholderColor(ThemeConstants.TEXT_SECONDARY)
            .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
            .onChange((value: string) => {
              this.scheduleSearch(value)
            })
            .onSubmit((value: string) => {
              this.submitSearch(value)
            })
        }
        if (this.hasRuntimeFilters()) {
          ListItem() {
            Row() {
              Blank()
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Text(s('common_filter'))
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeConstants.BRAND_PRIMARY)
                  .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
              }
              .height(ThemeConstants.ACTION_CHIP_HEIGHT)
              .backgroundColor(Color.Transparent)
              .borderRadius(ThemeConstants.RADIUS_CHIP)
              .onClick(() => {
                this.openFilters()
              })
              .bindSheet($$this.filtersShown, this.SearchFiltersSheet, {
                detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                showClose: false,
                onDisappear: () => {
                  this.closeFilters()
                },
              })
            }
            .width('100%')
          }
        }
        if (this.viewModel.loadingSearch && this.viewModel.searchResults.length === 0) {
          ListItem() {
            LoadingProgress()
              .width(ThemeConstants.SPACE_XXL)
              .height(ThemeConstants.SPACE_XXL)
              .color(ThemeConstants.BRAND_PRIMARY)
          }
        } else if (this.viewModel.errorMessage.length > 0 && this.viewModel.searchResults.length === 0) {
          ListItem() {
            this.SearchErrorState()
          }
        } else if (this.viewModel.searchResults.length === 0) {
          ListItem() {
            this.EmptySearch()
          }
        } else {
          ListItem() {
            this.ResultsGrid(this.viewModel.searchResults)
          }
          if (this.viewModel.errorMessage.length > 0) {
            ListItem() {
              this.SearchErrorState()
            }
          }
          if (this.viewModel.hasMoreSearch) {
            ListItem() {
              KomaActionButton({
                label: this.viewModel.loadingSearch ? s('common_loading_more') : s('common_load_more'),
                kind: 'secondary',
                fill: true,
                isEnabled: !this.viewModel.loadingSearch,
                action: () => {
                  void this.viewModel.loadMoreSearch()
                },
              })
            }
          }
        }
      }
    }
  }
}
