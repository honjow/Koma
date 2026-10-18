import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  LibraryReadStateFilter,
  LibrarySortBy,
  LibraryCategoryFilter,
} from './LibraryStore'

export type LibraryServerSourceFilter = string
export type LibraryRuntimeSourceFilter = string
export type LibrarySourceFilter = 'all' | 'local' | 'private' | 'komga' | 'kavita' | 'opds' | 'webdav' | 'source_package' | LibraryServerSourceFilter | LibraryRuntimeSourceFilter
export type LibraryAvailabilityFilter = 'all' | 'downloaded' | 'fully_downloaded' | 'partially_downloaded' | 'not_downloaded'
export type LibraryMetadataStatusFilter = 'all' | 'ongoing' | 'completed' | 'hiatus' | 'cancelled' | 'unknown'
export type LibraryViewMode = 'grid' | 'list'
export type LibraryListDensity = 'compact' | 'standard' | 'comfortable'

export interface LibraryFilterPreferences {
  sortBy: LibrarySortBy
  viewMode: LibraryViewMode
  listDensity: LibraryListDensity
  showBadges: boolean
  source: LibrarySourceFilter
  readState: LibraryReadStateFilter
  category: LibraryCategoryFilter
  availability: LibraryAvailabilityFilter
  metadataStatus: LibraryMetadataStatusFilter
}

export interface LibraryFilterPreferenceChanges {
  sortBy?: LibrarySortBy
  viewMode?: LibraryViewMode
  listDensity?: LibraryListDensity
  showBadges?: boolean
  source?: LibrarySourceFilter
  readState?: LibraryReadStateFilter
  category?: LibraryCategoryFilter
  availability?: LibraryAvailabilityFilter
  metadataStatus?: LibraryMetadataStatusFilter
}

interface LibraryFilterWrite {
  key: string
  value: preferences.ValueType
}

interface LibraryFilterPreviousValue extends LibraryFilterWrite {
  existed: boolean
}

// The preferences cache and its flush belong to one owner across page/Store instances.
const libraryFilterOperations: Map<string, Promise<void>> = new Map()

const LIBRARY_FILTER_STORE_NAME: string = 'koma_library_filter_preferences'
const LIBRARY_SORT_KEY: string = 'library.sort'
const LIBRARY_VIEW_MODE_KEY: string = 'library.viewMode'
const LIBRARY_LIST_DENSITY_KEY: string = 'library.listDensity'
const LIBRARY_SHOW_BADGES_KEY: string = 'library.showBadges'
const LIBRARY_FILTER_SOURCE_KEY: string = 'library.filter.source'
const LIBRARY_FILTER_READ_STATE_KEY: string = 'library.filter.readState'
const LIBRARY_FILTER_CATEGORY_KEY: string = 'library.filter.category'
const LIBRARY_FILTER_AVAILABILITY_KEY: string = 'library.filter.availability'
const LIBRARY_FILTER_METADATA_STATUS_KEY: string = 'library.filter.metadataStatus'

const DEFAULT_LIBRARY_FILTER_PREFERENCES: LibraryFilterPreferences = {
  sortBy: 'lastRead',
  viewMode: 'grid',
  listDensity: 'standard',
  showBadges: true,
  source: 'all',
  readState: 'all',
  category: 'all',
  availability: 'all',
  metadataStatus: 'all',
}

function normalizeSortBy(value: string): LibrarySortBy {
  if (value === 'added' || value === 'title' || value === 'source') {
    return value
  }
  return 'lastRead'
}

function normalizeViewMode(value: string): LibraryViewMode {
  if (value === 'list') {
    return 'list'
  }
  return 'grid'
}

function normalizeListDensity(value: string): LibraryListDensity {
  if (value === 'compact' || value === 'comfortable') {
    return value
  }
  return 'standard'
}

function normalizeShowBadges(value: boolean): boolean {
  return value === false ? false : true
}

export function libraryServerSourceFilter(serverId: string): LibraryServerSourceFilter {
  return `server:${serverId.trim()}`
}

export function libraryRuntimeSourceFilter(sourceId: string): LibraryRuntimeSourceFilter {
  return `source:${sourceId.trim()}`
}

export function libraryServerIdFromSourceFilter(value: string): string | undefined {
  if (!value.startsWith('server:')) {
    return undefined
  }
  const serverId = value.slice('server:'.length).trim()
  return serverId.length === 0 ? undefined : serverId
}

export function libraryRuntimeIdFromSourceFilter(value: string): string | undefined {
  if (!value.startsWith('source:')) {
    return undefined
  }
  const sourceId = value.slice('source:'.length).trim()
  return sourceId.length === 0 ? undefined : sourceId
}

function normalizeSource(value: string): LibrarySourceFilter {
  if (value === 'wasm') {
    return 'source_package'
  }
  const serverId = libraryServerIdFromSourceFilter(value)
  if (serverId !== undefined) {
    return libraryServerSourceFilter(serverId)
  }
  const sourceId = libraryRuntimeIdFromSourceFilter(value)
  if (sourceId !== undefined) {
    return libraryRuntimeSourceFilter(sourceId)
  }
  if (
    value === 'local' ||
    value === 'private' ||
    value === 'komga' ||
    value === 'kavita' ||
    value === 'opds' ||
    value === 'webdav' ||
    value === 'source_package'
  ) {
    return value
  }
  return 'all'
}

function normalizeReadState(value: string): LibraryReadStateFilter {
  if (value === 'unread' || value === 'reading' || value === 'completed') {
    return value
  }
  return 'all'
}

function normalizeCategory(value: string): LibraryCategoryFilter {
  if (value === 'uncategorized' || value === 'favorite' || value === 'read_later') {
    return value
  }
  if (value.trim().length > 0) {
    return value.trim()
  }
  return 'all'
}

function normalizeAvailability(value: string): LibraryAvailabilityFilter {
  if (value === 'downloaded' ||
    value === 'fully_downloaded' ||
    value === 'partially_downloaded' ||
    value === 'not_downloaded') {
    return value
  }
  return 'all'
}

function normalizeMetadataStatus(value: string): LibraryMetadataStatusFilter {
  if (value === 'ongoing' || value === 'completed' || value === 'hiatus' || value === 'cancelled' || value === 'unknown') {
    return value
  }
  return 'all'
}

export class LibraryFilterStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const previous = libraryFilterOperations.get(key) ?? Promise.resolve()
    const result = previous.then(operation)
    const settled = result.then((): void => {}, (): void => {})
    libraryFilterOperations.set(key, settled)
    void settled.then((): void => {
      if (libraryFilterOperations.get(key) === settled) libraryFilterOperations.delete(key)
    })
    return result
  }

  load(): Promise<LibraryFilterPreferences> {
    return this.ordered(async (): Promise<LibraryFilterPreferences> => {
      const store = await this.preferences()
      return this.readSnapshot(store)
    })
  }

  loadSync(): LibraryFilterPreferences {
    // The initial page already has an asynchronous recovery path. Do not expose
    // another writer's uncommitted Preferences cache while it awaits flush.
    if (libraryFilterOperations.has(this.context.filesDir)) throw new Error('library_filter_pending_write')
    const store = preferences.getPreferencesSync(this.context, { name: LIBRARY_FILTER_STORE_NAME })
    return this.readSnapshot(store)
  }

  private readSnapshot(store: preferences.Preferences): LibraryFilterPreferences {
    const sortBy = store.getSync(LIBRARY_SORT_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.sortBy) as string
    const viewMode = store.getSync(LIBRARY_VIEW_MODE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.viewMode) as string
    const listDensity = store.getSync(LIBRARY_LIST_DENSITY_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.listDensity) as string
    const showBadges = store.getSync(LIBRARY_SHOW_BADGES_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.showBadges) as boolean
    const source = store.getSync(LIBRARY_FILTER_SOURCE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.source) as string
    const readState = store.getSync(LIBRARY_FILTER_READ_STATE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.readState) as string
    const category = store.getSync(LIBRARY_FILTER_CATEGORY_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.category) as string
    const availability = store.getSync(LIBRARY_FILTER_AVAILABILITY_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.availability) as string
    const metadataStatus = store.getSync(LIBRARY_FILTER_METADATA_STATUS_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.metadataStatus) as string
    return {
      sortBy: normalizeSortBy(sortBy),
      viewMode: normalizeViewMode(viewMode),
      listDensity: normalizeListDensity(listDensity),
      showBadges: normalizeShowBadges(showBadges),
      source: normalizeSource(source),
      readState: normalizeReadState(readState),
      category: normalizeCategory(category),
      availability: normalizeAvailability(availability),
      metadataStatus: normalizeMetadataStatus(metadataStatus),
    }
  }

  update(changes: LibraryFilterPreferenceChanges): Promise<LibraryFilterPreferences> {
    // Capture the caller's field intent before waiting behind another writer.
    const writes: LibraryFilterWrite[] = []
    if (changes.sortBy !== undefined) writes.push({ key: LIBRARY_SORT_KEY, value: normalizeSortBy(changes.sortBy) })
    if (changes.viewMode !== undefined) writes.push({ key: LIBRARY_VIEW_MODE_KEY, value: normalizeViewMode(changes.viewMode) })
    if (changes.listDensity !== undefined) writes.push({ key: LIBRARY_LIST_DENSITY_KEY, value: normalizeListDensity(changes.listDensity) })
    if (changes.showBadges !== undefined) writes.push({ key: LIBRARY_SHOW_BADGES_KEY, value: normalizeShowBadges(changes.showBadges) })
    if (changes.source !== undefined) writes.push({ key: LIBRARY_FILTER_SOURCE_KEY, value: normalizeSource(changes.source) })
    if (changes.readState !== undefined) writes.push({ key: LIBRARY_FILTER_READ_STATE_KEY, value: normalizeReadState(changes.readState) })
    if (changes.category !== undefined) writes.push({ key: LIBRARY_FILTER_CATEGORY_KEY, value: normalizeCategory(changes.category) })
    if (changes.availability !== undefined) writes.push({ key: LIBRARY_FILTER_AVAILABILITY_KEY, value: normalizeAvailability(changes.availability) })
    if (changes.metadataStatus !== undefined) writes.push({ key: LIBRARY_FILTER_METADATA_STATUS_KEY, value: normalizeMetadataStatus(changes.metadataStatus) })
    return BackupRestoreActivity.runWrite(() => this.ordered(async (): Promise<LibraryFilterPreferences> => {
      const store = await this.preferences()
      const previous: LibraryFilterPreviousValue[] = writes.map((write: LibraryFilterWrite): LibraryFilterPreviousValue => {
        return { key: write.key, value: store.getSync(write.key, ''), existed: store.hasSync(write.key) }
      })
      try {
        for (const write of writes) await store.put(write.key, write.value)
        await store.flush()
      } catch (error) {
        try {
          for (const saved of previous) {
            if (saved.existed) store.putSync(saved.key, saved.value)
            else store.deleteSync(saved.key)
          }
          await store.flush()
        } catch (_rollbackError) {
          throw new Error('library_filter_rollback_failed')
        }
        throw error as Error
      }
      return this.readSnapshot(store)
    }))
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_FILTER_STORE_NAME)
  }
}
