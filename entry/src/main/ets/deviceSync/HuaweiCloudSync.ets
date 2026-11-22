import { abilityAccessCtrl, common, Permissions, Want } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { LibraryRdbStorage, LibraryShelfSyncEdits } from '../model/LibraryRdbStorage'
import { readerPositions } from '../model/ReaderDataRows'
import { appReaderSessionStore, publishLiveCloudReading } from '../model/ReaderSessionStore'
import { ReaderPreferencesStore } from '../model/ReaderPreferencesStore'
import { SearchHistoryStore } from '../model/SearchHistoryStore'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import { openUserDataDatabase } from '../model/UserDataDatabase'
import { loadSourceSubscriptionPreferences } from '../sourceRuntime/SourceSubscriptionStorage'
import { SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { komaCloudReadingVerificationWork, komaCloudVerificationRun } from '../state/KomaDeviceVerificationIsolation'
import { appSourcePackageManagerCache } from '../viewmodel/SourcePackageManagerCache'
import { syncKeyParts, syncReadingIdentity } from './DeviceSyncData'
import { SyncGroup, SYNC_GROUPS } from './DeviceSyncFacts'
import {
  acknowledgeCloudWorkDeletions, cloudBusinessChanges, cloudTablesForGroups, prepareCloudWorkDeletions,
  SHELF_PARENT_TABLES, startCloudWorkDeletions, stopCloudWorkDeletions,
} from './HuaweiCloudBusinessTables'
import { HUAWEI_CLOUD_SYNC_BUILD_ENABLED } from './HuaweiCloudSyncBuildFlag'
import { KomaDeviceSyncOwners } from './DeviceSyncOwners'
import { DeviceSyncStorage, SyncLocalDocument, SyncSavedConnection } from './DeviceSyncStorage'

const SPACE = '7f562b9b-3095-4c87-a586-25c9cc5fa988'
const PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC'
const SETTINGS_URI = 'hicloud://cloudDrive/getInfo?path=MainActivity'
const TIMEOUT_MS = 240000
const RETRY_MS = 60000
@ObservedV2
export class HuaweiCloudSyncView {
  @Trace available: boolean = false
  @Trace verificationOnly: boolean = false
  @Trace enabled: boolean = false
  @Trace busy: boolean = false
  @Trace configuring: boolean = false
  @Trace lastSuccess: number = 0
  @Trace error: string = ''
}

class HuaweiCloudSync {
  readonly view = new HuaweiCloudSyncView()
  private context?: common.UIAbilityContext
  private storage?: DeviceSyncStorage
  private publish?: (groups: SyncGroup[], readingIds?: string[], shelf?: LibraryShelfSyncEdits) => void
  private nativeChanges: relationalStore.ChangeInfo[] = []
  private selection: () => SyncGroup[] = (): SyncGroup[] => []
  private readyStore?: Promise<relationalStore.RdbStore>
  private current?: Promise<void>
  private nativeConfiguration: Promise<void> = Promise.resolve()
  private nativeEnabled: boolean = false
  private nativeTransfer?: Promise<void>
  private cancelTransfer?: () => void
  private publication?: Promise<void>
  private publicationTimer: number = -1
  private needsPublication: boolean = false
  private foreground: boolean = false
  private restoring: boolean = false
  private generation: number = 0
  private timer: number = -1
  private deadline: number = 0
  private verificationRun: string = ''
  private readingVerificationWork: string = ''

  async startup(context: common.UIAbilityContext, webdav: KomaDeviceSyncOwners, selection: () => SyncGroup[]): Promise<void> {
    this.view.available = HUAWEI_CLOUD_SYNC_BUILD_ENABLED &&
      canIUse('SystemCapability.DistributedDataManager.CloudSync.Client')
    if (!this.view.available) return
    const storage = new DeviceSyncStorage(context.filesDir, true)
    const owner = new KomaDeviceSyncOwners(context, storage, true)
    await owner.recoverBeforeStartup()
    owner.recoverAlongside(webdav)
    webdav.recoverAlongside(owner)
    this.context = context
    this.storage = storage
    this.verificationRun = komaCloudVerificationRun()
    this.readingVerificationWork = komaCloudReadingVerificationWork()
    this.view.verificationOnly = this.verificationRun !== '' || this.readingVerificationWork !== ''
    this.selection = this.readingVerificationWork === '' ? selection : (): SyncGroup[] => ['reading']
    const active = storage.load().active
    this.view.enabled = active?.enabled === true && !this.view.verificationOnly
    this.view.lastSuccess = !this.view.verificationOnly && active?.endpointIdentity === 'huawei-cloud-rdb' ?
      active.lastSuccess : 0
    this.view.error = this.view.verificationOnly ? '' : active?.lastError ?? ''
  }

  attachPublisher(publish: (groups: SyncGroup[], readingIds?: string[], shelf?: LibraryShelfSyncEdits) => void): void {
    this.publish = publish
    this.schedulePublication()
  }

  onForeground(value: boolean): void {
    this.foreground = value
    this.cancelTimer()
    if (value) {
      this.schedulePublication()
      this.schedule(1500)
    }
  }

  setRestoring(value: boolean): void {
    this.restoring = value
    this.generation++
    this.cancelTimer()
    if (!value) {
      this.schedulePublication()
      this.schedule(2500)
    }
  }

  selectionChanged(): void {
    this.generation++
    this.cancelTimer()
    this.schedule(1500)
  }

  changed(group: SyncGroup): void {
    if (this.selection().includes(group)) this.schedule(group === 'reading' ? 1500 : 4000)
  }

  async openSystemSettings(): Promise<void> {
    const want: Want = { action: 'ohos.want.action.viewData', uri: SETTINGS_URI }
    await this.context?.startAbility(want)
  }

  async setEnabled(enabled: boolean): Promise<void> {
    const context = this.context
    const storage = this.storage
    if (context === undefined || storage === undefined || !this.view.available || this.view.configuring) return
    if (!this.verificationContextMatches()) return
    this.view.configuring = true
    this.view.error = ''
    try {
      if (enabled) {
        const manager = abilityAccessCtrl.createAtManager()
        const permission = await manager.requestPermissionsFromUser(context, [PERMISSION])
        if (permission.authResults[0] !== 0) {
          // A prior denial suppresses the standard prompt. Only an explicit,
          // later enable action opens the permission settings prompt.
          if (permission.dialogShownResults?.[0] !== false) throw new Error('permission')
          const result = await manager.requestPermissionOnSetting(context, [PERMISSION])
          if (result[0] !== 0) throw new Error('permission')
        }
      }
      this.generation++
      this.cancelTimer()
      if (enabled && this.verificationRun !== '') throw new Error('verification_reading_scope')
      if (enabled && this.readingVerificationWork !== '') this.verificationComicId()
      if (enabled) await this.distributedStore(context)
      else if (this.view.enabled) {
        const store = await openUserDataDatabase(context)
        await this.configureCloudTables(store, this.registrationTables(), false)
        this.nativeEnabled = false
        const cancel = this.cancelTransfer
        if ((this.nativeTransfer !== undefined || this.current !== undefined) && typeof store.stopCloudSync === 'function') {
          await store.stopCloudSync()
          cancel?.()
        }
        this.cancelTimer()
      }
      if (this.view.verificationOnly) {
        this.view.enabled = enabled
        return
      }
      storage.update((state: SyncLocalDocument): void => {
        const active: SyncSavedConnection = state.active ?? {
          credential: '', endpointIdentity: 'huawei-cloud-rdb', space: SPACE, revision: 0, manifestHash: '',
          selected: [], automatic: true, reviewRequired: false, lastSuccess: 0, lastError: '', groups: [],
        }
        active.enabled = enabled
        active.selected = this.selection()
        active.endpointIdentity = 'huawei-cloud-rdb'
        active.lastError = ''
        state.active = active
      })
      this.view.enabled = enabled
      if (enabled) this.schedule(1500)
    } catch (error) {
      this.report(error as Error)
    } finally {
      this.view.configuring = false
    }
  }

  sync(): Promise<void> {
    if (this.current !== undefined) return this.current
    if (this.nativeTransfer !== undefined) return Promise.resolve()
    if (this.publication !== undefined) return this.publication.then((): Promise<void> => this.sync())
    if (!this.view.enabled || this.view.configuring || this.restoring || !this.verificationContextMatches() || this.context === undefined ||
      this.storage === undefined) return Promise.resolve()
    if (this.selection().length === 0) {
      this.view.error = 'empty'
      return Promise.resolve()
    }
    this.cancelTimer()
    const generation = this.generation
    this.view.busy = true
    this.view.error = ''
    this.current = this.round(this.context, this.storage, generation).catch((error: Error): void => {
      if (generation === this.generation) this.report(error)
    }).finally((): void => {
      this.view.busy = false
      this.current = undefined
      this.schedulePublication()
      this.schedule(RETRY_MS)
    })
    return this.current
  }

  private schedule(delay: number): void {
    if (this.view.verificationOnly || !this.foreground || !this.view.enabled || this.restoring || this.selection().length === 0) return
    const deadline = Date.now() + delay
    if (this.timer >= 0 && this.deadline <= deadline) return
    this.cancelTimer()
    this.deadline = deadline
    this.timer = setTimeout((): void => {
      this.timer = -1
      this.deadline = 0
      void this.sync()
    }, delay)
  }

  private cancelTimer(): void {
    if (this.timer >= 0) clearTimeout(this.timer)
    this.timer = -1
    this.deadline = 0
  }

  private verificationContextMatches(): boolean {
    return this.verificationRun === komaCloudVerificationRun() &&
      this.readingVerificationWork === komaCloudReadingVerificationWork()
  }

  private verificationComicId(): string | undefined {
    if (this.readingVerificationWork === '') return undefined
    const work = syncKeyParts(this.readingVerificationWork)
    if (work.length !== 2 || !syncReadingIdentity(work[0], work[1])) throw new Error('verification_reading_scope')
    return sourceLibraryComicId(work[0], work[1])
  }

  private report(error: Error): void {
    const code = error.message || 'unknown'
    const nativeCode = (error as BusinessError).code
    this.view.error = nativeCode === 201 ? 'permission' : code
    DiagnosticLogger.warn('huawei-cloud-sync', 'failed', 'code=' + (nativeCode ?? '') + ' ' + code)
  }

  private distributedStore(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (this.readyStore !== undefined) return this.readyStore
    const pending = this.registerTables(context).catch((error: Error): never => {
      this.readyStore = undefined
      DiagnosticLogger.exception('huawei-cloud-sync', 'table-setup-failed', error)
      if ((error as BusinessError).code === 201 || error.message === 'verification_reading_scope') throw error
      throw new Error('table_setup')
    })
    this.readyStore = pending
    return pending
  }

  private registrationTables(): string[] {
    return cloudTablesForGroups(this.readingVerificationWork === '' ? SYNC_GROUPS : ['reading'])
  }

  private async registerTables(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const store = await openUserDataDatabase(context)
    const names = this.registrationTables()
    if (this.readingVerificationWork === '') {
      await Promise.all([new SearchHistoryStore(context).prepareStorage(), loadSourceSubscriptionPreferences(context)])
    }
    // Register with the database offline. ArkData can
    // independently queue a sync when a schema upgrade clears its watermark.
    // That task does not use the manual round's work predicate.
    await prepareCloudWorkDeletions(store)
    await this.configureCloudTables(store, names, false)
    store.on('dataChange', relationalStore.SubscribeType.SUBSCRIBE_TYPE_CLOUD_DETAILS,
      (changes: relationalStore.ChangeInfo[]): void => { this.receiveChanges(changes) })
    DiagnosticLogger.info('huawei-cloud-sync', 'registered',
      'database=Koma enableCloud=false tables=' + names.join(','))
    return store
  }

  private configureCloudTables(store: relationalStore.RdbStore, tables: string[], enableCloud: boolean): Promise<void> {
    // ArkData 26 rejects a predicate while the database auto-sync switch is on.
    // A user disabling sync must run after any pending native activation.
    this.nativeConfiguration = this.nativeConfiguration.catch((): void => {}).then(async (): Promise<void> => {
      await store.setDistributedTables(tables, relationalStore.DistributedType.DISTRIBUTED_CLOUD,
        { autoSync: false, autoSyncSwitch: false, enableCloud: enableCloud })
    })
    return this.nativeConfiguration
  }

  private transfer(store: relationalStore.RdbStore, tables: string[], predicate?: relationalStore.RdbPredicates): Promise<void> {
    const generation = this.generation
    let timedOut = false
    // ArkData commits rows during transfer. Keep the existing restore gate
    // occupied until the native task ends, even if the UI has timed out.
    const active = BackupRestoreActivity.runWrite(async (): Promise<void> => {
      if (generation !== this.generation) throw new Error('sync_local_busy')
      try {
        await this.startNativeTransfer(store, tables, predicate)
      } finally {
        if (timedOut) await stopCloudWorkDeletions(store)
      }
    }).finally((): void => {
      this.nativeTransfer = undefined
      if (timedOut) {
        this.schedulePublication()
        this.schedule(0)
      }
    })
    this.nativeTransfer = active
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      const timer = setTimeout((): void => {
        timedOut = true
        reject(new Error('timeout'))
      }, TIMEOUT_MS)
      void active.then(resolve, reject).finally((): void => clearTimeout(timer))
    })
  }

  private startNativeTransfer(store: relationalStore.RdbStore, tables: string[],
    predicate?: relationalStore.RdbPredicates): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      const cancel = (): void => finish(new Error('sync_local_busy'))
      const finish = (error?: Error): void => {
        if (this.cancelTransfer !== cancel) return
        this.cancelTransfer = undefined
        if (error === undefined) resolve()
        else reject(error)
      }
      this.cancelTransfer = cancel
      const onProgress = (progress: relationalStore.ProgressDetails): void => {
        if (progress.schedule !== relationalStore.Progress.SYNC_FINISH || this.cancelTransfer !== cancel) return
        let uploadFailed = 0
        let downloadFailed = 0
        const failedTables: string[] = []
        for (const table of tables) {
          const detail = progress.details?.[table]
          if (detail === undefined) continue
          uploadFailed += detail.upload.failed
          downloadFailed += detail.download.failed
          if (detail.upload.failed > 0 || detail.download.failed > 0) failedTables.push(table)
          DiagnosticLogger.info('huawei-cloud-sync', 'table',
            table + ' up=' + detail.upload.successful + ' down=' + detail.download.successful +
              ' upFailed=' + detail.upload.failed + ' downFailed=' + detail.download.failed)
        }
        const code = progress.code
        DiagnosticLogger.info('huawei-cloud-sync', 'finish', 'code=' + code + ' upFailed=' + uploadFailed +
          ' downFailed=' + downloadFailed + (progress.message ? ' message=' + progress.message.slice(0, 200) : ''))
        // Keep concrete SDK causes such as network and quota. The generic result
        // still includes per-direction failure counts when records could not sync.
        if (code !== relationalStore.ProgressCode.SUCCESS && code !== relationalStore.ProgressCode.UNKNOWN_ERROR) {
          finish(new Error(String(code)))
        } else if (uploadFailed > 0 || downloadFailed > 0) {
          const reason = downloadFailed === 0 ? 'upload' : uploadFailed === 0 ? 'download' : 'partial'
          const group = SYNC_GROUPS.find((value: SyncGroup): boolean => {
            const groupTables = cloudTablesForGroups([value])
            return failedTables.every((table: string): boolean => groupTables.includes(table))
          })
          finish(new Error(group === undefined ? reason : reason + ':' + group))
        } else if (code !== relationalStore.ProgressCode.SUCCESS) {
          finish(new Error(String(code)))
        } else {
          finish()
        }
      }
      const mode = relationalStore.SyncMode.SYNC_MODE_TIME_FIRST
      // The debug predicate reads only cloud records already linked to this
      // primary key on the device. It cannot discover a new cloud record.
      void Promise.resolve().then((): Promise<void> => predicate === undefined ? store.cloudSync(mode, tables, onProgress) :
        store.cloudSyncEx({ mode, predicate }, onProgress)).catch((error: Error): void => finish(error))
    })
  }

  private receiveChanges(changes: relationalStore.ChangeInfo[]): void {
    if (changes.length === 0) return
    this.nativeChanges.push(...changes)
    this.needsPublication = true
    this.schedulePublication()
  }

  private canPublish(): boolean {
    return !this.restoring && this.publish !== undefined && this.verificationContextMatches()
  }

  private schedulePublication(delay: number = 0): void {
    const context = this.context
    if (context === undefined || !this.needsPublication || !this.canPublish() ||
      this.current !== undefined || this.publication !== undefined || this.publicationTimer >= 0) return
    // ArkData's progress and data-change callbacks arrive independently. A
    // late change only needs a local publication, even with auto-sync off.
    this.publicationTimer = setTimeout((): void => {
      this.publicationTimer = -1
      if (!this.canPublish() || this.current !== undefined || this.publication !== undefined) return
      let retryDelay = 0
      this.publication = this.distributedStore(context).then(async (store: relationalStore.RdbStore): Promise<void> => {
        if (!this.canPublish()) return
        const work = this.verificationComicId()
        // The selection controls transfers. Rows already committed by the
        // SDK still need to appear if the user changed that selection.
        await this.applyChanges(context, store, work === undefined ? SYNC_GROUPS : this.selection(), work)
      }).catch((error: Error): void => {
        if (error.message === 'sync_local_busy') retryDelay = 500
        else {
          retryDelay = RETRY_MS
          DiagnosticLogger.exception('huawei-cloud-sync', 'publication-failed', error)
        }
      }).finally((): void => {
        this.publication = undefined
        this.schedulePublication(retryDelay)
      })
    }, delay)
  }

  private async applyChanges(context: common.UIAbilityContext, store: relationalStore.RdbStore, groups: SyncGroup[],
    selectedWork?: string): Promise<void> {
    const changes = this.nativeChanges
    this.nativeChanges = []
    this.needsPublication = false
    try {
      const effects = await cloudBusinessChanges(store, changes, groups, selectedWork)
      if (effects.groups.size === 0 && effects.deletedWorkSerial === 0) return
      const reading = effects.readingScope()
      if (selectedWork !== undefined && reading.some(item => item.comicId !== selectedWork)) {
        throw new Error('verification_reading_scope')
      }
      await BackupRestoreActivity.runDeviceSyncCommit(async (): Promise<void> => {
        if (reading.length > 0) publishLiveCloudReading(context.filesDir, reading)
        const shelf = effects.shelfWorks.size > 0 || effects.categories || effects.smartCategories ?
          new LibraryRdbStorage(store).cloudShelfEdits(Array.from(effects.shelfWorks), effects.categories,
            effects.smartCategories, Array.from(effects.removedCategoryIds)) :
          undefined
        await new SearchHistoryStore(context).applyCloudTermRemovals(effects.removedSearchTerms)
        if (effects.removedSubscriptionUrls.size > 0) {
          await new SourceIndexService(context).applyCloudRemovals(effects.removedSubscriptionUrls)
        }
        this.publish?.(Array.from(effects.groups), reading.map(item => item.comicId), shelf)
      })
      if (effects.groups.has('reader-settings')) await new ReaderPreferencesStore(context).load()
      if (effects.groups.has('source-subscriptions')) await appSourcePackageManagerCache.reloadSavedCatalog(context)
      await acknowledgeCloudWorkDeletions(store, effects.deletedWorkSerial)
    } catch (error) {
      this.nativeChanges = changes.concat(this.nativeChanges)
      this.needsPublication = true
      throw error as Error
    }
  }

  private async round(context: common.UIAbilityContext, storage: DeviceSyncStorage, generation: number): Promise<void> {
    const guard = (): void => {
      if (this.generation !== generation || this.restoring || !this.view.enabled || !this.verificationContextMatches() ||
        BackupRestoreActivity.isRestoring()) throw new Error('sync_local_busy')
    }
    guard()
    const selected = this.selection()
    const store = await this.distributedStore(context)
    const selectedWork = this.verificationComicId()
    const tables = cloudTablesForGroups(selected)
    if (selected.includes('reading') && !await appReaderSessionStore(context.filesDir).flushAsync()) {
      throw new Error('sync_local_busy')
    }
    guard()
    await startCloudWorkDeletions(store, selectedWork)
    let failure: Error | undefined
    try {
      guard()
      if (selectedWork !== undefined) {
        if (context.applicationInfo.debug !== true || typeof store.cloudSyncEx !== 'function') {
          throw new Error('verification_reading_scope')
        }
        try {
          await this.configureCloudTables(store, tables, true)
          for (const table of tables) {
            guard()
            const predicate = new relationalStore.RdbPredicates(table).equalTo('comic_id', selectedWork)
            if (table === 'reader_chapter_states') {
              // The scoped call requires both parts of the chapter state's key.
              const chapter = readerPositions.read(store, 'comic_id = ?', [selectedWork])[0]?.chapterId
              if (!chapter) throw new Error('verification_reading_scope')
              predicate.and().equalTo('chapter_id', chapter)
            }
            await this.transfer(store, [table], predicate)
          }
        } finally {
          await this.configureCloudTables(store, tables, false)
        }
      } else {
        if (!this.nativeEnabled) {
          await this.configureCloudTables(store, tables, true)
          this.nativeEnabled = true
          guard()
        }
        if (selected.includes('shelf')) {
          await this.transfer(store, SHELF_PARENT_TABLES)
          guard()
          // Smart categories need their rule rows before publication.
          await this.transfer(store, tables.filter(table => !SHELF_PARENT_TABLES.includes(table)))
        } else await this.transfer(store, tables)
      }
    } catch (error) {
      failure = error as Error
    }
    // A partial failure leaves successfully downloaded rows committed. Only
    // a JS timeout leaves the transfer worker active and still capturing keys.
    this.needsPublication = true
    if (failure?.message !== 'timeout') await stopCloudWorkDeletions(store)
    if (this.canPublish() && !BackupRestoreActivity.isRestoring()) {
      try {
        await this.applyChanges(context, store, selectedWork === undefined ? SYNC_GROUPS : selected, selectedWork)
      } catch (error) {
        if (failure === undefined) throw error as Error
        DiagnosticLogger.exception('huawei-cloud-sync', 'publication-failed', error as Error)
      }
    }
    if (failure !== undefined) throw failure
    guard()
    const success = Date.now()
    // Verification reads and writes the selected comic, but has its own in-memory
    // status so it cannot change the user's ordinary switch or success time.
    if (this.view.verificationOnly) {
      this.view.lastSuccess = success
      return
    }
    storage.update((state: SyncLocalDocument): void => {
      if (state.active === undefined) return
      state.active.lastSuccess = success
      state.active.lastError = ''
    })
    this.view.lastSuccess = success
  }
}

export const appHuaweiCloudSync = new HuaweiCloudSync()
