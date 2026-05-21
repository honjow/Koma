import {
  ReaderSessionConfig,
  getReaderSessionPageUri,
} from './ReaderSessionStore'

export enum ReaderPageRenderKind {
  MOCK_FALLBACK = 'mock_fallback',
  LOCAL_FILE_IMAGE = 'local_file_image',
  URI_PLACEHOLDER = 'uri_placeholder',
}

export interface ReaderPageRenderSource {
  kind: ReaderPageRenderKind
  uri: string
  imageUri: string
  fallbackPageIndex: number
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

function isAppImportExtractPath(path: string): boolean {
  const appImportRoots = [
    '/data/storage/el2/base/haps/entry/cache/import/',
    '/data/storage/el2/base/haps/entry/files/import/',
    '/data/storage/el2/base/cache/import/',
    '/data/storage/el2/base/files/import/',
  ]
  return appImportRoots.some((root: string) => {
    if (!path.startsWith(root)) {
      return false
    }
    return path.indexOf('/extract/', root.length) > root.length
  })
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

export function createReaderPageRenderSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource {
  const uri = getReaderSessionPageUri(config, pageIndex)
  if (uri.length === 0 || uri.startsWith('mock://')) {
    return {
      kind: ReaderPageRenderKind.MOCK_FALLBACK,
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
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri,
    imageUri: '',
    fallbackPageIndex: pageIndex,
  }
}
