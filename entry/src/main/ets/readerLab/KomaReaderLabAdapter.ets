import { firstReaderChapter } from '../model/ReaderChapterSequence'
import { common } from '@kit.AbilityKit'
import {
  ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderAsset, ReaderAssetKind,
  ReaderImageInformation, ReaderImageInformationSource, ReaderImageShareTarget,
  ReaderAssetFailure, ReaderAssetFailureClassifier,
} from '@reader-kit/core'
import { KomaReaderFailure } from './KomaReaderFailure'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ReaderFileCropSource, ReaderFileInformation } from '@reader-kit/ui'
import { InMemoryLibraryStore } from '../model/LibraryStore'
import { ComicSourceKind } from '../model/ComicModels'
import { localLibraryFolderRootUriFromComic } from '../model/LocalLibraryFolderContract'
import { activateLocalLibraryFolderAccess } from '../model/LocalLibraryFolderAccessService'
import { AppFilesLibraryStorePersistenceAdapter, hydrateLibraryStoreFromJson } from '../model/LibraryPersistence'
import { ReaderSessionConfig, cloneReaderSessionConfig, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { OfflineDownloadStore } from '../model/OfflineDownloadStore'
import { createKomaReaderLabOfflineConfig } from './KomaReaderLabOfflineConfig'
import { KomaReaderLabThumbnailProvider } from './KomaReaderLabThumbnailProvider'
import { KomaReaderCatalogHost } from './KomaReaderCatalogHost'
import {
  ReaderPageRenderKind, ReaderPageRenderSource, configureReaderOfflineDownloads, configureReaderRemoteImageCache,
  createReaderPageRenderSources, fetchAndCacheReaderRemoteSource,
} from '../model/ReaderPageSourceAdapter'

export class KomaReaderLabChapterChoice {
  key: ReaderUnitKey
  title: string

  constructor(key: ReaderUnitKey, title: string) {
    this.key = key
    this.title = title
  }
}

/** Defer metadata I/O until requested; its failure must not reject the displayed body asset. */
class KomaReaderFileInformation implements ReaderImageInformationSource {
  private path: string

  constructor(uri: string) {
    this.path = uri.startsWith('file://') ? uri.substring('file://'.length) : uri
  }

  async read(): Promise<ReaderImageInformation> {
    const facts = new ReaderImageInformation()
    facts.bytes = fs.statSync(this.path).size
    return new ReaderFileInformation(this.path, facts).read()
  }
}

/** D1 reads local/downloaded chapters. It never fetches chapter pages or persists the user's library. */
export class KomaReaderLabAdapter implements ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost,
  ReaderAssetFailureClassifier {
  cancellationMode: 'consumer-only' | 'transport' = 'consumer-only'
  informationSupported: boolean = true

  classify(error: Error): ReaderAssetFailure {
    return KomaReaderFailure.from(error)
  }
  private library: InMemoryLibraryStore = new InMemoryLibraryStore()
  private configs: Map<string, ReaderSessionConfig> = new Map()
  private sources: Map<string, ReaderPageRenderSource[]> = new Map()
  private preparedUnits: Map<string, ReaderUnit> = new Map()
  private preparingUnits: Map<string, Promise<ReaderUnit>> = new Map()
  private preparationCancellation: ReaderCancellation = new ReaderCancellation()
  private sourceRequests: Map<string, Promise<string>> = new Map()
  private refreshingSources: Map<string, Promise<void>> = new Map()
  private automaticallyRefreshedUnits: Set<string> = new Set()
  private automaticPageRetries: Set<string> = new Set()
  private chapterPreloadEnabled: boolean
  private closed: boolean = false
  private catalogFailureText: string = ''

  catalogFailureMessage(): string { return this.catalogFailureText }
  private requestContext?: common.UIAbilityContext
  private filesDir: string
  private thumbnails: KomaReaderLabThumbnailProvider
  private catalogHost: KomaReaderCatalogHost | null

  private unitId(key: ReaderUnitKey): string { return JSON.stringify([key.scope, key.work, key.unit]) }

  constructor(filesDir: string, cacheDir: string, catalogHost: KomaReaderCatalogHost | null = null,
    requestContext?: common.UIAbilityContext, chapterPreloadEnabled: boolean = false) {
    this.chapterPreloadEnabled = chapterPreloadEnabled
    this.requestContext = requestContext
    this.filesDir = filesDir
    this.thumbnails = new KomaReaderLabThumbnailProvider(cacheDir)
    this.catalogHost = catalogHost
    const payload = new AppFilesLibraryStorePersistenceAdapter(filesDir).load()
    if (payload !== undefined) hydrateLibraryStoreFromJson(this.library, payload)
    configureReaderOfflineDownloads(filesDir)
    if (cacheDir.length > 0) configureReaderRemoteImageCache(cacheDir)
  }

  initialKey(work: string, unit: string): ReaderUnitKey {
    const hosted = this.catalogHost?.initial(work, unit) ?? null
    if (hosted !== null && hosted.comicId === work && hosted.chapterId === unit && hosted.totalPages > 0) {
      return new ReaderUnitKey('koma-local', work, unit)
    }
    const comic = this.library.getComic(work)
    const chapter = unit.length > 0 ? unit : (firstReaderChapter(comic?.chapters ?? [])?.id ?? '')
    return new ReaderUnitKey('koma-local', work, chapter)
  }

  async open(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    const prepared = this.preparedUnits.get(this.unitId(key))
    return prepared !== undefined ? prepared.copy() : this.prepare(key, cancellation)
  }

  /** One reader entry shares prepared catalogs and their in-flight host request.
   * Cancelling a prefetch consumer must not cancel a foreground chapter join. */
  async prepare(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    this.catalogFailureText = ''
    try {
      return await this.prepareShared(key, cancellation)
    } catch (error) {
      cancellation.check()
      if (this.closed) throw new Error('closed_koma_reader')
      this.catalogFailureText = KomaReaderFailure.catalogMessage(error as Error)
      throw error as Error
    }
  }

  private async prepareShared(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (this.closed || key.scope !== 'koma-local') throw new Error('invalid_koma_reader_scope')
    const id = this.unitId(key)
    const prepared = this.preparedUnits.get(id)
    if (prepared !== undefined) return prepared.copy()
    let pending = this.preparingUnits.get(id)
    if (pending === undefined) {
      const request = this.prepareUnit(key.copy(), this.preparationCancellation)
      this.preparingUnits.set(id, request)
      const retire = (): void => {
        if (this.preparingUnits.get(id) === request) this.preparingUnits.delete(id)
      }
      void request.then(retire, retire)
      pending = request
    }
    const unit = await pending
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    return unit.copy()
  }

  private async prepareUnit(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    const hosted = await this.catalogHost?.prepare(key, cancellation) ?? null
    if (hosted !== null) return this.installConfig(key, hosted, cancellation)
    const comic = this.library.getComic(key.work)
    if (comic === undefined || !comic.chapters.some((chapter) => chapter.id === key.unit)) {
      throw new Error('missing_koma_chapter')
    }
    if (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
      const rootUri = localLibraryFolderRootUriFromComic(comic)
      if (rootUri !== undefined) {
        cancellation.check()
        if (this.closed) throw new Error('closed_koma_reader')
        const access = await activateLocalLibraryFolderAccess(rootUri)
        cancellation.check()
        if (this.closed) throw new Error('closed_koma_reader')
        // Match the production reader: activation failure remains a page-load concern.
        console.info('[KomaReaderLab] step=folder_activate status=' + access.status)
      }
    }
    let config = createReaderSessionConfigFromComic(comic, key.unit)
    if (config.totalPages <= 0 && config.chapterId.length > 0) {
      try {
        const validation = new OfflineDownloadStore(this.filesDir).validateDownloadedChapter(
          comic.id, key.unit, { validateContentHash: false })
        config = createKomaReaderLabOfflineConfig(config, validation)
      } catch (_error) {
        // An unavailable manifest leaves the original empty catalog unchanged.
      }
    }
    if (!Number.isSafeInteger(config.totalPages) || config.totalPages < 1) {
      throw new Error('missing_koma_chapter_pages')
    }
    return this.installConfig(key, config, cancellation)
  }

  private installConfig(key: ReaderUnitKey, config: ReaderSessionConfig,
    cancellation: ReaderCancellation): ReaderUnit {
    if (config.comicId !== key.work || config.chapterId !== key.unit ||
      !Number.isSafeInteger(config.totalPages) || config.totalPages < 1 ||
      config.pageUris.length !== config.totalPages) throw new Error('invalid_koma_host_catalog')
    // One chapter source list; URI classification itself does not fetch remote pages.
    const sources = createReaderPageRenderSources(config, { preferOffline: true })
    const unit = new ReaderUnit(key.copy(), `${config.title ?? ''} · ${config.chapterTitle ?? ''}`, config.totalPages)
    cancellation.check()
    this.configs.set(this.unitId(key), config)
    this.sources.set(this.unitId(key), sources)
    this.preparedUnits.set(this.unitId(key), unit)
    return unit.copy()
  }

  async page(unit: ReaderUnit, index: number, cancellation: ReaderCancellation): Promise<ReaderPage> {
    cancellation.check()
    const config = this.configs.get(this.unitId(unit.key))
    if (config === undefined) throw new Error('missing_koma_session')
    const page = new ReaderPage(unit.key, config.pageIds?.[index] ?? `${unit.key.unit}:${index}`, index)
    page.width = config.pageWidths?.[index] ?? 0
    page.height = config.pageHeights?.[index] ?? 0
    page.thumbnail.kind = 'derived'
    const source = this.sources.get(this.unitId(unit.key))?.[index]
    page.thumbnail.available = source !== undefined &&
      source.kind !== ReaderPageRenderKind.URI_PLACEHOLDER && source.imageUri.length > 0
    return page
  }

  adjacent(unit: ReaderUnit, direction: 'next' | 'previous'): ReaderUnitKey | null {
    const config = this.configs.get(this.unitId(unit.key))
    if (config === undefined) return null
    const chapterIds = config.continuationChapterIds ?? config.chapterIds
    const index = chapterIds.indexOf(unit.key.unit)
    const target = index + (direction === 'next' ? 1 : -1)
    if (index < 0 || target < 0 || target >= chapterIds.length) return null
    return new ReaderUnitKey(unit.key.scope, unit.key.work, chapterIds[target])
  }

  /** Host-owned chapter catalog projection for the optional picker; reader-kit never sees these titles. */
  chapterChoices(unit: ReaderUnitKey): KomaReaderLabChapterChoice[] {
    const config = this.configs.get(this.unitId(unit))
    if (config === undefined) return []
    // Manual selection matches the legacy reader's complete catalog. Only the
    // previous/next boundary above is restricted to the verified continuation
    // sequence, so editions outside that sequence do not disappear from UI.
    return config.chapterIds.map((chapterId: string, index: number): KomaReaderLabChapterChoice => {
      return new KomaReaderLabChapterChoice(
        new ReaderUnitKey(unit.scope, unit.work, chapterId),
        index >= 0 ? (config.chapterTitles?.[index] ?? '') : '',
      )
    })
  }

  sessionConfig(unit: ReaderUnitKey): ReaderSessionConfig | null {
    const config = this.configs.get(this.unitId(unit))
    return config === undefined ? null : cloneReaderSessionConfig(config)
  }

  /** Only the host's verified continuation sequence authorizes speculative work. */
  async preloadNextUnit(unit: ReaderUnit, depth: number, cancellation: ReaderCancellation): Promise<void> {
    cancellation.check()
    if (!this.chapterPreloadEnabled || this.closed) return
    const sequence = this.configs.get(this.unitId(unit.key))?.continuationChapterIds
    if (sequence === undefined) return
    const index = sequence.indexOf(unit.key.unit)
    if (index < 0 || index + 1 >= sequence.length) return
    const next = new ReaderUnitKey(unit.key.scope, unit.key.work, sequence[index + 1])
    const prepared = await this.prepareShared(next, cancellation)
    for (let page = 0; page < Math.min(depth, prepared.pageCount); page += 1) {
      cancellation.check()
      const descriptor = await this.page(prepared, page, cancellation)
      await this.preload(descriptor, cancellation)
    }
  }

  /** Explicit retry refreshes the host-owned page addresses without replacing the live unit.
   * Match stable page IDs so a reordered provider response cannot open another image. */
  private async refreshPageSources(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<void> {
    const id = this.unitId(key)
    let pending = this.refreshingSources.get(id)
    if (pending === undefined) {
      const request = (async (): Promise<void> => {
        const config = await this.catalogHost?.prepare(key, this.preparationCancellation, true) ?? null
        this.preparationCancellation.check()
        if (this.closed) throw new Error('closed_koma_reader')
        if (config === null || config.comicId !== key.work || config.chapterId !== key.unit) {
          throw new Error('missing_koma_chapter_pages')
        }
        const fresh = createReaderPageRenderSources(config, { preferOffline: true })
        const byId = new Map<string, ReaderPageRenderSource>()
        fresh.forEach((source: ReaderPageRenderSource): void => {
          if (source.pageId !== undefined) byId.set(source.pageId, source)
        })
        const current = this.sources.get(id)
        if (current === undefined) throw new Error('missing_koma_page_source')
        const next = current.map((source: ReaderPageRenderSource): ReaderPageRenderSource => {
          if (source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) return source
          const replacement = source.pageId === undefined ? undefined : byId.get(source.pageId)
          if (replacement === undefined) throw new Error('missing_koma_page_source')
          return replacement
        })
        this.sources.set(id, next)
      })()
      this.refreshingSources.set(id, request)
      const retire = (): void => {
        if (this.refreshingSources.get(id) === request) this.refreshingSources.delete(id)
      }
      void request.then(retire, retire)
      pending = request
    }
    await pending
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
  }

  /** Share descriptor resolution and image transport before the file-cache layer. */
  private sourceFile(key: ReaderUnitKey, index: number, forceReload: boolean = false): Promise<string> {
    if (this.closed) return Promise.reject(new Error('closed_koma_reader'))
    const source = this.sources.get(this.unitId(key))?.[index]
    if (source === undefined) return Promise.reject(new Error('missing_koma_page_source'))
    const id = JSON.stringify([this.unitId(key), index])
    const pending = this.sourceRequests.get(id)
    if (pending !== undefined && !forceReload) return pending
    const request = fetchAndCacheReaderRemoteSource(source, this.requestContext, forceReload)
    this.sourceRequests.set(id, request)
    const retire = (): void => {
      if (this.sourceRequests.get(id) === request) this.sourceRequests.delete(id)
    }
    void request.then(retire, retire)
    return request
  }

  async preload(page: ReaderPage, cancellation: ReaderCancellation): Promise<void> {
    cancellation.check()
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined || source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
      console.info(`[KomaReaderPreload] source=${page.sourceIndex} result=local-skip`)
      return
    }
    await this.sourceFile(page.unit, page.sourceIndex)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    console.info(`[KomaReaderPreload] source=${page.sourceIndex} result=ready`)
  }

  async imageShareSource(target: ReaderImageShareTarget,
    cancellation: ReaderCancellation): Promise<KomaReaderLabImageShareSource> {
    const source = this.sources.get(this.unitId(target.unit.key))?.[target.sourceIndex]
    if (source === undefined || source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || source.imageUri.length === 0) {
      throw new Error('koma_lab_share_source_unavailable')
    }
    cancellation.check()
    const filePath = await this.sourceFile(target.unit.key, target.sourceIndex)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    return new KomaReaderLabImageShareSource(filePath,
      `${target.unit.title} ${target.sourceIndex + 1}`.trim().slice(0, 96))
  }

  private recoverableImageFailure(error: Error): boolean {
    // Authentication/challenge, TLS, invalid source data and decode errors need their own handling.
    return [2300006, 2300007, 2300018, 2300028, 2300052, 2300055, 2300056, 2300999]
      .some((code: number): boolean => error.message === `reader_remote_image_fetch_failed_${code}`) ||
      [404, 408, 410, 500, 502, 503, 504]
        .some((status: number): boolean => error.message === `reader_remote_image_http_${status}`)
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation, forceReload: boolean): Promise<ReaderAsset> {
    cancellation.check()
    const prior = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (forceReload && prior?.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE &&
      prior.sourceRuntimeId !== undefined && prior.sourceRuntimeId.length > 0) {
      await this.refreshPageSources(page.unit, cancellation)
    }
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined) throw new Error('unsupported_koma_lab_asset')
    if (source.kind === ReaderPageRenderKind.URI_PLACEHOLDER ||
      source.uri === 'source-placeholder://chapter' || source.imageUri.length === 0) {
      const config = this.configs.get(this.unitId(page.unit))
      throw KomaReaderFailure.sourceError(config?.sourceFailureReason, config?.sourceFailure)
    }
    let filePath: string
    try {
      filePath = await this.sourceFile(page.unit, page.sourceIndex, forceReload)
    } catch (error) {
      cancellation.check()
      if (this.closed) throw new Error('closed_koma_reader')
      const retryId = JSON.stringify([this.unitId(page.unit), page.key])
      if (forceReload || source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE ||
        source.sourceRuntimeId === undefined || source.sourceRuntimeId.length === 0 ||
        this.automaticPageRetries.has(retryId) || !this.recoverableImageFailure(error as Error)) {
        throw error as Error
      }
      this.automaticPageRetries.add(retryId)
      DiagnosticLogger.info('reader', 'automatic_page_retry', 'attempt=1 reason=' + (error as Error).message)
      const unitId = this.unitId(page.unit)
      if (!this.automaticallyRefreshedUnits.has(unitId)) {
        this.automaticallyRefreshedUnits.add(unitId)
        await this.refreshPageSources(page.unit, cancellation)
      } else {
        // Neighbour failures join the same fresh plan, rather than refetching the chapter per image.
        await this.refreshingSources.get(unitId)
      }
      cancellation.check()
      if (this.closed) throw new Error('closed_koma_reader')
      filePath = await this.sourceFile(page.unit, page.sourceIndex, true)
    }
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    if (kind === 'thumbnail') return this.thumbnails.load(filePath, cancellation)
    const asset = new ReaderAsset(filePath.startsWith('/') ? `file://${filePath}` : filePath,
      () => {}, new KomaReaderFileInformation(filePath))
    asset.crop = new ReaderFileCropSource(filePath,
      `${page.unit.scope}:${page.unit.work}:${page.unit.unit}:${page.key}`)
    return asset
  }

  close(): void {
    this.closed = true
    this.preparationCancellation.cancel()
    this.preparingUnits.clear()
    this.sourceRequests.clear()
    this.refreshingSources.clear()
    this.automaticallyRefreshedUnits.clear()
    this.automaticPageRetries.clear()
    this.thumbnails.close()
    this.configs.clear()
    this.sources.clear()
    this.preparedUnits.clear()
  }
}

export class KomaReaderLabImageShareSource {
  uri: string
  title: string
  constructor(uri: string, title: string) {
    this.uri = uri
    this.title = title
  }
}
