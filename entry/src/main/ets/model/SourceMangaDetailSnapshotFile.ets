import { buffer } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import type { SourceMangaDetailSnapshotRecord } from './SourceMangaDetailSnapshotCache'
import { SOURCE_DETAIL_CACHE_SCHEMA_VERSION, SOURCE_DETAIL_CACHE_MAX_RECORDS, SOURCE_DETAIL_CACHE_MAX_BYTES,
  validSourceDetailCacheRecord } from './SourceMangaDetailSnapshotRecord'

/** File access and serialization run off the UI thread. The caller serializes writes and clears. */
interface SourceMangaDetailSnapshotCacheDocument {
  schemaVersion: number
  records: SourceMangaDetailSnapshotRecord[]
}

@Concurrent
export function readDetailCache(path: string): SourceMangaDetailSnapshotRecord[] {
  if (!fs.accessSync(path)) return []
  const parsed = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as SourceMangaDetailSnapshotCacheDocument
  if (parsed.schemaVersion !== SOURCE_DETAIL_CACHE_SCHEMA_VERSION || !Array.isArray(parsed.records)) return []
  return parsed.records.filter((record: SourceMangaDetailSnapshotRecord): boolean => validSourceDetailCacheRecord(record))
    .sort((left: SourceMangaDetailSnapshotRecord, right: SourceMangaDetailSnapshotRecord): number =>
      right.lastAccessAt - left.lastAccessAt)
    .slice(0, SOURCE_DETAIL_CACHE_MAX_RECORDS)
}

@Concurrent
export async function writeDetailCache(root: string, path: string, records: SourceMangaDetailSnapshotRecord[]): Promise<void> {
  if (!await fs.access(root)) {
    try {
      await fs.mkdir(root)
    } catch (error) {
      if (!await fs.access(root)) throw error as Error
    }
  }
  let selected = records.filter((record: SourceMangaDetailSnapshotRecord): boolean => validSourceDetailCacheRecord(record))
    .slice(0, SOURCE_DETAIL_CACHE_MAX_RECORDS)
  let payload: string
  while (true) {
    const document: SourceMangaDetailSnapshotCacheDocument = {
      schemaVersion: SOURCE_DETAIL_CACHE_SCHEMA_VERSION,
      records: selected,
    }
    payload = JSON.stringify(document)
    if (payload.length <= SOURCE_DETAIL_CACHE_MAX_BYTES || selected.length <= 1) break
    selected = selected.slice(0, selected.length - 1)
  }
  const temporary = `${path}.tmp`
  let file: fs.File | undefined = undefined
  try {
    file = await fs.open(temporary, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    const written = await fs.write(file.fd, payload, { encoding: 'utf-8' })
    if (written !== buffer.byteLength(payload, 'utf-8')) throw new Error('source_detail_cache_write_incomplete')
    await fs.fsync(file.fd)
    await fs.close(file)
    file = undefined
    await fs.rename(temporary, path)
  } finally {
    if (file !== undefined) {
      try { await fs.close(file) } catch (_error) {}
    }
    try { if (await fs.access(temporary)) await fs.unlink(temporary) } catch (_error) {}
  }
}
