import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { Chapter, Comic } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { MOCK_LIBRARY_READER_SESSION } from '../model/MockLibraryData'
import { installReaderRemoteHeaders } from '../model/ReaderPageSourceAdapter'
import { ReaderSessionConfig, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { RemoteServerStore, KomgaServerRecord } from '../model/RemoteServerStore'
import { KomgaClient, KomgaHeaders } from '../remote/KomgaClient'
import {
  KomgaBookDto,
  KomgaLibraryDto,
  KomgaPageDto,
  KomgaPageImageKind,
  KomgaSeriesDto,
  createKomgaComicId,
  mapKomgaBookToChapter,
  mapKomgaPageToPage,
  mapKomgaSeriesToComic,
} from '../remote/KomgaModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

const KOMGA_PAGE_SIZE: number = 30

interface KomgaSeriesRouteParam {
  libraryId?: string
  seriesId?: string
  seriesTitle?: string
}

@ComponentV2
export struct KomgaSeriesPage {
  @Param params: KomgaSeriesRouteParam = {}
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private libraries: KomgaLibraryDto[] = []
  @Local private selectedLibraryId: string = ''
  @Local private series: KomgaSeriesDto[] = []
  @Local private selectedSeries: KomgaSeriesDto | undefined = undefined
  @Local private books: KomgaBookDto[] = []
  @Local private loading: boolean = true
  @Local private loadingMore: boolean = false
  @Local private errorText: string = ''
  @Local private page: number = 0
  @Local private hasMore: boolean = true
  @Local private favoriteRevision: number = 0
  private record?: KomgaServerRecord
  private initialSeriesOpened: boolean = false
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  private client(): KomgaClient | undefined {
    if (this.record === undefined) {
      return undefined
    }
    return this.store().createKomgaClient(this.record)
  }

  aboutToAppear(): void {
    this.loadInitial()
  }

  private async loadInitial(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const store = this.store()
      const saved = await store.loadKomga()
      if (saved === undefined) {
        this.errorText = s('komga_config_required')
        return
      }
      this.record = saved
      const client = store.createKomgaClient(saved)
      console.info('[Komga] step=load_libraries_start')
      this.libraries = await client.listLibraries()
      this.selectedLibraryId = this.params.libraryId === undefined ? '' : this.params.libraryId
      console.info(`[Komga] step=load_libraries_ok libraries=${this.libraries.length}`)
      await this.reloadSeries()
      await this.openInitialSeriesIfNeeded()
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[Komga] step=load_initial_failed code=komga_initial_load_failed')
    } finally {
      this.loading = false
    }
  }

  private async reloadSeries(): Promise<void> {
    this.page = 0
    this.hasMore = true
    this.series = []
    this.selectedSeries = undefined
    this.books = []
    this.initialSeriesOpened = false
    await this.loadMoreSeries()
  }

  private async loadMoreSeries(): Promise<void> {
    if (this.loadingMore || !this.hasMore) {
      return
    }
    const client = this.client()
    if (client === undefined) {
      return
    }
    this.loadingMore = true
    try {
      console.info(`[Komga] step=load_series_start page=${this.page}`)
      const libraryIds = this.selectedLibraryId.length === 0 ? undefined : [this.selectedLibraryId]
      const response = await client.listSeries({
        page: this.page,
        size: KOMGA_PAGE_SIZE,
        libraryIds,
        sort: ['metadata.titleSort,asc'],
      })
      this.series = this.series.concat(response.content)
      this.hasMore = response.last === undefined ? response.content.length >= KOMGA_PAGE_SIZE : !response.last
      this.page += 1
      console.info(`[Komga] step=load_series_ok count=${response.content.length} total=${this.series.length}`)
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[Komga] step=load_series_failed code=komga_series_load_failed')
    } finally {
      this.loadingMore = false
    }
  }

  private async openSeries(series: KomgaSeriesDto): Promise<void> {
    const client = this.client()
    if (client === undefined) {
      return
    }
    this.selectedSeries = series
    this.books = []
    this.errorText = ''
    try {
      console.info(`[Komga] step=load_books_start series=${series.id}`)
      const response = await client.listBooks({
        page: 0,
        size: 100,
        seriesIds: [series.id],
        sort: ['metadata.numberSort,asc'],
      })
      this.books = response.content.filter((book: KomgaBookDto) => book.seriesId === series.id)
      console.info(`[Komga] step=load_books_ok books=${this.books.length}`)
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[Komga] step=load_books_failed code=komga_books_load_failed')
    }
  }

  private async openInitialSeriesIfNeeded(): Promise<void> {
    if (this.initialSeriesOpened) {
      return
    }
    const seriesId = this.params.seriesId
    if (seriesId === undefined || seriesId.length === 0) {
      return
    }
    this.initialSeriesOpened = true
    const loaded = this.series.find((item: KomgaSeriesDto): boolean => item.id === seriesId)
    if (loaded !== undefined) {
      await this.openSeries(loaded)
      return
    }
    await this.openSeries({
      id: seriesId,
      name: this.params.seriesTitle === undefined || this.params.seriesTitle.length === 0 ? seriesId : this.params.seriesTitle,
    } as KomgaSeriesDto)
  }

  private async openBook(book: KomgaBookDto): Promise<void> {
    const client = this.client()
    const record = this.record
    const series = this.selectedSeries
    if (client === undefined || record === undefined || series === undefined) {
      return
    }
    try {
      console.info(`[Komga] step=load_pages_start book=${book.id}`)
      const pageDtos = await client.listBookPages(book.id)
      const comicId = createKomgaComicId(record.server.id, series.id)
      const chapterId = `komga:${record.server.id}:book:${book.id}`
      const pages = pageDtos.map((page: KomgaPageDto) => {
        const mapped = mapKomgaPageToPage(record.server.id, book.id, comicId, chapterId, page)
        mapped.uri = client.getPageImageUrl(book.id, page.number, KomgaPageImageKind.STREAM)
        return mapped
      })
      const chapter: Chapter = mapKomgaBookToChapter(record.server.id, book, comicId, pages, 0)
      const comic: Comic = mapKomgaSeriesToComic(record.server.id, series, [chapter])
      const firstPage = pageDtos[0]
      if (firstPage !== undefined) {
        comic.coverUri = client.getPageImageUrl(book.id, firstPage.number, KomgaPageImageKind.THUMBNAIL)
      }
      const config = createReaderSessionConfigFromComic(comic, chapter.id)
      this.installReaderSession(config, client.getBaseUrl(), this.store().getKomgaImageHeaders(record))
      console.info(`[Komga] step=open_reader book=${book.id} pages=${pages.length}`)
      RouterHelper.pushReader()
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[Komga] step=open_book_failed code=komga_book_open_failed')
    }
  }

  private isSelectedSeriesFavorited(): boolean {
    const record = this.record
    const series = this.selectedSeries
    if (record === undefined || series === undefined || this.favoriteRevision < 0) {
      return false
    }
    return this.libraryStore.findByRemote(record.server.id, series.id) !== undefined
  }

  private async addSelectedSeriesToLibrary(): Promise<void> {
    const client = this.client()
    const record = this.record
    const series = this.selectedSeries
    if (client === undefined || record === undefined || series === undefined) {
      return
    }
    if (this.libraryStore.findByRemote(record.server.id, series.id) !== undefined) {
      this.showToast(s('common_already_in_library'))
      return
    }
    try {
      console.info(`[Favorite] step=komga_add_start server=${record.server.id} resource=${series.id}`)
      let bookRows = this.books
      if (bookRows.length === 0) {
        const response = await client.listBooks({
          page: 0,
          size: 100,
          seriesIds: [series.id],
          sort: ['metadata.numberSort,asc'],
        })
        bookRows = response.content.filter((book: KomgaBookDto) => book.seriesId === series.id)
        this.books = bookRows
      }
      const comicId = createKomgaComicId(record.server.id, series.id)
      const chapters: Chapter[] = []
      let coverUri: string | undefined = undefined
      for (let index = 0; index < bookRows.length; index += 1) {
        const book = bookRows[index]
        const chapterId = `komga:${record.server.id}:book:${book.id}`
        const pageDtos = await client.listBookPages(book.id)
        if (coverUri === undefined && pageDtos.length > 0) {
          coverUri = client.getPageImageUrl(book.id, pageDtos[0].number, KomgaPageImageKind.THUMBNAIL)
        }
        const pages = pageDtos.map((page: KomgaPageDto) => {
          const mapped = mapKomgaPageToPage(record.server.id, book.id, comicId, chapterId, page)
          mapped.uri = client.getPageImageUrl(book.id, page.number, KomgaPageImageKind.STREAM)
          return mapped
        })
        chapters.push(mapKomgaBookToChapter(record.server.id, book, comicId, pages, index))
      }
      const comic = mapKomgaSeriesToComic(record.server.id, series, chapters)
      comic.coverUri = coverUri
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast(s('common_added_to_library'))
      console.info(`[Favorite] step=komga_add_ok chapters=${chapters.length} pages=${comic.pageCount}`)
    } catch (error) {
      void error
      this.errorText = s('common_add_to_library_failed')
      this.showToast(s('common_add_to_library_failed'))
      console.error('[Favorite] step=komga_add_failed code=komga_add_failed')
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private installReaderSession(config: ReaderSessionConfig, urlPrefix: string, headers: KomgaHeaders): void {
    MOCK_LIBRARY_READER_SESSION.comicId = config.comicId
    MOCK_LIBRARY_READER_SESSION.chapterId = config.chapterId
    MOCK_LIBRARY_READER_SESSION.title = config.title
    MOCK_LIBRARY_READER_SESSION.chapterTitle = config.chapterTitle
    MOCK_LIBRARY_READER_SESSION.totalPages = config.totalPages
    MOCK_LIBRARY_READER_SESSION.pageUris = config.pageUris
    MOCK_LIBRARY_READER_SESSION.pageIds = config.pageIds
    MOCK_LIBRARY_READER_SESSION.pageWidths = config.pageWidths
    MOCK_LIBRARY_READER_SESSION.pageHeights = config.pageHeights
    installReaderRemoteHeaders(urlPrefix, headers)
  }

  private seriesTitle(item: KomgaSeriesDto): string {
    if (item.metadata?.title !== undefined && item.metadata.title.length > 0) {
      return item.metadata.title
    }
    return item.name
  }

  private bookTitle(item: KomgaBookDto): string {
    if (item.metadata?.title !== undefined && item.metadata.title.length > 0) {
      return item.metadata.title
    }
    return item.name
  }

  @Builder
  private LibraryFilter() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(s('komga_section_libraries'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        KomaActionButton({
          label: s('common_all'),
          kind: this.selectedLibraryId.length === 0 ? 'primary' : 'ghost',
          compact: true,
          controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
          action: () => {
            this.selectedLibraryId = ''
            this.reloadSeries()
          },
        })
          .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        ForEach(this.libraries, (library: KomgaLibraryDto) => {
          KomaActionButton({
            label: library.name,
            kind: this.selectedLibraryId === library.id ? 'primary' : 'ghost',
            compact: true,
            controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
            action: () => {
              this.selectedLibraryId = library.id
              this.reloadSeries()
            },
          })
            .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
        }, (library: KomgaLibraryDto) => library.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private SeriesRow(item: KomgaSeriesDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column() {
        Text(this.seriesTitle(item).substring(0, 1).toLocaleUpperCase())
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.LIST_COVER_WIDTH)
      .height(ThemeConstants.LIST_COVER_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .borderRadius(ThemeConstants.RADIUS_THUMB)
      .backgroundColor(ThemeConstants.BRAND_PRIMARY)

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(this.seriesTitle(item))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(s('komga_books_count').replace('%s', `${item.booksCount === undefined ? 0 : item.booksCount}`))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openSeries(item)
    })
  }

  @Builder
  private BookRow(item: KomgaBookDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.bookTitle(item))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(s('komga_pages_count').replace('%s', `${item.media?.pagesCount === undefined ? 0 : item.media.pagesCount}`))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(s('common_read'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openBook(item)
    })
  }

  @Builder
  private BooksPanel() {
    if (this.selectedSeries !== undefined) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text(this.seriesTitle(this.selectedSeries))
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .width('100%')
          KomaActionButton({
            label: this.isSelectedSeriesFavorited() ? s('common_in_library') : s('common_add_to_library'),
            kind: this.isSelectedSeriesFavorited() ? 'primary' : 'secondary',
            action: () => {
              this.addSelectedSeriesToLibrary()
            },
          })
            .width('100%')
          if (this.books.length === 0) {
            Text(s('komga_books_empty'))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .width('100%')
              .padding(ThemeConstants.SPACE_LG)
              .borderRadius(ThemeConstants.RADIUS_CARD)
              .backgroundColor(ThemeConstants.CARD)
          } else {
            ForEach(this.books, (book: KomgaBookDto) => {
              this.BookRow(book)
            }, (book: KomgaBookDto) => book.id)
          }
        }
        .width('100%')
      }
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        onReachEnd: () => {
          this.loadMoreSeries()
        },
      }) {
        if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(ThemeConstants.SPACE_XXL)
                .height(ThemeConstants.SPACE_XXL)
                .color(ThemeConstants.BRAND_PRIMARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        } else if (this.errorText.length > 0) {
          ListItem() {
            Text(this.errorText)
              .width('100%')
              .padding(ThemeConstants.SPACE_LG)
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .borderRadius(ThemeConstants.RADIUS_CARD)
              .backgroundColor(ThemeConstants.CARD)
          }
        } else {
          ListItem() {
            this.LibraryFilter()
          }
          this.BooksPanel()
          ForEach(this.series, (item: KomgaSeriesDto) => {
            ListItem() {
              this.SeriesRow(item)
            }
          }, (item: KomgaSeriesDto) => item.id)
          if (this.loadingMore) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(ThemeConstants.SPACE_XL)
                  .height(ThemeConstants.SPACE_XL)
                  .color(ThemeConstants.BRAND_PRIMARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(ThemeConstants.SPACE_MD)
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
