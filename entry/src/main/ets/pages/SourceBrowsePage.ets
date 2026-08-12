import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { GroupedListSection } from '../components/ui/GroupedListSection'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFilter, SourceManga } from '../model/SourceModels'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectSourceRuntimeState, SourceRuntimeState } from '../state/SourceRuntimeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  BrowseSourceSectionState,
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
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private sourceRuntimeState: SourceRuntimeState = connectSourceRuntimeState()
  @Local private filtersShown: boolean = false
  @Local private listingMenuOpen: boolean = false
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
    const current = this.currentSource()
    const selected = this.viewModel.selectedSource
    if (selected?.sourceId !== current.sourceId ||
      selected?.version !== current.version ||
      selected?.wasmByteCount !== current.wasmByteCount) {
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
      columnCount: ThemeConstants.SOURCE_RESULT_GRID_COLUMN_COUNT,
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
      title: this.hasBrowseContent() ? s('browse_error_load_more') : s('browse_error_load_home'),
      message: this.viewModel.errorMessage,
      actionLabel: s('common_retry'),
      showAction: true,
      action: () => {
        this.retryBrowseError()
      },
    })
  }

  @Builder
  private SourceToolbar() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Blank()
      KomaActionButton({
        label: s('tab_search'),
        icon: $r('sys.symbol.magnifyingglass'),
        kind: 'ghost',
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.onSearchRequested(this.currentSource())
        },
      })
      if (this.hasRuntimeFilters()) {
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
          .bindSheet($$this.filtersShown, this.SourceFiltersSheet, {
            detents: [SheetSize.MEDIUM, SheetSize.LARGE],
            showClose: false,
            onDisappear: () => {
              this.closeFilters()
            },
          })
      }
      KomaIconButton({
        icon: $r('sys.symbol.arrow_clockwise'),
        kind: 'ghost',
        isEnabled: !this.viewModel.loadingBrowse,
        action: () => {
          this.reloadBrowse()
        },
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SourceFiltersSheet() {
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
          KomaActionButton({
            label: s('common_reset'),
            kind: 'ghost',
            compact: true,
            isEnabled: !this.viewModel.loadingBrowse,
            action: () => {
              void this.viewModel.resetBrowseFilters()
            },
          })
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
    .height(260)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  aboutToAppear(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel.loadInstalledSources()
    if (this.shouldLoadBrowseOnAppear()) {
      this.reloadBrowse()
    }
  }

  @Monitor('sourceRuntimeState.revision')
  private refreshCurrentSourceSummary(): void {
    reloadInstalledSourcePackages(getContext(this) as common.UIAbilityContext)
    this.viewModel.loadInstalledSources()
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
        reserveTitleBar: true,
        onReachEnd: () => {
          void this.viewModel.loadMoreBrowse()
        },
      }) {
        ListItem() {
          this.SourceToolbar()
        }

        if (this.viewModel.loadingBrowse &&
          this.viewModel.homeSections.length === 0 &&
          this.viewModel.browseSections.length === 0) {
          ListItem() {
            this.LoadingBrowseState()
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
