import { common } from '@kit.AbilityKit'
import { workScheduler } from '@kit.BackgroundTasksKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { KOMA_BUNDLE_NAME } from '../common/Constants'
import { Chapter, sameComicIdentity } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { hydrateLibraryStoreFromJson,
  serializeLibraryStore, LibraryStorePersistenceService } from './LibraryPersistence'
import { appReaderSessionStore } from './ReaderSessionStore'
import { LibraryUpdatePreferencesStore } from './LibraryUpdatePreferencesStore'
import { LibraryAutomationPreferencesStore } from './LibraryAutomationPreferencesStore'
import { LibraryUpdateComicResult, summarizeResults,
  countLibraryUpdateNewChapters } from './LibraryUpdateService'
import { LibraryUpdateResultStore, setLatestLibraryUpdateSummary } from './LibraryUpdateResultStore'
import { LibraryUpdateStateBridge } from '../state/LibraryUpdateState'
import { enqueueAutomaticallyAddedChapters } from './LibraryAutomaticDownload'
import { mutateLibraryUpdatePreferences } from './LibraryUpdateCoordinator'
import { BackupService } from './BackupService'
import { writeAppTextFile } from './AppFileTextPersistence'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { currentAutomationEpoch } from './AutomationStateEpoch'
import { RemoteServerStore } from './RemoteServerStore'

import { LIBRARY_BACKGROUND_WORK_ID, BACKUP_BACKGROUND_WORK_ID, MAINTENANCE_ABILITY, MAINTENANCE_CONFIG_FILE,
  BACKUP_SNAPSHOT, JOURNAL_DIR, UPDATE_CURSOR, BackgroundServerSnapshot, BackgroundMaintenanceConfiguration,
  BackgroundLibraryJournal, BackgroundUpdateCursor, latestBackgroundObservations } from './BackgroundMaintenanceContract'

// Only the UI process reads/writes XML preferences and the live library. The Extension
// reads an atomic private snapshot and writes immutable results, merged by the live owner.
// Do not bypass this boundary by instantiating the foreground Coordinator in the Extension.
let configurationWrites: Promise<void> = Promise.resolve()

function configPath(context: common.Context): string { return `${context.filesDir}/${MAINTENANCE_CONFIG_FILE}` }

function readConfiguration(context: common.Context): BackgroundMaintenanceConfiguration | undefined {
  return fs.accessSync(configPath(context)) ?
    JSON.parse(fs.readTextSync(configPath(context))) as BackgroundMaintenanceConfiguration : undefined
}

export function synchronizeBackgroundMaintenance(context: common.UIAbilityContext, captureData: boolean = false): Promise<void> {
  const run = configurationWrites.then(async (): Promise<void> => {
    const updates = await new LibraryUpdatePreferencesStore(context).load(true)
    const policy = await new LibraryAutomationPreferencesStore(context).load()
    const backupService = new BackupService(context)
    const backup = await backupService.loadAutomaticPreferences()
    let servers = readConfiguration(context)?.servers ?? {} as BackgroundServerSnapshot
    if (captureData && updates.autoCheckEnabled && !updates.foregroundOnly) {
      const source = new RemoteServerStore(context)
      servers = { komga: await source.loadKomga(), kavita: await source.loadKavita(),
        webdav: await source.loadWebDav(), opds: await source.loadOpds() }
    }
    if (captureData && backup.enabled && backup.backgroundEnabled) {
      const reader = appReaderSessionStore(context.filesDir)
      if (!reader.flush()) throw new Error('backup_progress_commit_failed')
      writeAppTextFile(`${context.filesDir}/${BACKUP_SNAPSHOT}`, await backupService.exportBackgroundTemplate())
    }
    const config: BackgroundMaintenanceConfiguration = { updates, policy, backup, servers }
    writeAppTextFile(configPath(context), JSON.stringify(config))
    const wanted: workScheduler.WorkInfo[] = []
    if (updates.autoCheckEnabled && !updates.foregroundOnly) {
      const work: workScheduler.WorkInfo = {
        workId: LIBRARY_BACKGROUND_WORK_ID, bundleName: KOMA_BUNDLE_NAME, abilityName: MAINTENANCE_ABILITY,
        networkType: policy.updateWifiOnly ? workScheduler.NetworkType.NETWORK_TYPE_WIFI : workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isRepeat: true, repeatCycleTime: updates.intervalHours * 3600000, isPersisted: true, parameters: {},
      }
      if (policy.updateChargingOnly) { work.isCharging = true; work.chargerType = workScheduler.ChargingType.CHARGING_PLUGGED_ANY }
      wanted.push(work)
    }
    if (backup.enabled && backup.backgroundEnabled) {
      wanted.push({ workId: BACKUP_BACKGROUND_WORK_ID, bundleName: KOMA_BUNDLE_NAME, abilityName: MAINTENANCE_ABILITY,
        storageRequest: workScheduler.StorageRequest.STORAGE_LEVEL_OKAY,
        isRepeat: true, repeatCycleTime: backup.intervalHours * 3600000, isPersisted: true, parameters: {} })
    }
    const existing = await workScheduler.obtainAllWorks()
    for (const id of [LIBRARY_BACKGROUND_WORK_ID, BACKUP_BACKGROUND_WORK_ID]) {
      const previous = existing.find((work: workScheduler.WorkInfo): boolean => work.workId === id)
      const next = wanted.find((work: workScheduler.WorkInfo): boolean => work.workId === id)
      if (previous !== undefined && next !== undefined && previous.repeatCycleTime === next.repeatCycleTime &&
        (previous.networkType ?? 0) === (next.networkType ?? 0) && (previous.isCharging === true) === (next.isCharging === true)) continue
      if (previous !== undefined) { previous.parameters = {}; workScheduler.stopWork(previous, true) }
      if (next !== undefined) workScheduler.startWork(next)
    }
    const registered = (await workScheduler.obtainAllWorks()).filter((work: workScheduler.WorkInfo): boolean =>
      work.workId === LIBRARY_BACKGROUND_WORK_ID || work.workId === BACKUP_BACKGROUND_WORK_ID)
    DiagnosticLogger.info('maintenance', 'schedule_synced', 'work_ids=' + registered.map((work: workScheduler.WorkInfo): number => work.workId).join(','))
  })
  configurationWrites = run.catch(() => {})
  return run
}

let applyingResults: Promise<void> | undefined = undefined

export function applyBackgroundLibraryResults(context: common.UIAbilityContext, library: LibraryStore,
  persistence: LibraryStorePersistenceService | undefined): Promise<void> {
  if (applyingResults !== undefined) return applyingResults
  const operation = mergeBackgroundResults(context, library, persistence)
    .finally(() => { applyingResults = undefined })
  applyingResults = operation
  return operation
}

async function mergeBackgroundResults(context: common.UIAbilityContext, library: LibraryStore,
  persistence: LibraryStorePersistenceService | undefined): Promise<void> {
  const directory = `${context.filesDir}/${JOURNAL_DIR}`
  if (!await fs.access(directory) || persistence === undefined) return
  const names = (await fs.listFile(directory)).filter((name: string): boolean => /^\d+-\d+\.json$/.test(name)).sort()
  if (names.length === 0) return
  const journals: BackgroundLibraryJournal[] = []
  for (const name of names) journals.push(JSON.parse(await fs.readText(`${directory}/${name}`)) as BackgroundLibraryJournal)
  await BackupRestoreActivity.runWrite(async (): Promise<void> => {
    let previous: string | undefined = undefined
    const chapterIds: Map<string, Set<string>> = new Map()
    const results: LibraryUpdateComicResult[] = []
    let stale = false
    try {
      // No await between reading current state and committing: user edits cannot interleave a stale rollback.
      const observations = latestBackgroundObservations(journals.filter((journal: BackgroundLibraryJournal): boolean =>
        currentAutomationEpoch(context, journal.generation)))
      for (const observation of observations) {
        const change = observation.change
        if (change !== undefined) {
          const current = library.getComic(change.before.id)
          if (current === undefined || !sameComicIdentity(current, change.before)) continue
          if (current.updatedAt !== change.before.updatedAt) { stale = true; continue }
          if (previous === undefined) previous = serializeLibraryStore(library)
          chapterIds.set(current.id, new Set<string>(current.chapters.map((chapter: Chapter): string => chapter.id)))
          library.upsertComic(change.after)
        }
        results.push(observation.result)
      }
      if (previous !== undefined) persistence.persist()
    } catch (error) {
      if (previous !== undefined) hydrateLibraryStoreFromJson(library, previous)
      throw error as Error
    }
    if (results.length === 0) {
      // Discarded pre-restore work must not postpone checking the restored library.
      for (const name of names) await fs.unlink(`${directory}/${name}`)
      return
    }
    const summary = summarizeResults(Date.now(), results)
    await enqueueAutomaticallyAddedChapters(context, library, appReaderSessionStore(context.filesDir), summary, chapterIds)
    await new LibraryUpdateResultStore(context).save(summary)
    const cursorPath = `${context.filesDir}/${UPDATE_CURSOR}`
    const cursor: BackgroundUpdateCursor | undefined = await fs.access(cursorPath)
      ? JSON.parse(await fs.readText(cursorPath)) as BackgroundUpdateCursor : undefined
    const incomplete = cursor !== undefined && currentAutomationEpoch(context, cursor.generation) && cursor.remaining.length > 0
    // A time-limited background slice is not a completed whole-library check.
    // Keep the due clock unchanged so the existing foreground check can finish it.
    if (!stale && !incomplete) await mutateLibraryUpdatePreferences(() => new LibraryUpdatePreferencesStore(context).saveLastSummary(
      summary.checkedAt, summary.totalCount, countLibraryUpdateNewChapters(summary),
      summary.updatedCount, summary.skippedCount, summary.failedCount, true))
    setLatestLibraryUpdateSummary(summary)
    for (const name of names) await fs.unlink(`${directory}/${name}`)
    LibraryUpdateStateBridge.notifyCompleted()
  })
}
