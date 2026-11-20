import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'
import { buffer, taskpool } from '@kit.ArkTS'
import { isAvifFileType } from './ImageFileContent'

export type RemoteImageCacheHeaders = Record<string, string>
export type RemoteImageDownloadProgress = (loaded: number, total: number) => void

/** Share a file and its latest byte count with consumers joining an in-flight request. */
export class RemoteImageFileRequest {
  readonly file: Promise<string>
  private listeners: Set<RemoteImageDownloadProgress> = new Set<RemoteImageDownloadProgress>()
  private loaded: number = 0
  private total: number = 0

  constructor(start: (report: RemoteImageDownloadProgress) => Promise<string>) {
    this.file = start((loaded: number, total: number): void => {
      this.loaded = loaded
      this.total = total
      this.listeners.forEach((listener: RemoteImageDownloadProgress): void => { listener(loaded, total) })
    })
  }

  observe(listener: RemoteImageDownloadProgress): () => void {
    this.listeners.add(listener)
    if (this.total > 0) listener(this.loaded, this.total)
    return (): void => { this.listeners.delete(listener) }
  }

  wait(listener?: RemoteImageDownloadProgress): Promise<string> {
    if (listener === undefined) return this.file
    return this.file.finally(this.observe(listener))
  }
}

export const DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES: number = 500 * 1024 * 1024
const REMOTE_IMAGE_CACHE_SCHEMA_VERSION: number = 1
const REMOTE_IMAGE_CACHE_DIR_NAME: string = 'reader-remote-image-cache'
const REMOTE_IMAGE_CACHE_MANIFEST_NAME: string = 'manifest.v1.json'
const READER_CACHE_WRITE_SETTLE_MS: number = 400
const EVICT_UNLINK_BATCH: number = 8

export interface RemoteImageCacheManifestEntry {
  key: string
  url: string
  path: string
  size: number
  lastAccessAt: number
  avif?: boolean
}

export interface RemoteImageCacheStats {
  totalBytes: number
  entryCount: number
}

interface RemoteImageCacheManifestDocument {
  schemaVersion: number
  entries: RemoteImageCacheManifestEntry[]
}

export interface ReaderCachedPageFiles {
  imagePath?: string
  metadataPath?: string
  metadataText?: string
}

interface ReaderCacheFileAvailability {
  image: boolean
  metadata: boolean
  metadataText?: string
}

@Concurrent
function checkReaderCacheFiles(imagePath: string, metadataPath: string): ReaderCacheFileAvailability {
  const image = fs.accessSync(imagePath)
  const metadata = image && metadataPath.length > 0 && fs.accessSync(metadataPath)
  return { image, metadata, metadataText: metadata ? fs.readTextSync(metadataPath, { encoding: 'utf-8' }) : undefined }
}

async function readerCacheFileAvailability(imagePath: string, metadataPath: string): Promise<ReaderCacheFileAvailability> {
  try {
    return await taskpool.execute(checkReaderCacheFiles, imagePath, metadataPath) as ReaderCacheFileAvailability
  } catch (_error) {
    const image = await fs.access(imagePath)
    const metadata = image && metadataPath.length > 0 && await fs.access(metadataPath)
    return { image, metadata, metadataText: metadata ? await fs.readText(metadataPath) : undefined }
  }
}

function normalizeSeparator(value: string): string {
  return value.replace(/\\/g, '/')
}

function trimTrailingSlash(value: string): string {
  let normalized = normalizeSeparator(value).trim()
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1)
  }
  return normalized
}

function joinSandboxPath(parent: string, child: string): string {
  const left = trimTrailingSlash(parent)
  const right = normalizeSeparator(child).replace(/^\/+/, '').replace(/\/+$/, '')
  return right.length === 0 ? left : `${left}/${right}`
}

@Concurrent
async function writeBytes(path: string, bytes: ArrayBuffer): Promise<void> {
  const tempPath = `${path}.tmp`
  let file: fs.File | undefined = undefined
  try {
    // Keep a previously published complete image until its replacement is complete.
    file = await fs.open(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    const written = await fs.write(file.fd, bytes)
    if (written !== bytes.byteLength) throw new Error('Incomplete image cache write')
    await fs.close(file)
    file = undefined
    if ((await fs.stat(tempPath)).size !== bytes.byteLength) {
      throw new Error('Incomplete image cache file')
    }
    await fs.rename(tempPath, path)
  } catch (_error) {
    try {
      if (await fs.access(tempPath)) await fs.unlink(tempPath)
    } catch (_cleanupError) {
    }
    throw _error as Error
  } finally {
    if (file !== undefined) {
      try {
        await fs.close(file)
      } catch (_closeError) {
      }
    }
  }
}

function stableHeaderValue(value: string | undefined): string {
  return value === undefined ? '' : value
}

function stableHeadersKey(headers: RemoteImageCacheHeaders | undefined): string {
  if (headers === undefined) {
    return ''
  }
  const names = Object.keys(headers).sort()
  if (names.length === 0) {
    return ''
  }
  return names.map((name: string) => `${name.toLocaleLowerCase()}=${stableHeaderValue(headers[name])}`).join('\n')
}

function readUrlSource(url: string): string {
  const schemeIndex = url.indexOf('://')
  if (schemeIndex < 0) {
    return 'remote'
  }
  const rest = url.slice(schemeIndex + 3)
  const slashIndex = rest.indexOf('/')
  return slashIndex < 0 ? rest : rest.slice(0, slashIndex)
}

function createStableCacheHash(value: string): string {
  let hashA = 2166136261
  let hashB = 2166136261 ^ 0x9e3779b9
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    hashA = Math.imul((hashA ^ code) >>> 0, 16777619) >>> 0
    hashB = Math.imul((hashB ^ (code + index)) >>> 0, 16777619) >>> 0
  }
  return `${hashA.toString(16).padStart(8, '0')}${hashB.toString(16).padStart(8, '0')}`
}

function cacheKeyFor(url: string, headers: RemoteImageCacheHeaders | undefined, cacheKeySeed?: string): string {
  if (cacheKeySeed !== undefined && cacheKeySeed.trim().length > 0) {
    return createStableCacheHash(`seed\n${cacheKeySeed.trim()}`)
  }
  const source = readUrlSource(url)
  return createStableCacheHash(`${source}\n${url}\n${stableHeadersKey(headers)}`)
}

function extensionForUrl(url: string): string {
  const withoutRef = url.split('?')[0].split('#')[0].toLocaleLowerCase()
  const lastSegment = withoutRef.split('/').pop() ?? ''
  const dotIndex = lastSegment.lastIndexOf('.')
  if (dotIndex < 0 || dotIndex === lastSegment.length - 1) {
    return 'img'
  }
  const extension = lastSegment.slice(dotIndex + 1).replace(/[^a-z0-9]/g, '')
  return extension.length === 0 ? 'img' : extension
}

function safeParseManifest(payload: string): RemoteImageCacheManifestDocument {
  const parsed = JSON.parse(payload) as RemoteImageCacheManifestDocument
  if (parsed.schemaVersion !== REMOTE_IMAGE_CACHE_SCHEMA_VERSION || !Array.isArray(parsed.entries)) {
    throw new Error('Unsupported remote image cache manifest')
  }
  return parsed
}

export function formatRemoteImageCacheSize(totalBytes: number): string {
  if (totalBytes < 1024) {
    return `${totalBytes} B`
  }
  const kib = totalBytes / 1024
  if (kib < 1024) {
    return `${kib.toFixed(kib < 10 ? 1 : 0)} KB`
  }
  const mib = kib / 1024
  if (mib < 1024) {
    return `${mib.toFixed(mib < 10 ? 1 : 0)} MB`
  }
  const gib = mib / 1024
  return `${gib.toFixed(gib < 10 ? 1 : 0)} GB`
}

export class RemoteImageCacheStore {
  private readonly rootDir: string
  private readonly manifestPath: string
  private readonly trackAvif: boolean
  private readonly coalesceAccessWrites: boolean
  private entries: Map<string, RemoteImageCacheManifestEntry> = new Map<string, RemoteImageCacheManifestEntry>()
  private totalBytes: number = 0
  private accessWriteTimer: number = -1
  private accessDirty: boolean = false
  private manifestWritePaused: boolean = false

  private operationTail: Promise<void> = Promise.resolve()
  private imageRequests: Map<string, RemoteImageFileRequest> = new Map<string, RemoteImageFileRequest>()
  private reloadRequests: Map<string, RemoteImageFileRequest> = new Map<string, RemoteImageFileRequest>()
  private evictionPaused: boolean = false
  private evictionPending: boolean = false
  private pendingEvictionMaxBytes: number = 0
  private pendingEvictionPreservedPaths: string[] = []
  private resumeEviction: (() => void) | null = null

  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const next = this.operationTail.then(operation, operation)
    this.operationTail = next.then((): void => {}, (): void => {})
    return next
  }

  private setEntry(entry: RemoteImageCacheManifestEntry): void {
    this.totalBytes += entry.size - (this.entries.get(entry.key)?.size ?? 0)
    this.entries.set(entry.key, entry)
  }

  private removeEntry(key: string): void {
    this.totalBytes -= this.entries.get(key)?.size ?? 0
    this.entries.delete(key)
  }

  constructor(cacheDir: string, directoryName: string = REMOTE_IMAGE_CACHE_DIR_NAME, coalesceAccessWrites: boolean = false) {
    this.rootDir = joinSandboxPath(cacheDir, directoryName)
    this.manifestPath = joinSandboxPath(this.rootDir, REMOTE_IMAGE_CACHE_MANIFEST_NAME)
    this.trackAvif = directoryName === REMOTE_IMAGE_CACHE_DIR_NAME
    this.coalesceAccessWrites = this.trackAvif || coalesceAccessWrites
    this.ensureRoot()
    this.restore()
  }

  /** Only the cache can identify the format of bytes it published at this path. */
  avifAtPath(path: string): boolean | undefined {
    if (!path.startsWith(this.rootDir + '/')) return undefined
    const leaf = path.slice(this.rootDir.length + 1)
    const entry = this.entries.get(leaf.split('.')[0])
    return entry?.path === path && typeof entry.avif === 'boolean' ? entry.avif : undefined
  }

  get(url: string, headers?: RemoteImageCacheHeaders, cacheKeySeed?: string): Promise<string | undefined> {
    return this.enqueue(() => this.getNow(cacheKeyFor(url, headers, cacheKeySeed)))
  }

  /** Keep existence checks authoritative after OS cache eviction. Return any
   * small processing descriptor with the body lookup to avoid a second UI callback. */
  getReaderPage(imageSeed: string, metadataSeed?: string): Promise<ReaderCachedPageFiles> {
    return this.enqueue(async (): Promise<ReaderCachedPageFiles> => {
      const imageKey = cacheKeyFor('', undefined, imageSeed)
      const image = this.entries.get(imageKey)
      if (image === undefined) return {}
      const metadataKey = metadataSeed === undefined ? '' : cacheKeyFor('source-image-processing.json', undefined,
        metadataSeed)
      const metadata = this.entries.get(metadataKey)
      const availability = await readerCacheFileAvailability(image.path, metadata?.path ?? '')
      const imagePath = await this.finishLookup(imageKey, image, availability.image)
      if (imagePath === undefined || metadata === undefined) return { imagePath }
      const metadataPath = await this.finishLookup(metadataKey, metadata, availability.metadata)
      return { imagePath, metadataPath, metadataText: metadataPath === undefined ? undefined : availability.metadataText }
    })
  }

  /** Remove one corrupt cached image while keeping the manifest and quota consistent. */
  invalidatePath(path: string): Promise<boolean> {
    return this.enqueue(() => this.invalidatePathNow(path))
  }

  private async invalidatePathNow(path: string): Promise<boolean> {
    const normalized = normalizeSeparator(path)
    const prefix = `${this.rootDir}/`
    if (!normalized.startsWith(prefix)) return false
    const leaf = normalized.slice(prefix.length)
    if (leaf.length === 0 || leaf.includes('/') || leaf === '.' || leaf === '..' ||
      leaf === REMOTE_IMAGE_CACHE_MANIFEST_NAME) return false
    let dirty = false
    this.entries.forEach((entry: RemoteImageCacheManifestEntry, key: string): void => {
      if (entry.path !== normalized) return
      this.removeEntry(key)
      dirty = true
    })
    try {
      if (await fs.access(normalized)) await fs.unlink(normalized)
    } catch (_error) {
      if (await fs.access(normalized)) return false
    }
    if (dirty) await this.persist()
    return true
  }

  private async getNow(key: string): Promise<string | undefined> {
    const entry = this.entries.get(key)
    if (entry !== undefined && this.trackAvif) {
      // Preload and processed readers also use single-file hits as a page
      // joins the visible window. Keep those checks on the same worker.
      const availability = await readerCacheFileAvailability(entry.path, '')
      return this.finishLookup(key, entry, availability.image)
    }
    return this.finishLookup(key, entry, entry !== undefined && await fs.access(entry.path))
  }

  private async finishLookup(key: string, entry: RemoteImageCacheManifestEntry | undefined,
    exists: boolean): Promise<string | undefined> {
    if (entry === undefined) {
      console.info(`[ReaderCache] step=miss key=${key}`)
      return Promise.resolve(undefined)
    }
    if (!exists) {
      this.removeEntry(key)
      await this.persist()
      console.info(`[ReaderCache] step=miss key=${key}`)
      return Promise.resolve(undefined)
    }
    entry.lastAccessAt = Date.now()
    if (this.coalesceAccessWrites) this.scheduleManifestWrite()
    else await this.persist()
    console.info(`[ReaderCache] step=hit key=${key} size=${entry.size}`)
    return Promise.resolve(entry.path)
  }

  /** Body, thumbnail and preload share the same cache identity and complete file publication. */
  getOrFetch(
    url: string,
    headers: RemoteImageCacheHeaders | undefined,
    fetchBytes: (report: RemoteImageDownloadProgress) => Promise<ArrayBuffer>,
    cacheKeySeed?: string,
    forceReload: boolean = false,
    onProgress?: RemoteImageDownloadProgress,
  ): Promise<string> {
    const key = cacheKeyFor(url, headers, cacheKeySeed)
    // Reader requests carry the URL and headers resolved for this download.
    // Use that same identity for coalescing, lookup and publication, including
    // plain remote reader URLs that do not have a source-provided seed.
    const reuseKey = this.trackAvif || (cacheKeySeed !== undefined && cacheKeySeed.trim().length > 0)
    const refreshing = this.reloadRequests.get(key)
    if (refreshing !== undefined) return refreshing.wait(onProgress)
    const pending = this.imageRequests.get(key)
    if (pending !== undefined && !forceReload) return pending.wait(onProgress)
    const request = new RemoteImageFileRequest(async (report: RemoteImageDownloadProgress): Promise<string> => {
      if (forceReload && pending !== undefined) {
        // Retire the old publisher first; it must not overwrite the explicit replacement later.
        try { await pending.file } catch (_error) {}
      }
      if (!forceReload) {
        const cached = await (reuseKey ? this.enqueue(() => this.getNow(key)) :
          this.get(url, headers, cacheKeySeed))
        if (cached !== undefined && cached.length > 0) return cached
      }
      const bytes = await fetchBytes(report)
      return reuseKey ? this.enqueue(() => this.putNow(key, url, bytes)) :
        this.put(url, headers, bytes, cacheKeySeed)
    })
    this.imageRequests.set(key, request)
    if (forceReload) this.reloadRequests.set(key, request)
    const release = (): void => {
      if (this.imageRequests.get(key) === request) this.imageRequests.delete(key)
      if (this.reloadRequests.get(key) === request) this.reloadRequests.delete(key)
    }
    // Release both success and failure; a failed shared request must permit an ordinary retry.
    void request.file.then(release, release)
    return request.wait(onProgress)
  }

  put(url: string, headers: RemoteImageCacheHeaders | undefined, bytes: ArrayBuffer, cacheKeySeed?: string): Promise<string> {
    return this.enqueue(() => this.putNow(cacheKeyFor(url, headers, cacheKeySeed), url, bytes))
  }

  private async putNow(key: string, url: string, bytes: ArrayBuffer): Promise<string> {
    const filePath = joinSandboxPath(this.rootDir, `${key}.${extensionForUrl(url)}`)
    if (this.trackAvif) {
      // The reader can finish several downloads during one fling. Keep their
      // file-open, write, stat and rename callbacks on the worker, and publish
      // the index only after the same atomic file commit succeeds. The caller
      // still owns its buffer (for example a source processor can reuse it).
      const task = new taskpool.Task(writeBytes, filePath, bytes)
      task.setCloneList([bytes])
      await taskpool.execute(task)
    } else {
      await writeBytes(filePath, bytes)
    }
    this.setEntry({
      key,
      url,
      path: filePath,
      size: bytes.byteLength,
      lastAccessAt: Date.now(),
      avif: this.trackAvif ? isAvifFileType(bytes, Math.min(bytes.byteLength, 128)) : undefined,
    })
    this.scheduleManifestWrite()
    return filePath
  }

  evictIfOver(maxBytes: number, preservedPath?: string | string[]): Promise<void> {
    return this.enqueue(() => this.evictIfOverNow(maxBytes, preservedPath))
  }

  /**
   * The live continuous reader publishes many image files while the List is
   * moving. Directory reconciliation and unlink callbacks return to the UI
   * thread, so keep their maintenance demand outside the gesture and run the
   * latest quota once interaction settles. Explicit cache management still
   * calls evictIfOver directly.
   */
  maintainIfOver(maxBytes: number, preservedPath?: string | string[]): void {
    if (maxBytes <= 0 || this.totalBytes <= maxBytes) return
    this.pendingEvictionMaxBytes = maxBytes
    const protectedPaths = typeof preservedPath === 'string' ? [preservedPath] : preservedPath ?? []
    this.pendingEvictionPreservedPaths = Array.from(new Set(
      this.pendingEvictionPreservedPaths.concat(protectedPaths)))
    this.evictionPending = true
    if (!this.evictionPaused) void this.runPendingEviction()
  }

  setEvictionPaused(paused: boolean): void {
    this.evictionPaused = paused
    if (paused) return
    const resume = this.resumeEviction
    this.resumeEviction = null
    if (resume !== null) resume()
    if (this.evictionPending) void this.runPendingEviction()
  }

  private async runPendingEviction(): Promise<void> {
    if (this.evictionPaused) {
      await new Promise<void>((resume: () => void): void => { this.resumeEviction = resume })
    }
    if (!this.evictionPending) return
    this.evictionPending = false
    const maxBytes = this.pendingEvictionMaxBytes
    const preserved = this.pendingEvictionPreservedPaths
    this.pendingEvictionPreservedPaths = []
    await this.evictIfOver(maxBytes, preserved)
  }

  private async evictIfOverNow(maxBytes: number, preservedPath?: string | string[]): Promise<void> {
    if (maxBytes <= 0 || this.totalBytes <= maxBytes) {
      return
    }
    // A cache insert below quota doesn't need to touch any existing file.
    // Under pressure, reconcile once with the directory (including OS eviction).
    const files = new Set<string>(await fs.listFile(this.rootDir, { recursion: false, listNum: 0 }))
    const rows: RemoteImageCacheManifestEntry[] = []
    let dirty = false
    for (const entry of this.entries.values()) {
      if (files.has(entry.path.slice(this.rootDir.length + 1))) rows.push(entry)
      else { this.removeEntry(entry.key); dirty = true }
    }
    rows.sort((left: RemoteImageCacheManifestEntry, right: RemoteImageCacheManifestEntry) => {
      return left.lastAccessAt - right.lastAccessAt
    })
    let removedSinceYield = 0
    for (const entry of rows) {
      if (this.totalBytes <= maxBytes) {
        break
      }
      if (typeof preservedPath === 'string' ? entry.path === preservedPath : preservedPath?.includes(entry.path)) continue
      try {
        await fs.unlink(entry.path)
      } catch (_err) {
        if (await fs.access(entry.path)) continue
      }
      this.removeEntry(entry.key)
      dirty = true
      removedSinceYield += 1
      if (removedSinceYield >= EVICT_UNLINK_BATCH) {
        removedSinceYield = 0
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 0) })
      }
      console.info(`[ReaderCache] step=evict key=${entry.key} size=${entry.size} total=${this.totalBytes}`)
    }
    if (dirty) await this.persist()
  }

  stats(): Promise<RemoteImageCacheStats> {
    return this.enqueue(() => this.statsNow())
  }

  private async statsNow(): Promise<RemoteImageCacheStats> {
    let totalBytes = 0
    let entryCount = 0
    const staleKeys: string[] = []
    this.entries.forEach((entry: RemoteImageCacheManifestEntry) => {
      if (fs.accessSync(entry.path)) {
        totalBytes += entry.size
        entryCount += 1
      } else {
        staleKeys.push(entry.key)
      }
    })
    if (staleKeys.length > 0) {
      staleKeys.forEach((key: string) => {
        this.removeEntry(key)
      })
      await this.persist()
    }
    return {
      totalBytes,
      entryCount,
    }
  }

  clear(): Promise<void> {
    return this.enqueue(() => this.clearNow())
  }

  private async clearNow(): Promise<void> {
    this.cancelAccessWrite()
    this.accessDirty = false
    const paths: string[] = []
    this.entries.forEach((entry: RemoteImageCacheManifestEntry) => {
      if (!paths.includes(entry.path)) {
        paths.push(entry.path)
      }
    })
    let clearFailed = false
    try {
      const listFileOptions: ListFileOptions = {
        recursion: false,
        listNum: 0,
      }
      const listedEntries = await fs.listFile(this.rootDir, listFileOptions)
      listedEntries.forEach((entry: string) => {
        const normalizedEntry = normalizeSeparator(entry)
        if (normalizedEntry.length === 0 ||
          normalizedEntry === REMOTE_IMAGE_CACHE_MANIFEST_NAME ||
          normalizedEntry.includes('/') ||
          normalizedEntry === '.' ||
          normalizedEntry === '..') {
          return
        }
        const entryPath = joinSandboxPath(this.rootDir, normalizedEntry)
        if (!paths.includes(entryPath)) {
          paths.push(entryPath)
        }
      })
    } catch (_err) {
      clearFailed = true
    }
    for (const path of paths) {
      try {
        if (fs.accessSync(path)) {
          await fs.unlink(path)
        }
      } catch (_err) {
        clearFailed = true
      }
    }
    this.entries.forEach((entry: RemoteImageCacheManifestEntry, key: string) => {
      if (!fs.accessSync(entry.path)) this.removeEntry(key)
    })
    if (clearFailed) {
      await this.persist()
      throw new Error('remote_image_cache_clear_failed')
    }
    this.entries.clear()
    this.totalBytes = 0
    try {
      if (fs.accessSync(this.manifestPath)) {
        await fs.unlink(this.manifestPath)
      }
    } catch (_err) {
      throw new Error('remote_image_cache_clear_failed')
    }
  }

  private ensureRoot(): void {
    if (!fs.accessSync(this.rootDir)) {
      fs.mkdirSync(this.rootDir, true)
    }
  }

  private restore(): void {
    if (!fs.accessSync(this.manifestPath)) {
      return
    }
    try {
      const document = safeParseManifest(fs.readTextSync(this.manifestPath, { encoding: 'utf-8' }))
      document.entries.forEach((entry: RemoteImageCacheManifestEntry) => {
        const prefix = `${this.rootDir}/`
        const leaf = entry.path.startsWith(prefix) ? entry.path.slice(prefix.length) : ''
        // A cache manifest never grants ownership of downloads or external files.
        if (entry.key.length > 0 && entry.size > 0 && leaf.length > 0 &&
          !leaf.includes('/') && leaf !== '.' && leaf !== '..' && leaf !== REMOTE_IMAGE_CACHE_MANIFEST_NAME) {
          this.setEntry(entry)
        }
      })
    } catch (_err) {
      this.entries.clear()
      this.totalBytes = 0
    }
  }

  private cancelAccessWrite(): void {
    if (this.accessWriteTimer < 0) return
    clearTimeout(this.accessWriteTimer)
    this.accessWriteTimer = -1
  }

  setManifestWritePaused(paused: boolean): void {
    this.manifestWritePaused = paused
    // The reader pauses writes while gestures move the List; resuming starts
    // one settled write that commits every hit and publication since then.
    if (!paused && this.accessDirty && this.accessWriteTimer < 0) this.scheduleManifestWrite()
  }

  private scheduleManifestWrite(): void {
    this.accessDirty = true
    if (this.manifestWritePaused) return
    this.cancelAccessWrite()
    this.accessWriteTimer = setTimeout((): void => {
      this.accessWriteTimer = -1
      // Hits and new publications both update the in-memory manifest
      // immediately; only the manifest file can wait. One settled write
      // commits the full payload. An immediate persist from eviction,
      // invalidation or clear cancels this timer first, so those paths stay
      // fully synchronous.
      void this.enqueue(async (): Promise<void> => {
        if (!this.accessDirty || this.accessWriteTimer >= 0 || this.manifestWritePaused) return
        await this.persist()
      }).catch((): void => {
        // A metadata failure must not fail a hit or a publication. Retry on
        // the next access, publication or structural write.
      })
    }, READER_CACHE_WRITE_SETTLE_MS)
  }

  private manifestPayload(): string {
    const document: RemoteImageCacheManifestDocument = {
      schemaVersion: REMOTE_IMAGE_CACHE_SCHEMA_VERSION,
      entries: Array.from(this.entries.values()),
    }
    return JSON.stringify(document)
  }

  private async persist(): Promise<void> {
    this.cancelAccessWrite()
    const temporary = this.manifestPath + '.tmp'
    const payload = this.manifestPayload()
    try {
      const file = await fs.open(temporary, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      try {
        if (await fs.write(file.fd, payload, { encoding: 'utf-8' }) !== buffer.byteLength(payload, 'utf-8')) {
          throw new Error('Incomplete image cache access write')
        }
      } finally {
        await fs.close(file)
      }
      await fs.rename(temporary, this.manifestPath)
      this.accessDirty = false
    } catch (_error) {
      try { await fs.unlink(temporary) } catch (_error) {}
      throw _error as Error
    }
  }
}
