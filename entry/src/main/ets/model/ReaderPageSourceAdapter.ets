import {
  ReaderSessionConfig,
  getReaderSessionPageUri,
} from './ReaderSessionStore'
import { KomgaHeaders } from '../remote/KomgaClient'

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
  headers?: KomgaHeaders
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
  headers: KomgaHeaders
}

const READER_SANDBOX_ROOTS: ReaderSandboxRoot[] = [
  { label: 'cache_haps_entry', path: '/data/storage/el2/base/haps/entry/cache/import/' },
  { label: 'files_haps_entry', path: '/data/storage/el2/base/haps/entry/files/import/' },
  { label: 'cache_base', path: '/data/storage/el2/base/cache/import/' },
  { label: 'files_base', path: '/data/storage/el2/base/files/import/' },
]

const readerRemoteHeaderRules: ReaderRemoteHeaderRule[] = []

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

function resolveReaderRemoteHeaders(uri: string): KomgaHeaders | undefined {
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
    headers,
  }
  if (index >= 0) {
    readerRemoteHeaderRules[index] = rule
  } else {
    readerRemoteHeaderRules.push(rule)
  }
  console.info('[Reader] remote headers installed')
}

export function createReaderUriDiagnostics(uri: string, pageIndex: number = 0): ReaderPageRenderDiagnostics {
  const normalized = normalizeReaderPageUri(uri)
  const path = stripFileUriScheme(normalized)
  const decodedPath = decodeFileUriPath(path)
  const source = createReaderUriRenderSource(uri, pageIndex)
  const imageSource = source.imageUri.length > 0 ? source.imageUri : ''
  return {
    pageIndex,
    kind: source.kind,
    imageSourceForm: getReaderImageSourceForm(source),
    hasFileScheme: normalized.startsWith('file://'),
    hasRawFragmentOrQuery: normalized.includes('#') || normalized.includes('?'),
    matchedSandboxRoot: decodedPath.length > 0 ? matchReaderSandboxRoot(decodedPath) : 'none',
    extension: getReaderUriExtension(uri),
    uriHash: createShortReaderHash(normalized),
    sourceHash: createShortReaderHash(imageSource.length > 0 ? imageSource : normalized),
    redactedTail: createReaderRedactedTail(uri),
  }
}

export function createReaderPageRenderSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource {
  const uri = getReaderSessionPageUri(config, pageIndex)
  return createReaderUriRenderSource(uri, pageIndex)
}

export function createReaderPageRenderDiagnostics(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderDiagnostics {
  return createReaderUriDiagnostics(getReaderSessionPageUri(config, pageIndex), pageIndex)
}
