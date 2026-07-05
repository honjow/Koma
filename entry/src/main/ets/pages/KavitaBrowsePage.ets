import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { RemoteServerStore, KavitaServerRecord } from '../model/RemoteServerStore'
import {
  createKavitaChapterId,
  createKavitaComicId,
  KavitaChapterDto,
  KavitaChapterInfoDto,
  KavitaFileDimensionDto,
  KavitaLibraryDto,
  KavitaSeriesDto,
  KavitaVolumeDto,
  mapKavitaChapterToChapter,
  mapKavitaPageToPage,
  mapKavitaSeriesToComic,
} from '../remote/KavitaModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  Chapter,
  Comic,
  Page,
} from '../model/ComicModels'

function s(name: string): string {
  return AppStrings.get(name)
}

const KAVITA_SERIES_PAGE_SIZE: number = 50

export interface KavitaBrowseRouteParam {
  libraryId?: number
  seriesId?: string
  seriesTitle?: string
}

@ComponentV2
export struct KavitaBrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private libraries: KavitaLibraryDto[] = []
  @Local private selectedLibrary: KavitaLibraryDto | undefined = undefined
  @Local private selectedSeries: KavitaSeriesDto | undefined = undefined
  @Local private series: KavitaSeriesDto[] = []
  @Local private volumes: KavitaVolumeDto[] = []
  @Local private loading: boolean = true
  @Local private seriesLoading: boolean = false
  @Local private seriesLoadingMore: boolean = false
  @Local private seriesHasMore: boolean = false
  @Local private seriesPage: number = 1
  @Local private volumesLoading: boolean = false
  @Local private errorKey: string = ''
  @Local private seriesErrorKey: string = ''
  @Local private volumesErrorKey: string = ''
  @Local private openingChapterId: string = ''
  @Local private addingSelectedSeries: boolean = false
  @Local private favoriteRevision: number = 0
  private autoOpenedRouteKey: string = ''
  @Param params: KavitaBrowseRouteParam = {}
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onOpenReader: (comicId: string, chapterId?: string) => void = () => {}
  private record?: KavitaServerRecord

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadLibraries()
  }

  private async loadLibraries(): Promise<void> {
    this.loading = true
    this.errorKey = ''
    try {
      const store = this.store()
      const saved = await store.loadKavita()
      if (saved === undefined) {
        this.errorKey = 'kavita_browse_not_configured'
        this.libraries = []
        return
      }
      this.record = saved
      console.info('[Kavita] step=load_libraries_start')
      this.libraries = await store.createKavitaClient(saved).listLibraries()
      await this.openRouteParamTarget()
      console.info(`[Kavita] step=load_libraries_ok libraries=${this.libraries.length}`)
    } catch (error) {
      void error
      this.errorKey = 'kavita_browse_load_failed'
      this.libraries = []
      console.error('[Kavita] step=load_libraries_failed code=kavita_libraries_load_failed')
    } finally {
      this.loading = false
    }
  }

  private routeParamKey(): string {
    const libraryId = this.params.libraryId
    const seriesId = this.params.seriesId
    if (libraryId === undefined || seriesId === undefined || seriesId.trim().length === 0) {
      return ''
    }
    return `${libraryId}:${seriesId.trim()}`
  }

  private async openRouteParamTarget(): Promise<void> {
    const key = this.routeParamKey()
    if (key.length === 0 || this.autoOpenedRouteKey === key) {
      return
    }
    const libraryId = this.params.libraryId as number
    const seriesId = Number.parseInt(this.params.seriesId as string, 10)
    if (!Number.isFinite(seriesId) || seriesId <= 0) {
      return
    }
    const library = this.libraries.find((item: KavitaLibraryDto): boolean => item.id === libraryId)
    if (library === undefined) {
      return
    }
    this.autoOpenedRouteKey = key
    await this.openLibrary(library)
    const series = this.series.find((item: KavitaSeriesDto): boolean => item.id === seriesId)
    if (series !== undefined) {
      await this.openSeries(series)
    }
  }

  private async openLibrary(item: KavitaLibraryDto): Promise<void> {
    if (this.record === undefined || this.seriesLoading) {
      return
    }
    this.selectedLibrary = item
    this.series = []
    this.seriesErrorKey = ''
    this.seriesPage = 1
    this.seriesHasMore = false
    this.seriesLoading = true
    try {
      console.info(`[Kavita] step=load_series_start library=${item.id}`)
      const record = this.record
      if (record === undefined) {
        return
      }
      const rows = await this.store().createKavitaClient(record).listSeries(item.id, 1, KAVITA_SERIES_PAGE_SIZE)
      this.series = rows
      this.seriesHasMore = rows.length >= KAVITA_SERIES_PAGE_SIZE
      console.info(`[Kavita] step=load_series_ok library=${item.id} series=${this.series.length}`)
    } catch (error) {
      void error
      this.seriesErrorKey = 'kavita_series_load_failed'
      this.series = []
      console.error('[Kavita] step=load_series_failed code=kavita_series_load_failed')
    } finally {
      this.seriesLoading = false
    }
  }

  private backToLibraries(): void {
    this.selectedLibrary = undefined
    this.selectedSeries = undefined
    this.series = []
    this.volumes = []
    this.seriesPage = 1
    this.seriesHasMore = false
    this.seriesLoadingMore = false
    this.seriesErrorKey = ''
    this.volumesErrorKey = ''
  }

  private appendUniqueSeries(current: KavitaSeriesDto[], next: KavitaSeriesDto[]): KavitaSeriesDto[] {
    const merged = current.slice()
    next.forEach((item: KavitaSeriesDto) => {
      if (merged.find((series: KavitaSeriesDto): boolean => series.id === item.id) === undefined) {
        merged.push(item)
      }
    })
    return merged
  }

  private async loadMoreSeries(): Promise<void> {
    const record = this.record
    const library = this.selectedLibrary
    if (record === undefined || library === undefined || this.seriesLoading || this.seriesLoadingMore || !this.seriesHasMore) {
      return
    }
    const nextPage = this.seriesPage + 1
    this.seriesLoadingMore = true
    this.seriesErrorKey = ''
    try {
      console.info(`[Kavita] step=load_more_series_start library=${library.id} page=${nextPage}`)
      const rows = await this.store().createKavitaClient(record).listSeries(library.id, nextPage, KAVITA_SERIES_PAGE_SIZE)
      this.series = this.appendUniqueSeries(this.series, rows)
      this.seriesPage = nextPage
      this.seriesHasMore = rows.length >= KAVITA_SERIES_PAGE_SIZE
      console.info(`[Kavita] step=load_more_series_ok library=${library.id} page=${nextPage} series=${rows.length}`)
    } catch (error) {
      void error
      this.seriesErrorKey = 'browse_error_load_more'
      console.error('[Kavita] step=load_more_series_failed code=kavita_series_load_more_failed')
    } finally {
      this.seriesLoadingMore = false
    }
  }

  private backToSeries(): void {
    this.selectedSeries = undefined
    this.volumes = []
    this.volumesErrorKey = ''
  }

  private async openSeries(item: KavitaSeriesDto): Promise<void> {
    if (this.record === undefined || this.volumesLoading) {
      return
    }
    this.selectedSeries = item
    this.volumes = []
    this.volumesErrorKey = ''
    this.volumesLoading = true
    try {
      const record = this.record
      if (record === undefined) {
        return
      }
      console.info(`[Kavita] step=load_volumes_start series=${item.id}`)
      this.volumes = await this.store().createKavitaClient(record).listVolumes(item.id)
      console.info(`[Kavita] step=load_volumes_ok series=${item.id} volumes=${this.volumes.length}`)
    } catch (error) {
      void error
      this.volumesErrorKey = 'kavita_volumes_load_failed'
      this.volumes = []
      console.error('[Kavita] step=load_volumes_failed code=kavita_volumes_load_failed')
    } finally {
      this.volumesLoading = false
    }
  }

  private libraryTypeText(item: KavitaLibraryDto): string {
    if (item.type === undefined) {
      return s('kavita_library_type_unknown')
    }
    return s('kavita_library_type_value').replace('%s', `${item.type}`)
  }

  private seriesTitle(item: KavitaSeriesDto): string {
    if (item.localizedName !== undefined && item.localizedName.length > 0) {
      return item.localizedName
    }
    return item.name
  }

  private seriesDetail(item: KavitaSeriesDto): string {
    const pages = item.pages === undefined ? 0 : item.pages
    const read = item.pagesRead === undefined ? 0 : item.pagesRead
    return s('kavita_series_pages_progress').replace('%s', `${read}`).replace('%s', `${pages}`)
  }

  private volumeTitle(item: KavitaVolumeDto): string {
    if (item.name !== undefined && item.name.length > 0) {
      return item.name
    }
    if (item.number !== undefined) {
      return s('kavita_volume_number_title').replace('%s', `${item.number}`)
    }
    return s('kavita_volume_unknown_title')
  }

  private volumeDetail(item: KavitaVolumeDto): string {
    const chapters = item.chapters === undefined ? 0 : item.chapters.length
    const pages = item.pages === undefined ? 0 : item.pages
    return s('kavita_volume_detail').replace('%s', `${chapters}`).replace('%s', `${pages}`)
  }

  private chapterTitle(item: KavitaChapterDto): string {
    if (item.titleName !== undefined && item.titleName.length > 0) {
      return item.titleName
    }
    if (item.title !== undefined && item.title.length > 0) {
      return item.title
    }
    if (item.range !== undefined && item.range.length > 0) {
      return s('kavita_chapter_range_title').replace('%s', item.range)
    }
    return s('kavita_chapter_unknown_title')
  }

  private chapterDetail(item: KavitaChapterDto): string {
    const pages = item.pages === undefined ? 0 : item.pages
    const read = item.pagesRead === undefined ? 0 : item.pagesRead
    return s('kavita_series_pages_progress').replace('%s', `${read}`).replace('%s', `${pages}`)
  }

  private knownChapters(): KavitaChapterDto[] {
    const chapters: KavitaChapterDto[] = []
    this.volumes.forEach((volume: KavitaVolumeDto) => {
      if (volume.chapters !== undefined) {
        volume.chapters.forEach((chapter: KavitaChapterDto) => {
          if (chapters.find((item: KavitaChapterDto): boolean => item.id === chapter.id) === undefined) {
            chapters.push(chapter)
          }
        })
      }
    })
    return chapters
  }

  private dimensionForPageIndex(info: KavitaChapterInfoDto | undefined, pageIndex: number): KavitaFileDimensionDto | undefined {
    const dimensions = info?.pageDimensions
    if (dimensions === undefined || dimensions.length === 0) {
      return undefined
    }
    const matched = dimensions.find((item: KavitaFileDimensionDto): boolean => {
      return item.pageNumber === pageIndex || item.pageNumber === pageIndex + 1
    })
    return matched === undefined ? dimensions[pageIndex] : matched
  }

  private buildChapterPages(record: KavitaServerRecord, chapter: KavitaChapterDto, comicId: string, mappedChapterId: string, info?: KavitaChapterInfoDto): Page[] {
    const client = this.store().createKavitaClient(record)
    const pageCount = info?.pages === undefined ? chapter.pages === undefined ? 0 : chapter.pages : info.pages
    const pages: Page[] = []
    for (let index = 0; index < pageCount; index += 1) {
      pages.push(mapKavitaPageToPage(
        record.server.id,
        chapter.id,
        comicId,
        mappedChapterId,
        index,
        client.buildReaderImageUrl(chapter.id, index),
        this.dimensionForPageIndex(info, index),
      ))
    }
    return pages
  }

  private createSeriesComic(record: KavitaServerRecord, series: KavitaSeriesDto, sourceChapters: KavitaChapterDto[]): Comic | undefined {
    const comicId = createKavitaComicId(record.server.id, series.id)
    const chapters: Chapter[] = []
    sourceChapters.forEach((chapter: KavitaChapterDto) => {
      const mappedChapterId = createKavitaChapterId(record.server.id, chapter.id)
      const pages = this.buildChapterPages(record, chapter, comicId, mappedChapterId)
      if (pages.length > 0) {
        chapters.push(mapKavitaChapterToChapter(record.server.id, chapter, comicId, pages))
      }
    })
    const sortedChapters = chapters.sort((left: Chapter, right: Chapter): number => left.index - right.index)
    if (sortedChapters.length === 0) {
      return undefined
    }
    const comic = mapKavitaSeriesToComic(record.server.id, series, sortedChapters[0])
    comic.chapters = sortedChapters
    comic.chapterCount = sortedChapters.length
    comic.pageCount = sortedChapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0)
    return comic
  }

  private createReaderComic(record: KavitaServerRecord, series: KavitaSeriesDto, selectedChapter: KavitaChapterDto, info: KavitaChapterInfoDto): Comic | undefined {
    const knownChapters = this.knownChapters()
    const sourceChapters = knownChapters.length === 0 ? [selectedChapter] : knownChapters
    const comicId = createKavitaComicId(record.server.id, series.id)
    const chapters: Chapter[] = []
    sourceChapters.forEach((chapter: KavitaChapterDto) => {
      const mappedChapterId = createKavitaChapterId(record.server.id, chapter.id)
      const chapterInfo = chapter.id === selectedChapter.id ? info : undefined
      const pages = this.buildChapterPages(record, chapter, comicId, mappedChapterId, chapterInfo)
      chapters.push(mapKavitaChapterToChapter(record.server.id, chapter, comicId, pages, chapterInfo))
    })
    const selectedMappedChapter = chapters.find((chapter: Chapter): boolean => chapter.id === createKavitaChapterId(record.server.id, selectedChapter.id))
    if (selectedMappedChapter === undefined || selectedMappedChapter.pageCount <= 0) {
      return undefined
    }
    const comic = mapKavitaSeriesToComic(record.server.id, series, selectedMappedChapter, info)
    comic.chapters = chapters.sort((left: Chapter, right: Chapter): number => left.index - right.index)
    comic.chapterCount = comic.chapters.length
    comic.pageCount = comic.chapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0)
    return comic
  }

  private isSelectedSeriesInLibrary(): boolean {
    const record = this.record
    const series = this.selectedSeries
    if (record === undefined || series === undefined || this.favoriteRevision < 0) {
      return false
    }
    return this.libraryStore.findByRemote(record.server.id, `${series.id}`) !== undefined
  }

  private async addSelectedSeriesToLibrary(): Promise<void> {
    const record = this.record
    const series = this.selectedSeries
    if (record === undefined || series === undefined || this.addingSelectedSeries) {
      return
    }
    if (this.libraryStore.findByRemote(record.server.id, `${series.id}`) !== undefined) {
      this.showToast(s('common_already_in_library'))
      return
    }
    this.addingSelectedSeries = true
    try {
      console.info(`[Favorite] step=kavita_add_start server=${record.server.id} resource=${series.id}`)
      let volumeRows = this.volumes
      if (volumeRows.length === 0) {
        volumeRows = await this.store().createKavitaClient(record).listVolumes(series.id)
        this.volumes = volumeRows
      }
      const chapters = this.knownChapters()
      const comic = this.createSeriesComic(record, series, chapters)
      if (comic === undefined) {
        this.showToast(s('common_no_images_to_add'))
        console.warn('[Favorite] step=kavita_add_failed code=kavita_no_pages')
        return
      }
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast(s('common_added_to_library'))
      console.info(`[Favorite] step=kavita_add_ok chapters=${comic.chapterCount} pages=${comic.pageCount}`)
    } catch (error) {
      void error
      this.showToast(s('common_add_to_library_failed'))
      console.error('[Favorite] step=kavita_add_failed code=kavita_add_failed')
    } finally {
      this.addingSelectedSeries = false
    }
  }

  private async openChapter(chapter: KavitaChapterDto): Promise<void> {
    const record = this.record
    const series = this.selectedSeries
    if (record === undefined || series === undefined || this.openingChapterId.length > 0) {
      return
    }
    this.openingChapterId = `${chapter.id}`
    try {
      const client = this.store().createKavitaClient(record)
      console.info(`[Kavita] step=load_chapter_info_start chapter=${chapter.id}`)
      const info = await client.getChapterInfo(chapter.id)
      const comic = this.createReaderComic(record, series, chapter, info)
      if (comic === undefined) {
        this.showToast(s('common_no_images_to_add'))
        console.warn('[Kavita] step=open_chapter_failed code=kavita_no_pages')
        return
      }
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.onLibraryChanged()
      this.onOpenReader(comic.id, createKavitaChapterId(record.server.id, chapter.id))
      console.info(`[Kavita] step=open_chapter_ok chapters=${comic.chapterCount} pages=${comic.pageCount}`)
    } catch (error) {
      void error
      this.showToast(s('kavita_chapter_open_failed'))
      console.error('[Kavita] step=open_chapter_failed code=kavita_chapter_open_failed')
    } finally {
      this.openingChapterId = ''
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  @Builder
  private BackRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
      Text(s('kavita_action_back_libraries'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.backToLibraries()
    })
  }

  @Builder
  private BackToSeriesRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
      Text(s('kavita_action_back_series'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.backToSeries()
    })
  }

  @Builder
  private LibraryRow(item: KavitaLibraryDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.SOURCE_ICON_SIZE)
      .height(ThemeConstants.SOURCE_ICON_SIZE)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.SOURCE_KOMGA_COLOR)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.libraryTypeText(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
        .opacity(0.35)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openLibrary(item)
    })
  }

  @Builder
  private SeriesRow(item: KavitaSeriesDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(s('kavita_series_icon'))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.SOURCE_ICON_SIZE)
      .height(ThemeConstants.SOURCE_ICON_SIZE)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.SOURCE_KAVITA_COLOR)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.seriesTitle(item))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.seriesDetail(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openSeries(item)
    })
  }

  @Builder
  private VolumeRow(item: KavitaVolumeDto) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(s('kavita_volume_icon'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
        }
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(ThemeConstants.SOURCE_KAVITA_COLOR)

        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.volumeTitle(item))
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.volumeDetail(item))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (item.chapters !== undefined && item.chapters.length > 0) {
        ForEach(item.chapters, (chapter: KavitaChapterDto) => {
          Row({ space: ThemeConstants.SPACE_SM }) {
            Text(this.chapterTitle(chapter))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.chapterDetail(chapter))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
            if (this.openingChapterId === `${chapter.id}`) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(ThemeConstants.BRAND_PRIMARY)
            } else {
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor([ThemeConstants.TEXT_TERTIARY])
                .opacity(0.35)
            }
          }
          .width('100%')
          .padding({ left: ThemeConstants.SOURCE_ICON_SIZE + ThemeConstants.SPACE_MD, right: 0, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
          .onClick(() => {
            this.openChapter(chapter)
          })
        }, (chapter: KavitaChapterDto) => `${chapter.id}`)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private SeriesHeader() {
    if (this.selectedSeries !== undefined) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(this.seriesTitle(this.selectedSeries))
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .width('100%')
        KomaActionButton({
          label: this.isSelectedSeriesInLibrary() ? s('common_in_library') : s('common_add_to_library'),
          kind: this.isSelectedSeriesInLibrary() ? 'primary' : 'secondary',
          action: () => {
            this.addSelectedSeriesToLibrary()
          },
        })
          .width('100%')
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_MD)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  @Builder
  private EmptyState() {
    KomaEmptyState({
      title: s(this.errorKey.length > 0 ? this.errorKey : 'kavita_browse_empty_title'),
      message: s(this.errorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_browse_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.errorKey.length > 0,
      action: () => {
        this.loadLibraries()
      },
    })
  }

  @Builder
  private SeriesEmptyState() {
    KomaEmptyState({
      title: s(this.seriesErrorKey.length > 0 ? this.seriesErrorKey : 'kavita_series_empty_title'),
      message: s(this.seriesErrorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_series_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.seriesErrorKey.length > 0 && this.selectedLibrary !== undefined,
      action: () => {
        const library = this.selectedLibrary
        if (library !== undefined) {
          this.openLibrary(library)
        }
      },
    })
  }

  @Builder
  private VolumesEmptyState() {
    KomaEmptyState({
      title: s(this.volumesErrorKey.length > 0 ? this.volumesErrorKey : 'kavita_volumes_empty_title'),
      message: s(this.volumesErrorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_volumes_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.volumesErrorKey.length > 0 && this.selectedSeries !== undefined,
      action: () => {
        const series = this.selectedSeries
        if (series !== undefined) {
          this.openSeries(series)
        }
      },
    })
  }

  @Builder
  private LoadMoreSeriesRow() {
    KomaActionButton({
      label: this.seriesLoadingMore ? s('common_loading_more') : s('common_load_more'),
      kind: 'secondary',
      isEnabled: !this.seriesLoadingMore,
      busy: this.seriesLoadingMore,
      action: () => {
        this.loadMoreSeries()
      },
    })
      .width('100%')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.selectedSeries !== undefined) {
          ListItem() {
            this.BackToSeriesRow()
          }
          ListItem() {
            this.SeriesHeader()
          }
          if (this.volumesLoading) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(ThemeConstants.LOADING_SIZE_LARGE)
                  .height(ThemeConstants.LOADING_SIZE_LARGE)
                  .color(ThemeConstants.BRAND_PRIMARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          } else if (this.volumes.length === 0) {
            ListItem() {
              this.VolumesEmptyState()
            }
          } else {
            ForEach(this.volumes, (item: KavitaVolumeDto) => {
              ListItem() {
                this.VolumeRow(item)
              }
            }, (item: KavitaVolumeDto) => `${item.id}`)
          }
        } else if (this.selectedLibrary !== undefined) {
          ListItem() {
            this.BackRow()
          }
          if (this.seriesLoading) {
            ListItem() {
              Row() {
                LoadingProgress()
                  .width(ThemeConstants.LOADING_SIZE_LARGE)
                  .height(ThemeConstants.LOADING_SIZE_LARGE)
                  .color(ThemeConstants.BRAND_PRIMARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
          } else if (this.series.length === 0) {
            ListItem() {
              this.SeriesEmptyState()
            }
          } else {
            ForEach(this.series, (item: KavitaSeriesDto) => {
              ListItem() {
                this.SeriesRow(item)
              }
            }, (item: KavitaSeriesDto) => `${item.id}`)
            if (this.seriesHasMore) {
              ListItem() {
                this.LoadMoreSeriesRow()
              }
            }
          }
        } else if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(ThemeConstants.LOADING_SIZE_LARGE)
                .height(ThemeConstants.LOADING_SIZE_LARGE)
                .color(ThemeConstants.BRAND_PRIMARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        } else if (this.libraries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          ForEach(this.libraries, (item: KavitaLibraryDto) => {
            ListItem() {
              this.LibraryRow(item)
            }
          }, (item: KavitaLibraryDto) => `${item.id}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
