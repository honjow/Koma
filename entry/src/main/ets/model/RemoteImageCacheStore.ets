import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'

export type RemoteImageCacheHeaders = Record<string, string>

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

export interface RemoteImageCacheStats {
  totalBytes: number
  entryCount: number
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

function cacheKeyFor(url: string, headers: RemoteImageCacheHeaders | undefined): string {
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
  private entries: Map<string, RemoteImageCacheManifestEntry> = new Map<string, RemoteImageCacheManifestEntry>()

  constructor(cacheDir: string) {
    this.rootDir = joinSandboxPath(cacheDir, REMOTE_IMAGE_CACHE_DIR_NAME)
    this.manifestPath = joinSandboxPath(this.rootDir, REMOTE_IMAGE_CACHE_MANIFEST_NAME)
    this.ensureRoot()
    this.restore()
  }

  get(url: string, headers?: RemoteImageCacheHeaders): Promise<string | undefined> {
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

  async put(url: string, headers: RemoteImageCacheHeaders | undefined, bytes: ArrayBuffer): Promise<string> {
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

  async stats(): Promise<RemoteImageCacheStats> {
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
        this.entries.delete(key)
      })
      this.persist()
    }
    return {
      totalBytes,
      entryCount,
    }
  }

  async clear(): Promise<void> {
    const paths: string[] = []
    this.entries.forEach((entry: RemoteImageCacheManifestEntry) => {
      if (!paths.includes(entry.path)) {
        paths.push(entry.path)
      }
    })
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
    }
    for (const path of paths) {
      try {
        if (fs.accessSync(path)) {
          await fs.unlink(path)
        }
      } catch (_err) {
      }
    }
    this.entries.clear()
    try {
      if (fs.accessSync(this.manifestPath)) {
        await fs.unlink(this.manifestPath)
      }
    } catch (_err) {
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
