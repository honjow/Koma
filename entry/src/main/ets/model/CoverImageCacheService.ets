import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { ComicSourceKind } from './ComicModels'
import {
  RemoteImageCacheHeaders,
  RemoteImageCacheStore,
} from './RemoteImageCacheStore'
import {
  KavitaServerRecord,
  KomgaServerRecord,
  OpdsServerRecord,
  RemoteServerStore,
  WebDavServerRecord,
} from './RemoteServerStore'
import { KomgaHeaders } from '../remote/KomgaClient'

const COVER_IMAGE_CACHE_DIRECTORY_NAME: string = 'cover-image-cache'
const COVER_IMAGE_CACHE_MAX_BYTES: number = 96 * 1024 * 1024

export interface CoverImageRequest {
  uri: string
  identity: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
}

class EmptyCoverHttpHeader {
}

class ResolvedCoverImageRequest {
  url: string
  cacheNamespace: string
  headers: RemoteImageCacheHeaders | undefined

  constructor(url: string, cacheNamespace: string, headers?: RemoteImageCacheHeaders) {
    this.url = url
    this.cacheNamespace = cacheNamespace
    this.headers = headers
  }
}

let coverImageCacheStore: RemoteImageCacheStore | null = null
const coverImageInFlight: Map<string, Promise<string>> = new Map<string, Promise<string>>()

function isRemoteHttpUri(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('http://') || normalized.startsWith('https://')
}

function isDirectLocalUri(uri: string): boolean {
  const normalized = uri.toLocaleLowerCase()
  return normalized.startsWith('file://') || normalized.startsWith('mock://')
}

function isRemoteServerSourceKind(sourceKind: ComicSourceKind | undefined): boolean {
  return sourceKind === ComicSourceKind.KOMGA_REMOTE ||
    sourceKind === ComicSourceKind.KAVITA_REMOTE ||
    sourceKind === ComicSourceKind.WEBDAV_REMOTE ||
    sourceKind === ComicSourceKind.OPDS_REMOTE
}

function resolveServerUri(uri: string, prefix: string): string {
  if (isRemoteHttpUri(uri)) {
    return uri
  }
  const normalizedPrefix = prefix.trim()
  if (normalizedPrefix.length === 0) {
    return uri
  }
  return `${normalizedPrefix.endsWith('/') ? normalizedPrefix : `${normalizedPrefix}/`}${uri.replace(/^\/+/, '')}`
}

function httpOriginKey(uri: string): string {
  const match = /^(https?):\/\/(?:[^@/?#]*@)?(\[[^\]]+\]|[^:/?#]+)(?::([0-9]+))?(?:[/?#]|$)/i.exec(uri.trim())
  if (match === null) {
    return ''
  }
  const scheme = match[1].toLocaleLowerCase()
  const host = match[2].toLocaleLowerCase()
  if (host.length === 0) {
    return ''
  }
  const specifiedPort = match[3] ?? ''
  const effectivePort = specifiedPort.length > 0
    ? specifiedPort
    : (scheme === 'https' ? '443' : '80')
  return `${scheme}://${host}:${effectivePort}`
}

function privateServerHeadersForRequest(
  requestUri: string,
  serverBaseUrl: string,
  headers: KomgaHeaders,
): RemoteImageCacheHeaders | undefined {
  // Relative metadata is resolved against its configured server. An absolute
  // URL may instead be a CDN or another host, which must never receive that
  // private server's credentials.
  if (!isRemoteHttpUri(requestUri)) {
    return imageHeaders(headers)
  }
  const requestOrigin = httpOriginKey(requestUri)
  const serverOrigin = httpOriginKey(serverBaseUrl)
  if (requestOrigin.length === 0 || requestOrigin !== serverOrigin) {
    return undefined
  }
  return imageHeaders(headers)
}

function matchingServerId(configuredServerId: string, requestedServerId?: string): boolean {
  const requested = requestedServerId?.trim() ?? ''
  // A typed remote comic must identify its own server. Applying the current
  // server's credentials to an older record with no ID can both fail and leak
  // credentials to an unrelated absolute cover URL.
  return requested.length > 0 && configuredServerId === requested
}

function imageHeaders(headers: KomgaHeaders): RemoteImageCacheHeaders | undefined {
  const out: RemoteImageCacheHeaders = {}
  if (headers.authorization !== undefined && headers.authorization.length > 0) {
    out['Authorization'] = headers.authorization
  }
  if (headers.accept !== undefined && headers.accept.length > 0) {
    out['Accept'] = headers.accept
  }
  if (headers.contentType !== undefined && headers.contentType.length > 0) {
    out['Content-Type'] = headers.contentType
  }
  if (headers.xApiKey !== undefined && headers.xApiKey.length > 0) {
    out['X-API-Key'] = headers.xApiKey
  }
  if (headers.xAuthToken !== undefined && headers.xAuthToken.length > 0) {
    out['X-Auth-Token'] = headers.xAuthToken
  }
  return Object.keys(out).length > 0 ? out : undefined
}

function cacheNamespaceFor(request: CoverImageRequest, url: string): string {
  const sourceKind = request.sourceKind ?? ComicSourceKind.PRIVATE_LIBRARY
  const serverId = request.remoteServerId?.trim() ?? ''
  const identity = request.identity.trim().length > 0 ? request.identity.trim() : request.uri
  return `cover:${sourceKind}:${serverId}:${identity}:${url}`
}

function configuredCoverRequest(
  request: CoverImageRequest,
  url: string,
  headers?: RemoteImageCacheHeaders,
): ResolvedCoverImageRequest {
  return new ResolvedCoverImageRequest(url, cacheNamespaceFor(request, url), headers)
}

async function resolveKomgaCoverRequest(
  store: RemoteServerStore,
  request: CoverImageRequest,
): Promise<ResolvedCoverImageRequest> {
  const record: KomgaServerRecord | undefined = await store.loadKomga()
  if (record === undefined || !matchingServerId(record.server.id, request.remoteServerId)) {
    throw new Error('cover_image_komga_server_unavailable')
  }
  const url = resolveServerUri(request.uri, record.server.baseUrl)
  return configuredCoverRequest(
    request,
    url,
    privateServerHeadersForRequest(request.uri, record.server.baseUrl, store.getKomgaImageHeaders(record)),
  )
}

async function resolveKavitaCoverRequest(
  store: RemoteServerStore,
  request: CoverImageRequest,
): Promise<ResolvedCoverImageRequest> {
  const record: KavitaServerRecord | undefined = await store.loadKavita()
  if (record === undefined || !matchingServerId(record.server.id, request.remoteServerId)) {
    throw new Error('cover_image_kavita_server_unavailable')
  }
  const url = resolveServerUri(request.uri, record.server.baseUrl)
  return configuredCoverRequest(
    request,
    url,
    privateServerHeadersForRequest(request.uri, record.server.baseUrl, store.getKavitaImageHeaders(record)),
  )
}

async function resolveWebDavCoverRequest(
  store: RemoteServerStore,
  request: CoverImageRequest,
): Promise<ResolvedCoverImageRequest> {
  const record: WebDavServerRecord | undefined = await store.loadWebDav()
  if (record === undefined || !matchingServerId(record.server.id, request.remoteServerId)) {
    throw new Error('cover_image_webdav_server_unavailable')
  }
  const url = resolveServerUri(request.uri, record.server.baseUrl)
  return configuredCoverRequest(
    request,
    url,
    privateServerHeadersForRequest(request.uri, record.server.baseUrl, store.getWebDavImageHeaders(record)),
  )
}

async function resolveOpdsCoverRequest(
  store: RemoteServerStore,
  request: CoverImageRequest,
): Promise<ResolvedCoverImageRequest> {
  const record: OpdsServerRecord | undefined = await store.loadOpds()
  if (record === undefined || !matchingServerId(record.server.id, request.remoteServerId)) {
    throw new Error('cover_image_opds_server_unavailable')
  }
  const url = resolveServerUri(request.uri, record.server.rootUrl)
  return configuredCoverRequest(
    request,
    url,
    privateServerHeadersForRequest(request.uri, record.server.rootUrl, store.getOpdsImageHeaders(record)),
  )
}

async function resolveCoverRequest(
  context: common.UIAbilityContext,
  request: CoverImageRequest,
): Promise<ResolvedCoverImageRequest> {
  // Local and mock covers are already concrete image sources. Never append a
  // private-server base URL to them merely because their comic came from one.
  // Relative remote cover paths intentionally continue below so the matching
  // server's base URL and credentials can resolve them.
  if (isDirectLocalUri(request.uri)) {
    return configuredCoverRequest(request, request.uri)
  }
  // Legacy generic private-library records may contain a non-runtime image
  // URL but no typed server identity. Treat them as ordinary URLs instead of
  // guessing which configured server owns their credentials.
  if (!isRemoteServerSourceKind(request.sourceKind)) {
    return configuredCoverRequest(request, request.uri)
  }
  const store = new RemoteServerStore(context)
  if (request.sourceKind === ComicSourceKind.KOMGA_REMOTE) {
    return resolveKomgaCoverRequest(store, request)
  }
  if (request.sourceKind === ComicSourceKind.KAVITA_REMOTE) {
    return resolveKavitaCoverRequest(store, request)
  }
  if (request.sourceKind === ComicSourceKind.WEBDAV_REMOTE) {
    return resolveWebDavCoverRequest(store, request)
  }
  if (request.sourceKind === ComicSourceKind.OPDS_REMOTE) {
    return resolveOpdsCoverRequest(store, request)
  }
  return configuredCoverRequest(request, request.uri)
}

function httpHeaders(headers?: RemoteImageCacheHeaders): Object {
  if (headers === undefined || Object.keys(headers).length === 0) {
    return new EmptyCoverHttpHeader()
  }
  return headers as Object
}

async function downloadCoverBytes(url: string, headers?: RemoteImageCacheHeaders): Promise<ArrayBuffer> {
  const request = http.createHttp()
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      header: httpHeaders(headers),
      readTimeout: 60000,
      connectTimeout: 30000,
    })
    if (response.responseCode !== 200) {
      console.warn(`[CoverCache] step=http_status_failed status=${response.responseCode}`)
      throw new Error(`cover_image_http_${response.responseCode}`)
    }
    return response.result as ArrayBuffer
  } catch (error) {
    const businessError = error as BusinessError
    console.warn(`[CoverCache] step=http_request_failed code=${businessError.code === undefined ? 'unknown' : businessError.code}`)
    throw new Error(`cover_image_fetch_failed_${businessError.code === undefined ? 'unknown' : businessError.code}`)
  } finally {
    request.destroy()
  }
}

function cacheStoreFor(context: common.UIAbilityContext): RemoteImageCacheStore {
  if (coverImageCacheStore === null) {
    coverImageCacheStore = new RemoteImageCacheStore(context.cacheDir, COVER_IMAGE_CACHE_DIRECTORY_NAME)
  }
  return coverImageCacheStore
}

/**
 * Resolves an image through an explicit cover request rather than Reader's mutable
 * session headers. Local and mock URIs remain direct image sources.
 */
export async function resolveCachedCoverImage(
  context: common.UIAbilityContext,
  request: CoverImageRequest,
): Promise<string> {
  const resolved = await resolveCoverRequest(context, request)
  if (!isRemoteHttpUri(resolved.url)) {
    return resolved.url
  }
  const cache = cacheStoreFor(context)
  const cached = await cache.get(resolved.url, resolved.headers, resolved.cacheNamespace)
  if (cached !== undefined && cached.length > 0) {
    return cached
  }
  const existing = coverImageInFlight.get(resolved.cacheNamespace)
  if (existing !== undefined) {
    return existing
  }
  const loading = downloadCoverBytes(resolved.url, resolved.headers)
    .then((bytes: ArrayBuffer): Promise<string> => {
      return cache.put(resolved.url, resolved.headers, bytes, resolved.cacheNamespace)
    })
    .then((path: string): string => {
      void cache.evictIfOver(COVER_IMAGE_CACHE_MAX_BYTES)
      return path
    })
  coverImageInFlight.set(resolved.cacheNamespace, loading)
  try {
    return await loading
  } finally {
    if (coverImageInFlight.get(resolved.cacheNamespace) === loading) {
      coverImageInFlight.delete(resolved.cacheNamespace)
    }
  }
}
