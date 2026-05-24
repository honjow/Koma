import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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

const KOMGA_PAGE_SIZE: number = 30

interface KomgaSeriesRouteParam {
  libraryId?: string
}

@Component
export struct KomgaSeriesPage {
  @Prop params: KomgaSeriesRouteParam = {}
  @State private libraries: KomgaLibraryDto[] = []
  @State private selectedLibraryId: string = ''
  @State private series: KomgaSeriesDto[] = []
  @State private selectedSeries: KomgaSeriesDto | undefined = undefined
  @State private books: KomgaBookDto[] = []
  @State private loading: boolean = true
  @State private loadingMore: boolean = false
  @State private errorText: string = ''
  @State private page: number = 0
  @State private hasMore: boolean = true
  @State private favoriteRevision: number = 0
  private record?: KomgaServerRecord
  libraryStore: LibraryStore = createSeededLibraryStore()
  libraryPersistenceService?: LibraryStorePersistenceService
  onLibraryChanged: () => void = () => {}

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
        throw new Error('请先在设置里配置 Komga')
      }
      this.record = saved
      const client = store.createKomgaClient(saved)
      console.info('[Komga] step=load_libraries_start')
      this.libraries = await client.listLibraries()
      this.selectedLibraryId = this.params.libraryId === undefined ? '' : this.params.libraryId
      console.info(`[Komga] step=load_libraries_ok libraries=${this.libraries.length}`)
      await this.reloadSeries()
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      console.error('[Komga] step=load_initial_failed message=' + e.message)
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
      const e = error as Error
      this.errorText = e.message
      console.error('[Komga] step=load_series_failed message=' + e.message)
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
      const e = error as Error
      this.errorText = e.message
      console.error('[Komga] step=load_books_failed message=' + e.message)
    }
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
      const config = createReaderSessionConfigFromComic(comic, chapter.id)
      this.installReaderSession(config, client.getBaseUrl(), this.store().getKomgaImageHeaders(record))
      console.info(`[Komga] step=open_reader book=${book.id} pages=${pages.length}`)
      RouterHelper.pushReader()
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      console.error('[Komga] step=open_book_failed message=' + e.message)
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
      this.showToast('已在书架中')
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
      for (let index = 0; index < bookRows.length; index += 1) {
        const book = bookRows[index]
        const chapterId = `komga:${record.server.id}:book:${book.id}`
        const pageDtos = await client.listBookPages(book.id)
        const pages = pageDtos.map((page: KomgaPageDto) => {
          const mapped = mapKomgaPageToPage(record.server.id, book.id, comicId, chapterId, page)
          mapped.uri = client.getPageImageUrl(book.id, page.number, KomgaPageImageKind.STREAM)
          return mapped
        })
        chapters.push(mapKomgaBookToChapter(record.server.id, book, comicId, pages, index))
      }
      const comic = mapKomgaSeriesToComic(record.server.id, series, chapters)
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast('已加入书架')
      console.info(`[Favorite] step=komga_add_ok chapters=${chapters.length} pages=${comic.pageCount}`)
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      this.showToast('加入书架失败')
      console.error('[Favorite] step=komga_add_failed message=' + e.message)
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
    Column({ space: 10 }) {
      Text('Libraries')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_accent'))
        .width('100%')
      Row({ space: 8 }) {
        Button('全部')
          .height(34)
          .fontSize(13)
          .fontColor(this.selectedLibraryId.length === 0 ? Color.White : $r('app.color.koma_accent'))
          .backgroundColor(this.selectedLibraryId.length === 0 ? $r('app.color.koma_accent') : '#00000000')
          .border({ width: 1, color: $r('app.color.koma_accent') })
          .borderRadius(8)
          .onClick(() => {
            this.selectedLibraryId = ''
            this.reloadSeries()
          })
        ForEach(this.libraries, (library: KomgaLibraryDto) => {
          Button(library.name)
            .height(34)
            .fontSize(13)
            .fontColor(this.selectedLibraryId === library.id ? Color.White : $r('app.color.koma_accent'))
            .backgroundColor(this.selectedLibraryId === library.id ? $r('app.color.koma_accent') : '#00000000')
            .border({ width: 1, color: $r('app.color.koma_accent') })
            .borderRadius(8)
            .onClick(() => {
              this.selectedLibraryId = library.id
              this.reloadSeries()
            })
        }, (library: KomgaLibraryDto) => library.id)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private SeriesRow(item: KomgaSeriesDto) {
    Row({ space: 12 }) {
      Column() {
        Text(this.seriesTitle(item).substring(0, 1).toLocaleUpperCase())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(48)
      .height(64)
      .justifyContent(FlexAlign.Center)
      .borderRadius(8)
      .backgroundColor('#16745F')

      Column({ space: 6 }) {
        Text(this.seriesTitle(item))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${item.booksCount === undefined ? 0 : item.booksCount} books`)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.openSeries(item)
    })
  }

  @Builder
  private BookRow(item: KomgaBookDto) {
    Row({ space: 12 }) {
      Column({ space: 5 }) {
        Text(this.bookTitle(item))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${item.media?.pagesCount === undefined ? 0 : item.media.pagesCount} pages`)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('读')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_accent'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.openBook(item)
    })
  }

  @Builder
  private BooksPanel() {
    if (this.selectedSeries !== undefined) {
      ListItem() {
        Column({ space: 10 }) {
          Text(this.seriesTitle(this.selectedSeries))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .width('100%')
          Button(this.isSelectedSeriesFavorited() ? '已收藏' : '加入书架')
            .height(40)
            .width('100%')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isSelectedSeriesFavorited() ? Color.White : $r('app.color.koma_accent'))
            .backgroundColor(this.isSelectedSeriesFavorited() ? $r('app.color.koma_accent') : '#00000000')
            .border({ width: 1, color: $r('app.color.koma_accent') })
            .borderRadius(8)
            .onClick(() => {
              this.addSelectedSeriesToLibrary()
            })
          if (this.books.length === 0) {
            Text('暂无 books')
              .fontSize(14)
              .fontColor($r('app.color.koma_text_secondary'))
              .width('100%')
              .padding(16)
              .borderRadius(8)
              .backgroundColor($r('app.color.koma_card'))
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
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
        onReachEnd: () => {
          this.loadMoreSeries()
        },
      }) {
        if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress().width(32).height(32).color($r('app.color.koma_accent'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        } else if (this.errorText.length > 0) {
          ListItem() {
            Text(this.errorText)
              .width('100%')
              .padding(16)
              .fontSize(14)
              .fontColor($r('app.color.koma_text_secondary'))
              .borderRadius(8)
              .backgroundColor($r('app.color.koma_card'))
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
                LoadingProgress().width(26).height(26).color($r('app.color.koma_accent'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(12)
            }
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
