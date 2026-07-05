import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
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
import { RemoteServerStore, WebDavServerRecord } from '../model/RemoteServerStore'
import { DavComicCandidateKind, DavResource } from '../remote/WebDavModels'
import { WebDavClient, readWebDavUrlPath } from '../remote/WebDavClient'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct WebDavBrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private pathSegments: string[] = []
  @Local private folders: DavResource[] = []
  @Local private images: DavResource[] = []
  @Local private loading: boolean = true
  @Local private errorText: string = ''
  @Local private favoriteRevision: number = 0
  private record?: WebDavServerRecord
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  private client(): WebDavClient | undefined {
    if (this.record === undefined) {
      return undefined
    }
    return this.store().createWebDavClient(this.record)
  }

  aboutToAppear(): void {
    this.loadInitial()
  }

  private async loadInitial(): Promise<void> {
    this.loading = true
    this.errorText = ''
    try {
      const saved = await this.store().loadWebDav()
      if (saved === undefined) {
        this.errorText = s('webdav_config_required')
        return
      }
      this.record = saved
      console.info('[WebDAV] step=load_initial')
      await this.loadDirectory([])
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[WebDAV] step=load_initial_failed code=webdav_initial_load_failed')
    } finally {
      this.loading = false
    }
  }

  private async loadDirectory(pathSegments: string[]): Promise<void> {
    const client = this.client()
    if (client === undefined) {
      return
    }
    this.loading = true
    this.errorText = ''
    try {
      console.info(`[WebDAV] step=propfind_start path=${pathSegments.join('/')}`)
      const resources = await client.propfind(pathSegments, 1)
      this.pathSegments = pathSegments
      this.folders = this.sortResources(resources.filter((resource: DavResource) => {
        return resource.isCollection && !this.isCurrentResource(client, pathSegments, resource)
      }))
      this.images = this.sortResources(resources.filter((resource: DavResource) => {
        return !resource.isCollection && resource.candidateKind === DavComicCandidateKind.IMAGE_FILE
      }))
      console.info(`[WebDAV] step=propfind_ok folders=${this.folders.length} images=${this.images.length}`)
    } catch (error) {
      void error
      this.errorText = s('common_load_failed')
      console.error('[WebDAV] step=propfind_failed code=webdav_propfind_failed')
    } finally {
      this.loading = false
    }
  }

  private async openFolder(folder: DavResource): Promise<void> {
    const client = this.client()
    if (client === undefined) {
      return
    }
    const nextPath = this.relativeSegments(client, folder.href)
    await this.loadDirectory(nextPath)
  }

  private goUp(): void {
    if (this.pathSegments.length === 0) {
      return
    }
    this.loadDirectory(this.pathSegments.slice(0, this.pathSegments.length - 1))
  }

  private openReader(): void {
    const client = this.client()
    const record = this.record
    if (client === undefined || record === undefined || this.images.length === 0) {
      return
    }
    const title = this.currentTitle()
    const now = Date.now()
    const comicId = `webdav:${record.server.id}:comic:${this.shortHash(client.buildUrl(this.pathSegments))}`
    const chapterId = `webdav:${record.server.id}:chapter:${this.shortHash(client.buildUrl(this.pathSegments))}`
    const pages = this.images.map((resource: DavResource, index: number): Page => {
      const name = this.resourceName(resource)
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: client.getResourceUrl(resource),
        sortKey: normalizeSortKey(name),
        byteSize: resource.contentLength,
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title,
      index: 0,
      sourcePath: client.buildUrl(this.pathSegments),
      sortKey: normalizeSortKey(title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    const comic: Comic = {
      id: comicId,
      title,
      sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
      sourcePath: client.buildUrl(this.pathSegments),
      coverUri: pages.length === 0 ? undefined : pages[0].uri,
      sortTitle: normalizeSortKey(title),
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
    console.info(`[WebDAV] step=open_reader pages=${pages.length}`)
    RouterHelper.pushReader()
  }

  private currentDirectoryUrl(): string {
    const client = this.client()
    return client === undefined ? '' : client.buildUrl(this.pathSegments)
  }

  private currentResourceId(): string {
    return this.currentDirectoryUrl()
  }

  private isCurrentDirectoryFavorited(): boolean {
    const record = this.record
    if (record === undefined || this.favoriteRevision < 0) {
      return false
    }
    return this.libraryStore.findByRemote(record.server.id, this.currentResourceId()) !== undefined
  }

  private createCurrentDirectoryComic(): Comic | undefined {
    const client = this.client()
    const record = this.record
    if (client === undefined || record === undefined || this.images.length === 0) {
      return undefined
    }
    const title = this.currentTitle()
    const directoryUrl = client.buildUrl(this.pathSegments)
    const now = Date.now()
    const comicId = `webdav:${record.server.id}:comic:${this.shortHash(directoryUrl)}`
    const chapterId = `webdav:${record.server.id}:chapter:${this.shortHash(directoryUrl)}`
    const pages = this.images.map((resource: DavResource, index: number): Page => {
      const name = this.resourceName(resource)
      return {
        id: `${chapterId}:page:${index + 1}`,
        comicId,
        chapterId,
        index,
        fileName: name,
        uri: client.getResourceUrl(resource),
        sortKey: normalizeSortKey(name),
        byteSize: resource.contentLength,
      }
    })
    const chapter: Chapter = {
      id: chapterId,
      comicId,
      title,
      index: 0,
      sourcePath: directoryUrl,
      sortKey: normalizeSortKey(title),
      pages,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
    }
    return {
      id: comicId,
      title,
      sourceKind: ComicSourceKind.WEBDAV_REMOTE,
      sourcePath: directoryUrl,
      remoteServerId: record.server.id,
      remoteResourceId: directoryUrl,
      coverUri: pages.length === 0 ? undefined : pages[0].uri,
      sortTitle: normalizeSortKey(title),
      preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
      chapters: [chapter],
      chapterCount: 1,
      pageCount: pages.length,
      createdAt: now,
      updatedAt: now,
      lastImportedAt: now,
    }
  }

  private addCurrentDirectoryToLibrary(): void {
    const record = this.record
    if (record === undefined) {
      return
    }
    const resourceId = this.currentResourceId()
    if (this.libraryStore.findByRemote(record.server.id, resourceId) !== undefined) {
      this.showToast(s('common_already_in_library'))
      return
    }
    const comic = this.createCurrentDirectoryComic()
    if (comic === undefined) {
      this.showToast(s('common_no_images_to_add'))
      return
    }
    try {
      console.info(`[Favorite] step=webdav_add_start server=${record.server.id} resourceHash=${this.shortHash(resourceId)}`)
      if (this.libraryPersistenceService === undefined) {
        this.libraryStore.upsertComic(comic)
      } else {
        upsertComicAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, comic)
      }
      this.favoriteRevision += 1
      this.onLibraryChanged()
      this.showToast(s('common_added_to_library'))
      console.info(`[Favorite] step=webdav_add_ok pages=${comic.pageCount}`)
    } catch (error) {
      void error
      this.errorText = s('common_add_to_library_failed')
      this.showToast(s('common_add_to_library_failed'))
      console.error('[Favorite] step=webdav_add_failed code=webdav_add_failed')
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
    const client = this.client()
    if (record === undefined || client === undefined) {
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
    installReaderRemoteHeaders(client.getBaseUrl(), this.store().getWebDavImageHeaders(record))
  }

  private isCurrentResource(client: WebDavClient, pathSegments: string[], resource: DavResource): boolean {
    return this.normalizeUrl(client.buildUrl(pathSegments)) === this.normalizeUrl(resource.href)
  }

  private normalizeUrl(value: string): string {
    let normalized = value
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1)
    }
    return normalized
  }

  private relativeSegments(client: WebDavClient, href: string): string[] {
    try {
      const rawRootPath = readWebDavUrlPath(client.buildUrl([]))
      const rootPath = rawRootPath.endsWith('/') ? rawRootPath : rawRootPath + '/'
      let childPath = readWebDavUrlPath(href)
      if (childPath.endsWith('/')) {
        childPath = childPath.substring(0, childPath.length - 1)
      }
      if (!childPath.startsWith(rootPath)) {
        return this.pathSegments
      }
      return childPath.substring(rootPath.length).split('/').filter((segment: string) => {
        return segment.length > 0
      }).map((segment: string) => decodeURIComponent(segment))
    } catch (_err) {
      return this.pathSegments
    }
  }

  private sortResources(resources: DavResource[]): DavResource[] {
    return resources.slice().sort((left: DavResource, right: DavResource) => {
      return this.resourceName(left).localeCompare(this.resourceName(right))
    })
  }

  private currentTitle(): string {
    if (this.pathSegments.length === 0) {
      return s('route_webdav_title')
    }
    return this.pathSegments[this.pathSegments.length - 1]
  }

  private resourceName(resource: DavResource): string {
    if (resource.displayname !== undefined && resource.displayname.length > 0) {
      return resource.displayname
    }
    try {
      const pathname = readWebDavUrlPath(resource.href)
      const trimmed = pathname.endsWith('/') ? pathname.substring(0, pathname.length - 1) : pathname
      const name = trimmed.split('/').pop()
      return name === undefined || name.length === 0 ? resource.href : decodeURIComponent(name)
    } catch (_err) {
      return resource.href
    }
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
        KomaActionButton({
          label: s('common_back'),
          kind: 'ghost',
          compact: true,
          controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
          accentColor: this.pathSegments.length === 0 ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.BRAND_PRIMARY,
          isEnabled: this.pathSegments.length > 0,
          action: () => {
            this.goUp()
          },
        })
        Text(this.currentTitle())
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if (this.images.length > 0) {
        KomaActionButton({
          label: this.isCurrentDirectoryFavorited() ? s('common_in_library') : s('webdav_action_add_directory'),
          kind: this.isCurrentDirectoryFavorited() ? 'primary' : 'secondary',
          action: () => {
            this.addCurrentDirectoryToLibrary()
          },
        })
          .width('100%')
        KomaActionButton({
          label: s('webdav_action_read_pages').replace('%s', `${this.images.length}`),
          kind: 'primary',
          action: () => {
            this.openReader()
          },
        })
          .width('100%')
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private FolderRow(item: DavResource) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text('D')
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .width(ThemeConstants.BUTTON_HEIGHT)
        .height(ThemeConstants.BUTTON_HEIGHT)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.resourceName(item))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(s('webdav_item_folder'))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openFolder(item)
    })
  }

  @Builder
  private ImageRow(item: DavResource, index: number) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Text(`${index + 1}`)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .width(ThemeConstants.BUTTON_HEIGHT)
        .height(ThemeConstants.BUTTON_HEIGHT)
        .textAlign(TextAlign.Center)
        .backgroundColor(ThemeConstants.BG_SUB)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.resourceName(item))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.contentLength === undefined ? s('webdav_item_image') : s('webdav_item_bytes').replace('%s', `${item.contentLength}`))
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
      this.openReader()
    })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
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
          ForEach(this.folders, (item: DavResource) => {
            ListItem() {
              this.FolderRow(item)
            }
          }, (item: DavResource) => item.href)
          ForEach(this.images, (item: DavResource, index: number) => {
            ListItem() {
              this.ImageRow(item, index)
            }
          }, (item: DavResource) => item.href)
          if (this.folders.length === 0 && this.images.length === 0) {
            ListItem() {
              Text(s('webdav_empty_directory'))
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
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
