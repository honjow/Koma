import {
  ReaderCatalog, ReaderAssetProvider, ReaderPreloadHost, ReaderUnitKey, ReaderUnit, ReaderPage,
  ReaderCancellation, ReaderAsset, ReaderAssetKind,
  ReaderImageInformation, ReaderImageInformationSource, ReaderImageShareTarget,
  ReaderAssetFailure, ReaderAssetFailureClassifier,
} from '@reader-kit/core'
import { KomaReaderFailure } from './KomaReaderFailure'
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
  private closed: boolean = false
  private filesDir: string
  private thumbnails: KomaReaderLabThumbnailProvider
  private catalogHost: KomaReaderCatalogHost | null

  private unitId(key: ReaderUnitKey): string { return JSON.stringify([key.scope, key.work, key.unit]) }

  constructor(filesDir: string, cacheDir: string, catalogHost: KomaReaderCatalogHost | null = null) {
    this.filesDir = filesDir
    this.thumbnails = new KomaReaderLabThumbnailProvider(cacheDir)
    this.catalogHost = catalogHost
    const payload = new AppFilesLibraryStorePersistenceAdapter(filesDir).load()
    if (payload !== undefined) hydrateLibraryStoreFromJson(this.library, payload)
    configureReaderOfflineDownloads(filesDir)
    if (filesDir.length > 0) configureReaderRemoteImageCache(`${filesDir}/reader-image-cache`)
  }

  initialKey(work: string, unit: string): ReaderUnitKey {
    const hosted = this.catalogHost?.initial(work, unit) ?? null
    if (hosted !== null && hosted.comicId === work && hosted.chapterId === unit && hosted.totalPages > 0) {
      return new ReaderUnitKey('koma-local', work, unit)
    }
    const comic = this.library.getComic(work)
    const chapter = unit.length > 0 ? unit : (comic?.chapters[0]?.id ?? '')
    return new ReaderUnitKey('koma-local', work, chapter)
  }

  async open(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    const prepared = this.preparedUnits.get(this.unitId(key))
    return prepared !== undefined ? prepared.copy() : this.prepare(key, cancellation)
  }

  /** Host preparation leaves the active reader untouched; open consumes this metadata without repeating I/O. */
  async prepare(key: ReaderUnitKey, cancellation: ReaderCancellation): Promise<ReaderUnit> {
    cancellation.check()
    if (this.closed || key.scope !== 'koma-local') throw new Error('invalid_koma_reader_scope')
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
    return config.chapterIds.map((chapterId: string): KomaReaderLabChapterChoice => {
      const index = config.chapterIds.indexOf(chapterId)
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

  async preload(page: ReaderPage, cancellation: ReaderCancellation): Promise<void> {
    cancellation.check()
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined || source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
      console.info(`[KomaReaderPreload] source=${page.sourceIndex} result=local-skip`)
      return
    }
    await fetchAndCacheReaderRemoteSource(source)
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
    const filePath = await fetchAndCacheReaderRemoteSource(source)
    cancellation.check()
    if (this.closed) throw new Error('closed_koma_reader')
    return new KomaReaderLabImageShareSource(filePath,
      `${target.unit.title} ${target.sourceIndex + 1}`.trim().slice(0, 96))
  }

  async load(page: ReaderPage, kind: ReaderAssetKind, cancellation: ReaderCancellation, _forceReload: boolean): Promise<ReaderAsset> {
    cancellation.check()
    const source = this.sources.get(this.unitId(page.unit))?.[page.sourceIndex]
    if (source === undefined) throw new Error('unsupported_koma_lab_asset')
    if (source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || source.imageUri.length === 0) {
      throw new Error('koma_lab_page_source_unavailable')
    }
    const filePath = await fetchAndCacheReaderRemoteSource(source)
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
