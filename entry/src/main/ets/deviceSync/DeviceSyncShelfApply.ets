import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'
import { LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION, PersistedComic, PersistedLibraryCategory, PersistedLibraryStoreDocument,
  assertValidLibraryStoreJson, readLibraryStoreDocument } from '../model/LibraryPersistence'
import { ComicSourceKind, ReadingDirection, libraryCategoryNameKey, normalizeLibraryCategoryName, normalizeSortKey } from '../model/ComicModels'
import { sourceLibraryComicId } from '../model/SourceLibraryComic'
import type { LibrarySmartCategory, LibrarySmartFilter } from '../model/LibrarySmartCategory'
import type { LibraryShelfSyncEdits, LibraryShelfSyncImage } from '../model/LibraryRdbStorage'
import { isSyncReplica } from './DeviceSyncFacts'
import { smartCategoryStorageId, syncCoverAddress, SyncChapterCatalog, SyncSmartCategory, SyncWorkLabel, syncKey, syncKeyParts,
  syncNumberedCategoryName, syncSharedCategoryId, syncShelfIdentity, syncShelfMove } from './DeviceSyncData'
import type { SyncLocalShelfMove } from './DeviceSyncSignals'
import type { SyncLocalValue } from './DeviceSyncStorage'
import { syncDigest } from './DeviceSyncWire'

export const FAVORITE = 'favorite'
export const READ_LATER = 'read_later'

export interface SyncLocalCategory {
  local: string
  shared: string
  localOnly: boolean
  originalName?: string
  displayedName?: string
  mergedInto?: string
  members?: string[]
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
  if (existing?.localOnly === true) {
    return projection.categories.find((row: SyncLocalCategory): boolean => row.mergedInto === local && !row.localOnly)?.shared
  }
  if (local === FAVORITE) return 'builtin-favorite'
  if (local === READ_LATER) return 'builtin-read-later'
  return existing?.shared ?? (isSyncReplica(local) ? local : syncSharedCategoryId(replica, local))
}

export function categoryAliases(local: string, projection: SyncProjection, replica: string): SyncLocalCategory[] {
  const current = projection.categories.find((row: SyncLocalCategory): boolean => row.local === local)
  const aliases = projection.categories.filter((row: SyncLocalCategory): boolean => row.mergedInto === local && !row.localOnly)
  if (current !== undefined) return current.localOnly ? aliases : [current].concat(aliases)
  const shared = toSharedCategory(local, projection, replica)
  if (shared === undefined) return aliases
  return [{ local, shared, localOnly: false } as SyncLocalCategory].concat(aliases)
}

export function categoryMembershipAliases(local: string, comicId: string, projection: SyncProjection, replica: string): string[] {
  const aliases = categoryAliases(local, projection, replica)
  if (aliases.length <= 1) return aliases.map((row: SyncLocalCategory): string => row.shared)
  const members = aliases.filter((row: SyncLocalCategory): boolean => row.members?.includes(comicId) === true)
  return (members.length > 0 ? members : aliases.slice(0, 1)).map((row: SyncLocalCategory): string => row.shared)
}

export function originalCategoryName(name: string, mapping?: SyncLocalCategory): string {
  return mapping?.displayedName === name ? mapping.originalName ?? name : name
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
  const alias = projection.categories.find((row: SyncLocalCategory): boolean => row.shared === shared && !row.localOnly)
  if (alias?.mergedInto !== undefined && library.customCategories?.some(row => row.id === alias.mergedInto)) return alias.mergedInto
  const existing = (library.customCategories ?? []).find((row: PersistedLibraryCategory): boolean =>
    toSharedCategory(row.id, projection, replica) === shared)
  // A received category already has its business ID. Store that exact ID.
  return existing?.id ?? shared
}

export function smartCategoryKey(id: string): string {
  // Existing local IDs also travel in backups. Derive the same identity
  // when the same old smart category is restored on two devices.
  return syncKey(['smart-category', smartCategoryStorageId(id).slice('smart:'.length)])
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

function uniqueCategoryName(name: string, used: Set<string>, incoming?: Set<string>): string {
  const original = normalizeLibraryCategoryName(name)
  let value = original
  let index = 2
  while (used.has(libraryCategoryNameKey(value)) ||
    (value !== original && incoming?.has(libraryCategoryNameKey(value)) === true)) {
    value = syncNumberedCategoryName(original, (index++).toString())
  }
  used.add(libraryCategoryNameKey(value))
  return value
}

// A restored shelf and WebDAV may carry different wire IDs for the same manual
// category. Keep those wire IDs and their member sets so an older peer's change
// to one ID cannot erase another ID's members. Only the local view is merged.
function expandCategoryAliases(library: PersistedLibraryStoreDocument, projection: SyncProjection, replica: string): void {
  const categories = library.customCategories ?? []
  const aliases = projection.categories.filter((row: SyncLocalCategory): boolean => row.mergedInto !== undefined)
  if (aliases.length === 0) return
  const byId = new Map<string, PersistedLibraryCategory>(categories.map(category => [category.id, category]))
  const virtualIds = new Map<string, string>()
  for (const alias of aliases) {
    const primary = byId.get(alias.mergedInto ?? '')
    if (primary === undefined) continue
    virtualIds.set(alias.shared, alias.local)
    if (byId.has(alias.local)) continue
    const name = originalCategoryName(primary.name, alias)
    categories.push({ id: alias.local, name, sortOrder: primary.sortOrder, createdAt: primary.createdAt,
      updatedAt: primary.updatedAt, isPrivate: primary.isPrivate })
  }
  for (const comic of library.comics) {
    if (shelfWork(comic) === undefined) continue
    comic.categoryIds = comic.categoryIds?.flatMap((id: string): string[] => {
      if (!aliases.some((alias: SyncLocalCategory): boolean => alias.mergedInto === id)) return [id]
      const rows = categoryMembershipAliases(id, comic.id, projection, replica)
      const keepLocal = projection.categories.some((row: SyncLocalCategory): boolean => row.local === id && row.localOnly)
      const result = rows.map((shared: string): string => virtualIds.get(shared) ?? id)
      if (keepLocal || result.length === 0) result.push(id)
      return result
    })
  }
  projection.categories = projection.categories.filter((row: SyncLocalCategory): boolean =>
    row.mergedInto === undefined || virtualIds.has(row.shared))
  for (const alias of aliases) {
    const primary = byId.get(alias.mergedInto ?? '')
    if (primary !== undefined) {
      const name = originalCategoryName(primary.name, alias)
      alias.originalName = name
      alias.displayedName = name
    }
    alias.mergedInto = undefined
  }
}

function mergeCategoryAliases(library: PersistedLibraryStoreDocument, projection: SyncProjection, replica: string,
  admittedIds: Set<string>): void {
  const categories = library.customCategories ?? []
  const mappings = new Map<string, SyncLocalCategory>(projection.categories.map(row => [row.local, row]))
  const byName = new Map<string, PersistedLibraryCategory[]>()
  const order = categories.slice().sort((a: PersistedLibraryCategory, b: PersistedLibraryCategory): number =>
    a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
  const used = new Set<string>((library.smartCategories ?? []).map(group => libraryCategoryNameKey(group.name)))
  for (const category of order) {
    if (category.id === FAVORITE || category.id === READ_LATER) {
      used.add(libraryCategoryNameKey(category.name))
      continue
    }
    const name = libraryCategoryNameKey(originalCategoryName(category.name, mappings.get(category.id)))
    const group = byName.get(name) ?? []
    group.push(category)
    byName.set(name, group)
  }
  const remap = new Map<string, string>()
  const mergedRows = new Map<string, SyncLocalCategory>()
  const sharedOrder = order.flatMap((category: PersistedLibraryCategory): string[] =>
    sharedCategoryRecord(category.id, projection, replica) === undefined ? [] :
      categoryAliases(category.id, projection, replica).map((row: SyncLocalCategory): string => row.shared))
  for (const groups of byName.values()) {
    if (groups.length === 1) used.add(libraryCategoryNameKey(groups[0].name))
  }
  for (const entry of byName) {
    const name = entry[0]
    const group = entry[1]
    if (group.length < 2) continue
    const admitted = group.filter((category: PersistedLibraryCategory): boolean => admittedIds.has(category.id))
    const candidates = admitted.length > 0 ? admitted : group
    const primary = group.every((category: PersistedLibraryCategory): boolean => isSyncReplica(category.id)) ?
      group.reduce((first: PersistedLibraryCategory, category: PersistedLibraryCategory): PersistedLibraryCategory =>
        category.id < first.id ? category : first) :
      candidates.find((category: PersistedLibraryCategory): boolean =>
        libraryCategoryNameKey(category.name) === name) ?? candidates[0]
    const original = originalCategoryName(primary.name, mappings.get(primary.id))
    primary.sortOrder = group[0].sortOrder
    primary.name = uniqueCategoryName(original, used)
    if (group.some((category: PersistedLibraryCategory): boolean => category.isPrivate === true)) primary.isPrivate = true
    for (const category of group) {
      const mapping = mappings.get(category.id)
      const shared = mapping?.shared ?? toSharedCategory(category.id, projection, replica)
      if (shared === undefined) continue
      const name = category === primary ? original : originalCategoryName(category.name, mapping)
      const row: SyncLocalCategory = { local: category.id, shared, localOnly: mapping?.localOnly === true, originalName: name,
        displayedName: primary.name, members: [] }
      if (category !== primary) {
        row.mergedInto = primary.id
        remap.set(category.id, primary.id)
      }
      mergedRows.set(category.id, row)
    }
  }
  if (remap.size === 0) return
  projection.categories = projection.categories.filter((row: SyncLocalCategory): boolean => !mergedRows.has(row.local))
  projection.categories.push(...Array.from(mergedRows.values()))
  library.customCategories = categories.filter((category: PersistedLibraryCategory): boolean => !remap.has(category.id))
  for (const comic of library.comics) {
    if (comic.categoryIds === undefined) continue
    const shared = shelfWork(comic) !== undefined
    const next = new Set<string>()
    for (const id of comic.categoryIds) {
      if (shared) mergedRows.get(id)?.members?.push(comic.id)
      next.add(remap.get(id) ?? id)
    }
    comic.categoryIds = Array.from(next)
  }
  for (const group of library.smartCategories ?? []) {
    for (const rule of group.filters) {
      if (rule.method === 'category' && rule.value !== undefined) rule.value = remap.get(rule.value) ?? rule.value
    }
  }
  const strategies = library.categoryDisplayStrategies
  if (strategies !== undefined) {
    const claimed = new Set<string>(strategies.filter(item => !remap.has(item.categoryId)).map(item => item.categoryId))
    library.categoryDisplayStrategies = strategies.filter(item => {
      const primary = remap.get(item.categoryId)
      if (primary === undefined) return true
      if (claimed.has(primary)) return false
      claimed.add(primary)
      item.categoryId = primary
      return true
    })
  }
  if (JSON.stringify(sharedOrder) !== JSON.stringify(projection.projectedOrder)) projection.categoryOrder = sharedOrder
  projection.projectedOrder = library.customCategories.slice().sort((a: PersistedLibraryCategory, b: PersistedLibraryCategory): number =>
    a.sortOrder - b.sortOrder || a.createdAt - b.createdAt)
    .flatMap((category: PersistedLibraryCategory): string[] =>
      sharedCategoryRecord(category.id, projection, replica) === undefined ? [] :
        categoryAliases(category.id, projection, replica).map((row: SyncLocalCategory): string => row.shared))
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
  const categoryChanges = changes.filter((change: SyncLocalValue): boolean => syncKeyParts(change.key)[0] === 'category')
  const incomingNames = new Set<string>(categoryChanges.filter((change: SyncLocalValue): boolean => change.value !== '')
    .map((change: SyncLocalValue): string => libraryCategoryNameKey(JSON.parse(change.value) as string)))
  categoryChanges
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
      const name = uniqueCategoryName(originalName, names, incomingNames)
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
    if (key[0] !== 'category-privacy' || change.value === '') return
    const id = toLocalCategory(key[1], library, projection, replica)
    const category = categories.find((row: PersistedLibraryCategory): boolean => row.id === id)
    if (category !== undefined) category.isPrivate = change.value === 'true'
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
  libraryText?: string
  shelfEdits?: LibraryShelfSyncEdits
  projectionText: string
}

function shelfSyncEdits(before: PersistedLibraryStoreDocument | undefined,
  after: PersistedLibraryStoreDocument): LibraryShelfSyncEdits {
  const previous: LibraryShelfSyncImage = { present: before !== undefined, works: [] }
  const next: LibraryShelfSyncImage = { present: true, works: [] }
  const oldWorks = before?.comics ?? []
  const remaining = new Map<string, PersistedComic>(oldWorks.map((work: PersistedComic): [string, PersistedComic] => [work.id, work]))
  const comicIds: string[] = []
  const unchangedCatalogs: string[] = []
  for (const work of after.comics) {
    const old = remaining.get(work.id)
    remaining.delete(work.id)
    if (old !== undefined && JSON.stringify(old.chapters) === JSON.stringify(work.chapters)) {
      // Both documents are private to the preparation task. Strip the
      // catalogs from the recovery images after validating the full result.
      old.chapters = []
      work.chapters = []
      if (JSON.stringify(old) === JSON.stringify(work)) continue
      comicIds.push(work.id)
      unchangedCatalogs.push(work.id)
      previous.works.push(old)
      next.works.push(work)
      continue
    }
    comicIds.push(work.id)
    if (old !== undefined) previous.works.push(old)
    next.works.push(work)
  }
  remaining.forEach((work: PersistedComic, id: string): void => {
    comicIds.push(id)
    previous.works.push(work)
  })
  if (oldWorks.length !== after.comics.length || oldWorks.some((work: PersistedComic, index: number): boolean =>
    work.id !== after.comics[index].id)) {
    previous.order = oldWorks.map((work: PersistedComic): string => work.id)
    next.order = after.comics.map((work: PersistedComic): string => work.id)
  }
  if (JSON.stringify(before?.customCategories) !== JSON.stringify(after.customCategories)) {
    previous.categories = before?.customCategories ?? null
    next.categories = after.customCategories ?? null
  }
  if (JSON.stringify(before?.categoryDisplayStrategies) !== JSON.stringify(after.categoryDisplayStrategies)) {
    previous.displayStrategies = before?.categoryDisplayStrategies ?? null
    next.displayStrategies = after.categoryDisplayStrategies ?? null
  }
  if (JSON.stringify(before?.smartCategories) !== JSON.stringify(after.smartCategories)) {
    previous.smartCategories = before?.smartCategories ?? null
    next.smartCategories = after.smartCategories ?? null
  }
  if (JSON.stringify(before?.syncShelfMoves) !== JSON.stringify(after.syncShelfMoves)) {
    previous.moves = before?.syncShelfMoves ?? null
    next.moves = after.syncShelfMoves ?? null
  }
  return { comicIds, unchangedCatalogs, before: previous, after: next }
}

// Keep the owned shelf document in one TaskPool task through decode, merge and
// validation. The caller still checks the admitted files and publishes the journal.
export function prepareSyncShelfDocument(raw: string | null, changes: SyncLocalValue[], projectionText: string,
  acceptedRemoval: string, replica: string, relational: boolean = false): PreparedSyncShelf {
  const library = raw === null ? emptySyncLibrary() : readLibraryStoreDocument(raw)
  const projection = JSON.parse(projectionText) as SyncProjection
  const admittedIds = new Set<string>((library.customCategories ?? []).map(category => category.id))
  expandCategoryAliases(library, projection, replica)
  applyShelf(changes, library, projection, acceptedRemoval, replica)
  applySmartCategories(changes, library, projection, replica)
  mergeCategoryAliases(library, projection, replica, admittedIds)
  applyChapterCatalogs(changes, library)
  const libraryText = JSON.stringify(library)
  assertValidLibraryStoreJson(libraryText)
  hiTraceMeter.traceByValue('KomaDeviceSyncShelfPreparedChars', libraryText.length)
  // Resolving aliases or recording a declined remote edit can change the sync
  // projection without changing the shelf. Keep the unchanged catalog in the worker.
  const nextProjection = JSON.stringify(projection)
  if (libraryText === raw) return { projectionText: nextProjection }
  if (!relational) return { libraryText, projectionText: nextProjection }
  const before = raw === null ? undefined : JSON.parse(raw) as PersistedLibraryStoreDocument
  return { shelfEdits: shelfSyncEdits(before, library), projectionText: nextProjection }
}
