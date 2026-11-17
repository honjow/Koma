import { writeAppTextFile } from './AppFileTextPersistence'
import { taskpool } from '@kit.ArkTS'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore, LibraryContents, libraryContents } from './LibraryStore'
import { AppFilesLibraryStorePersistenceAdapter, LibraryStorePersistenceService, LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  serializeLibraryStore, updatedSourceMangaDetail } from './LibraryPersistence'
import { alignSnapshotChapterCompletion, AppFilesReaderSessionPersistenceAdapter, ChapterReadingState,
  ReaderSessionDocumentSnapshot, ReaderSessionReadingSnapshot, READER_PROGRESS_PERSISTENCE_FILE_NAME,
  serializeReaderSessionForDevice } from './ReaderSessionStore'
import { MihonImportLabels, MihonImportSummary, importMihonWorks, linkMihonWork, mergeMihonReading, mihonDeclaredWork,
  mihonSourceMatcher, ResolvedMihonImport, summarizeMihonImport, withMihonTrackerCandidates } from './MihonImportPlanning'
import { MihonImportRecord, readMihonBackup } from './MihonBackupReader'
import { MihonSourceIdentity, mihonPathIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ComicTrackerMapping } from './TrackerModels'
import { SourceManga } from './SourceModels'
import { comicWithCompleteSourceCatalog } from './SourceLibraryComic'
import { MangaChapterItem, MangaDetail } from './MangaDetailModels'
import { SourceChapterIdentityPolicy } from '../sourceRuntime/SourceWebsitePolicy'
import { reconcileSourceChapterIdentity } from './SourceChapterIdentity'
import { finishAutomationRestoreInDirectory } from './AutomationStateEpoch'

type MihonSourceSummary = SourceRuntimeRegistryInstalledSourceSummary

export interface MihonLinkRequest {
  id: string
  target: Comic | string
  verifiedEdition?: boolean
  identity?: MihonSourceIdentity
}

export interface MihonCatalogLink {
  id: string
  detail: MangaDetail
  chapters: MangaChapterItem[]
  excludedChapterIds: string[]
  settingsFingerprint: string
  identity?: MihonSourceIdentity
  chapterPolicy?: SourceChapterIdentityPolicy
}

export interface MihonSourceMatch {
  id: string
  sourceId: string
  work?: SourceManga
}

export interface MihonTransactionRequest {
  bytes?: ArrayBuffer
  links?: MihonLinkRequest[]
  catalogLinkJson?: string
  sourceMatches?: MihonSourceMatch[]
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
  linkedComicIds?: string[]
  removedComicIds?: string[]
}

@Concurrent
export async function previewMihonBackupTask(bytes: ArrayBuffer): Promise<MihonImportSummary> {
  return summarizeMihonImport(await readMihonBackup(bytes))
}

@Concurrent
export function finishMihonAutomationRestoreTask(filesDir: string): void {
  finishAutomationRestoreInDirectory(filesDir)
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
      if (source !== undefined) {
        item.record.matchedSourceId = source.sourceId
        item.record.linkedWork = mihonDeclaredWork(item.record, source.sourceId, request.identities.get(source.sourceId)) ??
          item.record.linkedWork
      }
    }
  } else {
    if (request.sourceMatches !== undefined) {
      const matches = new Map<string, MihonSourceMatch>()
      request.sourceMatches.forEach((item: MihonSourceMatch): void => { matches.set(item.id, item) })
      library.replaceMihonImports(library.listMihonImports().map((record: MihonImportRecord): MihonImportRecord => {
        const match = matches.get(record.id)
        if (match === undefined || record.targetComicId) return record
        return { id: record.id, work: record.work, categoryIds: record.categoryIds, sourceName: record.sourceName,
          matchedSourceId: match.sourceId, linkedWork: match.work }
      }))
    }
    for (const link of request.links ?? []) {
      const record = library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === link.id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      if (link.verifiedEdition === true && record.targetComicId) continue
      const target = typeof link.target === 'string' ? library.getComic(link.target) : link.target
      if (target === undefined) throw new Error('migration_source_changed')
      entries.push(linkMihonWork(library, record, target, link.verifiedEdition, link.identity, request.labels))
    }
    if (request.catalogLinkJson !== undefined) {
      const catalog = JSON.parse(request.catalogLinkJson) as MihonCatalogLink
      const record = library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === catalog.id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      if (!record.targetComicId) {
        const detail = catalog.detail
        const candidate = comicWithCompleteSourceCatalog(detail.sourceId, detail.id, detail, catalog.chapters,
          catalog.excludedChapterIds, catalog.settingsFingerprint)
        const linked = linkMihonWork(library, record, candidate, true, catalog.identity, request.labels)
        const stored = library.getComic(linked.target.id)
        if (stored !== undefined) {
          const resolved = reconcileSourceChapterIdentity(stored, detail.id, catalog.chapters, undefined, catalog.chapterPolicy)
          library.upsertComic(updatedSourceMangaDetail(stored, detail, resolved.chapters, true,
            catalog.excludedChapterIds, catalog.settingsFingerprint))
        }
        entries.push(linked)
      }
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
  let linkedComicIds: string[] | undefined
  let removedComicIds: string[] | undefined
  if (request.bytes === undefined) {
    // The two complete files above are committed atomically. Only publish
    // the affected records into the live stores for a link or rule update.
    const targetIds = new Set<string>()
    const originalIds = new Set<string>()
    const changedImports = new Set<string>(request.sourceMatches?.map((match: MihonSourceMatch): string => match.id) ?? [])
    for (const item of entries) {
      targetIds.add(item.target.id)
      originalIds.add(item.record.id)
      changedImports.add(item.record.id)
    }
    removedComicIds = Array.from(originalIds).filter((id: string): boolean => !targetIds.has(id))
    const readingIds = new Set<string>(Array.from(targetIds).concat(removedComicIds))
    linkedComicIds = Array.from(readingIds)
    contents.comics = contents.comics.filter((comic: Comic): boolean => targetIds.has(comic.id))
    contents.mihonImports = contents.mihonImports.filter((record: MihonImportRecord): boolean => changedImports.has(record.id))
    reader.progress = reader.progress.filter((progress): boolean => readingIds.has(progress.comicId))
    reader.sourceHistory = reader.sourceHistory.filter((history): boolean => readingIds.has(history.comicId))
    reader.chapters = reader.chapters.filter((chapter: ChapterReadingState): boolean => readingIds.has(chapter.comicId))
    // Incremental publication never consumes the full statistics or remote histories.
    reader.readingSessions = undefined
    reader.remoteHistory = undefined
    reader.syncPositions = undefined
    reader.syncActions = undefined
  }
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
    targetComicId: entries.length === 1 ? entries[0].target.id : undefined, linkedComicIds, removedComicIds }
}
