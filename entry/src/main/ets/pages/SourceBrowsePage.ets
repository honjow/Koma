import { MangaGridItem } from '../components/MangaGridItem'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { AppStrings } from '../i18n/AppStrings'
import { SourceManga } from '../model/SourceModels'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
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
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private languageState: LanguageState = connectLanguageState()
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

  @Builder
  private ListingSelector() {
    if (this.viewModel.listings.length > 1) {
      Scroll() {
        Row({ space: ThemeConstants.SPACE_SM }) {
          ForEach(this.viewModel.listings, (listing: SourceListingDescriptor) => {
            KomaActionButton({
              label: listing.name,
              kind: this.viewModel.selectedListingId === listing.id ? 'primary' : 'secondary',
              compact: true,
              action: () => {
                void this.viewModel.selectBrowseListing(listing)
              },
            })
          }, (listing: SourceListingDescriptor) => listing.id)
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
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
    this.SectionHeader(section.listing.name, section.manga.length)
    this.MangaGrid(section.manga)
  }

  @Builder
  private HomeSection(section: SourceHomeSectionState) {
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
    if (this.languageState.effectiveLocale.length >= 0) {
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
              label: s('tab_search'),
              kind: 'primary',
              action: () => {
                this.onSearchRequested(this.source)
              },
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.ListingSelector()

          if (this.viewModel.loadingBrowse &&
            this.viewModel.homeSections.length === 0 &&
            this.viewModel.browseSections.length === 0) {
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
            ForEach(this.viewModel.homeSections, (section: SourceHomeSectionState) => {
              this.HomeSection(section)
            }, (section: SourceHomeSectionState) => section.id)

            ForEach(this.viewModel.browseSections, (section: BrowseSourceSectionState) => {
              this.BrowseSection(section)
            }, (section: BrowseSourceSectionState) => section.listing.id)

            if (this.viewModel.hasMoreBrowse) {
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
}
