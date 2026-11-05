import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import {
  LIBRARY_STORE_PERSISTENCE_FILE_NAME, LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, PersistedComic,
  PersistedLibraryCategory, PersistedLibraryStoreDocument, PersistedChapter, PersistedPage, assertValidLibraryStoreJson,
} from '../model/LibraryPersistence'
import {
  AppFilesReaderSessionPersistenceAdapter, ChapterReadingState, ReaderSessionDocumentSnapshot,
  READER_PROGRESS_PERSISTENCE_FILE_NAME, appReaderSessionStore, serializeReaderSessionForDevice,
} from '../model/ReaderSessionStore'
import {
  ReaderDeviceSyncPreferences, ReaderImageFitMode, ReaderPageMode, ReaderPreferencesStore,
  ReaderSeriesModeOverride,
} from '../model/ReaderPreferencesStore'
import {
  ComicSourceKind, ReadingDirection, ReadingProgress, isBuiltInLibraryCategoryName,
  libraryCategoryNameKey, normalizeLibraryCategoryName, normalizeSortKey,
} from '../model/ComicModels'
import { SourceReadHistoryEntry } from '../model/SourceReaderSession'
import { SearchHistoryEntry, SearchHistoryStore } from '../model/SearchHistoryStore'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import { SourceIndexService } from '../sourceRuntime/SourceIndexService'
import { SourceIndexRepository, subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'
import { DeviceSyncOwner, SyncApplyGroup } from './DeviceSyncEngine'
import { SyncGroup } from './DeviceSyncFacts'
import {
  SYNC_CATALOG_ID, SYNC_OFFICIAL_CATALOG, SyncPositionValue, SyncReaderMode, SyncRecentValue, SyncSubscription,
  SyncWorkLabel, syncChapterBelongsToSource, syncKey, syncKeyParts, syncKnownSource, syncPublicLabel, syncSearchIdentity,
} from './DeviceSyncData'
import { DeviceSyncStorage, SyncLocalSnapshot, SyncLocalValue, SyncOwnerRevision, SyncReadingReceipt, SyncReadingRestoreCandidate,
  SyncRestoreEdit } from './DeviceSyncStorage'
import { deviceSyncActionCaptureKey, deviceSyncCaptureKey, SyncCapturedReadingEdit, SyncReadingActionCapture,
  SyncReadingCapture } from './DeviceSyncSignals'
import { DeviceSyncPublicSources, SyncPublicWorkProof, syncHasTrustedPackage, matchesPublicSyncPageHash,
  matchesPublicSyncPages } from './DeviceSyncPublicSource'
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

interface SyncResumeProof {
  comicId: string
  chapterId: string
  pageTable: string
}

interface SyncProjection {
  categories: SyncLocalCategory[]
  blockedShelf: string[]
  readingProofs: SyncResumeProof[]
  acceptedQueries: SyncLocalValue[]
  receivedQueries: SyncLocalValue[]
  subscriptions: SyncLocalValue[]
  categoryOrder?: string[]
  projectedOrder?: string[]
  adoptedSharedCatalog?: boolean
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
}

function readFile(path: string): string | undefined {
  return fs.accessSync(path) ? fs.readTextSync(path, { encoding: 'utf-8' }) : undefined
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
  return source !== undefined && work !== undefined && syncKnownSource(source) ? { source, work } : undefined
}

function validDate(date: number): number {
  const now = Date.now()
  return Number.isFinite(date) && date >= 0 ? Math.min(Math.round(date), now + 24 * 60 * 60 * 1000) : 0
}

export class KomaDeviceSyncOwners implements DeviceSyncOwner {
  readonly publicSources: DeviceSyncPublicSources = new DeviceSyncPublicSources()
  private readonly context: common.UIAbilityContext
  private readonly storage: DeviceSyncStorage
  private publisher?: (groups: SyncGroup[]) => void

  constructor(context: common.UIAbilityContext, storage: DeviceSyncStorage) {
    this.context = context
    this.storage = storage
  }

  publishWith(publisher: (groups: SyncGroup[]) => void): void {
    this.publisher = publisher
  }

  private path(name: string): string {
    return this.context.filesDir + '/' + name
  }

  private projection(): SyncProjection {
    const json = readFile(this.path(SYNC_PROJECTION))
    if (json === undefined) {
      return { categories: [], blockedShelf: [], readingProofs: [], acceptedQueries: [],
        receivedQueries: [], subscriptions: [] }
    }
    return JSON.parse(json) as SyncProjection
  }

  private library(): PersistedLibraryStoreDocument {
    const raw = readFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME))
    if (raw === undefined) {
      return { schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, comics: [], customCategories: [] }
    }
    assertValidLibraryStoreJson(raw)
    return JSON.parse(raw) as PersistedLibraryStoreDocument
  }

  private reading(): ReaderSessionDocumentSnapshot {
    return new AppFilesReaderSessionPersistenceAdapter(this.context.filesDir).loadSnapshot()
  }

  private toSharedCategory(local: string, projection: SyncProjection): string | undefined {
    if (local === FAVORITE) return 'builtin-favorite'
    if (local === READ_LATER) return 'builtin-read-later'
    const existing = projection.categories.find((row: SyncLocalCategory): boolean => row.local === local)
    if (existing?.localOnly === true) return undefined
    return existing?.shared ?? syncUuid(this.storage.load().replica + ':category:' + local)
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

  private sourceIdentities(library: PersistedLibraryStoreDocument, reading: ReaderSessionDocumentSnapshot):
    Map<string, SyncSourceIdentity> {
    const result = new Map<string, SyncSourceIdentity>()
    library.comics.forEach((comic: PersistedComic): void => {
      const identity = knownWork(comic.sourceRuntimeId, comic.remoteResourceId)
      if (identity !== undefined) result.set(comic.id, identity)
    })
    reading.sourceHistory.forEach((entry: SourceReadHistoryEntry): void => {
      const identity = knownWork(entry.sourceId, entry.mangaId)
      if (identity !== undefined) result.set(entry.comicId, identity)
    })
    return result
  }

  async snapshot(group: SyncGroup, verify: boolean): Promise<SyncLocalSnapshot> {
    const side = readFile(this.path(SYNC_PROJECTION)) ?? ''
    const projection = this.projection()
    const values: SyncLocalValue[] = []
    let skipped = 0
    if (group === 'search-history') {
      const entries = await new SearchHistoryStore(this.context).load()
      return { values: projection.acceptedQueries, revision: syncDigest(side + JSON.stringify(entries)), skipped }
    }
    if (group === 'source-subscriptions') {
      const repositories = await new SourceIndexService(this.context).loadSavedRepositories()
      const official = repositories.find((repo: SourceIndexRepository): boolean =>
        subscriptionIdentity(repo.url) === subscriptionIdentity(SYNC_OFFICIAL_CATALOG))
      if (official !== undefined && projection.adoptedSharedCatalog !== true) {
        const value: SyncSubscription = { address: SYNC_OFFICIAL_CATALOG, label: syncPublicLabel(official.customName ?? '', 120) }
        row(values, ['catalog', SYNC_CATALOG_ID], value)
      }
      return { values, revision: syncDigest(JSON.stringify(repositories) + side), skipped: repositories.length - values.length }
    }
    const rawLibrary = readFile(this.path(LIBRARY_STORE_PERSISTENCE_FILE_NAME)) ?? ''
    const library = this.library()
    if (group === 'shelf') {
      const categories = (library.customCategories ?? []).slice().sort((a: PersistedLibraryCategory,
        b: PersistedLibraryCategory): number => a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
      const order: string[] = []
      categories.forEach((category: PersistedLibraryCategory): void => {
        const key = this.toSharedCategory(category.id, projection)
        if (key === undefined) return
        order.push(key)
        const mapping = projection.categories.find((item: SyncLocalCategory): boolean => item.local === category.id)
        const name = mapping?.displayedName === category.name ? mapping.originalName ?? category.name : category.name
        row(values, ['category', key], name)
      })
      if (order.length > 0) row(values, ['order'],
        JSON.stringify(order) === JSON.stringify(projection.projectedOrder) ? projection.categoryOrder ?? order : order)
      for (const comic of library.comics) {
        const identity = knownWork(comic.sourceRuntimeId, comic.remoteResourceId)
        if (identity === undefined || projection.blockedShelf.includes(comic.id)) {
          skipped++
          continue
        }
        const proof = await this.publicSources.work(identity.source, identity.work, verify)
        if (proof === undefined) {
          skipped++
          continue
        }
        const label: SyncWorkLabel = { title: proof.title, sourceName: proof.sourceName, sourceVersion: proof.sourceVersion }
        row(values, ['book', proof.source, proof.work], label)
        comic.categoryIds?.forEach((category: string): void => {
          const key = this.toSharedCategory(category, projection)
          if (key !== undefined) row(values, ['member', proof.source, proof.work, key], true)
        })
      }
      return { values, revision: syncDigest(rawLibrary + side), skipped }
    }
    if (verify && !BackupRestoreActivity.deviceSyncIsCommitting() &&
      !appReaderSessionStore(this.context.filesDir).flush()) throw new Error('sync_local_busy')
    const rawReading = readFile(this.path(READER_PROGRESS_PERSISTENCE_FILE_NAME)) ?? ''
    const reading = this.reading()
    const identities = this.sourceIdentities(library, reading)
    if (group === 'reader-settings') {
      const preferences = await new ReaderPreferencesStore(this.context).captureDeviceSyncPreferences()
      const mode: SyncReaderMode = { mode: preferences.mode.pageMode, direction: preferences.mode.readingDirection }
      row(values, ['global', 'mode'], mode)
      row(values, ['global', 'animation'], preferences.pageTurnAnimation)
      row(values, ['global', 'page-number'], preferences.showPageNumber)
      row(values, ['global', 'image-fit'], preferences.imageFitMode)
      for (const id of Object.keys(preferences.books)) {
        const identity = identities.get(id)
        if (identity === undefined || await this.publicSources.work(identity.source, identity.work, verify) === undefined) {
          skipped++
          continue
        }
        const book = preferences.books[id]
        row(values, ['book-mode', identity.source, identity.work],
          { mode: book.pageMode, direction: book.readingDirection } as SyncReaderMode)
      }
      return { values, revision: syncDigest(JSON.stringify(preferences) + rawLibrary + rawReading), skipped }
    }
    for (const progress of reading.progress) {
      const identity = identities.get(progress.comicId)
      if (identity === undefined || !syncChapterBelongsToSource(identity.source, identity.work, progress.chapterId)) {
        skipped++
        continue
      }
      const work = await this.publicSources.work(identity.source, identity.work, verify)
      const chapter = work === undefined ? undefined :
        await this.publicSources.chapter(identity.source, identity.work, progress.chapterId, verify)
      if (work === undefined || chapter === undefined) {
        skipped++
        continue
      }
      const savedChapter = library.comics.find((item: PersistedComic): boolean => item.id === progress.comicId)
        ?.chapters.find((item: PersistedChapter): boolean => item.id === progress.chapterId)
      const recorded = projection.readingProofs.some((item: SyncResumeProof): boolean =>
        item.comicId === progress.comicId && item.chapterId === progress.chapterId && item.pageTable === chapter.pageTable)
      if (!recorded && !matchesPublicSyncPages(identity.source, chapter, savedChapter?.pages.map((page: PersistedPage): string => page.uri) ?? [])) {
        skipped++
        continue
      }
      const value: SyncRecentValue = { title: work.title, sourceName: work.sourceName, sourceVersion: work.sourceVersion,
        chapter: progress.chapterId, chapterTitle: chapter.title, date: validDate(progress.updatedAt) }
      row(values, ['recent', identity.source, identity.work], value)
    }
    for (const chapter of reading.chapters) {
      const identity = identities.get(chapter.comicId)
      if (identity === undefined || !syncChapterBelongsToSource(identity.source, identity.work, chapter.chapterId)) continue
      const work = await this.publicSources.work(identity.source, identity.work, verify)
      const proof = work === undefined ? undefined :
        await this.publicSources.chapter(identity.source, identity.work, chapter.chapterId, verify)
      if (proof === undefined) continue
      const position = chapter.position
      const savedChapter = library.comics.find((item: PersistedComic): boolean => item.id === chapter.comicId)
        ?.chapters.find((item: PersistedChapter): boolean => item.id === chapter.chapterId)
      const recorded = projection.readingProofs.some((item: SyncResumeProof): boolean =>
        item.comicId === chapter.comicId && item.chapterId === chapter.chapterId && item.pageTable === proof.pageTable)
      if (position !== undefined && position.totalPages === proof.pages && position.pageIndex >= 0 && position.pageIndex < proof.pages &&
        (recorded || matchesPublicSyncPages(identity.source, proof, savedChapter?.pages.map((page: PersistedPage): string => page.uri) ?? []))) {
        const value: SyncPositionValue = { page: position.pageIndex, total: proof.pages, pageTable: proof.pageTable }
        row(values, ['position', identity.source, identity.work, chapter.chapterId], value)
      }
      if (chapter.isRead) row(values, ['read', identity.source, identity.work, chapter.chapterId], true)
      if (chapter.bookmarked === true) row(values, ['bookmark', identity.source, identity.work, chapter.chapterId], true)
    }
    const space = this.storage.load().active?.space
    const pending = (reading.syncPositions ?? []).filter((capture: SyncReadingCapture): boolean =>
      capture.space === space && !this.readingAcknowledged(capture))
    const protectedKeys = new Set<string>()
    pending.forEach((capture: SyncReadingCapture): void => {
      protectedKeys.add(syncKey(['position', capture.source, capture.work, capture.chapterId]))
      protectedKeys.add(syncKey(['recent', capture.source, capture.work]))
      if (capture.complete) protectedKeys.add(syncKey(['read', capture.source, capture.work, capture.chapterId]))
    })
    const actions = (reading.syncActions ?? []).filter((capture: SyncReadingActionCapture): boolean =>
      capture.space === space && !this.readingActionAcknowledged(capture))
    actions.forEach((capture: SyncReadingActionCapture): void => {
      capture.edits.forEach((edit: SyncCapturedReadingEdit): void => { protectedKeys.add(edit.key) })
    })
    const archive = this.storage.load().readingRestoreCandidates?.find((candidate: SyncReadingRestoreCandidate): boolean =>
      candidate.space === space)
    return { values, revision: syncDigest(rawLibrary + rawReading + side + JSON.stringify(archive ?? null)),
      skipped: skipped + pending.length + actions.length, protectedKeys: Array.from(protectedKeys),
      restoreEdits: verify && archive !== undefined ? await this.verifiedRestoreEdits(archive) : undefined }
  }

  private async verifiedRestoreEdits(archive: SyncReadingRestoreCandidate): Promise<SyncRestoreEdit[]> {
    const result = new Map<string, SyncRestoreEdit>()
    const lastAction = new Map<string, string>()
    for (const action of archive.actions) {
      const chapter = action.chapterId === '' ? undefined :
        await this.publicSources.chapter(action.source, action.work, action.chapterId, true)
      if (action.chapterId !== '' && chapter === undefined) continue
      for (const edit of action.edits) {
        let value = edit.value
        if (edit.kind === 'reset' && value === '') {
          if (chapter === undefined) continue
          const position: SyncPositionValue = { page: 0, total: chapter.pages, pageTable: chapter.pageTable }
          value = JSON.stringify(position)
        }
        result.set(edit.key, { key: edit.key, value, kind: edit.kind, observed: edit.observed })
        lastAction.set(edit.key, action.id)
      }
    }
    for (const capture of archive.positions) {
      const work = await this.publicSources.work(capture.source, capture.work, true)
      const chapter = await this.publicSources.chapter(capture.source, capture.work, capture.chapterId, true)
      if (work === undefined || chapter === undefined || capture.total !== chapter.pages ||
        !matchesPublicSyncPageHash(capture.source, chapter, capture.descriptorHash)) continue
      const position: SyncPositionValue = { page: capture.page, total: chapter.pages, pageTable: chapter.pageTable }
      const recent: SyncRecentValue = { title: work.title, sourceName: work.sourceName, sourceVersion: work.sourceVersion,
        chapter: capture.chapterId, chapterTitle: chapter.title, date: capture.date }
      const save = (key: string, value: string): void => {
        const priorAction = lastAction.get(key)
        if (priorAction === undefined || capture.observedActions.includes(priorAction)) result.set(key, { key, value, kind: 'set' })
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

  readingActionAcknowledged(capture: SyncReadingActionCapture): boolean {
    return this.readingActionReceipt(capture) !== undefined
  }

  readingActionReceipt(capture: SyncReadingActionCapture): SyncReadingReceipt | undefined {
    const key = deviceSyncActionCaptureKey(capture)
    return this.storage.load().readingReceipts?.find((item: SyncReadingReceipt): boolean => item.key === key)
  }

  removed(group: SyncGroup, keys: string[]): string[] {
    if (group !== 'shelf') return []
    const library = this.library()
    const projection = this.projection()
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
      const comic = library.comics.find((row: PersistedComic): boolean => row.id === id)
      if (comic === undefined) return true
      if (parts[0] === 'book') return false
      const local = this.toLocalCategory(parts[3], library, projection)
      return !(comic.categoryIds ?? []).includes(local)
    })
  }

  private uniqueCategoryName(name: string, used: Set<string>): string {
    const original = normalizeLibraryCategoryName(name)
    let value = original
    let index = 2
    while (used.has(libraryCategoryNameKey(value)) || isBuiltInLibraryCategoryName(value)) {
      const suffix = ' (' + index++ + ')'
      value = original.substring(0, 40 - suffix.length).trimEnd() + suffix
    }
    used.add(libraryCategoryNameKey(value))
    return value
  }

  private applyShelf(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument, projection: SyncProjection): void {
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
      if (key[0] !== 'book' || !syncKnownSource(key[1])) return
      const id = sourceLibraryComicId(key[1], key[2])
      const existing = library.comics.find((comic: PersistedComic): boolean => comic.id === id)
      if (change.value === '') {
        if (existing === undefined) return
        if (existing.personalNotes || existing.customCoverUri) {
          if (!projection.blockedShelf.includes(id)) projection.blockedShelf.push(id)
          return
        }
        library.comics = library.comics.filter((comic: PersistedComic): boolean => comic.id !== id)
      } else if (existing === undefined) {
        const label = JSON.parse(change.value) as SyncWorkLabel
        library.comics.push({ id, title: label.title, sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
          sourcePath: 'source://' + key[1] + '/' + key[2], sourceRuntimeId: key[1], remoteResourceId: key[2],
          sourceMetadata: { sourceName: label.sourceName }, sortTitle: normalizeSortKey(label.title),
          preferredDirection: ReadingDirection.RIGHT_TO_LEFT, chapters: [], chapterCount: 0, pageCount: 0,
          createdAt: now, updatedAt: now, lastImportedAt: now })
      } else {
        projection.blockedShelf = projection.blockedShelf.filter((value: string): boolean => value !== id)
      }
    })
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'order' && change.value !== '') {
        const order = JSON.parse(change.value) as string[]
        const ordered = categories.slice().sort((a: PersistedLibraryCategory,
          b: PersistedLibraryCategory): number => a.sortOrder - b.sortOrder)
        const shared = ordered.filter((category: PersistedLibraryCategory): boolean =>
          this.toSharedCategory(category.id, projection) !== undefined)
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
          if (this.toSharedCategory(category.id, projection) === undefined) category.sortOrder = index
          else shared[next++].sortOrder = index
        })
      }
      if (key[0] !== 'member' || !syncKnownSource(key[1])) return
      const comic = library.comics.find((item: PersistedComic): boolean => item.id === sourceLibraryComicId(key[1], key[2]))
      if (comic === undefined) return
      const local = this.toLocalCategory(key[3], library, projection)
      if (local !== FAVORITE && local !== READ_LATER && !categories.some((item: PersistedLibraryCategory): boolean => item.id === local)) return
      const next = (comic.categoryIds ?? []).filter((id: string): boolean => id !== local)
      if (change.value !== '') next.push(local)
      comic.categoryIds = next
    })
  }

  private applyReading(changes: SyncLocalValue[], snapshot: ReaderSessionDocumentSnapshot, projection: SyncProjection): void {
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'recent' || !syncKnownSource(key[1])) return
      const id = sourceLibraryComicId(key[1], key[2])
      let chapter = snapshot.chapters.find((state: ChapterReadingState): boolean => state.comicId === id && state.chapterId === key[3])
      if (chapter === undefined) {
        chapter = { comicId: id, chapterId: key[3], isRead: false, updatedAt: 0 }
        snapshot.chapters.push(chapter)
      }
      if (key[0] === 'position') {
        projection.readingProofs = projection.readingProofs.filter((proof: SyncResumeProof): boolean =>
          proof.comicId !== id || proof.chapterId !== key[3])
        if (change.value === '') {
          chapter.position = undefined
        } else {
          const position = JSON.parse(change.value) as SyncPositionValue
          chapter.position = makeProgress(id, key[3], position, chapter.isRead, chapter.position?.updatedAt ?? 0, chapter.position)
          projection.readingProofs.push({ comicId: id, chapterId: key[3], pageTable: position.pageTable })
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
        else old.completed = chapter.isRead
      }
    })
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] !== 'recent' || !syncKnownSource(key[1])) return
      const id = sourceLibraryComicId(key[1], key[2])
      const previous = snapshot.progress.find((item: ReadingProgress): boolean => item.comicId === id)
      snapshot.progress = snapshot.progress.filter((item: ReadingProgress): boolean => item.comicId !== id)
      const oldSource = snapshot.sourceHistory.find((item: SourceReadHistoryEntry): boolean => item.comicId === id)
      snapshot.sourceHistory = snapshot.sourceHistory.filter((item: SourceReadHistoryEntry): boolean => item.comicId !== id)
      if (change.value === '') return
      const value = JSON.parse(change.value) as SyncRecentValue
      const known = snapshot.chapters.find((item: ChapterReadingState): boolean => item.comicId === id && item.chapterId === value.chapter)
      const date = validDate(value.date)
      const progress: ReadingProgress = known?.position !== undefined ? datedProgress(known.position, date) :
        { comicId: id, chapterId: value.chapter, pageIndex: 0, totalPages: 0, progressRatio: 0,
          completed: known?.isRead === true, updatedAt: date, columnMode: previous?.columnMode }
      snapshot.progress.push(progress)
      snapshot.sourceHistory.push({ comicId: id, sourceId: key[1], mangaId: key[2], title: value.title,
        sourceName: value.sourceName, chapterId: value.chapter, chapterTitle: value.chapterTitle,
        mangaUrl: oldSource?.mangaUrl, coverUri: oldSource?.coverUri })
    })
  }

  private applyPreferences(changes: SyncLocalValue[], preferences: ReaderDeviceSyncPreferences): void {
    changes.forEach((change: SyncLocalValue): void => {
      const key = syncKeyParts(change.key)
      if (key[0] === 'book-mode' && syncKnownSource(key[1])) {
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

  private applyAuxiliary(group: SyncGroup, changes: SyncLocalValue[], projection: SyncProjection): void {
    changes.forEach((change: SyncLocalValue): void => {
      if (group === 'search-history') {
        projection.receivedQueries = projection.receivedQueries.filter((value: SyncLocalValue): boolean => value.key !== change.key)
        if (change.value === '') {
          projection.acceptedQueries = projection.acceptedQueries.filter((value: SyncLocalValue): boolean => value.key !== change.key)
        }
        if (change.value !== '') projection.receivedQueries.push(change)
      } else if (group === 'source-subscriptions') {
        projection.subscriptions = projection.subscriptions.filter((value: SyncLocalValue): boolean => value.key !== change.key)
        if (change.value !== '') projection.subscriptions.push(change)
      }
    })
  }

  private addImage(files: SyncFileImage[], name: string, after: string): void {
    const before = readFile(this.path(name))
    if (before !== after) files.push({ name, before, after })
  }

  async commit(groups: SyncApplyGroup[], expected: SyncOwnerRevision[], saveCursor: (id: string) => void): Promise<void> {
    const reader = appReaderSessionStore(this.context.filesDir)
    if (!reader.flush()) throw new Error('sync_local_busy')
    const readerRevision = reader.currentDeviceSyncRevision()
    try {
    await BackupRestoreActivity.runDeviceSyncCommit(async (): Promise<void> => {
      for (const target of expected) {
        if ((await this.snapshot(target.group, false)).revision !== target.revision) throw new Error('sync_local_changed')
      }
      const projection = this.projection()
      const files: SyncFileImage[] = []
      let previousPreferences: ReaderDeviceSyncPreferences | undefined
      let nextPreferences: ReaderDeviceSyncPreferences | undefined
      let previousSearch: SearchHistoryEntry[] | undefined
      let nextSearch: SearchHistoryEntry[] | undefined
      for (const group of groups) {
        if (group.changes.length === 0) continue
        if (group.group === 'shelf') {
          const library = this.library()
          this.applyShelf(group.changes, library, projection)
          const json = JSON.stringify(library)
          assertValidLibraryStoreJson(json)
          this.addImage(files, LIBRARY_STORE_PERSISTENCE_FILE_NAME, json)
        } else if (group.group === 'reading') {
          const reading = this.reading()
          this.applyReading(group.changes, reading, projection)
          reading.syncPositions = reading.syncPositions?.filter((capture: SyncReadingCapture): boolean => !this.readingAcknowledged(capture))
          reading.syncActions = reading.syncActions?.filter((capture: SyncReadingActionCapture): boolean =>
            !this.readingActionAcknowledged(capture) || (reading.syncPositions?.length ?? 0) > 0)
          this.addImage(files, READER_PROGRESS_PERSISTENCE_FILE_NAME, serializeReaderSessionForDevice(reading))
        } else if (group.group === 'reader-settings') {
          previousPreferences = await new ReaderPreferencesStore(this.context).captureDeviceSyncPreferences()
          nextPreferences = clonePrefs(previousPreferences)
          this.applyPreferences(group.changes, nextPreferences)
        } else {
          this.applyAuxiliary(group.group, group.changes, projection)
          if (group.group === 'search-history' && group.changes.some((change: SyncLocalValue): boolean => change.value === '')) {
            const dropped = group.changes.filter((change: SyncLocalValue): boolean => change.value === '')
              .map((change: SyncLocalValue): string => change.key)
            previousSearch = await new SearchHistoryStore(this.context).load()
            nextSearch = previousSearch.filter((entry: SearchHistoryEntry): boolean => entry.syncSourceSet === undefined ||
              !dropped.includes(syncKey(['query', syncSearchIdentity(entry.query), entry.syncSourceSet])))
          }
        }
      }
      const oldProjection = this.projection()
      if (JSON.stringify(oldProjection) !== JSON.stringify(projection)) this.addImage(files, SYNC_PROJECTION, JSON.stringify(projection))
      const id = util.generateRandomUUID()
      if (files.length === 0 && nextPreferences === undefined && nextSearch === undefined) {
        saveCursor(id)
        return
      }
      const journal: LocalJournal = { id, files, filesStarted: false, previousPreferences, nextPreferences, previousSearch, nextSearch }
      writeAppTextFile(this.path(SYNC_JOURNAL), JSON.stringify(journal))
      try {
        if (nextPreferences !== undefined) await new ReaderPreferencesStore(this.context).applyDeviceSyncPreferences(nextPreferences)
        if (nextSearch !== undefined) await new SearchHistoryStore(this.context).applyDeviceSyncEntries(nextSearch)
        if (reader.currentDeviceSyncRevision() !== readerRevision || files.some((image: SyncFileImage): boolean =>
          readFile(this.path(image.name)) !== image.before)) throw new Error('sync_local_changed')
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
    fs.unlinkSync(this.path(SYNC_JOURNAL))
  }

  rememberLocalReadingProof(comicId: string, chapterId: string, pageTable: string): void {
    const projection = this.projection()
    if (projection.readingProofs.some((proof: SyncResumeProof): boolean =>
      proof.comicId === comicId && proof.chapterId === chapterId && proof.pageTable === pageTable)) return
    projection.readingProofs = projection.readingProofs.filter((proof: SyncResumeProof): boolean =>
      proof.comicId !== comicId || proof.chapterId !== chapterId)
    projection.readingProofs.push({ comicId, chapterId, pageTable })
    writeAppTextFile(this.path(SYNC_PROJECTION), JSON.stringify(projection))
  }

  resumeProof(comicId: string, chapterId: string): string {
    return this.projection().readingProofs.find((proof: SyncResumeProof): boolean =>
      proof.comicId === comicId && proof.chapterId === chapterId)?.pageTable ?? ''
  }

  sourceIdentity(comicId: string): SyncSourceIdentity | undefined {
    return this.sourceIdentities(this.library(), this.reading()).get(comicId)
  }

  markAcceptedSharedSubscription(): void {
    const projection = this.projection()
    if (projection.adoptedSharedCatalog === true) return
    projection.adoptedSharedCatalog = true
    writeAppTextFile(this.path(SYNC_PROJECTION), JSON.stringify(projection))
  }

  sharedCategory(id: string): string | undefined {
    return this.toSharedCategory(id, this.projection())
  }

  isLocallyShelved(source: string, work: string): boolean {
    return this.library().comics.some((comic: PersistedComic): boolean =>
      comic.sourceRuntimeId === source && comic.remoteResourceId === work)
  }

  receivedSubscriptions(): SyncLocalValue[] {
    return this.projection().subscriptions
  }

  receivedQueries(): SyncLocalValue[] {
    return this.projection().receivedQueries
  }

  saveSearchValues(values: SyncLocalValue[], remove: string[] = []): void {
    const projection = this.projection()
    projection.acceptedQueries = values
    projection.receivedQueries = projection.receivedQueries.filter((row: SyncLocalValue): boolean => !remove.includes(row.key))
    writeAppTextFile(this.path(SYNC_PROJECTION), JSON.stringify(projection))
  }

  publicWork(source: string, work: string): Promise<SyncPublicWorkProof | undefined> {
    return this.publicSources.work(source, work, true)
  }
}
