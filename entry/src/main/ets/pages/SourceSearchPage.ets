import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT } from '../components/SourceSearchTitleField'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceFiltersSheetScaffold } from '../components/SourceFiltersSheetScaffold'
import { sourceFilterSheetOptions } from '../components/SourceFilterSheetOptions'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
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
  @Param chrome: SourceSearchRouteChromeState = new SourceSearchRouteChromeState()
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private query: string = ''
  @Local private filtersShown: boolean = false
  private searchTimer: number = 0
  private handledFilterRequestSeq: number = 0
  private handledQueryChangeSeq: number = 0
  private handledQuerySubmitSeq: number = 0
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

  private syncTitleActions(): void {
    this.chrome.filtersAvailable = this.hasRuntimeFilters()
  }

  @Monitor('chrome.filterRequestSeq')
  private handleTitleFilterRequest(): void {
    const requestSeq = this.chrome.filterRequestSeq
    if (requestSeq <= this.handledFilterRequestSeq) {
      return
    }
    this.handledFilterRequestSeq = requestSeq
    this.openFilters()
  }

  @Monitor('chrome.queryChangeSeq')
  private handleTitleQueryChange(): void {
    const requestSeq = this.chrome.queryChangeSeq
    if (requestSeq <= this.handledQueryChangeSeq) {
      return
    }
    this.handledQueryChangeSeq = requestSeq
    this.scheduleSearch(this.chrome.query)
  }

  @Monitor('chrome.querySubmitSeq')
  private handleTitleQuerySubmit(): void {
    const requestSeq = this.chrome.querySubmitSeq
    if (requestSeq <= this.handledQuerySubmitSeq) {
      return
    }
    this.handledQuerySubmitSeq = requestSeq
    this.submitSearch(this.chrome.query)
  }

  @Monitor('viewModel.filters')
  private syncTitleActionsFromViewModel(): void {
    this.syncTitleActions()
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
      onMangaTap: (selected: SourceManga) => {
        this.onMangaTap(selected)
      },
    })
  }

  @Builder
  private SearchFiltersSheet() {
    SourceFiltersSheetScaffold({
      title: s('common_filter'),
      resetLabel: s('common_reset'),
      showReset: this.hasActiveSearchFilters(),
      resetEnabled: !this.viewModel.loadingSearch,
      onClose: () => {
        this.closeFilters()
      },
      onReset: () => {
        this.resetSearchFilters()
      },
    }) {
      this.RuntimeFilterControls()
    }
  }

  @Builder
  private LoadingSearchState() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
      Text(s('common_loading'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  aboutToDisappear(): void {
    this.clearPendingSearchTimer()
  }

  aboutToAppear(): void {
    this.viewModel.loadInstalledSources()
    this.query = this.chrome.query
    this.syncTitleActions()
    void this.viewModel.ensureSearchFilters(this.currentSource())
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack() {
        SecondaryListScaffold({
          listSpace: ThemeConstants.SPACE_MD,
          horizontalPadding: ThemeConstants.SPACE_XL,
          pinnedOverlayHeight: SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT,
          bottomPadding: ThemeConstants.SPACE_XL,
          reserveTitleBar: true,
          onReachEnd: () => {
            void this.viewModel.loadMoreSearch()
          },
        }) {
          if (this.viewModel.loadingSearch && this.viewModel.searchResults.length === 0) {
            ListItem() {
              this.LoadingSearchState()
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
      .width('100%')
      .height('100%')
      .bindSheet($$this.filtersShown, this.SearchFiltersSheet,
        sourceFilterSheetOptions(() => {
          this.closeFilters()
        }))
    }
  }
}
