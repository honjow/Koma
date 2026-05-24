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
import { MOCK_LIBRARY_READER_SESSION } from '../model/MockLibraryData'
import { installReaderRemoteHeaders } from '../model/ReaderPageSourceAdapter'
import { ReaderSessionConfig, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { RemoteServerStore, WebDavServerRecord } from '../model/RemoteServerStore'
import { DavComicCandidateKind, DavResource } from '../remote/WebDavModels'
import { WebDavClient, readWebDavUrlPath } from '../remote/WebDavClient'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct WebDavBrowsePage {
  @State private pathSegments: string[] = []
  @State private folders: DavResource[] = []
  @State private images: DavResource[] = []
  @State private loading: boolean = true
  @State private errorText: string = ''
  private record?: WebDavServerRecord

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
        throw new Error('请先在设置里配置 WebDAV')
      }
      this.record = saved
      console.info('[WebDAV] step=load_initial')
      await this.loadDirectory([])
    } catch (error) {
      const e = error as Error
      this.errorText = e.message
      console.error('[WebDAV] step=load_initial_failed message=' + e.message)
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
      const e = error as Error
      this.errorText = e.message
      console.error('[WebDAV] step=propfind_failed message=' + e.message)
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
      return 'WebDAV'
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
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Button('上一级')
          .height(34)
          .fontSize(13)
          .fontColor(this.pathSegments.length === 0 ? $r('app.color.koma_text_secondary') : $r('app.color.koma_accent'))
          .enabled(this.pathSegments.length > 0)
          .backgroundColor('#00000000')
          .border({ width: 1, color: '#338F837D' })
          .borderRadius(8)
          .onClick(() => {
            this.goUp()
          })
        Text(this.currentTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      if (this.images.length > 0) {
        Button(`阅读 ${this.images.length} 页`)
          .height(40)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.koma_accent'))
          .borderRadius(8)
          .onClick(() => {
            this.openReader()
          })
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private FolderRow(item: DavResource) {
    Row({ space: 12 }) {
      Text('D')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor('#16745F')
        .borderRadius(8)
      Column({ space: 4 }) {
        Text(this.resourceName(item))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text('文件夹')
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>')
        .fontSize(18)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.openFolder(item)
    })
  }

  @Builder
  private ImageRow(item: DavResource, index: number) {
    Row({ space: 12 }) {
      Text(`${index + 1}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_accent'))
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .borderRadius(8)
      Column({ space: 4 }) {
        Text(this.resourceName(item))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.contentLength === undefined ? '图片' : `${item.contentLength} bytes`)
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
      this.openReader()
    })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
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
              Text('当前目录没有可阅读的图片或子目录')
                .width('100%')
                .padding(16)
                .fontSize(14)
                .fontColor($r('app.color.koma_text_secondary'))
                .borderRadius(8)
                .backgroundColor($r('app.color.koma_card'))
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
