import { Chapter, Comic, ComicSourceKind, ReadingDirection, ReadingProgress, normalizeSortKey,
  libraryCategoryNameKey, normalizeCategoryIds } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { ChapterReadingState, ReaderSessionReadingSnapshot } from './ReaderSessionStore'
import { SourceReadHistoryEntry } from './SourceReaderSession'
import { MihonBackup, MihonBackupChapter, MihonBackupHistory, MihonBackupTracking, MihonBackupWork, MihonBackupWorkSummary,
  MihonImportRecord, MihonImportWork } from './MihonBackupReader'
import { mangaHttpUrl } from './MangaWebLink'
import { MangaStatus } from './MangaDetailModels'
import { SourceManga } from './SourceModels'
import { migrationChapterMatch } from './SourceMangaMigration'
import { AppStrings } from '../i18n/AppStrings'
import { MihonSourceIdentity, mihonChapterPathIdentity, mihonPathIdentity,
  mihonTargetChapterId } from '../sourceRuntime/MihonSourceIdentity'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ComicTrackerMapping, TrackerProviderId } from './TrackerModels'

type MihonSourceSummary = SourceRuntimeRegistryInstalledSourceSummary

export interface MihonImportSummary {
  works: number
  favorites: number
  categories: number
  chapters: number
  history: number
  tracking: number
}

export function mihonImportKey(work: MihonBackupWork): string {
  return 'mihon:' + work.sourceId + ':' + work.url.trim()
}

export function mihonSourceName(record: MihonImportRecord): string {
  return record.sourceName || AppStrings.format('mihon_import_unnamed_source', record.work.sourceId)
}

export interface MihonImportLabels {
  untitled: string
  unnamedSource: string
}

function httpIdentity(value: string | undefined): string | undefined {
  // Keep the whole URL, including query and fragment, as either can identify an edition.
  return mangaHttpUrl(value)?.replace(/^(https?:\/\/[^/?#]+)/i, (origin: string): string => origin.toLowerCase())
}

export function mihonMatchText(value: string | undefined): string {
  return (value ?? '').normalize('NFKC').trim().toLowerCase().replace(/\s+/g, ' ')
}

/** Suggestions use explicit titles only. The user still chooses the edition. */
export function suggestedMihonShelfWorks(work: MihonBackupWorkSummary, shelf: Comic[]): Comic[] {
  const titles = new Set<string>([mihonMatchText(work.title)])
  for (const line of work.description.split(/\r?\n/)) {
    const alias = /^\s*[*_]*\s*(?:别名|別名|又名|alternate titles?)\s*[*_]*\s*[:：]\s*(.+?)\s*[*_]*\s*$/i.exec(line)
    if (alias !== null) titles.add(mihonMatchText(alias[1].replace(/^\s*[*_]+|[*_]+\s*$/g, '')))
  }
  titles.delete('')
  return shelf.filter((comic: Comic): boolean =>
    comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY && !!comic.sourceRuntimeId && !!comic.remoteResourceId &&
    !comic.sourceRuntimeId.startsWith('mihon:') && titles.has(mihonMatchText(comic.title)))
}

function sitePath(value: string | undefined): string | undefined {
  const url = httpIdentity(value)
  const path = url === undefined ? value?.trim() : url.replace(/^https?:\/\/[^/?#]+/i, '')
  return path?.startsWith('/') && !path.startsWith('//') && path.length > 1 ? path : undefined
}

/** A source name selects where to look. A work path or the same cover and
 * exact title must corroborate the work inside that source's catalog. */
export function matchesMihonSourceWork(work: MihonBackupWorkSummary, title: string, cover: string | undefined,
  url: string | undefined, webUrl: string | undefined): boolean {
  const path = sitePath(work.url)
  if (path !== undefined && (path === sitePath(url) || path === sitePath(webUrl))) return true
  const name = mihonMatchText(work.title)
  if (name.length === 0 || name !== mihonMatchText(title)) return false
  const coverUrl = httpIdentity(work.coverUrl)
  return coverUrl !== undefined && coverUrl === httpIdentity(cover)
}

export function pickMihonSourceWork(work: MihonBackupWorkSummary, catalog: SourceManga[]): SourceManga | undefined {
  const candidates = catalog.filter((candidate: SourceManga): boolean => candidate.id === work.url ||
    matchesMihonSourceWork(work, candidate.title, candidate.coverUrl, candidate.url, candidate.webUrl))
  return candidates.length === 1 ? candidates[0] : undefined
}

export function matchingMihonShelfWork(work: MihonBackupWorkSummary, sourceName: string, candidates: Comic[]): Comic | undefined {
  const link = httpIdentity(work.url)
  const matches = candidates.filter((comic: Comic): boolean =>
    comic.sourceRuntimeId !== undefined && !comic.sourceRuntimeId.startsWith('mihon:') &&
    ((link !== undefined && (link === httpIdentity(comic.sourceMetadata?.webUrl) || link === httpIdentity(comic.sourcePath))) ||
      (sourceName.length > 0 && mihonMatchText(sourceName) === mihonMatchText(comic.sourceMetadata?.sourceName) &&
        matchesMihonSourceWork(work, comic.title, comic.coverUri, comic.sourcePath, comic.sourceMetadata?.webUrl))))
  return matches.length === 1 ? matches[0] : undefined
}

interface MihonShelfMatch {
  comic: Comic
  identity?: MihonSourceIdentity
}

function matchImportedShelfWork(work: MihonBackupWork, sourceName: string, candidates: Comic[],
  identities: Map<string, MihonSourceIdentity>): MihonShelfMatch | undefined {
  const declared = Array.from(identities.entries()).filter((entry: [string, MihonSourceIdentity]): boolean =>
    entry[1].sourceIds.includes(work.sourceId))
  if (declared.length > 1) return undefined
  // Editions can share a title, cover or public URL. A declared Mihon
  // identity takes precedence over those hints, including for local merges.
  if (declared.length === 1) {
    const sourceId = declared[0][0]
    const identity = declared[0][1]
    const id = mihonPathIdentity(work.url, identity.work)
    const comic = id === undefined ? undefined : candidates.find((candidate: Comic): boolean =>
      candidate.sourceRuntimeId === sourceId && candidate.remoteResourceId === id && candidate.chapters.length > 0)
    return comic === undefined ? undefined : { comic, identity }
  }
  const comic = matchingMihonShelfWork(work, sourceName, candidates.filter((candidate: Comic): boolean =>
    !identities.has(candidate.sourceRuntimeId ?? '')))
  return comic === undefined ? undefined : { comic }
}

export function summarizeMihonImport(backup: MihonBackup): MihonImportSummary {
  const summary: MihonImportSummary = { works: backup.works.length, favorites: 0, categories: backup.categories.length,
    chapters: 0, history: 0, tracking: 0 }
  for (const work of backup.works) {
    if (work.favorite) summary.favorites++
    summary.chapters += work.chapters.length
    summary.history += work.history.length
    summary.tracking += work.tracking.length
  }
  return summary
}

export function mihonPlaceholder(record: MihonImportRecord, labels?: MihonImportLabels): Comic {
  const work = record.work
  const title = work.title || (labels?.untitled ?? AppStrings.get('manga_detail_title_fallback'))
  const createdAt = work.addedAt || work.modifiedAt
  const urls = new Map<string, number>()
  work.chapters.forEach((chapter: MihonBackupChapter): void => { urls.set(chapter.url, (urls.get(chapter.url) ?? 0) + 1) })
  const chapters = work.chapters.map((chapter: MihonBackupChapter, index: number): Chapter => ({
    id: urls.get(chapter.url) === 1 && chapter.url ? chapter.url : 'mihon-chapter:' + index + ':' + chapter.url,
    comicId: record.id, title: chapter.title, index, chapterNumber: chapter.number >= 0 ? chapter.number : undefined,
    scanlator: chapter.scanlator || undefined, dateUpload: chapter.uploadedAt || undefined, sourcePath: chapter.url,
    sortKey: index.toString(), pages: [], pageCount: 0, createdAt: chapter.fetchedAt, updatedAt: chapter.modifiedAt,
  }))
  return { id: record.id, title, subtitle: work.description || undefined, author: work.author || undefined,
    categoryIds: record.categoryIds.slice(), sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
    sourcePath: work.url, sourceRuntimeId: 'mihon:' + work.sourceId, remoteResourceId: work.url || record.id,
    coverUri: mangaHttpUrl(work.coverUrl), personalNotes: work.notes || undefined,
    sourceMetadata: { sourceName: record.sourceName || (labels === undefined ? mihonSourceName(record) :
      labels.unnamedSource.replace('%s', work.sourceId)), artist: work.artist || undefined, tags: work.genres.slice(),
      status: mihonStatus(work.status),
      webUrl: mangaHttpUrl(work.url) },
    sortTitle: normalizeSortKey(title), preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters, chapterCount: chapters.length, pageCount: 0, createdAt, updatedAt: work.modifiedAt, lastImportedAt: createdAt,
  }
}

function mihonStatus(status: number): MangaStatus | undefined {
  switch (status) {
    case 1: return MangaStatus.ONGOING
    case 2: return MangaStatus.COMPLETED
    case 5: return MangaStatus.CANCELLED
    case 6: return MangaStatus.HIATUS
    default: return undefined
  }
}

function mergeComicMetadata(target: Comic, original: Comic, categories: string[]): Comic {
  const result = JSON.parse(JSON.stringify(target)) as Comic
  result.categoryIds = normalizeCategoryIds((result.categoryIds ?? []).concat(categories))
  result.author = result.author || original.author
  result.subtitle = result.subtitle || original.subtitle
  result.coverUri = result.coverUri || original.coverUri
  result.personalNotes = result.personalNotes || original.personalNotes
  return result
}

function categoryLinks(backup: MihonBackup, library: LibraryStore): Map<string, string> {
  const names = new Map<string, string>()
  library.listCustomCategories().forEach(category => { names.set(libraryCategoryNameKey(category.name), category.id) })
  const smartNames = new Set<string>(library.listSmartCategories().map(category => libraryCategoryNameKey(category.name)))
  const links = new Map<string, string>()
  for (const category of backup.categories.slice().sort((left, right): number => left.order - right.order)) {
    const base = category.name.trim().slice(0, 40)
    if (!base) continue
    let name = base
    let suffix = 2
    while (smartNames.has(libraryCategoryNameKey(name))) {
      const marker = ' (' + suffix++ + ')'
      name = base.slice(0, 40 - marker.length) + marker
    }
    const key = libraryCategoryNameKey(name)
    const id = names.get(key) ?? library.createCustomCategory(name).id
    names.set(key, id)
    // Mihon exports manga memberships by category order, including order 0.
    links.set(category.order.toString(), id)
  }
  return links
}

function mergeOriginalWork(previous: MihonBackupWork, incoming: MihonBackupWork): MihonBackupWork {
  const newest = incoming.modifiedAt >= previous.modifiedAt ? incoming : previous
  const other = newest === incoming ? previous : incoming
  const result = JSON.parse(JSON.stringify(newest)) as MihonBackupWork
  result.title = newest.title || other.title
  result.author = newest.author || other.author
  result.artist = newest.artist || other.artist
  result.description = newest.description || other.description
  result.coverUrl = newest.coverUrl || other.coverUrl
  result.notes = newest.notes || other.notes
  result.genres = Array.from(new Set<string>(newest.genres.concat(other.genres)))
  result.categoryIds = Array.from(new Set<string>(previous.categoryIds.concat(incoming.categoryIds)))
  const chapters = new Map<string, MihonBackupChapter>()
  const history = new Map<string, MihonBackupHistory>()
  const trackers = new Map<string, MihonBackupTracking>()
  const reads = new Map<string, number>()
  previous.history.forEach(edge => { reads.set(edge.chapterUrl, Math.max(edge.readAt, reads.get(edge.chapterUrl) ?? 0)) })
  for (const edge of other.history.concat(newest.history)) {
    const key = edge.chapterUrl + '\n' + edge.readAt
    if ((history.get(key)?.readDuration ?? -1) < edge.readDuration) history.set(key, edge)
  }
  for (const chapter of previous.chapters) chapters.set(chapter.url + '\n' + chapter.scanlator, chapter)
  const incomingReads = new Map<string, number>()
  for (const edge of incoming.history) incomingReads.set(edge.chapterUrl, Math.max(edge.readAt, incomingReads.get(edge.chapterUrl) ?? 0))
  for (const chapter of incoming.chapters) {
    const key = chapter.url + '\n' + chapter.scanlator
    const current = chapters.get(key)
    const fromTime = Math.max(chapter.modifiedAt, incomingReads.get(chapter.url) ?? 0)
    const currentTime = Math.max(current?.modifiedAt ?? 0, reads.get(chapter.url) ?? 0)
    if (current === undefined || fromTime > currentTime || (fromTime === 0 && currentTime === 0 &&
      (!current.read && chapter.read || !current.bookmarked && chapter.bookmarked || current.pageIndex < chapter.pageIndex))) {
      chapters.set(key, chapter)
    }
  }
  for (const track of other.tracking.concat(newest.tracking)) {
    trackers.set(track.serviceId + ':' + track.libraryId + ':' + track.mediaId, track)
  }
  result.chapters = Array.from(chapters.values())
  result.history = Array.from(history.values())
  result.tracking = Array.from(trackers.values())
  return result
}

export interface ResolvedMihonImport {
  record: MihonImportRecord
  target: Comic
  sameEdition: boolean
  identity?: MihonSourceIdentity
}

function mihonLinkedWork(comic: Comic): SourceManga | undefined {
  if (!comic.sourceRuntimeId || !comic.remoteResourceId) return undefined
  return { id: comic.remoteResourceId, sourceId: comic.sourceRuntimeId, title: comic.title,
    url: comic.sourcePath, webUrl: comic.sourceMetadata?.webUrl, coverUrl: comic.coverUri }
}

// A source-declared identity is sufficient to open the real work. Keep the
// original reading records until its current chapter list can be matched.
export function mihonDeclaredWork(record: MihonImportWork, sourceId: string,
  identity: MihonSourceIdentity | undefined): SourceManga | undefined {
  if (identity === undefined || !identity.sourceIds.includes(record.work.sourceId)) return undefined
  const id = mihonPathIdentity(record.work.url, identity.work)
  return id === undefined ? undefined : { id, sourceId, title: record.work.title, coverUrl: mangaHttpUrl(record.work.coverUrl) }
}

export function importMihonWorks(backup: MihonBackup, library: LibraryStore,
  identities: Map<string, MihonSourceIdentity> = new Map<string, MihonSourceIdentity>(),
  labels?: MihonImportLabels): ResolvedMihonImport[] {
  const links = categoryLinks(backup, library)
  const names = new Map<string, string>()
  for (const source of backup.sources) names.set(source.id, source.name)
  const records = new Map<string, MihonImportRecord>()
  const candidates = library.listComicSummaries(false)
  const results: ResolvedMihonImport[] = []
  for (const work of backup.works) {
    const key = mihonImportKey(work)
    const previous = records.get(key) ?? library.readMihonImport(key)
    // Koma-assigned editions are stable across repeat imports.
    const sourceName = names.get(work.sourceId) || previous?.sourceName || ''
    const linked = previous?.targetComicId ? library.getComic(previous.targetComicId) : undefined
    const match = previous?.targetComicId
      ? linked === undefined ? undefined : matchImportedShelfWork(work, sourceName, [linked], identities)
      : matchImportedShelfWork(work, sourceName, candidates, identities)
    const existing = linked ?? (match === undefined ? undefined : library.getComic(match.comic.id))
    const original = previous === undefined ? work : mergeOriginalWork(previous.work, work)
    const record: MihonImportRecord = {
      id: key, sourceName, work: original,
      categoryIds: normalizeCategoryIds((previous?.categoryIds ?? []).concat(
        work.categoryIds.map((id: string): string => links.get(id) ?? ''))),
      matchedSourceId: previous?.matchedSourceId,
      targetComicId: existing?.id ?? previous?.targetComicId,
      linkedWork: existing === undefined ? previous?.linkedWork : mihonLinkedWork(existing),
    }
    records.set(key, record)
    // A user-linked history-only work has no shelf row to rebuild here. Its
    // Koma identity remains linked and the incoming original facts are saved.
    if (previous?.targetComicId && existing === undefined) continue
    const placeholder = mihonPlaceholder(record, labels)
    const originalShelf = library.getComic(key)
    const current = existing ?? originalShelf
    const target = current === undefined ? placeholder : mergeComicMetadata(current, placeholder, record.categoryIds)
    if (target.id === key) {
      target.chapters = placeholder.chapters
      target.chapterCount = placeholder.chapterCount
    }
    if (work.favorite || current !== undefined) library.upsertComic(target)
    if (existing !== undefined && originalShelf !== undefined) library.removeComic(key)
    results.push({ record, target, sameEdition: match !== undefined, identity: match?.identity })
  }
  library.updateMihonImports(Array.from(records.values()))
  return results
}

export function linkMihonWork(library: LibraryStore, from: MihonImportRecord, target: Comic,
  verifiedEdition: boolean = false, identity?: MihonSourceIdentity, labels?: MihonImportLabels): ResolvedMihonImport {
  const shelf = library.getComic(from.id)
  const match = library.listComicSummaries(false).find((comic: Comic): boolean =>
    comic.sourceRuntimeId === target.sourceRuntimeId && comic.remoteResourceId === target.remoteResourceId)
  const previous = match === undefined ? undefined : library.getComic(match.id)
  const current = previous === undefined ? target : JSON.parse(JSON.stringify(previous)) as Comic
  // Include chapters found during the match while keeping the local copy of
  // every cached chapter, its reading plan and existing shelf metadata.
  if (previous !== undefined) {
    const known = new Set<string>(current.chapters.map((chapter: Chapter): string => chapter.id))
    for (const chapter of target.chapters) {
      if (known.has(chapter.id)) continue
      const copy = JSON.parse(JSON.stringify(chapter)) as Chapter
      copy.comicId = current.id
      copy.index = current.chapters.length
      known.add(copy.id)
      current.chapters.push(copy)
    }
    current.chapterCount = Math.max(current.chapterCount, current.chapters.length)
  }
  const resolved = mergeComicMetadata(current, shelf ?? mihonPlaceholder(from, labels), shelf?.categoryIds ?? from.categoryIds)
  if (shelf !== undefined || previous !== undefined) library.upsertComic(resolved)
  library.removeComic(from.id)
  const record: MihonImportRecord = { id: from.id, work: from.work, categoryIds: from.categoryIds,
    sourceName: from.sourceName, matchedSourceId: from.matchedSourceId,
    targetComicId: resolved.id, linkedWork: mihonLinkedWork(resolved) }
  library.updateMihonImports([record])
  return { record, target: resolved, identity, sameEdition: verifiedEdition ||
    matchingMihonShelfWork(record.work, record.sourceName, [target]) !== undefined }
}

function numberedChapterKind(chapter: Chapter): 'volume' | 'chapter' | 'extra' | undefined {
  const title = mihonMatchText(chapter.title)
  if (/^(?:第\s*)?\d+\s*[卷巻]|^(?:volume|vol\.?)\s*\d/.test(title)) return 'volume'
  if (/^(?:第\s*)?\d+(?:\.\d+)?\s*[话話]|^(?:chapter|ch\.?)\s*\d/.test(title)) return 'chapter'
  if (/^(?:附[录錄]|[番卷]外|extra|appendix)\s*\d/.test(title)) return 'extra'
  return undefined
}

function mihonChapterMatch(chapter: Chapter, original: Chapter[], target: Chapter[]): Chapter | undefined {
  const kind = numberedChapterKind(chapter)
  if (kind === undefined || chapter.chapterNumber === undefined) return migrationChapterMatch(chapter, original, target)
  // A catalog can number volumes and individual chapters independently.
  // Explicit labels rule out the other kind without guessing at unlabelled entries.
  const compatible = (candidate: Chapter): boolean => {
    if (candidate.chapterNumber !== chapter.chapterNumber) return false
    const candidateKind = numberedChapterKind(candidate)
    return candidateKind === undefined || candidateKind === kind
  }
  return migrationChapterMatch(chapter, original.filter(compatible), target.filter(compatible))
}

function isMihonChapterStartFallback(previous: ReadingProgress, original: ReadingProgress): boolean {
  return original.pageIndex > 0 && previous.updatedAt === original.updatedAt &&
    previous.chapterId === original.chapterId && previous.pageIndex === 0 && previous.totalPages === 0 &&
    previous.pageId === undefined && previous.columnMode === undefined
}

/** Keep a later local position and local explicit read/bookmark changes. A matched
 * chapter on a different edition starts at its beginning; the original page is retained. */
export function mergeMihonReading(snapshot: ReaderSessionReadingSnapshot,
  imports: ResolvedMihonImport[], labels?: MihonImportLabels): number {
  const progress = new Map<string, ReadingProgress>()
  const histories = new Map<string, SourceReadHistoryEntry>()
  const states = new Map<string, ChapterReadingState>()
  snapshot.progress.forEach(row => { progress.set(row.comicId, row) })
  snapshot.sourceHistory.forEach(row => { histories.set(row.comicId, row) })
  snapshot.chapterStates.forEach(row => { states.set(row.comicId + '\n' + row.chapterId, row) })
  let unmatched = 0
  for (const item of imports) {
    const work = item.record.work
    const comic = item.target
    const pending = item.record.id === comic.id
    const originalChapters = pending ? comic.chapters : mihonPlaceholder(item.record, labels).chapters
    const lastRead = new Map<string, number>()
    for (const edge of work.history) lastRead.set(edge.chapterUrl, Math.max(lastRead.get(edge.chapterUrl) ?? 0, edge.readAt))
    const latestReadAt = work.history.reduce((latest: number, edge: MihonBackupHistory): number =>
      Math.max(latest, edge.readAt), 0)
    let latest: ReadingProgress | undefined
    let latestChapter: Chapter | undefined
    const identity = item.identity
    const chapterRule = identity?.chapter
    const declaredChapters = new Map<string, Chapter[]>()
    if (item.sameEdition && chapterRule !== undefined) {
      for (const chapter of comic.chapters) {
        const id = mihonTargetChapterId(chapter.id, chapterRule)
        if (id === undefined) continue
        const matches = declaredChapters.get(id) ?? []
        matches.push(chapter)
        declaredChapters.set(id, matches)
      }
    }
    for (let index = 0; index < work.chapters.length; index++) {
      const original = work.chapters[index]
      const readAt = lastRead.get(original.url) ?? 0
      if (!original.read && !original.bookmarked && original.pageIndex <= 0 && readAt <= 0) continue
      const originalChapter = originalChapters[index]
      const mappedId = identity === undefined ? undefined :
        mihonChapterPathIdentity(original.url, comic.remoteResourceId ?? '', identity)
      let direct: Chapter[] = []
      if (item.sameEdition) {
        if (chapterRule !== undefined) direct = mappedId === undefined ? [] : declaredChapters.get(mappedId) ?? []
        else direct = comic.chapters.filter((chapter: Chapter): boolean =>
          (chapter.id === original.url || chapter.sourcePath === original.url) &&
          (chapter.scanlator ?? '') === original.scanlator)
      }
      const destination = pending ? originalChapter : direct.length === 1 ? direct[0] :
        mihonChapterMatch(originalChapter, originalChapters, comic.chapters)
      if (destination === undefined) {
        unmatched++
        continue
      }
      const total = destination.pageCount
      // A catalog may omit page totals. The reader clamps the saved position
      // after resolving the actual pages of that same chapter.
      const exact = direct.length === 1 &&
        (item.identity === undefined || mappedId !== undefined && item.identity.samePageOrder === true) &&
        (total === 0 || total > original.pageIndex)
      const pageIndex = pending || exact ? Math.max(0, original.pageIndex) : 0
      if (!pending && !exact && original.pageIndex > 0) unmatched++
      const key = comic.id + '\n' + destination.id
      const previous = states.get(key)
      const localNewer = previous !== undefined && previous.updatedAt >= Math.max(original.modifiedAt, readAt)
      const completed = localNewer ? previous?.isRead === true : original.read
      const position: ReadingProgress = { comicId: comic.id, chapterId: destination.id,
        pageId: exact ? destination.pages[pageIndex]?.id : undefined, pageIndex, totalPages: total,
        progressRatio: total > 0 ? (pageIndex + 1) / total : 0, completed, updatedAt: readAt || original.modifiedAt }
      const previousPosition = previous?.position
      // An old import may have saved the start of this chapter with the
      // original event timestamp and no resolved pages. Reimport can repair
      // that placeholder without overriding a subsequent reading event.
      const repairFallback = exact && previousPosition !== undefined &&
        (previous?.updatedAt ?? 0) <= Math.max(original.modifiedAt, readAt) &&
        isMihonChapterStartFallback(previousPosition, position)
      const keepPosition = previousPosition !== undefined &&
        !repairFallback && (previousPosition.updatedAt >= position.updatedAt || (!exact && !pending))
      states.set(key, { comicId: comic.id, chapterId: destination.id,
        position: keepPosition ? previousPosition : position, isRead: completed,
        bookmarked: localNewer ? previous?.bookmarked : original.bookmarked,
        updatedAt: Math.max(previous?.updatedAt ?? 0, original.modifiedAt, readAt), sourceIdentity: previous?.sourceIdentity })
      if (readAt > 0 && readAt === latestReadAt && latest === undefined) {
        const resume = keepPosition && previousPosition !== undefined ? previousPosition : position
        // Compare the time of the reading event across works, even when the
        // matched edition retains its own saved page for that chapter.
        latest = { comicId: resume.comicId, chapterId: resume.chapterId, pageId: resume.pageId,
          pageIndex: resume.pageIndex, totalPages: resume.totalPages, progressRatio: resume.progressRatio,
          completed: resume.completed, columnMode: resume.columnMode, updatedAt: Math.max(resume.updatedAt, readAt) }
        latestChapter = destination
      }
    }
    const recent = progress.get(comic.id)
    if (latest !== undefined && (latest.updatedAt > (recent?.updatedAt ?? 0) ||
      recent !== undefined && isMihonChapterStartFallback(recent, latest))) {
      progress.set(comic.id, latest)
      histories.set(comic.id, { comicId: comic.id, sourceId: comic.sourceRuntimeId ?? ('mihon:' + work.sourceId),
        mangaId: comic.remoteResourceId ?? work.url, mangaUrl: comic.sourcePath, sourceName: comic.sourceMetadata?.sourceName,
        title: comic.title, coverUri: comic.coverUri, chapterId: latest.chapterId, chapterTitle: latestChapter?.title })
    }
    const originalRecent = progress.get(item.record.id)
    if (!pending && latest !== undefined && originalRecent !== undefined &&
      latest.updatedAt >= originalRecent.updatedAt) {
      progress.delete(item.record.id)
      histories.delete(item.record.id)
    }
  }
  snapshot.progress = Array.from(progress.values())
  snapshot.sourceHistory = Array.from(histories.values())
  snapshot.chapterStates = Array.from(states.values())
  return unmatched
}

export function mihonSourceMatcher(sources: MihonSourceSummary[], identities: Map<string, MihonSourceIdentity>): (record: MihonImportWork) => MihonSourceSummary | undefined {
  const byId = new Map<string, MihonSourceSummary>()
  const declared = new Map<string, MihonSourceSummary[]>()
  const byName = new Map<string, MihonSourceSummary[]>()
  for (const source of sources) {
    const rule = identities.get(source.sourceId)
    for (const id of new Set<string>(rule?.sourceIds ?? [])) {
      const matches = declared.get(id) ?? []
      matches.push(source)
      declared.set(id, matches)
    }
    // A source that declares its Mihon editions must not claim other
    // versions of the same title by sharing a provider name.
    if (rule !== undefined) continue
    byId.set(source.sourceId, source)
    if (!source.capabilities.includes('search')) continue
    const names = new Set<string>([mihonMatchText(source.displayName)])
    const localized = source.localizedNames
    if (localized !== undefined) {
      for (const name of Object.keys(localized)) names.add(mihonMatchText(localized[name]))
    }
    names.delete('')
    for (const name of names) {
      const matches = byName.get(name) ?? []
      matches.push(source)
      byName.set(name, matches)
    }
  }
  return (record: MihonImportWork): MihonSourceSummary | undefined => {
    const matches = declared.get(record.work.sourceId)
    if (matches !== undefined) return matches.length === 1 ? matches[0] : undefined
    const remembered = byId.get(record.matchedSourceId ?? '')
    if (remembered !== undefined) return remembered
    const named = byName.get(mihonMatchText(record.sourceName))
    return named?.length === 1 ? named[0] : undefined
  }
}

function trackerProvider(serviceId: number): TrackerProviderId | undefined {
  // Mihon's TrackerManager defines these numeric identifiers.
  switch (serviceId) {
    case 1: return 'myanimelist'
    case 2: return 'anilist'
    case 3: return 'kitsu'
    case 5: return 'bangumi'
    case 7: return 'mangaupdates'
    default: return undefined
  }
}

export function withMihonTrackerCandidates(current: ComicTrackerMapping[], imported: ResolvedMihonImport[]): ComicTrackerMapping[] {
  const mappings = current.slice()
  for (const entry of imported) {
    for (const track of entry.record.work.tracking ?? []) {
      const providerId = trackerProvider(track.serviceId)
      if (providerId === undefined || !/^\d*[1-9]\d*$/.test(track.mediaId)) continue
      if (mappings.some((row: ComicTrackerMapping): boolean =>
        row.comicId === entry.target.id && row.providerId === providerId)) continue
      // Explicit binding in Koma remains account-scoped. Restoring a candidate
      // preserves the title identity without scheduling any remote mutation.
      mappings.push({ comicId: entry.target.id, providerId, providerTitleId: track.mediaId, providerTitle: track.title,
        mappingState: 'candidate', userConfirmed: false, createdAt: entry.record.work.addedAt || Date.now() })
    }
  }
  return mappings
}
