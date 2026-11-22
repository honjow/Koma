import { writeAppTextFile } from './AppFileTextPersistence'
import { taskpool } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore, LibraryContents, libraryContents } from './LibraryStore'
import { AppFilesLibraryStorePersistenceAdapter, LibraryStorePersistenceService, LIBRARY_STORE_PERSISTENCE_FILE_NAME,
  serializeLibraryStore } from './LibraryPersistence'
import { AppFilesReaderSessionPersistenceAdapter, ChapterReadingState,
  ReaderSessionDocumentSnapshot, READER_PROGRESS_PERSISTENCE_FILE_NAME,
  serializeReaderSessionForDevice } from './ReaderSessionStore'
import { MihonImportLabels, MihonImportSummary, importMihonWorks, linkMihonWork, mihonDeclaredWork,
  mihonSourceMatcher, ResolvedMihonImport, summarizeMihonImport, withMihonTrackerCandidates } from './MihonImportPlanning'
import { MihonImportRecord, readMihonBackup } from './MihonBackupReader'
import { MihonSourceIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ComicTrackerMapping } from './TrackerModels'
import { SourceManga } from './SourceModels'
import { MangaChapterItem, MangaDetail } from './MangaDetailModels'
import { SourceChapterIdentityPolicy } from '../sourceRuntime/SourceWebsitePolicy'
import { applyMihonSourceMatch, linkCatalog, mergeReading, verifyMihonEdition } from './MihonCatalogPlanning'
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

export interface MihonPreparedCatalog {
  record: MihonImportRecord
  comic?: Comic
  reader: ReaderSessionDocumentSnapshot
  trackerMappings: ComicTrackerMapping[]
  unmatchedChapters: number
}

export interface MihonSingleLink {
  target?: Comic
  identity?: MihonSourceIdentity
  catalog?: MihonCatalogLink
  verifiedEdition?: boolean
  declaredIdentity?: MihonSourceIdentity
}

@Concurrent
export function prepareMihonLinkTask(linkJson: string, record: MihonImportRecord, previous: Comic[],
  reader: ReaderSessionDocumentSnapshot, labels: MihonImportLabels): MihonPreparedCatalog {
  const library = new InMemoryLibraryStore()
  previous.forEach((comic: Comic): void => { library.upsertComic(comic) })
  library.replaceMihonImports([record])
  const link = JSON.parse(linkJson) as MihonSingleLink
  const linked = link.catalog !== undefined ? linkCatalog(library, record, link.catalog, labels) :
    linkMihonWork(library, record, link.target!, link.verifiedEdition, link.identity, labels)
  verifyMihonEdition(linked, link.declaredIdentity)
  const unmatchedChapters = mergeReading(reader, [linked], labels)
  return { record: linked.record, comic: library.getComic(linked.target.id), reader, unmatchedChapters,
    trackerMappings: withMihonTrackerCandidates([], [linked]) }
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
  // The first checkpoint file is the shelf, captured by its current storage owner.
  new LibraryStorePersistenceService(library, new AppFilesLibraryStorePersistenceAdapter(stagedDir, '0')).restore()
  const readingBefore = stagedDir + '/1'
  const reader = new AppFilesReaderSessionPersistenceAdapter(filesDir).loadSnapshot(
    fs.accessSync(readingBefore) ? fs.readTextSync(readingBefore) : null)
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
        return applyMihonSourceMatch(record, match)
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
        entries.push(linkCatalog(library, record, catalog, request.labels))
      }
    }
  }
  for (const item of entries) {
    verifyMihonEdition(item, request.identities.get(item.target.sourceRuntimeId ?? ''))
  }
  const unmatchedChapters = mergeReading(reader, entries, request.labels)
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
