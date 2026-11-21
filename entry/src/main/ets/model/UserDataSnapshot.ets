import { common } from '@kit.AbilityKit'
import { openUserDataSnapshotDatabase } from './UserDataDatabase'
import { LibraryRdbStorage } from './LibraryRdbStorage'
import type { LibraryReadingMetadata } from './LibraryRdbStorage'
import type { PersistedComic } from './LibraryPersistence'
import { ReaderRdbStorage } from './ReaderRdbStorage'
import { serializeReaderSessionForDevice } from './ReaderSessionStore'
import type { ReaderSessionDocumentSnapshot } from './ReaderSessionStore'

export interface ReadingSyncDatabaseInput {
  works: LibraryReadingMetadata[]
  reading: ReaderSessionDocumentSnapshot
}

export async function readReadingSyncDatabaseInput(context: common.UIAbilityContext): Promise<ReadingSyncDatabaseInput> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    return { works: new LibraryRdbStorage(store).readReadingMetadata(), reading: new ReaderRdbStorage(store).readForSync() }
  } finally {
    await store.close()
  }
}

/** Full compatibility snapshots are background work, including row materialization and encoding. */
@Concurrent
export async function readUserDataSnapshot(context: common.UIAbilityContext,
  domain: 'library' | 'reading' | 'shelf-sync'): Promise<string | undefined> {
  const store = await openUserDataSnapshotDatabase(context)
  try {
    if (domain === 'reading') return serializeReaderSessionForDevice(new ReaderRdbStorage(store).read())
    const library = new LibraryRdbStorage(store)
    const document = domain === 'shelf-sync' ? library.readShelfSync() : library.read()
    return document === undefined ? undefined : JSON.stringify(document)
  } finally {
    await store.close()
  }
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
