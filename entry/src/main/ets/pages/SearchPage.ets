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
import { KomgaSeriesRouteParam } from './KomgaSeriesPage'
import { KavitaBrowseRouteParam } from './KavitaBrowsePage'
import { OpdsBrowseRouteParam } from './OpdsBrowsePage'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  addSearchHistoryEntry,
  removeSearchHistoryEntry,
  SearchHistoryEntry,
  SearchHistoryStore,
} from '../model/SearchHistoryStore'
import { safeSearchDiagnostic, searchStateUserText } from '../model/SearchStateMapper'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'

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
  @Param chrome: SearchRouteChromeState = new SearchRouteChromeState()
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private queryText: string = ''
  @Local private sections: CrossSearchSection[] = []
  @Local private history: SearchHistoryEntry[] = []
  @Local private historyLoadState: SearchHistoryLoadState = SearchHistoryLoadState.LOADING
  @Local private loading: boolean = false
  @Local private feedbackText: string = ''
  @Local private sourceFilter: CrossSearchSourceFilter = 'all'
  @Local private sourceFilterMenuOpen: boolean = false
  @Local private failedCoverUris: string[] = []
  private searchTimer: number = 0
  private searchSerial: number = 0
  private routeEpoch: number = 0
  private routeActive: boolean = false
  private historyMutationEpoch: number = 0
  private historyWriteTail: Promise<void> = Promise.resolve()
  private sourceFilterMutationEpoch: number = 0
  private sourceFilterWriteTail: Promise<void> = Promise.resolve()
  private handledQueryChangeSeq: number = 0
  private handledQuerySubmitSeq: number = 0
  private sourceFilterLoaded: boolean = false
  private service?: CrossSearchService
  private historyStore?: SearchHistoryStore
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onOpenKomgaResult: (param: KomgaSeriesRouteParam) => void = (_param: KomgaSeriesRouteParam) => {}
  @Event onOpenKavitaResult: (param: KavitaBrowseRouteParam) => void = (_param: KavitaBrowseRouteParam) => {}
  @Event onOpenOpdsResult: (param: OpdsBrowseRouteParam) => void = (_param: OpdsBrowseRouteParam) => {}

  aboutToAppear(): void {
    this.routeEpoch += 1
    this.routeActive = true
    this.searchSerial += 1
    this.sourceFilterLoaded = false
    const context = getContext(this) as common.UIAbilityContext
    this.service = new CrossSearchService(context)
    this.historyStore = new SearchHistoryStore(context)
    this.loadHistory()
    this.loadSourceFilter()
    this.consumeChromeQuery()
    console.info('[Search] step=page_appear')
  }

  aboutToReuse(): void {
    this.consumeChromeQuery()
  }

  aboutToDisappear(): void {
    this.routeActive = false
    this.routeEpoch += 1
    this.searchSerial += 1
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  private ownsRoute(routeEpoch: number): boolean {
    return this.routeActive && routeEpoch === this.routeEpoch
  }

  private scheduleSearch(value: string): void {
    const routeEpoch = this.routeEpoch
    if (!this.ownsRoute(routeEpoch)) {
      return
    }
    this.queryText = value
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    const timer = setTimeout(() => {
      if (this.searchTimer === timer) {
        this.searchTimer = 0
      }
      if (!this.ownsRoute(routeEpoch)) {
        return
      }
      void this.runSearch(value)
    }, SEARCH_DEBOUNCE_MS)
    this.searchTimer = timer
  }

  private async runSearch(value: string): Promise<void> {
    const routeEpoch = this.routeEpoch
    if (!this.ownsRoute(routeEpoch)) {
      return
    }
    const query = value.trim()
    this.searchSerial += 1
    const serial = this.searchSerial
    if (query.length === 0 || !isCrossSearchQueryMeaningful(query)) {
      this.sections = []
      this.feedbackText = ''
      this.loading = false
      console.info(query.length === 0 ? '[Search] step=query_cleared' : '[Search] step=query_ignored reason=not_meaningful')
      return
    }
    const service = this.service
    if (service === undefined) {
      return
    }
    const sourceFilter = this.sourceFilter
    this.loading = true
    this.sections = service.pendingSections(sourceFilter)
    this.feedbackText = ''
    this.recordHistory(query)
    console.info(`[Search] step=ui_search_start serial=${serial}`)
    try {
      const result = await service.search(query, sourceFilter)
      if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
        console.info(`[Search] step=ui_search_stale serial=${serial}`)
        return
      }
      this.sections = result
      this.feedbackText = ''
      console.info(`[Search] step=ui_search_done serial=${serial} sections=${result.length}`)
    } catch (error) {
      const e = error as Error
      if (!this.ownsRoute(routeEpoch) || serial !== this.searchSerial) {
        return
      }
      this.sections = []
      const diagnostic = safeSearchDiagnostic(e)
      this.feedbackText = diagnostic.userText
      console.error('[Search] step=ui_search_failed code=' + diagnostic.code)
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
      console.error('[Search] step=history_load_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private recordHistory(query: string): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const store = this.historyStore
    const mutationEpoch = this.historyMutationEpoch + 1
    this.historyMutationEpoch = mutationEpoch
    this.history = addSearchHistoryEntry(this.history, query)
    this.historyLoadState = SearchHistoryLoadState.READY
    if (store === undefined) {
      return
    }
    this.enqueueHistoryMutation(mutationEpoch, 'history_record', () => {
      return store.record(query)
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
      if (this.historyLoadState === SearchHistoryLoadState.LOADING) {
        this.historyLoadState = SearchHistoryLoadState.FAILED
      }
      console.error('[Search] step=' + step + '_failed code=' + safeSearchDiagnostic(error).code)
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
        console.error('[Search] step=source_filter_load_failed code=' + safeSearchDiagnostic(error).code)
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
    this.getUIContext().showAlertDialog({
      title: s('search_history_clear_title'),
      message: s('search_history_clear_message').replace('%s', `${this.history.length}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearHistory()
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private removeHistoryEntry(query: string): void {
    if (!this.ownsRoute(this.routeEpoch)) {
      return
    }
    const store = this.historyStore
    const mutationEpoch = this.historyMutationEpoch + 1
    this.historyMutationEpoch = mutationEpoch
    this.history = removeSearchHistoryEntry(this.history, query)
    this.historyLoadState = SearchHistoryLoadState.READY
    if (store === undefined) {
      return
    }
    this.enqueueHistoryMutation(mutationEpoch, 'history_remove', () => {
      return store.remove(query)
    })
  }

  private runHistoryQuery(query: string): void {
    this.chrome.submitQuery(query)
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
    this.sourceFilterMenuOpen = true
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
    this.sourceFilterMenuOpen = false
    this.saveSourceFilter(sourceFilter, mutationEpoch)
    if (changed && this.queryText.trim().length > 0) {
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
    void queued.catch((error: Error) => {
      if (mutationEpoch !== this.sourceFilterMutationEpoch) {
        return
      }
      console.error('[Search] step=source_filter_save_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private async openResult(item: CrossSearchResultItem): Promise<void> {
    console.info(`[Search] step=open_result kind=${item.sourceKind}`)
    if (item.sourceKind === 'local' && item.localComicId !== undefined) {
      RouterHelper.pushMangaDetail({ mangaId: item.localComicId })
      return
    }
    if (item.sourceKind === 'wasm' && item.sourceId !== undefined && item.sourceMangaId !== undefined) {
      RouterHelper.pushMangaDetail({ mangaId: item.sourceMangaId, sourceId: item.sourceId })
      return
    }
    if (item.sourceKind === 'komga') {
      const param: KomgaSeriesRouteParam = {
        seriesId: item.komgaSeriesId,
        seriesTitle: item.title,
      }
      this.onOpenKomgaResult(param)
      return
    }
    if (item.sourceKind === 'kavita') {
      const param: KavitaBrowseRouteParam = {
        libraryId: item.kavitaLibraryId,
        seriesId: item.kavitaSeriesId,
        seriesTitle: item.title,
      }
      this.onOpenKavitaResult(param)
      return
    }
    if (item.sourceKind === 'opds') {
      const param: OpdsBrowseRouteParam = {
        feedUrl: item.opdsFeedUrl,
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
        await service.openWebDavReader(item)
        RouterHelper.pushReader()
      } catch (error) {
        const e = error as Error
        const diagnostic = safeSearchDiagnostic(e)
        this.feedbackText = diagnostic.userText
        console.error('[Search] step=open_webdav_failed code=' + diagnostic.code)
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

  private sectionTitle(section: CrossSearchSection): string {
    return section.resultCount === 0 ? section.title : `${section.title} · ${section.resultCount}`
  }

  private sourceFilterLabel(): string {
    if (this.sourceFilter === 'local') {
      return s('search_filter_local')
    }
    if (this.sourceFilter === 'private') {
      return s('search_filter_private')
    }
    if (this.sourceFilter === 'source') {
      return s('search_filter_source')
    }
    return s('search_filter_all')
  }

  private hasMeaningfulSearchQuery(): boolean {
    return isCrossSearchQueryMeaningful(this.queryText)
  }

  @Builder
  private SourceFilterMenu() {
    Menu() {
      MenuItem({ content: s('search_filter_all') })
        .onClick(() => {
          this.setSourceFilter('all')
        })
      MenuItem({ content: s('search_filter_local') })
        .onClick(() => {
          this.setSourceFilter('local')
        })
      MenuItem({ content: s('search_filter_private') })
        .onClick(() => {
          this.setSourceFilter('private')
        })
        MenuItem({ content: s('search_filter_source') })
          .onClick(() => {
            this.setSourceFilter('source')
          })
      }
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
                Text(entry.query)
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
                this.runHistoryQuery(entry.query)
              })
              .gesture(
                LongPressGesture({ repeat: false, duration: 500 })
                  .onAction(() => {
                    this.removeHistoryEntry(entry.query)
                  })
              )
            }, (entry: SearchHistoryEntry) => `${entry.query}:${entry.updatedAt}`)
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
      this.setSourceFilter('all')
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

  private shouldShowCoverUri(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId)) < 0
  }

  private markCoverUriFailed(coverUri: string | undefined, sourceRuntimeId?: string, sourceImageId?: string): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId)
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
        if (this.shouldShowCoverUri(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id)) {
          if (this.isSourceAwareCover(item)) {
            CachedCoverImage({
              uri: item.coverUri ?? '',
              objectFit: ImageFit.Cover,
              sourceRuntimeId: item.sourceId ?? '',
              sourceImageId: item.sourceMangaId ?? item.id,
              onError: () => {
                this.markCoverUriFailed(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id)
              },
            })
          } else {
            Image(item.coverUri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .interpolation(ImageInterpolation.Medium)
              .onError(() => {
                this.markCoverUriFailed(item.coverUri, item.sourceId, item.sourceMangaId ?? item.id)
              })
          }
        } else {
          SymbolGlyph($r('sys.symbol.book'))
            .fontSize(ThemeConstants.FONT_SIZE_H2)
            .fontColor([ThemeConstants.TEXT_TERTIARY])
        }
      }
      .width(ThemeConstants.LIST_COVER_WIDTH)
      .height(ThemeConstants.LIST_COVER_HEIGHT)
      .borderRadius(ThemeConstants.RADIUS_THUMB)
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
        Text(item.subtitle.length === 0 ? item.sourceLabel : item.subtitle)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.matchQualityLabel(item.matchQuality))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
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
    .padding(ThemeConstants.SPACE_LG)
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

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
        reserveTitleBar: true,
      }) {
          ListItem() {
            Column() {
              Blank().height(SEARCH_TITLE_BOTTOM_HEIGHT)
            }
            .width('100%')
          }
          if (this.sourceFilter !== 'all') {
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
          if (!this.loading && this.queryText.trim().length > 0 && this.sections.length === 0 && this.totalResultCount() === 0 && this.feedbackText.length === 0) {
            ListItem() {
              this.EmptyResults()
            }
          }
          if (!this.loading && this.queryText.trim().length === 0 && this.feedbackText.length === 0) {
            ListItem() {
              this.HistoryPanel()
            }
          }
          ForEach(this.sections, (section: CrossSearchSection) => {
            if (section.state === 'running' || section.state === 'pending') {
              ListItem() {
                Column({ space: ThemeConstants.SPACE_SM }) {
                  this.SectionHeader(section.title)
                  Row({ space: ThemeConstants.SPACE_MD }) {
                    LoadingProgress()
                      .width(ThemeConstants.SPACE_XL)
                      .height(ThemeConstants.SPACE_XL)
                      .color(ThemeConstants.BRAND_PRIMARY)
                    Text(this.sectionStatusText(section))
                      .fontSize(ThemeConstants.FONT_SIZE_META)
                      .fontColor(ThemeConstants.TEXT_SECONDARY)
                  }
                  .width('100%')
                  .padding(ThemeConstants.SPACE_LG)
                  .borderRadius(ThemeConstants.RADIUS_CARD)
                  .backgroundColor(ThemeConstants.CARD)
                  .justifyContent(FlexAlign.Center)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            } else if (section.state === 'empty' || section.state === 'timeout' || section.state === 'failed' || section.state === 'unsupported') {
              ListItem() {
                Column({ space: ThemeConstants.SPACE_SM }) {
                  this.SectionHeader(section.title)
                  Text(this.sectionStatusText(section))
                    .width('100%')
                    .fontSize(ThemeConstants.FONT_SIZE_META)
                    .fontColor(ThemeConstants.TEXT_SECONDARY)
                    .padding(ThemeConstants.SPACE_LG)
                    .borderRadius(ThemeConstants.RADIUS_CARD)
                    .backgroundColor(ThemeConstants.CARD)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            } else if (section.state === 'ready' && section.items.length > 0) {
              ListItem() {
                this.SectionHeader(this.sectionTitle(section))
              }
              ForEach(section.items, (item: CrossSearchResultItem) => {
                ListItem() {
                  this.ResultRow(item)
                }
              }, (item: CrossSearchResultItem) => item.id)
            }
          }, (section: CrossSearchSection) => section.id)
      }

      Row()
        .width(1)
        .height(1)
        .margin({ top: ThemeConstants.TITLE_BAR_HEIGHT, right: ThemeConstants.SPACE_MD })
        .hitTestBehavior(HitTestMode.None)
        .bindMenu(this.sourceFilterMenuOpen, this.SourceFilterMenu(), {
          placement: Placement.BottomRight,
          onDisappear: () => {
            this.sourceFilterMenuOpen = false
          },
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
