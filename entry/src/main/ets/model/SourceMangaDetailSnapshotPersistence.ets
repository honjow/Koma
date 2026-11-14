import { common } from '@kit.AbilityKit'
import { readDetailCache, writeDetailCache } from './SourceMangaDetailSnapshotFile'
import { taskpool } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  sourceMangaDetailSnapshotCache,
  SourceMangaDetailSnapshotPersistencePort,
  SourceMangaDetailSnapshotRecord,
} from './SourceMangaDetailSnapshotCache'

const SOURCE_DETAIL_CACHE_DIRECTORY: string = 'source-runtime'
const SOURCE_DETAIL_CACHE_FILE: string = 'source-detail-snapshots.v1.json'
const SOURCE_DETAIL_CACHE_WRITE_SETTLE_MS: number = 300

function joinPath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return `${left}/${right}`
}

/** App-private, local-only page cache. It is excluded from backups and device sync. */
export class SourceMangaDetailSnapshotPersistence implements SourceMangaDetailSnapshotPersistencePort {
  private rootDirectory: string = ''
  private filePath: string = ''
  private hydrateTask: Promise<void> | null = null
  private pendingRecords: SourceMangaDetailSnapshotRecord[] | null = null
  private persistTimer: number = -1
  private clearRevision: number = 0
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
    this.clearRevision += 1
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
    const path = this.filePath
    const clearRevision = this.clearRevision
    try {
      const records = await taskpool.execute(readDetailCache, path) as SourceMangaDetailSnapshotRecord[]
      if (path === this.filePath && clearRevision === this.clearRevision) sourceMangaDetailSnapshotCache.restore(records)
    } catch (error) {
      DiagnosticLogger.warn('source_detail_cache', 'load_failed', String(error))
    }
  }

  private enqueueWrite(records: SourceMangaDetailSnapshotRecord[]): void {
    const root = this.rootDirectory
    const path = this.filePath
    this.writeChain = this.writeChain.then(async (): Promise<void> => {
      try {
        await taskpool.execute(writeDetailCache, root, path, records)
      } catch (error) {
        DiagnosticLogger.warn('source_detail_cache', 'persist_failed', String(error))
      }
    })
  }
}

export const sourceMangaDetailSnapshotPersistence: SourceMangaDetailSnapshotPersistence =
  new SourceMangaDetailSnapshotPersistence()
