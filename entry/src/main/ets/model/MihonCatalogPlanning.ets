import { InMemoryLibraryStore } from './LibraryStore'
import { MihonSourceIdentity, mihonPathIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { updatedSourceMangaDetail } from './LibraryPersistence'
import { alignSnapshotChapterCompletion, ReaderSessionDocumentSnapshot, ReaderSessionReadingSnapshot } from './ReaderSessionStore'
import { MihonImportLabels, ResolvedMihonImport, linkMihonWork, mergeMihonReading } from './MihonImportPlanning'
import type { MihonCatalogLink, MihonSourceMatch } from './MihonImportWorker'
import { MihonImportRecord } from './MihonBackupReader'
import { comicWithCompleteSourceCatalog } from './SourceLibraryComic'
import { reconcileSourceChapterIdentity } from './SourceChapterIdentity'

export function linkCatalog(library: InMemoryLibraryStore, record: MihonImportRecord, catalog: MihonCatalogLink,
  labels: MihonImportLabels): ResolvedMihonImport {
  const detail = catalog.detail
  const candidate = comicWithCompleteSourceCatalog(detail.sourceId, detail.id, detail, catalog.chapters,
    catalog.excludedChapterIds, catalog.settingsFingerprint)
  const linked = linkMihonWork(library, record, candidate, true, catalog.identity, labels)
  const stored = library.getComic(linked.target.id)
  if (stored !== undefined) {
    const resolved = reconcileSourceChapterIdentity(stored, detail.id, catalog.chapters, undefined, catalog.chapterPolicy)
    library.upsertComic(updatedSourceMangaDetail(stored, detail, resolved.chapters, true,
      catalog.excludedChapterIds, catalog.settingsFingerprint))
  }
  return linked
}

export function mergeReading(reader: ReaderSessionDocumentSnapshot, entries: ResolvedMihonImport[], labels: MihonImportLabels): number {
  const reading: ReaderSessionReadingSnapshot = { progress: reader.progress, sourceHistory: reader.sourceHistory,
    remoteHistory: reader.remoteHistory ?? [], chapterStates: reader.chapters, readingSessions: reader.readingSessions ?? [] }
  const unmatched = mergeMihonReading(reading, entries, labels)
  reader.progress = reading.progress
  reader.sourceHistory = reading.sourceHistory
  reader.chapters = reading.chapterStates
  alignSnapshotChapterCompletion(reader)
  return unmatched
}

export function verifyMihonEdition(item: ResolvedMihonImport, identity: MihonSourceIdentity | undefined): void {
  if (identity === undefined || !identity.sourceIds.includes(item.record.work.sourceId) ||
    item.target.remoteResourceId !== mihonPathIdentity(item.record.work.url, identity.work)) return
  item.sameEdition = true
  item.identity = identity
}

export function applyMihonSourceMatch(record: MihonImportRecord, match: MihonSourceMatch): MihonImportRecord {
  return { id: record.id, work: record.work, categoryIds: record.categoryIds, sourceName: record.sourceName,
    matchedSourceId: match.sourceId, linkedWork: match.work }
}
