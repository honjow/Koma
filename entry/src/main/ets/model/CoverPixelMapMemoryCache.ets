import { image } from '@kit.ImageKit'

// This cache only holds decoded library-cover thumbnails for the current app
// process. Remote bytes stay in CoverImageCacheService's disk cache; Reader
// pages intentionally keep their own, separate image lifecycle.
// Match NextE's bounded ImageKnife cover-memory budget while keeping the
// ownership model explicit for ArkUI PixelMap objects.
const COVER_PIXEL_MAP_MEMORY_MAX_ENTRIES: number = 128
const COVER_PIXEL_MAP_MEMORY_MAX_BYTES: number = 32 * 1024 * 1024

class CoverPixelMapCacheEntry {
  readonly key: string
  readonly token: number
  readonly pixelMap: image.PixelMap
  readonly byteSize: number
  lastAccessAt: number
  leaseCount: number = 0
  indexed: boolean = true

  constructor(
    key: string,
    token: number,
    pixelMap: image.PixelMap,
    byteSize: number,
  ) {
    this.key = key
    this.token = token
    this.pixelMap = pixelMap
    this.byteSize = byteSize
    this.lastAccessAt = Date.now()
  }
}

/**
 * A component may render a PixelMap only while it owns a lease. The cache is
 * the sole owner that eventually calls PixelMap.release(), so a recycled row
 * can never release an image still shown by another row.
 */
export class CoverPixelMapLease {
  readonly pixelMap: image.PixelMap
  readonly key: string
  readonly entryToken: number
  released: boolean = false

  constructor(pixelMap: image.PixelMap, key: string, entryToken: number) {
    this.pixelMap = pixelMap
    this.key = key
    this.entryToken = entryToken
  }
}

export class CoverPixelMapMemoryCache {
  private readonly entriesByKey: Map<string, CoverPixelMapCacheEntry> = new Map<string, CoverPixelMapCacheEntry>()
  private readonly entriesByToken: Map<number, CoverPixelMapCacheEntry> = new Map<number, CoverPixelMapCacheEntry>()
  private readonly inFlightByKey: Map<string, Promise<CoverPixelMapLease>> = new Map<string, Promise<CoverPixelMapLease>>()
  private nextToken: number = 1

  acquire(key: string): CoverPixelMapLease | undefined {
    const entry = this.entriesByKey.get(key)
    if (entry === undefined || !entry.indexed) {
      return undefined
    }
    entry.lastAccessAt = Date.now()
    entry.leaseCount += 1
    return new CoverPixelMapLease(entry.pixelMap, entry.key, entry.token)
  }

  private async putAndAcquire(
    key: string,
    pixelMap: image.PixelMap,
    byteSize: number,
  ): Promise<CoverPixelMapLease> {
    const existing = this.entriesByKey.get(key)
    if (existing !== undefined && existing.indexed) {
      // A concurrent decode completed first. The cache keeps that winning map;
      // this just-created map has no consumer and can be released immediately.
      await pixelMap.release()
      existing.lastAccessAt = Date.now()
      existing.leaseCount += 1
      return new CoverPixelMapLease(existing.pixelMap, existing.key, existing.token)
    }
    const entry = new CoverPixelMapCacheEntry(
      key,
      this.nextToken,
      pixelMap,
      Math.max(1, byteSize),
    )
    this.nextToken += 1
    entry.leaseCount = 1
    this.entriesByKey.set(key, entry)
    this.entriesByToken.set(entry.token, entry)
    await this.evictIfNeeded()
    return new CoverPixelMapLease(entry.pixelMap, entry.key, entry.token)
  }

  acquireOrLoad(
    key: string,
    loader: () => Promise<image.PixelMap>,
  ): Promise<CoverPixelMapLease> {
    const existingLease = this.acquire(key)
    if (existingLease !== undefined) {
      return Promise.resolve(existingLease)
    }
    const pending = this.inFlightByKey.get(key)
    if (pending !== undefined) {
      return pending.then((_winnerLease: CoverPixelMapLease): Promise<CoverPixelMapLease> => {
        const sharedLease = this.acquire(key)
        if (sharedLease !== undefined) {
          return Promise.resolve(sharedLease)
        }
        // clear() may unindex a just-completed entry. Start a new request only
        // after the original loader settles, so two components never share one
        // lease or race to release a PixelMap.
        return this.acquireOrLoad(key, loader)
      })
    }
    const loading = loader()
      .then((pixelMap: image.PixelMap): Promise<CoverPixelMapLease> => {
        return this.putAndAcquire(key, pixelMap, coverPixelMapByteSize(pixelMap))
      })
    this.inFlightByKey.set(key, loading)
    return loading.finally(() => {
      if (this.inFlightByKey.get(key) === loading) {
        this.inFlightByKey.delete(key)
      }
    })
  }

  async release(lease: CoverPixelMapLease | undefined): Promise<void> {
    if (lease === undefined || lease.released) {
      return
    }
    lease.released = true
    const entry = this.entriesByToken.get(lease.entryToken)
    if (entry === undefined || entry.pixelMap !== lease.pixelMap) {
      return
    }
    entry.leaseCount = Math.max(0, entry.leaseCount - 1)
    entry.lastAccessAt = Date.now()
    if (!entry.indexed && entry.leaseCount === 0) {
      await this.destroyEntry(entry)
      return
    }
    await this.evictIfNeeded()
  }

  async clear(): Promise<void> {
    const entries = Array.from(this.entriesByKey.values())
    this.entriesByKey.clear()
    for (const entry of entries) {
      entry.indexed = false
      if (entry.leaseCount === 0) {
        await this.destroyEntry(entry)
      }
    }
  }

  private async evictIfNeeded(): Promise<void> {
    while (this.entriesByKey.size > COVER_PIXEL_MAP_MEMORY_MAX_ENTRIES ||
      this.indexedByteSize() > COVER_PIXEL_MAP_MEMORY_MAX_BYTES) {
      const candidate = this.oldestUnleasedEntry()
      if (candidate === undefined) {
        // Visible components own the remaining maps. Keeping them until their
        // leases end is safer than releasing a PixelMap still bound to Image.
        return
      }
      this.entriesByKey.delete(candidate.key)
      candidate.indexed = false
      await this.destroyEntry(candidate)
    }
  }

  private indexedByteSize(): number {
    let total = 0
    this.entriesByKey.forEach((entry: CoverPixelMapCacheEntry) => {
      total += entry.byteSize
    })
    return total
  }

  private oldestUnleasedEntry(): CoverPixelMapCacheEntry | undefined {
    let candidate: CoverPixelMapCacheEntry | undefined = undefined
    this.entriesByKey.forEach((entry: CoverPixelMapCacheEntry) => {
      if (entry.leaseCount > 0) {
        return
      }
      if (candidate === undefined || entry.lastAccessAt < candidate.lastAccessAt) {
        candidate = entry
      }
    })
    return candidate
  }

  private async destroyEntry(entry: CoverPixelMapCacheEntry): Promise<void> {
    if (this.entriesByToken.get(entry.token) !== entry) {
      return
    }
    if (this.entriesByKey.get(entry.key) === entry) {
      this.entriesByKey.delete(entry.key)
    }
    this.entriesByToken.delete(entry.token)
    entry.indexed = false
    try {
      await entry.pixelMap.release()
    } catch (_error) {
      console.warn('[CoverPixelMapCache] step=release_failed')
    }
  }
}

export const coverPixelMapMemoryCache: CoverPixelMapMemoryCache = new CoverPixelMapMemoryCache()

export function coverPixelMapMemoryCacheKey(signature: string, decodeMaxEdge: number): string {
  const maxEdge = Math.max(1, Math.round(decodeMaxEdge))
  return `${signature}::cover_decode_v1::${maxEdge}`
}

export function coverPixelMapByteSize(pixelMap: image.PixelMap): number {
  return Math.max(1, pixelMap.getPixelBytesNumber())
}
