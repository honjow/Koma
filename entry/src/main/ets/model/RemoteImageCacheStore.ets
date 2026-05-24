import { fileIo as fs } from '@kit.CoreFileKit'
import { KomgaHeaders } from '../remote/KomgaClient'

export const DEFAULT_REMOTE_IMAGE_CACHE_MAX_BYTES: number = 500 * 1024 * 1024
const REMOTE_IMAGE_CACHE_SCHEMA_VERSION: number = 1
const REMOTE_IMAGE_CACHE_DIR_NAME: string = 'reader-remote-image-cache'
const REMOTE_IMAGE_CACHE_MANIFEST_NAME: string = 'manifest.v1.json'

export interface RemoteImageCacheManifestEntry {
  key: string
  url: string
  path: string
  size: number
  lastAccessAt: number
}

interface RemoteImageCacheManifestDocument {
  schemaVersion: number
  entries: RemoteImageCacheManifestEntry[]
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

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

function writeBytesSync(path: string, bytes: ArrayBuffer): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, bytes)
  } finally {
    closeFileQuietly(file)
  }
}

function stableHeaderValue(value: string | undefined): string {
  return value === undefined ? '' : value
}

function stableHeadersKey(headers: KomgaHeaders | undefined): string {
  if (headers === undefined) {
    return ''
  }
  if (headers.accept === undefined &&
    headers.authorization === undefined &&
    headers.contentType === undefined &&
    headers.xApiKey === undefined &&
    headers.xAuthToken === undefined) {
    return ''
  }
  return [
    `accept=${stableHeaderValue(headers.accept)}`,
    `authorization=${stableHeaderValue(headers.authorization)}`,
    `contentType=${stableHeaderValue(headers.contentType)}`,
    `xApiKey=${stableHeaderValue(headers.xApiKey)}`,
    `xAuthToken=${stableHeaderValue(headers.xAuthToken)}`,
  ].join('\n')
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

function cacheKeyFor(url: string, headers: KomgaHeaders | undefined): string {
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

export class RemoteImageCacheStore {
  private readonly rootDir: string
  private readonly manifestPath: string
  private entries: Map<string, RemoteImageCacheManifestEntry> = new Map<string, RemoteImageCacheManifestEntry>()

  constructor(cacheDir: string) {
    this.rootDir = joinSandboxPath(cacheDir, REMOTE_IMAGE_CACHE_DIR_NAME)
    this.manifestPath = joinSandboxPath(this.rootDir, REMOTE_IMAGE_CACHE_MANIFEST_NAME)
    this.ensureRoot()
    this.restore()
  }

  get(url: string, headers?: KomgaHeaders): Promise<string | undefined> {
    const key = cacheKeyFor(url, headers)
    const entry = this.entries.get(key)
    if (entry === undefined) {
      console.info(`[ReaderCache] step=miss key=${key}`)
      return Promise.resolve(undefined)
    }
    if (!fs.accessSync(entry.path)) {
      this.entries.delete(key)
      this.persist()
      console.info(`[ReaderCache] step=miss key=${key}`)
      return Promise.resolve(undefined)
    }
    entry.lastAccessAt = Date.now()
    this.entries.set(key, entry)
    this.persist()
    console.info(`[ReaderCache] step=hit key=${key} size=${entry.size}`)
    return Promise.resolve(entry.path)
  }

  async put(url: string, headers: KomgaHeaders | undefined, bytes: ArrayBuffer): Promise<string> {
    const key = cacheKeyFor(url, headers)
    const filePath = joinSandboxPath(this.rootDir, `${key}.${extensionForUrl(url)}`)
    writeBytesSync(filePath, bytes)
    const stat = fs.statSync(filePath)
    this.entries.set(key, {
      key,
      url,
      path: filePath,
      size: stat.size,
      lastAccessAt: Date.now(),
    })
    this.persist()
    return filePath
  }

  async evictIfOver(maxBytes: number): Promise<void> {
    if (maxBytes <= 0) {
      return
    }
    let total = 0
    const rows: RemoteImageCacheManifestEntry[] = []
    this.entries.forEach((entry: RemoteImageCacheManifestEntry) => {
      if (fs.accessSync(entry.path)) {
        total += entry.size
        rows.push(entry)
      }
    })
    if (total <= maxBytes) {
      return
    }
    rows.sort((left: RemoteImageCacheManifestEntry, right: RemoteImageCacheManifestEntry) => {
      return left.lastAccessAt - right.lastAccessAt
    })
    for (const entry of rows) {
      if (total <= maxBytes) {
        break
      }
      try {
        await fs.unlink(entry.path)
      } catch (_err) {
      }
      this.entries.delete(entry.key)
      total -= entry.size
      console.info(`[ReaderCache] step=evict key=${entry.key} size=${entry.size} total=${total}`)
    }
    this.persist()
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
        if (entry.key.length > 0 && entry.path.length > 0 && entry.size > 0) {
          this.entries.set(entry.key, entry)
        }
      })
    } catch (_err) {
      this.entries.clear()
    }
  }

  private persist(): void {
    const document: RemoteImageCacheManifestDocument = {
      schemaVersion: REMOTE_IMAGE_CACHE_SCHEMA_VERSION,
      entries: Array.from(this.entries.values()),
    }
    writeTextSync(this.manifestPath, JSON.stringify(document))
  }
}
