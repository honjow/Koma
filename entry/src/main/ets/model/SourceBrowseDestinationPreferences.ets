import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { MigratedPreferenceRecords } from './MigratedPreferenceRecords'
import { PreferenceColumnRows } from './PreferenceColumnRows'

const records = new MigratedPreferenceRecords('koma_source_browse_destination_v1')

/** Device-local navigation choice, independent of search, filters and result caches.
 * Undefined means no choice; the empty listing ID deliberately means the source Home.
 * Keep stable IDs across package updates and validate against get_listings before use.
 */
export class SourceBrowseDestinationPreferences {
  private rows?: PreferenceColumnRows

  async prepare(context: common.Context): Promise<void> {
    this.rows = await records.prepare(context)
  }

  load(sourceId: string): string | undefined {
    try {
      const raw = this.rows?.get(sourceId)
      if (raw === undefined) return undefined
      const value = JSON.parse(raw) as Object
      return typeof value === 'string' ? value : undefined
    } catch (error) {
      DiagnosticLogger.exception('browse', 'destination_read_failed', error as Error)
      return undefined
    }
  }

  save(sourceId: string, listingId: string): void {
    try {
      if (this.rows !== undefined && this.load(sourceId) !== listingId) {
        this.rows.put(sourceId, JSON.stringify(listingId))
      }
    } catch (error) {
      DiagnosticLogger.exception('browse', 'destination_save_failed', error as Error)
    }
  }

  clear(sourceId: string): void {
    try {
      this.rows?.put(sourceId, undefined)
    } catch (error) {
      DiagnosticLogger.exception('browse', 'destination_clear_failed', error as Error)
    }
  }
}

export const appSourceBrowseDestinationPreferences = new SourceBrowseDestinationPreferences()
