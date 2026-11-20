import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool, util } from '@kit.ArkTS'
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME, PersistedComic, PersistedLibraryCategory, PersistedLibraryStoreDocument,
  PersistedChapter, readLibraryStoreDocument,
} from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter, ChapterReadingState, ReaderSessionDocumentSnapshot,
  READER_PROGRESS_PERSISTENCE_FILE_NAME, appReaderSessionStore, serializeReaderSessionForDevice,
} from '../model/ReaderSessionStore'
import {
  DEFAULT_READER_PREFERENCES, ReaderDeviceSyncPreferences, ReaderImageFitMode, ReaderPageMode, ReaderPreferencesStore,
  ReaderSeriesModeOverride,
} from '../model/ReaderPreferencesStore'
import { ReadingDirection, ReadingProgress } from '../model/ComicModels'
import { SourceReadHistoryEntry } from '../model/SourceReaderSession'
import { normalizeSearchHistoryEntries, parseStoredSearchHistory, SearchHistoryEntry, SearchHistoryStore } from '../model/SearchHistoryStore'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import type { LibrarySmartCategory, LibrarySmartFilter } from '../model/LibrarySmartCategory'
import { SourceIndexDeviceSyncSnapshot, SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { isValidHttpUrl, normalizeIndexUrl, SourceIndexRepository, subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'
import { DeviceSyncOwner, SyncApplyGroup } from './DeviceSyncOwner'
import { isSyncReplica, SyncEdit, SyncFact, SyncGroup } from './DeviceSyncFacts'
import {
  CATEGORY_SYNC_PREFIX, safeSyncSearch, syncCatalogAddress, syncCatalogRecordKey, syncCoverAddress, SyncChapterCatalog, SyncPositionValue, SyncReaderMode, SyncRecentValue, SyncSearchValue, SyncSubscription,
  SyncWorkLabel, syncKey, syncKeyParts, syncPublicLabel, syncReadingIdentity, syncReadingPosition,
  syncSearchIdentity, syncShelfLabel, syncShelfMove, syncShelfMoveDestination,
  syncGroupVisibleValue, SyncShelfMove, SyncSmartCategory, SyncWorkSlice,
} from './DeviceSyncData'
import { DeviceSyncStorage, SyncGroupState, SyncLocalDocument, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision, SyncPreparedReceipt, SyncReadingReceipt, SyncSavedConnection,
  SyncReadingRestoreCandidate, SyncRestoreEdit } from './DeviceSyncStorage'
import { deviceSyncActionCaptureKey, deviceSyncCaptureKey, SyncCapturedReadingEdit, SyncReadingActionCapture,
  SyncReadingCapture, SyncLocalShelfMove } from './DeviceSyncSignals'
import { syncDigest } from './DeviceSyncWire'
import { packInputRows } from './DeviceSyncPlanner'
import {
  appendReadingChapter, appendReadingProgress, buildSyncReadingSnapshot, recentFromLocal,
  rememberLibraryIdentity, rememberChapterIdentity, rememberHistoryIdentity, rememberFactIdentity,
  SyncLocalReadingWork, SyncProjectedReadingSnapshot, validDate,
} from './DeviceSyncReadingSnapshot'
import { FAVORITE, READ_LATER, categoryAliases, categoryMembershipAliases,
  emptySyncLibrary, matchesShelfWork, originalCategoryName, PreparedSyncShelf,
  prepareSyncShelfDocument, sharedCategoryRecord, shelfSourceCover, shelfWork, smartCategoryKey,
  SyncKeptShelfDetails, SyncLocalCategory, SyncProjection, SyncResumeProof, SyncSourceIdentity, toLocalCategory,
  toSharedCategory } from './DeviceSyncShelfApply'

const SYNC_PROJECTION = 'device-sync-projection.v1.json'
const SYNC_JOURNAL = 'device-sync-local-commit.v1.json'

export interface SyncShelfRemoval {
  id: string
  title: string
  source: string
  work: string
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
function projectReadingSnapshot(directory: string, projectionName: string, archive: string,
  facts: string[]): SyncProjectedReadingSnapshot {
  // Keep the input files, UTF-8 decoding and row projection in one worker.
  // The caller only needs the revision and projected reading records.
  const input = [projectionName, LIBRARY_STORE_PERSISTENCE_FILE_NAME, READER_PROGRESS_PERSISTENCE_FILE_NAME]
    .map((name: string): string | null => {
      const path = directory + '/' + name
      return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : null
    })
  return buildSyncReadingSnapshot(directory, input[1], input[2], input[0] ?? '', archive, facts)
}

@Concurrent
function prepareSyncShelf(raw: string | null, changes: SyncLocalValue[], projectionText: string,
  acceptedRemoval: string, replica: string): PreparedSyncShelf {
  return prepareSyncShelfDocument(raw, changes, projectionText, acceptedRemoval, replica)
}

@Concurrent
function serializeSyncReading(reading: ReaderSessionDocumentSnapshot): string {
  return serializeReaderSessionForDevice(reading)
}

@Concurrent
function parseSyncLibrary(raw: string): PersistedLibraryStoreDocument {
  return readLibraryStoreDocument(raw)
}

@Concurrent
function projectSearchHistorySnapshot(payload: string): SyncLocalSnapshot {
  const entries = parseStoredSearchHistory(payload)
  const terms = new Map<string, SearchHistoryEntry>()
  for (const item of entries) {
    if (!safeSyncSearch(item.query)) continue
    const key = syncSearchIdentity(item.query)
    if ((terms.get(key)?.updatedAt ?? 0) <= item.updatedAt) terms.set(key, item)
  }
  const values: SyncLocalValue[] = []
  const labels: Record<string, string> = {}
  terms.forEach((item: SearchHistoryEntry, term: string): void => {
    const key = syncKey(['query', term])
    const value: SyncSearchValue = { text: item.query, date: item.updatedAt }
    values.push({ key, value: JSON.stringify(value) })
    labels[key] = item.query
  })
  return { values, labels, revision: syncDigest(JSON.stringify(entries)), skipped: 0 }
}

function clonePrefs(prefs: ReaderDeviceSyncPreferences): ReaderDeviceSyncPreferences {
  return JSON.parse(JSON.stringify(prefs)) as ReaderDeviceSyncPreferences
}

function row(values: SyncLocalValue[], key: string[], value: string | boolean | Object): void {
  values.push({ key: syncKey(key), value: JSON.stringify(value) })
}

async function scanSyncSnapshotRows<T>(rows: T[], work: SyncWorkSlice, guard: (() => void) | undefined,
  visit: (row: T) => void): Promise<void> {
  for (const item of rows) {
    const pause = work.pause()
    if (pause !== undefined) { await pause; guard?.() }
    visit(item)
  }
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

function knownWork(source: string | undefined, work: string | undefined): SyncSourceIdentity | undefined {
  return source !== undefined && work !== undefined && syncReadingIdentity(source, work) ? { source, work } : undefined
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

  private sharedSmartRule(rule: LibrarySmartFilter, projection: SyncProjection): LibrarySmartFilter {
    const value = rule.value
    if (rule.method !== 'category' || value === undefined || value === 'uncategorized') return rule
    const mapping = projection.categories.find((row: SyncLocalCategory): boolean => row.local === value)
    const shared = value.startsWith(CATEGORY_SYNC_PREFIX) ? value.slice(CATEGORY_SYNC_PREFIX.length) : ''
    // Keep a deleted category's identity so the rule continues to match
    // nothing until that category reappears. Never map by the displayed name.
    const category = mapping?.shared ?? (isSyncReplica(shared) ? shared : toSharedCategory(value, projection, this.storage.load().replica))
    return { method: rule.method, value: category, exclude: rule.exclude }
  }

  private readingFacts(): SyncFact[] {
    return this.storage.load().active?.groups.find((item: SyncGroupState): boolean => item.id === 'reading')?.facts ?? []
  }

  localReadingRecent(capture: SyncReadingCapture): SyncRecentValue {
    return capture.recent ?? recentFromLocal(capture.source, capture.chapterId, capture.date, capture.page,
      this.readingIdentities().get(capture.comicId))
  }

  readingIdentities(): Map<string, SyncLocalReadingWork> {
    const result = new Map<string, SyncLocalReadingWork>()
    const reading = this.reading()
    this.library().comics.forEach((comic: PersistedComic): void => { rememberLibraryIdentity(result, comic) })
    reading.chapters.forEach((chapter: ChapterReadingState): void => { rememberChapterIdentity(result, chapter) })
    reading.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => { rememberHistoryIdentity(result, entry) })
    this.readingFacts().forEach((fact: SyncFact): void => { rememberFactIdentity(result, fact) })
    return result
  }

  async snapshot(group: SyncGroup, verify: boolean, guard?: () => void, shelfSpace?: string,
    includeReadingLabels: boolean = true): Promise<SyncLocalSnapshot> {
    await this.recoverPendingLocalRollback()
    guard?.()
    // An explicit first-merge read has a per-review cancellation guard. It does
    // not turn the service on or grant unrelated owner requests permission.
    const values: SyncLocalValue[] = []
    const labels: Record<string, string> = {}
    let skipped = 0
    if (group === 'search-history') {
      const payload = await new SearchHistoryStore(this.context).captureDeviceSyncPayload()
      guard?.()
      const snapshot = await taskpool.execute(projectSearchHistorySnapshot, payload) as SyncLocalSnapshot
      guard?.()
      hiTraceMeter.traceByValue('KomaDeviceSyncSearchSnapshotRows', snapshot.values.length)
      return snapshot
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
    if (group === 'reading' && !includeReadingLabels && (!verify || !this.readingRestoreArchive())) {
      if (verify && !BackupRestoreActivity.deviceSyncIsCommitting() &&
        !appReaderSessionStore(this.context.filesDir).flush()) throw new Error('sync_local_busy')
      guard?.()
      const snapshot = await this.automaticReadingSnapshot(guard)
      if (!verify || !this.readingRestoreArchive()) return snapshot
      // A restore can appear while the worker runs. Keep the explicit proof
      // path, including its comparison to the archived reading identities.
    }
    const side = await readSnapshotFile(this.path(SYNC_PROJECTION))
    const rawLibrary = await readSnapshotFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME))
    const projection = this.projection(side ?? null)
    const parsed = await this.libraryForSnapshot(rawLibrary, group === 'shelf')
    const library = parsed.library
    guard?.()
    const work = new SyncWorkSlice()
    if (group === 'shelf') {
      const categories = (library.customCategories ?? []).slice().sort((a: PersistedLibraryCategory,
        b: PersistedLibraryCategory): number => a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
      const order: string[] = []
      const protectedKeys: string[] = []
      const replica = this.storage.load().replica
      categories.forEach((category: PersistedLibraryCategory): void => {
        if (sharedCategoryRecord(category.id, projection, replica) === undefined) return
        for (const alias of categoryAliases(category.id, projection, replica)) {
          order.push(alias.shared)
          const name = originalCategoryName(category.name, alias)
          row(values, ['category', alias.shared], name)
          labels[syncKey(['category', alias.shared])] = name
          if (category.isPrivate !== undefined) {
            row(values, ['category-privacy', alias.shared], category.isPrivate)
            labels[syncKey(['category-privacy', alias.shared])] = name
          }
        }
      })
      if (order.length > 0) row(values, ['order'],
        JSON.stringify(order) === JSON.stringify(projection.projectedOrder) ? projection.categoryOrder ?? order : order)
      for (const category of library.smartCategories ?? []) {
        const key = smartCategoryKey(category.id)
        const mapping = projection.categories.find((item: SyncLocalCategory): boolean => item.local === category.id)
        const name = mapping?.displayedName === category.name ? mapping.originalName ?? category.name : category.name
        const definition: SyncSmartCategory = { name, order: category.sortOrder, createdAt: category.createdAt,
          filters: category.filters.map((rule: LibrarySmartFilter): LibrarySmartFilter => this.sharedSmartRule(rule, projection)) }
        const value = JSON.stringify(definition)
        if (value.length > 8192) {
          protectedKeys.push(key)
          skipped++
        } else {
          values.push({ key, value })
          labels[key] = name
        }
      }
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
          for (const key of categoryMembershipAliases(category, comic.id, projection, replica)) {
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
        if (book !== undefined) {
          for (const id of book.categoryIds ?? []) {
            memberships.push(...categoryMembershipAliases(id, book.id, projection, replica))
          }
        }
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
    const identities = new Map<string, SyncLocalReadingWork>()
    await scanSyncSnapshotRows(library.comics, work, guard, (comic: PersistedComic): void =>
      rememberLibraryIdentity(identities, comic))
    await scanSyncSnapshotRows(reading.chapters, work, guard, (chapter: ChapterReadingState): void =>
      rememberChapterIdentity(identities, chapter))
    await scanSyncSnapshotRows(reading.sourceHistory, work, guard, (entry: SourceReadHistoryEntry): void =>
      rememberHistoryIdentity(identities, entry))
    const factsByKey = new Map<string, SyncFact>()
    await scanSyncSnapshotRows(knownFacts, work, guard, (fact: SyncFact): void => {
      rememberFactIdentity(identities, fact)
      factsByKey.set(fact.key, fact)
    })
    guard?.()
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
    hiTraceMeter.traceByValue('KomaDeviceSyncReadingSnapshotFacts', factsByKey.size)
    for (const progress of reading.progress) {
      const pause = work.pause()
      if (pause !== undefined) { await pause; guard?.() }
      readingOutsideScope += appendReadingProgress(values, progress, identities, factsByKey)
    }
    await scanSyncSnapshotRows(reading.chapters, work, guard, (chapter: ChapterReadingState): void =>
      appendReadingChapter(values, chapter, identities, factsByKey))
    const space = this.storage.load().active?.space
    const protectedKeys = this.protectedReadingKeys(reading.syncPositions ?? [], reading.syncActions ?? [], space)
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
      readingHistoryKeys: reading.sourceHistory.map((entry: SourceReadHistoryEntry): string =>
        syncKey(['recent', entry.sourceId, entry.mangaId])),
      protectedKeys,
      restoreEdits: verify && archive !== undefined ? this.restoreReadingEdits(archive, identities) : undefined }
  }

  private protectedReadingKeys(positions: SyncReadingCapture[], syncActions: SyncReadingActionCapture[],
    space: string | undefined): string[] {
    const protectedKeys = new Set<string>()
    const pending = positions.filter((capture: SyncReadingCapture): boolean =>
      capture.space === space && !this.readingAcknowledged(capture))
    pending.forEach((capture: SyncReadingCapture): void => {
      protectedKeys.add(syncKey(['position', capture.source, capture.work, capture.chapterId]))
      if (!this.readingHistoryAcknowledged(capture)) protectedKeys.add(syncKey(['recent', capture.source, capture.work]))
      if (capture.complete) protectedKeys.add(syncKey(['read', capture.source, capture.work, capture.chapterId]))
    })
    const actions = syncActions.filter((capture: SyncReadingActionCapture): boolean =>
      capture.space === space && !this.readingActionAcknowledged(capture))
    actions.forEach((capture: SyncReadingActionCapture): void => {
      capture.edits.forEach((edit: SyncCapturedReadingEdit): void => { protectedKeys.add(edit.key) })
    })
    return Array.from(protectedKeys)
  }

  private async automaticReadingSnapshot(guard?: () => void): Promise<SyncLocalSnapshot> {
    const work = new SyncWorkSlice()
    const facts = this.readingFacts()
    const factChunks = await packInputRows(facts, (): Promise<void> | undefined => work.pause())
    guard?.()
    const space = this.storage.load().active?.space
    const archive = this.storage.load().readingRestoreCandidates?.find((candidate: SyncReadingRestoreCandidate): boolean =>
      candidate.space === space)
    const prepared = await taskpool.execute(projectReadingSnapshot, this.context.filesDir, SYNC_PROJECTION,
      JSON.stringify(archive ?? null), factChunks) as SyncProjectedReadingSnapshot
    guard?.()
    const values: SyncLocalValue[] = []
    for (const chunk of prepared.valueChunks) {
      const pause = work.pause()
      if (pause !== undefined) { await pause; guard?.() }
      const rows = JSON.parse(chunk) as SyncLocalValue[]
      for (const row of rows) values.push(row)
    }
    hiTraceMeter.traceByValue('KomaDeviceSyncReadingSnapshotFacts', facts.length)
    hiTraceMeter.traceByValue('KomaDeviceSyncReadingSnapshotReturnChars',
      prepared.valueChunks.reduce((count: number, chunk: string): number => count + chunk.length, 0))
    return { values, labels: {}, revision: prepared.revision, skipped: prepared.skipped,
      readingOutsideScope: prepared.skipped, readingHistoryKeys: prepared.historyKeys,
      protectedKeys: this.protectedReadingKeys(prepared.positions, prepared.actions, space) }
  }

  private readingRestoreArchive(): SyncReadingRestoreCandidate | undefined {
    const state = this.storage.load()
    return state.readingRestoreCandidates?.find((candidate: SyncReadingRestoreCandidate): boolean =>
      candidate.space === state.active?.space)
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
      const recent = capture.recent ?? recentFromLocal(capture.source, capture.chapterId, capture.date, capture.page,
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
      if (parts[0] === 'smart-category') {
        return !(library.smartCategories ?? []).some((category: LibrarySmartCategory): boolean =>
          smartCategoryKey(category.id) === key)
      }
      if (parts[0] === 'category' || parts[0] === 'category-privacy') {
        return !(library.customCategories ?? []).some((category: PersistedLibraryCategory): boolean =>
          categoryAliases(category.id, projection, this.storage.load().replica).some(row => row.shared === parts[1])) &&
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
      const local = toLocalCategory(parts[3], library, projection, this.storage.load().replica)
      return !(comic.categoryIds ?? []).includes(local)
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
    this.applySubscriptions(group.changes, snapshot)
  }

  async commit(groups: SyncApplyGroup[], expected: SyncOwnerRevision[], prepareCursor: (id: string) => Promise<SyncPreparedReceipt>,
    acceptedRemoval: string = '', stillAllowed?: () => boolean): Promise<void> {
    await this.recoverPendingLocalRollback()
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
      let projection = this.projection(admittedFiles[2] ?? null)
      const originalProjection = JSON.stringify(projection)
      const files: SyncFileImage[] = []
      let previousPreferences: ReaderDeviceSyncPreferences | undefined
      let nextPreferences: ReaderDeviceSyncPreferences | undefined
      let previousSearch: SearchHistoryEntry[] | undefined
      let nextSearch: SearchHistoryEntry[] | undefined
      let previousSubscriptions: SourceIndexDeviceSyncSnapshot | undefined
      let nextSubscriptions: SourceIndexDeviceSyncSnapshot | undefined
      for (const group of groups) {
        // An older client may already have applied both category IDs. Its
        // first complete shelf sync can repair them even with no incoming diff.
        const repairCategories = group.group === 'shelf' && admittedFiles[0] !== undefined &&
          projection.categories.some((row: SyncLocalCategory): boolean => !row.local.startsWith('smart:') &&
            row.mergedInto === undefined && row.originalName !== undefined && row.originalName !== row.displayedName)
        if (group.changes.length === 0 && !repairCategories) continue
        if (group.group === 'shelf') {
          const raw = admittedFiles[0]
          const prepared = await taskpool.execute(prepareSyncShelf, raw ?? null, group.changes,
            JSON.stringify(projection), acceptedRemoval, this.storage.load().replica) as PreparedSyncShelf
          projection = this.projection(prepared.projectionText)
          this.addImage(files, LIBRARY_STORE_PERSISTENCE_FILE_NAME, raw, prepared.libraryText)
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
        const receipt = await prepareCursor(id)
        try {
          if (stillAllowed?.() === false) throw new Error('sync_local_changed')
          receipt.publish()
        } finally {
          await receipt.dispose()
        }
        return
      }
      const journal: LocalJournal = { id, files, filesStarted: false, previousPreferences, nextPreferences, previousSearch, nextSearch,
        previousSubscriptions, nextSubscriptions }
      writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
      let receipt: SyncPreparedReceipt | undefined
      try {
        if (nextPreferences !== undefined) await new ReaderPreferencesStore(this.context).applyDeviceSyncPreferences(nextPreferences)
        if (nextSearch !== undefined) await new SearchHistoryStore(this.context).applyDeviceSyncEntries(nextSearch)
        if (nextSubscriptions !== undefined) await new SourceIndexService(this.context).applyDeviceSyncSnapshot(nextSubscriptions)
        receipt = await prepareCursor(id)
        if (stillAllowed?.() === false || reader.currentDeviceSyncRevision() !== readerRevision ||
          fileNames.some((name: string, index: number): boolean =>
          readFile(this.path(name)) !== admittedFiles[index])) throw new Error('sync_local_changed')
        receipt.check()
        // Keep the owner files and receipt publication in one synchronous turn.
        // A crash before the receipt replacement still rolls back via the journal.
        journal.filesStarted = true
        writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
        for (const image of files) writeAppTextFile(this.path(image.name), image.after)
        receipt.publish()
        fs.unlinkSync(this.path(SYNC_JOURNAL))
      } catch (error) {
        try {
          await this.recoverBeforeStartup()
        } catch (_recoveryError) {
          if (this.storage.load().localReceipt === id) {
            BackupRestoreActivity.blockUntilRestart()
            throw new Error('sync_local_recovery_required')
          }
          BackupRestoreActivity.deferDeviceSyncRollback()
          throw new Error('sync_local_rollback_pending')
        }
        throw error as Error
      } finally {
        await receipt?.dispose()
      }
      const changed = groups.filter((group: SyncApplyGroup): boolean => group.changes.length > 0 ||
        (group.group === 'shelf' && files.some((image: SyncFileImage): boolean => image.name === LIBRARY_STORE_PERSISTENCE_FILE_NAME)))
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

  async recoverPendingLocalRollback(): Promise<void> {
    await BackupRestoreActivity.recoverDeviceSyncRollback((): Promise<void> => this.recoverBeforeStartup())
    if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_recovery_required')
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
      [{ group: 'shelf', revision: snapshot.revision }], (id: string): Promise<SyncPreparedReceipt> => {
        return this.storage.prepareReceipt((state: SyncLocalDocument): void => { state.localReceipt = id }, (): void => {})
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
    await this.commit([{ group: 'shelf', changes }], [{ group: 'shelf', revision: snapshot.revision }], (id: string): Promise<SyncPreparedReceipt> => {
      return this.storage.prepareReceipt((state: SyncLocalDocument): void => { state.localReceipt = id }, (): void => {})
    })
  }

  sourceIdentity(comicId: string): SyncSourceIdentity | undefined {
    const identity = this.readingIdentities().get(comicId)
    return knownWork(identity?.source, identity?.work)
  }

  sharedCategory(id: string): string | undefined {
    return toSharedCategory(id, this.projection(), this.storage.load().replica)
  }

  sharedCategories(id: string): string[] {
    return categoryAliases(id, this.projection(), this.storage.load().replica).map((row: SyncLocalCategory): string => row.shared)
  }

  shelfWorkLabel(source: string, work: string): SyncWorkLabel | undefined {
    const comic = this.library().comics.find((item: PersistedComic): boolean => matchesShelfWork(item, source, work))
    return comic === undefined ? undefined : shelfLabel(comic, source)
  }

  shelfMemberships(source: string, work: string): string[] {
    const comic = this.library().comics.find((item: PersistedComic): boolean => matchesShelfWork(item, source, work))
    const projection = this.projection()
    const categories: string[] = []
    if (comic !== undefined) {
      for (const id of comic.categoryIds ?? []) {
        categories.push(...categoryMembershipAliases(id, comic.id, projection, this.storage.load().replica))
      }
    }
    return categories
  }

}
