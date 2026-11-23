import { SourceCommentsTarget } from '../sourceRuntime/SourceCommentsContract'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { BannerFilterMode, ImageRuleSnapshot } from '../model/ImageBannerRules'
import { sourceChapterOrderFor, appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
import { AppStrings } from '../i18n/AppStrings'
import { firstReaderChapter } from '../model/ReaderChapterSequence'
import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import {
  ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderProcessingCancellation, ReaderAsset, ReaderAssetKind,
  ReaderImageInformation, ReaderImageInformationSource, ReaderImageShareTarget,
  ReaderAssetFailure, ReaderAssetFailureClassifier, ReaderAssetNotice,
} from '@reader-kit/core'
import { KomaReaderFailure } from './KomaReaderFailure'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ReaderFileInformation } from '@reader-kit/ui'
import { KomaReaderCropSource } from './KomaReaderCropSource'
import { InMemoryLibraryStore } from '../model/LibraryStore'
import { Comic, ComicSourceKind, isDeferredFolderArchiveChapter } from '../model/ComicModels'
import { localLibraryFolderRootUriFromComic } from '../model/LocalLibraryFolderContract'
import { activateLocalLibraryFolderAccess } from '../model/LocalLibraryFolderAccessService'
import { openLocalFolderArchive, removeLocalFolderArchive } from '../import/LocalFolderArchiveReader'
import { ComicArchiveBookmark } from '../import/ComicArchiveBookmarkParser'
import { comicArchiveExtractionRoot, readComicArchiveBookmarks } from '../import/ComicArchiveBookmarks'
import { parsePdfPageUri, readPdfBookmarks } from '../import/PdfPageService'
import { AppFilesLibraryStorePersistenceAdapter, hydrateLibraryStoreFromJson } from '../model/LibraryPersistence'
import { ReaderSessionConfig, cloneReaderSessionConfig, createReaderSessionConfigFromComic } from '../model/ReaderSessionStore'
import { OfflineDownloadStore } from '../model/OfflineDownloadStore'
import { RemoteImageDownloadProgress, RemoteImageFileRequest } from '../model/RemoteImageCacheStore'
import { komaContentStorageBase, komaRuntimeStorageKey } from '../model/KomaContentStorage'
import { createKomaReaderLabOfflineConfig } from './KomaReaderLabOfflineConfig'
import { KomaReaderLabThumbnailProvider } from './KomaReaderLabThumbnailProvider'
import { KomaReaderCatalogHost } from './KomaReaderCatalogHost'
import {
  ReaderPageRenderKind, ReaderPageRenderSource, configureReaderOfflineDownloads, configureReaderRemoteImageCache,
  createReaderPageRenderSources, fetchAndCacheReaderRemoteSource, prepareReaderDisplayImage,
} from '../model/ReaderPageSourceAdapter'

const MAX_AUTOMATIC_PAGE_RETRIES: number = 3
const AUTOMATIC_PAGE_RETRY_DELAY_MS: number[] = [300, 800, 1500]

export class KomaReaderLabChapterChoice {
  key: ReaderUnitKey
  title: string
  pageIndex?: number

  constructor(key: ReaderUnitKey, title: string, pageIndex?: number) {
    this.key = key
    this.title = title
    this.pageIndex = pageIndex
  }
}

/** Read only the cached file header off the UI thread; native decode remains the authority. */
@Concurrent
async function readPreloadedImageSize(path: string): Promise<string> {
  let source: image.ImageSource | undefined = undefined
  try {
    source = image.createImageSource(path.startsWith('file://') ? path.substring(7) : path)
    const info = await source.getImageInfo()
    return `${info.size.width},${info.size.height}`
  } finally {
    if (source !== undefined) await source.release()
  }
}

class KomaReaderPreloadedSize {
  source: ReaderPageRenderSource
  width: number
  height: number
  constructor(source: ReaderPageRenderSource, width: number, height: number) {
    this.source = source
    this.width = width
    this.height = height
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

export interface KomaReaderChapterPosition {
  index: number
  total: number
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
  private archiveBookmarks: Map<string, ComicArchiveBookmark[]> = new Map()
  private sources: Map<string, ReaderPageRenderSource[]> = new Map()
  private preparedUnits: Map<string, ReaderUnit> = new Map()
  private preparingUnits: Map<string, Promise<ReaderUnit>> = new Map()
  private preparingSequences: Set<string> = new Set()
  private resolvedSequences: Map<string, string[]> = new Map()
  onSequenceReady: () => void = (): void => {}
  private preparationCancellation: ReaderCancellation = new ReaderCancellation()
  private sourceRequests: Map<string, RemoteImageFileRequest> = new Map()
  private preloadedSizes: Map<string, KomaReaderPreloadedSize> = new Map()
  /** First-open format evidence: dimensions read from the page's own download. */
  onPageSize: ((unitId: string, index: number, width: number, height: number) => void) | undefined = undefined
  onAutomaticPageSize: ((page: ReaderPage) => void) | undefined = undefined
  automaticPaging: () => boolean = (): boolean => false
  private preloadedSizeVersions: Map<string, number> = new Map()
  private refreshingSources: Map<string, Promise<void>> = new Map()
  private automaticallyRefreshedUnits: Set<string> = new Set()
  private automaticPageRetries: Map<string, number> = new Map()
  private bannerPolicy: () => BannerFilterMode
  private ruleSnapshot: Promise<ImageRuleSnapshot>
  private presentationRevision: number = 0
  private chapterPreloadEnabled: boolean
  private cropStrength: () => string
  private remotePreloadAllowed: () => boolean
  private closed: boolean = false
  private catalogFailureText: string = ''
  private catalogLoginSource: string = ''
  private catalogLoginUnit: ReaderUnitKey | null = null
  onAuthenticationRequested: ((sourceId: string, unit: ReaderUnitKey, current: () => boolean, reopenCatalog: boolean) => Promise<boolean>) | null = null

  catalogFailureMessage(): string { return this.catalogFailureText }
  catalogAuthenticationSource(): string { return this.catalogLoginSource }
  catalogAuthenticationTarget(): ReaderUnitKey | null { return this.catalogLoginUnit?.copy() ?? null }
  invalidateAuthenticationCatalog(unit: ReaderUnitKey): void {
    const id = this.unitId(unit)
    this.preparedUnits.delete(id); this.sources.delete(id); this.configs.delete(id); this.sourceRequests.clear()
  }

  private authenticationSource(error: Error, unit: ReaderUnitKey): string {
    if (!(error instanceof SourceRuntimeError) ||
      (error.diagnostic.code !== 'auth_required' && error.diagnostic.reason !== 'auth_required') ||
      (error.diagnostic.status !== 0 && error.diagnostic.status !== 401)) return ''
    const config = this.configs.get(this.unitId(unit)) ?? this.catalogHost?.initial(unit.work, unit.unit)
    const id = config?.sourceRuntimeId ?? this.readerWork(unit.work)?.sourceRuntimeId ?? ''
    const entry = appSourceRuntimeRegistry.lookup(id).entry
    return entry?.enabled === true && entry.authentication !== undefined ? id : ''
  }

  private authenticationNotice(error: Error, page: ReaderPage, kind: ReaderAssetKind,
    cancellation: ReaderCancellation, reopenCatalog: boolean = false): ReaderAsset | null {
    const sourceId = this.authenticationSource(error, page.unit)
    const action = this.onAuthenticationRequested
    if (sourceId.length === 0 || kind !== 'original' || action === null) return null
    const unit = page.unit.copy()
    const current = (): boolean => !this.closed && !cancellation.isCancelled()
    const asset = new ReaderAsset('')
    asset.setNotice(new ReaderAssetNotice('koma-source-login', AppStrings.get('source_login'),
      error instanceof SourceRuntimeError ? error.userText : AppStrings.get('source_login_required'), AppStrings.get('source_login')),
      async (): Promise<boolean> => current() ? await action(sourceId, unit, current, reopenCatalog) : false)
    return asset
  }
  private requestContext?: common.UIAbilityContext
  private filesDir: string
  private cacheDir: string
  private localArchiveRoots: string[] = []
  private offlineStorageBase: string
  private runtimeKey: string
  private thumbnails: KomaReaderLabThumbnailProvider
  private catalogHost: KomaReaderCatalogHost | null

  private unitId(key: ReaderUnitKey): string { return JSON.stringify([key.scope, key.work, key.unit]) }

  constructor(filesDir: string, cacheDir: string, thumbnailHeightPx: number, catalogHost: KomaReaderCatalogHost | null = null,
    requestContext?: common.UIAbilityContext, chapterPreloadEnabled: boolean = false,
    cropStrength: () => string = (): string => 'standard',
    remotePreloadAllowed: () => boolean = (): boolean => true,
    bannerPolicy: () => BannerFilterMode = (): BannerFilterMode => 'source') {
    this.bannerPolicy = bannerPolicy
    this.ruleSnapshot = requestContext === undefined ? Promise.resolve<ImageRuleSnapshot>({ schemaVersion: 1, records: [] }) :
      ImageRuleStore.forContext(requestContext).pinned()
    this.chapterPreloadEnabled = chapterPreloadEnabled
    this.cropStrength = cropStrength
    this.remotePreloadAllowed = remotePreloadAllowed
    this.requestContext = requestContext
    this.filesDir = filesDir
    this.cacheDir = cacheDir
    this.offlineStorageBase = requestContext === undefined ? filesDir : komaContentStorageBase(requestContext)
    this.runtimeKey = requestContext === undefined ? filesDir : komaRuntimeStorageKey(requestContext)
    this.thumbnails = new KomaReaderLabThumbnailProvider(cacheDir, thumbnailHeightPx)
    this.catalogHost = catalogHost
    // The ordinary reader already has a work resolver. A compatibility
    // snapshot can scan every RDB page row on the UI thread before first paint.
    // Keep it only for the standalone Lab that has no app catalog host.
    if (catalogHost === null) {
      const payload = new AppFilesLibraryStorePersistenceAdapter(filesDir).load()
      if (payload !== undefined) hydrateLibraryStoreFromJson(this.library, payload)
    }
    configureReaderOfflineDownloads(this.offlineStorageBase, this.runtimeKey)
    if (cacheDir.length > 0) configureReaderRemoteImageCache(cacheDir)
  }

  private readerWork(work: string): Comic | undefined {
    return this.catalogHost === null ? this.library.getComic(work) : this.catalogHost.work(work)
  }

  initialKey(work: string, unit: string): ReaderUnitKey {
    const hosted = this.catalogHost?.initial(work, unit) ?? null
    if (hosted !== null && hosted.comicId === work && hosted.chapterId === unit && hosted.totalPages > 0) {
      return new ReaderUnitKey('koma-local', work, unit)
    }
    const comic = this.readerWork(work)
    const chapter = unit.length > 0 ? unit : (firstReaderChapter(comic?.chapters ?? [], sourceChapterOrderFor(comic?.sourceRuntimeId))?.id ?? '')
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
    this.catalogLoginSource = ''; this.catalogLoginUnit = null
    try {
      return await this.prepareShared(key, cancellation)
    } catch (error) {
      cancellation.check()
      if (this.closed) throw new Error('closed_koma_reader')
      this.catalogFailureText = KomaReaderFailure.catalogMessage(error as Error)
      this.catalogLoginSource = this.authenticationSource(error as Error, key)
      this.catalogLoginUnit = this.catalogLoginSource.length > 0 ? key.copy() : null
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
    if (hosted !== null) {
      await this.prepareArchiveBookmarks(key, hosted, cancellation)
      return this.installConfig(key, hosted, cancellation)
    }
    const comic = this.readerWork(key.work)
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
    const chapter = comic.chapters.find((item) => item.id === key.unit)
    if (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER && chapter !== undefined &&
      isDeferredFolderArchiveChapter(chapter)) {
      const opened = await openLocalFolderArchive(this.cacheDir, chapter.sourcePath)
      if (this.closed || cancellation.isCancelled()) {
        await removeLocalFolderArchive(opened.rootDir)
        cancellation.check()
        throw new Error('closed_koma_reader')
      }
      this.localArchiveRoots.push(opened.rootDir)
      config.totalPages = opened.pages.length
      config.pageUris = opened.pages.map((page) => page.uri)
      config.pageIds = opened.pages.map((_page, index) => `${key.unit}-page-${index + 1}`)
      if (opened.bookmarks.length > 0) this.archiveBookmarks.set(this.unitId(key), opened.bookmarks)
    }
    if (config.totalPages <= 0 && config.chapterId.length > 0) {
      try {
        const validation = new OfflineDownloadStore(this.offlineStorageBase, this.runtimeKey).validateDownloadedChapter(
          comic.id, key.unit, { validateContentHash: false })
        config = createKomaReaderLabOfflineConfig(config, validation)
      } catch (_error) {
        // An unavailable manifest leaves the original empty catalog unchanged.
      }
    }
    if (!Number.isSafeInteger(config.totalPages) || config.totalPages < 1) {
      throw new Error('missing_koma_chapter_pages')
    }
    await this.prepareArchiveBookmarks(key, config, cancellation)
    return this.installConfig(key, config, cancellation)
  }

  private async prepareArchiveBookmarks(key: ReaderUnitKey, config: ReaderSessionConfig,
    cancellation: ReaderCancellation): Promise<void> {
    if (config.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE && config.deferredLocalArchive !== true) return
    if (this.archiveBookmarks.has(this.unitId(key))) return
    const pdf = parsePdfPageUri(config.pageUris[0] ?? '')
    if (pdf !== undefined) {
      const bookmarks = await readPdfBookmarks(pdf.path)
      cancellation.check()
      if (!this.closed && bookmarks.length > 0) this.archiveBookmarks.set(this.unitId(key), bookmarks)
      return
    }
    const root = comicArchiveExtractionRoot(config.pageUris[0] ?? '')
    if (root === undefined) return
    const bookmarks = await readComicArchiveBookmarks(root, config.totalPages, config.pageUris)
    cancellation.check()
    if (!this.closed && bookmarks.length > 0) this.archiveBookmarks.set(this.unitId(key), bookmarks)
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
    const sequence = this.resolvedSequences.get(this.unitId(key))
    if (sequence !== undefined) {
      config.continuationChapterIds = sequence.slice()
      config.sourceChapterChronologyPending = false
    }
    this.configs.set(this.unitId(key), config)
    this.sources.set(this.unitId(key), sources)
    this.preparedUnits.set(this.unitId(key), unit)
    if (config.sourceRuntimeId !== undefined && (config.continuationChapterIds === undefined ||
      config.sourceChapterChronologyPending === true)) {
      void this.prepareSequence(key.copy())
    }
    return unit.copy()
  }

  private async prepareSequence(key: ReaderUnitKey): Promise<void> {
    const work = JSON.stringify([key.scope, key.work])
    if (this.closed || this.catalogHost === null || this.preparingSequences.has(work)) return
    this.preparingSequences.add(work)
    try {
      const catalog = await this.catalogHost.sequence(key.copy(), this.preparationCancellation)
      if (this.closed || catalog === undefined) return
      const sequence = catalog.continuation
      if (sequence !== undefined && sequence.includes(key.unit)) {
        sequence.forEach((chapterId: string): void => {
          const id = this.unitId(new ReaderUnitKey(key.scope, key.work, chapterId))
          this.resolvedSequences.set(id, sequence)
          const config = this.configs.get(id)
          if (config !== undefined) config.continuationChapterIds = sequence.slice()
        })
      }
      // Publish the manual choices without rebuilding the current chapter's
      // source list or restarting its images.
      const config = this.configs.get(this.unitId(key))
      if (config !== undefined) config.sourceChapterChronologyPending = false
      const chapterIds = catalog.chapterIds
      const chapterIndex = chapterIds?.indexOf(key.unit) ?? -1
      if (config !== undefined && chapterIds !== undefined && chapterIndex >= 0) {
        config.chapterIds = chapterIds.slice()
        config.chapterTitles = catalog.chapterTitles?.slice()
        config.chapterTitle = catalog.chapterTitles?.[chapterIndex] ?? config.chapterTitle
      }
      this.onSequenceReady()
    } catch (_error) {
      if (!this.closed) DiagnosticLogger.warn('reader', 'chapter_sequence_unavailable', 'reason=chapter_sequence_unavailable')
    } finally {
      // This is an in-flight gate, not a permanent failure cache. A canceled
      // verification or transient network failure must remain retryable.
      this.preparingSequences.delete(work)
    }
  }

  chapterCatalogPending(unit: ReaderUnitKey): boolean {
    const config = this.configs.get(this.unitId(unit))
    return config?.sourceRuntimeId !== undefined && (config.sourceChapterChronologyPending === true ||
      (config.continuationChapterIds === undefined && config.chapterIds.length <= 1))
  }

  async retryChapterCatalog(unit: ReaderUnitKey): Promise<void> {
    if (this.chapterCatalogPending(unit)) await this.prepareSequence(unit.copy())
  }

  spreadMetadata(unit: ReaderUnit): ReaderPage[] {
    const config = this.configs.get(this.unitId(unit.key))
    if (config === undefined) return []
    const boundaries: ReaderPage[] = []
    for (let index = 0; index < unit.pageCount; index++) {
      const width = config.pageWidths?.[index] ?? 0
      const height = config.pageHeights?.[index] ?? 0
      if (!Number.isFinite(width) || !Number.isFinite(height) || height <= 0 || width < height) continue
      const page = new ReaderPage(unit.key, config.pageIds?.[index] ?? `${unit.key.unit}:${index}`, index)
      page.width = width
      page.height = height
      boundaries.push(page)
    }
    return boundaries
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
    const warmedSize = this.preloadedSizes.get(JSON.stringify([this.unitId(unit.key), index]))
    if (warmedSize !== undefined && warmedSize.source === source && (page.width <= 0 || page.height <= 0)) {
      page.width = warmedSize.width
      page.height = warmedSize.height
    }
    page.thumbnail.available = source !== undefined &&
      source.kind !== ReaderPageRenderKind.URI_PLACEHOLDER &&
      (source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST || source.imageUri.length > 0)
    return page
  }

  adjacent(unit: ReaderUnit, direction: 'next' | 'previous'): ReaderUnitKey | null {
    const config = this.configs.get(this.unitId(unit.key))
    if (config === undefined) return null
    // Online adjacency shares preloading's verified edition boundary. The manual
    // picker has a forward presentation too, and retains every entry inside
    // the detail page's selected edition/language scope.
    const chapterIds = this.readingChapterIds(config)
    const index = chapterIds.indexOf(unit.key.unit)
    const target = index + (direction === 'next' ? 1 : -1)
    if (index < 0 || target < 0 || target >= chapterIds.length) return null
    return new ReaderUnitKey(unit.key.scope, unit.key.work, chapterIds[target])
  }

  private readingChapterIds(config: ReaderSessionConfig): string[] {
    return config.continuationChapterIds ??
      (config.sourceRuntimeId === undefined ? config.chapterIds : [])
  }

  /** The toolbar counts the same forward sequence as adjacent(), including its
   * edition boundary. Picker order is only a presentation choice. A pending
   * catalog must not turn a resume placeholder into a misleading 1 / 1. */
  chapterReadingPosition(unit: ReaderUnitKey): KomaReaderChapterPosition | undefined {
    const config = this.configs.get(this.unitId(unit))
    if (config === undefined || this.chapterCatalogPending(unit)) return undefined
    const ids = this.readingChapterIds(config)
    const index = ids.indexOf(unit.unit)
    return index < 0 ? undefined : { index, total: ids.length }
  }

  /** Host-owned chapter catalog projection for the optional picker; reader-kit never sees these titles. */
  chapterChoices(unit: ReaderUnitKey): KomaReaderLabChapterChoice[] {
    const config = this.configs.get(this.unitId(unit))
    if (config === undefined) return []
    // The host already applies the detail edition/language selection. Keep
    // every manual choice in that scope, rather than replacing this catalog
    // with the narrower verified continuation sequence.
    const choices: KomaReaderLabChapterChoice[] = []
    config.chapterIds.forEach((chapterId: string, index: number): void => {
      const bookmarks = chapterId === unit.unit ? (this.archiveBookmarks.get(this.unitId(unit)) ?? []) : []
      if (config.chapterIds.length !== 1 || bookmarks.length === 0) {
        choices.push(new KomaReaderLabChapterChoice(
          new ReaderUnitKey(unit.scope, unit.work, chapterId), config.chapterTitles?.[index] ?? '',
        ))
      }
      if (chapterId === unit.unit) {
        bookmarks.forEach((bookmark: ComicArchiveBookmark): void => {
          choices.push(new KomaReaderLabChapterChoice(unit.copy(), bookmark.title, bookmark.pageIndex))
        })
      }
    })
    return choices
  }

  // The title leaf reads only current metadata; page changes must not clone the full catalog.
  workTitle(unit: ReaderUnitKey): string {
    return this.configs.get(this.unitId(unit))?.title ?? this.readerWork(unit.work)?.title ?? ''
  }
  chapterTitle(unit: ReaderUnitKey): string {
    return this.configs.get(this.unitId(unit))?.chapterTitle ??
      this.readerWork(unit.work)?.chapters.find((chapter) => chapter.id === unit.unit)?.title ?? ''
  }

  chapterCommentsTarget(unit: ReaderUnitKey): SourceCommentsTarget | undefined {
    const config = this.configs.get(this.unitId(unit))
    const comic = this.readerWork(unit.work)
    const sourceId = config?.sourceRuntimeId ?? comic?.sourceRuntimeId
    if (!sourceId || !unit.unit) return undefined
    const prefix = sourceId + ':'
    const mangaId = comic?.remoteResourceId ?? (unit.work.startsWith(prefix) ? unit.work.substring(prefix.length) : '')
    if (!mangaId) return undefined
    return { sourceId, mangaId, chapterId: unit.unit, subtitle: this.chapterTitle(unit) }
  }

  /** Catalog preparation is session-local and does not imply native image presentation. */
  chapterPrepared(unit: ReaderUnitKey): boolean {
    return this.preparedUnits.has(this.unitId(unit))
  }

  sessionConfig(unit: ReaderUnitKey): ReaderSessionConfig | null {
    const config = this.configs.get(this.unitId(unit))
    return config === undefined ? null : cloneReaderSessionConfig(config)
  }

  /** Spend the requested page budget across host-owned continuation chapters. */
  async preloadNextUnit(unit: ReaderUnit, depth: number, cancellation: ReaderCancellation,
    onPrepared?: (unit: ReaderUnit, indexes: number[], precedingPages: number) => void): Promise<void> {
    cancellation.check()
    if (!this.chapterPreloadEnabled || this.closed) return
    const config = this.configs.get(this.unitId(unit.key))
    if (!this.remotePreloadAllowed() && config?.sourceKind !== ComicSourceKind.LOCAL_FOLDER &&
      config?.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE) return
    // Folder import already establishes the same chapter order used by adjacent().
    // It has no WASM edition/group metadata, so warm that existing local adjacency
    // without enabling or changing automatic navigation in the Legacy reader.
    // Online sources still require their explicitly verified continuation group.
    const sequence = config?.continuationChapterIds ??
      (config?.sourceKind === ComicSourceKind.LOCAL_FOLDER ? config.chapterIds : undefined)
    if (sequence === undefined) return
    const index = sequence.indexOf(unit.key.unit)
    if (index < 0 || !Number.isFinite(depth) || depth < 0) return
    const budget = Math.floor(depth)
    let remaining = budget
    let precedingPages = 0
    const warming: Promise<Error | undefined>[] = []
    for (let chapter = index + 1; chapter < sequence.length; chapter += 1) {
      cancellation.check()
      if (!this.remotePreloadAllowed() && config?.sourceKind !== ComicSourceKind.LOCAL_FOLDER &&
        config?.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE) break
      const next = new ReaderUnitKey(unit.key.scope, unit.key.work, sequence[chapter])
      const prepared = await this.prepareShared(next, cancellation)
      const count = Math.min(remaining, prepared.pageCount)
      const indexes: number[] = []
      for (let page = 0; page < count; page += 1) indexes.push(page)
      onPrepared?.(prepared.copy(), indexes, precedingPages)
      if (count === 0) {
        console.info('[KomaReaderPreload] next_unit_catalog result=ready')
        return
      }
      // Resolve the next chapter while this chapter's images warm; a series
      // of single-page chapters must not wait for every image serially.
      const warm = async (): Promise<void> => {
        for (let page = 0; page < count; page += 1) {
          cancellation.check()
          const descriptor = await this.page(prepared, page, cancellation)
          await this.preload(descriptor, cancellation)
        }
      }
      warming.push(warm().then((): Error | undefined => undefined, (error: Error): Error | undefined => error))
      remaining -= count
      precedingPages += count
      if (remaining === 0) break
    }
    const results = await Promise.all(warming)
    cancellation.check()
    const failure = results.find((error: Error | undefined): boolean => error !== undefined)
    if (failure !== undefined) throw failure
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

  async refreshImageRules(): Promise<void> {
    this.ruleSnapshot = this.requestContext === undefined ? Promise.resolve<ImageRuleSnapshot>({ schemaVersion: 1, records: [] }) :
      ImageRuleStore.forContext(this.requestContext).pinned()
    await this.ruleSnapshot
    this.invalidatePresentation()
  }

  invalidatePresentation(): void {
    this.presentationRevision += 1
    this.sourceRequests.clear()
    this.preloadedSizes.clear()
    this.preloadedSizeVersions.clear()
  }

  /** Share descriptor resolution and image transport before the file-cache layer. */
  private sourceFile(key: ReaderUnitKey, index: number, forceReload: boolean = false,
    onProgress?: RemoteImageDownloadProgress): Promise<string> {
    if (this.closed) return Promise.reject(new Error('closed_koma_reader'))
    const source = this.sources.get(this.unitId(key))?.[index]
    if (source === undefined) return Promise.reject(new Error('missing_koma_page_source'))
    const id = JSON.stringify([this.unitId(key), index])
    if (forceReload) {
      this.preloadedSizes.delete(id)
      this.preloadedSizeVersions.set(id, (this.preloadedSizeVersions.get(id) ?? 0) + 1)
    }
    const pending = this.sourceRequests.get(id)
    if (pending !== undefined && !forceReload) return pending.wait(onProgress)
    const revision = this.presentationRevision
    const sizeVersion = this.preloadedSizeVersions.get(id) ?? 0
    const policy = this.bannerPolicy()
    const request = new RemoteImageFileRequest(async (report: RemoteImageDownloadProgress): Promise<string> => {
      const trace = DiagnosticLogger.begin('reader_asset', 'file', `page=${index + 1} force=${forceReload}`)
      try {
        const snapshot = await this.ruleSnapshot
        trace.info('rules_ready', '')
        const path = await fetchAndCacheReaderRemoteSource(source, this.requestContext, forceReload, { snapshot, policy },
          (width: number, height: number): void => {
            if (!this.closed && revision === this.presentationRevision &&
              (this.preloadedSizeVersions.get(id) ?? 0) === sizeVersion &&
              this.sources.get(this.unitId(key))?.[index] === source) {
              this.onPageSize?.(this.unitId(key), index, width, height)
              if (this.automaticPaging()) this.publishPreparedSize(key, index, source, width, height)
            }
          }, report)
        if (revision !== this.presentationRevision || policy !== this.bannerPolicy()) throw new Error('reader_source_page_processing_stale')
        trace.finish('completed')
        return path
      } catch (error) {
        trace.finish('failed', DiagnosticLogger.errorSummary(error as Error))
        throw error as Error
      }
    })
    this.sourceRequests.set(id, request)
    const retire = (): void => {
      if (this.sourceRequests.get(id) === request) this.sourceRequests.delete(id)
    }
    void request.file.then(retire, retire)
    return request.wait(onProgress)
  }

  private publishPreparedSize(key: ReaderUnitKey, index: number, source: ReaderPageRenderSource,
    width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return
    const unit = this.unitId(key)
    const id = JSON.stringify([unit, index])
    const previous = this.preloadedSizes.get(id)
    if (previous?.source === source && previous.width === width && previous.height === height) return
    this.preloadedSizes.set(id, new KomaReaderPreloadedSize(source, width, height))
    const config = this.configs.get(unit)
    if (config === undefined || !this.automaticPaging()) return
    const page = new ReaderPage(key, config.pageIds?.[index] ?? `${key.unit}:${index}`, index)
    page.width = width
    page.height = height
    this.onAutomaticPageSize?.(page)
  }

  private async prepareImageSize(page: ReaderPage, filePath: string, cancellation: ReaderCancellation): Promise<void> {
    if (page.width > 0 && page.height > 0) return
    const unitId = this.unitId(page.unit)
    const source = this.sources.get(unitId)?.[page.sourceIndex]
    const sizeKey = JSON.stringify([unitId, page.sourceIndex])
    if (source === undefined || this.preloadedSizes.get(sizeKey)?.source === source) return
    const sizeVersion = this.preloadedSizeVersions.get(sizeKey) ?? 0
    const revision = this.presentationRevision
    try {
      const size = await taskpool.execute<[string], string>(readPreloadedImageSize, filePath)
      cancellation.check()
      if (this.closed || revision !== this.presentationRevision ||
        (this.preloadedSizeVersions.get(sizeKey) ?? 0) !== sizeVersion ||
        this.sources.get(unitId)?.[page.sourceIndex] !== source) return
      const dimensions = size.split(',')
      this.publishPreparedSize(page.unit, page.sourceIndex, source, Number(dimensions[0]), Number(dimensions[1]))
    } catch (_error) {
      // Native image decoding remains the fallback when no header size is available.
      cancellation.check()
    }
  }

  async preload(page: ReaderPage, cancellation: ReaderCancellation): Promise<void> {
    cancellation.check()
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined || source.kind === ReaderPageRenderKind.URI_PLACEHOLDER) {
      return
    }
    if (!this.remotePreloadAllowed() && (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE ||
      source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST)) return
    const filePath = await this.sourceFile(page.unit, page.sourceIndex)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    await this.prepareImageSize(page, filePath, cancellation)
    console.info(`[KomaReaderPreload] source=${page.sourceIndex} result=ready`)
  }

  unitUsesRemoteImages(unit: ReaderUnitKey): boolean {
    return this.sources.get(this.unitId(unit))?.some((source: ReaderPageRenderSource): boolean =>
      source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE || source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST) === true
  }

  async imageShareSource(target: ReaderImageShareTarget,
    cancellation: ReaderCancellation): Promise<KomaReaderLabImageShareSource> {
    const source = this.sources.get(this.unitId(target.unit.key))?.[target.sourceIndex]
    if (source === undefined || source.kind === ReaderPageRenderKind.URI_PLACEHOLDER ||
      (source.kind !== ReaderPageRenderKind.SOURCE_TEXT_REQUEST && source.imageUri.length === 0)) {
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
      [408, 429, 500, 502, 503, 504]
        .some((status: number): boolean => error.message === `reader_remote_image_http_${status}`)
  }

  private delayAutomaticPageRetry(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void): void => {
      setTimeout((): void => { resolve() }, milliseconds)
    })
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation, forceReload: boolean,
    onProgress?: RemoteImageDownloadProgress): Promise<ReaderAsset> {
    cancellation.check()
    const prior = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (forceReload && prior?.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE &&
      prior.sourceRuntimeId !== undefined && prior.sourceRuntimeId.length > 0) {
      await this.refreshPageSources(page.unit, cancellation)
    }
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined) throw new Error('unsupported_koma_lab_asset')
    if (cancellation instanceof ReaderProcessingCancellation && cancellation.priority === 'prefetch' &&
      !this.remotePreloadAllowed() && (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE ||
        source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST)) {
      cancellation.cancel()
      cancellation.check()
    }
    if (source.kind === ReaderPageRenderKind.URI_PLACEHOLDER ||
      source.uri === 'source-placeholder://chapter' ||
      (source.kind !== ReaderPageRenderKind.SOURCE_TEXT_REQUEST && source.imageUri.length === 0)) {
      const config = this.configs.get(this.unitId(page.unit))
      const error = KomaReaderFailure.sourceError(config?.sourceFailureReason, config?.sourceFailure)
      const notice = this.authenticationNotice(error, page, kind, cancellation, true)
      if (notice !== null) return notice
      throw error
    }
    const retryId = JSON.stringify([this.unitId(page.unit), page.key])
    let retries = this.automaticPageRetries.get(retryId) ?? 0
    let filePath = ''
    let progressTotal: number = 0
    const report = onProgress === undefined ? undefined : (loaded: number, total: number): void => {
      if (this.closed || cancellation.isCancelled()) return
      progressTotal = total
      onProgress(loaded, total)
    }
    while (true) {
      try {
        filePath = await this.sourceFile(page.unit, page.sourceIndex, forceReload || retries > 0, report)
        break
      } catch (error) {
        cancellation.check()
        if (this.closed) throw new Error('closed_koma_reader')
        const notice = this.authenticationNotice(error as Error, page, kind, cancellation)
        if (notice !== null) return notice
        if (forceReload || source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE ||
          source.sourceRuntimeId === undefined || source.sourceRuntimeId.length === 0 ||
          retries >= MAX_AUTOMATIC_PAGE_RETRIES || !this.recoverableImageFailure(error as Error)) {
          throw error as Error
        }
        retries += 1
        if (progressTotal > 0) report?.(0, progressTotal)
        this.automaticPageRetries.set(retryId, retries)
        DiagnosticLogger.info('reader', 'automatic_page_retry',
          `attempt=${retries}/${MAX_AUTOMATIC_PAGE_RETRIES} delay=${AUTOMATIC_PAGE_RETRY_DELAY_MS[retries - 1]} reason=${(error as Error).message}`)
        const unitId = this.unitId(page.unit)
        try {
          if (retries === 1 && !this.automaticallyRefreshedUnits.has(unitId)) {
            this.automaticallyRefreshedUnits.add(unitId)
            await this.refreshPageSources(page.unit, cancellation)
          } else {
            // Neighbour failures join the same fresh plan, rather than refetching the chapter per image.
            await this.refreshingSources.get(unitId)
          }
        } catch (refreshError) {
          cancellation.check()
          if (!(refreshError instanceof SourceRuntimeError) || refreshError.diagnostic.kind !== 'network') {
            throw refreshError as Error
          }
          // The current chapter plan still contains the same page. A temporary
          // catalog failure must let an automatic retry use that address again.
        }
        cancellation.check()
        if (this.closed) throw new Error('closed_koma_reader')
        await this.delayAutomaticPageRetry(AUTOMATIC_PAGE_RETRY_DELAY_MS[retries - 1])
        cancellation.check()
      }
    }
    this.automaticPageRetries.delete(retryId)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    const displayPath = await prepareReaderDisplayImage(filePath, forceReload)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    if (kind === 'thumbnail') return this.thumbnails.load(displayPath, cancellation)
    if (this.automaticPaging()) await this.prepareImageSize(page, displayPath, cancellation)
    cancellation.check()
    const asset = new ReaderAsset(displayPath.startsWith('/') ? `file://${displayPath}` : displayPath,
      () => {}, new KomaReaderFileInformation(filePath))
    asset.saveUri = filePath.startsWith('/') ? `file://${filePath}` : filePath
    asset.crop = new KomaReaderCropSource(displayPath, this.cropStrength)
    return asset
  }

  close(): void {
    this.closed = true
    this.preparationCancellation.cancel()
    this.localArchiveRoots?.forEach((root: string): void => { void removeLocalFolderArchive(root) })
    this.localArchiveRoots = []
    this.preparingUnits.clear()
    this.preparingSequences.clear()
    this.resolvedSequences.clear()
    this.sourceRequests.clear()
    this.preloadedSizes.clear()
    this.preloadedSizeVersions.clear()
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
