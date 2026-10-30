import { Chapter, Comic } from './ComicModels'
import { MangaChapterItem } from './MangaDetailModels'

const MH1234_SOURCE_ID: string = 'com.mh1234.koma'
const BAOZI_SOURCE_ID: string = 'online.baozimh.koma'

interface BaoziChapterIdentity {
  base: string
  title?: string
}

function baoziChapterIdentity(work: string, id: string): BaoziChapterIdentity | undefined {
  const identity = /^chapter:([^:#]+):([^#]+)(?:#([\s\S]+))?$/.exec(id)
  if (identity === null || identity[1] !== work) return undefined
  return { base: `chapter:${work}:${identity[2]}`, title: identity[3] }
}

function baoziWork(mangaId: string): string | undefined {
  return /^manga:([^:#]+)$/.exec(mangaId)?.[1]
}

function chapterIdentityConflict(): void {
  throw new Error('source_chapter_identity_ambiguous')
}

/** Keep persisted IDs in both directions; never infer a missing legacy title. */
function reconcileBaoziChapterIdentity(
  comic: Comic, mangaId: string, chapters: MangaChapterItem[],
): SourceChapterIdentityResolution {
  const unchanged: SourceChapterIdentityResolution = {
    chapters, storedChapters: comic.chapters, removedDuplicateIds: [],
  }
  const work = baoziWork(mangaId)
  if (work === undefined || comic.chapters.length === 0) return unchanged
  const storedGroups = new Map<string, Chapter[]>()
  const remoteGroups = new Map<string, MangaChapterItem[]>()
  comic.chapters.forEach((chapter: Chapter): void => {
    const key = baoziChapterIdentity(work, chapter.id)?.base
    if (key !== undefined) storedGroups.set(key, (storedGroups.get(key) ?? []).concat([chapter]))
  })
  chapters.forEach((chapter: MangaChapterItem): void => {
    const key = baoziChapterIdentity(work, chapter.id)?.base
    if (key !== undefined) remoteGroups.set(key, (remoteGroups.get(key) ?? []).concat([chapter]))
  })
  const aliases = new Map<string, string>()
  storedGroups.forEach((stored: Chapter[], key: string): void => {
    const remote = remoteGroups.get(key) ?? []
    if (!stored.some((chapter: Chapter): boolean => chapter.id !== key) &&
      !remote.some((chapter: MangaChapterItem): boolean => chapter.id !== key)) return
    const remoteTitles = new Map<string, string>()
    remote.forEach((chapter: MangaChapterItem): void => {
      const previous = remoteTitles.get(chapter.id)
      if (previous !== undefined && previous !== chapter.title) chapterIdentityConflict()
      remoteTitles.set(chapter.id, chapter.title)
    })
    // A legacy slot must have exactly one full-title counterpart before its
    // existing progress/pages can be associated with a title-bearing identity.
    stored.filter((chapter: Chapter): boolean => chapter.id === key).forEach((chapter: Chapter): void => {
      if (remote.length === 0) return
      if (chapter.title.length === 0 || stored.some((other: Chapter): boolean =>
        other.id === key && other.title !== chapter.title)) chapterIdentityConflict()
      const matches = remote.filter((item: MangaChapterItem): boolean => item.title === chapter.title)
      const ids = new Set<string>(matches.map((item: MangaChapterItem): string => item.id))
      if (ids.size !== 1) chapterIdentityConflict()
      const id = Array.from(ids)[0]
      if (id !== key) {
        if (stored.some((other: Chapter): boolean => other.id === id)) chapterIdentityConflict()
        aliases.set(id, key)
      }
    })
    remote.filter((chapter: MangaChapterItem): boolean => chapter.id === key).forEach((chapter: MangaChapterItem): void => {
      const exact = stored.filter((item: Chapter): boolean => item.id === key)
      if (exact.length > 0) {
        if (exact.some((item: Chapter): boolean => item.title !== chapter.title)) chapterIdentityConflict()
        return
      }
      const matches = stored.filter((item: Chapter): boolean => item.title === chapter.title)
      const ids = new Set<string>(matches.map((item: Chapter): string => item.id))
      if (chapter.title.length === 0 || ids.size !== 1) chapterIdentityConflict()
      aliases.set(key, Array.from(ids)[0])
    })
  })
  if (aliases.size === 0) return unchanged
  const seen = new Map<string, string>()
  const resolved: MangaChapterItem[] = []
  chapters.forEach((chapter: MangaChapterItem): void => {
    const id = aliases.get(chapter.id) ?? chapter.id
    const previous = seen.get(id)
    if (previous !== undefined) {
      if (previous !== chapter.id) chapterIdentityConflict()
      if (aliases.has(chapter.id)) return
    }
    seen.set(id, chapter.id)
    resolved.push(id === chapter.id ? chapter : withChapterId(chapter, id))
  })
  // User decision: ambiguous updates fail as a whole and retain the old catalog
  // and progress. Callers already own that failure path; no partial mutation.
  return { chapters: resolved, storedChapters: comic.chapters, removedDuplicateIds: [] }
}

function workId(sourceId: string | undefined, mangaId: string): string | undefined {
  if (sourceId !== MH1234_SOURCE_ID) return undefined
  return /^\/comic\/([1-9][0-9]*)\.html$/.exec(mangaId)?.[1]
}

// Decode only the observed unpadded base64url identity. The opaque suffix is
// validated, never calculated or used to construct a request URL.
function legacyIdentity(id: string): string | undefined {
  const token = /^\/go\/([A-Za-z0-9_-]+)$/.exec(id)?.[1]
  if (token === undefined || token.length > 256 || token.length % 4 === 1) return undefined
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  let value = 0
  let bits = 0
  let decoded = ''
  for (let index = 0; index < token.length; index += 1) {
    value = (value << 6) | alphabet.indexOf(token[index])
    bits += 6
    if (bits >= 8) {
      bits -= 8
      decoded += String.fromCharCode((value >> bits) & 255)
      value &= (1 << bits) - 1
    }
  }
  if (value !== 0) return undefined
  return /^([1-9][0-9]*)-([1-9][0-9]*)-[0-9a-f]{10}$/.test(decoded) ? decoded : undefined
}

function chapterKey(work: string, id: string): string | undefined {
  const current = /^\/comic\/([1-9][0-9]*)\/([1-9][0-9]*)\.html$/.exec(id)
  if (current !== null) return current[1] === work ? current[2] : undefined
  const legacy = legacyIdentity(id)?.split('-')
  return legacy !== undefined && legacy[0] === work ? legacy[1] : undefined
}

function withChapterId(chapter: MangaChapterItem, id: string): MangaChapterItem {
  const copied = JSON.parse(JSON.stringify(chapter)) as MangaChapterItem
  copied.id = id
  return copied
}

export interface SourceChapterIdentityResolution {
  chapters: MangaChapterItem[]
  storedChapters: Chapter[]
  removedDuplicateIds: string[]
}

/** Only an exact, unambiguous legacy/current pair within this source/work is eligible. */
export function reconcileSourceChapterIdentity(
  comic: Comic,
  mangaId: string,
  chapters: MangaChapterItem[],
  protectedChapterIds: Set<string> | undefined,
): SourceChapterIdentityResolution {
  if (comic.sourceRuntimeId === BAOZI_SOURCE_ID) return reconcileBaoziChapterIdentity(comic, mangaId, chapters)
  const unchanged: SourceChapterIdentityResolution = {
    chapters, storedChapters: comic.chapters, removedDuplicateIds: [],
  }
  const work = workId(comic.sourceRuntimeId, mangaId)
  if (work === undefined) return unchanged
  const storedGroups = new Map<string, Chapter[]>()
  comic.chapters.forEach((chapter: Chapter): void => {
    const key = chapterKey(work, chapter.id)
    if (key !== undefined) storedGroups.set(key, (storedGroups.get(key) ?? []).concat([chapter]))
  })
  const remoteGroups = new Map<string, MangaChapterItem[]>()
  chapters.forEach((chapter: MangaChapterItem): void => {
    const key = chapterKey(work, chapter.id)
    if (key !== undefined) remoteGroups.set(key, (remoteGroups.get(key) ?? []).concat([chapter]))
  })
  const aliases = new Map<string, string>()
  const removed = new Set<string>()
  storedGroups.forEach((stored: Chapter[], key: string): void => {
    const legacy = stored.filter((chapter: Chapter): boolean => chapter.id.startsWith('/go/'))
    const current = stored.filter((chapter: Chapter): boolean => !chapter.id.startsWith('/go/'))
    const remote = remoteGroups.get(key) ?? []
    const currentIds = new Set<string>(remote.filter((chapter: MangaChapterItem): boolean =>
      !chapter.id.startsWith('/go/')).map((chapter: MangaChapterItem): string => chapter.id))
    if (legacy.length !== 1 || current.length > 1 || currentIds.size !== 1 ||
      remote.some((chapter: MangaChapterItem): boolean =>
        chapter.id.startsWith('/go/') && chapter.id !== legacy[0].id)) return
    const currentId = Array.from(currentIds)[0]
    if (current.length === 1 && current[0].id !== currentId) return
    aliases.set(currentId, legacy[0].id)
    if (current.length === 1 && current[0].pages.length === 0 && current[0].pageCount === 0 &&
      protectedChapterIds !== undefined && !protectedChapterIds.has(currentId) &&
      !remote.some((chapter: MangaChapterItem): boolean => chapter.id === currentId &&
        (chapter.isRead || chapter.isDownloaded || chapter.downloadStatus !== undefined))) {
      removed.add(currentId)
    }
  })
  if (aliases.size === 0) return unchanged
  const targets = new Set<string>(Array.from(aliases.values()))
  const seen = new Set<string>()
  const resolved: MangaChapterItem[] = []
  chapters.forEach((chapter: MangaChapterItem): void => {
    const id = aliases.get(chapter.id) ?? chapter.id
    if (targets.has(id) && seen.has(id)) return
    seen.add(id)
    resolved.push(id === chapter.id ? chapter : withChapterId(chapter, id))
  })
  return {
    chapters: resolved,
    storedChapters: comic.chapters.filter((chapter: Chapter): boolean => !removed.has(chapter.id)),
    removedDuplicateIds: Array.from(removed),
  }
}

/** An old history ID may resolve through the same exact pair without changing that history ID. */
export function sourceChapterForRetainedIdentity(
  sourceId: string, mangaId: string, chapterId: string, chapters: MangaChapterItem[],
): MangaChapterItem | undefined {
  const exact = chapters.find((chapter: MangaChapterItem): boolean => chapter.id === chapterId)
  if (exact !== undefined) return exact
  if (sourceId === BAOZI_SOURCE_ID) {
    const work = baoziWork(mangaId)
    const retained = work === undefined ? undefined : baoziChapterIdentity(work, chapterId)
    // An orphaned legacy ID carries no title: a unique current slot alone
    // cannot prove which old chapter it was. Existing stored chapters resume
    // directly; a title-bearing history ID can use an exact title match here.
    if (work === undefined || retained?.title === undefined) return undefined
    const group = chapters.filter((chapter: MangaChapterItem): boolean =>
      baoziChapterIdentity(work, chapter.id)?.base === retained.base)
    const matches = group.filter((chapter: MangaChapterItem): boolean => chapter.title === retained.title)
    const ids = new Set<string>(matches.map((chapter: MangaChapterItem): string => chapter.id))
    if (ids.size !== 1 || group.some((chapter: MangaChapterItem): boolean =>
      chapter.id === matches[0]?.id && chapter.title !== retained.title)) return undefined
    return withChapterId(matches[0], chapterId)
  }
  const work = workId(sourceId, mangaId)
  if (work === undefined || legacyIdentity(chapterId) === undefined) return undefined
  const key = chapterKey(work, chapterId)
  if (key === undefined) return undefined
  const matching = chapters.filter((chapter: MangaChapterItem): boolean => chapterKey(work, chapter.id) === key)
  if (matching.length !== 1 || matching[0].id.startsWith('/go/')) return undefined
  return withChapterId(matching[0], chapterId)
}
