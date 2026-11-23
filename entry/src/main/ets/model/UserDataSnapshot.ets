import { shelfRowsRevision } from '../deviceSync/DeviceSyncShelfApply'
import { common } from '@kit.AbilityKit'
import { openUserDataSnapshotDatabase } from './UserDataDatabase'
import { LibraryRdbStorage } from './LibraryRdbStorage'
import type { LibraryReadingMetadata } from './LibraryRdbStorage'
import type { PersistedComic, PersistedLibraryStoreDocument } from './LibraryPersistence'
import { ReaderRdbStorage } from './ReaderRdbStorage'
import type { ReaderSessionDocumentSnapshot } from './ReaderSessionStore'

export interface ReadingSyncDatabaseInput {
  works: LibraryReadingMetadata[]
  reading: ReaderSessionDocumentSnapshot
}

@Concurrent
export async function readReadingSyncDatabaseInput(context: common.UIAbilityContext): Promise<ReadingSyncDatabaseInput> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    return { works: new LibraryRdbStorage(store).readReadingMetadata(), reading: new ReaderRdbStorage(store).readForSync() }
  } finally {
    await store.close()
  }
}

export interface ShelfSyncDatabaseInput {
  library?: PersistedLibraryStoreDocument
  revision: string
}

@Concurrent
export async function readShelfSyncDatabaseInput(context: common.UIAbilityContext): Promise<ShelfSyncDatabaseInput> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    const library = new LibraryRdbStorage(store).readShelfSync()
    return { library, revision: shelfRowsRevision(library) }
  } finally { await store.close() }
}

/** Deletion recovery needs the exact content of the deleted works. */
@Concurrent
export async function readShelfWorksForRecovery(context: common.UIAbilityContext, comicIds: string[]): Promise<PersistedComic[]> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    const library = new LibraryRdbStorage(store)
    const works: PersistedComic[] = []
    for (const id of comicIds) {
      const work = library.readWork(id)
      if (work === undefined) throw new Error('sync_local_changed')
      works.push(work)
    }
    return works
  } finally {
    await store.close()
  }
}
