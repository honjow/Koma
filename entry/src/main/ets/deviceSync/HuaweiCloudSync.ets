import { abilityAccessCtrl, common, Permissions, Want } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { taskpool } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { komaCloudReadingVerificationWork, komaCloudVerificationRun } from '../state/KomaDeviceVerificationIsolation'
import { checkSyncGroupFact, syncBucketKey, syncKeyParts, syncReadingIdentity, SyncWorkSlice } from './DeviceSyncData'
import { applyReceiptBaselines } from './DeviceSyncEngine'
import { checkedSyncFact, isSyncReplica, mergeSyncFact, SyncFact, SyncGroup, SYNC_GROUPS } from './DeviceSyncFacts'
import { HUAWEI_CLOUD_SYNC_BUILD_ENABLED } from './HuaweiCloudSyncBuildFlag'
import { KomaDeviceSyncOwners } from './DeviceSyncOwners'
import {
  bySyncFact, PackedPlanInput, PackedSyncPlan, packSyncPlan, packSyncPlanInput, planDeviceSync, PreparedGroup, replaceGroup,
  unpackSyncPlan, unpackSyncPlanInput,
} from './DeviceSyncPlanner'
import { DeviceSyncStorage, SyncGroupState, SyncLocalDocument, SyncSavedConnection } from './DeviceSyncStorage'
import { syncDigest, syncUtf8, SYNC_MAX_OBJECT_BYTES, SYNC_MAX_ROUND_BYTES } from './DeviceSyncWire'

const SPACE = '7f562b9b-3095-4c87-a586-25c9cc5fa988'
// ArkData rejects the hyphenated store ID of the existing business RDB.
// Only transport rows are distributed. The business owners keep their RDB.
const CLOUD_DATABASE = 'koma_user_data.db'
const PERMISSION: Permissions = 'ohos.permission.DISTRIBUTED_DATASYNC'
const SETTINGS_URI = 'hicloud://cloudDrive/getInfo?path=MainActivity'
const TIMEOUT_MS = 240000
const RETRY_MS = 60000
const VERIFICATION_PREFIX = 'koma-cloud-verification-'

interface CloudRecord {
  schema: number
  writer: string
  fact: SyncFact
}

interface CloudCounts {
  uploaded: number
  downloaded: number
}

function cloudTable(group: SyncGroup): string {
  return 'cloud_sync_' + group.replace(/-/g, '_')
}

function recordId(writer: string, key: string): string {
  return syncDigest(JSON.stringify([writer, key]))
}

@Concurrent
function planCloudRound(groups: PackedPlanInput[], space: string, replica: string, counter: number): PackedSyncPlan {
  return packSyncPlan(planDeviceSync(unpackSyncPlanInput(groups), undefined, [], space, true, replica, counter,
    { writer: true, shared: true }))
}

@ObservedV2
export class HuaweiCloudSyncView {
  @Trace available: boolean = false
  @Trace verificationOnly: boolean = false
  @Trace enabled: boolean = false
  @Trace busy: boolean = false
  @Trace configuring: boolean = false
  @Trace lastSuccess: number = 0
  @Trace error: string = ''
  @Trace uploaded: number = 0
  @Trace downloaded: number = 0
}

class HuaweiCloudSync {
  readonly view = new HuaweiCloudSyncView()
  private context?: common.UIAbilityContext
  private storage?: DeviceSyncStorage
  private owner?: KomaDeviceSyncOwners
  private selection: () => SyncGroup[] = (): SyncGroup[] => []
  private readyStore?: Promise<relationalStore.RdbStore>
  private current?: Promise<void>
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
    this.owner = owner
    this.verificationRun = komaCloudVerificationRun()
    this.readingVerificationWork = komaCloudReadingVerificationWork()
    this.view.verificationOnly = this.verificationRun !== '' || this.readingVerificationWork !== ''
    this.selection = this.readingVerificationWork === '' ? selection : (): SyncGroup[] => ['reading']
    const active = storage.load().active
    this.view.enabled = active?.enabled === true && !this.view.verificationOnly
    this.view.lastSuccess = active?.lastSuccess ?? 0
    this.view.error = active?.lastError ?? ''
  }

  attachPublisher(publish: (groups: SyncGroup[]) => void): void {
    this.owner?.publishWith(publish)
  }

  onForeground(value: boolean): void {
    this.foreground = value
    this.cancelTimer()
    if (value) this.schedule(1500)
  }

  setRestoring(value: boolean): void {
    this.restoring = value
    this.generation++
    this.cancelTimer()
    if (!value) this.schedule(2500)
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
      if (this.verificationRun !== '') {
        this.view.enabled = enabled
        return
      }
      if (enabled && this.readingVerificationWork !== '') {
        const work = syncKeyParts(this.readingVerificationWork)
        const active = storage.load().active
        if (work.length !== 2 || !syncReadingIdentity(work[0], work[1]) || active?.enabled === true ||
          active?.groups.some(group => group.id !== 'reading' ||
            group.facts.some(fact => !this.matchesReadingWork(fact.key)))) {
          throw new Error('verification_reading_scope')
        }
      }
      if (enabled) await this.distributedStore(context)
      storage.update((state: SyncLocalDocument): void => {
        const active: SyncSavedConnection = state.active ?? {
          credential: '', endpointIdentity: 'huawei-cloud', space: SPACE, revision: 0, manifestHash: '',
          selected: [], automatic: true, reviewRequired: false, lastSuccess: 0, lastError: '', groups: [],
        }
        // Keep the real reading receipt, but do not leave all-content sync on
        // when the device is next started without the debug work scope.
        active.enabled = enabled && this.readingVerificationWork === ''
        active.selected = this.selection()
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
    if (!this.view.enabled || this.restoring || !this.verificationContextMatches() || this.context === undefined ||
      this.storage === undefined || this.owner === undefined) return Promise.resolve()
    if (this.verificationRun === '' && this.selection().length === 0) {
      this.view.error = 'empty'
      return Promise.resolve()
    }
    this.cancelTimer()
    const generation = this.generation
    this.view.busy = true
    this.view.error = ''
    const operation = this.verificationRun === '' ? this.round(this.context, this.storage, this.owner, generation) :
      this.verifyTransport(this.context, generation)
    this.current = operation.catch((error: Error): void => {
      if (generation === this.generation) this.report(error)
    }).finally((): void => {
      this.view.busy = false
      this.current = undefined
      this.schedule(RETRY_MS)
    })
    return this.current
  }

  private schedule(delay: number): void {
    if (this.verificationRun !== '' || !this.foreground || !this.view.enabled || this.restoring || this.selection().length === 0) return
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

  private matchesReadingWork(key: string): boolean {
    return this.readingVerificationWork === '' || syncBucketKey(key) === this.readingVerificationWork
  }

  private report(error: Error): void {
    const code = error.message || 'unknown'
    this.view.error = code
    DiagnosticLogger.warn('huawei-cloud-sync', 'failed', 'code=' + ((error as BusinessError).code ?? '') + ' ' + code)
  }

  private distributedStore(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (this.readyStore !== undefined) return this.readyStore
    const pending = this.registerTables(context).catch((error: Error): never => {
      this.readyStore = undefined
      throw error
    })
    this.readyStore = pending
    return pending
  }

  private async registerTables(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, {
      name: CLOUD_DATABASE, securityLevel: relationalStore.SecurityLevel.S3, allowRebuild: false,
    })
    const names = SYNC_GROUPS.map(cloudTable)
    for (const name of names) {
      await store.execute('CREATE TABLE IF NOT EXISTS ' + name + ' (record_id TEXT PRIMARY KEY, payload TEXT)')
      if (this.verificationRun !== '') await this.assertVerificationTable(store, name)
    }
    // Explicit scheduling applies the shared dataset selection on every run.
    await store.setDistributedTables(names, relationalStore.DistributedType.DISTRIBUTED_CLOUD, { autoSync: false })
    DiagnosticLogger.info('huawei-cloud-sync', 'registered', 'tables=' + names.join(','))
    return store
  }

  private async assertVerificationTable(store: relationalStore.RdbStore, table: string): Promise<void> {
    const rows = await store.querySql('SELECT record_id FROM ' + table + ' WHERE record_id NOT LIKE ? LIMIT 1',
      [VERIFICATION_PREFIX + '%'])
    try {
      if (rows.goToNextRow()) throw new Error('verification_table_contains_user_data')
    } finally {
      rows.close()
    }
  }

  private async verifyTransport(context: common.UIAbilityContext, generation: number): Promise<void> {
    const run = this.verificationRun
    const mode = run.slice(0, run.indexOf(':'))
    const fixture = run.slice(mode.length + 1)
    const guard = (): void => {
      if (run !== komaCloudVerificationRun() || generation !== this.generation || !this.view.enabled) {
        throw new Error('sync_cancelled')
      }
    }
    guard()
    const tables = SYNC_GROUPS.map(cloudTable)
    const store = await this.distributedStore(context)
    for (const table of tables) await this.assertVerificationTable(store, table)
    guard()
    const counts = await this.transfer(store, tables)
    guard()
    // Test runs exercise the same signed package, tables and native API.
    // The fixture never reads the application's business-data owners.
    const id = VERIFICATION_PREFIX + fixture
    let found = 0
    for (const table of tables) {
      await this.assertVerificationTable(store, table)
      guard()
      const rows = await store.querySql('SELECT payload FROM ' + table + ' WHERE record_id = ?', [id])
      try {
        if (rows.goToNextRow() && rows.getString(0) === id + ':' + table) found++
      } finally {
        rows.close()
      }
    }
    if ((mode === 'send' && found === 0) || (mode === 'remove' && found > 0)) {
      const transaction = await store.createTransaction()
      try {
        for (const table of tables) {
          guard()
          if (mode === 'send') {
            await transaction.execute('INSERT INTO ' + table + ' (record_id, payload) VALUES (?, ?)', [id, id + ':' + table])
          } else {
            await transaction.execute('DELETE FROM ' + table + ' WHERE record_id = ?', [id])
          }
        }
        await transaction.commit()
      } catch (error) {
        await transaction.rollback()
        throw error as Error
      }
      guard()
      const written = await this.transfer(store, tables)
      counts.uploaded += written.uploaded
      counts.downloaded += written.downloaded
    } else if (((mode === 'receive' || mode === 'send') && found !== tables.length) ||
      (mode === 'absent' && found !== 0)) {
      throw new Error('verification_partial')
    }
    guard()
    DiagnosticLogger.info('huawei-cloud-sync', 'verification', 'mode=' + mode + ' matched=' + found + ' tables=' + tables.length)
    this.view.lastSuccess = Date.now()
    this.view.uploaded = counts.uploaded
    this.view.downloaded = counts.downloaded
  }

  private transfer(store: relationalStore.RdbStore, tables: string[]): Promise<CloudCounts> {
    return new Promise<CloudCounts>((resolve: (counts: CloudCounts) => void, reject: (error: Error) => void): void => {
      const timer = setTimeout((): void => reject(new Error('timeout')), TIMEOUT_MS)
      void store.cloudSync(relationalStore.SyncMode.SYNC_MODE_TIME_FIRST, tables,
        (progress: relationalStore.ProgressDetails): void => {
          if (progress.schedule !== relationalStore.Progress.SYNC_FINISH) return
          clearTimeout(timer)
          const counts: CloudCounts = { uploaded: 0, downloaded: 0 }
          let failed = 0
          for (const table of tables) {
            const detail = progress.details?.[table]
            if (detail === undefined) continue
            counts.uploaded += detail.upload.successful
            counts.downloaded += detail.download.successful
            failed += detail.upload.failed + detail.download.failed
            DiagnosticLogger.info('huawei-cloud-sync', 'table',
              table + ' up=' + detail.upload.successful + ' down=' + detail.download.successful +
                ' failed=' + (detail.upload.failed + detail.download.failed))
          }
          DiagnosticLogger.info('huawei-cloud-sync', 'finish', 'code=' + progress.code + ' failed=' + failed)
          if (progress.code !== 0 || failed > 0) reject(new Error(progress.code === 0 ? 'partial' : String(progress.code)))
          else resolve(counts)
        }).catch((error: Error): void => {
        clearTimeout(timer)
        reject(error)
      })
    })
  }

  private async readFacts(store: relationalStore.RdbStore, group: SyncGroup, work: SyncWorkSlice,
    budget: CloudRoundBudget, guard: () => void): Promise<SyncFact[]> {
    const result = await store.querySql('SELECT record_id, payload FROM ' + cloudTable(group))
    const facts = new Map<string, SyncFact>()
    try {
      while (result.goToNextRow()) {
        const pause = work.pause()
        if (pause !== undefined) { await pause; guard() }
        const id = result.getString(0)
        if (id.startsWith(VERIFICATION_PREFIX)) continue
        const payload = result.getString(1)
        const size = syncUtf8(payload).byteLength
        budget.bytes += size
        if (size === 0 || size > SYNC_MAX_OBJECT_BYTES || budget.bytes > SYNC_MAX_ROUND_BYTES) {
          throw new Error('record_size')
        }
        const row = JSON.parse(payload) as CloudRecord
        if (row.schema !== 1 || !isSyncReplica(row.writer)) throw new Error('record_format')
        const fact = checkedSyncFact(row.fact)
        if (id !== recordId(row.writer, fact.key)) throw new Error('record_format')
        checkSyncGroupFact(group, fact)
        if (!this.matchesReadingWork(fact.key)) throw new Error('verification_reading_scope')
        const previous = facts.get(fact.key)
        facts.set(fact.key, previous === undefined ? fact : mergeSyncFact(previous, fact))
      }
    } finally { result.close() }
    return Array.from(facts.values())
  }

  private async writePending(store: relationalStore.RdbStore, groups: SyncGroupState[], prepared: PreparedGroup[],
    writer: string, work: SyncWorkSlice, guard: () => void): Promise<boolean> {
    let written = false
    const transaction = await store.createTransaction()
    try {
      for (const group of groups) {
        const keys = new Set<string>(group.pending.map(edit => edit.key))
        if (keys.size === 0) continue
        const protectedKeys = prepared.find(row => row.id === group.id)?.local.protectedKeys ?? []
        const facts = bySyncFact(group.facts)
        for (const key of keys) {
          if (!this.matchesReadingWork(key) || group.deferred?.includes(key) || protectedKeys.includes(key)) continue
          const fact = facts.get(key)
          if (fact === undefined) continue
          const pause = work.pause()
          if (pause !== undefined) { await pause; guard() }
          const row: CloudRecord = { schema: 1, writer, fact }
          const payload = JSON.stringify(row)
          if (syncUtf8(payload).byteLength > SYNC_MAX_OBJECT_BYTES) throw new Error('record_size')
          await transaction.execute('INSERT INTO ' + cloudTable(group.id) + ' (record_id, payload) VALUES (?, ?) ' +
            'ON CONFLICT(record_id) DO UPDATE SET payload=excluded.payload WHERE payload<>excluded.payload',
            [recordId(writer, fact.key), payload])
          written = true
        }
      }
      guard()
      await transaction.commit()
      return written
    } catch (error) {
      await transaction.rollback()
      throw error as Error
    }
  }

  private async round(context: common.UIAbilityContext, storage: DeviceSyncStorage, owner: KomaDeviceSyncOwners,
    generation: number): Promise<void> {
    const guard = (): void => {
      if (this.generation !== generation || this.restoring || !this.view.enabled || !this.verificationContextMatches() ||
        BackupRestoreActivity.isRestoring()) throw new Error('sync_local_busy')
    }
    await owner.recoverPendingLocalRollback()
    guard()
    const selected = this.selection()
    const tables = selected.map(cloudTable)
    const store = await this.distributedStore(context)
    guard()
    if (this.readingVerificationWork !== '') {
      // Native upload scans the whole table. Refuse the test if any existing
      // transport row belongs to a different work, before contacting the cloud.
      await this.readFacts(store, 'reading', new SyncWorkSlice(), { bytes: 0 }, guard)
      guard()
    }
    const counts = await this.transfer(store, tables)
    guard()
    const original = storage.load()
    const active = original.active
    if (active === undefined) return
    const work = new SyncWorkSlice()
    const budget: CloudRoundBudget = { bytes: 0 }
    const prepared: PreparedGroup[] = []
    for (const id of selected) {
      const remote = await this.readFacts(store, id, work, budget, guard)
      const local = await owner.snapshot(id, true, guard, SPACE, false)
      if (this.readingVerificationWork !== '') {
        local.values = local.values.filter(row => this.matchesReadingWork(row.key))
        local.protectedKeys = local.protectedKeys?.filter(key => this.matchesReadingWork(key))
      }
      const previous = active.groups.find(group => group.id === id)
      const baseline = previous?.baseline.map(item => item.key) ?? []
      const present = new Set<string>(local.values.map(item => item.key))
      const removed = id === 'source-subscriptions' ? baseline.filter(key => !present.has(key)) :
        await owner.removed(id, baseline)
      prepared.push({ id, local, remote, previous, requiresPreview: false, resetBaseline: false, removed })
    }
    const input = await packSyncPlanInput(prepared, (): Promise<void> | undefined => work.pause())
    const plan = await unpackSyncPlan(
      await taskpool.execute(planCloudRound, input, SPACE, original.replica, original.counter) as PackedSyncPlan,
      (): Promise<void> | undefined => work.pause(),
    )
    guard()
    for (const apply of plan.applies) await owner.validateChanges(apply)
    const committed = applyReceiptBaselines(plan.groups, plan.applies)
    await owner.commit(plan.applies, plan.revisions, (receipt: string) =>
      storage.prepareReceipt((state: SyncLocalDocument): void => {
        if (storage.load() !== original || state.active === undefined) throw new Error('sync_local_changed')
        state.localReceipt = receipt
        state.counter = plan.counter
        for (const group of committed) state.active.groups = replaceGroup(state.active.groups, group)
      }, guard), '', (): boolean => generation === this.generation && this.view.enabled)
    const wrote = await this.writePending(store, committed, prepared, original.replica, work, guard)
    if (wrote) {
      const next = await this.transfer(store, tables)
      counts.uploaded += next.uploaded
      counts.downloaded += next.downloaded
    }
    guard()
    const success = Date.now()
    storage.update((state: SyncLocalDocument): void => {
      if (state.active === undefined) return
      state.active.lastSuccess = success
      state.active.lastError = ''
      state.active.groups = state.active.groups.map((group: SyncGroupState): SyncGroupState => {
        if (!selected.includes(group.id)) return group
        const protectedKeys = prepared.find(row => row.id === group.id)?.local.protectedKeys ?? []
        return { id: group.id, facts: group.facts, baseline: group.baseline, deferred: group.deferred,
          deferredRoots: group.deferredRoots,
          pending: group.pending.filter(edit => group.deferred?.includes(edit.key) || protectedKeys.includes(edit.key)) }
      })
    })
    this.view.lastSuccess = success
    this.view.uploaded = counts.uploaded
    this.view.downloaded = counts.downloaded
  }
}

interface CloudRoundBudget {
  bytes: number
}

export const appHuaweiCloudSync = new HuaweiCloudSync()
