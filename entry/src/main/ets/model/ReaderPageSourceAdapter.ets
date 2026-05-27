import {
  ReaderSessionConfig,
  getReaderSessionPageId,
  getReaderSessionPageUri,
} from './ReaderSessionStore'
import {
  Comic,
  ComicSourceKind,
} from './ComicModels'
import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import {
  KomgaHeaders,
} from '../remote/KomgaClient'
import {
  DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  RemoteImageCacheStats,
  RemoteImageCacheStore,
  formatRemoteImageCacheSize as formatRemoteImageCacheSizeFromStore,
} from './RemoteImageCacheStore'
import { RemoteServerStore } from './RemoteServerStore'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { runRegisteredSourceRequestById } from '../sourceRuntime/SourceRuntimeService'
import {
  SourceSettingsRecord,
  appSourceSettingsStore,
} from '../sourceRuntime/SourceSettingsStore'
import { OfflineDownloadStore } from './OfflineDownloadStore'

export type ReaderRemoteImageHeaders = Record<string, string>
export type ReaderRemoteImageCacheStats = RemoteImageCacheStats

export enum ReaderPageRenderKind {
  LOCAL_FILE_IMAGE = 'local_file_image',
  REMOTE_URL_IMAGE = 'remote_url_image',
  URI_PLACEHOLDER = 'uri_placeholder',
}

export interface ReaderPageRenderSource {
  kind: ReaderPageRenderKind
  uri: string
  imageUri: string
  fallbackPageIndex: number
  headers?: ReaderRemoteImageHeaders
  sourceRuntimeId?: string
  pageId?: string
  pageUri?: string
}

export interface ReaderPageRenderSourceOptions {
  preferOffline?: boolean
}

export interface ReaderPageRenderDiagnostics {
  pageIndex: number
  kind: ReaderPageRenderKind
  imageSourceForm: string
  hasFileScheme: boolean
  hasRawFragmentOrQuery: boolean
  matchedSandboxRoot: string
  extension: string
  uriHash: string
  sourceHash: string
  redactedTail: string
}

interface ReaderSandboxRoot {
  label: string
  path: string
}

interface ReaderRemoteHeaderRule {
  prefix: string
  headers: ReaderRemoteImageHeaders
}

interface SourceRuntimeImageRequestDescriptor {
  url?: string
  headers?: Record<string, string>
}

interface SourceRuntimeResolvedImageRequest {
  url: string
  headers?: ReaderRemoteImageHeaders
}

interface ReaderSourceImageRequestArgs {
  pageId: string
  url?: string
  pageUri?: string
}

interface ReaderSourceImageRequestHostHints {
  network: boolean
}

interface ReaderSourceImageRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: ReaderSourceImageRequestArgs
  settings: SourceSettingsRecord
  hostHints: ReaderSourceImageRequestHostHints
}

const READER_SANDBOX_ROOTS: ReaderSandboxRoot[] = [
  { label: 'cache_haps_entry', path: '/data/storage/el2/base/haps/entry/cache/import/' },
  { label: 'files_haps_entry', path: '/data/storage/el2/base/haps/entry/files/import/' },
  { label: 'cache_base', path: '/data/storage/el2/base/cache/import/' },
  { label: 'files_base', path: '/data/storage/el2/base/files/import/' },
]

const readerRemoteHeaderRules: ReaderRemoteHeaderRule[] = []
let readerRemoteImageCacheStore: RemoteImageCacheStore | undefined = undefined
let readerOfflineDownloadStore: OfflineDownloadStore | undefined = undefined
let readerRemoteImageCacheMaxBytes: number = DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES
const readerPrefetchInFlight: string[] = []

function normalizeReaderPageUri(uri: string): string {
  return uri.trim().replace(/\\/g, '/')
}

function hasTraversalSegment(path: string): boolean {
  return path.split('/').some((segment: string) => segment === '..')
}

function decodeFileUriPath(path: string): string {
  try {
    return decodeURIComponent(path)
  } catch (_err) {
    return ''
  }
}

function isSupportedLocalImagePath(path: string): boolean {
  const normalized = path.toLocaleLowerCase()
  return normalized.endsWith('.jpg') ||
    normalized.endsWith('.jpeg') ||
    normalized.endsWith('.png') ||
    normalized.endsWith('.webp') ||
    normalized.endsWith('.gif') ||
    normalized.endsWith('.bmp') ||
    normalized.endsWith('.avif')
}

function isReaderRemoteImageSourceUri(uri: string): boolean {
  const normalized = normalizeReaderPageUri(uri).toLocaleLowerCase()
  return normalized.startsWith('http://') || normalized.startsWith('https://')
}

function resolveReaderRemoteHeaders(uri: string): ReaderRemoteImageHeaders | undefined {
  const matched = readerRemoteHeaderRules.find((rule: ReaderRemoteHeaderRule) => {
    return uri.startsWith(rule.prefix)
  })
  return matched === undefined ? undefined : matched.headers
}

function isAppImportExtractPath(path: string): boolean {
  return READER_SANDBOX_ROOTS.some((root: ReaderSandboxRoot) => {
    if (!path.startsWith(root.path)) {
      return false
    }
    return path.indexOf('/extract/', root.path.length) > root.path.length
  })
}

function matchReaderSandboxRoot(path: string): string {
  const matched = READER_SANDBOX_ROOTS.find((root: ReaderSandboxRoot) => {
    return path.startsWith(root.path) && path.indexOf('/extract/', root.path.length) > root.path.length
  })
  return matched === undefined ? 'none' : matched.label
}

function getReaderUriExtension(uri: string): string {
  const normalized = normalizeReaderPageUri(uri)
  const withoutQuery = normalized.split('?')[0].split('#')[0]
  const lastSegment = withoutQuery.split('/').pop() ?? ''
  const dotIndex = lastSegment.lastIndexOf('.')
  if (dotIndex < 0 || dotIndex === lastSegment.length - 1) {
    return ''
  }
  return lastSegment.slice(dotIndex + 1).toLocaleLowerCase()
}

function createShortReaderHash(value: string): string {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash ^ value.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0').slice(-8)
}

function remoteFetchKey(url: string, headers: ReaderRemoteImageHeaders | undefined): string {
  return createShortReaderHash(`${url}\n${JSON.stringify(headers ?? {})}`)
}

function readerRemoteHeadersToHttpHeaderObject(headers: ReaderRemoteImageHeaders | undefined): Object {
  const entries: string[] = []
  if (headers !== undefined) {
    Object.keys(headers).sort().forEach((name: string) => {
      const value = headers[name]
      if (value !== undefined) {
        entries.push(`${JSON.stringify(name)}:${JSON.stringify(value)}`)
      }
    })
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

function komgaHeadersToReaderRemoteImageHeaders(headers: KomgaHeaders): ReaderRemoteImageHeaders {
  const normalized: ReaderRemoteImageHeaders = {}
  if (headers.authorization !== undefined) {
    normalized['Authorization'] = headers.authorization
  }
  if (headers.accept !== undefined) {
    normalized['Accept'] = headers.accept
  }
  if (headers.contentType !== undefined) {
    normalized['Content-Type'] = headers.contentType
  }
  if (headers.xApiKey !== undefined) {
    normalized['X-API-Key'] = headers.xApiKey
  }
  if (headers.xAuthToken !== undefined) {
    normalized['X-Auth-Token'] = headers.xAuthToken
  }
  return normalized
}

function normalizeSourceImageHeaders(raw: Record<string, string> | undefined): ReaderRemoteImageHeaders | undefined {
  if (raw === undefined) {
    return undefined
  }
  const headers: ReaderRemoteImageHeaders = {}
  Object.keys(raw).forEach((name: string) => {
    const normalizedName = name.trim()
    const value = raw[name]
    if (normalizedName.length > 0 && typeof value === 'string') {
      headers[normalizedName] = value
    }
  })
  return Object.keys(headers).length === 0 ? undefined : headers
}

async function fetchReaderRemoteImageBytes(url: string, headers: ReaderRemoteImageHeaders | undefined): Promise<ArrayBuffer> {
  const request = http.createHttp()
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      header: readerRemoteHeadersToHttpHeaderObject(headers),
      readTimeout: 60000,
      connectTimeout: 30000,
      maxLimit: 100 * 1024 * 1024,
    })
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error(`remote image status ${response.responseCode}`)
    }
    return response.result as ArrayBuffer
  } finally {
    request.destroy()
  }
}

export async function fetchReaderRemoteSourceBytes(source: ReaderPageRenderSource): Promise<ArrayBuffer> {
  if (source.sourceRuntimeId !== undefined && source.pageId !== undefined) {
    const resolved = resolveSourceRuntimeImageRequest(source.sourceRuntimeId, source.pageId, source.pageUri)
    if (resolved !== undefined) {
      return fetchReaderRemoteImageBytes(resolved.url, resolved.headers)
    }
    if (source.pageUri === undefined || !isReaderRemoteImageSourceUri(source.pageUri)) {
      console.warn(`[ReaderOffline] step=source_image_request_fallback allowed=false source=${createShortReaderHash(source.sourceRuntimeId)} page=${createShortReaderHash(source.pageId)}`)
      throw new Error('Source image request failed and fallback page URI is not a valid URL')
    }
    console.warn(`[ReaderOffline] step=source_image_request_fallback allowed=true source=${createShortReaderHash(source.sourceRuntimeId)} page=${createShortReaderHash(source.pageId)} urlHash=${createShortReaderHash(source.pageUri)}`)
    return fetchReaderRemoteImageBytes(source.pageUri, source.headers)
  }
  return fetchReaderRemoteImageBytes(source.imageUri, source.headers)
}

function createReaderRedactedTail(uri: string): string {
  const normalized = normalizeReaderPageUri(uri)
  const path = decodeFileUriPath(stripFileUriScheme(normalized))
  const extension = getReaderUriExtension(uri)
  const extensionTail = extension.length > 0 ? `<file.${extension}>` : '<file>'
  const extractIndex = path.indexOf('/extract/')
  if (extractIndex >= 0) {
    const afterExtract = path.slice(extractIndex + '/extract/'.length)
    const relativeSegments = afterExtract.split('/').filter((segment: string) => segment.length > 0)
    if (relativeSegments.length > 1) {
      return `<segment>/extract/<segment>/${extensionTail}`
    }
    return `<segment>/extract/${extensionTail}`
  }
  const strippedPath = stripFileUriScheme(normalized)
  const pathSegments = strippedPath.split('/').filter((segment: string) => segment.length > 0)
  if (pathSegments.length > 1) {
    return `<segment>/${extensionTail}`
  }
  return extensionTail
}

function getReaderImageSourceForm(source: ReaderPageRenderSource): string {
  if (source.imageUri.length === 0) {
    return 'none'
  }
  if (source.imageUri.startsWith('file://')) {
    return 'file_uri'
  }
  if (source.imageUri.startsWith('/')) {
    return 'absolute_path'
  }
  return 'other'
}

function createReaderUriRenderSource(uri: string, pageIndex: number): ReaderPageRenderSource {
  if (uri.length === 0 || uri.startsWith('mock://')) {
    return {
      kind: ReaderPageRenderKind.URI_PLACEHOLDER,
      uri,
      imageUri: '',
      fallbackPageIndex: pageIndex,
    }
  }
  if (isReaderLocalImageSourceUri(uri)) {
    return {
      kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
      uri,
      imageUri: createReaderImageSourceUri(uri),
      fallbackPageIndex: pageIndex,
    }
  }
  if (isReaderRemoteImageSourceUri(uri)) {
    return {
      kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
      uri,
      imageUri: uri,
      fallbackPageIndex: pageIndex,
      headers: resolveReaderRemoteHeaders(uri),
    }
  }
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri,
    imageUri: '',
    fallbackPageIndex: pageIndex,
  }
}

function createReaderSourceRuntimeRenderSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource | undefined {
  if (config.sourceRuntimeId === undefined || config.sourceRuntimeId.trim().length === 0) {
    return undefined
  }
  const pageId = getReaderSessionPageId(config, pageIndex)
  if (pageId.length === 0) {
    return undefined
  }
  const uri = getReaderSessionPageUri(config, pageIndex)
  const fallbackImageUri = isReaderRemoteImageSourceUri(uri) ? uri : `source-runtime://${config.sourceRuntimeId}/${encodeURIComponent(pageId)}`
  return {
    kind: ReaderPageRenderKind.REMOTE_URL_IMAGE,
    uri,
    imageUri: fallbackImageUri,
    fallbackPageIndex: pageIndex,
    sourceRuntimeId: config.sourceRuntimeId,
    pageId,
    pageUri: uri,
  }
}

function stripFileUriScheme(uri: string): string {
  if (!uri.startsWith('file://')) {
    return uri
  }
  return uri.slice('file://'.length)
}

export function isReaderLocalImageSourceUri(uri: string): boolean {
  const normalized = normalizeReaderPageUri(uri)
  if (normalized.length === 0 || normalized.includes('#') || normalized.includes('?')) {
    return false
  }
  if (normalized.includes('://') && !normalized.startsWith('file://')) {
    return false
  }
  const path = stripFileUriScheme(normalized)
  if (!path.startsWith('/') || hasTraversalSegment(path)) {
    return false
  }
  const decodedPath = decodeFileUriPath(path)
  if (decodedPath.length === 0 || !decodedPath.startsWith('/') || hasTraversalSegment(decodedPath)) {
    return false
  }
  return isAppImportExtractPath(decodedPath) && isSupportedLocalImagePath(decodedPath)
}

export function createReaderImageSourceUri(uri: string): string {
  const normalized = normalizeReaderPageUri(uri)
  return decodeFileUriPath(stripFileUriScheme(normalized))
}

export function installReaderRemoteHeaders(prefix: string, headers: KomgaHeaders): void {
  const normalizedPrefix = prefix.trim()
  if (normalizedPrefix.length === 0) {
    return
  }
  const index = readerRemoteHeaderRules.findIndex((rule: ReaderRemoteHeaderRule) => rule.prefix === normalizedPrefix)
  const rule: ReaderRemoteHeaderRule = {
    prefix: normalizedPrefix,
    headers: komgaHeadersToReaderRemoteImageHeaders(headers),
  }
  if (index >= 0) {
    readerRemoteHeaderRules[index] = rule
  } else {
    readerRemoteHeaderRules.push(rule)
  }
  console.info('[Reader] remote headers installed')
}

export async function installReaderRemoteHeadersForComic(context: common.UIAbilityContext, comic: Comic): Promise<void> {
  if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE &&
    comic.sourceKind !== ComicSourceKind.OPDS_REMOTE &&
    comic.sourceKind !== ComicSourceKind.WEBDAV_REMOTE) {
    return
  }
  const store = new RemoteServerStore(context)
  if (comic.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
    const record = await store.loadKomga()
    if (record === undefined) {
      throw new Error('Komga server is not configured')
    }
    installReaderRemoteHeaders(store.createKomgaClient(record).getBaseUrl(), store.getKomgaImageHeaders(record))
    console.info('[Favorite] step=reader_headers_installed kind=komga')
    return
  }
  if (comic.sourceKind === ComicSourceKind.OPDS_REMOTE) {
    const record = await store.loadOpds()
    if (record === undefined) {
      throw new Error('OPDS server is not configured')
    }
    installReaderRemoteHeaders(store.createOpdsClient(record).getUrlPrefix(), store.getOpdsImageHeaders(record))
    console.info('[Favorite] step=reader_headers_installed kind=opds')
    return
  }
  const record = await store.loadWebDav()
  if (record === undefined) {
    throw new Error('WebDAV server is not configured')
  }
  installReaderRemoteHeaders(store.createWebDavClient(record).getBaseUrl(), store.getWebDavImageHeaders(record))
  console.info('[Favorite] step=reader_headers_installed kind=webdav')
}

export function configureReaderRemoteImageCache(cacheDir: string, maxBytes: number = DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES): void {
  if (cacheDir.length === 0) {
    return
  }
  if (readerRemoteImageCacheStore === undefined) {
    readerRemoteImageCacheStore = new RemoteImageCacheStore(cacheDir)
    console.info('[ReaderCache] step=ready')
  }
  readerRemoteImageCacheMaxBytes = maxBytes
  readerRemoteImageCacheStore.evictIfOver(readerRemoteImageCacheMaxBytes)
}

export function configureReaderOfflineDownloads(filesDir: string): void {
  if (filesDir.length === 0) {
    return
  }
  if (readerOfflineDownloadStore === undefined) {
    readerOfflineDownloadStore = new OfflineDownloadStore(filesDir)
    console.info('[ReaderOffline] step=ready')
  }
}

function createReaderOfflineDownloadRenderSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource | undefined {
  if (readerOfflineDownloadStore === undefined || config.comicId.length === 0 || config.chapterId.length === 0) {
    return undefined
  }
  const pageId = getReaderSessionPageId(config, pageIndex)
  const localPath = readerOfflineDownloadStore.resolveDownloadedPage(config.comicId, config.chapterId, pageId, pageIndex)
  if (localPath === undefined) {
    return undefined
  }
  return {
    kind: ReaderPageRenderKind.LOCAL_FILE_IMAGE,
    uri: localPath,
    imageUri: localPath,
    fallbackPageIndex: pageIndex,
    pageId,
  }
}

export async function getReaderRemoteImageCacheStats(): Promise<ReaderRemoteImageCacheStats> {
  if (readerRemoteImageCacheStore === undefined) {
    return {
      totalBytes: 0,
      entryCount: 0,
    }
  }
  return readerRemoteImageCacheStore.stats()
}

export async function clearReaderRemoteImageCache(): Promise<ReaderRemoteImageCacheStats> {
  if (readerRemoteImageCacheStore === undefined) {
    return {
      totalBytes: 0,
      entryCount: 0,
    }
  }
  await readerRemoteImageCacheStore.clear()
  return readerRemoteImageCacheStore.stats()
}

export function formatReaderRemoteImageCacheSize(totalBytes: number): string {
  return formatRemoteImageCacheSizeFromStore(totalBytes)
}

export async function resolveLocalCached(url: string, headers?: ReaderRemoteImageHeaders): Promise<string | undefined> {
  if (readerRemoteImageCacheStore === undefined) {
    console.info('[ReaderCache] step=miss reason=unconfigured')
    return undefined
  }
  return readerRemoteImageCacheStore.get(url, headers)
}

export async function fetchAndCacheReaderRemoteImage(url: string, headers?: ReaderRemoteImageHeaders): Promise<string> {
  const cachedPath = await resolveLocalCached(url, headers)
  if (cachedPath !== undefined) {
    return cachedPath
  }
  const bytes = await fetchReaderRemoteImageBytes(url, headers)
  if (readerRemoteImageCacheStore === undefined) {
    throw new Error('Reader remote image cache is unavailable')
  }
  const path = await readerRemoteImageCacheStore.put(url, headers, bytes)
  await readerRemoteImageCacheStore.evictIfOver(readerRemoteImageCacheMaxBytes)
  return path
}

function sourceRuntimeImageRequestPayload(responseData: Record<string, Object> | undefined): SourceRuntimeImageRequestDescriptor | undefined {
  if (responseData === undefined) {
    return undefined
  }
  const imageRequest = responseData['imageRequest']
  if (imageRequest !== undefined && typeof imageRequest === 'object' && !Array.isArray(imageRequest)) {
    return imageRequest as SourceRuntimeImageRequestDescriptor
  }
  return responseData as SourceRuntimeImageRequestDescriptor
}

function resolveSourceRuntimeImageRequest(sourceRuntimeId: string, pageId: string, pageUri?: string): SourceRuntimeResolvedImageRequest | undefined {
  const args: ReaderSourceImageRequestArgs = { pageId }
  if (pageUri !== undefined && isReaderRemoteImageSourceUri(pageUri)) {
    args.url = pageUri
    args.pageUri = pageUri
  }
  const settings = appSourceSettingsStore.loadForSource(sourceRuntimeId)
  const hostHints: ReaderSourceImageRequestHostHints = { network: false }
  const request: ReaderSourceImageRequest = {
    type: 'request',
    version: 1,
    requestId: `reader-image-request-${createShortReaderHash(sourceRuntimeId)}-${createShortReaderHash(pageId)}-${Date.now()}`,
    operation: 'get_image_request',
    sourceId: sourceRuntimeId,
    args,
    settings,
    hostHints,
  }
  try {
    const summary = runRegisteredSourceRequestById(appSourceRuntimeRegistry, sourceRuntimeId, JSON.stringify(request))
    if (summary.response === undefined || summary.response.ok !== true || summary.response.operation !== 'get_image_request') {
      console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=${summary.reasonCode ?? 'runtime_response'}`)
      return undefined
    }
    const payload = sourceRuntimeImageRequestPayload(summary.response.data as Record<string, Object> | undefined)
    if (payload === undefined || payload.url === undefined || !isReaderRemoteImageSourceUri(payload.url)) {
      console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=invalid_url`)
      return undefined
    }
    const headers = normalizeSourceImageHeaders(payload.headers)
    console.info(`[ReaderCache] step=source_image_request ok=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} urlHash=${createShortReaderHash(payload.url)} headers=${headers === undefined ? 0 : Object.keys(headers).length}`)
    return {
      url: payload.url,
      headers,
    }
  } catch (error) {
    void error
    console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=exception`)
    return undefined
  }
}

export async function fetchAndCacheReaderRemoteSource(source: ReaderPageRenderSource): Promise<string> {
  if (source.sourceRuntimeId !== undefined && source.pageId !== undefined) {
    const resolved = resolveSourceRuntimeImageRequest(source.sourceRuntimeId, source.pageId, source.pageUri)
    if (resolved !== undefined) {
      return fetchAndCacheReaderRemoteImage(resolved.url, resolved.headers)
    }
    if (source.pageUri === undefined || !isReaderRemoteImageSourceUri(source.pageUri)) {
      console.warn(`[ReaderCache] step=source_image_request_fallback allowed=false source=${createShortReaderHash(source.sourceRuntimeId)} page=${createShortReaderHash(source.pageId)}`)
      throw new Error('Source image request failed and fallback page URI is not a valid URL')
    }
    console.warn(`[ReaderCache] step=source_image_request_fallback allowed=true source=${createShortReaderHash(source.sourceRuntimeId)} page=${createShortReaderHash(source.pageId)} urlHash=${createShortReaderHash(source.pageUri)}`)
    return fetchAndCacheReaderRemoteImage(source.pageUri, source.headers)
  }
  return fetchAndCacheReaderRemoteImage(source.imageUri, source.headers)
}

export function prefetchReaderRemoteImage(source: ReaderPageRenderSource): void {
  if (source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE || readerRemoteImageCacheStore === undefined) {
    return
  }
  const key = remoteFetchKey(source.imageUri, source.headers)
  if (readerPrefetchInFlight.includes(key)) {
    return
  }
  readerPrefetchInFlight.push(key)
  console.info(`[ReaderCache] step=prefetch_start key=${key} page=${source.fallbackPageIndex}`)
  fetchAndCacheReaderRemoteSource(source)
    .then((_path: string) => {
      console.info(`[ReaderCache] step=prefetch_done key=${key} page=${source.fallbackPageIndex}`)
    })
    .catch((error: Error) => {
      console.warn(`[ReaderCache] step=prefetch_done key=${key} page=${source.fallbackPageIndex} failed=true message=${error.message}`)
    })
    .finally(() => {
      const index = readerPrefetchInFlight.indexOf(key)
      if (index >= 0) {
        readerPrefetchInFlight.splice(index, 1)
      }
    })
}

export function createReaderUriDiagnostics(uri: string, pageIndex: number = 0): ReaderPageRenderDiagnostics {
  const source = createReaderUriRenderSource(uri, pageIndex)
  return createReaderSourceDiagnostics(source)
}

function createReaderSourceDiagnostics(source: ReaderPageRenderSource): ReaderPageRenderDiagnostics {
  const normalized = normalizeReaderPageUri(source.uri)
  const path = stripFileUriScheme(normalized)
  const decodedPath = decodeFileUriPath(path)
  const imageSource = source.imageUri.length > 0 ? source.imageUri : normalized
  return {
    pageIndex: source.fallbackPageIndex,
    kind: source.kind,
    imageSourceForm: getReaderImageSourceForm(source),
    hasFileScheme: normalized.startsWith('file://'),
    hasRawFragmentOrQuery: normalized.includes('#') || normalized.includes('?'),
    matchedSandboxRoot: decodedPath.length > 0 ? matchReaderSandboxRoot(decodedPath) : 'none',
    extension: getReaderUriExtension(source.uri),
    uriHash: createShortReaderHash(normalized),
    sourceHash: createShortReaderHash(imageSource),
    redactedTail: createReaderRedactedTail(source.uri),
  }
}

export function createReaderPageRenderSource(config: ReaderSessionConfig, pageIndex: number, options?: ReaderPageRenderSourceOptions): ReaderPageRenderSource {
  if (options?.preferOffline !== false) {
    const offlineDownloadSource = createReaderOfflineDownloadRenderSource(config, pageIndex)
    if (offlineDownloadSource !== undefined) {
      return offlineDownloadSource
    }
  }
  const sourceRuntimeSource = createReaderSourceRuntimeRenderSource(config, pageIndex)
  if (sourceRuntimeSource !== undefined) {
    return sourceRuntimeSource
  }
  const uri = getReaderSessionPageUri(config, pageIndex)
  return createReaderUriRenderSource(uri, pageIndex)
}

export function createReaderPageRenderDiagnostics(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderDiagnostics {
  return createReaderSourceDiagnostics(createReaderPageRenderSource(config, pageIndex))
}
