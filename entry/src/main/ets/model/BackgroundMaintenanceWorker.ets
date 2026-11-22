import { common, appManager } from '@kit.AbilityKit'
import { exportComicCovers } from './ComicPersonalization'
import { fileIo as fs } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore } from './LibraryStore'
import { hydrateLibraryStoreFromJson, prepareLiveLibraryStorage, readLiveLibrarySnapshot } from './LibraryPersistence'
import { appReaderSessionStore, prepareLiveReaderStorage, readLiveReaderSnapshot } from './ReaderSessionStore'
import { offlineDownloadQueuePath, prepareOfflineQueueDatabase, readOfflineQueueDatabaseSnapshot, readableOfflineDownloadQueuePath,
  usesOfflineQueueDatabase } from './OfflineDownloadQueueStore'
import { KOMA_BUNDLE_NAME } from '../common/Constants'
import { automationEpoch, currentAutomationEpoch } from './AutomationStateEpoch'
import { protectedSourceChapterIds } from './SourceChapterIdentityGuard'
import { shouldAutomaticallyUpdateComic } from './LibraryAutomationPolicy'
import { automaticUpdateConditionsSatisfied } from './AutomaticUpdateConditions'
import { LibraryUpdateService, summarizeResults } from './LibraryUpdateService'
import { publishLibraryUpdateNotification } from './LibraryUpdateResultStore'
import { writeAutomaticBackupToDirectory } from './BackupAutomaticDirectory'
import { BACKUP_FILE_EXTENSION, BACKUP_FILE_HEADER_BYTES, encodeBackupFile, publishBackupFile,
  readBackupBytes, readBackupFileHeader } from './BackupFileFormat'
import { writeAppTextFile } from './AppFileTextPersistence'
import { ensureKomaBackgroundContentStorageBase, hasKomaPublicContentStorage } from './KomaContentStorage'
import { migrateLocalBackups } from './BackupLocalStorage'
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
  const contentBase = await ensureKomaBackgroundContentStorageBase(context)
  const processes = await appManager.getRunningProcessInformation()
  if (processes.some((process: appManager.ProcessInformation): boolean => process.processName === KOMA_BUNDLE_NAME &&
    (process.state === appManager.ProcessState.STATE_FOREGROUND || process.state === appManager.ProcessState.STATE_ACTIVE))) {
    DiagnosticLogger.info('maintenance', 'foreground_skip', 'states=' + processes.map((process: appManager.ProcessInformation): number => process.state).join(','))
    return
  }
  // A maintenance launch only reads the selected storage. The UI owns migration and recovery.
  await prepareLiveLibraryStorage(context, false)
  await prepareLiveReaderStorage(context, false)
  await prepareOfflineQueueDatabase(context)
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
    const librarySnapshot = readLiveLibrarySnapshot(context.filesDir)
    if (librarySnapshot !== undefined) document['libraryStore'] = librarySnapshot
    const readingSnapshot = readLiveReaderSnapshot(context.filesDir)
    if (readingSnapshot !== undefined) document['readingProgress'] = readingSnapshot
    if (document['downloadQueue'] !== undefined) {
      const relativeQueue = offlineDownloadQueuePath(contentBase, context.filesDir).substring(context.filesDir.length + 1)
      if (usesOfflineQueueDatabase(context.filesDir, relativeQueue)) {
        const queue = readOfflineQueueDatabaseSnapshot(context.filesDir, relativeQueue)
        if (queue !== undefined) document['downloadQueue'] = queue
      } else {
        const queuePath = readableOfflineDownloadQueuePath(contentBase, context.filesDir)
        if (await fs.access(queuePath)) document['downloadQueue'] = await fs.readText(queuePath)
      }
    }
    document['sourcePackages'] = exportInstalledSourcePackages()
    document['customCovers'] = await exportComicCovers(context, document['libraryStore'] as string)
    document['enhancedCovers'] = await exportComicCovers(context, document['libraryStore'] as string, true)
    document['localLibraryMetadata'] = exportLocalLibraryMetadataBackupEntries(document['libraryStore'] as string)
    const exportedAt = Date.now()
    document['exportedAt'] = exportedAt
    if (stopped()) return
    // This snapshot is refreshed at background entry after progress commits. It is not an invented fresh export.
    try {
      const payload = await encodeBackupFile(JSON.stringify(document), { exportedAt, encrypted: false })
      if (stopped()) return
      if (config.backup.directoryUri) {
        await writeAutomaticBackupToDirectory(config.backup.directoryUri, payload, config.backup.retentionCount, exportedAt)
      } else {
        if (contentBase === context.filesDir && hasKomaPublicContentStorage(context)) {
          throw new Error('backup_public_storage_unavailable')
        }
        const directory = await migrateLocalBackups(context.filesDir, contentBase)
        if (!await fs.access(directory)) await fs.mkdir(directory)
        await publishBackupFile(`${directory}/koma-backup-${exportedAt}${BACKUP_FILE_EXTENSION}`, payload)
        try {
          const names = (await fs.listFile(directory)).filter((name: string): boolean =>
            /^koma-backup-\d+\.(json|komabk)$/.test(name)).sort().reverse()
          const automatic: string[] = []
          for (const name of names) {
            const path = `${directory}/${name}`
            if (name.endsWith('.json') ||
              readBackupFileHeader(await readBackupBytes(path, BACKUP_FILE_HEADER_BYTES))?.encrypted === false) {
              automatic.push(path)
            }
          }
          for (const path of automatic.slice(config.backup.retentionCount)) await fs.unlink(path)
        } catch (error) {
          DiagnosticLogger.exception('maintenance', 'background_backup_retention_failed', error as Error)
        }
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
  const librarySnapshot = readLiveLibrarySnapshot(context.filesDir)
  if (librarySnapshot === undefined) return
  const library = new InMemoryLibraryStore()
  hydrateLibraryStoreFromJson(library, librarySnapshot)
  const reader = appReaderSessionStore(context.filesDir)
  const service = new LibraryUpdateService(library, registry, undefined, new SnapshotRemoteServerStore(context, config.servers),
    (comic: Comic): Set<string> | undefined => protectedSourceChapterIds(comic, contentBase, reader,
      registry.lookup(comic.sourceRuntimeId ?? '').entry?.websitePolicy?.chapterIdentity, context.filesDir),
    (comic: Comic): boolean => shouldAutomaticallyUpdateComic(comic, reader, config.policy),
    config.policy.refreshWorkInfo === true)
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
