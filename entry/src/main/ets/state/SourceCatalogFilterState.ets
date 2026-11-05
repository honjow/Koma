import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { SourceCatalogFilters, SourceCatalogRating, sourceCatalogLanguage } from '../model/SourceCatalogPresentation'

const STORE: string = 'koma_source_catalog_filters_v1'
const KEY: string = 'catalog.filters'

interface SourceCatalogPresentationPreferences extends SourceCatalogFilters {
  pinnedSourceIds?: string[]
}

function normalizedFilters(value: SourceCatalogPresentationPreferences): SourceCatalogPresentationPreferences {
  const languages = value.languages === undefined ? undefined :
    Array.from(new Set(value.languages.filter((language: string): boolean => typeof language === 'string')
      .map(sourceCatalogLanguage)))
  const rating: SourceCatalogRating = ['safe', 'suggestive', 'adult', 'unknown'].includes(value.rating) ? value.rating : 'all'
  const pinnedSourceIds = Array.isArray(value.pinnedSourceIds)
    ? Array.from(new Set(value.pinnedSourceIds.filter((id: string): boolean => typeof id === 'string' && id.length > 0)))
    : []
  return { languages, rating, pinnedSourceIds }
}

// One portable display preference owner for Browse and the package catalog.
// It does not enable/disable source packages or change global search scope.
@ObservedV2
export class SourceCatalogFilterState {
  @Trace languages: string[] | undefined = undefined
  @Trace rating: SourceCatalogRating = 'all'
  @Trace pinnedSourceIds: string[] = []
  @Trace loaded: boolean = false
  private ready?: Promise<void>
  private context?: common.Context
  private writes: Promise<void> = Promise.resolve()
  private generation: number = 0
  private edit: number = 0
  private persisted: SourceCatalogPresentationPreferences = { rating: 'all' }

  prepare(context: common.Context): Promise<void> {
    this.context = context
    if (this.ready === undefined) {
      const generation = this.generation
      const edit = this.edit
      const loading = preferences.getPreferences(context, STORE).then(async (store: preferences.Preferences): Promise<void> => {
        const value = normalizedFilters(JSON.parse(await store.get(KEY, '{}') as string) as SourceCatalogPresentationPreferences)
        if (generation === this.generation) {
          this.persisted = value
          if (edit === this.edit) this.publish(value)
          this.loaded = true
        }
      }).catch((error: Error): void => {
        if (generation === this.generation) this.ready = undefined
        throw error
      })
      this.ready = loading
    }
    return this.ready
  }

  invalidate(): void { this.generation += 1; this.ready = undefined; this.loaded = false }

  private publish(value: SourceCatalogPresentationPreferences): void {
    this.languages = value.languages
    this.rating = value.rating
    this.pinnedSourceIds = value.pinnedSourceIds ?? []
  }

  get active(): boolean { return this.languages !== undefined || this.rating !== 'all' }

  // HDS switches also report model-driven changes. A partial selection turns
  // the All switch off; that echo must not become a request to clear the list.
  setAllLanguages(enabled: boolean): Promise<void> {
    if (enabled === (this.languages === undefined)) return Promise.resolve()
    return this.save({ languages: enabled ? undefined : [], rating: this.rating })
  }

  setLanguage(language: string, enabled: boolean, available: string[]): Promise<void> {
    const code = sourceCatalogLanguage(language)
    if (enabled === (this.languages === undefined || this.languages.includes(code))) return Promise.resolve()
    const selected = (this.languages ?? available).filter((value: string): boolean => value !== code)
    if (enabled) selected.push(code)
    return this.save({ languages: available.every((value: string): boolean => selected.includes(value))
      ? undefined : selected, rating: this.rating })
  }

  save(value: SourceCatalogFilters): Promise<void> {
    if (!this.loaded && this.context !== undefined) {
      return this.prepare(this.context).then(() => this.save(value))
    }
    return this.savePresentation({ languages: value.languages, rating: value.rating, pinnedSourceIds: this.pinnedSourceIds })
  }

  setSourcePinned(id: string, pinned: boolean): Promise<void> {
    if (!this.loaded && this.context !== undefined) {
      return this.prepare(this.context).then(() => this.setSourcePinned(id, pinned))
    }
    if (id.length === 0 || this.pinnedSourceIds.includes(id) === pinned) return Promise.resolve()
    const next = this.pinnedSourceIds.filter((key: string): boolean => key !== id)
    if (pinned) next.unshift(id)
    return this.savePresentation({ languages: this.languages, rating: this.rating, pinnedSourceIds: next })
  }

  private savePresentation(value: SourceCatalogPresentationPreferences): Promise<void> {
    const next = normalizedFilters(value)
    const context = this.context
    if (context === undefined) return Promise.reject(new Error('source_filter_not_ready'))
    const generation = this.generation
    const preparation = this.prepare(context)
    const edit = ++this.edit
    // Publish the selection immediately: consecutive language taps must build on
    // the preceding tap, rather than overwrite an in-flight disk write.
    this.publish(next)
    const run = this.writes.then(async (): Promise<void> => {
      await preparation
      if (generation !== this.generation) return
      return BackupRestoreActivity.runWrite(async (): Promise<void> => {
        const store = await preferences.getPreferences(context, STORE)
        const previous = await store.get(KEY, '{}') as string
        try { await store.put(KEY, JSON.stringify(next)); await store.flush() }
        catch (error) {
          await store.put(KEY, previous); await store.flush()
          throw error as Error
        }
        if (generation === this.generation) this.persisted = next
      })
    }).catch((error: Error): void => {
      if (generation === this.generation && edit === this.edit) this.publish(this.persisted)
      throw error
    })
    this.writes = run.catch((): void => {})
    return run
  }
}

export const appSourceCatalogFilters: SourceCatalogFilterState = new SourceCatalogFilterState()
