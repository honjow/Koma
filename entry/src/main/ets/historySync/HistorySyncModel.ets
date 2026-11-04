/**
 * Wire format v1 covers installed book sources. Source, work and chapter IDs are
 * exact. Titles are display metadata. Page URLs, page IDs, statistics, bookmarks,
 * private-library accounts and local-file identities stay out of the wire format.
 */
export interface SyncWorkIdentity {
  sourceId: string
  mangaId: string
}

export interface SyncPosition {
  updatedAt: number
  pageIndex: number
  totalPages: number
  columnMode?: 'odd_left' | 'even_left'
}

export interface SyncRecent {
  updatedAt: number
  deleted: boolean
  chapterId?: string
  title?: string
  chapterTitle?: string
}

export interface SyncChapter {
  chapterId: string
  readAt: number
  isRead: boolean
  position?: SyncPosition
}

export interface SyncWork extends SyncWorkIdentity {
  recent?: SyncRecent
  chapters: SyncChapter[]
}

export function syncWorkKey(identity: SyncWorkIdentity): string {
  return JSON.stringify([identity.sourceId, identity.mangaId])
}

function isNewer(time: number, value: Object, otherTime: number, other: Object): boolean {
  return time > otherTime || (time === otherTime && JSON.stringify(value) > JSON.stringify(other))
}

function mergeRecent(a?: SyncRecent, b?: SyncRecent): SyncRecent | undefined {
  if (a === undefined || b === undefined) return a ?? b
  if (a.updatedAt === b.updatedAt && a.deleted !== b.deleted) return a.deleted ? a : b
  return isNewer(a.updatedAt, a, b.updatedAt, b) ? a : b
}

function mergePosition(a?: SyncPosition, b?: SyncPosition): SyncPosition | undefined {
  if (a === undefined || b === undefined) return a ?? b
  return isNewer(a.updatedAt, a, b.updatedAt, b) ? a : b
}

function mergeChapters(a: SyncChapter[], b: SyncChapter[]): SyncChapter[] {
  const byId = new Map<string, SyncChapter>()
  a.forEach((row: SyncChapter): void => { byId.set(row.chapterId, row) })
  b.forEach((row: SyncChapter): void => {
    const old = byId.get(row.chapterId)
    if (old === undefined) {
      byId.set(row.chapterId, row)
      return
    }
    // Prefer an explicit unread fact at an exact clock tie. Position has its own clock.
    const useIncoming = row.readAt > old.readAt || (row.readAt === old.readAt && !row.isRead)
    byId.set(row.chapterId, {
      chapterId: row.chapterId,
      readAt: useIncoming ? row.readAt : old.readAt,
      isRead: useIncoming ? row.isRead : old.isRead,
      position: mergePosition(old.position, row.position),
    })
  })
  return Array.from(byId.values()).sort((left: SyncChapter, right: SyncChapter): number =>
    left.chapterId < right.chapterId ? -1 : left.chapterId > right.chapterId ? 1 : 0)
}

export function mergeSyncWorks(a: SyncWork[], b: SyncWork[]): SyncWork[] {
  const works = new Map<string, SyncWork>()
  a.concat(b).forEach((row: SyncWork): void => {
    const key = syncWorkKey(row)
    const old = works.get(key)
    works.set(key, {
      sourceId: row.sourceId,
      mangaId: row.mangaId,
      recent: mergeRecent(old?.recent, row.recent),
      chapters: mergeChapters(old?.chapters ?? [], row.chapters),
    })
  })
  return Array.from(works.keys()).sort().map((key: string): SyncWork => works.get(key) as SyncWork)
}

function nonEmptyText(value: string, max: number): boolean {
  return typeof value === 'string' && value.length > 0 && value.length <= max && value === value.trim()
}

function clock(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0
}

function validPosition(position: SyncPosition): boolean {
  return position !== null && typeof position === 'object' && clock(position.updatedAt) &&
    clock(position.pageIndex) && clock(position.totalPages) && position.totalPages > position.pageIndex &&
    (position.columnMode === undefined || position.columnMode === 'odd_left' || position.columnMode === 'even_left')
}

/** Validate and reconstruct the wire allowlist before merging or writing to the reader store. */
export function parseSyncWorks(payload: string): SyncWork[] {
  const parsed = JSON.parse(payload) as SyncWork[]
  if (!Array.isArray(parsed)) throw new Error('data')
  const keys = new Set<string>()
  return parsed.map((work: SyncWork): SyncWork => {
    if (work === null || typeof work !== 'object' || !nonEmptyText(work.sourceId, 512) ||
      !nonEmptyText(work.mangaId, 8192) || !Array.isArray(work.chapters)) throw new Error('data')
    const key = syncWorkKey(work)
    if (keys.has(key)) throw new Error('data')
    keys.add(key)
    let recent: SyncRecent | undefined
    const value = work.recent
    if (value !== undefined) {
      if (value === null || typeof value !== 'object' || !clock(value.updatedAt) ||
        typeof value.deleted !== 'boolean') throw new Error('data')
      if (value.deleted) {
        recent = { updatedAt: value.updatedAt, deleted: true }
      } else {
        if (value.chapterId === undefined || !nonEmptyText(value.chapterId, 8192) ||
          value.title === undefined || !nonEmptyText(value.title, 8192) ||
          (value.chapterTitle !== undefined && !nonEmptyText(value.chapterTitle, 8192))) throw new Error('data')
        recent = { updatedAt: value.updatedAt, deleted: false, chapterId: value.chapterId,
          title: value.title, chapterTitle: value.chapterTitle }
      }
    }
    const ids = new Set<string>()
    const chapters = work.chapters.map((row: SyncChapter): SyncChapter => {
      if (row === null || typeof row !== 'object' || !nonEmptyText(row.chapterId, 8192) ||
        !clock(row.readAt) || typeof row.isRead !== 'boolean' || ids.has(row.chapterId)) throw new Error('data')
      ids.add(row.chapterId)
      const pos = row.position
      if (pos !== undefined && !validPosition(pos)) throw new Error('data')
      const position: SyncPosition | undefined = pos === undefined ? undefined :
        { updatedAt: pos.updatedAt, pageIndex: pos.pageIndex, totalPages: pos.totalPages, columnMode: pos.columnMode }
      return { chapterId: row.chapterId, readAt: row.readAt, isRead: row.isRead, position }
    })
    if (recent !== undefined && !recent.deleted && !chapters.some((chapter: SyncChapter): boolean =>
      chapter.chapterId === recent?.chapterId && chapter.position !== undefined)) throw new Error('data')
    return { sourceId: work.sourceId, mangaId: work.mangaId, recent, chapters }
  })
}
