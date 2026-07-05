import { MangaGridItem } from '../components/MangaGridItem'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  BrowseSourceSectionState,
  BrowseViewModel,
  SourceHomeSectionState,
  SourceListingDescriptor,
} from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

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
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private filtersExpanded: boolean = false
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

  private shouldLoadBrowseOnAppear(): boolean {
    if (this.viewModel.loadingBrowse) {
      return false
    }
    if (this.viewModel.selectedSource?.sourceId !== this.source.sourceId) {
      return true
    }
    return !this.hasBrowseContent() &&
      this.viewModel.errorMessage.length === 0 &&
      this.viewModel.selectedListingId.length === 0 &&
      this.viewModel.listings.length === 0
  }

  private currentSource(): SourceRuntimeRegistryInstalledSourceSummary {
    return this.viewModel.sourceSummaryForId(this.source.sourceId) ?? this.source
  }

  private reloadBrowse(): void {
    if (this.viewModel.loadingBrowse) {
      return
    }
    this.viewModel.loadInstalledSources()
    void this.viewModel.loadBrowseHome(this.currentSource())
  }

  private retryBrowseError(): void {
    if (this.hasBrowseContent()) {
      void this.viewModel.loadMoreBrowse()
      return
    }
    this.reloadBrowse()
  }

  private setBrowseFilterValue(filter: SourceFilter, value: SourceFilterControlValue | undefined): void {
    void this.viewModel.setBrowseFilterValue(filter.id, value)
  }

  private hasRuntimeFilters(): boolean {
    return this.viewModel.filters.length > 0
  }

  private toggleFilters(): void {
    this.filtersExpanded = !this.filtersExpanded
  }

  @Builder
  private ListingSelector() {
    if (this.viewModel.listings.length > 1) {
      Scroll() {
        Row({ space: ThemeConstants.SPACE_SM }) {
          ForEach(this.viewModel.listings, (listing: SourceListingDescriptor) => {
            this.ListingChip(listing)
          }, (listing: SourceListingDescriptor) => listing.id)
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  private ListingChip(listing: SourceListingDescriptor) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(listing.name)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.viewModel.selectedListingId === listing.id ?
          ThemeConstants.TEXT_ON_BRAND :
          ThemeConstants.BRAND_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    }
    .height(ThemeConstants.ACTION_CHIP_HEIGHT)
    .constraintSize({ maxWidth: 220 })
    .backgroundColor(this.viewModel.selectedListingId === listing.id ?
      ThemeConstants.BRAND_PRIMARY :
      $r('sys.color.ohos_id_color_button_normal'))
    .border({
      width: this.viewModel.selectedListingId === listing.id ? 0 : 1,
      color: this.viewModel.selectedListingId === listing.id ? Color.Transparent : ThemeConstants.BRAND_PRIMARY,
    })
    .onClick(() => {
      void this.viewModel.selectBrowseListing(listing)
    })
  }

  @Builder
  private RuntimeFilterControls() {
    SourceFilterControls({
      filters: this.viewModel.filters,
      values: this.viewModel.browseFilterValues,
      busy: this.viewModel.loadingBrowse,
      onFilterChange: (filter: SourceFilter, value: SourceFilterControlValue | undefined) => {
        this.setBrowseFilterValue(filter, value)
      },
      onReset: () => {
        void this.viewModel.resetBrowseFilters()
      },
    })
  }

  @Builder
  private SectionHeader(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
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
      this.SectionHeader(section.listing.name, section.manga.length)
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
            kind: 'secondary',
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
    .columnsGap(ThemeConstants.SPACE_MD)
    .rowsGap(ThemeConstants.SPACE_LG)
    .cachedCount(12)
  }

  @Builder
  private EmptyBrowseResults() {
    KomaEmptyState({
      title: s('source_browse_empty_results_title'),
      message: s('source_browse_empty_results_message'),
      actionLabel: s('common_reset'),
      showAction: this.viewModel.filters.length > 0,
      action: () => {
        void this.viewModel.resetBrowseFilters()
      },
    })
  }

  @Builder
  private BrowseErrorState() {
    KomaEmptyState({
      title: this.hasBrowseContent() ? s('browse_error_load_more') : s('browse_error_load_home'),
      message: this.viewModel.errorMessage,
      actionLabel: s('common_retry'),
      showAction: true,
      action: () => {
        this.retryBrowseError()
      },
    })
  }

  aboutToAppear(): void {
    if (this.shouldLoadBrowseOnAppear()) {
      this.reloadBrowse()
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        onReachEnd: () => {
          void this.viewModel.loadMoreBrowse()
        },
      }) {
        ListItem() {
          Row({ space: ThemeConstants.SPACE_MD }) {
            Text(`${this.currentSource().displayName} · v${this.currentSource().version}`)
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            KomaActionButton({
              label: s('tab_search'),
              kind: 'primary',
              compact: true,
              controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
              action: () => {
                this.onSearchRequested(this.currentSource())
              },
            })

            if (this.hasRuntimeFilters()) {
              KomaActionButton({
                label: s('common_filter'),
                kind: this.filtersExpanded ? 'primary' : 'secondary',
                compact: true,
                action: () => {
                  this.toggleFilters()
                },
              })
            }

            KomaIconButton({
              icon: $r('sys.symbol.arrow_clockwise'),
              kind: 'secondary',
              isEnabled: !this.viewModel.loadingBrowse,
              action: () => {
                this.reloadBrowse()
              },
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }

        if (this.viewModel.listings.length > 1) {
          ListItem() {
            this.ListingSelector()
          }
        }

        if (this.hasRuntimeFilters() && this.filtersExpanded) {
          ListItem() {
            this.RuntimeFilterControls()
          }
        }

        if (this.viewModel.loadingBrowse &&
          this.viewModel.homeSections.length === 0 &&
          this.viewModel.browseSections.length === 0) {
          ListItem() {
            LoadingProgress()
              .width(ThemeConstants.LOADING_SIZE_LARGE)
              .height(ThemeConstants.LOADING_SIZE_LARGE)
              .color(ThemeConstants.BRAND_PRIMARY)
          }
        } else if (this.viewModel.errorMessage.length > 0 && !this.hasBrowseContent()) {
          ListItem() {
            this.BrowseErrorState()
          }
        } else if (!this.hasBrowseContent()) {
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

          if (this.viewModel.errorMessage.length > 0) {
            ListItem() {
              this.BrowseErrorState()
            }
          } else if (this.viewModel.hasMoreBrowse) {
            ListItem() {
              KomaActionButton({
                label: this.viewModel.loadingBrowse ? s('common_loading_more') : s('common_load_more'),
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
  }
}
