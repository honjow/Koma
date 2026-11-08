import { Chapter, Comic } from './ComicModels'
import { MangaChapterItem } from './MangaDetailModels'

import { SourceChapterIdentityPolicy, SourceLegacyChapterEncoding } from '../sourceRuntime/SourceWebsitePolicy'

interface TitledChapterIdentity {
  base: string
  title?: string
}

function identitySlot(id: string, prefix: string, suffix: string = ''): string | undefined {
  if (!id.startsWith(prefix) || !id.endsWith(suffix) || id.length <= prefix.length + suffix.length) return undefined
  return id.slice(prefix.length, id.length - suffix.length)
}

function chapterPrefix(work: string, policy: SourceChapterIdentityPolicy): string {
  return policy.chapterPrefix + work + policy.chapterSeparator
}

function titledChapterIdentity(work: string, id: string, policy: SourceChapterIdentityPolicy,
  separator: string): TitledChapterIdentity | undefined {
  const index = id.indexOf(separator, chapterPrefix(work, policy).length)
  const base = index < 0 ? id : id.slice(0, index)
  if (identitySlot(base, chapterPrefix(work, policy), policy.chapterSuffix) === undefined) return undefined
  return { base, title: index < 0 ? undefined : id.slice(index + separator.length) }
}

function titledWork(mangaId: string, policy: SourceChapterIdentityPolicy, separator: string): string | undefined {
  const work = identitySlot(mangaId, policy.workPrefix, policy.workSuffix)
  return work !== undefined && !work.includes(separator) && !work.includes(policy.chapterSeparator) ? work : undefined
}

function chapterIdentityConflict(): void {
  throw new Error('source_chapter_identity_ambiguous')
}

/** Keep persisted IDs in both directions; never infer a missing legacy title. */
function reconcileTitledChapterIdentity(
  comic: Comic, mangaId: string, chapters: MangaChapterItem[],
  policy: SourceChapterIdentityPolicy, separator: string,
): SourceChapterIdentityResolution {
  const unchanged: SourceChapterIdentityResolution = {
    chapters, storedChapters: comic.chapters, removedDuplicateIds: [],
  }
  const work = titledWork(mangaId, policy, separator)
  if (work === undefined || comic.chapters.length === 0) return unchanged
  const storedGroups = new Map<string, Chapter[]>()
  const remoteGroups = new Map<string, MangaChapterItem[]>()
  comic.chapters.forEach((chapter: Chapter): void => {
    const key = titledChapterIdentity(work, chapter.id, policy, separator)?.base
    if (key !== undefined) storedGroups.set(key, (storedGroups.get(key) ?? []).concat([chapter]))
  })
  chapters.forEach((chapter: MangaChapterItem): void => {
    const key = titledChapterIdentity(work, chapter.id, policy, separator)?.base
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

function numericWork(mangaId: string, policy: SourceChapterIdentityPolicy): string | undefined {
  const work = identitySlot(mangaId, policy.workPrefix, policy.workSuffix)
  return work !== undefined && /^[1-9][0-9]*$/.test(work) ? work : undefined
}

// Decode only the observed unpadded base64url identity. The opaque suffix is
// validated, never calculated or used to construct a request URL.
function legacyIdentity(id: string, legacy: SourceLegacyChapterEncoding): string[] | undefined {
  const token = identitySlot(id, legacy.prefix)
  if (token === undefined || token.length > 256 || token.length % 4 === 1 || !/^[A-Za-z0-9_-]+$/.test(token)) return undefined
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
  const parts = decoded.split(legacy.separator)
  return parts.length === 3 && /^[1-9][0-9]*$/.test(parts[0]) && /^[1-9][0-9]*$/.test(parts[1]) &&
    parts[2].length === legacy.hexSuffixLength && /^[0-9a-f]+$/.test(parts[2]) ? parts : undefined
}

function chapterKey(work: string, id: string, policy: SourceChapterIdentityPolicy,
  legacy: SourceLegacyChapterEncoding): string | undefined {
  const current = identitySlot(id, chapterPrefix(work, policy), policy.chapterSuffix)
  if (current !== undefined && /^[1-9][0-9]*$/.test(current)) return current
  const parts = legacyIdentity(id, legacy)
  return parts !== undefined && parts[0] === work ? parts[1] : undefined
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
  policy?: SourceChapterIdentityPolicy,
): SourceChapterIdentityResolution {
  if (policy?.titleSeparator !== undefined) {
    return reconcileTitledChapterIdentity(comic, mangaId, chapters, policy, policy.titleSeparator)
  }
  const unchanged: SourceChapterIdentityResolution = {
    chapters, storedChapters: comic.chapters, removedDuplicateIds: [],
  }
  const legacyFormat = policy?.encodedLegacy
  if (policy === undefined || legacyFormat === undefined) return unchanged
  const work = numericWork(mangaId, policy)
  if (work === undefined) return unchanged
  const storedGroups = new Map<string, Chapter[]>()
  comic.chapters.forEach((chapter: Chapter): void => {
    const key = chapterKey(work, chapter.id, policy, legacyFormat)
    if (key !== undefined) storedGroups.set(key, (storedGroups.get(key) ?? []).concat([chapter]))
  })
  const remoteGroups = new Map<string, MangaChapterItem[]>()
  chapters.forEach((chapter: MangaChapterItem): void => {
    const key = chapterKey(work, chapter.id, policy, legacyFormat)
    if (key !== undefined) remoteGroups.set(key, (remoteGroups.get(key) ?? []).concat([chapter]))
  })
  const aliases = new Map<string, string>()
  const removed = new Set<string>()
  storedGroups.forEach((stored: Chapter[], key: string): void => {
    const legacy = stored.filter((chapter: Chapter): boolean => chapter.id.startsWith(legacyFormat.prefix))
    const current = stored.filter((chapter: Chapter): boolean => !chapter.id.startsWith(legacyFormat.prefix))
    const remote = remoteGroups.get(key) ?? []
    const currentIds = new Set<string>(remote.filter((chapter: MangaChapterItem): boolean =>
      !chapter.id.startsWith(legacyFormat.prefix)).map((chapter: MangaChapterItem): string => chapter.id))
    if (legacy.length !== 1 || current.length > 1 || currentIds.size !== 1 ||
      remote.some((chapter: MangaChapterItem): boolean =>
        chapter.id.startsWith(legacyFormat.prefix) && chapter.id !== legacy[0].id)) return
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
  policy: SourceChapterIdentityPolicy | undefined, mangaId: string, chapterId: string, chapters: MangaChapterItem[],
): MangaChapterItem | undefined {
  const exact = chapters.find((chapter: MangaChapterItem): boolean => chapter.id === chapterId)
  if (exact !== undefined) return exact
  if (policy === undefined) return undefined
  const separator = policy.titleSeparator
  if (separator !== undefined) {
    const work = titledWork(mangaId, policy, separator)
    const retained = work === undefined ? undefined : titledChapterIdentity(work, chapterId, policy, separator)
    // An orphaned legacy ID carries no title: a unique current slot alone
    // cannot prove which old chapter it was. Existing stored chapters resume
    // directly; a title-bearing history ID can use an exact title match here.
    if (work === undefined || retained?.title === undefined) return undefined
    const group = chapters.filter((chapter: MangaChapterItem): boolean =>
      titledChapterIdentity(work, chapter.id, policy, separator)?.base === retained.base)
    const matches = group.filter((chapter: MangaChapterItem): boolean => chapter.title === retained.title)
    const ids = new Set<string>(matches.map((chapter: MangaChapterItem): string => chapter.id))
    if (ids.size !== 1 || group.some((chapter: MangaChapterItem): boolean =>
      chapter.id === matches[0]?.id && chapter.title !== retained.title)) return undefined
    return withChapterId(matches[0], chapterId)
  }
  const legacyFormat = policy.encodedLegacy
  if (legacyFormat === undefined) return undefined
  const work = numericWork(mangaId, policy)
  if (work === undefined || legacyIdentity(chapterId, legacyFormat) === undefined) return undefined
  const key = chapterKey(work, chapterId, policy, legacyFormat)
  if (key === undefined) return undefined
  const matching = chapters.filter((chapter: MangaChapterItem): boolean => chapterKey(work, chapter.id, policy, legacyFormat) === key)
  if (matching.length !== 1 || matching[0].id.startsWith(legacyFormat.prefix)) return undefined
  return withChapterId(matching[0], chapterId)
}
