import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  sourceMangaDetailSnapshotCache,
  SourceMangaDetailSnapshotPersistencePort,
  SourceMangaDetailSnapshotRecord,
} from './SourceMangaDetailSnapshotCache'

const SOURCE_DETAIL_CACHE_SCHEMA_VERSION: number = 1
const SOURCE_DETAIL_CACHE_DIRECTORY: string = 'source-runtime'
const SOURCE_DETAIL_CACHE_FILE: string = 'source-detail-snapshots.v1.json'
const SOURCE_DETAIL_CACHE_WRITE_SETTLE_MS: number = 300
const SOURCE_DETAIL_CACHE_MAX_RECORDS: number = 32
const SOURCE_DETAIL_CACHE_MAX_BYTES: number = 8 * 1024 * 1024

interface SourceMangaDetailSnapshotCacheDocument {
  schemaVersion: number
  records: SourceMangaDetailSnapshotRecord[]
}

function joinPath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return `${left}/${right}`
}

function validRecord(record: SourceMangaDetailSnapshotRecord): boolean {
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

function parseDocument(payload: string): SourceMangaDetailSnapshotRecord[] {
  const parsed = JSON.parse(payload) as SourceMangaDetailSnapshotCacheDocument
  if (parsed.schemaVersion !== SOURCE_DETAIL_CACHE_SCHEMA_VERSION || !Array.isArray(parsed.records)) return []
  return parsed.records.filter((record: SourceMangaDetailSnapshotRecord): boolean => validRecord(record))
    .sort((left: SourceMangaDetailSnapshotRecord, right: SourceMangaDetailSnapshotRecord): number =>
      right.lastAccessAt - left.lastAccessAt)
    .slice(0, SOURCE_DETAIL_CACHE_MAX_RECORDS)
}

/** App-private, local-only page cache. It is excluded from backups and device sync. */
export class SourceMangaDetailSnapshotPersistence implements SourceMangaDetailSnapshotPersistencePort {
  private rootDirectory: string = ''
  private filePath: string = ''
  private hydrateTask: Promise<void> | null = null
  private pendingRecords: SourceMangaDetailSnapshotRecord[] | null = null
  private persistTimer: number = -1
  private writeChain: Promise<void> = Promise.resolve()

  hydrate(context: common.UIAbilityContext): Promise<void> {
    const rootDirectory = joinPath(context.filesDir, SOURCE_DETAIL_CACHE_DIRECTORY)
    const filePath = joinPath(rootDirectory, SOURCE_DETAIL_CACHE_FILE)
    if (this.filePath === filePath && this.hydrateTask !== null) return this.hydrateTask
    this.rootDirectory = rootDirectory
    this.filePath = filePath
    sourceMangaDetailSnapshotCache.setPersistence(this)
    this.hydrateTask = this.load()
    return this.hydrateTask
  }

  persist(records: SourceMangaDetailSnapshotRecord[]): void {
    if (this.filePath.length === 0) return
    this.pendingRecords = records.slice()
    if (this.persistTimer >= 0) clearTimeout(this.persistTimer)
    this.persistTimer = setTimeout((): void => {
      this.persistTimer = -1
      const latest = this.pendingRecords
      this.pendingRecords = null
      if (latest !== null) this.enqueueWrite(latest)
    }, SOURCE_DETAIL_CACHE_WRITE_SETTLE_MS)
  }

  clear(): void {
    if (this.persistTimer >= 0) clearTimeout(this.persistTimer)
    this.persistTimer = -1
    this.pendingRecords = null
    const path = this.filePath
    if (path.length === 0) return
    this.writeChain = this.writeChain.then(async (): Promise<void> => {
      try {
        if (await fs.access(path)) await fs.unlink(path)
        if (await fs.access(`${path}.tmp`)) await fs.unlink(`${path}.tmp`)
      } catch (error) {
        DiagnosticLogger.warn('source_detail_cache', 'clear_failed', String(error))
      }
    })
  }

  private async load(): Promise<void> {
    try {
      if (!await fs.access(this.filePath)) return
      const payload = await fs.readText(this.filePath, { encoding: 'utf-8' })
      sourceMangaDetailSnapshotCache.restore(parseDocument(payload))
    } catch (error) {
      DiagnosticLogger.warn('source_detail_cache', 'load_failed', String(error))
    }
  }

  private enqueueWrite(records: SourceMangaDetailSnapshotRecord[]): void {
    this.writeChain = this.writeChain.then(async (): Promise<void> => {
      try {
        await this.write(records)
      } catch (error) {
        DiagnosticLogger.warn('source_detail_cache', 'persist_failed', String(error))
      }
    })
  }

  private async write(records: SourceMangaDetailSnapshotRecord[]): Promise<void> {
    if (!await fs.access(this.rootDirectory)) {
      try {
        await fs.mkdir(this.rootDirectory)
      } catch (error) {
        if (!await fs.access(this.rootDirectory)) throw error as Error
      }
    }
    let selected = records.filter((record: SourceMangaDetailSnapshotRecord): boolean => validRecord(record))
      .slice(0, SOURCE_DETAIL_CACHE_MAX_RECORDS)
    let payload = ''
    while (true) {
      const document: SourceMangaDetailSnapshotCacheDocument = {
        schemaVersion: SOURCE_DETAIL_CACHE_SCHEMA_VERSION,
        records: selected,
      }
      payload = JSON.stringify(document)
      if (payload.length <= SOURCE_DETAIL_CACHE_MAX_BYTES || selected.length <= 1) break
      selected = selected.slice(0, selected.length - 1)
    }
    const temporary = `${this.filePath}.tmp`
    let file: fs.File | undefined = undefined
    try {
      file = await fs.open(temporary, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      const written = await fs.write(file.fd, payload, { encoding: 'utf-8' })
      if (written !== buffer.byteLength(payload, 'utf-8')) throw new Error('source_detail_cache_write_incomplete')
      await fs.fsync(file.fd)
      await fs.close(file)
      file = undefined
      await fs.rename(temporary, this.filePath)
    } finally {
      if (file !== undefined) {
        try { await fs.close(file) } catch (_error) {}
      }
      try { if (await fs.access(temporary)) await fs.unlink(temporary) } catch (_error) {}
    }
  }
}

export const sourceMangaDetailSnapshotPersistence: SourceMangaDetailSnapshotPersistence =
  new SourceMangaDetailSnapshotPersistence()
