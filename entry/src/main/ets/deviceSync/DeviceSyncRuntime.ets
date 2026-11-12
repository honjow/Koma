import { common } from '@kit.AbilityKit'
import { connection } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { util } from '@kit.ArkTS'
import { ReadingProgress } from '../model/ComicModels'
import { appReaderSessionStore } from '../model/ReaderSessionStore'
import { SourceReaderSessionRequest } from '../model/SourceReaderSession'
import { getInstalledSourcePackage } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { DeviceSyncEngine, DeviceSyncLocalEdit, SyncMergeChoice, SyncPreview, SyncReadingRound,
  SyncReadingWorkConflict, SyncReadingWorkResult, syncRequiresExplicitReview } from './DeviceSyncEngine'
import { DeviceSyncShardCache } from './DeviceSyncShardCache'
import { mergeSyncVectors, SyncEditKind, SyncGroup, SyncVersion } from './DeviceSyncFacts'
import { KomaDeviceSyncOwners, SyncShelfRemoval } from './DeviceSyncOwners'
import {
  DeviceSyncStorage, SyncBlockedReading, SyncGroupState, SyncLocalDocument, SyncReadingRestoreCandidate,
} from './DeviceSyncStorage'
import {
  syncBusinessKey, syncCatalogRecordKey, syncKey, syncKeyParts, syncReadingIdentity, syncReadingPosition, syncReadingRecent, syncSearchIdentity,
  syncShelfIdentity, SyncPositionValue,
  SyncReaderMode,
} from './DeviceSyncData'
import { connectDeviceSyncOwnerEdits, connectDeviceSyncProgress, connectDeviceSyncReadingCapture, connectDeviceSyncRestore,
  connectDeviceSyncSignals, connectDeviceSyncSearchHistory, deviceSyncActionCaptureKey, deviceSyncCaptureKey, SyncBookModeSignal, SyncCapturedReadingEdit,
  SyncLibrarySignal, SyncReadingActionCapture, SyncReadingCapture, SyncReadingSignal } from './DeviceSyncSignals'
import { SyncConnectionDraft } from './DeviceSyncWebDav'
import { subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'

const IDLE_CHECK_MIN_MS: number = 60000
const IDLE_CHECK_MAX_MS: number = 300000
type SyncScheduleReason = 'activity' | 'idle' | 'retry'

@ObservedV2
export class DeviceSyncViewState {
  @Trace ready: boolean = false
  @Trace connected: boolean = false
  @Trace configured: boolean = false
  @Trace awaitingFirstMerge: boolean = false
  @Trace unresolvedCommit: boolean = false
  @Trace selected: SyncGroup[] = ['shelf', 'reading']
  @Trace automatic: boolean = false
  @Trace enabled: boolean = true
  @Trace busy: boolean = false
  @Trace transferInFlight: boolean = false
  @Trace manualInProgress: boolean = false
  @Trace needsReview: boolean = false
  @Trace requiresExplicitReview: boolean = false
  @Trace lastSuccess: number = 0
  @Trace error: string = ''
  @Trace revision: number = 0
  @Trace searchHistoryRevision: number = 0
  @Trace shelfRemovals: SyncShelfRemoval[] = []
  @Trace blockedReadings: SyncBlockedReading[] = []
  @Trace manualReadingResult?: SyncReadingRound
}

interface ActiveReadingSync {
  comicId: string
  scope: string
  source: string
  work: string
  chapter: string
  title: string
  sourceName: string
  chapterTitle: string
  workUrl?: string
  positionKey: string
  recentKey: string
  readKey: string
  positionSeen: SyncVersion[]
  recentSeen: SyncVersion[]
  recentCleared: SyncVersion[]
  readSeen: SyncVersion[]
  lastPage: number
  lastComplete: boolean
}

interface PendingReadingSync {
  session: ActiveReadingSync
  progress: ReadingProgress
  id: string
  observedActions: string[]
}

class DeviceSyncRuntime {
  readonly view: DeviceSyncViewState = new DeviceSyncViewState()
  private context?: common.UIAbilityContext
  private engine?: DeviceSyncEngine
  private storage?: DeviceSyncStorage
  private owners?: KomaDeviceSyncOwners
  private foreground: boolean = false
  private openReviews: number = 0
  private timer: number = -1
  private deadline: number = 0
  private idleCheckDelay: number = IDLE_CHECK_MIN_MS
  private activeSync?: Promise<void>
  private manualSync?: Promise<void>
  private editingConnection: boolean = false
  private taskDone?: Promise<void>
  private changeGeneration: number = 0
  private syncedGeneration: number = -1
  private failures: number = 0
  private network?: connection.NetConnection
  private session?: ActiveReadingSync
  private pendingReading: Map<string, PendingReadingSync> = new Map()
  private blockedReading?: PendingReadingSync
  private recoveredOnForeground: boolean = false
  private libraryEdits: Promise<void> = Promise.resolve()
  private bookModeEdits: Promise<void> = Promise.resolve()

  async startup(context: common.UIAbilityContext): Promise<void> {
    if (this.engine !== undefined) return
    this.context = context
    const storage = new DeviceSyncStorage(context.filesDir)
    const owners = new KomaDeviceSyncOwners(context, storage)
    await owners.recoverBeforeStartup()
    await owners.restoreKeptShelfDetails().catch((): void => {})
    this.owners = owners
    this.storage = storage
    this.engine = new DeviceSyncEngine(storage, owners, new DeviceSyncShardCache(context.cacheDir))
    try {
      this.refresh()
      this.view.ready = true
    } catch (_error) {
      // Optional sync metadata is isolated from normal shelf and Reader startup.
      this.engine = undefined
      this.owners = undefined
      this.view.error = 'sync_local_state_invalid'
      return
    }
    connectDeviceSyncSignals((group: SyncGroup): void => { this.changed(group) })
    connectDeviceSyncSearchHistory((query?: string): void => { this.removeSharedSearch(query) })
    connectDeviceSyncRestore((): void => { this.beginRestore() }, (committed: boolean): void => { this.finishRestore(committed) })
    connectDeviceSyncProgress((progress: ReadingProgress): boolean => this.allowProgress(progress))
    connectDeviceSyncReadingCapture((rows: ReadingProgress[]): SyncReadingCapture[] => this.stagePositions(rows),
      (capture: SyncReadingCapture): boolean => owners.readingAcknowledged(capture),
      (actions: SyncReadingSignal[]): SyncReadingActionCapture[] => this.stageReaderActions(actions),
      (capture: SyncReadingActionCapture): boolean => owners.readingActionAcknowledged(capture))
    connectDeviceSyncOwnerEdits((actions: SyncLibrarySignal[]): void => { this.recordLibrary(actions) },
      (action: SyncBookModeSignal): void => { this.recordBookMode(action) },
      (address: string): void => { this.removeSharedSubscription(address) },
      (): string | undefined => this.engine?.groupScope('shelf') ? this.engine.active()?.space : undefined)
  }

  onForeground(active: boolean): void {
    const wasForeground = this.foreground
    this.foreground = active
    if (!active) {
      this.retainBlockedReading()
      this.cancelTimer()
      this.recoveredOnForeground = false
      if (wasForeground) this.flushReadingInBackground()
      return
    }
    if (this.network === undefined) {
      const network = connection.createNetConnection()
      this.network = network
      network.on('netAvailable', (): void => { this.schedule(2500) })
      network.register((_error: BusinessError): void => {})
    }
    this.recoverForeground()
    this.schedule(0)
  }

  private recoverForeground(): void {
    if (this.recoveredOnForeground || !this.foreground || this.openReviews > 0 || this.engine === undefined ||
      !this.view.enabled || this.view.busy) return
    this.recoveredOnForeground = true
    void this.task((): Promise<void> => this.needed().recoverOnForeground()).catch((): void => {})
  }

  attachPublisher(publish: (groups: SyncGroup[]) => void): void {
    this.owners?.publishWith((groups: SyncGroup[]): void => {
      this.view.revision++
      if (groups.includes('search-history')) this.view.searchHistoryRevision++
      publish(groups)
    })
  }

  private refresh(): void {
    const state = this.engine?.active()
    const configuration = this.engine?.configuration()
    this.view.connected = state !== undefined
    this.view.configured = configuration !== undefined
    this.view.awaitingFirstMerge = configuration !== undefined && state === undefined
    this.view.unresolvedCommit = this.engine?.hasUnresolvedCommit() ?? false
    this.view.selected = this.engine?.selection() ?? this.view.selected
    this.view.automatic = configuration?.automatic ?? false
    this.view.enabled = configuration !== undefined && configuration.enabled !== false
    this.view.requiresExplicitReview = state?.restoreReview === true && syncRequiresExplicitReview(state)
    this.view.needsReview = state?.groups.some((group: SyncGroupState): boolean =>
      group.id !== 'reading' && state.selected.includes(group.id) && (group.deferred?.length ?? 0) > 0) ?? false
    this.view.lastSuccess = state?.lastSuccess ?? 0
    this.view.shelfRemovals = state?.selected.includes('shelf') ? this.owners?.blockedShelfItems() ?? [] : []
    const retained = state?.selected.includes('reading') ? (this.storage?.load().blockedReadings ?? [])
      .filter((item: SyncBlockedReading): boolean => item.capture.space === state.space) : []
    const labelKeys = retained.map((item: SyncBlockedReading): string =>
      syncKey(['position', item.capture.source, item.capture.work, item.capture.chapterId]))
    const labels: Record<string, string> = labelKeys.length === 0 ? {} : this.owners?.readingLabels(labelKeys) ?? {}
    this.view.blockedReadings = retained.map((item: SyncBlockedReading): SyncBlockedReading =>
      ({ title: labels[syncKey(['position', item.capture.source, item.capture.work, item.capture.chapterId])] ?? item.title, capture: item.capture }))
  }

  private needed(): DeviceSyncEngine {
    if (this.engine === undefined) throw new Error('sync_not_ready')
    return this.engine
  }

  private async task<T>(action: () => Promise<T>, publishError: boolean = true, resumeRecovery: boolean = true): Promise<T> {
    if (this.view.busy) throw new Error('sync_already_running')
    let finish: () => void = (): void => {}
    this.taskDone = new Promise<void>((resolve: () => void): void => { finish = resolve })
    const stateGuard = this.engine?.stateGuard()
    this.view.busy = true
    // Draft requests share the task lock, while their errors belong to the form.
    if (publishError) this.view.error = ''
    try {
      const result = await action()
      this.refresh()
      return result
    } catch (error) {
      let current = true
      try { stateGuard?.() } catch (_changed) { current = false }
      if (publishError && current && this.engine?.active()?.enabled !== false) this.view.error = (error as Error).message
      this.refresh()
      throw error as Error
    } finally {
      this.view.busy = false
      this.taskDone = undefined
      finish()
      if (resumeRecovery) this.recoverForeground()
    }
  }

  private async editConnection<T>(action: () => Promise<T>): Promise<T> {
    if (this.editingConnection) throw new Error('sync_already_running')
    this.editingConnection = true
    try {
      const result = await action()
      this.refresh()
      return result
    } finally { this.editingConnection = false }
  }

  test(draft: SyncConnectionDraft, selected: SyncGroup[]): Promise<boolean> {
    return this.editConnection(async (): Promise<boolean> => {
      const recovered = await this.needed().testConnection(draft, selected)
      return recovered
    })
  }

  cancelConnectionTest(): void { this.engine?.cancelConnectionTest() }

  saveConfiguration(draft: SyncConnectionDraft): Promise<void> {
    return this.editConnection(async (): Promise<void> => {
      const previous = this.needed().configuration()?.endpointIdentity
      await this.needed().saveConfiguration(draft)
      if (previous !== this.needed().configuration()?.endpointIdentity) {
        this.view.error = ''
        this.view.manualReadingResult = undefined
      }
    })
  }

  prepareSaved(selected: SyncGroup[]): Promise<SyncPreview> {
    return this.task(async (): Promise<SyncPreview> => {
      const engine = this.needed()
      const permit = engine.beginReview()
      const guard = engine.reviewRequestGuard(permit)
      if (this.view.connected && selected.includes('reading')) await this.recordPositions(guard)
      guard()
      return engine.prepareSaved(selected, permit)
    }, false, false)
  }

  recoverLastSync(): Promise<void> {
    return this.task(async (): Promise<void> => {
      await this.needed().recoverOnForeground()
      this.view.error = ''
    })
  }

  draft(): Promise<SyncConnectionDraft | undefined> {
    return this.needed().connectionDraft()
  }

  prepare(draft: SyncConnectionDraft, selected: SyncGroup[], publishError: boolean = true): Promise<SyncPreview> {
    return this.task(async (): Promise<SyncPreview> => {
      if (selected.includes('reading')) await this.recordPositions()
      return this.needed().prepare(draft, selected)
    }, publishError)
  }

  confirm(token: string, choices: SyncMergeChoice[], publishError: boolean = true): Promise<void> {
    return this.task(async (): Promise<void> => {
      await this.needed().confirm(token, choices)
      this.view.error = ''
    }, publishError).then((): void => { this.schedule(0) })
  }

  discard(token?: string): void {
    this.engine?.discardPreview(token)
  }

  holdAutomaticForReview(): () => void {
    // Keep an explicit review stable without interrupting an in-flight write.
    this.openReviews++
    this.cancelTimer()
    let held = true
    return (): void => {
      if (!held) return
      held = false
      this.openReviews--
      if (this.openReviews !== 0) return
      this.recoverForeground()
      this.schedule(0)
    }
  }

  waitForCurrentTransfer(): Promise<void> {
    // Transfer errors are reported separately from the requested settings action.
    return this.activeSync?.catch((): void => {}) ?? Promise.resolve()
  }

  previewChoices(token: string, choices: SyncMergeChoice[]): SyncPreview { return this.needed().previewChoices(token, choices) }

  sync(allowIdle: boolean = false): Promise<void> {
    if (this.activeSync !== undefined) return this.activeSync
    if (this.view.busy) return Promise.reject(new Error('sync_already_running'))
    const generation = this.changeGeneration
    this.view.transferInFlight = true
    const active = this.task(async (): Promise<void> => {
      await this.recordPositions()
      await this.needed().syncNow(allowIdle && generation === this.syncedGeneration)
      this.syncedGeneration = generation
    }).finally((): void => {
      this.activeSync = undefined
      this.view.transferInFlight = false
    })
    this.activeSync = active
    return active
  }

  syncFromRefresh(): Promise<void> {
    const state = this.view
    // Pulling is an explicit request, even when automatic checks are off.
    if (!state.configured || !state.enabled || state.selected.length === 0 || state.requiresExplicitReview) {
      return Promise.resolve()
    }
    return this.syncManually()
  }

  syncManually(): Promise<void> {
    if (this.manualSync !== undefined) return this.manualSync
    this.manualSync = this.runManualSync().finally((): void => { this.manualSync = undefined })
    return this.manualSync
  }

  private async runManualSync(): Promise<void> {
    this.view.manualInProgress = true
    this.view.manualReadingResult = undefined
    try {
      while (this.activeSync === undefined && this.taskDone !== undefined) await this.taskDone
      await this.sync()
      if (this.changeGeneration !== this.syncedGeneration || this.needed().lastReadingRound === undefined) await this.sync()
      this.updateManualReadingResult()
    } finally {
      this.view.manualInProgress = false
    }
  }

  private updateManualReadingResult(): void {
    const context = this.context
    const engine = this.needed()
    const report = engine.lastReadingRound
    if (context === undefined || report === undefined || !this.view.selected.includes('reading')) return
    const reader = appReaderSessionStore(context.filesDir)
    const space = engine.active()?.space
    const unsettled = reader.pendingDeviceSyncPositions().filter((row: SyncReadingCapture): boolean =>
      row.space === space && this.owners?.readingAcknowledged(row) !== true).length +
      reader.pendingDeviceSyncActions().filter((row: SyncReadingActionCapture): boolean =>
        row.space === space && this.owners?.readingActionAcknowledged(row) !== true).length
    this.view.manualReadingResult = { uploaded: report.uploaded, downloaded: report.downloaded, pending: report.pending + unsettled }
  }

  disconnect(): Promise<void> {
    // Invalidate queued work immediately even if an earlier HTTP response has
    // not arrived. The engine keeps the old intent separate.
    return this.needed().disconnect().then((): void => {
      this.view.error = ''
      this.view.manualReadingResult = undefined
      this.refresh()
    })
  }

  setAutomatic(value: boolean): void {
    this.needed().setAutomatic(value)
    this.refresh()
    if (value) this.schedule(0)
    else this.cancelTimer()
  }

  setEnabled(value: boolean): void {
    this.needed().setEnabled(value)
    this.cancelTimer()
    this.refresh()
    this.recoveredOnForeground = false
    if (value) this.recoverForeground()
    if (value) this.schedule(3000)
  }

  setSelection(selected: SyncGroup[]): void {
    this.needed().setSelection(selected)
    this.cancelTimer()
    this.refresh()
    if (!selected.includes('reading')) this.view.manualReadingResult = undefined
    if (this.activeSync === undefined) this.schedule(0)
    else void this.waitForCurrentTransfer().then((): void => { this.schedule(0) })
  }

  resolveShelfRemoval(item: SyncShelfRemoval, keep: boolean): Promise<void> {
    return this.task(async (): Promise<void> => {
      const engine = this.needed()
      const owners = this.owners
      const scope = engine.groupScope('shelf')
      if (owners === undefined || scope === '' || !owners.blockedShelfItems().some((row: SyncShelfRemoval): boolean => row.id === item.id)) return
      if (!keep) {
        await owners.acceptShelfRemoval(item)
        return
      }
      const label = owners.shelfWorkLabel(item.source, item.work)
      if (label === undefined) return
      if (scope !== engine.groupScope('shelf')) throw new Error('sync_connection_changed')
      engine.recordEdits('shelf', [{ key: syncKey(['book', item.source, item.work]), kind: 'set', value: JSON.stringify(label) }])
      await engine.syncNow()
    })
  }

  beginRestore(): void {
    const active = this.engine?.active()
    const context = this.context
    const owners = this.owners
    if (active !== undefined && context !== undefined && owners !== undefined) {
      const reader = appReaderSessionStore(context.filesDir)
      if (!reader.flush()) throw new Error('reader_progress_save_failed')
      const positions = reader.pendingDeviceSyncPositions().filter((capture: SyncReadingCapture): boolean =>
        capture.space === active.space && !owners.readingAcknowledged(capture))
      const actions = reader.pendingDeviceSyncActions().filter((capture: SyncReadingActionCapture): boolean =>
        capture.space === active.space && !owners.readingActionAcknowledged(capture))
      if (positions.length > 0 || actions.length > 0) {
        this.storage?.update((state: SyncLocalDocument): void => {
          const all = state.readingRestoreCandidates ?? []
          const previous = all.find((candidate: SyncReadingRestoreCandidate): boolean => candidate.space === active.space)
          const saved: SyncReadingRestoreCandidate = {
            space: active.space, positions: (previous?.positions ?? []).filter((old: SyncReadingCapture): boolean =>
              !positions.some((capture: SyncReadingCapture): boolean => deviceSyncCaptureKey(old) === deviceSyncCaptureKey(capture))).concat(positions),
            actions: (previous?.actions ?? []).filter((old: SyncReadingActionCapture): boolean =>
              !actions.some((capture: SyncReadingActionCapture): boolean => capture.id === old.id)).concat(actions),
          }
          state.readingRestoreCandidates = all.filter((candidate: SyncReadingRestoreCandidate): boolean =>
            candidate.space !== active.space).concat(saved)
        })
      }
    }
    this.engine?.beginRestore()
  }

  finishRestore(committed: boolean): void {
    this.engine?.finishRestore(committed)
    this.refresh()
  }

  changed(group: SyncGroup): void {
    if (this.view.selected.includes(group)) {
      this.changeGeneration++
      this.schedule(group === 'reading' ? 1500 : 5000)
    }
  }

  readerClosed(): void {
    this.session = undefined
    if (this.view.selected.includes('reading')) this.schedule(0)
  }

  historyOpened(): void { this.schedule(0) }

  bookshelfOpened(): void {
    if (this.view.selected.includes('shelf') || this.view.selected.includes('reading')) this.schedule(0)
  }

  async waitForReadingSync(request?: SourceReaderSessionRequest): Promise<SyncReadingWorkConflict | undefined> {
    if (!this.foreground || !this.automaticAllowed() || !this.view.selected.includes('reading')) return undefined
    if (this.activeSync !== undefined) {
      const waiting = this.activeSync
      let timer = -1
      try {
        await Promise.race([waiting, new Promise<void>((resolve: () => void): void => {
          timer = setTimeout(resolve, 2000)
        })])
      } catch (_error) {
      } finally {
        if (timer >= 0) clearTimeout(timer)
      }
      if (this.activeSync === waiting) return undefined
    }
    if (this.view.busy || request === undefined) return undefined
    try {
      await this.recordPositions()
      const focused = this.needed().syncReadingWork(request.sourceId, request.mangaId)
      let timer = -1
      const result = await Promise.race([focused, new Promise<SyncReadingWorkResult | undefined>((resolve): void => {
        timer = setTimeout((): void => resolve(undefined), 2000)
      })])
      if (timer >= 0) clearTimeout(timer)
      if (result?.conflict !== undefined) {
        return result.conflict
      }
    } catch (_error) {
      // The saved local position remains usable when the focused read fails.
    }
    return undefined
  }

  async resolveReadingResumeConflict(conflict: SyncReadingWorkConflict, useRemote: boolean): Promise<void> {
    const engine = this.needed()
    const guard = engine.requestGuard()
    if (useRemote) await engine.applyReadingFocus(conflict.facts, guard)
    else engine.mergeReadingFocusFacts(conflict.facts)
    const chosen = useRemote ? conflict.remote : conflict.local
    const edits: DeviceSyncLocalEdit[] = [{ key: syncKey(['recent', conflict.source, conflict.work]),
      kind: 'set', value: JSON.stringify(chosen.recent) }]
    if (chosen.position !== undefined) {
      edits.push({ key: syncKey(['position', conflict.source, conflict.work, chosen.chapter]),
        kind: 'set', value: JSON.stringify(chosen.position) })
    }
    engine.recordEdits('reading', edits)
    this.schedule(0)
  }

  private automaticAllowed(): boolean {
    return this.openReviews === 0 && this.view.configured && this.view.enabled && this.view.automatic &&
      !this.view.requiresExplicitReview && this.view.selected.length > 0
  }

  private cancelTimer(): void {
    if (this.timer >= 0) clearTimeout(this.timer)
    this.timer = -1
    this.deadline = 0
  }

  private flushReadingInBackground(): void {
    const context = this.context
    if (context === undefined || !this.automaticAllowed() || !this.view.selected.includes('reading')) return
    const reader = appReaderSessionStore(context.filesDir)
    if (!reader.flush()) return
    const connection = this.engine?.active()
    const space = connection?.space
    const pending = reader.pendingDeviceSyncPositions().some((row: SyncReadingCapture): boolean =>
      row.space === space && this.owners?.readingAcknowledged(row) !== true) ||
      reader.pendingDeviceSyncActions().some((row: SyncReadingActionCapture): boolean =>
        row.space === space && this.owners?.readingActionAcknowledged(row) !== true) ||
      connection?.groups.some((group: SyncGroupState): boolean => group.id === 'reading' && group.pending.length > 0) === true
    if (this.activeSync === undefined && (this.view.busy || !pending)) return
    try {
      let id = -1
      const finish = (): void => {
        if (id < 0) return
        const request = id
        id = -1
        try { backgroundTaskManager.cancelSuspendDelay(request) } catch (_error) {}
      }
      id = backgroundTaskManager.requestSuspendDelay('Koma', finish).requestId
      void this.sync().catch((): void => {}).finally(finish)
    } catch (_error) {
      // The reader document already owns the outbox if the OS denies extra time.
    }
  }

  private schedule(delay: number, reason: SyncScheduleReason = 'activity'): void {
    if (!this.foreground || !this.automaticAllowed()) return
    if (reason === 'activity') this.idleCheckDelay = IDLE_CHECK_MIN_MS
    const deadline = Date.now() + delay
    if (this.timer >= 0 && this.deadline <= deadline) return
    this.cancelTimer()
    this.deadline = deadline
    this.timer = setTimeout((): void => {
      this.timer = -1
      this.deadline = 0
      if (!this.foreground || !this.automaticAllowed()) return
      if (this.view.busy) {
        this.schedule(1500, reason)
        return
      }
      const lastApplied = this.view.lastSuccess
      void this.sync(true).then((): void => {
        this.failures = 0
        // Local changes and user entry points still pull promptly. An unchanged
        // idle probe should spend less time on the remote directory next time.
        this.idleCheckDelay = reason === 'idle' && this.view.lastSuccess === lastApplied ?
          Math.min(IDLE_CHECK_MAX_MS, this.idleCheckDelay * 2) : IDLE_CHECK_MIN_MS
        this.schedule(this.idleCheckDelay, 'idle')
      }).catch((): void => {
        this.failures++
        this.schedule(Math.min(IDLE_CHECK_MAX_MS, IDLE_CHECK_MIN_MS * this.failures), 'retry')
      })
    }, delay)
  }

  beginReadingChapter(request: SourceReaderSessionRequest): void {
    if (this.session?.comicId === request.comicId && this.session.chapter === request.chapterId &&
      this.session.scope === this.engine?.readingScope()) return
    this.retainBlockedReading()
    this.session = undefined
    const scope = this.engine?.readingScope() ?? ''
    if (scope === '' || !syncReadingIdentity(request.sourceId, request.mangaId, request.chapterId)) return
    const suffix = [request.sourceId, request.mangaId, request.chapterId]
    const positionKey = syncKey(['position'].concat(suffix))
    const recentKey = syncKey(['recent', request.sourceId, request.mangaId])
    const readKey = syncKey(['read'].concat(suffix))
    const engine = this.needed()
    const previous = this.context === undefined ? undefined : appReaderSessionStore(this.context.filesDir).getProgress(request.comicId)
    this.session = { comicId: request.comicId, scope, source: request.sourceId, work: request.mangaId, chapter: request.chapterId,
      title: request.title, sourceName: request.sourceName ?? getInstalledSourcePackage(request.sourceId)?.name ?? request.sourceId,
      chapterTitle: request.chapterTitles?.[request.chapterIds.indexOf(request.chapterId)] ?? '', workUrl: request.mangaUrl,
      positionKey, recentKey, readKey,
      positionSeen: engine.observed('reading', positionKey), recentSeen: engine.observed('reading', recentKey),
      recentCleared: engine.cleared('reading', recentKey),
      readSeen: engine.observed('reading', readKey), lastPage: previous?.chapterId === request.chapterId ? previous.pageIndex : -1,
      lastComplete: previous?.chapterId === request.chapterId && previous.completed }
  }

  openReading(request: SourceReaderSessionRequest): 'ready' | 'missing' {
    this.retainBlockedReading()
    this.session = undefined
    if (this.owners?.receivedReading(request.comicId, request.chapterId) === true &&
      getInstalledSourcePackage(request.sourceId)?.enabled !== true) return 'missing'
    this.beginReadingChapter(request)
    return 'ready'
  }

  receivedReading(comicId: string, chapterId: string): boolean {
    return this.owners?.receivedReading(comicId, chapterId) ?? false
  }

  private allowProgress(progress: ReadingProgress): boolean {
    const session = this.session
    if (session === undefined || this.engine?.readingScope() !== session.scope ||
      session.comicId !== progress.comicId || session.chapter !== progress.chapterId) return true
    return this.engine?.hasUnseenBarrier('reading', session.positionKey, session.positionSeen) !== true &&
      this.engine?.hasUnseenBarrier('reading', session.recentKey, session.recentSeen, session.recentCleared) !== true
  }

  observeReading(progress: ReadingProgress): void {
    const session = this.session
    if (session === undefined || this.engine?.readingScope() !== session.scope || session.comicId !== progress.comicId || session.chapter !== progress.chapterId ||
      syncReadingPosition(progress.pageIndex, progress.totalPages) === undefined ||
      (session.lastPage === progress.pageIndex && session.lastComplete === progress.completed)) return
    session.lastPage = progress.pageIndex
    session.lastComplete = progress.completed
    const reader = this.context === undefined ? undefined : appReaderSessionStore(this.context.filesDir)
    const observedActions = reader?.pendingDeviceSyncActions().filter((action: SyncReadingActionCapture): boolean =>
      action.source === session.source && action.work === session.work && (action.chapterId === '' || action.chapterId === session.chapter))
      .map((action: SyncReadingActionCapture): string => action.id) ?? []
    const pending: PendingReadingSync = { session, progress, id: util.generateRandomUUID(), observedActions }
    if (this.allowProgress(progress)) this.pendingReading.set(session.positionKey, pending)
    else this.blockedReading = pending
  }

  retainBlockedReading(): void {
    const blocked = this.blockedReading
    const active = this.engine?.active()
    if (blocked === undefined || active === undefined || this.engine?.readingScope() !== blocked.session.scope) return
    const session = blocked.session
    const progress = blocked.progress
    const capture: SyncReadingCapture = { id: blocked.id, space: active.space, source: session.source, work: session.work,
      comicId: session.comicId, chapterId: session.chapter, page: progress.pageIndex, total: progress.totalPages,
      complete: progress.completed, date: progress.updatedAt, recent: syncReadingRecent(session.source, session.chapter, progress.updatedAt, session.title,
        session.sourceName, session.chapterTitle, progress.pageIndex, session.workUrl),
      observedActions: blocked.observedActions, positionSeen: session.positionSeen, recentSeen: session.recentSeen,
      recentCleared: session.recentCleared, readSeen: session.readSeen }
    try {
      this.storage?.update((state: SyncLocalDocument): void => {
        const key = deviceSyncCaptureKey(capture)
        state.blockedReadings = (state.blockedReadings ?? []).filter((item: SyncBlockedReading): boolean =>
          deviceSyncCaptureKey(item.capture) !== key).concat({ title: session.title, capture })
      })
      this.blockedReading = undefined
      this.view.blockedReadings = (this.storage?.load().blockedReadings ?? []).filter((item: SyncBlockedReading): boolean =>
        item.capture.space === active.space)
    } catch (_error) { this.view.error = 'sync_local_recovery_required' }
  }

  recoverBlockedReading(item: SyncBlockedReading): Promise<void> {
    return this.task(async (): Promise<void> => {
      const capture = item.capture
      const engine = this.needed()
      const owners = this.owners
      const scope = engine.readingScope()
      if (owners === undefined || scope === '' || capture.space !== engine.active()?.space) throw new Error('sync_connection_changed')
      const guard = engine.requestGuard()
      const position = syncReadingPosition(capture.page, capture.total, capture.date)
      if (position === undefined || !syncReadingIdentity(capture.source, capture.work, capture.chapterId)) {
        throw new Error('sync_unsupported_value')
      }
      const recent = owners.localReadingRecent(capture)
      const positionKey = syncKey(['position', capture.source, capture.work, capture.chapterId])
      const recentKey = syncKey(['recent', capture.source, capture.work])
      await engine.assertReadingUnprotected([positionKey, recentKey])
      guard()
      if (scope !== engine.readingScope()) throw new Error('sync_connection_changed')
      const receiptKey = deviceSyncCaptureKey(capture)
      const version = engine.recordEdits('reading', [
        { key: positionKey, kind: 'set', value: JSON.stringify(position) },
        { key: recentKey, kind: 'set', value: JSON.stringify(recent) },
      ], { key: receiptKey, id: capture.id }) ?? this.storage?.load().readingReceipts?.find(item =>
        item.key === receiptKey && item.id === capture.id)?.version
      await engine.syncNow()
      if (engine.readingWritePending(version)) throw new Error('sync_reading_proof_pending')
      this.storage?.update((state: SyncLocalDocument): void => {
        state.blockedReadings = state.blockedReadings?.filter((row: SyncBlockedReading): boolean => row.capture.id !== capture.id)
      })
    })
  }

  private stagePositions(rows: ReadingProgress[]): SyncReadingCapture[] {
    const active = this.engine?.active()
    const scope = this.engine?.readingScope()
    if (active === undefined || scope === '') return []
    const captures: SyncReadingCapture[] = []
    this.pendingReading.forEach((pending: PendingReadingSync, key: string): void => {
      const session = pending.session
      if (session.scope !== scope) {
        this.pendingReading.delete(key)
        return
      }
      const progress = rows.find((row: ReadingProgress): boolean => row.comicId === session.comicId &&
        row.chapterId === session.chapter && row.pageIndex === pending.progress.pageIndex && row.totalPages === pending.progress.totalPages)
      if (progress === undefined) return
      const capture: SyncReadingCapture = { id: pending.id, space: active.space, source: session.source, work: session.work,
        comicId: session.comicId, chapterId: session.chapter, page: progress.pageIndex, total: progress.totalPages,
        complete: progress.completed, date: progress.updatedAt, recent: syncReadingRecent(session.source, session.chapter, progress.updatedAt, session.title,
          session.sourceName, session.chapterTitle, progress.pageIndex, session.workUrl), observedActions: pending.observedActions,
        positionSeen: session.positionSeen, recentSeen: session.recentSeen, recentCleared: session.recentCleared, readSeen: session.readSeen }
      if (this.owners?.readingAcknowledged(capture) === true) this.pendingReading.delete(key)
      else captures.push(capture)
    })
    return captures
  }

  validateReadingPages(comicId: string, chapterId: string, totalPages: number): boolean {
    if (this.context === undefined || this.owners?.receivedReadingPosition(comicId, chapterId) !== true) return true
    const progress = appReaderSessionStore(this.context.filesDir).getChapterProgress(comicId, chapterId)
    return progress === undefined || progress.totalPages === totalPages
  }

  private async recordPositions(reviewGuard?: () => void): Promise<void> {
    const context = this.context
    const owners = this.owners
    const engine = this.engine
    const scope = engine?.readingScope() ?? ''
    if (context === undefined || owners === undefined || engine === undefined || engine.active()?.enabled === false || scope === '' ||
      (engine.active()?.restoreReview === true && syncRequiresExplicitReview(engine.active()))) return
    const serviceGuard = engine.requestGuard()
    const guard = (): void => {
      serviceGuard()
      reviewGuard?.()
      if (engine.readingScope() !== scope) throw new Error('sync_connection_changed')
    }
    const reader = appReaderSessionStore(context.filesDir)
    if (!(await reader.flushAsync())) throw new Error('sync_local_busy')
    const actions = reader.pendingDeviceSyncActions()
    await this.recordReaderActions(actions, scope, guard)
    guard()
    const pending = reader.pendingDeviceSyncPositions()
    const positionSeenAfterLocalActions = (capture: SyncReadingCapture, key: string, seen: SyncVersion[]): SyncVersion[] => {
      const versions: SyncVersion[] = []
      actions.forEach((action: SyncReadingActionCapture): void => {
        if (action.space === capture.space && capture.observedActions.includes(action.id) &&
          action.edits.some((edit: SyncCapturedReadingEdit): boolean => edit.key === key)) {
          const version = owners.readingActionReceipt(action)?.version
          if (version !== undefined) versions.push(version)
        }
      })
      return mergeSyncVectors(seen, versions)
    }
    for (const capture of pending) {
      if (capture.space !== engine.active()?.space || owners.readingAcknowledged(capture)) continue
      const suffix = [capture.source, capture.work, capture.chapterId]
      const positionKey = syncKey(['position'].concat(suffix))
      const recentKey = syncKey(['recent', capture.source, capture.work])
      const readKey = syncKey(['read'].concat(suffix))
      const position = syncReadingPosition(capture.page, capture.total, capture.date)
      if (position === undefined || !syncReadingIdentity(capture.source, capture.work, capture.chapterId)) continue
      const recent = owners.localReadingRecent(capture)
      const saved = reader.getProgress(capture.comicId)
      const edits: DeviceSyncLocalEdit[] = []
      const positionSeen = positionSeenAfterLocalActions(capture, positionKey, capture.positionSeen)
      const recentSeen = positionSeenAfterLocalActions(capture, recentKey, capture.recentSeen)
      const readSeen = positionSeenAfterLocalActions(capture, readKey, capture.readSeen)
      if (!engine.hasUnseenBarrier('reading', positionKey, positionSeen)) {
        edits.push({ key: positionKey, kind: 'set', value: JSON.stringify(position), observed: positionSeen })
      }
      if (saved?.chapterId === capture.chapterId &&
        !owners.readingHistoryAcknowledged?.(capture) &&
        !engine.hasUnseenBarrier('reading', recentKey, recentSeen, capture.recentCleared)) {
        edits.push({ key: recentKey, kind: 'set', value: JSON.stringify(recent), observed: recentSeen })
      }
      if (capture.complete && !engine.hasUnseenBarrier('reading', readKey, readSeen)) {
        edits.push({ key: readKey, kind: 'set', value: 'true', observed: readSeen })
      }
      const key = deviceSyncCaptureKey(capture)
      const version = await engine.recordReadingEdits(edits, { key, id: capture.id }, guard)
      const session = this.session
      if (version !== undefined && session?.chapter === capture.chapterId && session.comicId === capture.comicId && session.scope === scope) {
        if (edits.some((edit: DeviceSyncLocalEdit): boolean => edit.key === positionKey)) session.positionSeen = mergeSyncVectors(session.positionSeen, [version])
        if (edits.some((edit: DeviceSyncLocalEdit): boolean => edit.key === recentKey)) session.recentSeen = mergeSyncVectors(session.recentSeen, [version])
        if (edits.some((edit: DeviceSyncLocalEdit): boolean => edit.key === readKey)) session.readSeen = mergeSyncVectors(session.readSeen, [version])
      }
    }
  }

  private stageReaderActions(actions: SyncReadingSignal[]): SyncReadingActionCapture[] {
    const engine = this.engine
    const active = engine?.active()
    if (actions.length === 0 || engine === undefined || active === undefined || engine.readingScope() === '') return []
    const captured: SyncReadingActionCapture[] = []
    const identities = this.owners?.readingIdentities()
    for (const action of actions) {
      const identity = action.identity ?? identities?.get(action.comicId)
      if (identity === undefined || !syncReadingIdentity(identity.source, identity.work, action.chapterId || undefined)) continue
      const source = identity.source
      const work = identity.work
      const edits: SyncCapturedReadingEdit[] = []
      const append = (key: string, kind: SyncEditKind, value: string): void => {
        edits.push({ key, kind, value, observed: engine.observed('reading', key) })
      }
      if (action.kind === 'remove-history' || action.kind === 'clear-history') {
        const key = syncKey(['recent', source, work])
        if (engine.observed('reading', key).length > 0) append(key, action.kind === 'clear-history' ? 'clear-observed' : 'delete', '')
      } else if (action.chapterId !== '') {
        const suffix = [source, work, action.chapterId]
        if (action.kind === 'bookmark' || action.kind === 'unbookmark') {
          append(syncKey(['bookmark'].concat(suffix)), action.kind === 'bookmark' ? 'set' : 'delete',
            action.kind === 'bookmark' ? 'true' : '')
        } else if (action.kind === 'read') {
          append(syncKey(['read'].concat(suffix)), 'set', 'true')
        } else {
          append(syncKey(['read'].concat(suffix)), 'reset', 'false')
          append(syncKey(['position'].concat(suffix)), 'reset', '')
        }
      }
      if (edits.length > 0) captured.push({ id: util.generateRandomUUID(), space: active.space, source, work,
        chapterId: action.chapterId, edits })
    }
    return captured
  }

  private async recordReaderActions(actions: SyncReadingActionCapture[], scope: string,
    guard: () => void = (): void => {}): Promise<void> {
    const engine = this.engine
    const owners = this.owners
    if (engine === undefined || owners === undefined) return
    const earlier = new Map<string, SyncVersion[]>()
    for (const capture of actions) {
      if (capture.space !== engine.active()?.space) continue
      if (!owners.readingActionAcknowledged(capture)) {
        guard()
        if (engine.readingScope() !== scope) return
        const edits = capture.edits.map((edit: SyncCapturedReadingEdit): DeviceSyncLocalEdit => {
          let value = edit.value
          let kind = edit.kind
          if (kind === 'reset' && value === '') {
            const known = engine.knownReadingValue(edit.key)
            if (known === undefined) kind = 'delete'
            else {
              const reset = JSON.parse(known) as SyncPositionValue
              reset.page = 0
              value = JSON.stringify(reset)
            }
          }
          return { key: edit.key, kind, value, observed: mergeSyncVectors(edit.observed, earlier.get(edit.key) ?? []) }
        })
        await engine.recordReadingEdits(edits, { key: deviceSyncActionCaptureKey(capture), id: capture.id }, guard)
      }
      const version = owners.readingActionReceipt(capture)?.version
      if (version !== undefined) {
        capture.edits.forEach((edit: SyncCapturedReadingEdit): void => {
          earlier.set(edit.key, mergeSyncVectors(earlier.get(edit.key) ?? [], [version]))
        })
      }
    }
  }

  private recordLibrary(actions: SyncLibrarySignal[]): void {
    const scope = this.engine?.groupScope('shelf') ?? ''
    if (actions.length === 0) return
    this.libraryEdits = this.libraryEdits.then(async (): Promise<void> => {
      if (actions.some((action: SyncLibrarySignal): boolean => action.kind === 'add-book')) {
        await this.owners?.restoreKeptShelfDetails()
      }
      if (scope !== '') await this.applyLibraryActions(actions, scope)
    })
      .catch((error: Error): void => { this.view.error = error.message })
  }

  private async applyLibraryActions(actions: SyncLibrarySignal[], scope: string): Promise<void> {
    const owners = this.owners
    const engine = this.engine
    if (owners === undefined || engine === undefined || scope !== engine.groupScope('shelf')) return
    const output: DeviceSyncLocalEdit[] = []
    const pending = new Set<string>()
    const add = (key: string, kind: SyncEditKind, value: string): void => {
      if (pending.has(key)) return
      pending.add(key)
      output.push({ key, kind, value })
    }
    for (const action of actions) {
      if (action.kind === 'remove-category') {
        const category = owners.sharedCategory(action.category ?? '')
        if (category === undefined) continue
        const key = syncKey(['category', category])
        if (engine.observed('shelf', key).length > 0) add(key, 'delete', '')
        engine.knownGroupKeys('shelf').forEach((item: string): void => {
          const parts = syncKeyParts(item)
          if (parts[0] === 'member' && parts[3] === category) add(item, 'delete', '')
        })
        continue
      }
      const source = action.source ?? ''
      const work = action.work ?? ''
      if (!syncShelfIdentity(source, work)) continue
      if (action.kind === 'remove-book') {
        const key = syncKey(['book', source, work])
        if (engine.observed('shelf', key).length > 0) add(key, 'delete', '')
        engine.knownGroupKeys('shelf').forEach((item: string): void => {
          const parts = syncKeyParts(item)
          if (parts[0] === 'member' && parts[1] === source && parts[2] === work) add(item, 'delete', '')
        })
      } else if (action.kind === 'add-book') {
        const label = owners.shelfWorkLabel(source, work)
        if (label !== undefined) {
          const key = syncKey(['book', source, work])
          add(key, 'set', JSON.stringify(label))
          if (engine.hasShelfMove(key)) {
            const categories = owners.shelfMemberships(source, work)
            engine.knownGroupKeys('shelf').forEach((item: string): void => {
              const parts = syncKeyParts(item)
              if (parts[0] === 'member' && parts[1] === source && parts[2] === work && !categories.includes(parts[3])) {
                add(item, 'delete', '')
              }
            })
          }
        }
      } else {
        const category = owners.sharedCategory(action.category ?? '')
        if (category === undefined) continue
        const key = syncKey(['member', source, work, category])
        if (action.kind === 'remove-member') {
          if (engine.observed('shelf', key).length > 0) add(key, 'delete', '')
        } else if (owners.shelfWorkLabel(source, work) !== undefined) add(key, 'set', 'true')
      }
    }
    if (scope !== engine.groupScope('shelf')) return
    engine.recordEdits('shelf', output)
    this.changed('shelf')
  }

  private recordBookMode(action: SyncBookModeSignal): void {
    const scope = this.engine?.groupScope('reader-settings') ?? ''
    if (scope === '') return
    this.bookModeEdits = this.bookModeEdits.then((): Promise<void> => this.applyBookMode(action, scope))
      .catch((error: Error): void => { this.view.error = error.message })
  }

  private async applyBookMode(action: SyncBookModeSignal, scope: string): Promise<void> {
    const engine = this.engine
    const owners = this.owners
    if (owners === undefined || engine === undefined || scope !== engine.groupScope('reader-settings')) return
    const identity = owners.sourceIdentity(action.comicId)
    if (identity === undefined) return
    const key = syncKey(['book-mode', identity.source, identity.work])
    if (action.mode === undefined || action.direction === undefined) {
      if (engine.observed('reader-settings', key).length > 0) {
        engine.recordEdits('reader-settings', [{ key, kind: 'delete', value: '' }])
      }
    } else {
      const value: SyncReaderMode = { mode: action.mode, direction: action.direction }
      if (scope === engine.groupScope('reader-settings')) {
        engine.recordEdits('reader-settings', [{ key, kind: 'set', value: JSON.stringify(value) }])
      }
    }
    this.changed('reader-settings')
  }

  private removeSharedSubscription(address: string): void {
    const engine = this.engine
    if (engine === undefined || engine.groupScope('source-subscriptions') === '') return
    const key = syncCatalogRecordKey(subscriptionIdentity(address))
    const known = engine.knownGroupKeys('source-subscriptions').filter((item: string): boolean =>
      syncBusinessKey('source-subscriptions', item) === key)
    try {
      engine.recordEdits('source-subscriptions', known.map((item: string): DeviceSyncLocalEdit =>
        ({ key: item, kind: 'delete', value: '' })))
      this.changed('source-subscriptions')
    } catch (error) { this.view.error = (error as Error).message }
  }

  private removeSharedSearch(query?: string): void {
    const engine = this.engine
    if (engine === undefined || engine.groupScope('search-history') === '') return
    const term = query === undefined ? undefined : syncSearchIdentity(query)
    const keys = engine.knownGroupKeys('search-history').filter((key: string): boolean =>
      term === undefined || syncKeyParts(key)[1] === term)
    const kind: SyncEditKind = term === undefined ? 'clear-observed' : 'delete'
    try {
      engine.recordEdits('search-history', keys.map((key: string): DeviceSyncLocalEdit => ({ key, kind, value: '' })))
      this.changed('search-history')
    } catch (error) { this.view.error = (error as Error).message }
  }

}

export const appDeviceSync: DeviceSyncRuntime = new DeviceSyncRuntime()
