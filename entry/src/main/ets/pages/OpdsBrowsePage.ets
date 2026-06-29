import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  Chapter,
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
  normalizeSortKey,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  upsertComicAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { MOCK_LIBRARY_READER_SESSION } from '../model/MockLibraryData'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import { installReaderRemoteHeaders } from '../model/ReaderPageSourceAdapter'
import { ReaderSessionConfig, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { OpdsServerRecord, RemoteServerStore } from '../model/RemoteServerStore'
import {
  mapOpdsPublicationToAcquisitions,
  mapOpdsPublicationToImages,
} from '../remote/OpdsParser'
import {
  OpdsAcquisitionDto,
  OpdsAcquisitionStatus,
  OpdsBookDto,
  OpdsCatalogDto,
  OpdsImageDto,
  OpdsLink,
  OpdsLinkKind,
  OpdsParseResult,
} from '../remote/OpdsModels'
import { ThemeConstants } from '../theme/ThemeConstants'

interface OpdsHistoryEntry {
  url: string
  title: string
}

@ComponentV2
export struct OpdsBrowsePage {
  @Local private title: string = 'OPDS'
  @Local private currentUrl: string = ''
  @Local private history: OpdsHistoryEntry[] = []
  @Local private navigation: OpdsCatalogDto[] = []
  @Local private publications: OpdsBookDto[] = []
  @Local private selectedPublication: OpdsBookDto | undefined = undefined
  @Local private selectedImages: OpdsImageDto[] = []
  @Local private loading: boolean = true
  @Local private errorText: string = ''
  @Local private favoriteRevision: number = 0
  private record?: OpdsServerRecord
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadInitial()
  }

  private async loadInitial(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const saved = await this.store().loadOpds()
      if (saved === undefined) {
        throw new Error('请先在设置里配置 OPDS')
      }
      this.record = saved
      this.currentUrl = saved.server.rootUrl
      console.info('[OPDS] step=load_initial')
      await this.loadCatalog(saved.server.rootUrl, false)
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      console.error('[OPDS] step=load_initial_failed message=' + e.message)
    } finally {
      this.loading = false
    }
  }

  private async loadCatalog(url: string, pushHistory: boolean): Promise<void> {
    const record = this.record
    if (record === undefined) {
      return
    }
    this.loading = true
    this.errorText = ''
    try {
      console.info(`[OPDS] step=load_catalog_start urlHash=${this.shortHash(url)}`)
      const catalog = await this.store().createOpdsClient(record).fetchCatalog(url)
      if (pushHistory) {
        this.history = this.history.concat([{ url: this.currentUrl, title: this.title }])
      }
      this.applyCatalog(catalog)
      console.info(`[OPDS] step=load_catalog_ok version=${catalog.version} navigation=${catalog.navigation.length} publications=${catalog.publications.length}`)
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      console.error('[OPDS] step=load_catalog_failed message=' + e.message)
    } finally {
      this.loading = false
    }
  }

  private applyCatalog(catalog: OpdsParseResult): void {
    this.currentUrl = catalog.feedUrl
    this.title = catalog.title === undefined || catalog.title.length === 0 ? 'OPDS' : catalog.title
    this.navigation = catalog.navigation
    this.publications = catalog.publications
    this.selectedPublication = undefined
    this.selectedImages = []
  }

  private openNavigation(item: OpdsCatalogDto): void {
    console.info(`[OPDS] step=open_navigation title=${item.title}`)
    this.loadCatalog(item.href, true)
  }

  private goUp(): void {
    if (this.selectedPublication !== undefined) {
      this.selectedPublication = undefined
      this.selectedImages = []
      return
    }
    if (this.history.length === 0) {
      return
    }
    const previous = this.history[this.history.length - 1]
    this.history = this.history.slice(0, this.history.length - 1)
    this.title = previous.title
    this.loadCatalog(previous.url, false)
  }

  private async openPublication(publication: OpdsBookDto): Promise<void> {
    this.selectedPublication = publication
    this.selectedImages = mapOpdsPublicationToImages(publication)
    const manifestLink = this.findManifestLink(publication)
    if (manifestLink === undefined) {
      console.info(`[OPDS] step=open_publication title=${publication.title} images=${this.selectedImages.length}`)
      return
    }
    const record = this.record
    if (record === undefined) {
      return
    }
    try {
      console.info(`[OPDS] step=load_publication_manifest_start urlHash=${this.shortHash(manifestLink.href)}`)
      const manifestImages = await this.store().createOpdsClient(record).fetchPublicationImages(manifestLink.href)
      if (manifestImages.length > 0) {
        this.selectedImages = manifestImages
      }
      console.info(`[OPDS] step=load_publication_manifest_ok images=${manifestImages.length}`)
    } catch (error) {
      const e = error as Error
      console.error('[OPDS] step=load_publication_manifest_failed message=' + e.message)
    }
  }

  private findManifestLink(publication: OpdsBookDto): OpdsLink | undefined {
    return publication.links.find((link: OpdsLink): boolean => {
      const type = link.type === undefined ? '' : link.type.toLocaleLowerCase()
      return link.kind === OpdsLinkKind.SELF &&
        (type.indexOf('json') >= 0 || type.indexOf('divina') >= 0 || type.indexOf('webpub') >= 0)
    })
  }

  private openReader(): void {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.selectedImages.length === 0) {
      this.errorText = '这个 OPDS 条目没有可直接阅读的图片 URL'
      return
    }
    const now = Date.now()
    const comicId = `opds:${record.server.id}:comic:${this.shortHash(publication.id)}`
    const chapterId = `opds:${record.server.id}:chapter:${this.shortHash(publication.id + this.currentUrl)}`
    const pages = this.selectedImages.map((image: OpdsImageDto, index: number): Page => {
      const name = image.title === undefined || image.title.length === 0 ? `page-${index + 1}` : image.title
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: image.href,
        sortKey: normalizeSortKey(name),
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title: publication.title,
      index: 0,
      sourcePath: this.currentUrl,
      sortKey: normalizeSortKey(publication.title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    const comic: Comic = {
      id: comicId,
      title: publication.title,
      sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
      sourcePath: this.currentUrl,
      coverUri: pages[0].uri,
      sortTitle: normalizeSortKey(publication.title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
    const config = createReaderSessionConfigFromComic(comic, chapterId)
    this.installReaderSession(config)
    console.info(`[OPDS] step=open_reader images=${pages.length}`)
    RouterHelper.pushReader()
  }

  private isSelectedPublicationFavorited(): boolean {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.favoriteRevision < 0) {
      return false
    }
    return this.libraryStore.findByRemote(record.server.id, publication.id) !== undefined
  }

  private createSelectedPublicationComic(): Comic | undefined {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined || this.selectedImages.length === 0) {
      return undefined
    }
    const now = Date.now()
    const comicId = `opds:${record.server.id}:comic:${this.shortHash(publication.id)}`
    const chapterId = `opds:${record.server.id}:chapter:${this.shortHash(publication.id + this.currentUrl)}`
    const pages = this.selectedImages.map((image: OpdsImageDto, index: number): Page => {
      const name = image.title === undefined || image.title.length === 0 ? `page-${index + 1}` : image.title
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: image.href,
        sortKey: normalizeSortKey(name),
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title: publication.title,
      index: 0,
      sourcePath: this.currentUrl,
      sortKey: normalizeSortKey(publication.title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    return {
      id: comicId,
      title: publication.title,
      subtitle: publication.summary,
      author: publication.author,
      sourceKind: ComicSourceKind.OPDS_REMOTE,
      sourcePath: this.currentUrl,
      remoteServerId: record.server.id,
      remoteResourceId: publication.id,
      coverUri: pages[0].uri,
      sortTitle: normalizeSortKey(publication.title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
  }

  private addSelectedPublicationToLibrary(): void {
    const record = this.record
    const publication = this.selectedPublication
    if (record === undefined || publication === undefined) {
      return
    }
    if (this.libraryStore.findByRemote(record.server.id, publication.id) !== undefined) {
      this.showToast('已在书架中')
      return
    }
    const comic = this.createSelectedPublicationComic()
    if (comic === undefined) {
      this.errorText = '这个 OPDS 条目没有可收藏的图片 URL'
      this.showToast('没有可收藏图片')
      return
    }
    try {
      console.info(`[Favorite] step=opds_add_start server=${record.server.id} resource=${publication.id}`)
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast('已加入书架')
      console.info(`[Favorite] step=opds_add_ok pages=${comic.pageCount}`)
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      this.showToast('加入书架失败')
      console.error('[Favorite] step=opds_add_failed message=' + e.message)
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private installReaderSession(config: ReaderSessionConfig): void {
    const record = this.record
    if (record === undefined) {
      return
    }
    MOCK_LIBRARY_READER_SESSION.comicId = config.comicId
    MOCK_LIBRARY_READER_SESSION.chapterId = config.chapterId
    MOCK_LIBRARY_READER_SESSION.title = config.title
    MOCK_LIBRARY_READER_SESSION.chapterTitle = config.chapterTitle
    MOCK_LIBRARY_READER_SESSION.totalPages = config.totalPages
    MOCK_LIBRARY_READER_SESSION.pageUris = config.pageUris
    MOCK_LIBRARY_READER_SESSION.pageIds = config.pageIds
    MOCK_LIBRARY_READER_SESSION.pageWidths = config.pageWidths
    MOCK_LIBRARY_READER_SESSION.pageHeights = config.pageHeights
    installReaderRemoteHeaders(this.store().createOpdsClient(record).getUrlPrefix(), this.store().getOpdsImageHeaders(record))
  }

  private acquisitionText(publication: OpdsBookDto): string {
    const acquisitions = mapOpdsPublicationToAcquisitions(publication)
    if (acquisitions.length === 0) {
      return '无 acquisition'
    }
    const supported = acquisitions.filter((item: OpdsAcquisitionDto): boolean => item.status === OpdsAcquisitionStatus.SUPPORTED).length
    return supported > 0 ? `${supported} 个可获取文件` : 'acquisition 暂不支持'
  }

  private shortHash(value: string): string {
    let hash = 2166136261
    for (let index = 0; index < value.length; index += 1) {
      hash = (hash ^ value.charCodeAt(index)) >>> 0
      hash = Math.imul(hash, 16777619) >>> 0
    }
    return hash.toString(16).padStart(8, '0').slice(-8)
  }

  @Builder
  private HeaderCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Button('上一级')
          .height(ThemeConstants.FILTER_CHIP_HEIGHT)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor((this.history.length === 0 && this.selectedPublication === undefined) ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.BRAND_PRIMARY)
          .enabled(this.history.length > 0 || this.selectedPublication !== undefined)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.DIVIDER })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.goUp()
          })
        Text(this.selectedPublication === undefined ? this.title : this.selectedPublication.title)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if (this.selectedPublication !== undefined && this.selectedImages.length > 0) {
        Button(this.isSelectedPublicationFavorited() ? '已收藏' : '加入书架')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isSelectedPublicationFavorited() ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(this.isSelectedPublicationFavorited() ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.addSelectedPublicationToLibrary()
          })
        Button(`阅读 ${this.selectedImages.length} 张图片`)
          .height(ThemeConstants.BUTTON_HEIGHT)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.openReader()
          })
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private NavigationRow(item: OpdsCatalogDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text('C')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(ThemeConstants.RADIUS_THUMB)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.type === undefined ? 'Catalog' : item.type)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openNavigation(item)
    })
  }

  @Builder
  private PublicationRow(item: OpdsBookDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text(item.title.substring(0, 1).toLocaleUpperCase())
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .width(ThemeConstants.LIST_COVER_WIDTH)
        .height(ThemeConstants.LIST_COVER_HEIGHT)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
        .borderRadius(ThemeConstants.RADIUS_THUMB)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.acquisitionText(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openPublication(item)
    })
  }

  @Builder
  private PublicationDetail(publication: OpdsBookDto) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(publication.summary === undefined ? '无简介' : publication.summary)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      ForEach(mapOpdsPublicationToAcquisitions(publication), (item: OpdsAcquisitionDto) => {
        Text(item.status === OpdsAcquisitionStatus.SUPPORTED ? `Acquisition：${item.type ?? item.href}` : `暂不支持：${item.type ?? item.href}`)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(item.status === OpdsAcquisitionStatus.SUPPORTED ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY)
      }, (item: OpdsAcquisitionDto) => item.href)
      ForEach(this.selectedImages, (item: OpdsImageDto, index: number) => {
        Text(`${index + 1}. ${item.title ?? item.href}`)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }, (item: OpdsImageDto) => item.href)
      if (this.selectedImages.length === 0) {
        Text('未发现可直接阅读的 image / readingOrder / pageList URL')
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
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
            this.HeaderCard()
          }
          if (this.selectedPublication !== undefined) {
            ListItem() {
              this.PublicationDetail(this.selectedPublication)
            }
          } else {
            ForEach(this.navigation, (item: OpdsCatalogDto) => {
              ListItem() {
                this.NavigationRow(item)
              }
            }, (item: OpdsCatalogDto) => item.href)
            ForEach(this.publications, (item: OpdsBookDto) => {
              ListItem() {
                this.PublicationRow(item)
              }
            }, (item: OpdsBookDto) => item.id)
            if (this.navigation.length === 0 && this.publications.length === 0) {
              ListItem() {
                Text('当前 catalog 没有 navigation 或 publication')
                  .width('100%')
                  .padding(ThemeConstants.SPACE_LG)
                  .fontSize(ThemeConstants.FONT_SIZE_BODY)
                  .fontColor(ThemeConstants.TEXT_SECONDARY)
                  .borderRadius(ThemeConstants.RADIUS_CARD)
                  .backgroundColor(ThemeConstants.CARD)
              }
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
