import { Chapter, Comic } from './ComicModels'
import { MangaChapterItem } from './MangaDetailModels'

export function chapterSortKey(chapter: MangaChapterItem, index: number): string {
  if (chapter.chapterNumber !== undefined) {
    return `${chapter.chapterNumber}`
  }
  if (chapter.volumeNumber !== undefined && chapter.volumeNumber.length > 0) {
    return `${chapter.volumeNumber}:${index}`
  }
  return `${index}`
}

export function enrichSourceChapterMetadata(comic: Comic, remoteChapters: MangaChapterItem[]): boolean {
  const remoteById = new Map<string, MangaChapterItem>()
  remoteChapters.forEach((chapter: MangaChapterItem): void => { remoteById.set(chapter.id, chapter) })
  let changed = false
  comic.chapters.forEach((chapter: Chapter): void => {
    const remote = remoteById.get(chapter.id)
    if (remote === undefined) {
      return
    }
    // A successfully resolved source snapshot owns sequence metadata and language, including unknown.
    if (remote.language !== chapter.language) {
      chapter.language = remote.language
      changed = true
    }
    if (remote.chapterNumber !== chapter.chapterNumber) {
      chapter.chapterNumber = remote.chapterNumber
      changed = true
    }
    if (remote.volumeNumber !== chapter.volumeNumber) {
      chapter.volumeNumber = remote.volumeNumber
      changed = true
    }
    if (remote.readingOrder !== chapter.readingOrder) {
      chapter.readingOrder = remote.readingOrder
      changed = true
    }
    if (remote.readingGroup !== chapter.readingGroup) {
      chapter.readingGroup = remote.readingGroup
      changed = true
    }
    if (remote.continuationEligible !== chapter.continuationEligible) {
      chapter.continuationEligible = remote.continuationEligible
      changed = true
    }
    if (remote.dateUpload !== undefined && remote.dateUpload !== chapter.dateUpload) {
      chapter.dateUpload = remote.dateUpload
      changed = true
    }
    const sortKey = chapterSortKey(remote, chapter.index)
    if (sortKey !== chapter.sortKey) {
      chapter.sortKey = sortKey
      changed = true
    }
  })
  return changed
}
