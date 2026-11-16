import { writeAppTextFile } from './AppFileTextPersistence'
import { taskpool } from '@kit.ArkTS'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore, LibraryContents, libraryContents } from './LibraryStore'
import { AppFilesLibraryStorePersistenceAdapter, LibraryStorePersistenceService, LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  serializeLibraryStore } from './LibraryPersistence'
import { alignSnapshotChapterCompletion, AppFilesReaderSessionPersistenceAdapter, ReaderSessionDocumentSnapshot,
  ReaderSessionReadingSnapshot, READER_PROGRESS_PERSISTENCE_FILE_NAME, serializeReaderSessionForDevice } from './ReaderSessionStore'
import { MihonImportLabels, MihonImportSummary, importMihonWorks, linkMihonWork, mergeMihonReading,
  mihonSourceMatcher, ResolvedMihonImport, summarizeMihonImport, withMihonTrackerCandidates } from './MihonImportPlanning'
import { MihonImportRecord, readMihonBackup } from './MihonBackupReader'
import { MihonSourceIdentity, mihonPathIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ComicTrackerMapping } from './TrackerModels'

type MihonSourceSummary = SourceRuntimeRegistryInstalledSourceSummary

export interface MihonLinkRequest {
  id: string
  target: Comic | string
  verifiedEdition?: boolean
  identity?: MihonSourceIdentity
}

export interface MihonTransactionRequest {
  bytes?: ArrayBuffer
  links?: MihonLinkRequest[]
  identities: Map<string, MihonSourceIdentity>
  sources: MihonSourceSummary[]
  labels: MihonImportLabels
  trackerMappings: ComicTrackerMapping[]
}

export interface MihonPreparedTransaction {
  library: LibraryContents
  reader: ReaderSessionDocumentSnapshot
  trackerMappings: ComicTrackerMapping[]
  unmatchedChapters: number
  targetComicId?: string
}

@Concurrent
export async function previewMihonBackupTask(bytes: ArrayBuffer): Promise<MihonImportSummary> {
  return summarizeMihonImport(await readMihonBackup(bytes))
}

/** Only the prepared documents and their display data cross back to ArkUI.
 * The UI owner still controls the checkpoint and publishes both files together. */
@Concurrent
export async function prepareMihonTransactionTask(filesDir: string, stagedDir: string,
  request: MihonTransactionRequest): Promise<MihonPreparedTransaction> {
  const library = new InMemoryLibraryStore()
  new LibraryStorePersistenceService(library, new AppFilesLibraryStorePersistenceAdapter(filesDir)).restore()
  const reader = new AppFilesReaderSessionPersistenceAdapter(filesDir).loadSnapshot()
  let entries: ResolvedMihonImport[] = []
  if (request.bytes !== undefined) {
    const backup = await readMihonBackup(request.bytes)
    entries = importMihonWorks(backup, library, request.identities, request.labels)
    const matchSource = mihonSourceMatcher(request.sources, request.identities)
    for (const item of entries) {
      if (item.record.targetComicId) continue
      const source = matchSource(item.record)
      if (source !== undefined) item.record.matchedSourceId = source.sourceId
    }
  } else {
    for (const link of request.links ?? []) {
      const record = library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === link.id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      if (link.verifiedEdition === true && record.targetComicId) continue
      const target = typeof link.target === 'string' ? library.getComic(link.target) : link.target
      if (target === undefined) throw new Error('migration_source_changed')
      entries.push(linkMihonWork(library, record, target, link.verifiedEdition, link.identity, request.labels))
    }
  }
  for (const item of entries) {
    const identity = request.identities.get(item.target.sourceRuntimeId ?? '')
    if (identity !== undefined && identity.sourceIds.includes(item.record.work.sourceId) &&
      item.target.remoteResourceId === mihonPathIdentity(item.record.work.url, identity.work)) {
      item.sameEdition = true
      item.identity = identity
    }
  }
  const reading: ReaderSessionReadingSnapshot = { progress: reader.progress, sourceHistory: reader.sourceHistory,
    remoteHistory: reader.remoteHistory ?? [], chapterStates: reader.chapters, readingSessions: reader.readingSessions ?? [] }
  const unmatchedChapters = mergeMihonReading(reading, entries, request.labels)
  reader.progress = reading.progress
  reader.sourceHistory = reading.sourceHistory
  reader.chapters = reading.chapterStates
  alignSnapshotChapterCompletion(reader)
  writeAppTextFile(stagedDir + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME, serializeLibraryStore(library))
  writeAppTextFile(stagedDir + '/' + READER_PROGRESS_PERSISTENCE_FILE_NAME, serializeReaderSessionForDevice(reader))
  // TaskPool serializes each message. Send the large collections in batches
  // so a single cross-thread result cannot exhaust its message buffer.
  const contents = libraryContents(library)
  for (let offset = 0; offset < contents.comics.length; offset += 16) {
    taskpool.Task.sendData('comics', contents.comics.slice(offset, offset + 16))
  }
  for (let offset = 0; offset < contents.mihonImports.length; offset += 16) {
    taskpool.Task.sendData('imports', contents.mihonImports.slice(offset, offset + 16))
  }
  for (let offset = 0; offset < reader.chapters.length; offset += 512) {
    taskpool.Task.sendData('chapters', reader.chapters.slice(offset, offset + 512))
  }
  contents.comics = []
  contents.mihonImports = []
  reader.chapters = []
  taskpool.Task.sendData('complete')
  return { library: contents, reader, unmatchedChapters,
    trackerMappings: withMihonTrackerCandidates(request.trackerMappings, entries),
    targetComicId: entries.length === 1 ? entries[0].target.id : undefined }
}
