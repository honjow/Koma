import { common } from '@kit.AbilityKit'
import { openUserDataSnapshotDatabase } from './UserDataDatabase'
import { LibraryRdbStorage } from './LibraryRdbStorage'
import { ReaderRdbStorage } from './ReaderRdbStorage'
import { taskpool } from '@kit.ArkTS'
import { Comic } from './ComicModels'
import { InMemoryLibraryStore, LibraryContents } from './LibraryStore'
import { ReadOnlyLibraryStorePersistenceAdapter, LibraryStorePersistenceService } from './LibraryPersistence'
import { ChapterReadingState, ReaderSessionDocumentSnapshot } from './ReaderSessionStore'
import { MihonImportLabels, MihonImportSummary, importMihonWorks, mihonImportKey, linkMihonWork, mihonDeclaredWork,
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
 * The UI owner commits affected RDB rows atomically before publishing them. */
@Concurrent
export async function prepareMihonTransactionTask(context: common.UIAbilityContext,
  request: MihonTransactionRequest): Promise<MihonPreparedTransaction> {
  const library = new InMemoryLibraryStore()
  const database = await openUserDataSnapshotDatabase(context)
  try {
  const shelf = new LibraryRdbStorage(database)
  const adapter = new ReadOnlyLibraryStorePersistenceAdapter(shelf)
  new LibraryStorePersistenceService(library, adapter).restoreForLaunch('all')
  const changedImports = new Set<string>(request.sourceMatches?.map((match: MihonSourceMatch): string => match.id) ?? [])
  let entries: ResolvedMihonImport[] = []
  if (request.bytes !== undefined) {
    const backup = await readMihonBackup(request.bytes)
    for (const work of backup.works) changedImports.add(mihonImportKey(work))
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
      const changed: MihonImportRecord[] = []
      for (const match of request.sourceMatches) {
        const record = library.readMihonImport(match.id)
        if (record !== undefined && !record.targetComicId) changed.push(applyMihonSourceMatch(record, match))
      }
      library.updateMihonImports(changed)
    }
    for (const link of request.links ?? []) {
      const record = library.readMihonImport(link.id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      if (link.verifiedEdition === true && record.targetComicId) continue
      const target = typeof link.target === 'string' ? library.getComic(link.target) : link.target
      if (target === undefined) throw new Error('migration_source_changed')
      entries.push(linkMihonWork(library, record, target, link.verifiedEdition, link.identity, request.labels))
    }
    if (request.catalogLinkJson !== undefined) {
      const catalog = JSON.parse(request.catalogLinkJson) as MihonCatalogLink
      const record = library.readMihonImport(catalog.id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      if (!record.targetComicId) {
        entries.push(linkCatalog(library, record, catalog, request.labels))
      }
    }
  }
  for (const item of entries) {
    verifyMihonEdition(item, request.identities.get(item.target.sourceRuntimeId ?? ''))
  }
  const targetIds = new Set<string>()
  const originalIds = new Set<string>()
  for (const item of entries) {
    targetIds.add(item.target.id)
    originalIds.add(item.record.id)
    changedImports.add(item.record.id)
  }
  const removedComicIds = Array.from(originalIds).filter((id: string): boolean => !targetIds.has(id))
  const linkedComicIds = Array.from(new Set(Array.from(targetIds).concat(removedComicIds)))
  const reader = new ReaderRdbStorage(database).readCatalogLinkReading(linkedComicIds)
  const unmatchedChapters = mergeReading(reader, entries, request.labels)
  const comics: Comic[] = []
  for (const id of targetIds) {
    const comic = library.getComic(id)
    if (comic !== undefined) comics.push(comic)
  }
  const imports: MihonImportRecord[] = []
  for (const id of changedImports) {
    const record = library.readMihonImport(id)
    if (record !== undefined) imports.push(record)
  }
  const contents: LibraryContents = { comics, mihonImports: imports,
    customCategories: library.listCustomCategories(), smartCategories: library.listSmartCategories(),
    displayStrategies: library.listCategoryDisplayStrategies(), shelfMoves: library.listSyncShelfMoves() }
  reader.readingSessions = undefined
  reader.remoteHistory = undefined
  reader.syncPositions = undefined
  reader.syncActions = undefined
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
  } finally { await database.close() }
}
