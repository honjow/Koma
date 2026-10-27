import { taskpool } from '@kit.ArkTS'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { readSourceSettingObservationFile, writeSourceSettingObservationFile } from './SourceSettingObservationFile'
import { SourceSettingObservations, SourceSettingObservationSources,
  checkedSourceSettingObservations, checkedSourceSettingObservationSources,
  mergedSourceSettingObservations } from './SourceSettingObservations'

/** One process owner and serial commit queue for learned public option values.
 * File I/O/fsync happens in TaskPool, never in a chapter callback/UI transition.
 * No registry notification or selected-settings revision changes on observation.
 */
export class SourceSettingObservationStore {
  private path: string = ''
  private scope: number = 0
  private revisions: Map<string, number> = new Map<string, number>()
  private removing: Set<string> = new Set<string>()
  private document: SourceSettingObservationSources | undefined = undefined
  private readFailed: boolean = false
  private pending: Promise<void> = Promise.resolve()

  configure(filesDir: string): void {
    const path = `${filesDir}/source-runtime/source-setting-observations.json`
    if (path === this.path) return
    this.path = path
    this.invalidateCachedDocument()
  }

  invalidateCachedDocument(): void {
    this.scope += 1
    this.document = undefined
    this.readFailed = false
    this.revisions.clear()
  }

  tokenForSource(sourceId: string): string {
    return `${this.scope}:${this.revisions.get(sourceId) ?? 0}`
  }

  private enqueue<T>(action: () => Promise<T>): Promise<T> {
    const result = this.pending.then(action)
    this.pending = result.then((): void => {}, (): void => {})
    return result
  }

  private async readDocument(): Promise<SourceSettingObservationSources> {
    if (this.document !== undefined) return this.document
    if (this.readFailed) throw new Error('source_setting_observations_invalid')
    if (this.path.length === 0) return {}
    const scope = this.scope
    let sources: SourceSettingObservationSources
    try {
      sources = await taskpool.execute(readSourceSettingObservationFile, this.path) as SourceSettingObservationSources
    } catch (error) {
      if (scope === this.scope) this.readFailed = true
      throw error as Error
    }
    if (scope !== this.scope) throw new Error('source_setting_observations_stale')
    this.document = sources
    return this.document
  }

  private async writeDocument(sources: SourceSettingObservationSources): Promise<void> {
    if (this.path.length === 0) throw new Error('source_setting_observations_unconfigured')
    const scope = this.scope
    await taskpool.execute(writeSourceSettingObservationFile, this.path, sources)
    if (scope !== this.scope) throw new Error('source_setting_observations_stale')
    this.document = sources
  }

  snapshotForSource(sourceId: string): SourceSettingObservations {
    const values: SourceSettingObservations = this.document?.[sourceId] ?? {}
    return checkedSourceSettingObservations(values)
  }

  loadForSource(sourceId: string): Promise<SourceSettingObservations> {
    return this.enqueue(async (): Promise<SourceSettingObservations> => {
      await this.readDocument()
      return this.snapshotForSource(sourceId)
    })
  }

  observe(sourceId: string, values: Object, token: string, isCurrent: () => boolean): Promise<void> {
    const incoming = checkedSourceSettingObservations(values)
    const current = (): boolean => this.path.length > 0 && !this.removing.has(sourceId) &&
      !BackupRestoreActivity.isRestoring() && token === this.tokenForSource(sourceId) && isCurrent()
    return this.enqueue(async (): Promise<void> => {
      if (!current()) return
      await BackupRestoreActivity.runWrite(async (): Promise<void> => {
        const document = await this.readDocument()
        if (!current()) return
        const old = document[sourceId] ?? {}
        const next = mergedSourceSettingObservations(old, incoming)
        if (JSON.stringify(old) === JSON.stringify(next)) return
        // Every published record is immutable and every reader receives a copy.
        // Keep other sources' record identities; don't clone/serialize the whole
        // file in a directory callback. Validation/encoding belongs to Worker.
        const sources: SourceSettingObservationSources = {}
        Object.keys(document).forEach((id: string): void => { sources[id] = document[id] })
        sources[sourceId] = next
        await this.writeDocument(sources)
      })
    })
  }

  exportAll(): Promise<SourceSettingObservationSources> {
    return this.enqueue(async (): Promise<SourceSettingObservationSources> =>
      checkedSourceSettingObservationSources(await this.readDocument()))
  }

  /** BackupRestoreActivity owns restore admission and checkpoint rollback. */
  importDuringRestore(sources: SourceSettingObservationSources): Promise<void> {
    const checked = checkedSourceSettingObservationSources(sources)
    this.invalidateCachedDocument()
    return this.enqueue(async (): Promise<void> => { await this.writeDocument(checked) })
  }

  /** Registry removal owns the outer restore writer. Serialize with observations,
   * invalidate in-flight catalogs before awaiting, and restore on registry failure.
   */
  withSourceRemoved<T>(sourceId: string, mutation: () => Promise<T>): Promise<T> {
    this.removing.add(sourceId)
    this.revisions.set(sourceId, (this.revisions.get(sourceId) ?? 0) + 1)
    return this.enqueue(async (): Promise<T> => {
      try {
        const original = await this.readDocument()
        const next: SourceSettingObservationSources = {}
        Object.keys(original).forEach((id: string): void => { if (id !== sourceId) next[id] = original[id] })
        if (original[sourceId] !== undefined) await this.writeDocument(next)
        try {
          return await mutation()
        } catch (error) {
          if (original[sourceId] !== undefined) await this.writeDocument(original)
          throw error as Error
        }
      } finally {
        this.removing.delete(sourceId)
      }
    })
  }
}

export const appSourceSettingObservationStore: SourceSettingObservationStore = new SourceSettingObservationStore()
