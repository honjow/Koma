import { SyncGroup } from './DeviceSyncFacts'
import { SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision } from './DeviceSyncStorage'

export interface SyncApplyGroup {
  group: SyncGroup
  changes: SyncLocalValue[]
}

/** Business persistence boundary, independent of WebDAV configuration, timers or requests. */
export interface DeviceSyncOwner {
  snapshot(group: SyncGroup, flushLocalChanges: boolean, guard?: () => void, shelfSpace?: string,
    includeReadingLabels?: boolean): Promise<SyncLocalSnapshot>
  removed(group: SyncGroup, keys: string[]): Promise<string[]>
  validateChanges?(group: SyncApplyGroup): Promise<void>
  commit(groups: SyncApplyGroup[], expected: SyncOwnerRevision[], saveCursor: (receipt: string) => void): Promise<void>
}
