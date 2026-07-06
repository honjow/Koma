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
import { preferences } from '@kit.ArkData'
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
import {
  OfflineDownloadedChapterStatus,
  OfflineDownloadManifestValidation,
  OfflineDownloadStore,
} from './OfflineDownloadStore'

export type ReaderRemoteImageHeaders = Record<string, string>
export type ReaderRemoteImageCacheStats = RemoteImageCacheStats

export const READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS: number[] = [
  100 * 1024 * 1024,
  DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  1024 * 1024 * 1024,
]
const READER_REMOTE_IMAGE_CACHE_PREFS_STORE_NAME: string = 'koma_reader_remote_image_cache_v1'
const READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY: string = 'reader.remoteImageCache.maxBytes'
const READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY: string = 'reader.remoteImageCache.autoCleanEnabled'

export interface ReaderRemoteImageCachePreferences {
  maxBytes: number
  autoCleanEnabled: boolean
}

export const DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES: ReaderRemoteImageCachePreferences = {
  maxBytes: DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  autoCleanEnabled: true,
}

export enum ReaderPageRenderKind {
  LOCAL_FILE_IMAGE = 'local_file_image',
  REMOTE_URL_IMAGE = 'remote_url_image',
  URI_PLACEHOLDER = 'uri_placeholder',
}

export enum ReaderPageUnavailableReason {
  OFFLINE_MISSING = 'offline_missing',
  SOURCE_UNAVAILABLE = 'source_unavailable',
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
  unavailableReason?: ReaderPageUnavailableReason
}

export interface ReaderPageRenderSourceOptions {
  preferOffline?: boolean
  offlineOnly?: boolean
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

const READER_SOURCE_UNAVAILABLE_URI_PREFIX: string = 'source-placeholder://'

interface SourceRuntimeImageHeaderRule {
  sourceRuntimeId: string
  headersRef: string
  headers: ReaderRemoteImageHeaders
}

interface SourceRuntimeImageRequestDescriptor {
  url?: string
  headers?: Record<string, string>
  headersRef?: string
  cacheKey?: string
  requiresAuth?: boolean
}

interface SourceRuntimeResolvedImageRequest {
  url: string
  headers?: ReaderRemoteImageHeaders
  cacheKeySeed?: string
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

const BLOCKED_SOURCE_IMAGE_HEADER_NAMES: string[] = [
  'authorization',
  'connection',
  'content-length',
  'cookie',
  'host',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'x-api-key',
  'x-auth-token',
]
const SOURCE_IMAGE_HEADER_MAX_COUNT: number = 16
const SOURCE_IMAGE_HEADER_VALUE_MAX_LENGTH: number = 4096

const READER_SANDBOX_ROOTS: ReaderSandboxRoot[] = [
  { label: 'cache_haps_entry', path: '/data/storage/el2/base/haps/entry/cache/import/' },
  { label: 'files_haps_entry', path: '/data/storage/el2/base/haps/entry/files/import/' },
  { label: 'cache_base', path: '/data/storage/el2/base/cache/import/' },
  { label: 'files_base', path: '/data/storage/el2/base/files/import/' },
]

const readerRemoteHeaderRules: ReaderRemoteHeaderRule[] = []
const sourceRuntimeImageHeaderRules: SourceRuntimeImageHeaderRule[] = []
let readerRemoteImageCacheStore: RemoteImageCacheStore | undefined = undefined
let readerOfflineDownloadStore: OfflineDownloadStore | undefined = undefined
let readerRemoteImageCacheMaxBytes: number = DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES
let readerRemoteImageCacheAutoCleanEnabled: boolean = true
const readerPrefetchInFlight: string[] = []

function normalizeReaderRemoteImageCacheMaxBytes(maxBytes: number): number {
  const normalized = Number.isFinite(maxBytes) ? Math.floor(maxBytes) : DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes
  return READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS.indexOf(normalized) >= 0 ?
    normalized :
    DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes
}

function normalizeReaderRemoteImageCachePreferences(
  value: ReaderRemoteImageCachePreferences,
): ReaderRemoteImageCachePreferences {
  return {
    maxBytes: normalizeReaderRemoteImageCacheMaxBytes(value.maxBytes),
    autoCleanEnabled: value.autoCleanEnabled !== false,
  }
}

export class ReaderRemoteImageCachePreferencesStore {
  private readonly context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<ReaderRemoteImageCachePreferences> {
    const store = await preferences.getPreferences(this.context, READER_REMOTE_IMAGE_CACHE_PREFS_STORE_NAME)
    const maxBytes =
      await store.get(READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY, DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes) as number
    const autoCleanEnabled =
      await store.get(READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY, DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled) as boolean
    return normalizeReaderRemoteImageCachePreferences({
      maxBytes,
      autoCleanEnabled,
    })
  }

  async save(preferencesValue: ReaderRemoteImageCachePreferences): Promise<void> {
    const normalized = normalizeReaderRemoteImageCachePreferences(preferencesValue)
    const store = await preferences.getPreferences(this.context, READER_REMOTE_IMAGE_CACHE_PREFS_STORE_NAME)
    await store.put(READER_REMOTE_IMAGE_CACHE_MAX_BYTES_KEY, normalized.maxBytes)
    await store.put(READER_REMOTE_IMAGE_CACHE_AUTO_CLEAN_KEY, normalized.autoCleanEnabled)
    await store.flush()
  }

  async saveMaxBytes(maxBytes: number): Promise<ReaderRemoteImageCachePreferences> {
    const current = await this.load()
    const normalized = normalizeReaderRemoteImageCachePreferences({
      maxBytes,
      autoCleanEnabled: current.autoCleanEnabled,
    })
    await this.save(normalized)
    return normalized
  }

  async saveAutoCleanEnabled(autoCleanEnabled: boolean): Promise<ReaderRemoteImageCachePreferences> {
    const current = await this.load()
    const normalized = normalizeReaderRemoteImageCachePreferences({
      maxBytes: current.maxBytes,
      autoCleanEnabled,
    })
    await this.save(normalized)
    return normalized
  }
}

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
    if (Object.keys(headers).length >= SOURCE_IMAGE_HEADER_MAX_COUNT) {
      return
    }
    const normalizedName = name.trim()
    const value = raw[name]
    if (isSafeSourceImageHeaderName(normalizedName) && isSafeSourceImageHeaderValue(value)) {
      headers[normalizedName] = value.trim()
    }
  })
  return Object.keys(headers).length === 0 ? undefined : headers
}

function safeSourceImageRef(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const normalized = value.trim()
  if (normalized.length === 0 ||
    normalized.length > 256 ||
    normalized.indexOf('\r') >= 0 ||
    normalized.indexOf('\n') >= 0) {
    return undefined
  }
  return normalized
}

function sourceImageCacheKeySeed(sourceRuntimeId: string, pageId: string, payload: SourceRuntimeImageRequestDescriptor): string | undefined {
  const cacheKey = safeSourceImageRef(payload.cacheKey)
  if (cacheKey !== undefined) {
    return `source:${sourceRuntimeId}:image:${cacheKey}`
  }
  const headersRef = safeSourceImageRef(payload.headersRef)
  if (headersRef !== undefined) {
    return `source:${sourceRuntimeId}:image-ref:${headersRef}:${pageId}`
  }
  return undefined
}

function mergeReaderRemoteImageHeaders(
  sourceHeaders: ReaderRemoteImageHeaders | undefined,
  hostHeaders: ReaderRemoteImageHeaders | undefined,
): ReaderRemoteImageHeaders | undefined {
  if (sourceHeaders === undefined) {
    return hostHeaders
  }
  if (hostHeaders === undefined) {
    return sourceHeaders
  }
  const merged: ReaderRemoteImageHeaders = {}
  Object.keys(sourceHeaders).forEach((name: string) => {
    merged[name] = sourceHeaders[name]
  })
  Object.keys(hostHeaders).forEach((name: string) => {
    merged[name] = hostHeaders[name]
  })
  return merged
}

function isSafeSourceImageHeaderName(name: string): boolean {
  if (name.length === 0 || BLOCKED_SOURCE_IMAGE_HEADER_NAMES.indexOf(name.toLocaleLowerCase()) >= 0) {
    return false
  }
  return /^[A-Za-z0-9!#$%&'*+.^_`|~-]+$/.test(name)
}

function isSafeSourceImageHeaderValue(value: string): boolean {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    value.length <= SOURCE_IMAGE_HEADER_VALUE_MAX_LENGTH &&
    value.indexOf('\r') < 0 &&
    value.indexOf('\n') < 0
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
  if (uri.startsWith(READER_SOURCE_UNAVAILABLE_URI_PREFIX)) {
    return {
      kind: ReaderPageRenderKind.URI_PLACEHOLDER,
      uri,
      imageUri: '',
      fallbackPageIndex: pageIndex,
      unavailableReason: ReaderPageUnavailableReason.SOURCE_UNAVAILABLE,
    }
  }
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

export function installSourceRuntimeImageHeaders(
  sourceRuntimeId: string,
  headersRef: string,
  headers: ReaderRemoteImageHeaders,
): void {
  const normalizedSourceId = sourceRuntimeId.trim()
  const normalizedRef = safeSourceImageRef(headersRef)
  if (normalizedSourceId.length === 0 || normalizedRef === undefined || Object.keys(headers).length === 0) {
    return
  }
  const rule: SourceRuntimeImageHeaderRule = {
    sourceRuntimeId: normalizedSourceId,
    headersRef: normalizedRef,
    headers,
  }
  const index = sourceRuntimeImageHeaderRules.findIndex((item: SourceRuntimeImageHeaderRule): boolean => {
    return item.sourceRuntimeId === normalizedSourceId && item.headersRef === normalizedRef
  })
  if (index >= 0) {
    sourceRuntimeImageHeaderRules[index] = rule
  } else {
    sourceRuntimeImageHeaderRules.push(rule)
  }
  console.info('[ReaderCache] step=source_image_headers_installed')
}

function resolveSourceRuntimeImageHeaders(sourceRuntimeId: string, headersRef: string | undefined): ReaderRemoteImageHeaders | undefined {
  const normalizedRef = safeSourceImageRef(headersRef)
  if (normalizedRef === undefined) {
    return undefined
  }
  const matched = sourceRuntimeImageHeaderRules.find((item: SourceRuntimeImageHeaderRule): boolean => {
    return item.sourceRuntimeId === sourceRuntimeId && item.headersRef === normalizedRef
  })
  return matched?.headers
}

export async function installReaderRemoteHeadersForComic(context: common.UIAbilityContext, comic: Comic): Promise<void> {
  if (comic.sourceKind !== ComicSourceKind.KOMGA_REMOTE &&
    comic.sourceKind !== ComicSourceKind.KAVITA_REMOTE &&
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
  if (comic.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
    const record = await store.loadKavita()
    if (record === undefined) {
      throw new Error('Kavita server is not configured')
    }
    installReaderRemoteHeaders(store.createKavitaClient(record).getBaseUrl(), store.getKavitaImageHeaders(record))
    console.info('[Favorite] step=reader_headers_installed kind=kavita')
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

export function configureReaderRemoteImageCache(
  cacheDir: string,
  maxBytes: number = DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES,
  autoCleanEnabled: boolean = true,
): void {
  if (cacheDir.length === 0) {
    return
  }
  if (readerRemoteImageCacheStore === undefined) {
    readerRemoteImageCacheStore = new RemoteImageCacheStore(cacheDir)
    console.info('[ReaderCache] step=ready')
  }
  readerRemoteImageCacheMaxBytes = maxBytes
  readerRemoteImageCacheAutoCleanEnabled = autoCleanEnabled
  if (readerRemoteImageCacheAutoCleanEnabled) {
    readerRemoteImageCacheStore.evictIfOver(readerRemoteImageCacheMaxBytes)
  }
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

function createReaderOfflineDownloadRenderSource(config: ReaderSessionConfig, pageIndex: number, offlineOnly: boolean = false): ReaderPageRenderSource | undefined {
  if (readerOfflineDownloadStore === undefined || config.comicId.length === 0 || config.chapterId.length === 0) {
    return undefined
  }
  const pageId = getReaderSessionPageId(config, pageIndex)
  const validation = readerOfflineDownloadStore.validateDownloadedChapter(config.comicId, config.chapterId, {
    validateContentHash: false,
  })
  if (validation.manifest === undefined && validation.reasonCode === 'manifest_missing') {
    return undefined
  }
  const localPath = readerOfflineDownloadStore.resolveDownloadedPage(config.comicId, config.chapterId, pageId, pageIndex, {
    validateContentHash: false,
  })
  if (localPath === undefined) {
    if (offlineOnly && isOfflineManifestReaderOwned(validation)) {
      console.warn(`[ReaderOffline] step=offline_page_unavailable comic=${createShortReaderHash(config.comicId)} chapter=${createShortReaderHash(config.chapterId)} page=${pageIndex} reason=${validation.reasonCode ?? 'page_unavailable'}`)
      return createReaderOfflineUnavailableSource(config, pageIndex)
    }
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

function isOfflineManifestReaderOwned(validation: OfflineDownloadManifestValidation): boolean {
  return validation.manifest !== undefined &&
    (validation.status === OfflineDownloadedChapterStatus.DOWNLOADED ||
      validation.status === OfflineDownloadedChapterStatus.PARTIAL ||
      validation.status === OfflineDownloadedChapterStatus.CORRUPT)
}

function createReaderOfflineUnavailableSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource {
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri: `offline-missing://${createShortReaderHash(config.comicId)}/${createShortReaderHash(config.chapterId)}/${pageIndex}`,
    imageUri: '',
    fallbackPageIndex: pageIndex,
    pageId: getReaderSessionPageId(config, pageIndex),
    unavailableReason: ReaderPageUnavailableReason.OFFLINE_MISSING,
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

export async function resolveLocalCached(url: string, headers?: ReaderRemoteImageHeaders, cacheKeySeed?: string): Promise<string | undefined> {
  if (readerRemoteImageCacheStore === undefined) {
    console.info('[ReaderCache] step=miss reason=unconfigured')
    return undefined
  }
  return readerRemoteImageCacheStore.get(url, headers, cacheKeySeed)
}

export async function fetchAndCacheReaderRemoteImage(url: string, headers?: ReaderRemoteImageHeaders, cacheKeySeed?: string): Promise<string> {
  const cachedPath = await resolveLocalCached(url, headers, cacheKeySeed)
  if (cachedPath !== undefined) {
    return cachedPath
  }
  const bytes = await fetchReaderRemoteImageBytes(url, headers)
  if (readerRemoteImageCacheStore === undefined) {
    throw new Error('Reader remote image cache is unavailable')
  }
  const path = await readerRemoteImageCacheStore.put(url, headers, bytes, cacheKeySeed)
  if (readerRemoteImageCacheAutoCleanEnabled) {
    await readerRemoteImageCacheStore.evictIfOver(readerRemoteImageCacheMaxBytes)
  }
  return path
}

export async function fetchAndCacheSourceRuntimeRemoteImage(
  sourceRuntimeId: string,
  imageUrl: string,
  imageId?: string,
): Promise<string> {
  const normalizedSourceId = sourceRuntimeId.trim()
  if (normalizedSourceId.length === 0) {
    return fetchAndCacheReaderRemoteImage(imageUrl)
  }
  const pageId = imageId !== undefined && imageId.trim().length > 0
    ? `cover:${imageId.trim()}`
    : `cover:${createShortReaderHash(imageUrl)}`
  const resolved = resolveSourceRuntimeImageRequest(normalizedSourceId, pageId, imageUrl)
  if (resolved !== undefined) {
    return fetchAndCacheReaderRemoteImage(resolved.url, resolved.headers, resolved.cacheKeySeed)
  }
  if (!isReaderRemoteImageSourceUri(imageUrl)) {
    console.warn(`[ReaderCache] step=source_cover_request_fallback allowed=false source=${createShortReaderHash(normalizedSourceId)} urlHash=${createShortReaderHash(imageUrl)}`)
    throw new Error('Source cover image request failed and fallback cover URI is not a valid URL')
  }
  console.warn(`[ReaderCache] step=source_cover_request_fallback allowed=true source=${createShortReaderHash(normalizedSourceId)} urlHash=${createShortReaderHash(imageUrl)}`)
  return fetchAndCacheReaderRemoteImage(imageUrl)
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

function isSourceRuntimeImageRequestOperation(operation: string | undefined): boolean {
  return operation === 'get_image_request' ||
    operation === 'image_request' ||
    operation === 'modify_image_request'
}

function resolveSourceRuntimeImageRequest(sourceRuntimeId: string, pageId: string, pageUri?: string): SourceRuntimeResolvedImageRequest | undefined {
  const args: ReaderSourceImageRequestArgs = { pageId }
  const normalizedPageUri = pageUri?.trim()
  if (normalizedPageUri !== undefined && normalizedPageUri.length > 0) {
    args.pageUri = normalizedPageUri
    if (isReaderRemoteImageSourceUri(normalizedPageUri)) {
      args.url = normalizedPageUri
    }
  }
  const settings = appSourceSettingsStore.loadForSource(sourceRuntimeId)
  const hostHints: ReaderSourceImageRequestHostHints = { network: true }
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
    if (summary.response === undefined || summary.response.ok !== true || !isSourceRuntimeImageRequestOperation(summary.response.operation)) {
      console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=${summary.reasonCode ?? 'runtime_response'}`)
      return undefined
    }
    const payload = sourceRuntimeImageRequestPayload(summary.response.data as Record<string, Object> | undefined)
    if (payload === undefined || payload.url === undefined || !isReaderRemoteImageSourceUri(payload.url)) {
      console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=invalid_url`)
      return undefined
    }
    const headers = normalizeSourceImageHeaders(payload.headers)
    const headersRef = safeSourceImageRef(payload.headersRef)
    const hostHeaders = resolveSourceRuntimeImageHeaders(sourceRuntimeId, headersRef)
    if (payload.requiresAuth === true && (headersRef === undefined || hostHeaders === undefined)) {
      console.warn(`[ReaderCache] step=source_image_request failed=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} reason=missing_headers_ref`)
      return undefined
    }
    const resolvedHeaders = mergeReaderRemoteImageHeaders(headers, hostHeaders)
    const cacheKeySeed = sourceImageCacheKeySeed(sourceRuntimeId, pageId, payload)
    console.info(`[ReaderCache] step=source_image_request ok=true source=${createShortReaderHash(sourceRuntimeId)} page=${createShortReaderHash(pageId)} urlHash=${createShortReaderHash(payload.url)} headers=${resolvedHeaders === undefined ? 0 : Object.keys(resolvedHeaders).length}`)
    return {
      url: payload.url,
      headers: resolvedHeaders,
      cacheKeySeed,
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
      return fetchAndCacheReaderRemoteImage(resolved.url, resolved.headers, resolved.cacheKeySeed)
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
      void error
      console.warn(`[ReaderCache] step=prefetch_done key=${key} page=${source.fallbackPageIndex} failed=true code=reader_prefetch_failed`)
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
  let offlineDownloadSource: ReaderPageRenderSource | undefined = undefined
  if (options?.preferOffline !== false) {
    offlineDownloadSource = createReaderOfflineDownloadRenderSource(config, pageIndex, options?.offlineOnly === true)
    if (offlineDownloadSource !== undefined) {
      return offlineDownloadSource
    }
  }
  const uri = getReaderSessionPageUri(config, pageIndex)
  if (uri.startsWith(READER_SOURCE_UNAVAILABLE_URI_PREFIX)) {
    return createReaderUriRenderSource(uri, pageIndex)
  }
  if (options?.offlineOnly === true) {
    const localSource = createReaderUriRenderSource(uri, pageIndex)
    if (localSource.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
      return localSource
    }
    return createReaderOfflineUnavailableSource(config, pageIndex)
  }
  const sourceRuntimeSource = createReaderSourceRuntimeRenderSource(config, pageIndex)
  if (sourceRuntimeSource !== undefined) {
    return sourceRuntimeSource
  }
  return createReaderUriRenderSource(uri, pageIndex)
}

export function createReaderPageRenderDiagnostics(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderDiagnostics {
  return createReaderSourceDiagnostics(createReaderPageRenderSource(config, pageIndex))
}

export function createReaderPageSourceDiagnostics(source: ReaderPageRenderSource): ReaderPageRenderDiagnostics {
  return createReaderSourceDiagnostics(source)
}
