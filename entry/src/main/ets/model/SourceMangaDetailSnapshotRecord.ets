import type { SourceMangaDetailSnapshotRecord } from './SourceMangaDetailSnapshotCache'

export const SOURCE_DETAIL_CACHE_SCHEMA_VERSION: number = 1
export const SOURCE_DETAIL_CACHE_MAX_RECORDS: number = 32
export const SOURCE_DETAIL_CACHE_MAX_BYTES: number = 8 * 1024 * 1024

export function validSourceDetailCacheRecord(record: SourceMangaDetailSnapshotRecord): boolean {
  if (record === undefined || record === null) return false
  const snapshot = record.snapshot
  return typeof record.sourceId === 'string' && record.sourceId.trim().length > 0 &&
    typeof record.mangaId === 'string' && record.mangaId.trim().length > 0 &&
    typeof record.manifestId === 'string' && typeof record.manifestVersion === 'string' &&
    Number.isFinite(record.wasmByteCount) && record.wasmByteCount >= 0 &&
    typeof record.settingsRevision === 'string' && typeof record.settingsFingerprint === 'string' &&
    Number.isFinite(record.lastAccessAt) && snapshot !== undefined && snapshot !== null &&
    snapshot.chaptersResolved === true && snapshot.detail !== undefined && snapshot.detail !== null &&
    typeof snapshot.detail.id === 'string' && Array.isArray(snapshot.chapters)
}
