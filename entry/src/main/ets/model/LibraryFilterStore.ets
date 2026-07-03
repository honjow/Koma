import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import {
  LibraryReadStateFilter,
  LibrarySortBy,
  LibraryCategoryFilter,
} from './LibraryStore'

export type LibrarySourceFilter = 'all' | 'local' | 'private' | 'komga' | 'opds' | 'webdav' | 'source_package'
export type LibraryAvailabilityFilter = 'all' | 'downloaded' | 'fully_downloaded' | 'partially_downloaded' | 'not_downloaded'
export type LibraryViewMode = 'grid' | 'list'

export interface LibraryFilterPreferences {
  sortBy: LibrarySortBy
  viewMode: LibraryViewMode
  showBadges: boolean
  source: LibrarySourceFilter
  readState: LibraryReadStateFilter
  category: LibraryCategoryFilter
  availability: LibraryAvailabilityFilter
}

const LIBRARY_FILTER_STORE_NAME: string = 'koma_library_filter_preferences'
const LIBRARY_SORT_KEY: string = 'library.sort'
const LIBRARY_VIEW_MODE_KEY: string = 'library.viewMode'
const LIBRARY_SHOW_BADGES_KEY: string = 'library.showBadges'
const LIBRARY_FILTER_SOURCE_KEY: string = 'library.filter.source'
const LIBRARY_FILTER_READ_STATE_KEY: string = 'library.filter.readState'
const LIBRARY_FILTER_CATEGORY_KEY: string = 'library.filter.category'
const LIBRARY_FILTER_AVAILABILITY_KEY: string = 'library.filter.availability'

const DEFAULT_LIBRARY_FILTER_PREFERENCES: LibraryFilterPreferences = {
  sortBy: 'lastRead',
  viewMode: 'grid',
  showBadges: true,
  source: 'all',
  readState: 'all',
  category: 'all',
  availability: 'all',
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

function normalizeShowBadges(value: boolean): boolean {
  return value === false ? false : true
}

function normalizeSource(value: string): LibrarySourceFilter {
  if (value === 'wasm') {
    return 'source_package'
  }
  if (
    value === 'local' ||
    value === 'private' ||
    value === 'komga' ||
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

export class LibraryFilterStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<LibraryFilterPreferences> {
    const store = await this.preferences()
    const sortBy = await store.get(LIBRARY_SORT_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.sortBy) as string
    const viewMode = await store.get(LIBRARY_VIEW_MODE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.viewMode) as string
    const showBadges = await store.get(LIBRARY_SHOW_BADGES_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.showBadges) as boolean
    const source = await store.get(LIBRARY_FILTER_SOURCE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.source) as string
    const readState = await store.get(LIBRARY_FILTER_READ_STATE_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.readState) as string
    const category = await store.get(LIBRARY_FILTER_CATEGORY_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.category) as string
    const availability = await store.get(LIBRARY_FILTER_AVAILABILITY_KEY, DEFAULT_LIBRARY_FILTER_PREFERENCES.availability) as string
    return {
      sortBy: normalizeSortBy(sortBy),
      viewMode: normalizeViewMode(viewMode),
      showBadges: normalizeShowBadges(showBadges),
      source: normalizeSource(source),
      readState: normalizeReadState(readState),
      category: normalizeCategory(category),
      availability: normalizeAvailability(availability),
    }
  }

  async save(preferencesValue: LibraryFilterPreferences): Promise<void> {
    const store = await this.preferences()
    await store.put(LIBRARY_SORT_KEY, normalizeSortBy(preferencesValue.sortBy))
    await store.put(LIBRARY_VIEW_MODE_KEY, normalizeViewMode(preferencesValue.viewMode))
    await store.put(LIBRARY_SHOW_BADGES_KEY, normalizeShowBadges(preferencesValue.showBadges))
    await store.put(LIBRARY_FILTER_SOURCE_KEY, normalizeSource(preferencesValue.source))
    await store.put(LIBRARY_FILTER_READ_STATE_KEY, normalizeReadState(preferencesValue.readState))
    await store.put(LIBRARY_FILTER_CATEGORY_KEY, normalizeCategory(preferencesValue.category))
    await store.put(LIBRARY_FILTER_AVAILABILITY_KEY, normalizeAvailability(preferencesValue.availability))
    await store.flush()
  }

  private async preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, LIBRARY_FILTER_STORE_NAME)
  }
}
