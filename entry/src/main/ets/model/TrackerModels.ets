import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ComicId } from './ComicModels'

export type TrackerProviderId = 'anilist' | 'myanimelist' | 'kitsu' | 'mangaupdates' | 'bangumi'
export type TrackerConnectionStatus = 'not_configured' | 'planned' | 'disabled'

export interface TrackerProviderConnection {
  providerId: TrackerProviderId
  displayName: string
  status: TrackerConnectionStatus
}

export interface ComicTrackerMapping {
  comicId: ComicId
  providerId: TrackerProviderId
  externalSeriesId: string
  externalTitle?: string
  lastMatchedAt?: number
}

export interface TrackerPreferences {
  connections: TrackerProviderConnection[]
  comicMappings: ComicTrackerMapping[]
}

export const TRACKER_PREFERENCES_STORE_NAME: string = 'koma_tracker_preferences_v1'
export const TRACKER_CONNECTIONS_KEY: string = 'tracker.connections'
export const TRACKER_COMIC_MAPPINGS_KEY: string = 'tracker.comicMappings'

export const DEFAULT_TRACKER_PROVIDER_CONNECTIONS: TrackerProviderConnection[] = [
  { providerId: 'anilist', displayName: 'AniList', status: 'not_configured' },
  { providerId: 'myanimelist', displayName: 'MyAnimeList', status: 'not_configured' },
  { providerId: 'kitsu', displayName: 'Kitsu', status: 'not_configured' },
  { providerId: 'mangaupdates', displayName: 'MangaUpdates', status: 'not_configured' },
  { providerId: 'bangumi', displayName: 'Bangumi', status: 'planned' },
]

export const DEFAULT_TRACKER_PREFERENCES: TrackerPreferences = {
  connections: DEFAULT_TRACKER_PROVIDER_CONNECTIONS,
  comicMappings: [],
}

export function getTrackerConnectionStatusLabel(status: TrackerConnectionStatus): string {
  if (status === 'disabled') {
    return '已停用'
  }
  if (status === 'planned') {
    return '规划中'
  }
  return '未连接'
}

export function normalizeTrackerConnectionStatus(value: string): TrackerConnectionStatus {
  if (value === 'planned' || value === 'disabled') {
    return value
  }
  return 'not_configured'
}

export function normalizeTrackerProviderConnection(value: TrackerProviderConnection): TrackerProviderConnection | undefined {
  const provider = DEFAULT_TRACKER_PROVIDER_CONNECTIONS.find((item: TrackerProviderConnection): boolean => {
    return item.providerId === value.providerId
  })
  if (provider === undefined) {
    return undefined
  }
  return {
    providerId: provider.providerId,
    displayName: provider.displayName,
    status: normalizeTrackerConnectionStatus(value.status),
  }
}

export function mergeTrackerProviderConnections(savedConnections: TrackerProviderConnection[]): TrackerProviderConnection[] {
  return DEFAULT_TRACKER_PROVIDER_CONNECTIONS.map((provider: TrackerProviderConnection): TrackerProviderConnection => {
    const saved = savedConnections.find((item: TrackerProviderConnection): boolean => {
      return item.providerId === provider.providerId
    })
    if (saved === undefined) {
      return provider
    }
    const normalized = normalizeTrackerProviderConnection(saved)
    return normalized === undefined ? provider : normalized
  })
}

export function normalizeComicTrackerMappings(values: ComicTrackerMapping[]): ComicTrackerMapping[] {
  const mappings: ComicTrackerMapping[] = []
  values.forEach((mapping: ComicTrackerMapping) => {
    const provider = DEFAULT_TRACKER_PROVIDER_CONNECTIONS.find((item: TrackerProviderConnection): boolean => {
      return item.providerId === mapping.providerId
    })
    if (provider === undefined || mapping.comicId.trim().length === 0 || mapping.externalSeriesId.trim().length === 0) {
      return
    }
    const next: ComicTrackerMapping = {
      comicId: mapping.comicId.trim(),
      providerId: provider.providerId,
      externalSeriesId: mapping.externalSeriesId.trim(),
    }
    if (mapping.externalTitle !== undefined && mapping.externalTitle.trim().length > 0) {
      next.externalTitle = mapping.externalTitle.trim()
    }
    if (mapping.lastMatchedAt !== undefined && mapping.lastMatchedAt > 0) {
      next.lastMatchedAt = mapping.lastMatchedAt
    }
    mappings.push(next)
  })
  return mappings
}

export class TrackerPreferencesStore {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async load(): Promise<TrackerPreferences> {
    const store = await this.preferences()
    const connectionsJson = await store.get(TRACKER_CONNECTIONS_KEY, JSON.stringify(DEFAULT_TRACKER_PROVIDER_CONNECTIONS)) as string
    const mappingsJson = await store.get(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify([])) as string
    return {
      connections: mergeTrackerProviderConnections(this.parseConnections(connectionsJson)),
      comicMappings: normalizeComicTrackerMappings(this.parseMappings(mappingsJson)),
    }
  }

  async saveConnections(connections: TrackerProviderConnection[]): Promise<TrackerPreferences> {
    const current = await this.load()
    const next: TrackerPreferences = {
      connections: mergeTrackerProviderConnections(connections),
      comicMappings: current.comicMappings,
    }
    const store = await this.preferences()
    await store.put(TRACKER_CONNECTIONS_KEY, JSON.stringify(next.connections))
    await store.flush()
    return next
  }

  private parseConnections(value: string): TrackerProviderConnection[] {
    try {
      const parsed = JSON.parse(value) as TrackerProviderConnection[]
      if (!Array.isArray(parsed)) {
        return DEFAULT_TRACKER_PROVIDER_CONNECTIONS
      }
      return parsed
    } catch (_error) {
      return DEFAULT_TRACKER_PROVIDER_CONNECTIONS
    }
  }

  private parseMappings(value: string): ComicTrackerMapping[] {
    try {
      const parsed = JSON.parse(value) as ComicTrackerMapping[]
      if (!Array.isArray(parsed)) {
        return []
      }
      return parsed
    } catch (_error) {
      return []
    }
  }

  private preferences(): Promise<preferences.Preferences> {
    return preferences.getPreferences(this.context, TRACKER_PREFERENCES_STORE_NAME)
  }
}
