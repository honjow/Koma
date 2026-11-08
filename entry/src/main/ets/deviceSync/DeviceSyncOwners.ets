import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool, util } from '@kit.ArkTS'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME, LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, PersistedComic,
  PersistedLibraryCategory, PersistedLibraryStoreDocument, PersistedChapter, assertValidLibraryStoreJson,
  readLibraryStoreDocument,
} from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter, ChapterReadingState, ReaderSessionDocumentSnapshot,
  READER_PROGRESS_PERSISTENCE_FILE_NAME, appReaderSessionStore, serializeReaderSessionForDevice,
} from '../model/ReaderSessionStore'
import {
  DEFAULT_READER_PREFERENCES, ReaderDeviceSyncPreferences, ReaderImageFitMode, ReaderPageMode, ReaderPreferencesStore,
  ReaderSeriesModeOverride,
} from '../model/ReaderPreferencesStore'
import {
  ComicSourceKind, ReadingDirection, ReadingProgress,
  libraryCategoryNameKey, normalizeLibraryCategoryName, normalizeSortKey,
} from '../model/ComicModels'
import { SourceReadHistoryEntry } from '../model/SourceReaderSession'
import { normalizeSearchHistoryEntries, SearchHistoryEntry, SearchHistoryStore } from '../model/SearchHistoryStore'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import { SourceIndexDeviceSyncSnapshot, SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { isValidHttpUrl, normalizeIndexUrl, SourceIndexRepository, subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'
import { DeviceSyncOwner, SyncApplyGroup } from './DeviceSyncOwner'
import { SyncEdit, SyncFact, SyncGroup } from './DeviceSyncFacts'
import {
  safeSyncSearch, syncCatalogAddress, syncCatalogRecordKey, syncCoverAddress, SyncChapterCatalog, SyncPositionValue, SyncReaderMode, SyncRecentValue, SyncSearchValue, SyncSubscription,
  SyncWorkLabel, syncKey, syncKeyParts, syncPublicLabel, syncReadingIdentity, syncReadingPosition,
  syncReadingRecent, syncSearchIdentity, syncShelfIdentity, syncShelfLabel, syncShelfMove, syncShelfMoveDestination,
  syncGroupVisibleValue, SyncShelfMove, SyncWorkSlice,
} from './DeviceSyncData'
import { DeviceSyncStorage, SyncGroupState, SyncLocalDocument, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision, SyncReadingReceipt, SyncSavedConnection,
  SyncReadingRestoreCandidate, SyncRestoreEdit } from './DeviceSyncStorage'
import { deviceSyncActionCaptureKey, deviceSyncCaptureKey, SyncCapturedReadingEdit, SyncReadingActionCapture,
  SyncReadingCapture, SyncLocalShelfMove } from './DeviceSyncSignals'
import { syncDigest } from './DeviceSyncWire'

const SYNC_PROJECTION = 'device-sync-projection.v1.json'
const SYNC_JOURNAL = 'device-sync-local-commit.v1.json'
const CATEGORY_SYNC_PREFIX = 'custom_sync_'
const FAVORITE = 'favorite'
const READ_LATER = 'read_later'

export interface SyncLocalCategory {
  local: string
  shared: string
  localOnly: boolean
  originalName?: string
  displayedName?: string
}

interface SyncSourceIdentity {
  source: string
  work: string
}

interface SyncLocalReadingWork extends SyncSourceIdentity {
  comic?: PersistedComic
  history?: SourceReadHistoryEntry
}

interface SyncResumeProof {
  comicId: string
  chapterId: string
  received?: boolean
}

export interface SyncShelfRemoval {
  id: string
  title: string
  source: string
  work: string
}

interface SyncKeptShelfDetails {
  id: string
  notes?: string
  cover?: string
}

interface SyncProjection {
  categories: SyncLocalCategory[]
  blockedShelf: string[]
  readingProofs: SyncResumeProof[]
  acceptedQueries: SyncLocalValue[]
  receivedQueries: SyncLocalValue[]
  subscriptions: SyncLocalValue[]
  acceptedSubscriptionKey?: string
  categoryOrder?: string[]
  projectedOrder?: string[]
  adoptedSharedCatalog?: boolean
  keptShelfDetails?: SyncKeptShelfDetails[]
  receivedRecent?: string[]
}

interface SyncFileImage {
  name: string
  before?: string
  after: string
}

interface LocalJournal {
  id: string
  files: SyncFileImage[]
  filesStarted?: boolean
  previousPreferences?: ReaderDeviceSyncPreferences
  nextPreferences?: ReaderDeviceSyncPreferences
  previousSearch?: SearchHistoryEntry[]
  nextSearch?: SearchHistoryEntry[]
  previousSubscriptions?: SourceIndexDeviceSyncSnapshot
  nextSubscriptions?: SourceIndexDeviceSyncSnapshot
}

interface SyncParsedLibrary {
  library: PersistedLibraryStoreDocument
  catalogs?: Record<string, SyncLocalValue[]>
}

function readFile(path: string): string | undefined {
  return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : undefined
}

async function readSnapshotFile(path: string): Promise<string | undefined> {
  return await fs.access(path) ? await fs.readText(path, { encoding: 'utf-8' }) : undefined
}

@Concurrent
function hashSyncSnapshot(parts: string[]): string {
  return syncDigest(parts.join(''))
}

@Concurrent
function parseReadingSnapshot(directory: string, persistedText: string | null): ReaderSessionDocumentSnapshot {
  return new AppFilesReaderSessionPersistenceAdapter(directory).loadSnapshot(persistedText)
}

@Concurrent
function serializeSyncLibrary(library: PersistedLibraryStoreDocument): string {
  const json = JSON.stringify(library)
  assertValidLibraryStoreJson(json)
  return json
}

@Concurrent
function serializeSyncReading(reading: ReaderSessionDocumentSnapshot): string {
  return serializeReaderSessionForDevice(reading)
}

function emptySyncLibrary(): PersistedLibraryStoreDocument {
  return { schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, comics: [], customCategories: [] }
}

@Concurrent
function parseSyncLibrary(raw: string): PersistedLibraryStoreDocument {
  return readLibraryStoreDocument(raw)
}

function clonePrefs(prefs: ReaderDeviceSyncPreferences): ReaderDeviceSyncPreferences {
  return JSON.parse(JSON.stringify(prefs)) as ReaderDeviceSyncPreferences
}

function row(values: SyncLocalValue[], key: string[], value: string | boolean | Object): void {
  values.push({ key: syncKey(key), value: JSON.stringify(value) })
}

function makeProgress(comicId: string, chapterId: string, position: SyncPositionValue, isRead: boolean,
  updatedAt: number, previous?: ReadingProgress): ReadingProgress {
  return { comicId, chapterId, pageIndex: position.page, totalPages: position.total,
    progressRatio: (position.page + 1) / position.total, completed: isRead, updatedAt,
    columnMode: previous?.columnMode }
}

function datedProgress(source: ReadingProgress, updatedAt: number): ReadingProgress {
  return { comicId: source.comicId, chapterId: source.chapterId, pageId: source.pageId,
    pageIndex: source.pageIndex, totalPages: source.totalPages, progressRatio: source.progressRatio,
    completed: source.completed, updatedAt, columnMode: source.columnMode }
}

function syncUuid(text: string): string {
  const hash = syncDigest(text)
  return hash.substring(0, 8) + '-' + hash.substring(8, 12) + '-' + hash.substring(12, 16) + '-' +
    hash.substring(16, 20) + '-' + hash.substring(20, 32)
}

function knownWork(source: string | undefined, work: string | undefined): SyncSourceIdentity | undefined {
  return source !== undefined && work !== undefined && syncReadingIdentity(source, work) ? { source, work } : undefined
}

function shelfWork(comic: PersistedComic): SyncSourceIdentity | undefined {
  const source = comic.sourceRuntimeId
  const work = comic.remoteResourceId
  return source !== undefined && work !== undefined && comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY &&
    comic.remoteServerId === undefined && syncShelfIdentity(source, work) && sourceLibraryComicId(source, work) === comic.id ?
    { source, work } : undefined
}

@Concurrent
function syncChapterCatalogRows(source: string, work: string, ids: string[], date: number): SyncLocalValue[] {
  const blocks: string[][] = []
  let current: string[] = []
  let length = 2
  for (const id of ids) {
    if (!syncReadingIdentity(source, work, id)) return []
    const size = JSON.stringify(id).length + 1
    if (length + size > 4096 && current.length > 0) { blocks.push(current); current = []; length = 2 }
    current.push(id)
    length += size
  }
  if (current.length > 0) blocks.push(current)
  const digest = syncDigest(JSON.stringify(ids))
  const header: SyncChapterCatalog = { digest, count: ids.length, blocks: blocks.length, date }
  const values: SyncLocalValue[] = []
  values.push({ key: syncKey(['chapter-catalog', source, work]), value: JSON.stringify(header) })
  blocks.forEach((ids: string[], index: number): void => {
    values.push({ key: syncKey(['chapter-catalog-block', source, work, digest, index.toString()]), value: JSON.stringify(ids) })
  })
  return values
}

function shelfLabel(comic: PersistedComic, source: string): SyncWorkLabel {
  return syncShelfLabel(source, comic.title, comic.sourceMetadata?.sourceName ?? '', comic.sourcePath)
}

function shelfSourceCover(comic?: PersistedComic): string | undefined {
  return syncCoverAddress(comic?.sourceCoverUri ?? (comic?.customCoverUri === undefined ? comic?.coverUri : undefined))
}

function matchesShelfWork(comic: PersistedComic, source: string, work: string): boolean {
  const identity = shelfWork(comic)
  return identity?.source === source && identity?.work === work
}

function indexShelfWorks(comics: PersistedComic[]): Map<string, PersistedComic> {
  const rows = new Map<string, PersistedComic>()
  for (const comic of comics) {
    const identity = shelfWork(comic)
    if (identity === undefined) continue
    const key = syncKey([identity.source, identity.work])
    if (!rows.has(key)) rows.set(key, comic)
  }
  return rows
}

function validDate(date: number): number {
  const now = Date.now()
  return Number.isFinite(date) && date >= 0 ? Math.min(Math.round(date), now + 24 * 60 * 60 * 1000) : 0
}

export class KomaDeviceSyncOwners implements DeviceSyncOwner {
  private readonly context: common.UIAbilityContext
  private readonly storage: DeviceSyncStorage
  private publisher?: (groups: SyncGroup[]) => void
  private snapshotLibraryRaw: string | undefined
  private snapshotLibrary: SyncParsedLibrary | undefined

  constructor(context: common.UIAbilityContext, storage: DeviceSyncStorage) {
    this.context = context
    this.storage = storage
  }

  publishWith(publisher: (groups: SyncGroup[]) => void): void {
    this.publisher = publisher
  }

  readingLabels(keys: string[], snapshot?: PersistedLibraryStoreDocument,
    sourceHistory?: SourceReadHistoryEntry[]): Record<string, string> {
    const labels: Record<string, string> = {}
    if (keys.length === 0) return labels
    const library = snapshot ?? this.library()
    const history = sourceHistory ?? this.reading().sourceHistory
    for (const key of keys) {
      const parts = syncKeyParts(key)
      if (parts.length < 3) continue
      const comic = library.comics.find((item: PersistedComic): boolean =>
        item.sourceRuntimeId === parts[1] && item.remoteResourceId === parts[2])
      const entry = history.find((item: SourceReadHistoryEntry): boolean => item.sourceId === parts[1] && item.mangaId === parts[2])
      const title = comic?.title ?? entry?.title
      if (title === undefined) continue
      const chapter = parts.length > 3 ? comic?.chapters.find((item: PersistedChapter): boolean => item.id === parts[3])?.title ??
        (entry?.chapterId === parts[3] ? entry.chapterTitle : undefined) ?? parts[3] : ''
      labels[key] = title + (chapter ? ' · ' + chapter : '')
    }
    return labels
  }

  private path(name: string): string {
    return this.context.filesDir + '/' + name
  }

  private projection(json: string | null | undefined = readFile(this.path(SYNC_PROJECTION))): SyncProjection {
    if (json === undefined || json === null) {
      return { categories: [], blockedShelf: [], readingProofs: [], acceptedQueries: [],
        receivedQueries: [], subscriptions: [] }
    }
    return JSON.parse(json) as SyncProjection
  }

  private library(): PersistedLibraryStoreDocument {
    const raw = readFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME))
    if (raw === undefined) {
      return emptySyncLibrary()
    }
    return readLibraryStoreDocument(raw)
  }

  private async libraryForSnapshot(raw: string | undefined, includeCatalogs: boolean): Promise<SyncParsedLibrary> {
    if (this.snapshotLibrary !== undefined && this.snapshotLibraryRaw === raw &&
      (!includeCatalogs || this.snapshotLibrary.catalogs !== undefined)) return this.snapshotLibrary
    const library = this.snapshotLibraryRaw === raw && this.snapshotLibrary !== undefined
      ? this.snapshotLibrary.library
      : (raw === undefined ? emptySyncLibrary() : await taskpool.execute(parseSyncLibrary, raw) as PersistedLibraryStoreDocument)
    const document: SyncParsedLibrary = { library }
    if (includeCatalogs) {
      const catalogs: Record<string, SyncLocalValue[]> = {}
      for (const comic of library.comics) {
        const identity = shelfWork(comic)
        const ids = comic.sourceMetadata?.sharedChapterIds
        if (identity === undefined || ids === undefined) continue
        catalogs[comic.id] = await taskpool.execute(syncChapterCatalogRows, identity.source, identity.work, ids,
          comic.sourceMetadata?.chapterCatalogUpdatedAt ?? 0) as SyncLocalValue[]
      }
      document.catalogs = catalogs
    }
    this.snapshotLibraryRaw = raw
    this.snapshotLibrary = document
    return document
  }

  private reading(): ReaderSessionDocumentSnapshot {
    return new AppFilesReaderSessionPersistenceAdapter(this.context.filesDir).loadSnapshot()
  }

  private toSharedCategory(local: string, projection: SyncProjection): string | undefined {
    const existing = projection.categories.find((row: SyncLocalCategory): boolean => row.local === local)
    if (existing?.localOnly === true) return undefined
    if (local === FAVORITE) return 'builtin-favorite'
    if (local === READ_LATER) return 'builtin-read-later'
    return existing?.shared ?? syncUuid(this.storage.load().replica + ':category:' + local)
  }

  private sharedCategoryRecord(local: string, projection: SyncProjection): string | undefined {
    // Legacy sync keys carry membership only. Keep the promoted local name and
    // order out of category records, whose wire identity must be a UUID.
    if (local === FAVORITE || local === READ_LATER) return undefined
    return this.toSharedCategory(local, projection)
  }

  private toLocalCategory(shared: string, library: PersistedLibraryStoreDocument, projection: SyncProjection): string {
    if (shared === 'builtin-favorite') return FAVORITE
    if (shared === 'builtin-read-later') return READ_LATER
    const existing = (library.customCategories ?? []).find((row: PersistedLibraryCategory): boolean =>
      this.toSharedCategory(row.id, projection) === shared)
    if (existing !== undefined) return existing.id
    const base = CATEGORY_SYNC_PREFIX + shared
    let id = base
    let suffix = 2
    while ((library.customCategories ?? []).some((row: PersistedLibraryCategory): boolean => row.id === id)) {
      id = base + '_' + suffix++
    }
    return id
  }

  private sourceIdentities(library: PersistedLibraryStoreDocument, reading: ReaderSessionDocumentSnapshot,
    knownFacts: SyncFact[] = []):
    Map<string, SyncLocalReadingWork> {
    const result = new Map<string, SyncLocalReadingWork>()
    library.comics.forEach((comic: PersistedComic): void => {
      const source = comic.sourceRuntimeId
      const work = comic.remoteResourceId
      if (source !== undefined && work !== undefined) result.set(comic.id, { source, work, comic })
    })
    reading.chapters.forEach((chapter: ChapterReadingState): void => {
      const identity = chapter.sourceIdentity
      if (identity !== undefined && !result.has(chapter.comicId) &&
        syncReadingIdentity(identity.source, identity.work) && sourceLibraryComicId(identity.source, identity.work) === chapter.comicId) {
        result.set(chapter.comicId, { source: identity.source, work: identity.work })
      }
    })
    reading.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
      result.set(entry.comicId, { source: entry.sourceId, work: entry.mangaId, history: entry,
        comic: result.get(entry.comicId)?.comic })
    })
    for (const fact of knownFacts) {
      const parts = syncKeyParts(fact.key)
      const id = sourceLibraryComicId(parts[1], parts[2])
      if (!result.has(id)) result.set(id, { source: parts[1], work: parts[2] })
    }
    return result
  }

  private readingFacts(): SyncFact[] {
    return this.storage.load().active?.groups.find((item: SyncGroupState): boolean => item.id === 'reading')?.facts ?? []
  }

  private recentFromLocal(source: string, chapter: string, date: number, page: number | undefined,
    work?: SyncLocalReadingWork): SyncRecentValue {
    const history = work?.history
    const comic = work?.comic
    const chapterTitle = history?.chapterId === chapter ? history.chapterTitle : undefined
    return syncReadingRecent(source, chapter, validDate(date), history?.title ?? comic?.title ?? source,
      history?.sourceName ?? comic?.sourceMetadata?.sourceName ?? source,
      chapterTitle ?? comic?.chapters.find((row: PersistedChapter): boolean => row.id === chapter)?.title ?? '',
      page, history?.mangaUrl ?? comic?.sourcePath)
  }

  localReadingRecent(capture: SyncReadingCapture): SyncRecentValue {
    return capture.recent ?? this.recentFromLocal(capture.source, capture.chapterId, capture.date, capture.page,
      this.readingIdentities().get(capture.comicId))
  }

  readingIdentities(): Map<string, SyncLocalReadingWork> {
    return this.sourceIdentities(this.library(), this.reading(), this.readingFacts())
  }

  async snapshot(group: SyncGroup, verify: boolean, guard?: () => void, shelfSpace?: string,
    includeReadingLabels: boolean = true): Promise<SyncLocalSnapshot> {
    // An explicit first-merge read has a per-review cancellation guard. It does
    // not turn the service on or grant unrelated owner requests permission.
    const values: SyncLocalValue[] = []
    const labels: Record<string, string> = {}
    let skipped = 0
    if (group === 'search-history') {
      const entries = await new SearchHistoryStore(this.context).load()
      const terms = new Map<string, SearchHistoryEntry>()
      entries.forEach((item: SearchHistoryEntry): void => {
        if (!safeSyncSearch(item.query)) return
        const key = syncSearchIdentity(item.query)
        if ((terms.get(key)?.updatedAt ?? 0) <= item.updatedAt) terms.set(key, item)
      })
      terms.forEach((item: SearchHistoryEntry, term: string): void => {
        const value: SyncSearchValue = { text: item.query, date: item.updatedAt }
        row(values, ['query', term], value)
        labels[syncKey(['query', term])] = item.query
      })
      return { values, labels, revision: syncDigest(JSON.stringify(entries)), skipped }
    }
    if (group === 'source-subscriptions') {
      const snapshot = await new SourceIndexService(this.context).captureDeviceSyncSnapshot()
      const seen = new Set<string>()
      snapshot.repositories.forEach((repo: SourceIndexRepository): void => {
        const identity = subscriptionIdentity(repo.url)
        const address = identity
        if (!syncCatalogAddress(address) || !syncCatalogAddress(identity) || seen.has(identity)) return
        seen.add(identity)
        const value: SyncSubscription = { address, label: syncPublicLabel(repo.customName ?? '', 120) }
        const key = syncCatalogRecordKey(identity)
        values.push({ key, value: JSON.stringify(value) })
        labels[key] = value.label || value.address
      })
      return { values, labels, revision: syncDigest(JSON.stringify(snapshot)), skipped }
    }
    const side = await readSnapshotFile(this.path(SYNC_PROJECTION))
    const projection = this.projection(side ?? null)
    const rawLibrary = await readSnapshotFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME))
    const parsed = await this.libraryForSnapshot(rawLibrary, group === 'shelf')
    const library = parsed.library
    guard?.()
    const work = new SyncWorkSlice()
    if (group === 'shelf') {
      const categories = (library.customCategories ?? []).slice().sort((a: PersistedLibraryCategory,
        b: PersistedLibraryCategory): number => a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
      const order: string[] = []
      categories.forEach((category: PersistedLibraryCategory): void => {
        const key = this.sharedCategoryRecord(category.id, projection)
        if (key === undefined) return
        order.push(key)
        const mapping = projection.categories.find((item: SyncLocalCategory): boolean => item.local === category.id)
        const name = mapping?.displayedName === category.name ? mapping.originalName ?? category.name : category.name
        row(values, ['category', key], name)
        labels[syncKey(['category', key])] = name
      })
      if (order.length > 0) row(values, ['order'],
        JSON.stringify(order) === JSON.stringify(projection.projectedOrder) ? projection.categoryOrder ?? order : order)
      for (const comic of library.comics) {
        const pause = work.pause()
        if (pause !== undefined) { await pause; guard?.() }
        const identity = shelfWork(comic)
        if (identity === undefined || projection.blockedShelf.includes(comic.id)) {
          skipped++
          continue
        }
        const label = shelfLabel(comic, identity.source)
        row(values, ['book', identity.source, identity.work], label)
        const cover = shelfSourceCover(comic)
        if (cover !== undefined) row(values, ['cover', identity.source, identity.work], cover)
        labels[syncKey(['book', identity.source, identity.work])] = label.title
        for (const catalog of parsed.catalogs?.[comic.id] ?? []) values.push(catalog)
        comic.categoryIds?.forEach((category: string): void => {
          const key = this.toSharedCategory(category, projection)
          if (key !== undefined) {
            row(values, ['member', identity.source, identity.work, key], true)
            labels[syncKey(['member', identity.source, identity.work, key])] = label.title + ' · ' +
              (categories.find((item: PersistedLibraryCategory): boolean => item.id === category)?.name ?? category)
          }
        })
      }
      const state = this.storage.load()
      const space = shelfSpace ?? state.active?.space
      const connection = state.active?.space === space ? state.active :
        state.archives?.find((item: SyncSavedConnection): boolean => item.space === space)
      const staged = connection?.groups.find((item: SyncGroupState): boolean => item.id === 'shelf')
      const previouslyStaged = new Map<string, SyncFact>((staged?.facts ?? []).map((fact: SyncFact): [string, SyncFact] => [fact.key, fact]))
      const protectedKeys: string[] = []
      library.syncShelfMoves?.forEach((move: SyncLocalShelfMove): void => {
        if (move.space !== space) return
        const key = syncKey(['book', move.source, move.work])
        if (values.some((value: SyncLocalValue): boolean => value.key === key)) return
        const target = move.target
        if (target === undefined) {
          protectedKeys.push(key)
          return
        }
        const sent = previouslyStaged.get(key)?.barriers.find((edit: SyncEdit): boolean => {
          const old = syncShelfMove(edit.value)
          return edit.version.replica === state.replica && old?.toSource === target.toSource && old?.toWork === target.toWork
        })
        if (sent !== undefined) {
          // An unrelated category edit must not generate a new migration.
          values.push({ key, value: sent.value })
          return
        }
        const book = library.comics.find((comic: PersistedComic): boolean => matchesShelfWork(comic, target.toSource, target.toWork))
        const memberships: string[] = []
        book?.categoryIds?.forEach((id: string): void => {
          const category = this.toSharedCategory(id, projection)
          if (category !== undefined) memberships.push(category)
        })
        const value = JSON.stringify({ toSource: target.toSource, toWork: target.toWork,
          categories: Array.from(new Set<string>(memberships)).sort() } as SyncShelfMove)
        if (value.length > 8192) protectedKeys.push(key)
        else values.push({ key, value })
      })
      const revision = await taskpool.execute(hashSyncSnapshot, [rawLibrary ?? '', side ?? '']) as string
      return { values, labels, protectedKeys, revision, skipped }
    }
    if (verify && !BackupRestoreActivity.deviceSyncIsCommitting() &&
      !appReaderSessionStore(this.context.filesDir).flush()) throw new Error('sync_local_busy')
    const rawReading = await readSnapshotFile(this.path(READER_PROGRESS_PERSISTENCE_FILE_NAME))
    const reading = await taskpool.execute(parseReadingSnapshot, this.context.filesDir, rawReading ?? null) as ReaderSessionDocumentSnapshot
    guard?.()
    const knownFacts = group === 'reading' ? this.readingFacts() : []
    const identities = this.sourceIdentities(library, reading, knownFacts)
    if (group === 'reader-settings') {
      const preferences = await new ReaderPreferencesStore(this.context).captureDeviceSyncPreferences()
      const mode: SyncReaderMode = { mode: preferences.mode.pageMode, direction: preferences.mode.readingDirection }
      row(values, ['global', 'mode'], mode)
      row(values, ['global', 'animation'], preferences.pageTurnAnimation)
      row(values, ['global', 'page-number'], preferences.showPageNumber)
      row(values, ['global', 'image-fit'], preferences.imageFitMode)
      for (const id of Object.keys(preferences.books)) {
        const identity = identities.get(id)
        if (identity === undefined) {
          skipped++
          continue
        }
        const book = preferences.books[id]
        const label = library.comics.find((comic: PersistedComic): boolean => comic.id === id)?.title
        if (label !== undefined) labels[syncKey(['book-mode', identity.source, identity.work])] = label
        row(values, ['book-mode', identity.source, identity.work],
          { mode: book.pageMode, direction: book.readingDirection } as SyncReaderMode)
      }
      // Global controls always have a real local value; a shared tombstone
      // cannot remove that setting. Optional per-book overrides can be removed.
      const defaultKeys: string[] = []
      const defaults = DEFAULT_READER_PREFERENCES
      if (mode.mode === defaults.pageMode && mode.direction === defaults.readingDirection) {
        defaultKeys.push(syncKey(['global', 'mode']))
      }
      if (preferences.pageTurnAnimation === defaults.pageTurnAnimation) defaultKeys.push(syncKey(['global', 'animation']))
      if (preferences.showPageNumber === defaults.showPageNumber) defaultKeys.push(syncKey(['global', 'page-number']))
      if (preferences.imageFitMode === defaults.imageFitMode) defaultKeys.push(syncKey(['global', 'image-fit']))
      const revision = await taskpool.execute(hashSyncSnapshot, [JSON.stringify(preferences), rawLibrary ?? '', rawReading ?? '']) as string
      return { values, revision, skipped, labels,
        defaultKeys,
        unsetKeys: preferences.unsetFields?.map((name: string): string => syncKey(['global', name])),
        retainedDeletionKeys: values.filter((item: SyncLocalValue): boolean => syncKeyParts(item.key)[0] === 'global')
          .map((item: SyncLocalValue): string => item.key) }
    }
    let readingOutsideScope = 0
    const protectedKeys = new Set<string>()
    const knownValues = new Map<string, string>()
    for (const fact of knownFacts) {
      const pause = work.pause()
      if (pause !== undefined) { await pause; guard?.() }
      const value = syncGroupVisibleValue('reading', fact)
      if (value !== undefined) knownValues.set(fact.key, value)
    }
    // The owner's persisted chapter/page is sufficient for export. Source
    // package and account checks belong to opening the chapter on each device.
    for (const progress of reading.progress) {
      const pause = work.pause()
      if (pause !== undefined) { await pause; guard?.() }
      const identity = identities.get(progress.comicId)
      if (identity === undefined || !syncReadingIdentity(identity.source, identity.work, progress.chapterId)) {
        readingOutsideScope++
        continue
      }
      const recentKey = syncKey(['recent', identity.source, identity.work])
      const cover = shelfSourceCover(identity.comic) ?? syncCoverAddress(identity.history?.coverUri)
      if (cover !== undefined) row(values, ['cover', identity.source, identity.work], cover)
      const known = knownValues.get(recentKey)
      const saved = known === undefined ? undefined : JSON.parse(known) as SyncRecentValue
      if (known !== undefined && saved?.chapter === progress.chapterId && saved.date === validDate(progress.updatedAt)) {
        values.push({ key: recentKey, value: known })
        continue
      }
      const position = syncReadingPosition(progress.pageIndex, progress.totalPages)
      row(values, ['recent', identity.source, identity.work],
        this.recentFromLocal(identity.source, progress.chapterId, progress.updatedAt, position?.page, identity))
    }
    for (const chapter of reading.chapters) {
      const pause = work.pause()
      if (pause !== undefined) { await pause; guard?.() }
      const identity = identities.get(chapter.comicId)
      if (identity === undefined || !syncReadingIdentity(identity.source, identity.work, chapter.chapterId)) continue
      const suffix = [identity.source, identity.work, chapter.chapterId]
      const positionKey = syncKey(['position'].concat(suffix))
      const known = knownValues.get(positionKey)
      const saved = known === undefined ? undefined : JSON.parse(known) as SyncPositionValue
      const position = chapter.position === undefined ? undefined :
        syncReadingPosition(chapter.position.pageIndex, chapter.position.totalPages, chapter.position.updatedAt)
      if (position !== undefined) {
        if (known !== undefined && saved?.page === position.page && saved.total === position.total) {
          values.push({ key: positionKey, value: known })
        } else {
          row(values, ['position'].concat(suffix), position)
        }
      }
      if (chapter.isRead) row(values, ['read'].concat(suffix), true)
      if (chapter.bookmarked === true) row(values, ['bookmark'].concat(suffix), true)
    }
    const space = this.storage.load().active?.space
    const pending = (reading.syncPositions ?? []).filter((capture: SyncReadingCapture): boolean =>
      capture.space === space && !this.readingAcknowledged(capture))
    pending.forEach((capture: SyncReadingCapture): void => {
      protectedKeys.add(syncKey(['position', capture.source, capture.work, capture.chapterId]))
      if (!this.readingHistoryAcknowledged(capture)) protectedKeys.add(syncKey(['recent', capture.source, capture.work]))
      if (capture.complete) protectedKeys.add(syncKey(['read', capture.source, capture.work, capture.chapterId]))
    })
    const actions = (reading.syncActions ?? []).filter((capture: SyncReadingActionCapture): boolean =>
      capture.space === space && !this.readingActionAcknowledged(capture))
    actions.forEach((capture: SyncReadingActionCapture): void => {
      capture.edits.forEach((edit: SyncCapturedReadingEdit): void => { protectedKeys.add(edit.key) })
    })
    const archive = this.storage.load().readingRestoreCandidates?.find((candidate: SyncReadingRestoreCandidate): boolean =>
      candidate.space === space)
    if (includeReadingLabels) {
      const knownLabels = this.readingLabels(knownFacts.map((item: SyncFact): string => item.key), library, reading.sourceHistory)
      for (const key of Object.keys(knownLabels)) if (labels[key] === undefined) labels[key] = knownLabels[key]
    }
    const revision = await taskpool.execute(hashSyncSnapshot, [rawLibrary ?? '', rawReading ?? '', side ?? '',
      JSON.stringify(archive ?? null)]) as string
    return { values, labels, revision,
      skipped: readingOutsideScope, readingOutsideScope,
      protectedKeys: Array.from(protectedKeys),
      restoreEdits: verify && archive !== undefined ? this.restoreReadingEdits(archive, identities) : undefined }
  }

  private restoreReadingEdits(archive: SyncReadingRestoreCandidate,
    identities: Map<string, SyncLocalReadingWork>): SyncRestoreEdit[] {
    const result = new Map<string, SyncRestoreEdit>()
    const lastAction = new Map<string, string>()
    for (const action of archive.actions) {
      if (!syncReadingIdentity(action.source, action.work, action.chapterId || undefined)) continue
      for (const edit of action.edits) {
        const kind = edit.kind === 'reset' && edit.value === '' ? 'delete' : edit.kind
        const value = edit.value
        const previous = result.get(edit.key)
        if (previous?.bundle !== undefined && kind === 'set') previous.followUp = value
        else result.set(edit.key, { key: edit.key, value, kind, observed: edit.observed,
          bundle: action.edits.length > 1 ? action.id : undefined })
        lastAction.set(edit.key, action.id)
      }
    }
    for (const capture of archive.positions) {
      if (!syncReadingIdentity(capture.source, capture.work, capture.chapterId)) continue
      const position = syncReadingPosition(capture.page, capture.total, capture.date)
      if (position === undefined) continue
      const recent = capture.recent ?? this.recentFromLocal(capture.source, capture.chapterId, capture.date, capture.page,
        identities.get(capture.comicId))
      const save = (key: string, value: string): void => {
        const priorAction = lastAction.get(key)
        if (priorAction !== undefined && !capture.observedActions.includes(priorAction)) return
        const previous = result.get(key)
        if (previous?.bundle !== undefined) previous.followUp = value
        else result.set(key, { key, value, kind: 'set', label: recent.title + ' · ' + recent.chapterTitle })
      }
      save(syncKey(['position', capture.source, capture.work, capture.chapterId]), JSON.stringify(position))
      save(syncKey(['recent', capture.source, capture.work]), JSON.stringify(recent))
      if (capture.complete) save(syncKey(['read', capture.source, capture.work, capture.chapterId]), 'true')
    }
    return Array.from(result.values())
  }

  readingAcknowledged(capture: SyncReadingCapture): boolean {
    const key = deviceSyncCaptureKey(capture)
    return this.storage.load().readingReceipts?.some((item: SyncReadingReceipt): boolean =>
      item.key === key && item.id === capture.id) === true
  }

  readingHistoryAcknowledged(capture: SyncReadingCapture): boolean {
    const key = 'history:' + deviceSyncCaptureKey(capture)
    return this.storage.load().readingReceipts?.some((item: SyncReadingReceipt): boolean =>
      item.key === key && item.id === capture.id) === true
  }

  readingActionAcknowledged(capture: SyncReadingActionCapture): boolean {
    return this.readingActionReceipt(capture) !== undefined
  }

  readingActionReceipt(capture: SyncReadingActionCapture): SyncReadingReceipt | undefined {
    const key = deviceSyncActionCaptureKey(capture)
    return this.storage.load().readingReceipts?.find((item: SyncReadingReceipt): boolean => item.key === key)
  }

  async removed(group: SyncGroup, keys: string[]): Promise<string[]> {
    if (group !== 'shelf') return []
    const rawLibrary = await readSnapshotFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME))
    const library = (await this.libraryForSnapshot(rawLibrary, false)).library
    const projection = this.projection(await readSnapshotFile(this.path(SYNC_PROJECTION)) ?? null)
    const comics = new Map<string, PersistedComic>()
    for (const comic of library.comics) if (!comics.has(comic.id)) comics.set(comic.id, comic)
    const space = this.storage.load().active?.space
    return keys.filter((key: string): boolean => {
      const parts = syncKeyParts(key)
      if (parts[0] === 'category') {
        return !(library.customCategories ?? []).some((category: PersistedLibraryCategory): boolean =>
          this.toSharedCategory(category.id, projection) === parts[1]) &&
          !projection.categories.some((category: SyncLocalCategory): boolean => category.shared === parts[1] && category.localOnly)
      }
      if (parts[0] !== 'book' && parts[0] !== 'member') return false
      const id = sourceLibraryComicId(parts[1], parts[2])
      if (projection.blockedShelf.includes(id)) return false
      if (library.syncShelfMoves?.some((move: SyncLocalShelfMove): boolean =>
        move.space === space && move.source === parts[1] && move.work === parts[2])) return false
      const comic = comics.get(id)
      if (comic === undefined) return true
      if (!matchesShelfWork(comic, parts[1], parts[2])) return false
      if (parts[0] === 'book') return false
      const local = this.toLocalCategory(parts[3], library, projection)
      return !(comic.categoryIds ?? []).includes(local)
    })
  }

  private applyChapterCatalogs(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument): void {
    const values = new Map<string, string>()
    changes.forEach((item: SyncLocalValue): void => { if (item.value !== '') values.set(item.key, item.value) })
    let works: Map<string, PersistedComic> | undefined
    changes.forEach((change: SyncLocalValue): void => {
      const parts = syncKeyParts(change.key)
      if (parts[0] !== 'chapter-catalog' || change.value === '') return
      if (works === undefined) works = indexShelfWorks(library.comics)
      const comic = works.get(syncKey([parts[1], parts[2]]))
      if (comic === undefined) return
      const header = JSON.parse(change.value) as SyncChapterCatalog
      const known = comic.sourceMetadata?.sharedChapterIds
      let ids: string[] = []
      if (known !== undefined && syncDigest(JSON.stringify(known)) === header.digest) ids = known.slice()
      else {
        if (header.blocks > values.size) throw new Error('sync_catalog_incomplete')
        for (let index = 0; index < header.blocks; index++) {
          const block = values.get(syncKey(['chapter-catalog-block', parts[1], parts[2], header.digest, index.toString()]))
          if (block === undefined) throw new Error('sync_catalog_incomplete')
          ids = ids.concat(JSON.parse(block) as string[])
        }
      }
      if (ids.length !== header.count || new Set<string>(ids).size !== header.count ||
        syncDigest(JSON.stringify(ids)) !== header.digest) throw new Error('sync_catalog_incomplete')
      comic.sourceMetadata = comic.sourceMetadata ?? {}
      comic.sourceMetadata.sharedChapterIds = ids
      comic.sourceMetadata.chapterCatalogUpdatedAt = header.date
      comic.chapterCount = ids.length
    })
  }

  private uniqueCategoryName(name: string, used: Set<string>): string {
    const original = normalizeLibraryCategoryName(name)
    let value = original
    let index = 2
    while (used.has(libraryCategoryNameKey(value))) {
      const suffix = ' (' + index++ + ')'
      value = original.substring(0, 40 - suffix.length).trimEnd() + suffix
    }
    used.add(libraryCategoryNameKey(value))
    return value
  }

  private applyShelf(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument, projection: SyncProjection,
    acceptedRemoval: string = ''): void {
    const categories = library.customCategories ?? []
    library.customCategories = categories
    const names = new Set<string>((library.smartCategories ?? []).map(item => libraryCategoryNameKey(item.name)))
    const rename = new Set<string>()
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'category' && change.value !== '') rename.add(this.toLocalCategory(key[1], library, projection))
    })
    categories.forEach((category: PersistedLibraryCategory): void => {
      if (!rename.has(category.id)) names.add(libraryCategoryNameKey(category.name))
    })
    const now = Date.now()
    changes.filter((change: SyncLocalValue): boolean => syncKeyParts(change.key)[0] === 'category')
      .sort((a: SyncLocalValue, b: SyncLocalValue): number => a.key < b.key ? -1 : a.key === b.key ? 0 : 1)
      .forEach((change: SyncLocalValue): void => {
        const shared = syncKeyParts(change.key)[1]
        const id = this.toLocalCategory(shared, library, projection)
        const existing = categories.find((category: PersistedLibraryCategory): boolean => category.id === id)
        if (change.value === '') {
          if (existing === undefined) return
          const privateMembers = library.comics.some((comic: PersistedComic): boolean =>
            (comic.categoryIds ?? []).includes(id) && !changes.some((change: SyncLocalValue): boolean => {
              const key = syncKeyParts(change.key)
              return key[0] === 'member' && key[3] === shared && change.value === '' &&
                comic.sourceRuntimeId === key[1] && comic.remoteResourceId === key[2]
            }))
          const deviceSettings = (library.categoryDisplayStrategies ?? []).some(item => item.categoryId === id)
          const smartDependency = (library.smartCategories ?? []).some(item => JSON.stringify(item).includes(JSON.stringify(id)))
          if (privateMembers || deviceSettings || smartDependency) {
            projection.categories = projection.categories.filter((row: SyncLocalCategory): boolean => row.local !== id)
            projection.categories.push({ local: id, shared, localOnly: true })
          } else {
            categories.splice(categories.indexOf(existing), 1)
            library.comics.forEach((comic: PersistedComic): void => {
              comic.categoryIds = comic.categoryIds?.filter((value: string): boolean => value !== id)
            })
          }
          return
        }
        const originalName = JSON.parse(change.value) as string
        const name = this.uniqueCategoryName(originalName, names)
        if (existing !== undefined) {
          existing.name = name
          existing.updatedAt = now
        } else {
          categories.push({ id, name, sortOrder: categories.length, createdAt: now, updatedAt: now })
        }
        projection.categories = projection.categories.filter((row: SyncLocalCategory): boolean => row.local !== id)
        projection.categories.push({ local: id, shared, localOnly: false, originalName, displayedName: name })
      })
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] !== 'book' || syncShelfMove(change.value) !== undefined) return
      const id = sourceLibraryComicId(key[1], key[2])
      const existing = library.comics.find((comic: PersistedComic): boolean => comic.id === id)
      if (existing !== undefined && !matchesShelfWork(existing, key[1], key[2])) return
      const kept = projection.keptShelfDetails?.find((entry: SyncKeptShelfDetails): boolean => entry.id === id)
      library.syncShelfMoves = library.syncShelfMoves?.filter((move: SyncLocalShelfMove): boolean =>
        move.source !== key[1] || move.work !== key[2])
      if (change.value === '') {
        if (existing === undefined) return
        if (id !== acceptedRemoval && (existing.personalNotes || existing.customCoverUri)) {
          if (!projection.blockedShelf.includes(id)) projection.blockedShelf.push(id)
          return
        }
        if (id === acceptedRemoval) {
          projection.blockedShelf = projection.blockedShelf.filter((value: string): boolean => value !== id)
          const details: SyncKeptShelfDetails = { id, notes: existing.personalNotes, cover: existing.customCoverUri }
          projection.keptShelfDetails = (projection.keptShelfDetails ?? []).filter((entry: SyncKeptShelfDetails): boolean =>
            entry.id !== id).concat(details)
        }
        library.comics = library.comics.filter((comic: PersistedComic): boolean => comic.id !== id)
      } else if (existing === undefined) {
        const label = JSON.parse(change.value) as SyncWorkLabel
        library.comics.push({ id, title: label.title, sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
          sourcePath: label.workUrl ?? 'source://' + key[1] + '/' + key[2], sourceRuntimeId: key[1], remoteResourceId: key[2],
          sourceMetadata: { sourceName: label.sourceName }, sortTitle: normalizeSortKey(label.title),
          preferredDirection: ReadingDirection.RIGHT_TO_LEFT, chapters: [], chapterCount: 0, pageCount: 0,
          personalNotes: kept?.notes, customCoverUri: kept?.cover, coverUri: kept?.cover,
          createdAt: now, updatedAt: now, lastImportedAt: now })
      } else {
        const label = JSON.parse(change.value) as SyncWorkLabel
        if (label.workUrl !== undefined && existing.sourcePath.startsWith('source://')) existing.sourcePath = label.workUrl
        projection.blockedShelf = projection.blockedShelf.filter((value: string): boolean => value !== id)
        if (kept !== undefined) {
          existing.personalNotes = existing.personalNotes ?? kept.notes
          if (existing.customCoverUri === undefined && kept.cover !== undefined) {
            existing.sourceCoverUri = existing.sourceCoverUri ?? existing.coverUri
            existing.customCoverUri = kept.cover
            existing.coverUri = kept.cover
          }
        }
      }
      if (kept !== undefined && change.value !== '') {
        projection.keptShelfDetails = projection.keptShelfDetails?.filter((entry: SyncKeptShelfDetails): boolean => entry.id !== id)
      }
    })
    let works: Map<string, PersistedComic> | undefined
    const byWork = (source: string, work: string): PersistedComic | undefined => {
      if (works === undefined) works = indexShelfWorks(library.comics)
      return works.get(syncKey([source, work]))
    }
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'cover' && change.value !== '') {
        const comic = byWork(key[1], key[2])
        if (comic !== undefined && shelfSourceCover(comic) === undefined) {
          const cover = JSON.parse(change.value) as string
          if (comic.customCoverUri !== undefined) comic.sourceCoverUri = comic.sourceCoverUri || cover
          else comic.coverUri = comic.coverUri || cover
        }
        return
      }
      if (key[0] === 'order' && change.value !== '') {
        const order = JSON.parse(change.value) as string[]
        const ordered = categories.slice().sort((a: PersistedLibraryCategory,
          b: PersistedLibraryCategory): number => a.sortOrder - b.sortOrder)
        const shared = ordered.filter((category: PersistedLibraryCategory): boolean =>
          this.sharedCategoryRecord(category.id, projection) !== undefined)
        shared.sort((a: PersistedLibraryCategory, b: PersistedLibraryCategory): number => {
          const aid = this.toSharedCategory(a.id, projection) ?? ''
          const bid = this.toSharedCategory(b.id, projection) ?? ''
          const ai = order.indexOf(aid)
          const bi = order.indexOf(bid)
          if (ai >= 0 && bi >= 0) return ai - bi
          if (ai >= 0) return -1
          if (bi >= 0) return 1
          return aid < bid ? -1 : aid === bid ? 0 : 1
        })
        projection.categoryOrder = order
        projection.projectedOrder = shared.map((item: PersistedLibraryCategory): string => this.toSharedCategory(item.id, projection) ?? '')
        let next = 0
        ordered.forEach((category: PersistedLibraryCategory, index: number): void => {
          if (this.sharedCategoryRecord(category.id, projection) === undefined) category.sortOrder = index
          else shared[next++].sortOrder = index
        })
      }
      if (key[0] !== 'member') return
      const comic = byWork(key[1], key[2])
      if (comic === undefined) return
      const local = this.toLocalCategory(key[3], library, projection)
      if (local !== FAVORITE && local !== READ_LATER && !categories.some((item: PersistedLibraryCategory): boolean => item.id === local)) return
      const next = (comic.categoryIds ?? []).filter((id: string): boolean => id !== local)
      if (change.value !== '') next.push(local)
      comic.categoryIds = next
    })
    // The engine resolves the winner and any chain. Verify the actual target
    // again in this same library write, after adds, deletes and memberships.
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      const move = key[0] === 'book' ? syncShelfMove(change.value) : undefined
      if (move === undefined) return
      const target = library.comics.find((comic: PersistedComic): boolean => matchesShelfWork(comic, move.toSource, move.toWork))
      if (target === undefined || move.categories?.some((category: string): boolean =>
        !(target.categoryIds ?? []).includes(this.toLocalCategory(category, library, projection)))) return
      const id = sourceLibraryComicId(key[1], key[2])
      const existing = library.comics.find((comic: PersistedComic): boolean => matchesShelfWork(comic, key[1], key[2]))
      if (existing === undefined) return
      if (id !== acceptedRemoval && (existing.personalNotes || existing.customCoverUri)) {
        if (!projection.blockedShelf.includes(id)) projection.blockedShelf.push(id)
        return
      }
      if (id === acceptedRemoval) {
        const details: SyncKeptShelfDetails = { id, notes: existing.personalNotes, cover: existing.customCoverUri }
        projection.keptShelfDetails = (projection.keptShelfDetails ?? []).filter((item: SyncKeptShelfDetails): boolean =>
          item.id !== id).concat(details)
      }
      projection.blockedShelf = projection.blockedShelf.filter((value: string): boolean => value !== id)
      library.comics = library.comics.filter((comic: PersistedComic): boolean => comic.id !== id)
    })
  }

  private applyReading(changes: SyncLocalValue[], snapshot: ReaderSessionDocumentSnapshot, projection: SyncProjection): void {
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'recent' || key[0] === 'cover') return
      const id = sourceLibraryComicId(key[1], key[2])
      let chapter = snapshot.chapters.find((state: ChapterReadingState): boolean => state.comicId === id && state.chapterId === key[3])
      if (chapter === undefined) {
        chapter = { comicId: id, chapterId: key[3], isRead: false, updatedAt: 0 }
        snapshot.chapters.push(chapter)
      }
      chapter.sourceIdentity = { source: key[1], work: key[2] }
      if (key[0] === 'position') {
        projection.readingProofs = projection.readingProofs.filter((proof: SyncResumeProof): boolean =>
          proof.comicId !== id || proof.chapterId !== key[3])
        if (change.value === '') {
          chapter.position = undefined
        } else {
          const position = JSON.parse(change.value) as SyncPositionValue
          chapter.position = makeProgress(id, key[3], position, chapter.isRead,
            position.date ?? chapter.position?.updatedAt ?? 0, chapter.position)
          projection.readingProofs.push({ comicId: id, chapterId: key[3], received: true })
        }
      } else if (key[0] === 'read') {
        chapter.isRead = change.value === 'true'
      } else if (key[0] === 'bookmark') {
        chapter.bookmarked = change.value === 'true'
      }
      if (chapter.position !== undefined) chapter.position.completed = chapter.isRead
      const recent = snapshot.progress.findIndex((item: ReadingProgress): boolean => item.comicId === id && item.chapterId === key[3])
      if (recent >= 0) {
        const old = snapshot.progress[recent]
        if (chapter.position !== undefined) snapshot.progress[recent] = datedProgress(chapter.position, old.updatedAt)
        else {
          old.completed = chapter.isRead
          if (key[0] === 'position' && change.value === '') {
            old.pageIndex = 0
            old.totalPages = 0
            old.pageId = undefined
            old.progressRatio = 0
          }
        }
      }
    })
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] !== 'recent') return
      const id = sourceLibraryComicId(key[1], key[2])
      const previous = snapshot.progress.find((item: ReadingProgress): boolean => item.comicId === id)
      snapshot.progress = snapshot.progress.filter((item: ReadingProgress): boolean => item.comicId !== id)
      const oldSource = snapshot.sourceHistory.find((item: SourceReadHistoryEntry): boolean => item.comicId === id)
      snapshot.sourceHistory = snapshot.sourceHistory.filter((item: SourceReadHistoryEntry): boolean => item.comicId !== id)
      projection.receivedRecent = (projection.receivedRecent ?? []).filter((comic: string): boolean => comic !== id)
      if (change.value === '') return
      projection.receivedRecent.push(id)
      const value = JSON.parse(change.value) as SyncRecentValue
      const known = snapshot.chapters.find((item: ChapterReadingState): boolean => item.comicId === id && item.chapterId === value.chapter)
      const date = validDate(value.date)
      const exact = known?.position !== undefined && (value.savedPage === undefined || value.savedPage === known.position.pageIndex)
      const progress: ReadingProgress = exact && known?.position !== undefined ? datedProgress(known.position, date) :
        { comicId: id, chapterId: value.chapter, pageIndex: 0, totalPages: 0, progressRatio: 0,
          completed: known?.isRead === true, updatedAt: date, columnMode: previous?.columnMode }
      snapshot.progress.push(progress)
      snapshot.sourceHistory.push({ comicId: id, sourceId: key[1], mangaId: key[2], title: value.title,
        sourceName: value.sourceName, chapterId: value.chapter, chapterTitle: value.chapterTitle,
        readingFormat: oldSource?.readingFormat,
        mangaUrl: oldSource?.mangaUrl ?? value.workUrl, coverUri: oldSource?.coverUri })
    })
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] !== 'cover' || change.value === '') return
      const id = sourceLibraryComicId(key[1], key[2])
      const history = snapshot.sourceHistory.find((item: SourceReadHistoryEntry): boolean =>
        item.comicId === id && item.sourceId === key[1] && item.mangaId === key[2])
      if (history !== undefined && !history.coverUri) history.coverUri = JSON.parse(change.value) as string
    })
  }

  private applyPreferences(changes: SyncLocalValue[], preferences: ReaderDeviceSyncPreferences): void {
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'book-mode' && syncReadingIdentity(key[1], key[2])) {
        const id = sourceLibraryComicId(key[1], key[2])
        if (change.value === '') {
          const remaining: Record<string, ReaderSeriesModeOverride> = {}
          Object.keys(preferences.books).forEach((key: string): void => {
            if (key !== id) remaining[key] = preferences.books[key]
          })
          preferences.books = remaining
        }
        else {
          const mode = JSON.parse(change.value) as SyncReaderMode
          preferences.books[id] = { pageMode: mode.mode as ReaderPageMode,
            readingDirection: mode.direction as ReadingDirection } as ReaderSeriesModeOverride
        }
      } else if (key[0] === 'global' && change.value !== '') {
        if (key[1] === 'mode') {
          const mode = JSON.parse(change.value) as SyncReaderMode
          preferences.mode = { pageMode: mode.mode as ReaderPageMode, readingDirection: mode.direction as ReadingDirection }
        } else if (key[1] === 'animation') preferences.pageTurnAnimation = change.value === 'true'
        else if (key[1] === 'page-number') preferences.showPageNumber = change.value === 'true'
        else if (key[1] === 'image-fit') preferences.imageFitMode = JSON.parse(change.value) as ReaderImageFitMode
      }
    })
  }

  private applySearch(changes: SyncLocalValue[], entries: SearchHistoryEntry[]): SearchHistoryEntry[] {
    let next = entries.slice()
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      const term = key[1]
      if (change.value === '') {
        next = next.filter((item: SearchHistoryEntry): boolean => syncSearchIdentity(item.query) !== term ||
          (key.length === 3 && item.syncSourceSet !== key[2]))
        return
      }
      const value = JSON.parse(change.value) as SyncSearchValue
      const current = next.find((item: SearchHistoryEntry): boolean => syncSearchIdentity(item.query) === term)
      if (current === undefined) {
        next.push(key.length === 3 ? { query: value.text, updatedAt: value.date, sourceFilter: 'source', syncSourceSet: key[2] } :
          { query: value.text, updatedAt: value.date })
      } else if ((key.length === 2 || current.updatedAt < value.date) &&
        (current.updatedAt !== value.date || current.query !== value.text)) {
        next[next.indexOf(current)] = { query: value.text, updatedAt: value.date, sourceFilter: current.sourceFilter,
          librarySource: current.librarySource }
      }
    })
    return normalizeSearchHistoryEntries(next)
  }

  private applySubscriptions(changes: SyncLocalValue[], snapshot: SourceIndexDeviceSyncSnapshot): SourceIndexDeviceSyncSnapshot {
    let repositories = snapshot.repositories.slice()
    changes.forEach((change: SyncLocalValue): void => {
      if (change.value === '') {
        repositories = repositories.filter((repo: SourceIndexRepository): boolean => syncCatalogRecordKey(subscriptionIdentity(repo.url)) !== change.key)
        return
      }
      const value = JSON.parse(change.value) as SyncSubscription
      if (!isValidHttpUrl(value.address) || syncCatalogRecordKey(subscriptionIdentity(value.address)) !== change.key) {
        throw new Error('sync_unsupported_value')
      }
      const current = repositories.find((repo: SourceIndexRepository): boolean => syncCatalogRecordKey(subscriptionIdentity(repo.url)) === change.key)
      const label = value.label || undefined
      if (current === undefined) repositories.push({ url: normalizeIndexUrl(value.address), lastUsedAt: 0, customName: label })
      else repositories[repositories.indexOf(current)] = { url: current.url, lastUsedAt: current.lastUsedAt,
        disabled: current.disabled, name: current.name, website: current.website, customName: label }
    })
    const activeUrl = snapshot.activeUrl
    return { repositories, activeUrl: activeUrl === '' || repositories.some((repo: SourceIndexRepository): boolean =>
      subscriptionIdentity(repo.url) === subscriptionIdentity(activeUrl)) ? activeUrl : repositories[0]?.url ?? '' }
  }

  private addImage(files: SyncFileImage[], name: string, before: string | undefined, after: string): void {
    if (before !== after) files.push({ name, before, after })
  }

  async validateChanges(group: SyncApplyGroup): Promise<void> {
    if (group.group !== 'source-subscriptions' || group.changes.length === 0) return
    const snapshot = await new SourceIndexService(this.context).captureDeviceSyncSnapshot()
    SourceIndexService.validateDeviceSyncSnapshot(this.applySubscriptions(group.changes, snapshot))
  }

  async commit(groups: SyncApplyGroup[], expected: SyncOwnerRevision[], saveCursor: (id: string) => void,
    acceptedRemoval: string = '', stillAllowed?: () => boolean): Promise<void> {
    const reader = appReaderSessionStore(this.context.filesDir)
    if (!reader.flush()) throw new Error('sync_local_busy')
    const readerRevision = reader.currentDeviceSyncRevision()
    try {
    await BackupRestoreActivity.runDeviceSyncCommit(async (): Promise<void> => {
      const fileNames = [LIBRARY_STORE_PERSISTENCE_FILE_NAME, READER_PROGRESS_PERSISTENCE_FILE_NAME, SYNC_PROJECTION]
      const admittedFiles = await Promise.all(fileNames.map((name: string): Promise<string | undefined> =>
        readSnapshotFile(this.path(name))))
      for (const target of expected) {
        // These revisions describe the exact persisted inputs. Rebuilding the
        // rows under the commit lock would revalidate an entire library.
        let current: string
        if (target.group === 'shelf') {
          current = await taskpool.execute(hashSyncSnapshot, [admittedFiles[0] ?? '', admittedFiles[2] ?? '']) as string
        } else if (target.group === 'reading') {
          const state = this.storage.load()
          const archive = state.readingRestoreCandidates?.find((candidate: SyncReadingRestoreCandidate): boolean =>
            candidate.space === state.active?.space)
          current = await taskpool.execute(hashSyncSnapshot, [admittedFiles[0] ?? '', admittedFiles[1] ?? '',
            admittedFiles[2] ?? '', JSON.stringify(archive ?? null)]) as string
        } else {
          current = (await this.snapshot(target.group, false)).revision
        }
        if (current !== target.revision) throw new Error('sync_local_changed')
      }
      const projection = this.projection(admittedFiles[2] ?? null)
      const originalProjection = JSON.stringify(projection)
      const files: SyncFileImage[] = []
      let previousPreferences: ReaderDeviceSyncPreferences | undefined
      let nextPreferences: ReaderDeviceSyncPreferences | undefined
      let previousSearch: SearchHistoryEntry[] | undefined
      let nextSearch: SearchHistoryEntry[] | undefined
      let previousSubscriptions: SourceIndexDeviceSyncSnapshot | undefined
      let nextSubscriptions: SourceIndexDeviceSyncSnapshot | undefined
      for (const group of groups) {
        if (group.changes.length === 0) continue
        if (group.group === 'shelf') {
          const raw = admittedFiles[0]
          const library = raw === undefined ? emptySyncLibrary() :
            await taskpool.execute(parseSyncLibrary, raw) as PersistedLibraryStoreDocument
          this.applyShelf(group.changes, library, projection, acceptedRemoval)
          this.applyChapterCatalogs(group.changes, library)
          const json = await taskpool.execute(serializeSyncLibrary, library) as string
          this.addImage(files, LIBRARY_STORE_PERSISTENCE_FILE_NAME, raw, json)
        } else if (group.group === 'reading') {
          const reading = await taskpool.execute(parseReadingSnapshot, this.context.filesDir, admittedFiles[1] ?? null) as ReaderSessionDocumentSnapshot
          this.applyReading(group.changes, reading, projection)
          reading.syncPositions = reading.syncPositions?.filter((capture: SyncReadingCapture): boolean => !this.readingAcknowledged(capture))
          reading.syncActions = reading.syncActions?.filter((capture: SyncReadingActionCapture): boolean =>
            !this.readingActionAcknowledged(capture) || (reading.syncPositions?.length ?? 0) > 0)
          const json = await taskpool.execute(serializeSyncReading, reading) as string
          this.addImage(files, READER_PROGRESS_PERSISTENCE_FILE_NAME, admittedFiles[1], json)
        } else if (group.group === 'reader-settings') {
          previousPreferences = await new ReaderPreferencesStore(this.context).captureDeviceSyncPreferences()
          nextPreferences = clonePrefs(previousPreferences)
          this.applyPreferences(group.changes, nextPreferences)
        } else if (group.group === 'search-history') {
          previousSearch = await new SearchHistoryStore(this.context).load()
          nextSearch = this.applySearch(group.changes, previousSearch)
        } else if (group.group === 'source-subscriptions') {
          previousSubscriptions = await new SourceIndexService(this.context).captureDeviceSyncSnapshot()
          nextSubscriptions = this.applySubscriptions(group.changes, previousSubscriptions)
        }
      }
      const nextProjection = JSON.stringify(projection)
      if (originalProjection !== nextProjection) this.addImage(files, SYNC_PROJECTION, admittedFiles[2], nextProjection)
      const id = util.generateRandomUUID()
      if (files.length === 0 && nextPreferences === undefined && nextSearch === undefined && nextSubscriptions === undefined) {
        if (stillAllowed?.() === false) throw new Error('sync_local_changed')
        saveCursor(id)
        return
      }
      const journal: LocalJournal = { id, files, filesStarted: false, previousPreferences, nextPreferences, previousSearch, nextSearch,
        previousSubscriptions, nextSubscriptions }
      writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
      try {
        if (nextPreferences !== undefined) await new ReaderPreferencesStore(this.context).applyDeviceSyncPreferences(nextPreferences)
        if (nextSearch !== undefined) await new SearchHistoryStore(this.context).applyDeviceSyncEntries(nextSearch)
        if (nextSubscriptions !== undefined) await new SourceIndexService(this.context).applyDeviceSyncSnapshot(nextSubscriptions)
        if (stillAllowed?.() === false || reader.currentDeviceSyncRevision() !== readerRevision ||
          fileNames.some((name: string, index: number): boolean =>
          readFile(this.path(name)) !== admittedFiles[index])) throw new Error('sync_local_changed')
        // File owners commit synchronously. They can accept ordinary edits
        // while Preferences await, but never interleave with this file phase.
        journal.filesStarted = true
        writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
        for (const image of files) writeAppTextFile(this.path(image.name), image.after)
        saveCursor(id)
        fs.unlinkSync(this.path(SYNC_JOURNAL))
      } catch (error) {
        try {
          await this.recoverBeforeStartup()
        } catch (_recoveryError) {
          BackupRestoreActivity.blockUntilRestart()
          throw new Error('sync_local_recovery_required')
        }
        throw error as Error
      }
      const changed = groups.filter((group: SyncApplyGroup): boolean => group.changes.length > 0)
        .map((group: SyncApplyGroup): SyncGroup => group.group)
      if (changed.includes('reading')) reader.reload()
      if (nextPreferences !== undefined) await new ReaderPreferencesStore(this.context).load()
      this.publisher?.(changed)
    })
    } finally {
      // A real Reader gesture during an awaited preference commit remains in
      // the original live owner. Flush only once the short write fence is gone.
      if (reader.currentDeviceSyncRevision() !== readerRevision) reader.flush()
    }
  }

  async recoverBeforeStartup(): Promise<void> {
    const raw = readFile(this.path(SYNC_JOURNAL))
    if (raw === undefined) return
    const journal = JSON.parse(raw) as LocalJournal
    if (!Array.isArray(journal.files) || journal.files.some((image: SyncFileImage): boolean =>
      ![LIBRARY_STORE_PERSISTENCE_FILE_NAME, READER_PROGRESS_PERSISTENCE_FILE_NAME, SYNC_PROJECTION].includes(image.name))) {
      throw new Error('sync_local_journal_invalid')
    }
    const committed = this.storage.load().localReceipt === journal.id
    if (journal.filesStarted !== false) {
      for (const image of journal.files) {
        const body = committed ? image.after : image.before
        if (body !== undefined) writeAppTextFile(this.path(image.name), body)
        else if (fs.accessSync(this.path(image.name))) fs.unlinkSync(this.path(image.name))
      }
      journal.filesStarted = false
      writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
    }
    const prefs = committed ? journal.nextPreferences : journal.previousPreferences
    if (prefs !== undefined) await new ReaderPreferencesStore(this.context).applyDeviceSyncPreferences(prefs)
    const search = committed ? journal.nextSearch : journal.previousSearch
    if (search !== undefined) await new SearchHistoryStore(this.context).applyDeviceSyncEntries(search)
    const subscriptions = committed ? journal.nextSubscriptions : journal.previousSubscriptions
    if (subscriptions !== undefined) await new SourceIndexService(this.context).applyDeviceSyncSnapshot(subscriptions)
    fs.unlinkSync(this.path(SYNC_JOURNAL))
  }

  receivedReadingPosition(comicId: string, chapterId: string): boolean {
    return this.projection().readingProofs.some((proof: SyncResumeProof): boolean =>
      proof.received === true && proof.comicId === comicId && proof.chapterId === chapterId)
  }

  blockedShelfItems(): SyncShelfRemoval[] {
    const pending = this.projection().blockedShelf
    if (pending.length === 0) return []
    const rows: SyncShelfRemoval[] = []
    const library = this.library()
    library.comics.forEach((comic: PersistedComic): void => {
      if (!pending.includes(comic.id)) return
      const identity = shelfWork(comic)
      if (identity !== undefined && this.shelfRemovalValue(identity.source, identity.work, library) !== undefined) {
        rows.push({ id: comic.id, title: comic.title, source: identity.source, work: identity.work })
      }
    })
    return rows
  }

  receivedReading(comicId: string, chapterId: string): boolean {
    const projection = this.projection()
    return projection.receivedRecent?.includes(comicId) === true || projection.readingProofs.some((proof: SyncResumeProof): boolean =>
      proof.received === true && proof.comicId === comicId && proof.chapterId === chapterId)
  }

  async acceptShelfRemoval(item: SyncShelfRemoval): Promise<void> {
    const space = this.storage.load().active?.space
    const snapshot = await this.snapshot('shelf', false)
    if (!this.blockedShelfItems().some((row: SyncShelfRemoval): boolean => row.id === item.id)) return
    const value = this.shelfRemovalValue(item.source, item.work, this.library())
    if (value === undefined) return
    await this.commit([{ group: 'shelf', changes: [{ key: syncKey(['book', item.source, item.work]), value }] }],
      [{ group: 'shelf', revision: snapshot.revision }], (id: string): void => {
        this.storage.update((state: SyncLocalDocument): void => { state.localReceipt = id })
      }, item.id, (): boolean => this.storage.load().active?.space === space &&
        this.shelfRemovalValue(item.source, item.work, this.library()) === value)
  }

  private shelfRemovalValue(source: string, work: string, library: PersistedLibraryStoreDocument): string | undefined {
    const active = this.storage.load().active
    if (!active?.selected.includes('shelf')) return undefined
    const shelf = active.groups.find((group: SyncGroupState): boolean => group.id === 'shelf')
    const facts = new Map<string, SyncFact>((shelf?.facts ?? []).map((fact: SyncFact): [string, SyncFact] => [fact.key, fact]))
    const known = (key: string): boolean => facts.has(key) && shelf?.deferred?.includes(key) !== true
    const visible = (key: string): string | undefined => {
      const fact = facts.get(key)
      return fact === undefined || !known(key) ? undefined : syncGroupVisibleValue('shelf', fact)
    }
    const key = syncKey(['book', source, work])
    if (!known(key)) return undefined
    if (visible(key) === undefined) return ''
    const target = syncShelfMoveDestination(key, visible, known)
    return target !== undefined &&
      library.comics.some((comic: PersistedComic): boolean => matchesShelfWork(comic, target.toSource, target.toWork)) ?
      JSON.stringify(target) : undefined
  }

  async restoreKeptShelfDetails(): Promise<void> {
    const kept = this.projection().keptShelfDetails ?? []
    if (kept.length === 0) return
    const changes: SyncLocalValue[] = []
    this.library().comics.forEach((comic: PersistedComic): void => {
      if (!kept.some((entry: SyncKeptShelfDetails): boolean => entry.id === comic.id)) return
      const identity = shelfWork(comic)
      // Only an existing ordinary shelf entry can recover local personalization.
      // applyShelf's existing-record branch does not consume a remote label.
      if (identity !== undefined) changes.push({ key: syncKey(['book', identity.source, identity.work]),
        value: JSON.stringify(shelfLabel(comic, identity.source)) })
    })
    if (changes.length === 0) return
    const snapshot = await this.snapshot('shelf', false)
    await this.commit([{ group: 'shelf', changes }], [{ group: 'shelf', revision: snapshot.revision }], (id: string): void => {
      this.storage.update((state: SyncLocalDocument): void => { state.localReceipt = id })
    })
  }

  sourceIdentity(comicId: string): SyncSourceIdentity | undefined {
    const identity = this.readingIdentities().get(comicId)
    return knownWork(identity?.source, identity?.work)
  }

  sharedCategory(id: string): string | undefined {
    return this.toSharedCategory(id, this.projection())
  }

  shelfWorkLabel(source: string, work: string): SyncWorkLabel | undefined {
    const comic = this.library().comics.find((item: PersistedComic): boolean => matchesShelfWork(item, source, work))
    return comic === undefined ? undefined : shelfLabel(comic, source)
  }

  shelfMemberships(source: string, work: string): string[] {
    const comic = this.library().comics.find((item: PersistedComic): boolean => matchesShelfWork(item, source, work))
    const projection = this.projection()
    const categories: string[] = []
    comic?.categoryIds?.forEach((id: string): void => {
      const category = this.toSharedCategory(id, projection)
      if (category !== undefined) categories.push(category)
    })
    return categories
  }

}
