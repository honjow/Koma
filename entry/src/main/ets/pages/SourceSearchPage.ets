import { komaSheetOptions } from '../theme/KomaPopupOptions'
import { SourceSettingsSheetHost } from '../components/SourceSettingsSheetHost'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { SourceWebSessionSheet } from '../components/SourceWebSessionSheet'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { SourceWebChallengeScope } from '../sourceRuntime/SourceWebChallengeGate'
import { SourceMangaGrid } from '../components/SourceMangaGrid'
import { SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT } from '../components/SourceSearchTitleField'
import { SourcePaginationFooter } from '../components/SourcePaginationFooter'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { MangaGridItem } from '../components/MangaGridItem'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { gridColumnCount, gridFallbackContainerWidth } from '../utils/GridColumns'
import { SourceFiltersSheetScaffold } from '../components/SourceFiltersSheetScaffold'
import { sourceFilterSheetOptions } from '../components/SourceFilterSheetOptions'
import { SourceFilterControls, SourceFilterControlValue } from '../components/SourceFilterControls'
import { AppStrings } from '../i18n/AppStrings'
import { openSourceWebSession, prepareSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { safeSearchDiagnostic } from '../model/SearchStateMapper'
import { SourceFilter, SourceManga, sourceFiltersForQuery } from '../model/SourceModels'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

function s(name: string): string {
  return AppStrings.get(name)
}

interface SourceSearchGridRow {
  key: string
  kind: 'manga' | 'loading' | 'empty' | 'error' | 'footer'
  manga?: SourceManga
  bottomPadding: number
}
interface SourceSearchGridProjection {
  rows: SourceSearchGridRow[]
  byKey: Map<string, SourceSearchGridRow>
  fullRowIndexes: number[]
}

@ComponentV2
export struct SourceSearchPage {
  @Param selectionMode: boolean = false
  @Event onMangaSelected: (manga: SourceManga) => void = (_manga: SourceManga) => {}
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
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  private gridScroller: Scroller = new Scroller()
  @Local private filtersShown: boolean = false
  private searchTimer: number = 0
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
      this.viewModel.cancelFilterDataLoad()
      this.closeWebChallenge()
      return
    }
    if (this.webChallengeShown || this.webChallengeClosing) return
    const receipt = this.viewModel.searchWebChallenge
    if (receipt === null || receipt.sourceId !== this.source.sourceId) return
    if (!this.viewModel.claimWebChallenge(receipt.scope, receipt.id, this.chrome.visible)) return
    const source = this.currentSource()
    const params = prepareSourceWebSession(source.sourceId, source.displayName, receipt.requestHandle)
    if (params === undefined) {
      this.viewModel.cancelWebChallenge(receipt.scope, receipt.id)
      return
    }
    this.webChallengeId = receipt.id
    this.webChallengeScope = receipt.scope
    if (params.sourceSession !== undefined) params.sourceSession.allowClearanceRetry = receipt.allowClearanceRetry
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
      autoRetryOnClearance: this.webChallengeParams.sourceSession?.allowClearanceRetry ?? false,
      canProbeOriginal: (): boolean => { return this.viewModel.canRetryWebChallenge(this.webChallengeScope, this.webChallengeId, this.chrome.visible) },
      onClose: () => { this.closeWebChallenge() },
      onCompleted: () => { this.completeWebChallenge() },
    })
  }


  @Monitor('chrome.refreshRequestSeq')
  private handleSourceSessionReturn(): void {
    if (this.chrome.refreshRequestSeq <= this.handledRefreshRequestSeq) return
    this.handledRefreshRequestSeq = this.chrome.refreshRequestSeq
    this.retrySearch()
  }

  private canVerifySource(): boolean {
    return this.viewModel.searchNeedsWebSession && (this.currentSource().webSessionOrigins ?? []).length > 0
  }

  private verifySource(): void {
    const source = this.currentSource()
    if (!openSourceWebSession(source.sourceId, source.displayName, () => { this.chrome.markRefreshNeeded() })) {
      this.getUIContext().getPromptAction().showToast({ message: s('source_web_not_allowed') })
    }
  }

  private handledQueryChangeSeq: number = 0
  private handledQuerySubmitSeq: number = 0
  private searchInitializationStarted: boolean = false
  private searchFiltersReady: boolean = false
  private routeActive: boolean = false
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
    this.syncTitleActions()
    this.clearPendingSearchTimer()
    if (!this.searchFiltersReady) {
      return
    }
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
    this.syncTitleActions()
    this.clearPendingSearchTimer()
    if (!this.searchFiltersReady) {
      return
    }
    if (value.trim().length === 0) {
      this.viewModel.clearSearch(this.currentSource())
      return
    }
    void this.viewModel.runSearch(this.currentSource(), value)
  }

  private rerunSearchIfReady(): void {
    if (this.searchFiltersReady && this.query.trim().length > 0) {
      void this.viewModel.runSearch(this.currentSource(), this.query)
    }
  }

  private retrySearch(): void {
    this.clearPendingSearchTimer()
    if (!this.searchFiltersReady) {
      void this.initializeSearch()
      return
    }
    if (this.query.trim().length === 0) {
      return
    }
    void this.viewModel.retrySearchPage()
  }

  private setSearchFilterValue(filter: SourceFilter, value: SourceFilterControlValue | undefined): void {
    if (this.viewModel.setSearchFilterValue(filter.id, value)) {
      this.rerunSearchIfReady()
    }
  }

  private hasActiveSearchFilters(): boolean {
    return this.viewModel.hasSearchFilterChanges(this.query)
  }

  private hasRuntimeFilters(): boolean {
    return this.runtimeFilters().length > 0
  }

  private runtimeFilters(): SourceFilter[] {
    return sourceFiltersForQuery(this.viewModel.filters, this.query)
  }

  private isFilteredEmptySearch(): boolean {
    return this.query.trim().length > 0 && this.hasActiveSearchFilters()
  }

  private resetSearchFilters(): void {
    this.viewModel.resetSearchFilters(this.query)
    this.rerunSearchIfReady()
  }

  private openFilters(): void {
    this.filtersShown = true
    void this.loadFilterData()
  }

  private async loadFilterData(): Promise<void> {
    const error = await this.viewModel.fetchSourceFilterData()
    if (this.filtersShown && error.length > 0) this.getUIContext().getPromptAction().showToast({ message: error })
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
      filters: this.runtimeFilters(),
      values: this.viewModel.searchFilterValues,
      busy: this.viewModel.loadingSearch,
      optionsLoading: this.viewModel.loadingFilterData,
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
      message: this.viewModel.searchErrorMessage,
      actionLabel: this.canVerifySource() ? s('source_web_open') : s('common_retry'),
      showAction: !this.searchFiltersReady || this.query.trim().length > 0,
      action: () => {
        if (this.canVerifySource()) this.verifySource()
        else this.retrySearch()
      },
    })
  }

  @Computed
  private get gridProjection(): SourceSearchGridProjection {
    const rows: SourceSearchGridRow[] = []
    if (this.viewModel.searchResults.length === 0) {
      const kind: 'loading' | 'error' | 'empty' = this.viewModel.loadingSearch ? 'loading' : this.viewModel.searchErrorMessage.length > 0 ? 'error' : 'empty'
      rows.push({ key: kind, kind, bottomPadding: ThemeConstants.SPACE_MD })
    } else {
      const width = this.safeArea.windowWidthVp > 0 ? this.safeArea.windowWidthVp : gridFallbackContainerWidth()
      const columns = gridColumnCount(width, ThemeConstants.SOURCE_GRID_MIN_COLUMN_WIDTH,
        ThemeConstants.SPACE_MD, ThemeConstants.SPACE_XL)
      const lastRowStart = Math.floor((this.viewModel.searchResults.length - 1) / columns) * columns
      this.viewModel.searchResults.forEach((item: SourceManga, index: number) => {
        rows.push({ key: `manga:${item.sourceId}:${item.id}`, kind: 'manga', manga: item,
          bottomPadding: index >= lastRowStart ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG })
      })
      rows.push({ key: 'footer', kind: 'footer', bottomPadding: ThemeConstants.SPACE_MD })
    }
    const byKey = new Map<string, SourceSearchGridRow>()
    const fullRowIndexes: number[] = []
    rows.forEach((row: SourceSearchGridRow, index: number) => {
      byKey.set(row.key, row)
      if (row.kind !== 'manga') fullRowIndexes.push(index)
    })
    return { rows, byKey, fullRowIndexes }
  }

  private currentGridRow(row: SourceSearchGridRow): SourceSearchGridRow {
    return this.gridProjection.byKey.get(row.key) ?? row
  }

  @Builder
  private GridRowContent(row: SourceSearchGridRow) {
    if (row.kind === 'manga' && this.selectionMode) {
      Column() {
        MangaGridItem({ manga: row.manga!, reserveTitleSpace: true,
          onMangaTap: (selected: SourceManga) => { this.onMangaSelected(selected) } })
      }.width('100%')
      .priorityGesture(LongPressGesture({ repeat: false }).onAction((): void => { this.onMangaTap(row.manga!) }))
    } else if (row.kind === 'manga') {
      MangaGridItem({ manga: row.manga!, onMangaTap: (selected: SourceManga) => { this.onMangaTap(selected) } })
    } else if (row.kind === 'loading') {
      this.LoadingSearchState()
    } else if (row.kind === 'error') {
      this.SearchErrorState()
    } else if (row.kind === 'empty') {
      this.EmptySearch()
    } else {
      SourcePaginationFooter({
        isLoading: this.viewModel.loadingSearch,
        hasMore: this.viewModel.hasMoreSearch,
        isError: this.viewModel.searchErrorMessage.length > 0,
        errorMessage: this.viewModel.searchErrorMessage.length > 0
          ? `${this.viewModel.searchErrorMessage} · ${s('common_retry')}` : '',
        onRetry: () => { void this.viewModel.retrySearchPage() },
      })
    }
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
    this.viewModel.cancelFilterDataLoad()
    this.closeWebChallenge()
    this.routeActive = false
    this.clearPendingSearchTimer()
  }

  aboutToAppear(): void {
    this.routeActive = true
    this.viewModel.loadInstalledSources()
    this.query = this.chrome.query
    this.syncTitleActions()
    void this.initializeSearch()
  }

  private async initializeSearch(): Promise<void> {
    if (this.searchInitializationStarted) {
      return
    }
    this.searchInitializationStarted = true
    this.viewModel.loadingSearch = true
    this.viewModel.searchErrorMessage = ''
    try {
      await this.viewModel.ensureSearchFilters(this.currentSource(), this.chrome.initialQuery.length === 0)
    } catch (error) {
      this.searchInitializationStarted = false
      if (this.routeActive) {
        this.viewModel.searchErrorMessage = safeSearchDiagnostic(error as Error).userText
      }
      return
    } finally {
      this.viewModel.loadingSearch = false
    }
    if (!this.routeActive) {
      this.searchInitializationStarted = false
      return
    }
    this.searchFiltersReady = true
    this.syncTitleActions()
    this.handledQueryChangeSeq = this.chrome.queryChangeSeq
    this.handledQuerySubmitSeq = this.chrome.querySubmitSeq
    this.query = this.chrome.query
    if (this.query.trim().length > 0) {
      this.submitSearch(this.query)
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
          onAvailabilityChanged: (available: boolean) => { this.chrome.settingsAvailable = available },
          onSettingsSaved: () => {
            this.chrome.markRefreshNeeded()
            this.chrome.resume()
          },
        })
        Column() {}
          .width(0)
          .height(0)
          .bindSheet($$this.webChallengeShown, this.WebChallengeSheet, komaSheetOptions({
            detents: [SheetSize.LARGE], showClose: false,
            enableOutsideInteractive: false, enableFloatingDragBar: true,
            onWillDismiss: (action: DismissSheetAction) => {
              this.closeWebChallenge()
              action.dismiss()
            },
            onDisappear: () => { this.finishWebChallengeDismiss() },
          }))
        SourceMangaGrid({
          scroller: this.gridScroller,
          contentItemCount: this.gridProjection.rows.length,
          fullRowIndexes: this.gridProjection.fullRowIndexes,
          pinnedOverlayHeight: SOURCE_SEARCH_TITLE_BOTTOM_HEIGHT,
          onReachEnd: () => { void this.viewModel.loadMoreSearch() },
        }) {
          ForEach(this.gridProjection.rows, (row: SourceSearchGridRow) => {
            GridItem() { this.GridRowContent(this.currentGridRow(row)) }
              .padding({ bottom: this.currentGridRow(row).bottomPadding })
              .clip(false)
          }, (row: SourceSearchGridRow) => row.key)
        }
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.filtersShown, this.SearchFiltersSheet,
        komaSheetOptions(sourceFilterSheetOptions(() => {
          this.closeFilters()
        })))
    }
  }
}
