import { appSourceSettingsStore } from '../sourceRuntime/SourceSettingsStore'
import {
  MangaChapterItem,
  MangaDetail,
} from './MangaDetailModels'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'

export interface SourceMangaDetailSnapshot {
  detail: MangaDetail
  chapters: MangaChapterItem[]
  chaptersResolved: boolean
  excludedChapterIds?: string[]
}

/** Serializable record shared by the in-memory cache and its local-only store. */
export interface SourceMangaDetailSnapshotRecord {
  sourceId: string
  mangaId: string
  manifestId: string
  manifestVersion: string
  wasmByteCount: number
  settingsRevision: string
  settingsFingerprint: string
  mangaUrl?: string
  lastAccessAt: number
  snapshot: SourceMangaDetailSnapshot
}

export interface SourceMangaDetailSnapshotPersistencePort {
  persist(records: SourceMangaDetailSnapshotRecord[]): void
  clear(): void
}

function cloneMangaDetail(detail: MangaDetail): MangaDetail {
  return {
    id: detail.id,
    title: detail.title,
    author: detail.author,
    artist: detail.artist,
    contentRating: detail.contentRating,
    description: detail.description,
    coverUrl: detail.coverUrl,
    status: detail.status,
    tags: detail.tags === undefined ? undefined : detail.tags.slice(),
    relatedManga: detail.relatedManga?.slice(),
    sourceId: detail.sourceId,
    sourceImageId: detail.sourceImageId,
    sourceName: detail.sourceName,
    chapterCount: detail.chapterCount,
    isInLibrary: detail.isInLibrary,
    url: detail.url,
    webUrl: detail.webUrl,
  }
}

function cloneMangaChapterItem(chapter: MangaChapterItem): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.chapterNumber,
    volumeNumber: chapter.volumeNumber,
    readingOrder: chapter.readingOrder,
    readingGroup: chapter.readingGroup,
    readingVariantGroup: chapter.readingVariantGroup,
    readingVariantSequence: chapter.readingVariantSequence,
    continuationEligible: chapter.continuationEligible,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    pageCount: chapter.pageCount,
    isRead: chapter.isRead,
    isDownloaded: chapter.isDownloaded,
    downloadStatus: chapter.downloadStatus,
  }
}

function cloneSnapshot(snapshot: SourceMangaDetailSnapshot): SourceMangaDetailSnapshot {
  return {
    detail: cloneMangaDetail(snapshot.detail),
    chapters: snapshot.chapters.map((chapter: MangaChapterItem): MangaChapterItem => cloneMangaChapterItem(chapter)),
    chaptersResolved: snapshot.chaptersResolved,
    excludedChapterIds: snapshot.excludedChapterIds?.slice(),
  }
}

function copyRecord(record: SourceMangaDetailSnapshotRecord, copySnapshot: boolean): SourceMangaDetailSnapshotRecord {
  return {
    sourceId: record.sourceId,
    mangaId: record.mangaId,
    manifestId: record.manifestId,
    manifestVersion: record.manifestVersion,
    wasmByteCount: record.wasmByteCount,
    settingsRevision: record.settingsRevision,
    settingsFingerprint: record.settingsFingerprint,
    mangaUrl: record.mangaUrl,
    lastAccessAt: record.lastAccessAt,
    snapshot: copySnapshot ? cloneSnapshot(record.snapshot) : record.snapshot,
  }
}

function sourceMangaDetailSnapshotCacheKey(
  entry: SourceRuntimeRegistryEntry,
  sourceId: string,
  mangaId: string,
): string {
  return [
    sourceId.trim(),
    mangaId.trim(),
    entry.manifestId?.trim() ?? '',
    entry.manifestVersion.trim(),
    `${entry.wasmByteCount}`,
  ].join('\u001f')
}

export class SourceMangaDetailSnapshotCache {
  private readonly snapshots: Map<string, SourceMangaDetailSnapshotRecord> =
    new Map<string, SourceMangaDetailSnapshotRecord>()
  private persistence: SourceMangaDetailSnapshotPersistencePort | undefined = undefined

  size(): number {
    return this.snapshots.size
  }

  clear(): number {
    const count = this.snapshots.size
    this.snapshots.clear()
    this.persistence?.clear()
    return count
  }

  setPersistence(persistence: SourceMangaDetailSnapshotPersistencePort): void {
    this.persistence = persistence
  }

  /** Restore complete records from the local-only cache document. */
  restore(records: SourceMangaDetailSnapshotRecord[]): void {
    records.forEach((record: SourceMangaDetailSnapshotRecord): void => {
      if (record.snapshot.chaptersResolved !== true) return
      const key = this.recordKey(record)
      const existing = this.snapshots.get(key)
      if (existing === undefined || existing.lastAccessAt <= record.lastAccessAt) {
        this.snapshots.set(key, copyRecord(record, true))
      }
    })
  }

  persistenceRecords(): SourceMangaDetailSnapshotRecord[] {
    return this.collectRecords(true)
  }

  private collectRecords(copySnapshot: boolean): SourceMangaDetailSnapshotRecord[] {
    const records: SourceMangaDetailSnapshotRecord[] = []
    this.snapshots.forEach((record: SourceMangaDetailSnapshotRecord): void => {
      if (record.snapshot.chaptersResolved === true) records.push(copyRecord(record, copySnapshot))
    })
    return records.sort((left: SourceMangaDetailSnapshotRecord, right: SourceMangaDetailSnapshotRecord): number =>
      right.lastAccessAt - left.lastAccessAt)
  }

  private recordKey(record: SourceMangaDetailSnapshotRecord): string {
    return [
      record.sourceId,
      record.mangaId,
      record.manifestId,
      record.manifestVersion,
      `${record.wasmByteCount}`,
    ].join('\u001f')
  }

  private persistIfNeeded(): void {
    // The cache owns its snapshot contents. Copy each record's recency for
    // the queued write while sharing the snapshot until TaskPool transfers it.
    this.persistence?.persist(this.collectRecords(false))
  }

  read(
    entry: SourceRuntimeRegistryEntry,
    sourceId: string,
    mangaId: string,
    mangaUrl?: string,
    settingsFingerprint?: string,
  ): SourceMangaDetailSnapshot | undefined {
    const key = sourceMangaDetailSnapshotCacheKey(entry, sourceId, mangaId)
    const cached = this.snapshots.get(key)
    if (cached === undefined) return undefined
    const currentManifestId = entry.manifestId?.trim() ?? ''
    const currentManifestVersion = entry.manifestVersion?.trim() ?? ''
    const identityChanged = cached.manifestId !== currentManifestId ||
      cached.manifestVersion !== currentManifestVersion || cached.wasmByteCount !== entry.wasmByteCount
    const settingsChanged = settingsFingerprint === undefined ?
      cached.settingsRevision !== appSourceSettingsStore.revisionForSource(sourceId) :
      cached.settingsFingerprint !== settingsFingerprint
    if (identityChanged || settingsChanged) {
      this.snapshots.delete(key)
      this.persistIfNeeded()
      return undefined
    }
    const snapshot = cached.snapshot
    const route = mangaUrl?.trim()
    if (route !== undefined && route.length > 0 && snapshot.detail.url?.trim() !== route) {
      return undefined
    }
    const previousAccess = cached.lastAccessAt
    cached.lastAccessAt = Date.now()
    // Only the eviction order is durable. Reopening its newest entry
    // does not need another transfer of all cached chapter rows to disk.
    for (const record of this.snapshots.values()) {
      if (record !== cached && record.snapshot.chaptersResolved &&
        (record.lastAccessAt >= previousAccess || record.lastAccessAt > cached.lastAccessAt)) {
        this.persistIfNeeded()
        break
      }
    }
    return cloneSnapshot(snapshot)
  }

  /** The reader can verify chronology while the detail still holds an older catalog.
   * Refresh the matching cache record without scheduling another UI-thread snapshot write. */
  rememberVerifiedReaderCatalog(entry: SourceRuntimeRegistryEntry, mangaId: string, mangaUrl: string | undefined,
    settingsRevision: string, chapters: MangaChapterItem[], excludedChapterIds?: string[]): void {
    if (entry.authentication !== undefined) return
    const key = sourceMangaDetailSnapshotCacheKey(entry, entry.sourceId, mangaId)
    const cached = this.snapshots.get(key)
    if (cached === undefined || cached.settingsRevision !== settingsRevision ||
      settingsRevision !== appSourceSettingsStore.revisionForSource(entry.sourceId) ||
      cached.snapshot.detail.url?.trim() !== mangaUrl?.trim()) return
    cached.snapshot.chapters = chapters.map((chapter: MangaChapterItem): MangaChapterItem => cloneMangaChapterItem(chapter))
    cached.snapshot.chaptersResolved = true
    cached.snapshot.excludedChapterIds = excludedChapterIds?.slice()
  }

  write(
    entry: SourceRuntimeRegistryEntry,
    sourceId: string,
    mangaId: string,
    snapshot: SourceMangaDetailSnapshot,
    settingsRevision: string,
    settingsFingerprint: string = '',
  ): void {
    if (settingsRevision !== appSourceSettingsStore.revisionForSource(sourceId)) return
    const record: SourceMangaDetailSnapshotRecord = {
      sourceId: sourceId.trim(),
      mangaId: mangaId.trim(),
      manifestId: entry.manifestId?.trim() ?? '',
      manifestVersion: entry.manifestVersion?.trim() ?? '',
      wasmByteCount: entry.wasmByteCount,
      settingsRevision,
      settingsFingerprint,
      mangaUrl: snapshot.detail.url,
      lastAccessAt: Date.now(),
      snapshot: cloneSnapshot(snapshot),
    }
    this.snapshots.set(this.recordKey(record), record)
    if (record.snapshot.chaptersResolved) this.persistIfNeeded()
  }
}

export const sourceMangaDetailSnapshotCache: SourceMangaDetailSnapshotCache = new SourceMangaDetailSnapshotCache()
