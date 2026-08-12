import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { Comic, ComicId, ComicSourceKind } from './ComicModels'
import { ReaderSessionConfig } from './ReaderSessionStore'
import {
  DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  RemoteImageCacheHeaders,
  RemoteImageCacheStats,
  RemoteImageCacheStore,
  formatRemoteImageCacheSize,
} from './RemoteImageCacheStore'
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadStore,
} from './OfflineDownloadStore'
import {
  KavitaServerRecord,
  KomgaServerRecord,
  OpdsServerRecord,
  RemoteServerStore,
  WebDavServerRecord,
} from './RemoteServerStore'
import { KomgaHeaders } from '../remote/KomgaClient'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import { runSourceOperationFromBytes } from '../sourceRuntime/SourceRuntimeRunner'

@Concurrent
function executeReaderSourceImageRequestOperation(requestJson: string, wasmBytes: Uint8Array): string {
  return JSON.stringify(runSourceOperationFromBytes(requestJson, wasmBytes))
}

export interface ReaderRemoteImageCachePreferences {
  maxBytes: number
  autoCleanEnabled: boolean
}

export interface ReaderRemoteImageCacheStats extends RemoteImageCacheStats {
}

function emptyReaderImageCacheStats(): ReaderRemoteImageCacheStats {
  return {
    totalBytes: 0,
    entryCount: 0,
  }
}

export const DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES: ReaderRemoteImageCachePreferences = {
  maxBytes: DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  autoCleanEnabled: true,
}

export const READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS: number[] = [
  100 * 1024 * 1024,
  250 * 1024 * 1024,
  500 * 1024 * 1024,
  1024 * 1024 * 1024,
  2048 * 1024 * 1024,
]

const READER_REMOTE_IMAGE_CACHE_PREFERENCES_STORE_NAME: string = 'koma_reader_remote_image_cache_v1'
const READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY: string = 'readerRemoteImageCache.maxBytes'
const READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY: string = 'readerRemoteImageCache.autoCleanEnabled'

export class ReaderRemoteImageCachePreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<ReaderRemoteImageCachePreferences> {
    const store = await this.preferences()
    const maxBytes = await store.get(
      READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY,
      DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes,
    ) as number
    const autoCleanEnabled = await store.get(
      READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY,
      DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled,
    ) as boolean
    return {
      maxBytes: maxBytes > 0 ? maxBytes : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes,
      autoCleanEnabled,
    }
  }

  async saveMaxBytes(maxBytes: number): Promise<ReaderRemoteImageCachePreferences> {
    const current = await this.load()
    const next: ReaderRemoteImageCachePreferences = {
      maxBytes: maxBytes > 0 ? maxBytes : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes,
      autoCleanEnabled: current.autoCleanEnabled,
    }
    const store = await this.preferences()
    await store.put(READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY, next.maxBytes)
    await store.flush()
    return next
  }

  async saveAutoCleanEnabled(enabled: boolean): Promise<ReaderRemoteImageCachePreferences> {
    const current = await this.load()
    const next: ReaderRemoteImageCachePreferences = {
      maxBytes: current.maxBytes,
      autoCleanEnabled: enabled,
    }
    const store = await this.preferences()
    await store.put(READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY, enabled)
    await store.flush()
    return next
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_REMOTE_IMAGE_CACHE_PREFERENCES_STORE_NAME)
  }
}

let readerImageCacheStore: RemoteImageCacheStore | null = null
let readerImageCacheMaxBytes: number = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes
let readerImageCacheAutoCleanEnabled: boolean = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled

export function configureReaderRemoteImageCache(
  cacheDir: string,
  maxBytes?: number,
  autoCleanEnabled?: boolean,
): void {
  if (maxBytes !== undefined && maxBytes > 0) {
    readerImageCacheMaxBytes = maxBytes
  }
  if (autoCleanEnabled !== undefined) {
    readerImageCacheAutoCleanEnabled = autoCleanEnabled
  }
  if (cacheDir.trim().length === 0) {
    return
  }
  if (readerImageCacheStore === null) {
    readerImageCacheStore = new RemoteImageCacheStore(cacheDir)
  }
  if (readerImageCacheAutoCleanEnabled) {
    void readerImageCacheStore.evictIfOver(readerImageCacheMaxBytes)
  }
}

export function getReaderRemoteImageCacheStats(): Promise<ReaderRemoteImageCacheStats> {
  if (readerImageCacheStore === null) {
    return Promise.resolve(emptyReaderImageCacheStats())
  }
  return readerImageCacheStore.stats()
}

export function clearReaderRemoteImageCache(): Promise<ReaderRemoteImageCacheStats> {
  if (readerImageCacheStore === null) {
    return Promise.resolve(emptyReaderImageCacheStats())
  }
  return readerImageCacheStore.clear().then(() => {
    return readerImageCacheStore?.stats() ?? emptyReaderImageCacheStats()
  })
}

export function formatReaderRemoteImageCacheSize(totalBytes: number): string {
  return formatRemoteImageCacheSize(totalBytes)
}

let readerUrlPrefix: string = ''
let readerRemoteHeaders: KomgaHeaders | null = null

class ResolvedReaderImageHeaders {
  urlPrefix: string
  headers: KomgaHeaders | null

  constructor(urlPrefix: string, headers: KomgaHeaders | null) {
    this.urlPrefix = urlPrefix
    this.headers = headers
  }
}

function httpHeadersForReaderRequest(extraHeaders?: RemoteImageCacheHeaders): Object {
  const values: Record<string, string> = {}
  if (readerRemoteHeaders !== null) {
    const headers = readerRemoteHeaders
    if (headers.authorization !== undefined) {
      values['Authorization'] = headers.authorization
    }
    if (headers.accept !== undefined) {
      values['Accept'] = headers.accept
    }
    if (headers.contentType !== undefined) {
      values['Content-Type'] = headers.contentType
    }
    if (headers.xApiKey !== undefined) {
      values['X-API-Key'] = headers.xApiKey
    }
    if (headers.xAuthToken !== undefined) {
      values['X-Auth-Token'] = headers.xAuthToken
    }
  }
  if (extraHeaders !== undefined) {
    Object.keys(extraHeaders).forEach((name: string) => {
      const value = extraHeaders[name]
      if (name.trim().length > 0 && value.length > 0) {
        values[name] = value
      }
    })
  }
  if (Object.keys(values).length === 0) {
    return new EmptyHttpHeader()
  }
  return values as Object
}

class EmptyHttpHeader {
}

function remoteImageCacheHeaders(extraHeaders?: RemoteImageCacheHeaders): RemoteImageCacheHeaders | undefined {
  const out: RemoteImageCacheHeaders = {}
  if (readerRemoteHeaders !== null) {
    const headers = readerRemoteHeaders
    if (headers.authorization !== undefined) {
      out['Authorization'] = headers.authorization
    }
    if (headers.accept !== undefined) {
      out['Accept'] = headers.accept
    }
    if (headers.contentType !== undefined) {
      out['Content-Type'] = headers.contentType
    }
    if (headers.xApiKey !== undefined) {
      out['X-API-Key'] = headers.xApiKey
    }
    if (headers.xAuthToken !== undefined) {
      out['X-Auth-Token'] = headers.xAuthToken
    }
  }
  if (extraHeaders !== undefined) {
    Object.keys(extraHeaders).forEach((name: string) => {
      const value = extraHeaders[name]
      if (name.trim().length > 0 && value.length > 0) {
        out[name] = value
      }
    })
  }
  return Object.keys(out).length > 0 ? out : undefined
}

export function installReaderRemoteHeaders(urlPrefix: string, headers: KomgaHeaders): void {
  readerUrlPrefix = urlPrefix ?? ''
  readerRemoteHeaders = headers
}

function normalizeReaderUrl(url: string): string {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url
  }
  const prefix = readerUrlPrefix.trim()
  if (prefix.length === 0) {
    return url
  }
  const normalizedPrefix = prefix.endsWith('/') ? prefix : `${prefix}/`
  return `${normalizedPrefix}${url.replace(/^\/+/, '')}`
}

function resolveServerImageHeaders(
  context: common.UIAbilityContext,
  comic: Comic,
): Promise<ResolvedReaderImageHeaders> {
  const store = new RemoteServerStore(context)
  if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
    return store.loadKomga().then((record: KomgaServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getKomgaImageHeaders(record))
    })
  }
  if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
    return store.loadKavita().then((record: KavitaServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getKavitaImageHeaders(record))
    })
  }
  if (comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
    return store.loadWebDav().then((record: WebDavServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getWebDavImageHeaders(record))
    })
  }
  if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
    return store.loadOpds().then((record: OpdsServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.rootUrl, store.getOpdsImageHeaders(record))
    })
  }
  return Promise.resolve(new ResolvedReaderImageHeaders('', null))
}

export function installReaderRemoteHeadersForComic(
  context: common.UIAbilityContext,
  comic: Comic,
): Promise<void> {
  return resolveServerImageHeaders(context, comic).then((resolved) => {
    if (resolved.headers === null) {
      installReaderRemoteHeaders('', {})
      return
    }
    installReaderRemoteHeaders(resolved.urlPrefix, resolved.headers)
  })
}

function isRemoteHttpUrl(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('http://') || normalized.startsWith('https://')
}

function isLocalFileUri(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('file://') || normalized.startsWith('mock://')
}

async function downloadReaderRemoteBytes(url: string, extraHeaders?: RemoteImageCacheHeaders): Promise<ArrayBuffer> {
  const httpRequest = http.createHttp()
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      header: httpHeadersForReaderRequest(extraHeaders),
      readTimeout: 60000,
      connectTimeout: 30000,
    })
    if (response.responseCode !== 200) {
      console.warn(`[ReaderImage] step=http_status_failed status=${response.responseCode}`)
      throw new Error(`reader_remote_image_http_${response.responseCode}`)
    }
    return response.result as ArrayBuffer
  } catch (error) {
    const e = error as BusinessError
    console.warn(`[ReaderImage] step=http_request_failed code=${e.code === undefined ? 'unknown' : e.code}`)
    throw new Error(`reader_remote_image_fetch_failed_${e.code === undefined ? 'unknown' : e.code}`)
  } finally {
    httpRequest.destroy()
  }
}

export async function fetchAndCacheReaderRemoteImage(uri: string): Promise<string> {
  if (readerImageCacheStore === null) {
    throw new Error('reader_remote_image_cache_unconfigured')
  }
  const url = normalizeReaderUrl(uri)
  const cached = await readerImageCacheStore.get(url, remoteImageCacheHeaders())
  if (cached !== undefined && cached.length > 0) {
    return cached
  }
  const bytes = await downloadReaderRemoteBytes(url)
  return readerImageCacheStore.put(url, remoteImageCacheHeaders(), bytes)
}

function readerImageRequestForPage(pageId: string, url: string): string {
  const request: ReaderImageRuntimeRequest = {
    type: 'request',
    version: 1,
    requestId: `reader-image-${Date.now()}`,
    operation: 'get_image_request',
    sourceId: '',
    args: new ReaderImageRuntimeArgs(pageId, url),
    settings: emptySourceSettingsRecord(),
    hostHints: new ReaderImageRuntimeHostHints(),
  }
  return JSON.stringify(request)
}

function emptySourceSettingsRecord(): Record<string, Object> {
  return {} as Record<string, Object>
}

class ReaderImageRuntimeArgs {
  pageId: string
  url: string

  constructor(pageId: string, url: string) {
    this.pageId = pageId
    this.url = url
  }
}

class ReaderImageRuntimeHostHints {
  network: boolean
  imageStrategy: string

  constructor() {
    this.network = true
    this.imageStrategy = 'descriptor-or-url'
  }
}

interface ReaderImageRuntimeRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: ReaderImageRuntimeArgs
  settings: Record<string, Object>
  hostHints: ReaderImageRuntimeHostHints
}

class SourceImageRequestDescriptor {
  url: string
  headers: RemoteImageCacheHeaders | undefined

  constructor(url: string, headers?: RemoteImageCacheHeaders) {
    this.url = url
    this.headers = headers
  }
}

function parseSourceImageRequestHeaders(value: Object | undefined): RemoteImageCacheHeaders | undefined {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  const raw = value as Record<string, Object>
  const headers: RemoteImageCacheHeaders = {}
  Object.keys(raw).forEach((name: string) => {
    const headerValue = raw[name]
    if (name.trim().length > 0 && typeof headerValue === 'string' && headerValue.length > 0) {
      headers[name] = headerValue
    }
  })
  return Object.keys(headers).length > 0 ? headers : undefined
}

function parseSourceImageRequestDescriptor(payload: string): SourceImageRequestDescriptor | undefined {
  try {
    const document = JSON.parse(payload) as Record<string, Object>
    const data = document['data']
    if (data === undefined || data === null || typeof data !== 'object') {
      return undefined
    }
    const record = data as Record<string, Object>
    const imageRequest = record['imageRequest']
    if (imageRequest !== undefined && imageRequest !== null && typeof imageRequest === 'object') {
      const imageRecord = imageRequest as Record<string, Object>
      const url = imageRecord['url']
      if (typeof url === 'string' && url.length > 0) {
        return new SourceImageRequestDescriptor(url, parseSourceImageRequestHeaders(imageRecord['headers']))
      }
    }
    const directUrl = record['url']
    if (typeof directUrl === 'string' && directUrl.length > 0) {
      return new SourceImageRequestDescriptor(directUrl, parseSourceImageRequestHeaders(record['headers']))
    }
    return undefined
  } catch (_err) {
    return undefined
  }
}

async function resolveSourceRuntimeImageRequest(
  sourceRuntimeId: string,
  uri: string,
  sourceImageId: string,
): Promise<SourceImageRequestDescriptor | undefined> {
  const sourceId = sourceRuntimeId.trim()
  if (sourceId.length === 0) {
    return undefined
  }
  const lookup = appSourceRuntimeRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined || !lookup.entry.enabled) {
    return undefined
  }
  const requestJson = readerImageRequestForPage(sourceImageId, uri)
  const wasmBytes = new Uint8Array(lookup.entry.wasmBytes.byteLength)
  wasmBytes.set(lookup.entry.wasmBytes)
  let responseJson: string
  try {
    // Match the source detail/chapter path: WAMR stays on a TaskPool worker,
    // while the configured host HTTP bridge dispatches NetworkKit on the UI
    // runtime. Loading the NAPI module dynamically inside the worker bypassed
    // that established execution path and crashed on a ticketed image request.
    responseJson = await taskpool.execute(
      executeReaderSourceImageRequestOperation,
      requestJson,
      wasmBytes,
    ) as string
  } catch (_error) {
    return undefined
  }
  try {
    const response = JSON.parse(responseJson) as Record<string, Object>
    if (response['ok'] !== true) {
      return undefined
    }
  } catch (_error) {
    return undefined
  }
  return parseSourceImageRequestDescriptor(responseJson)
}

export async function fetchAndCacheSourceRuntimeRemoteImage(
  sourceRuntimeId: string,
  uri: string,
  sourceImageId: string,
): Promise<string> {
  if (readerImageCacheStore === null) {
    throw new Error('reader_remote_image_cache_unconfigured')
  }
  const sourceId = sourceRuntimeId.trim()
  if (sourceId.length === 0) {
    return fetchAndCacheReaderRemoteImage(uri)
  }
  const imageRequest = await resolveSourceRuntimeImageRequest(sourceId, uri, sourceImageId)
  if (imageRequest === undefined) {
    console.warn(`[ReaderImage] step=image_request_unavailable source=${sourceId} page=${sourceImageId}`)
    return fetchAndCacheReaderRemoteImage(uri)
  }
  const cacheHeaders = remoteImageCacheHeaders(imageRequest.headers)
  const cached = await readerImageCacheStore.get(imageRequest.url, cacheHeaders, `source:${sourceId}:${sourceImageId}`)
  if (cached !== undefined && cached.length > 0) {
    return cached
  }
  const bytes = await downloadReaderRemoteBytes(imageRequest.url, imageRequest.headers)
  const path = await readerImageCacheStore.put(imageRequest.url, cacheHeaders, bytes, `source:${sourceId}:${sourceImageId}`)
  console.info(`[ReaderImage] step=source_cache_written source=${sourceId} page=${sourceImageId} bytes=${bytes.byteLength}`)
  return path
}

export function createReaderOfflineMissingUri(
  comicId: ComicId,
  chapterId: string,
  index: number,
): string {
  return `reader-offline-missing://${encodeURIComponent(comicId)}/${encodeURIComponent(chapterId)}/${index}`
}

export enum ReaderPageRenderKind {
  REMOTE_URL_IMAGE = 'remote_url_image',
  LOCAL_FILE_IMAGE = 'local_file_image',
  URI_PLACEHOLDER = 'uri_placeholder',
}

export interface ReaderPageRenderSource {
  kind: ReaderPageRenderKind
  uri: string
  imageUri: string
  sourceRuntimeId?: string
  pageId?: string
}

export interface ReaderPageRenderSourceOptions {
  preferOffline?: boolean
  offlineOnly?: boolean
}

let readerOfflineDownloadsDir: string = ''

export function configureReaderOfflineDownloads(filesDir: string): void {
  readerOfflineDownloadsDir = filesDir
}

function resolveOfflineReaderPage(
  config: ReaderSessionConfig,
  index: number,
): string {
  if (readerOfflineDownloadsDir.trim().length === 0) {
    return ''
  }
  try {
    const store = new OfflineDownloadStore(readerOfflineDownloadsDir)
    const pageId = config.pageIds !== undefined && index < config.pageIds.length
      ? config.pageIds[index]
      : `page-${index + 1}`
    return store.resolveDownloadedPage(config.comicId, config.chapterId, pageId, index) ?? ''
  } catch (_err) {
    return ''
  }
}

/**
 * Resolve a chapter's local pages once at the reader-session boundary.
 *
 * `resolveDownloadedPage` deliberately performs a full manifest validation,
 * including the page-file checks, because it is also used by one-shot actions
 * such as download verification.  Calling that method for every LazyForEach
 * slot makes normal Reader rendering and page turns repeatedly parse the same
 * manifest and walk every downloaded image.  Keep that integrity boundary,
 * but execute it once here and hand the Reader an immutable source list.
 */
function resolveOfflineReaderPages(config: ReaderSessionConfig): string[] {
  const count = Math.max(0, Math.floor(config.totalPages))
  const paths: string[] = []
  for (let index = 0; index < count; index += 1) {
    paths.push('')
  }
  if (count === 0 || readerOfflineDownloadsDir.trim().length === 0) {
    return paths
  }
  try {
    const store = new OfflineDownloadStore(readerOfflineDownloadsDir)
    // The reader does not need to hash all image bytes again before every
    // page is shown.  The manifest, identity, root, page-index, existence and
    // byte-size checks remain enforced for this session snapshot.
    const validation = store.validateDownloadedChapter(config.comicId, config.chapterId, {
      validateContentHash: false,
    })
    if (validation.manifest === undefined ||
      (validation.status !== OfflineDownloadedChapterStatus.DOWNLOADED &&
        validation.status !== OfflineDownloadedChapterStatus.PARTIAL)) {
      return paths
    }
    for (let index = 0; index < validation.manifest.pages.length; index += 1) {
      const page = validation.manifest.pages[index]
      if (page.pageIndex >= 0 && page.pageIndex < count && fs.accessSync(page.localPath)) {
        paths[page.pageIndex] = page.localPath
      }
    }
  } catch (_err) {
    // A broken download must not prevent an online source from opening.  The
    // normal source fallback below will surface the page-level error/retry UI.
  }
  return paths
}

function readerPageIdAt(config: ReaderSessionConfig, index: number): string | undefined {
  return config.pageIds !== undefined && index < config.pageIds.length
    ? config.pageIds[index]
    : undefined
}

function createReaderPageRenderSourceWithOfflinePath(
  config: ReaderSessionConfig,
  index: number,
  offlinePath: string,
  offlineOnly: boolean,
): ReaderPageRenderSource {
  const pageUri = index >= 0 && index < config.pageUris.length ? config.pageUris[index] : ''
  const pageId = readerPageIdAt(config, index)
  if (offlinePath.length > 0) {
    return {
      kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
      uri: `file://${offlinePath}`,
      imageUri: offlinePath,
      pageId,
    }
  }
  if (offlineOnly || pageUri.length === 0) {
    return {
      kind: ReaderPageRenderKind.URI_PLACEHOLDER,
      uri: createReaderOfflineMissingUri(config.comicId, config.chapterId, index),
      imageUri: '',
    }
  }
  if (isLocalFileUri(pageUri) || !isRemoteHttpUrl(pageUri)) {
    const localPath = pageUri.startsWith('file://') ? pageUri.substring('file://'.length) : pageUri
    return {
      kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
      uri: pageUri,
      imageUri: localPath,
      pageId,
    }
  }
  return {
    kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
    uri: pageUri,
    imageUri: pageUri,
    sourceRuntimeId: config.sourceRuntimeId,
    pageId,
  }
}

export function createReaderPageRenderSource(
  config: ReaderSessionConfig,
  index: number,
  options?: ReaderPageRenderSourceOptions,
): ReaderPageRenderSource {
  const preferOffline = options?.preferOffline === true
  const offlineOnly = options?.offlineOnly === true
  let offlinePath = ''
  if (preferOffline || offlineOnly) {
    offlinePath = resolveOfflineReaderPage(config, index)
  }
  return createReaderPageRenderSourceWithOfflinePath(config, index, offlinePath, offlineOnly)
}

/**
 * Construct all sources for one reader session from one validated offline
 * snapshot.  ReaderPage uses this instead of resolving a manifest from every
 * render, thumbnail, page-turn and preload callback.
 */
export function createReaderPageRenderSources(
  config: ReaderSessionConfig,
  options?: ReaderPageRenderSourceOptions,
): ReaderPageRenderSource[] {
  const count = Math.max(0, Math.floor(config.totalPages))
  const preferOffline = options?.preferOffline === true
  const offlineOnly = options?.offlineOnly === true
  const offlinePaths = preferOffline || offlineOnly ? resolveOfflineReaderPages(config) : []
  const sources: ReaderPageRenderSource[] = []
  for (let index = 0; index < count; index += 1) {
    sources.push(createReaderPageRenderSourceWithOfflinePath(
      config,
      index,
      offlinePaths[index] ?? '',
      offlineOnly,
    ))
  }
  return sources
}

export async function fetchAndCacheReaderRemoteSource(source: ReaderPageRenderSource): Promise<string> {
  if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
    return source.imageUri
  }
  if (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE) {
    if (source.sourceRuntimeId !== undefined && source.sourceRuntimeId.trim().length > 0 && source.pageId !== undefined) {
      return fetchAndCacheSourceRuntimeRemoteImage(source.sourceRuntimeId, source.imageUri, source.pageId)
    }
    return fetchAndCacheReaderRemoteImage(source.imageUri)
  }
  return source.uri
}

export async function fetchReaderRemoteSourceBytes(source: ReaderPageRenderSource): Promise<ArrayBuffer> {
  if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
    const file = fs.openSync(source.imageUri, fs.OpenMode.READ_ONLY)
    try {
      const stat = fs.statSync(source.imageUri)
      const buffer = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buffer)
      return buffer
    } finally {
      fs.closeSync(file)
    }
  }
  if (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE) {
    if (source.sourceRuntimeId !== undefined && source.sourceRuntimeId.trim().length > 0 && source.pageId !== undefined) {
      const imageRequest = await resolveSourceRuntimeImageRequest(source.sourceRuntimeId, source.imageUri, source.pageId)
      if (imageRequest !== undefined) {
        return downloadReaderRemoteBytes(imageRequest.url, imageRequest.headers)
      }
    }
    const url = normalizeReaderUrl(source.imageUri)
    return downloadReaderRemoteBytes(url)
  }
  throw new Error('reader_page_source_unavailable')
}
