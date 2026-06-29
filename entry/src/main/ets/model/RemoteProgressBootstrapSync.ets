import { common } from '@kit.AbilityKit'
import { RemoteProgressSyncBridge } from '../state/RemoteProgressSyncState'
import {
  Comic,
  ComicSourceKind,
  ReadingProgress,
} from './ComicModels'
import {
  AppFilesLibraryStorePersistenceAdapter,
  LibraryStorePersistenceService,
} from './LibraryPersistence'
import { InMemoryLibraryStore } from './LibraryStore'
import {
  AppFilesReaderSessionPersistenceAdapter,
  PersistentReaderSessionStore,
} from './ReaderSessionStore'
import { RemoteProgressSyncService } from './RemoteProgressSyncService'

export interface RemoteProgressBootstrapSyncResult {
  synced: number
  updated: number
  failed: number
}

const BOOTSTRAP_SYNC_COOLDOWN_MS: number = 60 * 1000
const UNKNOWN_SERVER_ID: string = ''

export class RemoteProgressBootstrapSync {
  private static running: boolean = false
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async syncAllKomgaProgress(): Promise<RemoteProgressBootstrapSyncResult> {
    const empty: RemoteProgressBootstrapSyncResult = { synced: 0, updated: 0, failed: 0 }
    if (RemoteProgressBootstrapSync.running || this.isCoolingDown()) {
      return empty
    }
    RemoteProgressBootstrapSync.running = true
    console.info('[BootstrapSync] step=start')
    try {
      const libraryStore = new InMemoryLibraryStore()
      const libraryPersistence = new LibraryStorePersistenceService(
        libraryStore,
        new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir)
      )
      libraryPersistence.restore()

      const sessionStore = new PersistentReaderSessionStore(
        new AppFilesReaderSessionPersistenceAdapter(this.context.filesDir)
      )
      const remoteComics = libraryStore.listComics().filter((comic: Comic): boolean => {
        return comic.sourceKind === ComicSourceKind.KOMGA_REMOTE
      })
      const groups = this.groupByServer(remoteComics)
      const service = new RemoteProgressSyncService(this.context)
      const results = await Promise.all(Array.from(groups.keys()).map((serverId: string) => {
        const comics = groups.get(serverId) ?? []
        return this.syncServer(serverId, comics, service, sessionStore)
      }))
      const total = results.reduce((acc: RemoteProgressBootstrapSyncResult, item: RemoteProgressBootstrapSyncResult) => {
        return {
          synced: acc.synced + item.synced,
          updated: acc.updated + item.updated,
          failed: acc.failed + item.failed,
        }
      }, empty)
      RemoteProgressSyncBridge.markSuccess()
      console.info(`[BootstrapSync] step=done updated=${total.updated} synced=${total.synced} failed=${total.failed}`)
      return total
    } catch (error) {
      const e = error as Error
      console.warn(`[BootstrapSync] step=done updated=0 synced=0 failed=1 message=${e.message}`)
      return { synced: 0, updated: 0, failed: 1 }
    } finally {
      RemoteProgressBootstrapSync.running = false
    }
  }

  private isCoolingDown(): boolean {
    const lastSuccessAt = RemoteProgressSyncBridge.lastSuccessAt()
    return lastSuccessAt > 0 && Date.now() - lastSuccessAt < BOOTSTRAP_SYNC_COOLDOWN_MS
  }

  private groupByServer(comics: Comic[]): Map<string, Comic[]> {
    const groups = new Map<string, Comic[]>()
    comics.forEach((comic: Comic) => {
      const serverId = comic.remoteServerId ?? UNKNOWN_SERVER_ID
      const group = groups.get(serverId) ?? []
      group.push(comic)
      groups.set(serverId, group)
    })
    return groups
  }

  private async syncServer(
    serverId: string,
    comics: Comic[],
    service: RemoteProgressSyncService,
    sessionStore: PersistentReaderSessionStore
  ): Promise<RemoteProgressBootstrapSyncResult> {
    let synced = 0
    let updated = 0
    let failed = 0
    try {
      for (let index = 0; index < comics.length; index += 1) {
        const comic = comics[index]
        try {
          const remoteProgress = await service.pull(comic)
          if (remoteProgress === undefined) {
            continue
          }
          synced += 1
          if (this.shouldApplyRemoteProgress(sessionStore.getProgress(comic.id), remoteProgress)) {
            sessionStore.saveProgress(remoteProgress)
            updated += 1
          }
        } catch (_error) {
          failed += 1
        }
      }
      console.info(`[BootstrapSync] step=server_ok serverId=${serverId} synced=${synced} updated=${updated} failed=${failed}`)
      return { synced, updated, failed }
    } catch (error) {
      const e = error as Error
      console.warn(`[BootstrapSync] step=server_fail serverId=${serverId} message=${e.message}`)
      return { synced, updated, failed: failed + comics.length - synced }
    }
  }

  private shouldApplyRemoteProgress(local: ReadingProgress | undefined, remote: ReadingProgress): boolean {
    if (local === undefined) {
      return true
    }
    return remote.updatedAt > local.updatedAt
  }
}
