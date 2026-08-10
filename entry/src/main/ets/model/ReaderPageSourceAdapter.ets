import { common } from '@kit.AbilityKit'
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
import { runRegisteredSourceRequestById } from '../sourceRuntime/SourceRuntimeService'
import { appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'

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

function httpHeadersForReaderRequest(): Object {
  const entries: string[] = []
  if (readerRemoteHeaders !== null) {
    const headers = readerRemoteHeaders
    if (headers.authorization !== undefined) {
      entries.push(`"Authorization":${JSON.stringify(headers.authorization)}`)
    }
    if (headers.accept !== undefined) {
      entries.push(`"Accept":${JSON.stringify(headers.accept)}`)
    }
    if (headers.contentType !== undefined) {
      entries.push(`"Content-Type":${JSON.stringify(headers.contentType)}`)
    }
    if (headers.xApiKey !== undefined) {
      entries.push(`"X-API-Key":${JSON.stringify(headers.xApiKey)}`)
    }
    if (headers.xAuthToken !== undefined) {
      entries.push(`"X-Auth-Token":${JSON.stringify(headers.xAuthToken)}`)
    }
  }
  if (entries.length === 0) {
    return new EmptyHttpHeader()
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

class EmptyHttpHeader {
}

function remoteImageCacheHeaders(): RemoteImageCacheHeaders | undefined {
  if (readerRemoteHeaders === null) {
    return undefined
  }
  const headers = readerRemoteHeaders
  const out: RemoteImageCacheHeaders = {}
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

async function downloadReaderRemoteBytes(url: string): Promise<ArrayBuffer> {
  const httpRequest = http.createHttp()
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      header: httpHeadersForReaderRequest(),
      readTimeout: 60000,
      connectTimeout: 30000,
    })
    if (response.responseCode !== 200) {
      throw new Error(`reader_remote_image_http_${response.responseCode}`)
    }
    return response.result as ArrayBuffer
  } catch (error) {
    const e = error as BusinessError
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

function readerImageRequestForPage(pageId: string): string {
  const request: ReaderImageRuntimeRequest = {
    type: 'request',
    version: 1,
    requestId: `reader-image-${Date.now()}`,
    operation: 'get_image_request',
    sourceId: '',
    args: new ReaderImageRuntimeArgs(pageId),
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

  constructor(pageId: string) {
    this.pageId = pageId
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

function parseSourceImageRequestUrl(payload: string): string {
  try {
    const document = JSON.parse(payload) as Record<string, Object>
    const data = document['data']
    if (data === undefined || data === null || typeof data !== 'object') {
      return ''
    }
    const record = data as Record<string, Object>
    const imageRequest = record['imageRequest']
    if (imageRequest !== undefined && imageRequest !== null && typeof imageRequest === 'object') {
      const imageRecord = imageRequest as Record<string, Object>
      const url = imageRecord['url']
      if (typeof url === 'string' && url.length > 0) {
        return url
      }
    }
    const directUrl = record['url']
    if (typeof directUrl === 'string' && directUrl.length > 0) {
      return directUrl
    }
    return ''
  } catch (_err) {
    return ''
  }
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
  const lookup = appSourceRuntimeRegistry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined || !lookup.entry.enabled) {
    return fetchAndCacheReaderRemoteImage(uri)
  }
  const requestJson = readerImageRequestForPage(sourceImageId)
  const summary = runRegisteredSourceRequestById(appSourceRuntimeRegistry, sourceId, requestJson)
  if (summary.response === undefined || !summary.responseOk) {
    return fetchAndCacheReaderRemoteImage(uri)
  }
  const resolvedUrl = parseSourceImageRequestUrl(JSON.stringify(summary.response))
  if (resolvedUrl.length === 0) {
    return fetchAndCacheReaderRemoteImage(uri)
  }
  const cached = await readerImageCacheStore.get(resolvedUrl, remoteImageCacheHeaders(), `source:${sourceId}:${sourceImageId}`)
  if (cached !== undefined && cached.length > 0) {
    return cached
  }
  const bytes = await downloadReaderRemoteBytes(resolvedUrl)
  return readerImageCacheStore.put(resolvedUrl, remoteImageCacheHeaders(), bytes, `source:${sourceId}:${sourceImageId}`)
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

export function createReaderPageRenderSource(
  config: ReaderSessionConfig,
  index: number,
  options?: ReaderPageRenderSourceOptions,
): ReaderPageRenderSource {
  const preferOffline = options?.preferOffline === true
  const offlineOnly = options?.offlineOnly === true
  const pageUri = index >= 0 && index < config.pageUris.length ? config.pageUris[index] : ''
  if (preferOffline || offlineOnly) {
    const offlinePath = resolveOfflineReaderPage(config, index)
    if (offlinePath.length > 0) {
      return {
        kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
        uri: `file://${offlinePath}`,
        imageUri: offlinePath,
        pageId: config.pageIds !== undefined && index < config.pageIds.length ? config.pageIds[index] : undefined,
      }
    }
    if (offlineOnly) {
      return {
        kind: ReaderPageRenderKind.URI_PLACEHOLDER,
        uri: createReaderOfflineMissingUri(config.comicId, config.chapterId, index),
        imageUri: '',
      }
    }
  }
  if (pageUri.length === 0) {
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
      pageId: config.pageIds !== undefined && index < config.pageIds.length ? config.pageIds[index] : undefined,
    }
  }
  return {
    kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
    uri: pageUri,
    imageUri: pageUri,
    sourceRuntimeId: config.sourceRuntimeId,
    pageId: config.pageIds !== undefined && index < config.pageIds.length ? config.pageIds[index] : undefined,
  }
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
    const url = normalizeReaderUrl(source.imageUri)
    return downloadReaderRemoteBytes(url)
  }
  throw new Error('reader_page_source_unavailable')
}
