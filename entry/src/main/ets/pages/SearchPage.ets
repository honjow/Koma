import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import {
  CrossSearchResultItem,
  CrossSearchSection,
  CrossSearchService,
} from '../model/CrossSearchService'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomgaSeriesPage } from './KomgaSeriesPage'
import { OpdsBrowsePage } from './OpdsBrowsePage'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { SearchHistoryEntry, SearchHistoryStore } from '../model/SearchHistoryStore'
import { safeSearchDiagnostic, searchStateUserText } from '../model/SearchStateMapper'

const SEARCH_DEBOUNCE_MS: number = 400
const KOMGA_ROUTE_NAME: string = 'SearchKomgaSeriesPage'
const OPDS_ROUTE_NAME: string = 'SearchOpdsBrowsePage'

@ComponentV2
export struct SearchPage {
  @Local private queryText: string = ''
  @Local private sections: CrossSearchSection[] = []
  @Local private history: SearchHistoryEntry[] = []
  @Local private loading: boolean = false
  @Local private feedbackText: string = ''
  private searchTimer: number = 0
  private searchSerial: number = 0
  private service?: CrossSearchService
  private historyStore?: SearchHistoryStore
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  private searchPathStack: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext
    this.service = new CrossSearchService(context)
    this.historyStore = new SearchHistoryStore(context)
    this.loadHistory()
    console.info('[Search] step=page_appear')
  }

  aboutToDisappear(): void {
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
  }

  private scheduleSearch(value: string): void {
    this.queryText = value
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    this.searchTimer = setTimeout(() => {
      this.searchTimer = 0
      void this.runSearch(this.queryText)
    }, SEARCH_DEBOUNCE_MS)
  }

  private async runSearch(value: string): Promise<void> {
    const query = value.trim()
    this.searchSerial += 1
    const serial = this.searchSerial
    if (query.length === 0) {
      this.sections = []
      this.feedbackText = ''
      this.loading = false
      console.info('[Search] step=query_cleared')
      return
    }
    const service = this.service
    if (service === undefined) {
      return
    }
    this.loading = true
    this.sections = service.pendingSections()
    this.feedbackText = ''
    this.recordHistory(query)
    console.info(`[Search] step=ui_search_start serial=${serial}`)
    try {
      const result = await service.search(query)
      if (serial !== this.searchSerial) {
        console.info(`[Search] step=ui_search_stale serial=${serial}`)
        return
      }
      this.sections = result
      this.feedbackText = ''
      console.info(`[Search] step=ui_search_done serial=${serial} sections=${result.length}`)
    } catch (error) {
      const e = error as Error
      if (serial !== this.searchSerial) {
        return
      }
      this.sections = []
      const diagnostic = safeSearchDiagnostic(e)
      this.feedbackText = diagnostic.userText
      console.error('[Search] step=ui_search_failed code=' + diagnostic.code)
    } finally {
      if (serial === this.searchSerial) {
        this.loading = false
      }
    }
  }

  private loadHistory(): void {
    const store = this.historyStore
    if (store === undefined) {
      return
    }
    void store.load().then((entries: SearchHistoryEntry[]) => {
      this.history = entries
    }).catch((error: Error) => {
      console.error('[Search] step=history_load_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private recordHistory(query: string): void {
    const store = this.historyStore
    if (store === undefined) {
      return
    }
    void store.record(query).then((entries: SearchHistoryEntry[]) => {
      this.history = entries
    }).catch((error: Error) => {
      console.error('[Search] step=history_record_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private clearHistory(): void {
    const store = this.historyStore
    this.history = []
    if (store === undefined) {
      return
    }
    void store.clear().catch((error: Error) => {
      console.error('[Search] step=history_clear_failed code=' + safeSearchDiagnostic(error).code)
    })
  }

  private runHistoryQuery(query: string): void {
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer)
      this.searchTimer = 0
    }
    this.queryText = query
    void this.runSearch(query)
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
      this.searchPathStack.pushPath({ name: KOMGA_ROUTE_NAME })
      return
    }
    if (item.sourceKind === 'opds') {
      this.searchPathStack.pushPath({ name: OPDS_ROUTE_NAME })
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

  private badgeText(item: CrossSearchResultItem): string {
    if (item.sourceKind === 'local') {
      return 'L'
    }
    if (item.sourceKind === 'komga') {
      return 'K'
    }
    if (item.sourceKind === 'opds') {
      return 'O'
    }
    if (item.sourceKind === 'webdav') {
      return 'W'
    }
    return 'S'
  }

  private badgeColor(item: CrossSearchResultItem): string {
    if (item.sourceKind === 'local') {
      return ThemeConstants.SOURCE_LOCAL_COLOR
    }
    if (item.sourceKind === 'komga') {
      return ThemeConstants.SOURCE_KOMGA_COLOR
    }
    if (item.sourceKind === 'opds') {
      return ThemeConstants.SOURCE_OPDS_COLOR
    }
    if (item.sourceKind === 'webdav') {
      return ThemeConstants.SOURCE_WEBDAV_COLOR
    }
    return ThemeConstants.SOURCE_WASM_COLOR
  }

  @Builder
  private SearchInput() {
    Search({ value: this.queryText, placeholder: '搜索标题、作者、标签...' })
      .width('100%')
      .height(ThemeConstants.BUTTON_HEIGHT)
      .backgroundColor(ThemeConstants.CARD)
      .placeholderColor(ThemeConstants.TEXT_SECONDARY)
      .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
      .onChange((value: string) => {
        this.scheduleSearch(value)
      })
      .onSubmit((value: string) => {
        this.scheduleSearch(value)
      })
  }

  @Builder
  private EmptyResults() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(this.queryText.trim().length === 0 ? '输入关键词开始搜索' : '没有匹配结果')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(this.queryText.trim().length === 0 ? '会同时搜索书架、私有库和已安装源。' : '换个关键词再试。')
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
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text('最近搜索')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .layoutWeight(1)
        if (this.history.length > 0) {
          KomaActionButton({
            label: '清除',
            kind: 'ghost',
            compact: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.clearHistory()
            },
          })
        }
      }
      .width('100%')

      if (this.history.length === 0) {
        Text('暂无搜索历史')
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor(ThemeConstants.CARD)
          .textAlign(TextAlign.Center)
      } else {
        ForEach(this.history, (entry: SearchHistoryEntry) => {
          Row() {
            Column({ space: ThemeConstants.SPACE_XS }) {
              Text(entry.query)
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeConstants.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(this.formatHistoryTime(entry.updatedAt))
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor(ThemeConstants.TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontColor([ThemeConstants.BRAND_PRIMARY])
          }
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor(ThemeConstants.CARD)
          .onClick(() => {
            this.runHistoryQuery(entry.query)
          })
        }, (entry: SearchHistoryEntry) => `${entry.query}:${entry.updatedAt}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
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

  @Builder
  private ResultRow(item: CrossSearchResultItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        if (item.coverUri !== undefined && item.coverUri.length > 0) {
          Image(item.coverUri)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Text(this.badgeText(item))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
        }
      }
      .width(ThemeConstants.LIST_COVER_WIDTH)
      .height(ThemeConstants.LIST_COVER_HEIGHT)
      .borderRadius(ThemeConstants.RADIUS_THUMB)
      .clip(true)
      .backgroundColor(this.badgeColor(item))

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
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(item.sourceKind === 'webdav' ? '读' : '>')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
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

  @Builder
  private SearchDestination(name: string, _param: Object) {
    if (name === KOMGA_ROUTE_NAME) {
      NavDestination() {
        KomgaSeriesPage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.libraryPersistenceService,
          onLibraryChanged: () => {
            this.onLibraryChanged()
          }
        })
      }
      .title('Komga')
    } else if (name === OPDS_ROUTE_NAME) {
      NavDestination() {
        OpdsBrowsePage({
          libraryStore: this.libraryStore,
          libraryPersistenceService: this.libraryPersistenceService,
          onLibraryChanged: () => {
            this.onLibraryChanged()
          }
        })
      }
      .title('OPDS')
    }
  }

  build() {
    Navigation(this.searchPathStack) {
      Column() {
        SecondaryListScaffold({
          listSpace: ThemeConstants.SPACE_MD,
          horizontalPadding: ThemeConstants.SPACE_XL,
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
        }) {
          ListItem() {
            this.SearchInput()
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
    .navDestination(this.SearchDestination)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
  }
}
