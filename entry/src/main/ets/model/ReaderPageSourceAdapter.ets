import { configureSourceRequestPolicy, waitForSourceRequestSlot } from '../sourceRuntime/SourceRequestPolicy'
import { renderSourceTextPage } from './SourceTextPageRenderer'
import { SourceTextPage, sourceTextPage, SourceTextPageRequest } from './SourceTextPageDescriptor'
import { sourceRequestWithHostFeatures } from '../sourceRuntime/SourceHostFeatures'
import { sourceSettingsFingerprint } from '../sourceRuntime/SourceSettingsIdentity'
import { SourceBaoziBannerService } from './SourceBaoziBannerService'
import { url } from '@kit.ArkTS'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { SourceRuntimeError } from './SourceRuntimeError'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { ComicId, ComicSourceKind } from './ComicModels'
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
import { privateServerHeadersForRequest } from './CoverImageCacheService'
import { KomgaHeaders } from '../remote/KomgaClient'
import { normalizeKavitaBaseUrl } from '../remote/KavitaClient'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { appSourceSettingsStore, SourceSettingsRecord } from '../sourceRuntime/SourceSettingsStore'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { executeSourceRequestInWorker as executeReaderSourceImageRequestOperation, SourceWorkerPriority } from '../sourceRuntime/SourceRuntimeWorkerClient'
import { runSourceOperationFromValidatedBytesAsync } from '../sourceRuntime/SourceRuntimeService'

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

const cachePreferenceMutations: Map<string, Promise<void>> = new Map<string, Promise<void>>()

function mutateCachePreferences(
  key: string,
  operation: () => Promise<ReaderRemoteImageCachePreferences>,
): Promise<ReaderRemoteImageCachePreferences> {
  const previous = cachePreferenceMutations.get(key) ?? Promise.resolve()
  const next = previous.then(operation, operation)
  cachePreferenceMutations.set(key, next.then((): void => {}, (): void => {}))
  return next
}

export class ReaderRemoteImageCachePreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  load(): Promise<ReaderRemoteImageCachePreferences> {
    return mutateCachePreferences(this.context.filesDir, () => this.loadCurrent())
  }

  private async loadCurrent(): Promise<ReaderRemoteImageCachePreferences> {
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
      maxBytes: Number.isFinite(maxBytes) && maxBytes > 0 ? maxBytes : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes,
      autoCleanEnabled: typeof autoCleanEnabled === 'boolean' ? autoCleanEnabled : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled,
    }
  }

  saveMaxBytes(maxBytes: number): Promise<ReaderRemoteImageCachePreferences> {
    return this.saveField(READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY,
      Number.isFinite(maxBytes) && maxBytes > 0 ? maxBytes : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes)
  }

  saveAutoCleanEnabled(enabled: boolean): Promise<ReaderRemoteImageCachePreferences> {
    return this.saveField(READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY, enabled)
  }

  private saveField(key: string, value: number | boolean): Promise<ReaderRemoteImageCachePreferences> {
    return BackupRestoreActivity.runWrite(() => mutateCachePreferences(this.context.filesDir, async (): Promise<ReaderRemoteImageCachePreferences> => {
      const current = await this.loadCurrent()
      const store = await this.preferences()
      const previous = key === READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY ? current.maxBytes : current.autoCleanEnabled
      try {
        await store.put(key, value)
        await store.flush()
      } catch (_error) {
        // A failed disk flush must not leave the Preferences instance ahead of disk.
        await store.put(key, previous)
        throw new Error('reader_remote_image_cache_preferences_save_failed')
      }
      const next: ReaderRemoteImageCachePreferences = {
        maxBytes: key === READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY ? value as number : current.maxBytes,
        autoCleanEnabled: key === READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY ? value as boolean : current.autoCleanEnabled,
      }
      configureReaderRemoteImageCache(this.context.cacheDir, next.maxBytes, next.autoCleanEnabled)
      return next
    }))
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, READER_REMOTE_IMAGE_CACHE_PREFERENCES_STORE_NAME)
  }
}

let readerImageCacheStore: RemoteImageCacheStore | null = null
let readerImageCacheMaxBytes: number = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes
let readerImageCacheAutoCleanEnabled: boolean = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled

/** Restore before Index/cover/Reader consumers; this cache never owns downloads. */
export async function restoreReaderRemoteImageCache(context: common.UIAbilityContext): Promise<void> {
  let saved: ReaderRemoteImageCachePreferences = {
    maxBytes: DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes,
    autoCleanEnabled: false,
  }
  try {
    saved = await new ReaderRemoteImageCachePreferencesStore(context).load()
  } catch (_error) {
    // Do not authorize cleanup under a guessed preference or block the App.
    DiagnosticLogger.warn('reader_page_source_adapter', 'preferences_restore_failed', '[ReaderCache] step=preferences_restore_failed cleanup=false')
  }
  try {
    configureReaderRemoteImageCache(context.cacheDir, saved.maxBytes, saved.autoCleanEnabled)
    console.info(`[ReaderCache] step=startup_ready maxBytes=${saved.maxBytes} autoClean=${saved.autoCleanEnabled}`)
  } catch (_error) {
    DiagnosticLogger.warn('reader_page_source_adapter', 'cache_unavailable', '[ReaderCache] step=cache_unavailable')
  }
}

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
    void readerImageCacheStore.evictIfOver(readerImageCacheMaxBytes).catch((): void => {
      DiagnosticLogger.warn('reader_page_source_adapter', 'cleanup_failed', '[ReaderCache] step=cleanup_failed')
    })
  }
}

async function maintainReaderImageCacheAfterWrite(path: string): Promise<void> {
  if (readerImageCacheStore === null || !readerImageCacheAutoCleanEnabled) return
  try {
    // Keep the just-returned image available even when one image alone exceeds the limit.
    await readerImageCacheStore.evictIfOver(readerImageCacheMaxBytes, path)
  } catch (_error) {
    DiagnosticLogger.warn('reader_page_source_adapter', 'cleanup_failed', '[ReaderCache] step=cleanup_failed')
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


class ResolvedReaderImageHeaders {
  urlPrefix: string
  headers: KomgaHeaders | null
  kavitaImageApiKey?: string

  constructor(urlPrefix: string, headers: KomgaHeaders | null, kavitaImageApiKey?: string) {
    this.urlPrefix = urlPrefix
    this.headers = headers
    this.kavitaImageApiKey = kavitaImageApiKey
  }
}

function httpHeadersForReaderRequest(headers?: RemoteImageCacheHeaders): Object {
  return headers === undefined ? new EmptyHttpHeader() : headers as Object
}

class EmptyHttpHeader {
}

interface ReaderRemoteIdentity {
  sourceKind?: ComicSourceKind
  remoteServerId?: string
  sourceRuntimeId?: string
}

class ReaderRemoteRequest {
  readonly url: string
  readonly requestUrl: string
  readonly headers?: RemoteImageCacheHeaders

  constructor(url: string, requestUrl: string, headers?: RemoteImageCacheHeaders) {
    this.url = url
    this.requestUrl = requestUrl
    this.headers = headers
  }
}

async function resolveReaderRemoteRequest(
  uri: string,
  identity?: ReaderRemoteIdentity,
  context?: common.UIAbilityContext,
): Promise<ReaderRemoteRequest> {
  const kind = identity?.sourceKind
  const privateSource = kind === ComicSourceKind.KOMGA_REMOTE || kind === ComicSourceKind.KAVITA_REMOTE ||
    kind === ComicSourceKind.OPDS_REMOTE || kind === ComicSourceKind.WEBDAV_REMOTE
  if (!privateSource) return new ReaderRemoteRequest(uri, uri)
  if (context === undefined || identity === undefined || !identity.remoteServerId?.trim()) {
    throw new Error('reader_remote_server_identity_missing')
  }
  const resolved = await resolveServerImageHeaders(context, identity)
  if (resolved.headers === null) throw new Error('reader_remote_server_unavailable')
  const prefix = resolved.urlPrefix.endsWith('/') ? resolved.urlPrefix : `${resolved.urlPrefix}/`
  const url = isRemoteHttpUrl(uri) ? uri : `${prefix}${uri.replace(/^\/+/, '')}`
  const headers = privateServerHeadersForRequest(uri, resolved.urlPrefix, resolved.headers)
  const imagePrefix = `${normalizeKavitaBaseUrl(resolved.urlPrefix)}/api/Reader/image?`
  const requestUrl = resolved.kavitaImageApiKey !== undefined && url.startsWith(imagePrefix)
    ? `${url}&apiKey=${encodeURIComponent(resolved.kavitaImageApiKey)}` : url
  return new ReaderRemoteRequest(url, requestUrl, headers)
}

function resolveServerImageHeaders(
  context: common.UIAbilityContext,
  comic: ReaderRemoteIdentity,
): Promise<ResolvedReaderImageHeaders> {
  const store = new RemoteServerStore(context)
  if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
    return store.loadKomga().then((record: KomgaServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined || comic.remoteServerId !== record.server.id) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getKomgaImageHeaders(record))
    })
  }
  if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
    return store.loadKavita().then((record: KavitaServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined || comic.remoteServerId !== record.server.id) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getKavitaImageHeaders(record), record.credential.apiKey)
    })
  }
  if (comic.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
    return store.loadWebDav().then((record: WebDavServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined || comic.remoteServerId !== record.server.id) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.baseUrl, store.getWebDavImageHeaders(record))
    })
  }
  if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
    return store.loadOpds().then((record: OpdsServerRecord | undefined): ResolvedReaderImageHeaders => {
      if (record === undefined || comic.remoteServerId !== record.server.id) {
        return new ResolvedReaderImageHeaders('', null)
      }
      return new ResolvedReaderImageHeaders(record.server.rootUrl, store.getOpdsImageHeaders(record))
    })
  }
  return Promise.resolve(new ResolvedReaderImageHeaders('', null))
}

function isRemoteHttpUrl(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('http://') || normalized.startsWith('https://')
}

function isLocalFileUri(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('file://') || normalized.startsWith('mock://')
}

async function downloadReaderRemoteBytes(url: string, extraHeaders?: RemoteImageCacheHeaders, sourceId: string = ''): Promise<ArrayBuffer> {
  await waitForSourceRequestSlot(sourceId, url)
  const trace = DiagnosticLogger.begin('reader_image', 'request', 'connectTimeoutMs=30000 readTimeoutMs=60000')
  const httpRequest = http.createHttp()
  let responseStarted: boolean = false
  let declaredBytes: number = -1
  try {
    httpRequest.on('headersReceive', (headers: Object) => {
      responseStarted = true
      declaredBytes = -1
      try {
        const fields = headers as Record<string, string>
        for (const key of Object.keys(fields)) {
          if (key.toLowerCase() === 'content-length' && /^\d+$/.test(fields[key])) {
            const length = Number(fields[key])
            if (Number.isSafeInteger(length)) declaredBytes = length
          }
        }
      } catch (_error) {
        // A malformed diagnostic header must not affect the image request.
      }
      trace.info('response', 'declaredBytes=' + declaredBytes)
    })
  } catch (error) {
    // Diagnostics registration must never prevent the original request.
    trace.warn('response_observer_unavailable', DiagnosticLogger.errorSummary(error as Error))
  }
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
      DiagnosticLogger.warn('reader_page_source_adapter', 'http_status_failed', `[ReaderImage] step=http_status_failed status=${response.responseCode}`)
      trace.finish('failed', 'status=' + response.responseCode + ' responseStarted=' + responseStarted +
        ' declaredBytes=' + declaredBytes + ' receivedBytes=' + (response.result as ArrayBuffer).byteLength)
      throw new Error(`reader_remote_image_http_${response.responseCode}`)
    }
    trace.finish('completed', 'status=' + response.responseCode + ' bytes=' + (response.result as ArrayBuffer).byteLength +
      ' responseStarted=' + responseStarted + ' declaredBytes=' + declaredBytes)
    return response.result as ArrayBuffer
  } catch (error) {
    // Keep an observed HTTP status intact instead of rewrapping it as transport "unknown".
    if (/^reader_remote_image_http_\d+$/.test((error as Error).message)) throw error as Error
    const e = error as BusinessError
    trace.finish('failed', 'responseStarted=' + responseStarted + ' declaredBytes=' + declaredBytes +
      ' receivedBytes=unknown ' + DiagnosticLogger.errorSummary(e))
    DiagnosticLogger.warn('reader_page_source_adapter', 'http_request_failed', `[ReaderImage] step=http_request_failed code=${e.code === undefined ? 'unknown' : e.code}`)
    throw new Error(`reader_remote_image_fetch_failed_${e.code === undefined ? 'unknown' : e.code}`)
  } finally {
    httpRequest.destroy()
  }
}

export async function fetchAndCacheReaderRemoteImage(
  uri: string,
  identity?: ReaderRemoteIdentity,
  context?: common.UIAbilityContext,
  forceReload: boolean = false,
): Promise<string> {
  if (readerImageCacheStore === null) throw new Error('reader_remote_image_cache_unconfigured')
  const request = await resolveReaderRemoteRequest(uri, identity, context)
  const path = await readerImageCacheStore.getOrFetch(request.url, request.headers,
    () => downloadReaderRemoteBytes(request.requestUrl, request.headers, identity?.sourceRuntimeId ?? ''), undefined, forceReload)
  await maintainReaderImageCacheAfterWrite(path)
  return path
}

export async function cacheSourceTextPageImage(spec: SourceTextPage, forceReload: boolean = false): Promise<string> {
  if (readerImageCacheStore === null) throw new Error('reader_remote_image_cache_unconfigured')
  // Internal cache label only: getOrFetch receives the local renderer, never HTTP.
  // Cache identity includes the rendering contract and exact plain text, not a fake URL.
  const seed: string = `source-text-page-v1:${JSON.stringify(spec)}`
  const path = await readerImageCacheStore.getOrFetch('source-text-page.png', undefined,
    () => renderSourceTextPage(spec), seed, forceReload)
  await maintainReaderImageCacheAfterWrite(path)
  return path
}

function readerImageRequestForPage(sourceId: string, pageId: string, url: string, mangaUrl?: string,
  settings?: SourceSettingsRecord): string {
  const request: ReaderImageRuntimeRequest = {
    type: 'request',
    version: 1,
    requestId: `reader-image-${Date.now()}`,
    operation: 'get_image_request',
    sourceId,
    args: new ReaderImageRuntimeArgs(pageId, url, mangaUrl),
    settings: settings ?? appSourceSettingsStore.loadForSource(sourceId),
    hostHints: new ReaderImageRuntimeHostHints(),
  }
  configureSourceRequestPolicy(sourceId, request.settings)
  return JSON.stringify(request)
}

function sourceImageMangaRoute(mangaUrl?: string): string | undefined {
  const route = mangaUrl?.trim()
  // source:// locates a Koma Library record; it is not the provider's optional
  // manga URL. Keep the stored locator, but omit it from image request identity.
  if (route === undefined || route.length === 0 || route.toLocaleLowerCase().startsWith('source://')) {
    return undefined
  }
  return route
}

class ReaderImageRuntimeArgs {
  pageId: string
  url: string
  mangaUrl?: string

  constructor(pageId: string, url: string, mangaUrl?: string) {
    this.pageId = pageId
    this.url = url
    const route = sourceImageMangaRoute(mangaUrl)
    if (route !== undefined) {
      this.mangaUrl = route
    }
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
  settings: SourceSettingsRecord
  hostHints: ReaderImageRuntimeHostHints
}

class SourceImageRequestDescriptor {
  url: string
  headers: RemoteImageCacheHeaders | undefined
  imageProcessingMode?: string

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
      const descriptor = new SourceImageRequestDescriptor(directUrl, parseSourceImageRequestHeaders(record['headers']))
      const processing = record['imageProcessing'] as Record<string, Object> | undefined
      if (processing?.['kind'] === 'baozi_banner' && (processing['mode'] === '1' || processing['mode'] === '2')) {
        descriptor.imageProcessingMode = processing['mode'] as string
      }
      return descriptor
    }
    // The source operation also emits an explicit GET request envelope.
    // The image transport is GET-only; never reinterpret another method as GET.
    const request = record['request']
    if (request !== undefined && request !== null && typeof request === 'object') {
      const requestRecord = request as Record<string, Object>
      const url = requestRecord['url']
      if (requestRecord['method'] === 'GET' && typeof url === 'string' && url.length > 0) {
        return new SourceImageRequestDescriptor(url, parseSourceImageRequestHeaders(requestRecord['headers']))
      }
    }
    return undefined
  } catch (_err) {
    return undefined
  }
}

interface ReaderImageCapabilityArgs {}

interface ReaderImageCapabilityHostHints {
  network: boolean
}

interface ReaderImageCapabilityRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: ReaderImageCapabilityArgs
  settings: ReaderImageCapabilityArgs
  hostHints: ReaderImageCapabilityHostHints
}

const sourceImageDescriptorAbsence: WeakMap<Uint8Array, Promise<boolean>> = new WeakMap<Uint8Array, Promise<boolean>>()

function sourceExplicitlyLacksImageRequest(sourceId: string, wasmBytes: Uint8Array): Promise<boolean> {
  const pending = sourceImageDescriptorAbsence.get(wasmBytes)
  if (pending !== undefined) return pending
  // 0067b4b5/980cc8a4: a legacy capability list can be incomplete. Only an
  // explicit source_info false permits bypass; unknown/failed probes keep the
  // old descriptor attempt. Package replacement changes the weak key, and
  // concurrent covers share this one network-disabled worker query.
  const request: ReaderImageCapabilityRequest = {
    type: 'request', version: 1, requestId: 'reader-image-capability',
    operation: 'source_info', sourceId, args: {}, settings: {}, hostHints: { network: false },
  }
  const query = runSourceOperationFromValidatedBytesAsync(JSON.stringify(request), wasmBytes).then((response): boolean => {
    if (response.ok !== true || response.operation !== 'source_info') return false
    const capabilities = (response.data as Record<string, Object> | undefined)?.['capabilities'] as Record<string, Object> | undefined
    return capabilities !== undefined && capabilities !== null && !Array.isArray(capabilities) &&
      typeof capabilities === 'object' && capabilities['imageRequest'] === false
  }).catch((): boolean => false)
  sourceImageDescriptorAbsence.set(wasmBytes, query)
  return query
}

function unavailableSourceImageDescriptor(sourceId: string): undefined {
  DiagnosticLogger.warn('reader_page_source_adapter', 'image_request_unavailable',
    `[ReaderImage] step=image_request_unavailable source=${sourceId} kind=image_descriptor`)
  return undefined
}

async function runReaderSourceImageOperation(entry: SourceRuntimeRegistryEntry, requestJson: string,
  priority: SourceWorkerPriority = SourceWorkerPriority.FOREGROUND): Promise<string> {
  const wasmBytes = new Uint8Array(entry.wasmBytes.byteLength)
  wasmBytes.set(entry.wasmBytes)
  const httpContextJson = sourceHttpIdentityJson(entry, undefined, false, 'get_image_request')
  // Keep normal images and deferred text on the same worker/host HTTP bridge.
  const hostRequest = sourceRequestWithHostFeatures(requestJson)
  return diagnoseSourceOperation(hostRequest, () => executeReaderSourceImageRequestOperation( hostRequest, wasmBytes, httpContextJson, priority,
  ))
}

async function resolveSourceRuntimeImageRequest(
  sourceRuntimeId: string,
  uri: string,
  sourceImageId: string,
  mangaUrl?: string,
  priority: SourceWorkerPriority = SourceWorkerPriority.FOREGROUND,
): Promise<SourceImageRequestDescriptor | undefined> {
  const sourceId = sourceRuntimeId.trim()
  if (sourceId.length === 0) {
    return undefined
  }
  const lookup = appSourceRuntimeRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined || !lookup.entry.enabled) {
    return unavailableSourceImageDescriptor(sourceId)
  }
  const descriptorRequired = lookup.entry.capabilities.includes('imageRequest')
  if (!descriptorRequired && await sourceExplicitlyLacksImageRequest(sourceId, lookup.entry.wasmBytes)) {
    return undefined
  }
  const requestJson = readerImageRequestForPage(sourceId, sourceImageId, uri, mangaUrl)
  let responseJson: string
  try {
    // Match the source detail/chapter path: WAMR stays on a TaskPool worker,
    // while the configured host HTTP bridge dispatches NetworkKit on the UI
    // runtime. Loading the NAPI module dynamically inside the worker bypassed
    // that established execution path and crashed on a ticketed image request.
    responseJson = await runReaderSourceImageOperation(lookup.entry, requestJson, priority)
  } catch (_error) {
    if (descriptorRequired) throw new Error('reader_source_image_request_failed')
    return unavailableSourceImageDescriptor(sourceId)
  }
  try {
    const response = JSON.parse(responseJson) as Record<string, Object>
    if (response['ok'] !== true) {
      if (descriptorRequired) throw new Error('reader_source_image_request_rejected')
      return unavailableSourceImageDescriptor(sourceId)
    }
  } catch (_error) {
    if (descriptorRequired) throw new Error('reader_source_image_request_rejected')
    return unavailableSourceImageDescriptor(sourceId)
  }
  const descriptor = parseSourceImageRequestDescriptor(responseJson)
  if (descriptor === undefined && descriptorRequired) throw new Error('reader_source_image_request_invalid')
  return descriptor ?? unavailableSourceImageDescriptor(sourceId)
}

function sourceTextRequestCurrent(entry: SourceRuntimeRegistryEntry, fingerprint: string): boolean {
  const latest = appSourceRuntimeRegistry.lookup(entry.sourceId)
  return latest.ok && latest.entry !== undefined && latest.entry === entry && latest.entry.enabled &&
    sourceSettingsFingerprint(appSourceSettingsStore.loadForSource(entry.sourceId)) === fingerprint
}

async function fetchAndCacheSourceRuntimeTextPage(source: ReaderPageRenderSource, forceReload: boolean): Promise<string> {
  if (readerImageCacheStore === null) throw new Error('reader_remote_image_cache_unconfigured')
  const sourceId = source.sourceRuntimeId?.trim() ?? ''
  const pageId = source.pageId ?? ''
  const request = source.sourceTextRequest
  const lookup = appSourceRuntimeRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined || !lookup.entry.enabled ||
    !lookup.entry.capabilities.includes('imageRequest') || request === undefined || pageId.length === 0) {
    throw new Error('reader_source_text_request_unavailable')
  }
  const entry = lookup.entry
  const settings = appSourceSettingsStore.loadForSource(sourceId)
  const fingerprint = sourceSettingsFingerprint(settings)
  const route = sourceImageMangaRoute(source.sourceMangaUrl)
  // The installed package path changes on replacement. Settings and template are
  // part of this public PNG cache identity; no credential snapshot is persisted.
  const seed = `source-text-request-v1:${JSON.stringify([
    sourceId, entry.manifestVersion, entry.wasmPath ?? '', pageId, route ?? '', request.template, fingerprint,
  ])}`
  const path = await readerImageCacheStore.getOrFetch('source-text-request.png', undefined, async (): Promise<ArrayBuffer> => {
    if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_text_request_stale')
    const requestJson = readerImageRequestForPage(sourceId, pageId, '', route, settings)
    const responseJson = await runReaderSourceImageOperation(entry, requestJson)
    if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_text_request_stale')
    const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
    if (response.ok !== true) throw new SourceRuntimeError(response)
    const data = response.data as Record<string, Object> | undefined
    const image = data?.['image'] as Record<string, Object> | undefined
    if (image === undefined || image['kind'] !== 'text') throw new Error('reader_source_text_request_invalid')
    const spec = sourceTextPage(image['text'])
    if (spec.template !== request.template) throw new Error('reader_source_text_request_invalid')
    const bytes = await renderSourceTextPage(spec)
    if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_text_request_stale')
    return bytes
  }, seed, forceReload)
  await maintainReaderImageCacheAfterWrite(path)
  if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_text_request_stale')
  return path
}

export async function fetchAndCacheSourceRuntimeRemoteImage(
  sourceRuntimeId: string,
  uri: string,
  sourceImageId: string,
  mangaUrl?: string,
  forceReload: boolean = false,
  priority: SourceWorkerPriority = SourceWorkerPriority.FOREGROUND,
): Promise<string> {
  if (readerImageCacheStore === null) {
    throw new Error('reader_remote_image_cache_unconfigured')
  }
  const sourceId = sourceRuntimeId.trim()
  if (sourceId.length === 0) {
    return fetchAndCacheReaderRemoteImage(uri, undefined, undefined, forceReload)
  }
  // Source page IDs can be chapter-local, so the original image URI belongs in the cache identity.
  const route = sourceImageMangaRoute(mangaUrl)
  const cacheIdentity = route === undefined
    ? [sourceId, sourceImageId, uri] : [sourceId, sourceImageId, uri, route]
  const cacheKeySeed = `source-page-v2:${JSON.stringify(cacheIdentity)}`
  const cachedFast = forceReload ? undefined : await readerImageCacheStore.get('', undefined, cacheKeySeed)
  if (cachedFast !== undefined && cachedFast.length > 0) {
    return cachedFast
  }
  const imageRequest = await resolveSourceRuntimeImageRequest(sourceId, uri, sourceImageId, route, priority)
  if (imageRequest === undefined) {
    return fetchAndCacheReaderRemoteImage(uri, { sourceRuntimeId: sourceId }, undefined, forceReload)
  }
  const cacheHeaders = imageRequest.headers
  const path = await readerImageCacheStore.getOrFetch(imageRequest.url, cacheHeaders,
    () => downloadReaderRemoteBytes(imageRequest.url, imageRequest.headers, sourceId), cacheKeySeed, forceReload)
  await maintainReaderImageCacheAfterWrite(path)
  return path
}

/** Covers share the same cache and ownership checks; only pending Worker priority differs. */
export function fetchAndCacheSourceRuntimeCoverImage(sourceRuntimeId: string, uri: string,
  sourceImageId: string, mangaUrl?: string): Promise<string> {
  return fetchAndCacheSourceRuntimeRemoteImage(sourceRuntimeId, uri, sourceImageId, mangaUrl,
    false, SourceWorkerPriority.BACKGROUND)
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
  SOURCE_TEXT_REQUEST = 'source_text_request',
}

export interface ReaderPageRenderSource extends ReaderRemoteIdentity {
  kind: ReaderPageRenderKind
  uri: string
  imageUri: string
  sourceRuntimeId?: string
  sourceMangaUrl?: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
  pageId?: string
  sourceOriginalImageUri?: string
  sourceText?: SourceTextPage
  sourceTextRequest?: SourceTextPageRequest
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
      // Downloaded pages retain their source identity for source-owned derived
      // presentation; the downloaded file itself remains the original.
      sourceRuntimeId: config.sourceRuntimeId,
      sourceMangaUrl: config.sourceMangaUrl,
      sourceOriginalImageUri: config.sourceOriginalImageUris?.[index] ?? pageUri,
    }
  }
  const textRequest = config.pageTextRequests?.[index]
  if (!offlineOnly && textRequest !== undefined && textRequest !== null) {
    return {
      kind: ReaderPageRenderKind.SOURCE_TEXT_REQUEST,
      uri: pageId ?? '', imageUri: '', pageId,
      sourceRuntimeId: config.sourceRuntimeId,
      sourceMangaUrl: config.sourceMangaUrl,
      sourceOriginalImageUri: pageUri,
      sourceTextRequest: { template: textRequest.template },
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
    let localPath = pageUri.startsWith('file://') ? pageUri.substring('file://'.length) : pageUri
    if (pageUri.startsWith('file://docs/')) {
      try {
        localPath = new fileUri.FileUri(pageUri).path
      } catch (_error) {
        // Keep an invalid page local to its existing load failure, not a whole-catalog failure.
      }
    }
    return {
      kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
      uri: pageUri,
      imageUri: localPath,
      pageId,
      sourceText: config.pageTextPages?.[index] ?? undefined,
      sourceRuntimeId: config.sourceRuntimeId,
      sourceMangaUrl: config.sourceMangaUrl,
      sourceOriginalImageUri: config.sourceOriginalImageUris?.[index],
    }
  }
  return {
    kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
    uri: pageUri,
    imageUri: pageUri,
    sourceRuntimeId: config.sourceRuntimeId,
    sourceMangaUrl: config.sourceMangaUrl,
    sourceKind: config.sourceKind,
    remoteServerId: config.remoteServerId,
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

async function prepareSourcePagePresentation(source: ReaderPageRenderSource, originalPath: string,
  context?: common.UIAbilityContext): Promise<string> {
  const sourceId = source.sourceRuntimeId?.trim() ?? ''
  const pageId = source.pageId ?? ''
  const originalUri = source.sourceOriginalImageUri ?? source.imageUri
  if (sourceId !== 'online.baozimh.koma' || pageId.length === 0 || context === undefined ||
    readerImageCacheStore === null) return originalPath
  try {
    const host = new url.URL(originalUri).hostname.toLowerCase()
    if (!['baozimh.com', 'baozicdn.com', 'bzcdn.net'].some((domain: string): boolean =>
      host === domain || host.endsWith('.' + domain))) return originalPath
  } catch (_error) { return originalPath }
  const lookup = appSourceRuntimeRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined || !lookup.entry.enabled) return originalPath
  const entry = lookup.entry
  const settings = appSourceSettingsStore.loadForSource(sourceId)
  // The source decides its own default; an older source returns no descriptor.
  // An explicit disabled or unknown value never starts processing.
  const mode = settings['BAOZI_BANNER']
  if (mode !== undefined && mode !== '1' && mode !== '2') return originalPath
  const fingerprint = sourceSettingsFingerprint(settings)
  let descriptor: SourceImageRequestDescriptor | undefined
  try {
    descriptor = await resolveSourceRuntimeImageRequest(sourceId, originalUri, pageId, source.sourceMangaUrl)
  } catch (_error) {
    if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_page_processing_stale')
    return originalPath
  }
  if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_page_processing_stale')
  if (descriptor?.imageProcessingMode === undefined) return originalPath
  const profileIdentity = JSON.stringify([sourceId, entry.manifestVersion, entry.wasmPath ?? '', fingerprint])
  const path = await SourceBaoziBannerService.prepare(originalPath, descriptor.imageProcessingMode,
    readerImageCacheStore, profileIdentity)
  if (path !== originalPath) await maintainReaderImageCacheAfterWrite(path)
  if (!sourceTextRequestCurrent(entry, fingerprint)) throw new Error('reader_source_page_processing_stale')
  return path
}

export async function fetchAndCacheReaderRemoteSource(source: ReaderPageRenderSource, context?: common.UIAbilityContext, forceReload: boolean = false): Promise<string> {
  if (source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST) {
    return fetchAndCacheSourceRuntimeTextPage(source, forceReload)
  }
  if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
    if (source.sourceText !== undefined) return cacheSourceTextPageImage(source.sourceText, forceReload)
    return prepareSourcePagePresentation(source, source.imageUri, context)
  }
  if (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE) {
    if (source.sourceRuntimeId !== undefined && source.sourceRuntimeId.trim().length > 0 && source.pageId !== undefined) {
      const original = await fetchAndCacheSourceRuntimeRemoteImage(source.sourceRuntimeId, source.imageUri, source.pageId, source.sourceMangaUrl, forceReload)
      return prepareSourcePagePresentation(source, original, context)
    }
    return fetchAndCacheReaderRemoteImage(source.imageUri, source, context, forceReload)
  }
  return source.uri
}

export async function fetchReaderRemoteSourceBytes(source: ReaderPageRenderSource, context?: common.UIAbilityContext): Promise<ArrayBuffer> {
  if (source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE || source.kind === ReaderPageRenderKind.SOURCE_TEXT_REQUEST) {
    // Downloads own the original bytes even when normal presentation has a
    // source-specific derivative. Text pages still use their existing renderer.
    const path = source.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE
      ? (source.sourceText === undefined ? source.imageUri : await cacheSourceTextPageImage(source.sourceText))
      : await fetchAndCacheReaderRemoteSource(source, context)
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    try {
      const stat = fs.statSync(path)
      const buffer = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buffer)
      return buffer
    } finally {
      fs.closeSync(file)
    }
  }
  if (source.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE) {
    if (source.sourceRuntimeId !== undefined && source.sourceRuntimeId.trim().length > 0 && source.pageId !== undefined) {
      const imageRequest = await resolveSourceRuntimeImageRequest(source.sourceRuntimeId, source.imageUri, source.pageId, source.sourceMangaUrl)
      if (imageRequest !== undefined) {
        return downloadReaderRemoteBytes(imageRequest.url, imageRequest.headers, source.sourceRuntimeId)
      }
    }
    const request = await resolveReaderRemoteRequest(source.imageUri, source, context)
    return downloadReaderRemoteBytes(request.requestUrl, request.headers, source.sourceRuntimeId ?? '')
  }
  throw new Error('reader_page_source_unavailable')
}
