import { SourceSettingsSheetHost } from '../components/SourceSettingsSheetHost'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { SourceWebSessionSheet } from '../components/SourceWebSessionSheet'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { SourceWebChallengeScope } from '../sourceRuntime/SourceWebChallengeGate'
import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT } from '../components/SourceBrowseTitleField'
import { SourcePaginationFooter } from '../components/SourcePaginationFooter'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { MangaGridItem } from '../components/MangaGridItem'
import { gridColumnCount, gridFallbackContainerWidth } from '../utils/GridColumns'
import { SourceFiltersSheetScaffold } from '../components/SourceFiltersSheetScaffold'
import { sourceFilterSheetOptions } from '../components/SourceFilterSheetOptions'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { openSourceWebSession, prepareSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
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

interface SourceBrowseGridRow {
  key: string
  kind: 'home-header' | 'browse-header' | 'manga' | 'loading' | 'empty-search' | 'empty-browse' | 'error' | 'footer'
  manga?: SourceManga
  homeSection?: SourceHomeSectionState
  browseSection?: BrowseSourceSectionState
  bottomPadding: number
}
interface SourceBrowseGridRowParams {
  row: SourceBrowseGridRow
}
interface SourceBrowseSectionHeaderParams {
  section: BrowseSourceSectionState
}
interface SourceHomeSectionHeaderParams {
  section: SourceHomeSectionState
}
interface SourceBrowseGridProjection {
  rows: SourceBrowseGridRow[]
  byKey: Map<string, SourceBrowseGridRow>
  fullRowIndexes: number[]
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
  private handledFilterRequestSeq: number = 0
  private handledRefreshRequestSeq: number = 0

  @Local private webChallengeShown: boolean = false
  @Local private webChallengeParams: MangaWebRouteParam = { url: '', title: '' }
  private webChallengeClosing: boolean = false
  private webChallengeId: number = 0
  private webChallengeScope: SourceWebChallengeScope = 'browse'

  @Monitor('chrome.visible', 'viewModel.browseWebChallenge', 'viewModel.searchWebChallenge')
  private handleWebChallenge(): void {
    if (!this.chrome.visible) {
      this.closeWebChallenge()
      return
    }
    if (this.webChallengeShown || this.webChallengeClosing) return
    const receipt = this.isSearchActive() ? this.viewModel.searchWebChallenge : this.viewModel.browseWebChallenge
    if (receipt === null || receipt.sourceId !== this.source.sourceId) return
    if (!this.viewModel.claimWebChallenge(receipt.scope, receipt.id, this.chrome.visible)) return
    const source = this.currentSource()
    const params = prepareSourceWebSession(source.sourceId, source.displayName)
    if (params === undefined) {
      this.viewModel.cancelWebChallenge(receipt.scope, receipt.id)
      return
    }
    this.webChallengeId = receipt.id
    this.webChallengeScope = receipt.scope
    this.webChallengeParams = params
    this.webChallengeShown = true
  }

  private closeWebChallenge(): void {
    if (this.webChallengeShown) this.webChallengeClosing = true
    const session = this.webChallengeParams.sourceSession
    if (session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
    if (this.webChallengeId > 0) this.viewModel.cancelWebChallenge(this.webChallengeScope, this.webChallengeId)
    this.webChallengeId = 0
    this.webChallengeShown = false
  }

  private completeWebChallenge(): void {
    const id = this.webChallengeId
    const scope = this.webChallengeScope
    this.webChallengeClosing = true
    this.webChallengeId = 0
    this.webChallengeShown = false
    if (id > 0) void this.viewModel.completeWebChallenge(scope, id, this.chrome.visible)
  }

  private finishWebChallengeDismiss(): void {
    this.webChallengeClosing = false
    this.handleWebChallenge()
  }

  @Builder
  private WebChallengeSheet() {
    SourceWebSessionSheet({
      params: this.webChallengeParams,
      onClose: () => { this.closeWebChallenge() },
      onCompleted: () => { this.completeWebChallenge() },
    })
  }


  @Monitor('chrome.refreshRequestSeq')
  private handleSourceSessionReturn(): void {
    if (this.chrome.refreshRequestSeq <= this.handledRefreshRequestSeq) return
    this.handledRefreshRequestSeq = this.chrome.refreshRequestSeq
    if (this.isSearchActive()) void this.viewModel.runSearch(this.currentSource(), this.viewModel.searchQuery)
    else if (this.viewModel.browseErrorIntent !== BrowseLoadIntent.NONE) this.retryBrowseError()
    else void this.refreshBrowse()
  }

  private canVerifySource(): boolean {
    const needsSession = this.isSearchActive() ? this.viewModel.searchNeedsWebSession : this.viewModel.browseNeedsWebSession
    return needsSession && (this.currentSource().webSessionOrigins ?? []).length > 0
  }

  private verifySource(): void {
    const source = this.currentSource()
    if (!openSourceWebSession(source.sourceId, source.displayName, () => { this.chrome.markRefreshNeeded() })) {
      this.getUIContext().getPromptAction().showToast({ message: s('source_web_not_allowed') })
    }
  }

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
    this.closeWebChallenge()
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
    const source = this.currentSource()
    this.chrome.webSessionAvailable = source.enabled && (source.webSessionOrigins ?? []).length > 0
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
  private SectionHeader(params: SourceBrowseSectionHeaderParams) {
    Row() {
      if (this.viewModel.listings.length > 1) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: ThemeConstants.SPACE_XS }) {
            Text(params.section.listing.name)
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
        .accessibilityText(params.section.listing.name)
        .onClick(() => {
          this.openListingMenu()
        })
      } else {
        Text(params.section.listing.name)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Blank()
      Text(s('library_count_books').replace('%s', `${params.section.manga.length}`))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
  }

  @Builder
  private HomeSectionHeader(params: SourceHomeSectionHeaderParams) {
      Row() {
        Text(params.section.title)
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Blank()
        if (this.hasListingForHomeSection(params.section)) {
          KomaActionButton({
            label: s('browse_section_open_listing'),
            kind: 'ghost',
            compact: true,
            isEnabled: !this.viewModel.loadingBrowse,
            action: () => {
              this.openHomeSectionListing(params.section)
            },
          })
        } else {
          Text(s('library_count_books').replace('%s', `${params.section.manga.length}`))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      .width('100%')
  }

  private sourceGridColumnCount(): number {
    const width = this.safeArea.windowWidthVp > 0 ? this.safeArea.windowWidthVp : gridFallbackContainerWidth()
    return gridColumnCount(width, ThemeConstants.SOURCE_GRID_MIN_COLUMN_WIDTH, ThemeConstants.SPACE_MD,
      ThemeConstants.SPACE_XL)
  }

  private appendMangaRows(rows: SourceBrowseGridRow[], prefix: string, manga: SourceManga[]): void {
    const columns = this.sourceGridColumnCount()
    const lastRowStart = Math.floor((manga.length - 1) / columns) * columns
    manga.forEach((item: SourceManga, index: number) => {
      rows.push({ key: `${prefix}:manga:${item.sourceId}:${item.id}`, kind: 'manga', manga: item,
        bottomPadding: index >= lastRowStart ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG })
    })
  }

  @Computed
  private get gridProjection(): SourceBrowseGridProjection {
    const rows: SourceBrowseGridRow[] = []
    if (this.isSearchActive()) {
      if (this.viewModel.loadingSearch && this.viewModel.searchResults.length === 0) {
        rows.push({ key: 'search-loading', kind: 'loading', bottomPadding: ThemeConstants.SPACE_MD })
      } else if (this.viewModel.searchResults.length === 0 && this.viewModel.searchErrorMessage.length > 0) {
        rows.push({ key: 'search-error', kind: 'error', bottomPadding: ThemeConstants.SPACE_MD })
      } else if (this.viewModel.searchResults.length === 0) {
        rows.push({ key: 'search-empty', kind: 'empty-search', bottomPadding: ThemeConstants.SPACE_MD })
      } else {
        this.appendMangaRows(rows, 'search', this.viewModel.searchResults)
        rows.push({ key: 'search-footer', kind: 'footer', bottomPadding: ThemeConstants.SPACE_MD })
      }
    } else if (!this.isBlockingBrowseLoading()) {
      if (this.viewModel.browseContentState === BrowseContentState.ERROR && !this.hasBrowseContent()) {
        rows.push({ key: 'browse-error', kind: 'error', bottomPadding: ThemeConstants.SPACE_MD })
      } else if (this.viewModel.browseContentState === BrowseContentState.EMPTY) {
        rows.push({ key: 'browse-empty', kind: 'empty-browse', bottomPadding: ThemeConstants.SPACE_MD })
      } else {
        this.viewModel.homeSections.forEach((section: SourceHomeSectionState) => {
          const prefix = `home:${section.id}`
          rows.push({ key: `${prefix}:header`, kind: 'home-header', homeSection: section,
            bottomPadding: section.manga.length > 0 ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_MD * 2 })
          this.appendMangaRows(rows, prefix, section.manga)
        })
        this.viewModel.browseSections.forEach((section: BrowseSourceSectionState) => {
          const prefix = `browse:${section.listing.id}`
          rows.push({ key: `${prefix}:header`, kind: 'browse-header', browseSection: section,
            bottomPadding: section.manga.length > 0 ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_MD * 2 })
          this.appendMangaRows(rows, prefix, section.manga)
        })
        if (this.viewModel.browseContentState === BrowseContentState.ERROR &&
          this.viewModel.errorMessage.length > 0 && this.viewModel.browseErrorIntent !== BrowseLoadIntent.PAGINATION) {
          rows.push({ key: 'browse-error', kind: 'error', bottomPadding: ThemeConstants.SPACE_MD })
        } else if (this.viewModel.browseSections.length > 0) {
          rows.push({ key: 'browse-footer', kind: 'footer', bottomPadding: ThemeConstants.SPACE_MD })
        }
      }
    }
    const byKey = new Map<string, SourceBrowseGridRow>()
    const fullRowIndexes: number[] = []
    rows.forEach((row: SourceBrowseGridRow, index: number) => {
      byKey.set(row.key, row)
      if (row.kind !== 'manga') fullRowIndexes.push(index)
    })
    return { rows, byKey, fullRowIndexes }
  }

  private currentGridRow(row: SourceBrowseGridRow): SourceBrowseGridRow {
    return this.gridProjection.byKey.get(row.key) ?? row
  }

  @Builder
  private GridRowContent(params: SourceBrowseGridRowParams) {
    if (params.row.kind === 'manga') {
      MangaGridItem({ manga: params.row.manga!, onMangaTap: (selected: SourceManga) => { this.onMangaTap(selected) } })
    } else if (params.row.kind === 'home-header') {
      this.HomeSectionHeader({ section: params.row.homeSection! })
    } else if (params.row.kind === 'browse-header') {
      this.SectionHeader({ section: params.row.browseSection! })
    } else if (params.row.kind === 'loading') {
      this.LoadingBrowseState()
    } else if (params.row.kind === 'empty-search') {
      KomaEmptyState({ title: s('source_search_empty_results_title'),
        message: s('source_search_empty_results_message') })
    } else if (params.row.kind === 'empty-browse') {
      this.EmptyBrowseResults()
    } else if (params.row.kind === 'error') {
      this.BrowseErrorState()
    } else {
      SourcePaginationFooter({
        isLoading: this.isSearchActive() ? this.viewModel.loadingSearch :
          this.viewModel.loadingBrowse && this.viewModel.browseLoadIntent === BrowseLoadIntent.PAGINATION,
        hasMore: this.isSearchActive() ? this.viewModel.hasMoreSearch : this.viewModel.hasMoreBrowse,
        isError: this.isSearchActive() ? this.viewModel.errorMessage.length > 0 :
          this.viewModel.browseErrorIntent === BrowseLoadIntent.PAGINATION,
        onRetry: () => {
          if (this.isSearchActive()) void this.viewModel.retrySearchPage()
          else void this.viewModel.retryBrowseFailure()
        },
      })
    }
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
      title: this.isSearchActive() ? s('source_search_error_title') :
        this.viewModel.browseErrorIntent === BrowseLoadIntent.PAGINATION
          ? s('browse_error_load_more') : s('browse_error_load_home'),
      message: this.viewModel.errorMessage,
      actionLabel: this.canVerifySource() ? s('source_web_open') : s('common_retry'),
      showAction: true,
      action: () => {
        if (this.canVerifySource()) this.verifySource()
        else if (this.isSearchActive()) void this.viewModel.runSearch(this.currentSource(), this.viewModel.searchQuery)
        else this.retryBrowseError()
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
        SourceSettingsSheetHost({
          sourceId: this.source.sourceId,
          sourceName: this.source.displayName,
          requestSeq: this.chrome.settingsRequestSeq,
          active: this.chrome.visible,
          onSettingsSaved: () => {
            this.chrome.markRefreshNeeded()
            this.chrome.resume()
          },
        })
        Column() {}
          .width(0)
          .height(0)
          .bindSheet($$this.webChallengeShown, this.WebChallengeSheet, {
            detents: [SheetSize.LARGE], showClose: false,
            enableOutsideInteractive: false, enableFloatingDragBar: true,
            onWillDismiss: (action: DismissSheetAction) => {
              this.closeWebChallenge()
              action.dismiss()
            },
            onDisappear: () => { this.finishWebChallengeDismiss() },
          })
        SourceMangaGrid({
          scroller: this.chrome.scroller,
          contentItemCount: this.gridProjection.rows.length,
          fullRowIndexes: this.gridProjection.fullRowIndexes,
          pinnedOverlayHeight: SOURCE_BROWSE_TITLE_BOTTOM_HEIGHT,
          withPullRefresh: true,
          resumeAtVisibleTail: !this.isSearchActive() && !this.viewModel.loadingBrowse &&
            this.viewModel.hasMoreBrowse && this.viewModel.browseErrorIntent === BrowseLoadIntent.NONE,
          onRefresh: async () => {
            if (this.isSearchActive()) await this.viewModel.runSearch(this.currentSource(), this.viewModel.searchQuery)
            else await this.refreshBrowse()
          },
          onReachEnd: () => {
            if (this.isSearchActive()) void this.viewModel.loadMoreSearch()
            else void this.viewModel.loadMoreBrowse()
          },
        }) {
          ForEach(this.gridProjection.rows, (row: SourceBrowseGridRow) => {
            GridItem() { this.GridRowContent({ row: this.currentGridRow(row) }) }
              .padding({ bottom: this.currentGridRow(row).bottomPadding })
              .clip(false)
          }, (row: SourceBrowseGridRow) => row.key)
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
