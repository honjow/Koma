import { Chapter, Comic } from './ComicModels'
import { MangaChapterItem } from './MangaDetailModels'

const MH1234_SOURCE_ID: string = 'com.mh1234.koma'

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
  const work = workId(sourceId, mangaId)
  if (work === undefined || legacyIdentity(chapterId) === undefined) return undefined
  const key = chapterKey(work, chapterId)
  if (key === undefined) return undefined
  const matching = chapters.filter((chapter: MangaChapterItem): boolean => chapterKey(work, chapter.id) === key)
  if (matching.length !== 1 || matching[0].id.startsWith('/go/')) return undefined
  return withChapterId(matching[0], chapterId)
}
