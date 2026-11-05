import { common } from '@kit.AbilityKit'
import { connection } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { ReadingProgress } from '../model/ComicModels'
import { appReaderSessionStore } from '../model/ReaderSessionStore'
import { MAX_SEARCH_HISTORY_COUNT, SearchHistoryEntry } from '../model/SearchHistoryStore'
import { SourceReaderSessionRequest } from '../model/SourceReaderSession'
import { SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { appSourceRuntimeRegistry, getInstalledSourcePackage, InstalledSourcePackage, listInstalled } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { DeviceSyncEngine, DeviceSyncLocalEdit, SyncMergeChoice, SyncPreview, SyncReadingDecision,
  syncRequiresExplicitReview } from './DeviceSyncEngine'
import { mergeSyncVectors, SyncEditKind, SyncGroup, SyncVersion } from './DeviceSyncFacts'
import { KomaDeviceSyncOwners, SyncShelfRemoval } from './DeviceSyncOwners'
import {
  DeviceSyncStorage, SyncBlockedReading, SyncGroupState, SyncLocalDocument, SyncLocalSnapshot, SyncLocalValue, SyncReadingRestoreCandidate,
} from './DeviceSyncStorage'
import {
  safeSyncSearch, syncChapterBelongsToSource, syncKey, syncKeyParts, syncSearchIdentity, SyncPositionValue,
  SyncRecentValue, SyncSearchValue, SyncSubscription, SyncReaderMode, SyncWorkLabel, SYNC_CATALOG_ID, SYNC_OFFICIAL_CATALOG,
} from './DeviceSyncData'
import { connectDeviceSyncOwnerEdits, connectDeviceSyncProgress, connectDeviceSyncReadingCapture, connectDeviceSyncRestore,
  connectDeviceSyncSignals, deviceSyncActionCaptureKey, deviceSyncCaptureKey, SyncBookModeSignal, SyncCapturedReadingEdit,
  SyncLibrarySignal, SyncReadingActionCapture, SyncReadingCapture, SyncReadingSignal } from './DeviceSyncSignals'
import { SyncConnectionDraft } from './DeviceSyncWebDav'
import { matchesPublicSyncPageHash, matchesPublicSyncPages, syncHasTrustedPackage, syncPageDescriptorHash } from './DeviceSyncPublicSource'
import { subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'

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
  @Trace needsReview: boolean = false
  @Trace requiresExplicitReview: boolean = false
  @Trace lastSuccess: number = 0
  @Trace error: string = ''
  @Trace revision: number = 0
  @Trace subscriptions: SyncLocalValue[] = []
  @Trace shelfRemovals: SyncShelfRemoval[] = []
  @Trace readingDecisions: SyncReadingDecision[] = []
  @Trace blockedReadings: SyncBlockedReading[] = []
}

interface ActiveReadingSync {
  comicId: string
  scope: string
  source: string
  work: string
  chapter: string
  title: string
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
  descriptorHash: string
  observedActions: string[]
}

class DeviceSyncRuntime {
  readonly view: DeviceSyncViewState = new DeviceSyncViewState()
  private context?: common.UIAbilityContext
  private engine?: DeviceSyncEngine
  private storage?: DeviceSyncStorage
  private owners?: KomaDeviceSyncOwners
  private foreground: boolean = false
  private timer: number = -1
  private failures: number = 0
  private network?: connection.NetConnection
  private session?: ActiveReadingSync
  private pendingReading?: PendingReadingSync
  private blockedReading?: PendingReadingSync
  private descriptorUris?: string[]
  private descriptorHash: string = ''
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
    this.engine = new DeviceSyncEngine(storage, owners)
    owners.guardSyncRequests((): (() => void) => this.needed().requestGuard())
    this.view.ready = true
    try {
      this.refresh()
    } catch (_error) {
      // Optional sync metadata is isolated from normal shelf and Reader startup.
      this.engine = undefined
      this.owners = undefined
      this.view.error = 'sync_local_state_invalid'
      return
    }
    connectDeviceSyncSignals((group: SyncGroup): void => { this.changed(group) })
    connectDeviceSyncRestore((): void => { this.beginRestore() }, (committed: boolean): void => { this.finishRestore(committed) })
    connectDeviceSyncProgress((progress: ReadingProgress): boolean => this.allowProgress(progress))
    connectDeviceSyncReadingCapture((rows: ReadingProgress[]): SyncReadingCapture | undefined => this.stagePosition(rows),
      (capture: SyncReadingCapture): boolean => owners.readingAcknowledged(capture),
      (actions: SyncReadingSignal[]): SyncReadingActionCapture[] => this.stageReaderActions(actions),
      (capture: SyncReadingActionCapture): boolean => owners.readingActionAcknowledged(capture))
    connectDeviceSyncOwnerEdits((actions: SyncLibrarySignal[]): void => { this.recordLibrary(actions) },
      (action: SyncBookModeSignal): void => { this.recordBookMode(action) },
      (address: string): void => { this.removeSharedSubscription(address) })
  }

  onForeground(active: boolean): void {
    this.foreground = active
    if (!active) {
      this.retainBlockedReading()
      if (this.timer >= 0) clearTimeout(this.timer)
      this.timer = -1
      return
    }
    if (this.network === undefined) {
      const network = connection.createNetConnection()
      this.network = network
      network.on('netAvailable', (): void => { this.schedule(2500) })
      network.register((_error: BusinessError): void => {})
    }
    this.recoverForeground()
    this.schedule(3000)
  }

  private recoverForeground(): void {
    if (this.recoveredOnForeground || !this.foreground || this.engine === undefined || !this.view.enabled || this.view.busy) return
    this.recoveredOnForeground = true
    void this.task((): Promise<void> => this.needed().recoverOnForeground()).catch((): void => {})
  }

  attachPublisher(publish: (groups: SyncGroup[]) => void): void {
    this.owners?.publishWith((groups: SyncGroup[]): void => {
      this.view.revision++
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
    if (configuration !== undefined) this.view.selected = configuration.selected.slice()
    this.view.automatic = configuration?.automatic ?? false
    this.view.enabled = configuration !== undefined && configuration.enabled !== false
    this.view.requiresExplicitReview = syncRequiresExplicitReview(state)
    this.view.needsReview = this.view.requiresExplicitReview || (state?.groups.some((group: SyncGroupState): boolean =>
      state.selected.includes(group.id) && (group.deferred?.length ?? 0) > 0) ?? false)
    this.view.lastSuccess = state?.lastSuccess ?? 0
    this.view.subscriptions = this.owners?.receivedSubscriptions() ?? []
    this.view.shelfRemovals = state?.selected.includes('shelf') ? this.owners?.blockedShelfItems() ?? [] : []
    const decisions = this.engine?.readingDecisions() ?? []
    const retained = state?.selected.includes('reading') ? (this.storage?.load().blockedReadings ?? [])
      .filter((item: SyncBlockedReading): boolean => item.capture.space === state.space) : []
    const labelKeys = decisions.map((item: SyncReadingDecision): string => item.key).concat(retained.map((item: SyncBlockedReading): string =>
      syncKey(['position', item.capture.source, item.capture.work, item.capture.chapterId])))
    const labels: Record<string, string> = labelKeys.length === 0 ? {} : this.owners?.readingLabels(labelKeys) ?? {}
    this.view.readingDecisions = decisions.map((item: SyncReadingDecision): SyncReadingDecision =>
      ({ key: item.key, title: labels[item.key] ?? item.title, values: item.values }))
    this.view.blockedReadings = retained.map((item: SyncBlockedReading): SyncBlockedReading =>
      ({ title: labels[syncKey(['position', item.capture.source, item.capture.work, item.capture.chapterId])] ?? item.title, capture: item.capture }))
  }

  private needed(): DeviceSyncEngine {
    if (this.engine === undefined) throw new Error('sync_not_ready')
    return this.engine
  }

  private async task<T>(action: () => Promise<T>, publishError: boolean = true, resumeRecovery: boolean = true): Promise<T> {
    if (this.view.busy) throw new Error('sync_already_running')
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
      if (resumeRecovery) this.recoverForeground()
    }
  }

  test(draft: SyncConnectionDraft, selected: SyncGroup[]): Promise<boolean> {
    return this.task(async (): Promise<boolean> => {
      const recovered = await this.needed().testConnection(draft, selected)
      if (recovered) this.view.error = ''
      return recovered
    }, false, false)
  }

  cancelConnectionTest(): void { this.engine?.cancelConnectionTest() }

  saveConfiguration(draft: SyncConnectionDraft, selected: SyncGroup[]): Promise<void> {
    return this.task(async (): Promise<void> => {
      await this.needed().saveConfiguration(draft, selected)
      if (this.needed().active() === undefined) this.view.error = ''
    }, false, false)
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
    }, publishError)
  }

  discard(token?: string): void {
    this.engine?.discardPreview(token)
  }

  previewChoices(token: string, choices: SyncMergeChoice[]): SyncPreview { return this.needed().previewChoices(token, choices) }

  sync(): Promise<void> {
    return this.task(async (): Promise<void> => {
      await this.recordPositions()
      await this.needed().syncNow()
    })
  }

  disconnect(): Promise<void> {
    // Invalidate queued work immediately even if an earlier HTTP response has
    // not arrived. The engine keeps the old intent separate.
    return this.needed().disconnect().then((): void => {
      this.view.error = ''
      this.refresh()
    })
  }

  setAutomatic(value: boolean): void {
    this.needed().setAutomatic(value)
    this.refresh()
    if (value) this.schedule(3000)
  }

  setEnabled(value: boolean): void {
    this.needed().setEnabled(value)
    if (this.timer >= 0) clearTimeout(this.timer)
    this.timer = -1
    this.refresh()
    this.recoveredOnForeground = false
    if (value) this.recoverForeground()
    if (value) this.schedule(3000)
  }

  setSelection(selected: SyncGroup[]): void {
    if (this.view.configured) {
      this.needed().setSelection(selected)
      this.refresh()
    }
    this.view.selected = selected.slice()
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
      const guard = engine.requestGuard()
      const work = await owners.publicSources.work(item.source, item.work, true, guard)
      guard()
      if (work === undefined) throw new Error('sync_public_work_unavailable')
      if (scope !== engine.groupScope('shelf')) throw new Error('sync_connection_changed')
      const label: SyncWorkLabel = { title: work.title, sourceName: work.sourceName, sourceVersion: work.sourceVersion }
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
    if (this.view.selected.includes(group)) this.schedule(15000)
  }

  private schedule(delay: number): void {
    if (!this.foreground || !this.view.connected || !this.view.enabled || !this.view.automatic || this.view.requiresExplicitReview ||
      this.view.selected.length === 0 || this.timer >= 0) return
    this.timer = setTimeout((): void => {
      this.timer = -1
      if (!this.foreground || !this.view.enabled || !this.view.automatic || this.view.requiresExplicitReview) return
      if (this.view.busy) {
        this.schedule(15000)
        return
      }
      void this.sync().then((): void => { this.failures = 0 }).catch((): void => {
        this.failures++
        this.schedule(Math.min(300000, 60000 * this.failures))
      })
    }, delay)
  }

  beginReadingChapter(request: SourceReaderSessionRequest): void {
    this.retainBlockedReading()
    this.descriptorUris = undefined
    const scope = this.engine?.readingScope() ?? ''
    if (scope === '' || !syncHasTrustedPackage(request.sourceId) ||
      !syncChapterBelongsToSource(request.sourceId, request.mangaId, request.chapterId)) return
    const suffix = [request.sourceId, request.mangaId, request.chapterId]
    const positionKey = syncKey(['position'].concat(suffix))
    const recentKey = syncKey(['recent', request.sourceId, request.mangaId])
    const readKey = syncKey(['read'].concat(suffix))
    const engine = this.needed()
    const previous = this.context === undefined ? undefined : appReaderSessionStore(this.context.filesDir).getProgress(request.comicId)
    this.session = { comicId: request.comicId, scope, source: request.sourceId, work: request.mangaId, chapter: request.chapterId,
      title: request.title, positionKey, recentKey, readKey,
      positionSeen: engine.observed('reading', positionKey), recentSeen: engine.observed('reading', recentKey),
      recentCleared: engine.cleared('reading', recentKey),
      readSeen: engine.observed('reading', readKey), lastPage: previous?.chapterId === request.chapterId ? previous.pageIndex : -1,
      lastComplete: previous?.chapterId === request.chapterId && previous.completed }
  }

  async openReading(request: SourceReaderSessionRequest, fromStart: boolean = false):
    Promise<'ready' | 'missing' | 'unverified' | 'changed' | 'unavailable'> {
    this.session = undefined
    const owners = this.owners
    if (owners === undefined || !syncChapterBelongsToSource(request.sourceId, request.mangaId, request.chapterId)) return 'ready'
    const proof = owners.resumeProof(request.comicId, request.chapterId)
    if (!syncHasTrustedPackage(request.sourceId)) {
      if (!owners.receivedReading(request.comicId, request.chapterId)) return 'ready'
      const installed = getInstalledSourcePackage(request.sourceId)
      return installed !== undefined && installed.enabled ? 'unverified' : 'missing'
    }
    if (proof !== '' && !fromStart) {
      const remote = await owners.publicSources.chapter(request.sourceId, request.mangaId, request.chapterId, true)
      if (remote === undefined) return 'unavailable'
      if (remote.pageTable !== proof) return 'changed'
    }
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

  observeReading(progress: ReadingProgress, uris: string[]): void {
    const session = this.session
    if (session === undefined || this.engine?.readingScope() !== session.scope || session.comicId !== progress.comicId || session.chapter !== progress.chapterId ||
      (session.lastPage === progress.pageIndex && session.lastComplete === progress.completed)) return
    session.lastPage = progress.pageIndex
    session.lastComplete = progress.completed
    if (uris !== this.descriptorUris) {
      this.descriptorUris = uris
      this.descriptorHash = syncPageDescriptorHash(session.source, uris)
    }
    const reader = this.context === undefined ? undefined : appReaderSessionStore(this.context.filesDir)
    const observedActions = reader?.pendingDeviceSyncActions().filter((action: SyncReadingActionCapture): boolean =>
      action.source === session.source && action.work === session.work && (action.chapterId === '' || action.chapterId === session.chapter))
      .map((action: SyncReadingActionCapture): string => action.id) ?? []
    const pending: PendingReadingSync = { session, progress, id: util.generateRandomUUID(), descriptorHash: this.descriptorHash, observedActions }
    if (this.allowProgress(progress)) this.pendingReading = pending
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
      complete: progress.completed, date: progress.updatedAt, descriptorHash: blocked.descriptorHash,
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

  chooseReadingDecision(key: string, value: string): Promise<void> {
    return this.task(async (): Promise<void> => {
      const engine = this.needed()
      const version = await engine.chooseReadingDecision(key, value)
      await engine.syncNow()
      if (engine.readingWritePending(version)) throw new Error('sync_reading_proof_pending')
    })
  }

  recoverBlockedReading(item: SyncBlockedReading): Promise<void> {
    return this.task(async (): Promise<void> => {
      const capture = item.capture
      const engine = this.needed()
      const owners = this.owners
      const scope = engine.readingScope()
      if (owners === undefined || scope === '' || capture.space !== engine.active()?.space) throw new Error('sync_connection_changed')
      const guard = engine.requestGuard()
      const work = await owners.publicSources.work(capture.source, capture.work, true, guard)
      const chapter = await owners.publicSources.chapter(capture.source, capture.work, capture.chapterId, true, guard)
      if (scope !== engine.readingScope()) throw new Error('sync_connection_changed')
      if (work === undefined || chapter === undefined || capture.total !== chapter.pages ||
        !matchesPublicSyncPageHash(capture.source, chapter, capture.descriptorHash)) throw new Error('sync_public_work_unavailable')
      const position: SyncPositionValue = { page: capture.page, total: chapter.pages, pageTable: chapter.pageTable }
      const recent: SyncRecentValue = { title: work.title, sourceName: work.sourceName, sourceVersion: work.sourceVersion,
        chapter: capture.chapterId, chapterTitle: chapter.title, date: capture.date }
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

  private stagePosition(rows: ReadingProgress[]): SyncReadingCapture | undefined {
    const pending = this.pendingReading
    const active = this.engine?.active()
    if (pending === undefined || active === undefined || pending.session.scope !== this.engine?.readingScope()) return undefined
    const session = pending.session
    const progress = rows.find((row: ReadingProgress): boolean => row.comicId === session.comicId &&
      row.chapterId === session.chapter && row.pageIndex === pending.progress.pageIndex && row.totalPages === pending.progress.totalPages)
    if (progress === undefined) return undefined
    const capture: SyncReadingCapture = { id: pending.id, space: active.space, source: session.source, work: session.work,
      comicId: session.comicId, chapterId: session.chapter, page: progress.pageIndex, total: progress.totalPages,
      complete: progress.completed, date: progress.updatedAt, descriptorHash: pending.descriptorHash, observedActions: pending.observedActions,
      positionSeen: session.positionSeen, recentSeen: session.recentSeen, recentCleared: session.recentCleared, readSeen: session.readSeen }
    return this.owners?.readingAcknowledged(capture) === true ? undefined : capture
  }

  async validateReadingPages(request: SourceReaderSessionRequest, uris: string[]): Promise<boolean> {
    const owners = this.owners
    if (owners === undefined) return true
    const saved = owners.resumeProof(request.comicId, request.chapterId)
    if (saved === '') return true
    const chapter = await owners.publicSources.chapter(request.sourceId, request.mangaId, request.chapterId, true)
    return chapter !== undefined && chapter.pageTable === saved && matchesPublicSyncPages(request.sourceId, chapter, uris)
  }

  private async recordPositions(reviewGuard?: () => void): Promise<void> {
    const context = this.context
    const owners = this.owners
    const engine = this.engine
    const scope = engine?.readingScope() ?? ''
    if (context === undefined || owners === undefined || engine === undefined || engine.active()?.enabled === false || scope === '' ||
      syncRequiresExplicitReview(engine.active())) return
    const serviceGuard = engine.requestGuard()
    const guard = (): void => { serviceGuard(); reviewGuard?.() }
    const reader = appReaderSessionStore(context.filesDir)
    if (!reader.flush()) throw new Error('sync_local_busy')
    const actions = reader.pendingDeviceSyncActions()
    await this.recordReaderActions(actions, scope, reviewGuard)
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
      const work = await owners.publicSources.work(capture.source, capture.work, true, guard)
      const chapter = await owners.publicSources.chapter(capture.source, capture.work, capture.chapterId, true, guard)
      if (scope !== engine.readingScope()) return
      if (work === undefined || chapter === undefined || chapter.pages !== capture.total ||
        !matchesPublicSyncPageHash(capture.source, chapter, capture.descriptorHash)) continue
      if (!reader.pendingDeviceSyncPositions().some((item: SyncReadingCapture): boolean => item.id === capture.id)) continue
      const suffix = [capture.source, capture.work, capture.chapterId]
      const position: SyncPositionValue = { page: capture.page, total: chapter.pages, pageTable: chapter.pageTable }
      const positionKey = syncKey(['position'].concat(suffix))
      const recentKey = syncKey(['recent', capture.source, capture.work])
      const readKey = syncKey(['read'].concat(suffix))
      const saved = reader.getProgress(capture.comicId)
      const edits: DeviceSyncLocalEdit[] = []
      const positionSeen = positionSeenAfterLocalActions(capture, positionKey, capture.positionSeen)
      const recentSeen = positionSeenAfterLocalActions(capture, recentKey, capture.recentSeen)
      const readSeen = positionSeenAfterLocalActions(capture, readKey, capture.readSeen)
      if (!engine.hasUnseenBarrier('reading', positionKey, positionSeen)) {
        edits.push({ key: positionKey, kind: 'set', value: JSON.stringify(position), observed: positionSeen })
      }
      if (saved?.chapterId === capture.chapterId && !engine.hasUnseenBarrier('reading', recentKey, recentSeen, capture.recentCleared)) {
        const recent: SyncRecentValue = { title: work.title, sourceName: work.sourceName, sourceVersion: work.sourceVersion,
          chapter: capture.chapterId, chapterTitle: chapter.title, date: capture.date }
        edits.push({ key: recentKey, kind: 'set', value: JSON.stringify(recent), observed: recentSeen })
      }
      if (capture.complete && !engine.hasUnseenBarrier('reading', readKey, readSeen)) {
        edits.push({ key: readKey, kind: 'set', value: 'true', observed: readSeen })
      }
      owners.rememberLocalReadingProof(capture.comicId, capture.chapterId, chapter.pageTable)
      const version = engine.recordEdits('reading', edits, { key: deviceSyncCaptureKey(capture), id: capture.id })
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
    if (engine === undefined || active === undefined || engine.readingScope() === '') return []
    const captured: SyncReadingActionCapture[] = []
    for (const action of actions) {
      const separator = action.comicId.indexOf(':')
      if (separator < 1) continue
      const source = action.comicId.substring(0, separator)
      const work = action.comicId.substring(separator + 1)
      const edits: SyncCapturedReadingEdit[] = []
      const append = (key: string, kind: SyncEditKind, value: string): void => {
        edits.push({ key, kind, value, observed: engine.observed('reading', key) })
      }
      if (action.kind === 'remove-history' || action.kind === 'clear-history') {
        const key = syncKey(['recent', source, work])
        if (engine.observed('reading', key).length > 0) append(key, action.kind === 'clear-history' ? 'clear-observed' : 'delete', '')
      } else if (syncChapterBelongsToSource(source, work, action.chapterId) && syncHasTrustedPackage(source)) {
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

  private async recordReaderActions(actions: SyncReadingActionCapture[], scope: string, reviewGuard?: () => void): Promise<void> {
    const engine = this.engine
    const owners = this.owners
    if (engine === undefined || owners === undefined) return
    const serviceGuard = engine.requestGuard()
    const guard = (): void => { serviceGuard(); reviewGuard?.() }
    const earlier = new Map<string, SyncVersion[]>()
    const blocked = new Set<string>()
    for (const capture of actions) {
      if (capture.space !== engine.active()?.space) continue
      if (capture.edits.some((edit: SyncCapturedReadingEdit): boolean => blocked.has(edit.key))) continue
      if (!owners.readingActionAcknowledged(capture)) {
        const position = capture.edits.find((edit: SyncCapturedReadingEdit): boolean => edit.kind === 'reset' && edit.value === '')
        const known = position === undefined ? undefined : engine.knownReadingValue(position.key)
        const verify = capture.chapterId !== '' && (position === undefined ?
          capture.edits.some((edit: SyncCapturedReadingEdit): boolean => edit.observed.length === 0) : known === undefined)
        const chapter = verify ? await owners.publicSources.chapter(capture.source, capture.work, capture.chapterId,
          engine.active()?.enabled !== false, guard) : undefined
        reviewGuard?.()
        if (engine.readingScope() !== scope) return
        if (verify && chapter === undefined) {
          capture.edits.forEach((edit: SyncCapturedReadingEdit): void => { blocked.add(edit.key) })
          continue
        }
        const edits = capture.edits.map((edit: SyncCapturedReadingEdit): DeviceSyncLocalEdit => {
          let value = edit.value
          if (edit === position) {
            const reset = known === undefined ? { page: 0, total: chapter?.pages ?? 0, pageTable: chapter?.pageTable ?? '' } as SyncPositionValue :
              JSON.parse(known) as SyncPositionValue
            reset.page = 0
            value = JSON.stringify(reset)
          }
          return { key: edit.key, kind: edit.kind, value, observed: mergeSyncVectors(edit.observed, earlier.get(edit.key) ?? []) }
        })
        engine.recordEdits('reading', edits, { key: deviceSyncActionCaptureKey(capture), id: capture.id })
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
      if (action.kind === 'remove-book') {
        const key = syncKey(['book', source, work])
        if (engine.observed('shelf', key).length > 0) add(key, 'delete', '')
        engine.knownGroupKeys('shelf').forEach((item: string): void => {
          const parts = syncKeyParts(item)
          if (parts[0] === 'member' && parts[1] === source && parts[2] === work) add(item, 'delete', '')
        })
      } else if (action.kind === 'add-book') {
        const proof = await owners.publicWork(source, work)
        if (proof !== undefined && owners.isLocallyShelved(source, work)) {
          const label: SyncWorkLabel = { title: proof.title, sourceName: proof.sourceName, sourceVersion: proof.sourceVersion }
          add(syncKey(['book', source, work]), 'set', JSON.stringify(label))
        }
      } else {
        const category = owners.sharedCategory(action.category ?? '')
        if (category === undefined) continue
        const key = syncKey(['member', source, work, category])
        if (action.kind === 'remove-member') {
          if (engine.observed('shelf', key).length > 0) add(key, 'delete', '')
        } else if (await owners.publicWork(source, work) !== undefined) add(key, 'set', 'true')
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
      const proof = await owners.publicWork(identity.source, identity.work)
      if (proof !== undefined && scope === engine.groupScope('reader-settings')) {
        engine.recordEdits('reader-settings', [{ key, kind: 'set', value: JSON.stringify(value) }])
      }
    }
    this.changed('reader-settings')
  }

  private removeSharedSubscription(address: string): void {
    const engine = this.engine
    if (engine === undefined || engine.groupScope('source-subscriptions') === '' ||
      subscriptionIdentity(address) !== subscriptionIdentity(SYNC_OFFICIAL_CATALOG)) return
    const key = syncKey(['catalog', SYNC_CATALOG_ID])
    try {
      if (engine.observed('source-subscriptions', key).length > 0) {
        engine.recordEdits('source-subscriptions', [{ key, kind: 'delete', value: '' }])
      }
    } catch (error) {
      this.view.error = (error as Error).message
    }
  }

  publicSearchSourceSet(): string {
    return this.verifyPublicSearchPlan(listInstalled().filter((source: InstalledSourcePackage): boolean => source.enabled)
      .map((source: InstalledSourcePackage): string => source.id))
  }

  verifyPublicSearchPlan(ids: string[]): string {
    if (ids.length === 0 || ids.some((source: string): boolean => !syncHasTrustedPackage(source) ||
      (appSourceRuntimeRegistry.lookup(source).entry?.webSessionOrigins?.length ?? 0) > 0)) return ''
    return ids.slice().sort().join(',')
  }

  availablePublicSearchSources(sourceSet: string): string[] {
    const original = sourceSet.split(',')
    return listInstalled().filter((source: InstalledSourcePackage): boolean => source.enabled &&
      original.includes(source.id) && this.verifyPublicSearchPlan([source.id]) !== '')
      .map((source: InstalledSourcePackage): string => source.id).sort()
  }

  recordPublicSearch(query: string, sources: string): void {
    if (!this.view.connected || !this.view.selected.includes('search-history') || !safeSyncSearch(query)) return
    if (sources === '') return
    const key = syncKey(['query', syncSearchIdentity(query), sources])
    const value: SyncSearchValue = { text: query.trim(), date: Date.now() }
    const json = JSON.stringify(value)
    const owners = this.owners
    if (owners === undefined) return
    void owners.snapshot('search-history', false).then((snapshot: SyncLocalSnapshot): void => {
      owners.saveSearchValues(snapshot.values.filter((row: SyncLocalValue): boolean => row.key !== key).concat({ key, value: json }))
      this.engine?.recordEdits('search-history', [{ key, kind: 'set', value: json }])
      this.changed('search-history')
    }).catch((): void => {})
  }

  mergeSearchHistory(local: SearchHistoryEntry[]): SearchHistoryEntry[] {
    const rows = this.owners?.receivedQueries() ?? []
    if (rows.length === 0) return local
    const remote = rows.map((row: SyncLocalValue): SearchHistoryEntry => {
      const value = JSON.parse(row.value) as SyncSearchValue
      return { query: value.text, updatedAt: Math.min(value.date, Date.now() + 86400000),
        sourceFilter: 'source', syncSourceSet: syncKeyParts(row.key)[2] }
    }).filter((entry: SearchHistoryEntry): boolean => !local.some((row: SearchHistoryEntry): boolean =>
      row.sourceFilter === 'source' && row.librarySource === undefined && row.syncSourceSet === entry.syncSourceSet &&
      syncSearchIdentity(row.query) === syncSearchIdentity(entry.query)))
    return local.concat(remote).sort((a: SearchHistoryEntry, b: SearchHistoryEntry): number => b.updatedAt - a.updatedAt)
      .slice(0, MAX_SEARCH_HISTORY_COUNT)
  }

  removePublicSearch(query: string | undefined, sourceSet: string = ''): void {
    const owners = this.owners
    if (owners === undefined || !this.view.selected.includes('search-history')) return
    const target = query === undefined ? '' : syncSearchIdentity(query)
    if (target !== '' && sourceSet === '') return
    void owners.snapshot('search-history', false).then((snapshot: SyncLocalSnapshot): void => {
      const shouldRemove = (row: SyncLocalValue): boolean => {
        const parts = syncKeyParts(row.key)
        return target === '' || (parts[1] === target && parts[2] === sourceSet)
      }
      const keys = new Set<string>(snapshot.values.concat(owners.receivedQueries()).filter(shouldRemove)
        .map((row: SyncLocalValue): string => row.key))
      const kind: SyncEditKind = target === '' ? 'clear-observed' : 'delete'
      this.engine?.recordEdits('search-history', Array.from(keys).map((key: string): DeviceSyncLocalEdit => ({ key, kind, value: '' })))
      owners.saveSearchValues(snapshot.values.filter((row: SyncLocalValue): boolean => !shouldRemove(row)), Array.from(keys))
      this.changed('search-history')
    }).catch((): void => {})
  }

  async acceptSubscription(candidate: SyncLocalValue): Promise<void> {
    const context = this.context
    if (context === undefined || !this.view.subscriptions.some((item: SyncLocalValue): boolean => item.key === candidate.key)) return
    const value = JSON.parse(candidate.value) as SyncSubscription
    await this.task(async (): Promise<void> => {
      const local = await this.owners?.snapshot('source-subscriptions', false)
      if ((local?.values.length ?? 0) === 0) this.owners?.markAcceptedSharedSubscription()
      await new SourceIndexService(context).acceptDeviceSyncSubscription(value.address, value.label)
      this.changed('source-subscriptions')
    })
  }
}

export const appDeviceSync: DeviceSyncRuntime = new DeviceSyncRuntime()
