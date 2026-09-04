import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT } from '../components/SourceBrowseTitleField'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { SourceFiltersSheetScaffold } from '../components/SourceFiltersSheetScaffold'
import { sourceFilterSheetOptions } from '../components/SourceFilterSheetOptions'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectSourceRuntimeState, SourceRuntimeState } from '../state/SourceRuntimeState'
import { SourceBrowseRouteChromeState } from '../state/SourceRouteChromeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  BrowseSourceSectionState,
  BrowseContentState,
  BrowseLoadIntent,
  BrowseViewModel,
  SourceHomeSectionState,
  SourceListingDescriptor,
} from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { reloadInstalledSourcePackages } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'

function s(name: string): string {
  return AppStrings.get(name)
}

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
  @Param chrome: SourceBrowseRouteChromeState = new SourceBrowseRouteChromeState()
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private sourceRuntimeState: SourceRuntimeState = connectSourceRuntimeState()
  private pendingSourceRuntimeRevision: number = 0
  @Local private filtersShown: boolean = false
  @Local private listingMenuOpen: boolean = false
  private browseScroller: Scroller = new Scroller()
  private handledFilterRequestSeq: number = 0
  private searchTimer: number = 0
  private handledQueryChangeSeq: number = 0
  private handledQuerySubmitSeq: number = 0
  @Event onSearchRequested: (source: SourceRuntimeRegistryInstalledSourceSummary) => void =
    (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private listingForHomeSection(section: SourceHomeSectionState): SourceListingDescriptor | undefined {
    if (section.listingId === undefined) {
      return undefined
    }
    return this.viewModel.listings.find((listing: SourceListingDescriptor): boolean => listing.id === section.listingId)
  }

  private hasListingForHomeSection(section: SourceHomeSectionState): boolean {
    return this.listingForHomeSection(section) !== undefined
  }

  private openHomeSectionListing(section: SourceHomeSectionState): void {
    const listing = this.listingForHomeSection(section)
    if (listing !== undefined) {
      void this.viewModel.selectBrowseListing(listing)
    }
  }

  private hasBrowseContent(): boolean {
    return this.viewModel.homeSections.length > 0 || this.viewModel.browseSections.some((section: BrowseSourceSectionState): boolean => {
      return section.manga.length > 0
    })
  }

  private isBlockingBrowseLoading(): boolean {
    return this.viewModel.browseContentState === BrowseContentState.UNRESOLVED ||
      this.viewModel.browseContentState === BrowseContentState.LOADING
  }

  private isSearchActive(): boolean {
    return this.viewModel.searchQuery.trim().length > 0
  }

  private clearPendingSearchTimer(): void {
    if (this.searchTimer !== 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  private scheduleBrowseSearch(value: string): void {
    this.clearPendingSearchTimer()
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.currentSource())
      return
    }
    this.searchTimer = setTimeout(() => {
      void this.viewModel.runSearch(this.currentSource(), value)
      this.searchTimer = 0
    }, 300)
  }

  private submitBrowseSearch(value: string): void {
    this.clearPendingSearchTimer()
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.currentSource())
      return
    }
    void this.viewModel.runSearch(this.currentSource(), value)
  }

  @Monitor('chrome.queryChangeSeq')
  private handleTitleQueryChange(): void {
    const requestSeq = this.chrome.queryChangeSeq
    if (requestSeq <= this.handledQueryChangeSeq) {
      return
    }
    this.handledQueryChangeSeq = requestSeq
    this.scheduleBrowseSearch(this.chrome.query)
  }

  @Monitor('chrome.querySubmitSeq')
  private handleTitleQuerySubmit(): void {
    const requestSeq = this.chrome.querySubmitSeq
    if (requestSeq <= this.handledQuerySubmitSeq) {
      return
    }
    this.handledQuerySubmitSeq = requestSeq
    this.submitBrowseSearch(this.chrome.query)
  }

  aboutToDisappear(): void {
    this.clearPendingSearchTimer()
  }

  private shouldLoadBrowseOnAppear(): boolean {
    if (this.viewModel.loadingBrowse) {
      return false
    }
    const current = this.currentSource()
    const selected = this.viewModel.selectedSource
    if (selected?.sourceId !== current.sourceId ||
      selected?.version !== current.version ||
      selected?.wasmByteCount !== current.wasmByteCount) {
      return true
    }
    return this.viewModel.browseContentState === BrowseContentState.UNRESOLVED
  }

  private currentSource(): SourceRuntimeRegistryInstalledSourceSummary {
    return this.viewModel.sourceSummaryForId(this.source.sourceId) ?? this.source
  }

  private reloadBrowse(): void {
    void this.loadBrowse(BrowseLoadIntent.INITIAL)
  }

  private async refreshBrowse(): Promise<void> {
    await this.loadBrowse(BrowseLoadIntent.REFRESH)
  }

  private async loadBrowse(intent: BrowseLoadIntent): Promise<void> {
    if (this.viewModel.loadingBrowse) {
      return
    }
    this.viewModel.loadInstalledSources()
    try {
      await this.viewModel.loadBrowseHome(this.currentSource(), intent)
    } finally {
      if (this.pendingSourceRuntimeRevision > 0) {
        this.pendingSourceRuntimeRevision = 0
        this.reloadBrowse()
      }
    }
  }

  private retryBrowseError(): void {
    void this.viewModel.retryBrowseFailure()
  }

  private setBrowseFilterValue(filter: SourceFilter, value: SourceFilterControlValue | undefined): void {
    void this.viewModel.setBrowseFilterValue(filter.id, value)
  }

  private hasRuntimeFilters(): boolean {
    return this.viewModel.filters.length > 0
  }

  private shouldOfferSearchFromEmptyState(): boolean {
    const source = this.currentSource()
    return !this.viewModel.sourceCanBrowse(source) && this.viewModel.sourceCanSearch(source)
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

  @Monitor('viewModel.filters')
  private syncTitleActionsFromViewModel(): void {
    this.syncTitleActions()
  }

  @Builder
  private ListingMenu() {
    Menu() {
      ForEach(this.viewModel.listings, (listing: SourceListingDescriptor) => {
        MenuItem({ content: listing.name })
          .onClick(() => {
            this.listingMenuOpen = false
            void this.viewModel.selectBrowseListing(listing)
          })
      }, (listing: SourceListingDescriptor) => listing.id)
    }
  }

  @Builder
  private RuntimeFilterControls() {
    SourceFilterControls({
      filters: this.viewModel.filters,
      values: this.viewModel.browseFilterValues,
      busy: this.viewModel.loadingBrowse,
      vertical: true,
      onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => {
        this.setBrowseFilterValue(filter, value)
      },
      onReset: () => {
        void this.viewModel.resetBrowseFilters()
      },
    })
  }

  private openListingMenu(): void {
    if (this.viewModel.listings.length > 1 && !this.viewModel.loadingBrowse) {
      this.listingMenuOpen = true
    }
  }

  @Builder
  private SectionHeader(title: string, count: number, selectable: boolean = false) {
    Row() {
      if (selectable) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: ThemeConstants.SPACE_XS }) {
            Text(title)
              .fontSize(ThemeConstants.FONT_SIZE_H3)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor([ThemeConstants.TEXT_TERTIARY])
          }
          .alignItems(VerticalAlign.Center)
        }
        .backgroundColor(Color.Transparent)
        .padding(0)
        .borderRadius(0)
        .bindMenu(this.listingMenuOpen, this.ListingMenu(), {
          placement: Placement.BottomLeft,
          onDisappear: () => {
            this.listingMenuOpen = false
          },
        })
        .accessibilityText(title)
        .onClick(() => {
          this.openListingMenu()
        })
      } else {
        Text(title)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Blank()
      Text(s('library_count_books').replace('%s', `${count}`))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
  }

  @Builder
  private BrowseSection(section: BrowseSourceSectionState) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      this.SectionHeader(section.listing.name, section.manga.length, this.viewModel.listings.length > 1)
      this.MangaGrid(section.manga)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private HomeSection(section: SourceHomeSectionState) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text(section.title)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Blank()
        if (this.hasListingForHomeSection(section)) {
          KomaActionButton({
            label: s('browse_section_open_listing'),
            kind: 'ghost',
            compact: true,
            isEnabled: !this.viewModel.loadingBrowse,
            action: () => {
              this.openHomeSectionListing(section)
            },
          })
        } else {
          Text(s('library_count_books').replace('%s', `${section.manga.length}`))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      .width('100%')
      this.MangaGrid(section.manga)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private MangaGrid(manga: SourceManga[]) {
    SourceMangaGrid({
      manga,
      onMangaTap: (selected: SourceManga) => {
        this.onMangaTap(selected)
      },
    })
  }

  @Builder
  private EmptyBrowseResults() {
    KomaEmptyState({
      title: s('source_browse_empty_results_title'),
      message: s('source_browse_empty_results_message'),
      actionLabel: this.shouldOfferSearchFromEmptyState() ? s('tab_search') : s('common_reset'),
      showAction: this.shouldOfferSearchFromEmptyState() || this.viewModel.filters.length > 0,
      action: () => {
        if (this.shouldOfferSearchFromEmptyState()) {
          this.onSearchRequested(this.currentSource())
        } else {
          void this.viewModel.resetBrowseFilters()
        }
      },
    })
  }

  @Builder
  private BrowseErrorState() {
    KomaEmptyState({
      title: this.viewModel.browseErrorIntent === BrowseLoadIntent.PAGINATION
        ? s('browse_error_load_more') : s('browse_error_load_home'),
      message: this.viewModel.errorMessage,
      actionLabel: s('common_retry'),
      showAction: true,
      action: () => {
        this.retryBrowseError()
      },
    })
  }

  @Builder
  private SourceFiltersSheet() {
    SourceFiltersSheetScaffold({
      title: s('common_filter'),
      resetLabel: s('common_reset'),
      showReset: true,
      resetEnabled: !this.viewModel.loadingBrowse,
      onClose: () => {
        this.closeFilters()
      },
      onReset: () => {
        void this.viewModel.resetBrowseFilters()
      },
    }) {
      this.RuntimeFilterControls()
    }
  }

  @Builder
  private LoadingBrowseState() {
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
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private BlockingBrowseLoadingOverlay() {
    Column() {
      Blank().height(this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT)
      Column() {
        this.LoadingBrowseState()
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      Blank().height(this.safeArea.bottomAvoidHeight + ThemeConstants.SPACE_XL)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel.loadInstalledSources()
    this.syncTitleActions()
    if (this.shouldLoadBrowseOnAppear()) {
      this.reloadBrowse()
    }
  }

  @Monitor('sourceRuntimeState.revision')
  private refreshCurrentSourceSummary(): void {
    if (this.viewModel.loadingBrowse) {
      this.pendingSourceRuntimeRevision = this.sourceRuntimeState.revision
      return
    }
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel.loadInstalledSources()
    this.syncTitleActions()
    if (this.shouldLoadBrowseOnAppear()) {
      this.reloadBrowse()
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack() {
        PullRefreshListScaffold({
          scroller: this.browseScroller,
          listSpace: ThemeConstants.SPACE_MD,
          horizontalPadding: ThemeConstants.SPACE_XL,
          bottomPadding: ThemeConstants.SPACE_XL,
          reserveTitleBar: true,
          topPadding: SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT,
          onRefresh: async () => {
            if (this.isSearchActive()) {
              await this.viewModel.runSearch(this.currentSource(), this.viewModel.searchQuery)
            } else {
              await this.refreshBrowse()
            }
          },
          onReachEnd: () => {
            if (this.isSearchActive()) {
              void this.viewModel.loadMoreSearch()
            } else {
              void this.viewModel.loadMoreBrowse()
            }
          },
        }) {
          if (this.isSearchActive()) {
            if (this.viewModel.loadingSearch && this.viewModel.searchResults.length === 0) {
              ListItem() {
                this.LoadingBrowseState()
              }
            } else if (this.viewModel.searchResults.length === 0) {
              ListItem() {
                KomaEmptyState({
                  title: s('source_search_empty_results_title'),
                  message: this.viewModel.errorMessage.length > 0
                    ? this.viewModel.errorMessage
                    : s('source_search_empty_results_message'),
                })
              }
            } else {
              ListItem() {
                this.MangaGrid(this.viewModel.searchResults)
              }
              if (this.viewModel.hasMoreSearch) {
                ListItem() {
                  KomaActionButton({
                    label: s('common_load_more'),
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
          } else if (!this.isBlockingBrowseLoading()) {
            if (this.viewModel.browseContentState === BrowseContentState.ERROR && !this.hasBrowseContent()) {
              ListItem() {
                this.BrowseErrorState()
              }
            } else if (this.viewModel.browseContentState === BrowseContentState.EMPTY) {
              ListItem() {
                this.EmptyBrowseResults()
              }
            } else {
              ForEach(this.viewModel.homeSections, (section: SourceHomeSectionState) => {
                ListItem() {
                  this.HomeSection(section)
                }
              }, (section: SourceHomeSectionState) => section.id)

              ForEach(this.viewModel.browseSections, (section: BrowseSourceSectionState) => {
                ListItem() {
                  this.BrowseSection(section)
                }
              }, (section: BrowseSourceSectionState) => section.listing.id)

              if (this.viewModel.browseContentState === BrowseContentState.ERROR &&
                this.viewModel.errorMessage.length > 0) {
                ListItem() {
                  this.BrowseErrorState()
                }
              } else if (this.viewModel.hasMoreBrowse) {
                ListItem() {
                  KomaActionButton({
                    label: this.viewModel.browseLoadIntent === BrowseLoadIntent.PAGINATION
                      ? s('common_loading_more') : s('common_load_more'),
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
          }
        }
        if (this.isBlockingBrowseLoading() && !this.isSearchActive()) {
          this.BlockingBrowseLoadingOverlay()
        }
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.filtersShown, this.SourceFiltersSheet,
        sourceFilterSheetOptions(() => {
          this.closeFilters()
        }))
    }
  }
}
