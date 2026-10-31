import { common, appManager } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore } from './LibraryStore'
import { LIBRARY_STORE_PERSISTENCE_FILE_NAME, hydrateLibraryStoreFromJson } from './LibraryPersistence'
import { appReaderSessionStore } from './ReaderSessionStore'
import { READER_PROGRESS_PERSISTENCE_FILE_NAME } from './ReaderSessionStore'
import { OFFLINE_DOWNLOAD_ROOT_DIR_NAME } from './OfflineDownloadStore'
import { OFFLINE_DOWNLOAD_QUEUE_FILE_NAME } from './OfflineDownloadQueueStore'
import { KOMA_BUNDLE_NAME } from '../common/Constants'
import { automationEpoch, currentAutomationEpoch } from './AutomationStateEpoch'
import { protectedSourceChapterIds } from './SourceChapterIdentityGuard'
import { shouldAutomaticallyUpdateComic } from './LibraryAutomationPolicy'
import { automaticUpdateConditionsSatisfied } from './AutomaticUpdateConditions'
import { LibraryUpdateService, summarizeResults } from './LibraryUpdateService'
import { publishLibraryUpdateNotification } from './LibraryUpdateResultStore'
import { writeAutomaticBackupToDirectory } from './BackupAutomaticDirectory'
import { writeAppTextFile } from './AppFileTextPersistence'
import { RemoteServerStore, KomgaServerRecord, KavitaServerRecord, WebDavServerRecord, OpdsServerRecord } from './RemoteServerStore'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { exportInstalledSourcePackages } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { exportLocalLibraryMetadataBackupEntries } from './LocalLibraryMetadataService'
import { LIBRARY_BACKGROUND_WORK_ID, BACKUP_BACKGROUND_WORK_ID, MAINTENANCE_CONFIG_FILE,
  BACKUP_SNAPSHOT, JOURNAL_DIR, UPDATE_CURSOR, BackgroundServerSnapshot, BackgroundMaintenanceConfiguration,
  BackgroundLibraryChange, BackgroundLibraryJournal, BackgroundUpdateCursor,
  BACKUP_BACKGROUND_RESULT, BackgroundBackupResult } from './BackgroundMaintenanceContract'

function readConfiguration(context: common.Context): BackgroundMaintenanceConfiguration | undefined {
  const path = `${context.filesDir}/${MAINTENANCE_CONFIG_FILE}`
  return fs.accessSync(path) ? JSON.parse(fs.readTextSync(path)) as BackgroundMaintenanceConfiguration : undefined
}

class SnapshotRemoteServerStore extends RemoteServerStore {
  private snapshot: BackgroundServerSnapshot
  constructor(context: common.Context, snapshot: BackgroundServerSnapshot) { super(context); this.snapshot = snapshot }
  async loadKomga(): Promise<KomgaServerRecord | undefined> { return this.snapshot.komga }
  async loadKavita(): Promise<KavitaServerRecord | undefined> { return this.snapshot.kavita }
  async loadWebDav(): Promise<WebDavServerRecord | undefined> { return this.snapshot.webdav }
  async loadOpds(): Promise<OpdsServerRecord | undefined> { return this.snapshot.opds }
}

export async function executeBackgroundMaintenance(context: common.Context, workId: number,
  registry: SourceRuntimeRegistry, cancelled: () => boolean): Promise<void> {
  const epoch = automationEpoch(context)
  if (epoch.restoring) return
  const stopped = (): boolean => cancelled() || !currentAutomationEpoch(context, epoch.generation)
  const config = readConfiguration(context)
  if (config === undefined) {
    DiagnosticLogger.warn('maintenance', 'configuration_missing', 'files_dir=' + context.filesDir)
    return
  }
  const processes = await appManager.getRunningProcessInformation()
  if (processes.some((process: appManager.ProcessInformation): boolean => process.processName === KOMA_BUNDLE_NAME &&
    (process.state === appManager.ProcessState.STATE_FOREGROUND || process.state === appManager.ProcessState.STATE_ACTIVE))) {
    DiagnosticLogger.info('maintenance', 'foreground_skip', 'states=' + processes.map((process: appManager.ProcessInformation): number => process.state).join(','))
    return
  }
  if (workId === BACKUP_BACKGROUND_WORK_ID) {
    if (!config.backup.enabled || !config.backup.backgroundEnabled || stopped()) return
    const resultPath = `${context.filesDir}/${BACKUP_BACKGROUND_RESULT}`
    const previous: BackgroundBackupResult = await fs.access(resultPath)
      ? JSON.parse(await fs.readText(resultPath)) as BackgroundBackupResult : { at: 0, lastRunAt: 0, failureCode: '' }
    if (Date.now() - Math.max(config.backup.lastRunAt, previous.lastRunAt) < config.backup.intervalHours * 3600000) return
    const snapshot = `${context.filesDir}/${BACKUP_SNAPSHOT}`
    if (!await fs.access(snapshot)) return
    const document = JSON.parse(await fs.readText(snapshot)) as Record<string, Object>
    // Settings/credentials are captured by their UI owner. Refresh domains that may keep changing
    // after background entry (in-flight updates/downloads) from their atomic persisted documents.
    const libraryPath = `${context.filesDir}/${LIBRARY_STORE_PERSISTENCE_FILE_NAME}`
    const progressPath = `${context.filesDir}/${READER_PROGRESS_PERSISTENCE_FILE_NAME}`
    const queuePath = `${context.filesDir}/${OFFLINE_DOWNLOAD_ROOT_DIR_NAME}/${OFFLINE_DOWNLOAD_QUEUE_FILE_NAME}`
    if (await fs.access(libraryPath)) document['libraryStore'] = await fs.readText(libraryPath)
    if (await fs.access(progressPath)) document['readingProgress'] = await fs.readText(progressPath)
    if (document['downloadQueue'] !== undefined && await fs.access(queuePath)) document['downloadQueue'] = await fs.readText(queuePath)
    document['sourcePackages'] = exportInstalledSourcePackages()
    document['localLibraryMetadata'] = exportLocalLibraryMetadataBackupEntries(document['libraryStore'] as string)
    document['exportedAt'] = Date.now()
    const payload = JSON.stringify(document)
    if (stopped()) return
    // This snapshot is refreshed at background entry after progress commits. It is not an invented fresh export.
    try {
    if (config.backup.directoryUri) {
      await writeAutomaticBackupToDirectory(config.backup.directoryUri, payload, config.backup.retentionCount)
    } else {
      const directory = `${context.filesDir}/backups`
      if (!await fs.access(directory)) await fs.mkdir(directory)
      writeAppTextFile(`${directory}/koma-backup-${Date.now()}.json`, payload)
      const names = (await fs.listFile(directory)).filter((name: string): boolean => /^koma-backup-\d+\.json$/.test(name)).sort().reverse()
      for (const name of names.slice(config.backup.retentionCount)) await fs.unlink(`${directory}/${name}`)
    }
    const result: BackgroundBackupResult = { at: Date.now(), lastRunAt: Date.now(), failureCode: '' }
    writeAppTextFile(resultPath, JSON.stringify(result))
    } catch (error) {
      const failed: BackgroundBackupResult = { at: Date.now(), lastRunAt: previous.lastRunAt, failureCode: 'backup_auto_export_failed' }
      writeAppTextFile(resultPath, JSON.stringify(failed))
      throw error as Error
    }
    DiagnosticLogger.info('maintenance', 'background_backup_saved', '[Maintenance] background_backup_saved')
    return
  }
  if (workId !== LIBRARY_BACKGROUND_WORK_ID || !config.updates.autoCheckEnabled || config.updates.foregroundOnly ||
    !automaticUpdateConditionsSatisfied(config.policy) || stopped()) return
  const libraryPath = `${context.filesDir}/${LIBRARY_STORE_PERSISTENCE_FILE_NAME}`
  if (!await fs.access(libraryPath)) return
  const library = new InMemoryLibraryStore()
  hydrateLibraryStoreFromJson(library, await fs.readText(libraryPath))
  const reader = appReaderSessionStore(context.filesDir)
  const service = new LibraryUpdateService(library, registry, undefined, new SnapshotRemoteServerStore(context, config.servers),
    (comic: Comic): Set<string> | undefined => protectedSourceChapterIds(comic, context.filesDir, reader),
    (comic: Comic): boolean => shouldAutomaticallyUpdateComic(comic, reader, config.policy))
  const cursorPath = `${context.filesDir}/${UPDATE_CURSOR}`
  const savedCursor: BackgroundUpdateCursor | undefined = await fs.access(cursorPath)
    ? JSON.parse(await fs.readText(cursorPath)) as BackgroundUpdateCursor : undefined
  const cursor: BackgroundUpdateCursor = savedCursor?.generation === epoch.generation ? savedCursor :
    { generation: epoch.generation, remaining: library.listComics().map((comic: Comic): string => comic.id), results: [], startedAt: Date.now() }
  const directory = `${context.filesDir}/${JOURNAL_DIR}`
  if (!await fs.access(directory)) await fs.mkdir(directory)
  const deadline = Date.now() + 105000
  while (cursor.remaining.length > 0 && !stopped() && Date.now() < deadline) {
    const id = cursor.remaining[0]
    const comic = library.getComic(id)
    if (comic !== undefined) {
      const before = JSON.parse(JSON.stringify(comic)) as Comic
      const result = await service.checkComic(comic)
      if (stopped()) return
      const summary = summarizeResults(Date.now(), [result])
      const after = library.getComic(id)
      const changes: BackgroundLibraryChange[] = after !== undefined && (result.status === 'updated' || result.metadataChanged)
        ? [{ before, after }] : []
      const journal: BackgroundLibraryJournal = { generation: epoch.generation, summary, changes }
      writeAppTextFile(`${directory}/${cursor.startedAt}-${cursor.results.length}.json`, JSON.stringify(journal))
      cursor.results.push(result)
    }
    cursor.remaining.shift()
    writeAppTextFile(cursorPath, JSON.stringify(cursor))
  }
  if (cursor.remaining.length === 0) {
    await publishLibraryUpdateNotification(summarizeResults(Date.now(), cursor.results))
    await fs.unlink(cursorPath)
  }
}
