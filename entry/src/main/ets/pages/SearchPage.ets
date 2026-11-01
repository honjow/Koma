import { SearchResultRow, SearchResultRowSource } from '../model/SearchResultRowSource'
import { komaSheetOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { SourceWebSessionSheet } from '../components/SourceWebSessionSheet'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { SourceWebChallengeReceipt } from '../sourceRuntime/SourceWebChallengeGate'
import { prepareSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { cancelSourceWebProbe } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { KomaMenuController, KomaMenuGroup, KomaMenuAction } from '../components/ui/KomaMenuController'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { CachedCoverImage, cachedCoverFailureKey } from '../components/CachedCoverImage'
import { SEARCH_TITLE_BOTTOM_HEIGHT } from '../components/SearchTitleField'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  CrossSearchMatchQuality,
  CrossSearchResultItem,
  CrossSearchSection,
  CrossSearchService,
  CrossSearchSourceFilter,
  isCrossSearchQueryMeaningful,
} from '../model/CrossSearchService'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ComicSourceKind } from '../model/ComicModels'
import { KomgaSeriesRouteParam } from './KomgaSeriesPage'
import { KavitaBrowseRouteParam } from './KavitaBrowsePage'
import { OpdsBrowseRouteParam } from './OpdsBrowsePage'
import { LibraryStore } from '../model/LibraryStore'
import { LibrarySearchSource, copyLibrarySearchSource, parseLibrarySearchQuery } from '../model/LibrarySearchQuery'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  addSearchHistoryEntry,
  removeSearchHistoryEntry,
  SearchHistoryEntry,
  SearchHistoryScope,
  searchHistoryEntryKey,
  SearchHistoryStore,
} from '../model/SearchHistoryStore'
import { safeSearchDiagnostic, searchStateUserText } from '../model/SearchStateMapper'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceManga } from '../model/SourceModels'
import { MangaGridItem } from '../components/MangaGridItem'

const SEARCH_DEBOUNCE_MS: number = 400

enum SearchHistoryLoadState {
  LOADING = 'loading',
  READY = 'ready',
  FAILED = 'failed',
}

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct SearchPage {
  @Param migrationSources: string[] | undefined = undefined
  @Event onMangaSelected: (manga: SourceManga) => void = (_manga: SourceManga) => {}
  @Param chrome: SearchRouteChromeState = new SearchRouteChromeState()
  @Param initialLibrarySource: LibrarySearchSource | undefined = undefined
  @Local private librarySource: LibrarySearchSource | undefined = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private queryText: string = ''
  @Local private sections: CrossSearchSection[] = []
  @Local private history: SearchHistoryEntry[] = []
  @Local private historyLoadState: SearchHistoryLoadState = SearchHistoryLoadState.LOADING
  @Local private loading: boolean = false
  @Local private feedbackText: string = ''
  @Local private sourceFilter: CrossSearchSourceFilter = 'all'
  @Local private resultRowCount: number = 0
  private resultModeMutationEpoch: number = 0
  private filterMenu: KomaMenuController = new KomaMenuController()
  @Local private failedCoverUris: string[] = []
  @Local private webChallengeShown: boolean = false
  @Local private webChallengeParams: MangaWebRouteParam = { url: '', title: '' }
  private webChallengeReceipt: SourceWebChallengeReceipt | undefined = undefined
  private webChallengeClosing: boolean = false
  private webChallengeRetryPending: boolean = false
  private webChallengeRetrySerial: number = 0
  private webChallengeEpoch: number = 0
  private searchTimer: number = 0
  private searchSerial: number = 0
  private resultOpenSerial: number = 0
  private routeEpoch: number = 0
  private routeActive: boolean = false
  private historyMutationEpoch: number = 0
  private historyWriteTail: Promise<void> = Promise.resolve()
  private sourceFilterMutationEpoch: number = 0
  private sourceFilterWriteTail: Promise<void> = Promise.resolve()
  private handledQueryChangeSeq: number = 0
  private handledQuerySubmitSeq: number = 0
  private sourceFilterLoaded: boolean = false
  private resultsQuery: string = ''
  private resultsSourceFilter: CrossSearchSourceFilter = 'all'
  private resultsLibrarySourceKey: string = ''
  private resultRows: SearchResultRowSource = new SearchResultRowSource()
  private service?: CrossSearchService
  private historyStore?: SearchHistoryStore
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onOpenLibraryResult: (comicId: string) => void = (_comicId: string) => {}
  @Event onOpenKomgaResult: (param: KomgaSeriesRouteParam) => void = (_param: KomgaSeriesRouteParam) => {}
  @Event onOpenKavitaResult: (param: KavitaBrowseRouteParam) => void = (_param: KavitaBrowseRouteParam) => {}
  @Event onOpenOpdsResult: (param: OpdsBrowseRouteParam) => void = (_param: OpdsBrowseRouteParam) => {}

  @Monitor('sections', 'migrationSources', 'chrome.resultsOnly')
  private updateResultRows(): void {
    this.resultRows.update(this.sections, this.migrationSources !== undefined, this.chrome.resultsOnly)
    this.resultRowCount = this.resultRows.totalCount()
  }

  aboutToAppear(): void {
    this.routeEpoch += 1
    this.routeActive = true
    this.searchSerial += 1
    this.sourceFilterLoaded = false
    this.librarySource = copyLibrarySearchSource(this.initialLibrarySource)
    const context = getContext(this) as common.UIAbilityContext
    this.service = new CrossSearchService(context, this.libraryStore)
    this.historyStore = new SearchHistoryStore(context)
    if (this.migrationSources !== undefined) {
      this.sourceFilter = 'source'
      this.sourceFilterLoaded = true
      this.historyLoadState = SearchHistoryLoadState.READY
    } else {
      this.loadHistory()
      this.loadResultMode()
      this.loadSourceFilter()
    }
    this.consumeChromeQuery()
    console.info('[Search] step=page_appear')
  }

  aboutToReuse(): void {
    this.consumeChromeQuery()
  }

  aboutToDisappear(): void {
    this.filterMenu.close()
    this.invalidateWebChallenges()
    this.service?.cancelPendingSearch()
    this.routeActive = false
    this.routeEpoch += 1
    this.searchSerial += 1
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  @Monitor('chrome.visible')
  private synchronizeWebChallengeVisibility(): void {
    if (!this.chrome.visible) this.invalidateWebChallenges()
    else this.handleWebChallenges()
  }

  private cancelCurrentWebSession(): void {
    const session = this.webChallengeParams.sourceSession
    if (session === undefined) return
    cancelSourceWebProbe(session.sourceId, session.sessionId)
    appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
  }

  private invalidateWebChallenges(): void {
    this.webChallengeEpoch += 1
    this.webChallengeRetrySerial += 1
    this.webChallengeRetryPending = false
    this.cancelCurrentWebSession()
    this.service?.cancelWebChallenges()
    this.webChallengeReceipt = undefined
    if (this.webChallengeShown) this.webChallengeClosing = true
    this.webChallengeShown = false
  }

  private handleWebChallenges(): void {
    const service = this.service
    if (!this.routeActive || !this.chrome.visible || service === undefined ||
      this.webChallengeShown || this.webChallengeClosing || this.webChallengeRetryPending) return
    for (const section of this.sections) {
      const receipt = section.webChallenge
      if (receipt === undefined || !service.claimWebChallenge(receipt, true)) continue
      const params = prepareSourceWebSession(receipt.sourceId, section.title, receipt.requestHandle)
      if (params?.sourceSession === undefined) {
        service.cancelWebChallenge(receipt)
        continue
      }
      params.sourceSession.allowClearanceRetry = receipt.allowClearanceRetry
      this.webChallengeReceipt = receipt
      this.webChallengeParams = params
      this.webChallengeShown = true
      return
    }
  }

  private closeWebChallenge(): void {
    const receipt = this.webChallengeReceipt
    if (receipt !== undefined) {
      this.cancelCurrentWebSession()
      this.service?.cancelWebChallenge(receipt)
    }
    this.webChallengeReceipt = undefined
    if (this.webChallengeShown) this.webChallengeClosing = true
    this.webChallengeShown = false
  }

  private async completeWebChallenge(): Promise<void> {
    const receipt = this.webChallengeReceipt
    const service = this.service
    this.webChallengeReceipt = undefined
    this.webChallengeClosing = true
    this.webChallengeShown = false
    if (receipt === undefined || service === undefined) return
    const retrySerial = ++this.webChallengeRetrySerial
    this.webChallengeRetryPending = true
    try {
      // Finish this original read before another source can acquire the single
      // native verification probe. Other ordinary search results still arrive.
      await service.completeWebChallenge(receipt, this.routeActive && this.chrome.visible)
    } finally {
      if (retrySerial === this.webChallengeRetrySerial) {
        this.webChallengeRetryPending = false
        this.handleWebChallenges()
      }
    }
  }

  private finishWebChallengeDismiss(): void {
    this.webChallengeClosing = false
    this.handleWebChallenges()
  }

  @Builder
  private WebChallengeSheet() {
    SourceWebSessionSheet({
      params: this.webChallengeParams,
      autoRetryOnClearance: this.webChallengeParams.sourceSession?.allowClearanceRetry ?? false,
      canProbeOriginal: (): boolean => {
        const receipt = this.webChallengeReceipt
        return receipt !== undefined && (this.service?.canRetryWebChallenge(receipt,
          this.routeActive && this.chrome.visible) ?? false)
      },
      onClose: () => { this.closeWebChallenge() },
      onCompleted: () => { void this.completeWebChallenge() },
    })
  }

  private ownsRoute(routeEpoch: number): boolean {
    return this.routeActive && routeEpoch === this.routeEpoch
  }

  private scheduleSearch(value: string): void {
    const routeEpoch = this.routeEpoch
    if (!this.ownsRoute(routeEpoch)) {
      return
    }
    this.invalidateWebChallenges()
    this.service?.cancelPendingSearch()
    this.queryText = value
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    // Input takes ownership immediately, including the debounce interval.
    this.searchSerial += 1
    const serial = this.searchSerial
    const query = value.trim()
    this.prepareSearchResults(query)
    if (!this.hasMeaningfulSearchQuery(query)) {
      return
    }
    const timer = setTimeout(() => {
      if (this.searchTimer === timer) {
        this.searchTimer = 0
      }
      if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
        return
      }
      void this.runSearch(query)
    }, SEARCH_DEBOUNCE_MS)
    this.searchTimer = timer
  }

  private prepareSearchResults(query: string): void {
    this.feedbackText = ''
    if (!this.hasMeaningfulSearchQuery(query)) {
      this.resultsQuery = ''
      this.sections = []
      this.loading = false
      return
    }
    const service = this.service
    if (service === undefined) {
      this.loading = false
      return
    }
    const sourceFilter = this.effectiveSourceFilter(query)
    const sourceKey = this.librarySource?.key ?? ''
    const sameSearch = this.resultsQuery === query && this.resultsSourceFilter === sourceFilter &&
      this.resultsLibrarySourceKey === sourceKey
    const pending = service.pendingSections(sourceFilter, this.migrationSources)
    // A refresh keeps results owned by this same query/filter until replacement
    // data arrives. A changed query/filter starts with its existing pending UI.
    this.sections = sameSearch ? pending.map((section: CrossSearchSection): CrossSearchSection => {
      return this.sections.find((current: CrossSearchSection) => current.id === section.id) ?? section
    }) : pending
    this.resultsQuery = query
    this.resultsSourceFilter = sourceFilter
    this.resultsLibrarySourceKey = sourceKey
    this.loading = true
  }

  private async runSearch(value: string): Promise<void> {
    const routeEpoch = this.routeEpoch
    if (!this.ownsRoute(routeEpoch)) {
      return
    }
    this.invalidateWebChallenges()
    const webChallengeEpoch = this.webChallengeEpoch
    const query = value.trim()
    this.searchSerial += 1
    const serial = this.searchSerial
    this.prepareSearchResults(query)
    if (!this.hasMeaningfulSearchQuery(query)) {
      console.info(query.length === 0 ? '[Search] step=query_cleared' : '[Search] step=query_ignored reason=not_meaningful')
      return
    }
    const service = this.service
    if (service === undefined) {
      return
    }
    const sourceFilter = this.effectiveSourceFilter(query)
    if (this.migrationSources === undefined) this.recordHistory(query)
    console.info(`[Search] step=ui_search_start serial=${serial}`)
    try {
      const result = await service.search(query, sourceFilter, (section: CrossSearchSection) => {
        if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
          return
        }
        const sectionIndex = this.sections.findIndex((candidate: CrossSearchSection) => candidate.id === section.id)
        if (sectionIndex < 0) {
          return
        }
        const nextSections = this.sections.slice()
        nextSections[sectionIndex] = section
        this.sections = nextSections
        this.handleWebChallenges()
        console.info(`[Search] step=ui_section_resolved serial=${serial} source=${section.id} state=${section.state}`)
      }, (): boolean => this.ownsRoute(routeEpoch) && serial === this.searchSerial &&
        webChallengeEpoch === this.webChallengeEpoch && this.chrome.visible, this.migrationSources, this.librarySource)
      if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
        console.info(`[Search] step=ui_search_stale serial=${serial}`)
        return
      }
      // A verified source may already have retried while the other original
      // tasks were still pending. Their final aggregate must retain that result.
      this.sections = result.map((section: CrossSearchSection): CrossSearchSection =>
        this.sections.find((current: CrossSearchSection): boolean => current.id === section.id) ?? section)
      this.handleWebChallenges()
      this.feedbackText = ''
      console.info(`[Search] step=ui_search_done serial=${serial} sections=${result.length}`)
    } catch (error) {
      const e = error as Error
      if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
        return
      }
      this.invalidateWebChallenges()
      this.sections = []
      const diagnostic = safeSearchDiagnostic(e)
      this.feedbackText = diagnostic.userText
      DiagnosticLogger.error('search_page', 'ui_search_failed', '[Search] step=ui_search_failed code=' + diagnostic.code)
    } finally {
      if (this.ownsRoute(routeEpoch) && serial === this.searchSerial) {
        this.loading = false
      }
    }
  }

  private loadHistory(): void {
    const store = this.historyStore
    const routeEpoch = this.routeEpoch
    const mutationEpoch = this.historyMutationEpoch
    this.historyLoadState = SearchHistoryLoadState.LOADING
    if (store === undefined) {
      if (this.ownsRoute(routeEpoch)) {
        this.historyLoadState = SearchHistoryLoadState.FAILED
      }
      return
    }
    void store.load().then((entries: SearchHistoryEntry[]) => {
      if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.historyMutationEpoch) {
        return
      }
      this.history = entries
      this.historyLoadState = SearchHistoryLoadState.READY
    }).catch((error: Error) => {
      if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.historyMutationEpoch) {
        return
      }
      this.historyLoadState = SearchHistoryLoadState.FAILED
      DiagnosticLogger.error('search_page', 'history_load_failed', '[Search] step=history_load_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private recordHistory(query: string): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const store = this.historyStore
    const mutationEpoch = this.historyMutationEpoch + 1
    this.historyMutationEpoch = mutationEpoch
    const scope: SearchHistoryScope = { sourceFilter: this.effectiveSourceFilter(query),
      librarySource: copyLibrarySearchSource(this.librarySource) }
    this.history = addSearchHistoryEntry(this.history, query, Date.now(), scope)
    this.historyLoadState = SearchHistoryLoadState.READY
    if (store === undefined) {
      return
    }
    this.enqueueHistoryMutation(mutationEpoch, 'history_record', () => {
      return store.record(query, scope)
    })
  }

  private clearHistory(): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const store = this.historyStore
    const mutationEpoch = this.historyMutationEpoch + 1
    this.historyMutationEpoch = mutationEpoch
    this.history = []
    this.historyLoadState = SearchHistoryLoadState.LOADING
    if (store === undefined) {
      this.historyLoadState = SearchHistoryLoadState.READY
      return
    }
    this.enqueueHistoryMutation(mutationEpoch, 'history_clear', () => {
      return store.clear().then((): SearchHistoryEntry[] | undefined => undefined)
    })
  }

  private enqueueHistoryMutation(
    mutationEpoch: number,
    step: string,
    operation: () => Promise<SearchHistoryEntry[] | undefined>,
  ): void {
    const routeEpoch = this.routeEpoch
    const queued = this.historyWriteTail.then(operation, operation)
    this.historyWriteTail = queued.then(
      (): void => {},
      (): void => {},
    )
    void queued.then((entries: SearchHistoryEntry[] | undefined) => {
      if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.historyMutationEpoch) {
        return
      }
      if (entries !== undefined) {
        this.history = entries
      }
      this.historyLoadState = SearchHistoryLoadState.READY
    }).catch((error: Error) => {
      if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.historyMutationEpoch) {
        return
      }
      DiagnosticLogger.error('search_page', 'step', '[Search] step=' + step + '_failed code=' + safeSearchDiagnostic(error).code)
      this.loadHistory()
    })
  }

  private loadSourceFilter(): void {
    const store = this.historyStore
    const routeEpoch = this.routeEpoch
    const mutationEpoch = this.sourceFilterMutationEpoch
    if (store === undefined) {
      if (this.ownsRoute(routeEpoch)) {
        this.sourceFilterLoaded = true
        this.consumeChromeQuery()
      }
      return
    }
    void store.loadSourceFilter()
      .then((sourceFilter: CrossSearchSourceFilter) => {
        if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.sourceFilterMutationEpoch) {
          return
        }
        this.sourceFilter = sourceFilter
        console.info('[Search] step=source_filter_restored value=' + sourceFilter)
      })
      .catch((error: Error) => {
        if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.sourceFilterMutationEpoch) {
          return
        }
        DiagnosticLogger.error('search_page', 'source_filter_load_failed', '[Search] step=source_filter_load_failed code=' + safeSearchDiagnostic(error).code)
      })
      .finally(() => {
        if (!this.ownsRoute(routeEpoch)) {
          return
        }
        this.sourceFilterLoaded = true
        this.consumeChromeQuery()
      })
  }

  private confirmClearHistory(): void {
    if (this.history.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('search_history_clear_title'),
      message: s('search_history_clear_message').replace('%s', `${this.history.length}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearHistory()
        },
      },
    })
  }

  private removeHistoryEntry(entry: SearchHistoryEntry): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const store = this.historyStore
    const mutationEpoch = this.historyMutationEpoch + 1
    this.historyMutationEpoch = mutationEpoch
    this.history = removeSearchHistoryEntry(this.history, entry.query, entry)
    this.historyLoadState = SearchHistoryLoadState.READY
    if (store === undefined) {
      return
    }
    this.enqueueHistoryMutation(mutationEpoch, 'history_remove', () => {
      return store.remove(entry.query, entry)
    })
  }

  private runHistoryQuery(entry: SearchHistoryEntry): void {
    DiagnosticLogger.info('search', 'history_submit', 'recent_query')
    // Replaying a query restores its own range, without overwriting the user's
    // global preference. Invalidate a still-pending preference read as well.
    this.sourceFilterMutationEpoch += 1
    this.sourceFilterLoaded = true
    if (entry.sourceFilter !== undefined && entry.librarySource === undefined) this.sourceFilter = entry.sourceFilter
    this.librarySource = copyLibrarySearchSource(entry.librarySource)
    this.chrome.submitQuery(entry.query)
  }

  private runImmediateQuery(query: string): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    this.queryText = query
    void this.runSearch(query)
  }

  @Monitor('chrome.queryChangeSeq')
  private onChromeQueryChanged(): void {
    this.consumeChromeQuery()
  }

  @Monitor('chrome.querySubmitSeq')
  private onChromeQuerySubmitted(): void {
    this.consumeChromeQuery()
  }

  @Monitor('chrome.filterRequestSeq')
  private onChromeFilterRequest(): void {
    this.filterMenu.open(this.getUIContext(), this.chrome.filterAnchorId, (): KomaMenuGroup[] => {
      const kinds: CrossSearchSourceFilter[] = ['all', 'local', 'private', 'source']
      const labels = ['search_filter_all', 'search_filter_local', 'search_filter_private', 'search_filter_source']
      const items: KomaMenuAction[] = kinds.map((kind: CrossSearchSourceFilter, index: number): KomaMenuAction => ({
        label: s(labels[index]), selected: this.effectiveSourceFilter() === kind,
        isEnabled: !this.libraryQueryActive() || kind === 'local',
        action: (): void => { if (!this.libraryQueryActive()) this.setSourceFilter(kind) },
      }))
      return [{ id: 'scope', items }]
    }, (): void => { DiagnosticLogger.warn('search_page', 'filter_menu_open_failed', 'native_anchor') })
  }

  @Monitor('chrome.resultModeRequestSeq')
  private onChromeResultModeRequest(): void {
    this.filterMenu.open(this.getUIContext(), this.chrome.resultModeAnchorId, (): KomaMenuGroup[] => {
      return [{ id: 'results', items: [
        { label: s('search_results_all'), selected: !this.chrome.resultsOnly,
          action: (): void => { this.setResultMode(false) } },
        { label: s('search_results_only'), selected: this.chrome.resultsOnly,
          action: (): void => { this.setResultMode(true) } },
      ] }]
    }, (): void => { DiagnosticLogger.warn('search_page', 'result_mode_menu_open_failed', 'native_anchor') })
  }

  private loadResultMode(): void {
    const epoch = this.resultModeMutationEpoch
    const route = this.routeEpoch
    void this.historyStore?.loadResultsOnly().then((value: boolean): void => {
      if (this.ownsRoute(route) && epoch === this.resultModeMutationEpoch) this.chrome.resultsOnly = value
    }).catch((error: Error): void => { DiagnosticLogger.exception('search_page', 'result_filter_load_failed', error) })
  }

  private setResultMode(value: boolean): void {
    this.resultModeMutationEpoch++
    this.chrome.resultsOnly = value
    void this.historyStore?.saveResultsOnly(value).catch((error: Error): void => {
      DiagnosticLogger.exception('search_page', 'result_filter_save_failed', error)
    })
  }

  private consumeChromeQuery(): void {
    if (!this.routeActive || !this.sourceFilterLoaded) {
      return
    }
    if (this.chrome.queryChangeSeq > this.handledQueryChangeSeq) {
      this.handledQueryChangeSeq = this.chrome.queryChangeSeq
      this.handleSearchTextChange(this.chrome.query)
    }
    if (this.chrome.querySubmitSeq > this.handledQuerySubmitSeq) {
      this.handledQuerySubmitSeq = this.chrome.querySubmitSeq
      this.handleSearchSubmit(this.chrome.query)
    }
  }

  private handleSearchTextChange(value: string): void {
    this.scheduleSearch(value)
  }

  private handleSearchSubmit(value: string): void {
    this.runImmediateQuery(value)
  }

  private setSourceFilter(sourceFilter: CrossSearchSourceFilter): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const mutationEpoch = this.sourceFilterMutationEpoch + 1
    this.sourceFilterMutationEpoch = mutationEpoch
    const changed = this.sourceFilter !== sourceFilter
    this.sourceFilter = sourceFilter
    this.saveSourceFilter(sourceFilter, mutationEpoch)
    if (changed && this.hasMeaningfulSearchQuery()) {
      if (this.searchTimer > 0) {
        clearTimeout(this.searchTimer)
        this.searchTimer = 0
      }
      void this.runSearch(this.queryText)
    }
  }

  private saveSourceFilter(sourceFilter: CrossSearchSourceFilter, mutationEpoch: number): void {
    const store = this.historyStore
    if (store === undefined) {
      return
    }
    const write = (): Promise<void> => {
      return store.saveSourceFilter(sourceFilter).then((): void => {})
    }
    const queued = this.sourceFilterWriteTail.then(write, write)
    this.sourceFilterWriteTail = queued.catch(() => {})
    const routeEpoch = this.routeEpoch
    void queued.catch(async (error: Error): Promise<void> => {
      if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.sourceFilterMutationEpoch) {
        return
      }
      DiagnosticLogger.error('search_page', 'source_filter_save_failed', '[Search] step=source_filter_save_failed code=' + safeSearchDiagnostic(error).code)
      try {
        const committed = await store.loadSourceFilter()
        if (!this.ownsRoute(routeEpoch) || mutationEpoch !== this.sourceFilterMutationEpoch) {
          return
        }
        const changed = this.sourceFilter !== committed
        this.sourceFilter = committed
        if (changed && this.hasMeaningfulSearchQuery()) {
          this.runImmediateQuery(this.queryText)
        }
      } catch (readError) {
        DiagnosticLogger.error('search_page', 'source_filter_reload_failed', '[Search] step=source_filter_reload_failed code=' + safeSearchDiagnostic(readError as Error).code)
      }
    })
  }

  private async openResult(item: CrossSearchResultItem): Promise<void> {
    const routeEpoch = this.routeEpoch
    const searchSerial = this.searchSerial
    const openSerial = ++this.resultOpenSerial
    const ownsOpen = (): boolean => this.ownsRoute(routeEpoch) && this.searchSerial === searchSerial &&
      this.resultOpenSerial === openSerial
    if (!ownsOpen()) return
    console.info(`[Search] step=open_result kind=${item.sourceKind}`)
    if (item.sourceKind === 'local' && item.localComicId !== undefined) {
      this.onOpenLibraryResult(item.localComicId)
      return
    }
    if (item.sourceKind === 'wasm' && item.sourceId !== undefined && item.sourceMangaId !== undefined) {
      RouterHelper.pushMangaDetail({
        mangaId: item.sourceMangaId,
        sourceId: item.sourceId,
        initialManga: {
          id: item.sourceMangaId,
          sourceId: item.sourceId,
          title: item.title,
          coverUrl: item.coverUri,
          url: item.sourceMangaUrl,
        },
      })
      return
    }
    if (item.sourceKind === 'komga') {
      const param: KomgaSeriesRouteParam = {
        expectedServerId: item.remoteServerId,
        seriesId: item.komgaSeriesId,
        seriesTitle: item.title,
      }
      this.onOpenKomgaResult(param)
      return
    }
    if (item.sourceKind === 'kavita') {
      const param: KavitaBrowseRouteParam = {
        expectedServerId: item.remoteServerId,
        libraryId: item.kavitaLibraryId,
        seriesId: item.kavitaSeriesId,
        seriesTitle: item.title,
      }
      this.onOpenKavitaResult(param)
      return
    }
    if (item.sourceKind === 'opds') {
      const param: OpdsBrowseRouteParam = {
        expectedServerId: item.remoteServerId,
        feedUrl: item.opdsFeedUrl,
        searchQuery: item.opdsSearchQuery,
        publicationId: item.opdsPublicationId,
      }
      this.onOpenOpdsResult(param)
      return
    }
    if (item.sourceKind === 'webdav') {
      const service = this.service
      if (service === undefined) {
        return
      }
      try {
        const opened = await service.openWebDavReader(item, ownsOpen)
        if (opened && ownsOpen()) RouterHelper.pushReader()
      } catch (error) {
        if (!ownsOpen()) return
        const e = error as Error
        const diagnostic = safeSearchDiagnostic(e)
        this.feedbackText = diagnostic.userText
        DiagnosticLogger.error('search_page', 'open_webdav_failed', '[Search] step=open_webdav_failed code=' + diagnostic.code)
      }
    }
  }

  private totalResultCount(): number {
    let count = 0
    this.sections.forEach((section: CrossSearchSection) => {
      count += section.items.length
    })
    return count
  }

  private sourceSectionTitle(section: CrossSearchSection): string {
    return section.id.startsWith('wasm:') ? sourceDisplayName(section.id.substring(5), section.title) : section.title
  }

  private sectionTitle(section: CrossSearchSection): string {
    const title = this.sourceSectionTitle(section)
    return section.resultCount === 0 ? title : `${title} · ${section.resultCount}`
  }

  private resultSubtitle(item: CrossSearchResultItem): string {
    if (item.sourceKind === 'wasm' && item.sourceId !== undefined &&
      (item.subtitle.length === 0 || item.subtitle === item.sourceLabel)) {
      return sourceDisplayName(item.sourceId, item.sourceLabel)
    }
    const subtitle = item.subtitle.length === 0 ? item.sourceLabel : item.subtitle
    const comic = item.sourceKind === 'local' && item.localComicId !== undefined
      ? this.libraryStore.getComic(item.localComicId) : undefined
    const sourceId = comic?.sourceRuntimeId
    const sourceName = sourceId === undefined ? '' : sourceDisplayName(sourceId, comic?.sourceMetadata?.sourceName)
    return sourceName.length === 0 ? subtitle : `${sourceName} · ${subtitle}`
  }

  private sourceFilterLabel(): string {
    const sourceFilter = this.effectiveSourceFilter()
    if (sourceFilter === 'local') {
      return s('search_filter_local') + (this.librarySource === undefined ? '' : ' · ' + this.librarySource.name)
    }
    if (sourceFilter === 'private') {
      return s('search_filter_private')
    }
    if (sourceFilter === 'source') {
      return s('search_filter_source')
    }
    return s('search_filter_all')
  }

  private libraryQueryActive(value: string = this.queryText): boolean {
    return this.migrationSources === undefined &&
      (this.librarySource !== undefined || parseLibrarySearchQuery(value).libraryOnly)
  }

  private effectiveSourceFilter(value: string = this.queryText): CrossSearchSourceFilter {
    return this.libraryQueryActive(value) ? 'local' : this.sourceFilter
  }

  private hasMeaningfulSearchQuery(value: string = this.queryText): boolean {
    return this.librarySource !== undefined || isCrossSearchQueryMeaningful(value)
  }

  private historyLabel(entry: SearchHistoryEntry): string {
    return entry.librarySource === undefined ? entry.query :
      entry.librarySource.name + (entry.query.length > 0 ? ' · ' + entry.query : '')
  }

  @Builder
  private EmptyResults() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(!this.hasMeaningfulSearchQuery() ? s('search_empty_idle_title') : s('search_empty_results_title'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(!this.hasMeaningfulSearchQuery() ? s('search_empty_idle_message') : s('search_empty_results_message'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_XL)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private HistoryPanel() {
      if (this.historyLoadState === SearchHistoryLoadState.LOADING) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          LoadingProgress()
            .width(ThemeConstants.SPACE_XL)
            .height(ThemeConstants.SPACE_XL)
            .color(ThemeConstants.BRAND_PRIMARY)
          Text(s('common_loading'))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        .padding(ThemeConstants.SPACE_LG)
        .borderRadius(ThemeConstants.RADIUS_CARD)
        .backgroundColor(ThemeConstants.CARD)
        .justifyContent(FlexAlign.Center)
      } else if (this.historyLoadState === SearchHistoryLoadState.FAILED) {
        Text(s('common_load_failed'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor(ThemeConstants.CARD)
          .textAlign(TextAlign.Center)
      } else if (this.history.length === 0) {
        Column() {
          Text(s('search_empty_idle_message'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_TERTIARY)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: ThemeConstants.SPACE_XXL })
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text(s('search_recent_title'))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .layoutWeight(1)
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor([ThemeConstants.TEXT_SECONDARY])
            }
            .width(ThemeConstants.ACTION_CHIP_HEIGHT)
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .backgroundColor(Color.Transparent)
            .accessibilityText(s('common_clear'))
            .onClick(() => {
              this.confirmClearHistory()
            })
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: ThemeConstants.SPACE_XS })

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.history, (entry: SearchHistoryEntry) => {
              Row({ space: ThemeConstants.SPACE_XS }) {
                Text(this.historyLabel(entry))
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor(ThemeConstants.TEXT_PRIMARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .backgroundColor(ThemeConstants.CARD)
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .padding({
                left: ThemeConstants.SPACE_MD,
                right: ThemeConstants.SPACE_MD,
                top: ThemeConstants.SPACE_SM,
                bottom: ThemeConstants.SPACE_SM,
              })
              .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
              .onClick(() => {
                this.runHistoryQuery(entry)
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    this.removeHistoryEntry(entry)
                  })
              )
            }, (entry: SearchHistoryEntry) => `${searchHistoryEntryKey(entry.query, entry)}:${entry.updatedAt}`)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
  }

  @Builder
  private ActiveFilterBadge() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(s('search_filter_label') + ': ' + this.sourceFilterLabel())
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor([ThemeConstants.BRAND_PRIMARY])
    }
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: ThemeConstants.SPACE_XS,
      bottom: ThemeConstants.SPACE_XS,
    })
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      if (this.librarySource !== undefined) {
        this.librarySource = undefined
        this.runImmediateQuery(this.queryText)
      } else {
        this.setSourceFilter('all')
      }
    })
  }

  private formatHistoryTime(updatedAt: number): string {
    const date = new Date(updatedAt)
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${month}-${day} ${hour}:${minute}`
  }

  private sectionStatusText(section: CrossSearchSection): string {
    if (section.errorText.length > 0) {
      return section.errorText
    }
    return searchStateUserText(section.state, section.diagnosticCode)
  }

  private matchQualityLabel(matchQuality: CrossSearchMatchQuality | undefined): string {
    if (matchQuality === 'title_exact') {
      return s('search_match_title_exact')
    }
    if (matchQuality === 'title_prefix') {
      return s('search_match_title_prefix')
    }
    if (matchQuality === 'title_contains') {
      return s('search_match_title_contains')
    }
    if (matchQuality === 'metadata_prefix') {
      return s('search_match_metadata_prefix')
    }
    if (matchQuality === 'metadata_contains') {
      return s('search_match_metadata_contains')
    }
    return s('search_match_weak')
  }

  private shouldShowCoverUri(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string, sourceMangaUrl?: string): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, undefined, undefined, sourceMangaUrl)) < 0
  }

  private markCoverUriFailed(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string, sourceMangaUrl?: string): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, undefined, undefined, sourceMangaUrl)
    if (normalized.length > 0 && this.failedCoverUris.indexOf(failureKey) < 0) {
      this.failedCoverUris = this.failedCoverUris.concat([failureKey])
    }
  }

  private isSourceAwareCover(item: CrossSearchResultItem): boolean {
    const coverUri = item.coverUri?.trim() ?? ''
    const sourceId = item.sourceId?.trim() ?? ''
    return item.sourceKind === 'wasm' && sourceId.length > 0 && coverUri.length > 0
  }

  @Builder
  private ResultRow(item: CrossSearchResultItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        if (this.shouldShowCoverUri(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id, item.sourceMangaUrl)) {
          if (this.isSourceAwareCover(item) || item.sourceKind === 'kavita') {
            CachedCoverImage({
              uri: item.coverUri ?? '',
              objectFit: ImageFit.Cover,
              sourceRuntimeId: item.sourceId ?? '',
              sourceImageId: item.kavitaSeriesId ?? item.sourceMangaId ?? item.id,
              sourceMangaUrl: item.sourceMangaUrl ?? '',
              sourceKind: item.sourceKind === 'kavita' ? ComicSourceKind.KAVITA_REMOTE : undefined,
              remoteServerId: item.remoteServerId ?? '',
              onError: () => {
                this.markCoverUriFailed(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id, item.sourceMangaUrl)
              },
            })
          } else {
            Image(item.coverUri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .interpolation(ImageInterpolation.Medium)
              .onError(() => {
                this.markCoverUriFailed(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id, item.sourceMangaUrl)
              })
          }
        } else {
          SymbolGlyph($r('sys.symbol.book'))
            .fontSize(ThemeConstants.FONT_SIZE_H2)
            .fontColor([ThemeConstants.TEXT_TERTIARY])
        }
      }
      .width(64)
      .height(88)
      .borderRadius(ThemeConstants.RADIUS_COVER)
      .clip(true)
      .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.resultSubtitle(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (item.matchQuality !== undefined) {
          Text(this.matchQualityLabel(item.matchQuality))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.sourceKind === 'webdav') {
        Text(s('search_result_action_read'))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      } else {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .fontColor([ThemeConstants.BRAND_PRIMARY])
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      void this.openResult(item)
    })
  }

  @Builder
  private SectionHeader(title: string) {
    Text(title)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .fontColor(ThemeConstants.TEXT_SECONDARY)
      .padding({ left: 4, right: 4, top: 4, bottom: 2 })
      .width('100%')
  }

  private canContinueSection(section: CrossSearchSection): boolean {
    if (section.state !== 'ready' || section.sourceKind !== 'wasm' || !section.id.startsWith('wasm:')) return false
    const entry = appSourceRuntimeRegistry.lookup(section.id.substring('wasm:'.length)).entry
    return entry !== undefined && entry.enabled && entry.capabilities.includes('search')
  }

  private continuationSource(section: CrossSearchSection): SourceRuntimeRegistryInstalledSourceSummary | undefined {
    if (section.state !== 'ready' || section.sourceKind !== 'wasm' || !section.id.startsWith('wasm:')) {
      return undefined
    }
    const sourceId = section.id.substring('wasm:'.length)
    return appSourceRuntimeRegistry.listInstalledSourceSummaries().find((source: SourceRuntimeRegistryInstalledSourceSummary) => {
      return source.sourceId === sourceId && source.enabled && source.capabilities.includes('search')
    })
  }

  private openSectionResults(section: CrossSearchSection): void {
    const source = this.continuationSource(section)
    if (source !== undefined && this.resultsQuery.length > 0) {
      RouterHelper.pushSourceSearch({ source: source }, this.resultsQuery,
        this.migrationSources === undefined ? undefined : (manga: SourceManga): void => { this.onMangaSelected(manga) })
    }
  }

  @Builder
  private MigrationResults(section: CrossSearchSection) {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_MD }) {
        ForEach(section.items, (item: CrossSearchResultItem) => {
          Column() {
            MangaGridItem({ manga: this.selectionManga(item), reserveTitleSpace: true,
              onMangaTap: (): void => { this.onMangaSelected(this.selectionManga(item)) } })
          }
          .width(ThemeConstants.SOURCE_GRID_MIN_COLUMN_WIDTH)
          .priorityGesture(LongPressGesture({ repeat: false }).onAction((): void => { void this.openResult(item) }))
        }, (item: CrossSearchResultItem) => item.id)
      }
      .alignItems(VerticalAlign.Top)
      .justifyContent(FlexAlign.Start)
      .constraintSize({ minWidth: '100%' })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  private selectionManga(item: CrossSearchResultItem): SourceManga {
    return { id: item.sourceMangaId ?? '', sourceId: item.sourceId ?? '', title: item.title,
      coverUrl: item.coverUri, url: item.sourceMangaUrl }
  }

  @Builder
  private ResultsSectionHeader(section: CrossSearchSection) {
    if (this.canContinueSection(section)) {
      Row() {
        Text(this.sectionTitle(section))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor([ThemeConstants.TEXT_SECONDARY])
      }
      .padding({ left: 4, right: 4, top: 4, bottom: 2 })
      .width('100%')
      .onClick(() => {
        this.openSectionResults(section)
      })
    } else {
      this.SectionHeader(this.sectionTitle(section))
    }
  }

  @Builder
  private SearchResultContent(row: SearchResultRow) {
    if (row.kind === 'header') {
      this.ResultsSectionHeader(row.section)
    } else if (row.kind === 'result') {
      this.ResultRow(row.item!)
    } else if (row.kind === 'migration') {
      this.MigrationResults(row.section)
    } else {
      Column({ space: ThemeConstants.SPACE_SM }) {
        this.SectionHeader(this.sourceSectionTitle(row.section))
        if (row.section.state === 'running' || row.section.state === 'pending') {
          Row({ space: ThemeConstants.SPACE_MD }) {
            LoadingProgress()
              .width(ThemeConstants.SPACE_XL)
              .height(ThemeConstants.SPACE_XL)
              .color(ThemeConstants.BRAND_PRIMARY)
            Text(this.sectionStatusText(row.section))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor(ThemeConstants.CARD)
          .justifyContent(FlexAlign.Center)
        } else {
          Text(this.sectionStatusText(row.section))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .padding(ThemeConstants.SPACE_LG)
            .borderRadius(ThemeConstants.RADIUS_CARD)
            .backgroundColor(ThemeConstants.CARD)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        pinnedOverlayHeight: SEARCH_TITLE_BOTTOM_HEIGHT,
        bottomPadding: ThemeConstants.SPACE_XL,
        floatingTabTailPadding: this.migrationSources === undefined ? ThemeConstants.FLOATING_TAB_BAR_CLEARANCE : 0,
        reserveTitleBar: true,
      }) {
          if (this.migrationSources === undefined && (this.librarySource !== undefined || this.sourceFilter !== 'all')) {
            ListItem() {
              this.ActiveFilterBadge()
            }
          }
          if (this.feedbackText.length > 0) {
            ListItem() {
              Text(this.feedbackText)
                .width('100%')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor(ThemeConstants.DANGER)
                .padding(ThemeConstants.SPACE_LG)
                .borderRadius(ThemeConstants.RADIUS_CARD)
                .backgroundColor(ThemeConstants.CARD)
            }
          }
          if (!this.loading && this.hasMeaningfulSearchQuery() && this.resultRowCount === 0 && this.totalResultCount() === 0 && this.feedbackText.length === 0) {
            ListItem() {
              this.EmptyResults()
            }
          }
          if (!this.loading && !this.hasMeaningfulSearchQuery() && this.feedbackText.length === 0) {
            ListItem() {
              this.HistoryPanel()
            }
          }
          if (this.chrome.resultsOnly && this.loading && this.resultRowCount === 0) {
            ListItem() {
              Row({ space: ThemeConstants.SPACE_MD }) {
                LoadingProgress().width(ThemeConstants.SPACE_XL).height(ThemeConstants.SPACE_XL)
                  .color(ThemeConstants.BRAND_PRIMARY)
                Text(s('search_state_running')).fontSize(ThemeConstants.FONT_SIZE_META)
                  .fontColor(ThemeConstants.TEXT_SECONDARY)
              }.width('100%').padding(ThemeConstants.SPACE_LG)
                .borderRadius(ThemeConstants.RADIUS_CARD).backgroundColor(ThemeConstants.CARD)
            }
          }
          LazyForEach(this.resultRows, (row: SearchResultRow) => {
            ListItem() { this.SearchResultContent(row) }
          }, (row: SearchResultRow): string => row.key)
      }


    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
    .bindSheet($$this.webChallengeShown, this.WebChallengeSheet, komaSheetOptions({
      detents: [SheetSize.LARGE], showClose: false,
      enableOutsideInteractive: false, enableFloatingDragBar: true,
      onWillDismiss: (action: DismissSheetAction) => {
        this.closeWebChallenge()
        action.dismiss()
      },
      onDisappear: () => { this.finishWebChallengeDismiss() },
    }))
  }
}
