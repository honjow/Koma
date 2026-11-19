import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'
import { LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, PersistedComic, PersistedLibraryCategory, PersistedLibraryStoreDocument,
  assertValidLibraryStoreJson, readLibraryStoreDocument } from '../model/LibraryPersistence'
import { ComicSourceKind, ReadingDirection, libraryCategoryNameKey, normalizeLibraryCategoryName, normalizeSortKey } from '../model/ComicModels'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import type { LibrarySmartCategory, LibrarySmartFilter } from '../model/LibrarySmartCategory'
import { isSyncReplica } from './DeviceSyncFacts'
import { syncCoverAddress, SyncChapterCatalog, SyncSmartCategory, SyncWorkLabel, syncKey, syncKeyParts, syncShelfIdentity,
  syncShelfMove } from './DeviceSyncData'
import type { SyncLocalShelfMove } from './DeviceSyncSignals'
import type { SyncLocalValue } from './DeviceSyncStorage'
import { syncDigest } from './DeviceSyncWire'

export const CATEGORY_SYNC_PREFIX = 'custom_sync_'
export const FAVORITE = 'favorite'
export const READ_LATER = 'read_later'

export interface SyncLocalCategory {
  local: string
  shared: string
  localOnly: boolean
  originalName?: string
  displayedName?: string
}

export interface SyncSourceIdentity {
  source: string
  work: string
}

export interface SyncResumeProof {
  comicId: string
  chapterId: string
  received?: boolean
}

export interface SyncKeptShelfDetails {
  id: string
  notes?: string
  cover?: string
}

export interface SyncProjection {
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

export function emptySyncLibrary(): PersistedLibraryStoreDocument {
  return { schemaVersion: LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, comics: [], customCategories: [] }
}

function syncUuid(text: string): string {
  const hash = syncDigest(text)
  return hash.substring(0, 8) + '-' + hash.substring(8, 12) + '-' + hash.substring(12, 16) + '-' +
    hash.substring(16, 20) + '-' + hash.substring(20, 32)
}

export function shelfWork(comic: PersistedComic): SyncSourceIdentity | undefined {
  const source = comic.sourceRuntimeId
  const work = comic.remoteResourceId
  return source !== undefined && work !== undefined && comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY &&
    comic.remoteServerId === undefined && syncShelfIdentity(source, work) && sourceLibraryComicId(source, work) === comic.id ?
    { source, work } : undefined
}

export function shelfSourceCover(comic?: PersistedComic): string | undefined {
  return syncCoverAddress(comic?.sourceCoverUri ?? (comic?.customCoverUri === undefined ? comic?.coverUri : undefined))
}

export function matchesShelfWork(comic: PersistedComic, source: string, work: string): boolean {
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

export function toSharedCategory(local: string, projection: SyncProjection, replica: string): string | undefined {
  const existing = projection.categories.find((row: SyncLocalCategory): boolean => row.local === local)
  if (existing?.localOnly === true) return undefined
  if (local === FAVORITE) return 'builtin-favorite'
  if (local === READ_LATER) return 'builtin-read-later'
  return existing?.shared ?? syncUuid(replica + ':category:' + local)
}

export function sharedCategoryRecord(local: string, projection: SyncProjection, replica: string): string | undefined {
  // Legacy sync keys carry membership only. Keep the promoted local name and
  // order out of category records, whose wire identity must be a UUID.
  if (local === FAVORITE || local === READ_LATER) return undefined
  return toSharedCategory(local, projection, replica)
}

export function toLocalCategory(shared: string, library: PersistedLibraryStoreDocument, projection: SyncProjection,
  replica: string): string {
  if (shared === 'builtin-favorite') return FAVORITE
  if (shared === 'builtin-read-later') return READ_LATER
  const existing = (library.customCategories ?? []).find((row: PersistedLibraryCategory): boolean =>
    toSharedCategory(row.id, projection, replica) === shared)
  if (existing !== undefined) return existing.id
  const base = CATEGORY_SYNC_PREFIX + shared
  let id = base
  let suffix = 2
  while ((library.customCategories ?? []).some((row: PersistedLibraryCategory): boolean => row.id === id)) {
    id = base + '_' + suffix++
  }
  return id
}

export function smartCategoryKey(id: string): string {
  const shared = id.slice('smart:'.length)
  // Existing local IDs also travel in backups. Derive the same identity
  // when the same old smart category is restored on two devices.
  return syncKey(['smart-category', isSyncReplica(shared) ? shared : syncUuid('smart-category:' + id)])
}

function applyChapterCatalogs(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument): void {
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

function uniqueCategoryName(name: string, used: Set<string>): string {
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

function applySmartCategories(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument,
  projection: SyncProjection, replica: string): void {
  const smartChanges = changes.filter((row: SyncLocalValue): boolean => syncKeyParts(row.key)[0] === 'smart-category')
  if (smartChanges.length === 0) return
  const groups = library.smartCategories ?? []
  const byKey = new Map<string, LibrarySmartCategory>(groups.map((group: LibrarySmartCategory): [string, LibrarySmartCategory] =>
    [smartCategoryKey(group.id), group]))
  const replaced = new Set<string>(smartChanges.map((row: SyncLocalValue): string => row.key))
  const names = new Set<string>((library.customCategories ?? []).map((category: PersistedLibraryCategory): string =>
    libraryCategoryNameKey(category.name)))
  byKey.forEach((group: LibrarySmartCategory, key: string): void => {
    if (!replaced.has(key)) names.add(libraryCategoryNameKey(group.name))
  })
  for (const change of smartChanges) {
    const shared = syncKeyParts(change.key)[1]
    const id = byKey.get(change.key)?.id ?? 'smart:' + shared
    projection.categories = projection.categories.filter((item: SyncLocalCategory): boolean => item.local !== id)
    if (change.value === '') {
      byKey.delete(change.key)
      library.categoryDisplayStrategies = library.categoryDisplayStrategies?.filter(item => item.categoryId !== id)
      continue
    }
    const definition = JSON.parse(change.value) as SyncSmartCategory
    const name = uniqueCategoryName(definition.name, names)
    const filters = definition.filters.map((rule: LibrarySmartFilter): LibrarySmartFilter => {
      const value = rule.value
      if (rule.method !== 'category' || value === undefined || value === 'uncategorized') return rule
      return { method: rule.method, value: toLocalCategory(value, library, projection, replica), exclude: rule.exclude }
    })
    byKey.set(change.key, { id, name, sortOrder: definition.order, createdAt: definition.createdAt, updatedAt: Date.now(), filters })
    projection.categories.push({ local: id, shared, localOnly: false, originalName: definition.name, displayedName: name })
  }
  library.smartCategories = Array.from(byKey.values())
}

function applyShelf(changes: SyncLocalValue[], library: PersistedLibraryStoreDocument, projection: SyncProjection,
  acceptedRemoval: string, replica: string): void {
  const categories = library.customCategories ?? []
  library.customCategories = categories
  const updatedSmart = new Set<string>(changes.filter((row: SyncLocalValue): boolean =>
    syncKeyParts(row.key)[0] === 'smart-category').map((row: SyncLocalValue): string => row.key))
  const names = new Set<string>((library.smartCategories ?? [])
    .filter((category: LibrarySmartCategory): boolean => !updatedSmart.has(smartCategoryKey(category.id)))
    .map((category: LibrarySmartCategory): string => libraryCategoryNameKey(category.name)))
  const rename = new Set<string>()
  changes.forEach((change: SyncLocalValue): void => {
    const key = syncKeyParts(change.key)
    if (key[0] === 'category' && change.value !== '') rename.add(toLocalCategory(key[1], library, projection, replica))
  })
  categories.forEach((category: PersistedLibraryCategory): void => {
    if (!rename.has(category.id)) names.add(libraryCategoryNameKey(category.name))
  })
  const now = Date.now()
  changes.filter((change: SyncLocalValue): boolean => syncKeyParts(change.key)[0] === 'category')
    .sort((a: SyncLocalValue, b: SyncLocalValue): number => a.key < b.key ? -1 : a.key === b.key ? 0 : 1)
    .forEach((change: SyncLocalValue): void => {
      const shared = syncKeyParts(change.key)[1]
      const id = toLocalCategory(shared, library, projection, replica)
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
        const smartDependency = (library.smartCategories ?? []).some((item: LibrarySmartCategory): boolean =>
          item.filters.some((rule: LibrarySmartFilter): boolean => rule.method === 'category' && rule.value === id))
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
      const name = uniqueCategoryName(originalName, names)
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
        sharedCategoryRecord(category.id, projection, replica) !== undefined)
      shared.sort((a: PersistedLibraryCategory, b: PersistedLibraryCategory): number => {
        const aid = toSharedCategory(a.id, projection, replica) ?? ''
        const bid = toSharedCategory(b.id, projection, replica) ?? ''
        const ai = order.indexOf(aid)
        const bi = order.indexOf(bid)
        if (ai >= 0 && bi >= 0) return ai - bi
        if (ai >= 0) return -1
        if (bi >= 0) return 1
        return aid < bid ? -1 : aid === bid ? 0 : 1
      })
      projection.categoryOrder = order
      projection.projectedOrder = shared.map((item: PersistedLibraryCategory): string => toSharedCategory(item.id, projection, replica) ?? '')
      let next = 0
      ordered.forEach((category: PersistedLibraryCategory, index: number): void => {
        if (sharedCategoryRecord(category.id, projection, replica) === undefined) category.sortOrder = index
        else shared[next++].sortOrder = index
      })
    }
    if (key[0] !== 'member') return
    const comic = byWork(key[1], key[2])
    if (comic === undefined) return
    const local = toLocalCategory(key[3], library, projection, replica)
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
      !(target.categoryIds ?? []).includes(toLocalCategory(category, library, projection, replica)))) return
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

export interface PreparedSyncShelf {
  libraryText: string
  projectionText: string
}

// Keep the owned shelf document in one TaskPool task through decode, merge and
// validation. The caller still checks the admitted files and publishes the journal.
export function prepareSyncShelfDocument(raw: string | null, changes: SyncLocalValue[], projectionText: string,
  acceptedRemoval: string, replica: string): PreparedSyncShelf {
  const library = raw === null ? emptySyncLibrary() : readLibraryStoreDocument(raw)
  const projection = JSON.parse(projectionText) as SyncProjection
  applyShelf(changes, library, projection, acceptedRemoval, replica)
  applySmartCategories(changes, library, projection, replica)
  applyChapterCatalogs(changes, library)
  const libraryText = JSON.stringify(library)
  assertValidLibraryStoreJson(libraryText)
  hiTraceMeter.traceByValue('KomaDeviceSyncShelfPreparedChars', libraryText.length)
  return { libraryText, projectionText: JSON.stringify(projection) }
}
