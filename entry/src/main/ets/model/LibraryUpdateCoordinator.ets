import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { protectedSourceChapterIds } from './SourceChapterIdentityGuard'
import { appReaderSessionStore } from './ReaderSessionStore'
import { Comic } from './ComicModels'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { LibraryStore } from './LibraryStore'
import { LibraryStorePersistenceService } from './LibraryPersistence'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { RemoteServerStore } from './RemoteServerStore'
import { LibraryUpdateService, LibraryUpdateSummary, countLibraryUpdateNewChapters } from './LibraryUpdateService'
import {
  LibraryUpdatePreferences,
  LibraryUpdatePreferencesStore,
  getLibraryUpdateNextDueAt,
  isLibraryUpdateDue,
} from './LibraryUpdatePreferencesStore'
import {
  LibraryUpdateResultStore,
  LibraryUpdateNotificationDispatchResult,
  clearLatestLibraryUpdateSummary,
  completedLibraryUpdateJobSnapshot,
  createLibraryUpdateJobSnapshot,
  publishLibraryUpdateFailureNotification,
  publishLibraryUpdateNotification,
  setLatestLibraryUpdateJobSnapshot,
  setLatestLibraryUpdateSummary,
} from './LibraryUpdateResultStore'
import { LibraryUpdateStateBridge } from '../state/LibraryUpdateState'
import { connectAppForegroundState } from '../state/AppForegroundState'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { shouldAutomaticallyUpdateComic } from './LibraryAutomationPolicy'
import { libraryChapterIdSnapshot, enqueueAutomaticallyAddedChapters } from './LibraryAutomaticDownload'
import { LibraryAutomationPreferences } from './LibraryAutomationPolicy'
import { automaticUpdateConditionsSatisfied } from './AutomaticUpdateConditions'

export interface LibraryUpdateCheckRequest {
  context: common.UIAbilityContext
  libraryStore: LibraryStore
  sourceRegistry: SourceRuntimeRegistry
  libraryPersistenceService?: LibraryStorePersistenceService
  reason: 'manual' | 'due'
  requireForeground?: boolean
}

export interface LibraryUpdateCheckResult {
  status: 'completed' | 'failed' | 'not-due' | 'unavailable'
  summary?: LibraryUpdateSummary
  preferences?: LibraryUpdatePreferences
  notification?: LibraryUpdateNotificationDispatchResult
  persistenceFailed: boolean
}

// One execution owner on the application's main thread. No secondary library or process is created.
let inFlight: Promise<LibraryUpdateCheckResult> | undefined = undefined
let inFlightReason: 'manual' | 'due' | undefined = undefined
let preferenceMutation: Promise<void> = Promise.resolve()

// Settings edits and completion writes share this short read-modify-write queue, not the network job.
export function mutateLibraryUpdatePreferences(
  operation: () => Promise<LibraryUpdatePreferences>,
): Promise<LibraryUpdatePreferences> {
  const result = preferenceMutation.then(() => BackupRestoreActivity.runWrite(operation))
  preferenceMutation = result.then(() => {}, () => {})
  return result
}

export function requestLibraryUpdateCheck(request: LibraryUpdateCheckRequest): Promise<LibraryUpdateCheckResult> {
  const active = inFlight
  const activeReason = inFlightReason
  if (active !== undefined) {
    DiagnosticLogger.info('library_update', 'admission', '[LibraryUpdateCoordinator] step=admission reason=' + request.reason + ' status=joined')
    if (request.reason === 'manual') {
      return active.then((result: LibraryUpdateCheckResult): Promise<LibraryUpdateCheckResult> | LibraryUpdateCheckResult => {
        // Automatic checks may exclude categories or books outside their release window.
        // The adopted manual action still checks the whole library after that job finishes.
        return activeReason === 'due' || result.status === 'not-due'
          ? requestLibraryUpdateCheck(request) : result
      })
    }
    return active
  }
  inFlightReason = request.reason
  let ran = false
  // Defer work until after the slot is reserved, including preference reads and running-state writes.
  const operation = Promise.resolve().then(() =>
    BackupRestoreActivity.runWrite(() => runLibraryUpdateCheck(request)))
    .then((result: LibraryUpdateCheckResult): LibraryUpdateCheckResult => {
      ran = result.status === 'completed' || result.status === 'failed'
      DiagnosticLogger.info('library_update', 'step', '[LibraryUpdateCoordinator] step=' + (ran ? 'check_done' : 'admission') +
        ' reason=' + request.reason + ' status=' + result.status)
      return result
    })
  inFlight = operation.finally(() => {
    inFlight = undefined
    inFlightReason = undefined
    LibraryUpdateStateBridge.setBusy(false)
    if (ran) {
      LibraryUpdateStateBridge.notifyCompleted()
    }
  })
  return inFlight
}

async function runLibraryUpdateCheck(request: LibraryUpdateCheckRequest): Promise<LibraryUpdateCheckResult> {
  const result: LibraryUpdateCheckResult = { status: 'unavailable', persistenceFailed: false }
  if (request.context === undefined || request.libraryStore === undefined || request.sourceRegistry === undefined) {
    return result
  }
  const preferencesStore = new LibraryUpdatePreferencesStore(request.context)
  const resultStore = new LibraryUpdateResultStore(request.context)
  try {
    // Read under the same short queue so an edit cannot interleave its multi-key preference writes.
    result.preferences = await mutateLibraryUpdatePreferences(() => preferencesStore.load(true))
  } catch (_error) {
    result.persistenceFailed = true
    DiagnosticLogger.warn('library_update_coordinator', 'preferences_load_failed', '[LibraryUpdateCoordinator] step=preferences_load_failed')
    if (request.reason === 'due') {
      return result
    }
    // Manual checking is still useful, but unknown preferences must never be replaced with defaults.
  }
  if (request.reason === 'due' &&
    (result.preferences === undefined || !isLibraryUpdateDue(result.preferences, Date.now()))) {
    result.status = 'not-due'
    return result
  }
  // Lifecycle-triggered checks revalidate after queued IO. Settings-triggered due/manual checks
  // retain their explicit user action semantics. This is an admission gate, not background execution.
  if (request.reason === 'due' && request.requireForeground && !connectAppForegroundState().active) {
    return result
  }
  let policy: LibraryAutomationPreferences | undefined = undefined
  try { policy = await new LibraryAutomationPreferencesStore(request.context).load() }
  catch (error) {
    DiagnosticLogger.exception('library_update', 'automation_policy_read_failed', error as Error)
    if (request.reason === 'due') { result.persistenceFailed = true; return result }
  }
  if (request.reason === 'due' && policy !== undefined && !automaticUpdateConditionsSatisfied(policy)) return result

  LibraryUpdateStateBridge.setBusy(true)
  const startedAt = Date.now()
  DiagnosticLogger.info('library_update', 'check_started', '[LibraryUpdateCoordinator] step=check_started reason=' + request.reason)
  const running = createLibraryUpdateJobSnapshot('running', startedAt, undefined, undefined, undefined, startedAt)
  setLatestLibraryUpdateJobSnapshot(running)
  try {
    // Await this write so it cannot land after the completed snapshot.
    await resultStore.saveJobSnapshot(running)
  } catch (_error) {
    result.persistenceFailed = true
    DiagnosticLogger.warn('library_update_coordinator', 'running_save_failed', '[LibraryUpdateCoordinator] step=running_save_failed')
  }

  let summary: LibraryUpdateSummary
  const reader = appReaderSessionStore(request.context.filesDir)
  const previousChapterIds = libraryChapterIdSnapshot(request.libraryStore)
  try {
    const automaticPolicy = policy
    const service = new LibraryUpdateService(request.libraryStore, request.sourceRegistry,
      request.libraryPersistenceService, new RemoteServerStore(request.context),
      (comic: Comic): Set<string> | undefined => protectedSourceChapterIds(
        comic, request.context.filesDir, reader),
      request.reason === 'due' && automaticPolicy !== undefined ?
        (comic: Comic): boolean => shouldAutomaticallyUpdateComic(comic, reader, automaticPolicy) : undefined)
    summary = await service.checkLibraryUpdates()
  } catch (_error) {
    // Only a service exception reaches this branch; persistence and notification failures are separate.
    result.status = 'failed'
    const checkedAt = Date.now()
    const failureCode = 'check_failed'
    clearLatestLibraryUpdateSummary()
    if (result.preferences !== undefined) {
      try {
        result.preferences = await mutateLibraryUpdatePreferences(() =>
          preferencesStore.saveFailedCheck(checkedAt, failureCode, true))
      } catch (_saveError) {
        result.persistenceFailed = true
        result.preferences = undefined
        DiagnosticLogger.warn('library_update_coordinator', 'failure_preferences_save_failed', '[LibraryUpdateCoordinator] step=failure_preferences_save_failed')
      }
    }
    const nextDueAt = result.preferences === undefined ? undefined : getLibraryUpdateNextDueAt(result.preferences)
    const state = nextDueAt !== undefined && nextDueAt > checkedAt ? 'backed-off' : 'failed'
    const snapshot = createLibraryUpdateJobSnapshot(state, checkedAt, undefined, failureCode, nextDueAt, startedAt)
    setLatestLibraryUpdateJobSnapshot(snapshot)
    try {
      await resultStore.saveJobSnapshot(snapshot)
    } catch (_saveError) {
      result.persistenceFailed = true
      DiagnosticLogger.warn('library_update_coordinator', 'failure_result_save_failed', '[LibraryUpdateCoordinator] step=failure_result_save_failed')
    }
    try {
      result.notification = await publishLibraryUpdateFailureNotification(checkedAt, failureCode)
    } catch (_notificationError) {
      result.notification = { delivered: false, code: 'publish_failed' }
    }
    return result
  }

  result.status = 'completed'
  result.summary = summary
  try {
    // Persisted library changes come first. Queue only received new chapter IDs, never a count or list position.
    await enqueueAutomaticallyAddedChapters(request.context, request.libraryStore, reader, summary, previousChapterIds)
  } catch (error) {
    DiagnosticLogger.exception('library_update', 'automatic_download_enqueue_failed', error as Error)
  }
  setLatestLibraryUpdateSummary(summary)
  if (result.preferences !== undefined) {
    try {
      result.preferences = await mutateLibraryUpdatePreferences(() => preferencesStore.saveLastSummary(
        summary.checkedAt, summary.totalCount, countLibraryUpdateNewChapters(summary),
        summary.updatedCount, summary.skippedCount, summary.failedCount, true,
      ))
    } catch (_error) {
      result.persistenceFailed = true
      result.preferences = undefined
      DiagnosticLogger.warn('library_update_coordinator', 'summary_preferences_save_failed', '[LibraryUpdateCoordinator] step=summary_preferences_save_failed')
    }
  }
  const nextDueAt = result.preferences === undefined ? undefined : getLibraryUpdateNextDueAt(result.preferences)
  const snapshot = completedLibraryUpdateJobSnapshot(summary, startedAt, nextDueAt)
  setLatestLibraryUpdateJobSnapshot(snapshot)
  try {
    await resultStore.save(summary, snapshot)
  } catch (_error) {
    result.persistenceFailed = true
    DiagnosticLogger.warn('library_update_coordinator', 'summary_result_save_failed', '[LibraryUpdateCoordinator] step=summary_result_save_failed')
  }
  try {
    result.notification = await publishLibraryUpdateNotification(summary)
  } catch (_error) {
    result.notification = { delivered: false, code: 'publish_failed' }
  }
  return result
}
