import { hash } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { Comic, ComicSourceKind, Page, copyLocalImportOrigin } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService, upsertComicAndPersistLibraryStore } from '../model/LibraryPersistence'
import { parsePdfPageUri } from './PdfPageService'

function sameSourceUris(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((uri: string, index: number): boolean => uri === right[index])
}

export function findPreviousLocalImport(libraryStore: LibraryStore, fresh: Comic): Comic | undefined {
  const origin = fresh.localImportOrigin
  if (origin === undefined) throw new Error('Local import origin missing')
  const matches = libraryStore.listComics().filter((comic: Comic): boolean => {
    if (comic.sourceKind !== fresh.sourceKind) return false
    if (comic.localImportOrigin !== undefined) {
      return comic.localImportOrigin.kind === origin.kind && sameSourceUris(comic.localImportOrigin.sourceUris, origin.sourceUris)
    }
    if (origin.kind === 'archive') return comic.sourcePath === origin.sourceUris[0]
    // Old image records did not persist original URIs. Their 32-bit cache
    // hash is not origin evidence; preserve them rather than guess a match.
    return false
  })
  if (matches.length > 1) throw new Error('Ambiguous local import origin')
  return matches[0]
}

function localPagePath(page: Page): string {
  if (!page.uri.startsWith('file://')) throw new Error('Local import page is not a sandbox file')
  return decodeURIComponent(page.uri.substring('file://'.length))
}

export async function sameOrderedLocalImportPages(previous: Comic, fresh: Comic): Promise<boolean> {
  if (previous.chapters.length !== fresh.chapters.length) return false
  const hashes = new Map<string, string>()
  for (let chapterIndex = 0; chapterIndex < fresh.chapters.length; chapterIndex += 1) {
    const oldPages = previous.chapters[chapterIndex].pages
    const newPages = fresh.chapters[chapterIndex].pages
    if (oldPages.length !== newPages.length) return false
    for (let index = 0; index < newPages.length; index += 1) {
      const newPdf = parsePdfPageUri(newPages[index].uri)
      const oldPdf = parsePdfPageUri(oldPages[index].uri)
      if (newPdf !== undefined || oldPdf !== undefined) {
        if (newPdf === undefined || oldPdf === undefined || newPdf.index !== oldPdf.index) return false
        let newHash = hashes.get(newPdf.path)
        if (newHash === undefined) { newHash = await hash.hash(newPdf.path, 'sha256'); hashes.set(newPdf.path, newHash) }
        let oldHash = hashes.get(oldPdf.path)
        try {
          if (oldHash === undefined) { oldHash = await hash.hash(oldPdf.path, 'sha256'); hashes.set(oldPdf.path, oldHash) }
        } catch (_error) { return false }
        if (oldHash !== newHash) return false
        continue
      }
      // New content must be readable. Missing old content can only invalidate
      // resume; it is never a reason to discard a valid newly selected copy.
      const newHash = await hash.hash(localPagePath(newPages[index]), 'sha256')
      let oldHash: string
      try {
        oldHash = await hash.hash(localPagePath(oldPages[index]), 'sha256')
      } catch (_error) {
        return false
      }
      if (oldHash !== newHash) return false
    }
  }
  return true
}

export function mergeLocalImport(previous: Comic | undefined, fresh: Comic, samePages: boolean): Comic {
  if (fresh.localImportOrigin === undefined || fresh.chapters.length === 0 ||
    fresh.chapters.some((chapter): boolean => chapter.pages.length === 0) ||
    (fresh.localImportOrigin.kind === 'archive' && fresh.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE) ||
    (fresh.localImportOrigin.kind === 'images' && fresh.sourceKind !== ComicSourceKind.LOCAL_FOLDER)) {
    throw new Error('Invalid prepared local import')
  }
  fresh.localImportOrigin = copyLocalImportOrigin(fresh.localImportOrigin)
  if (previous === undefined) return fresh

  fresh.id = previous.id
  fresh.chapters.forEach((chapter, chapterIndex): void => {
    const oldChapter = previous.chapters[chapterIndex]
    chapter.comicId = previous.id
    chapter.id = samePages && oldChapter !== undefined ? oldChapter.id : `${previous.id}-chapter-${util.generateRandomUUID()}`
    chapter.createdAt = samePages && oldChapter !== undefined ? oldChapter.createdAt : chapter.createdAt
    chapter.pages.forEach((page: Page, index: number): void => {
      page.comicId = previous.id
      page.chapterId = chapter.id
      page.id = samePages ? oldChapter.pages[index].id : `${chapter.id}-page-${index + 1}`
    })
  })
  fresh.createdAt = previous.createdAt
  fresh.title = previous.title
  fresh.sortTitle = previous.sortTitle
  fresh.author = previous.author ?? fresh.author
  // A previously known description wins; fill a missing one from newly read archive metadata.
  fresh.subtitle = previous.subtitle ?? fresh.subtitle
  fresh.categoryIds = previous.categoryIds?.slice()
  fresh.localMetadata = previous.localMetadata
  fresh.preferredDirection = previous.preferredDirection

  if (previous.coverUri !== undefined) {
    const firstPdf = parsePdfPageUri(previous.chapters[0]?.pages[0]?.uri ?? '')
    const pdfDir = firstPdf?.path.substring(0, firstPdf.path.lastIndexOf('/'))
    const generatedPdfCover = pdfDir !== undefined && previous.coverUri === `file://${pdfDir}/extract/cover.jpg` &&
      previous.customCoverUri === undefined
    const oldCoverChapter = previous.chapters.findIndex((chapter): boolean =>
      chapter.pages.some((page: Page): boolean => page.uri === previous.coverUri))
    const oldCoverIndex = oldCoverChapter < 0 ? -1 : previous.chapters[oldCoverChapter].pages.findIndex(
      (page: Page): boolean => page.uri === previous.coverUri)
    if (samePages && oldCoverChapter >= 0 && oldCoverIndex >= 0) {
      fresh.coverUri = fresh.chapters[oldCoverChapter].pages[oldCoverIndex].uri
    } else if (!generatedPdfCover && (oldCoverChapter !== 0 || oldCoverIndex !== 0)) {
      // Explicit cover remains reachable in the retained previous generation.
      fresh.coverUri = previous.coverUri
    }
  }
  return fresh
}

/** One commit owner for both normal import entries; no separate Reader-store write. */
export class LocalImportCommitService {
  private pending: Promise<void> = Promise.resolve()

  private readonly libraryStore: LibraryStore
  private readonly persistenceService: LibraryStorePersistenceService

  constructor(libraryStore: LibraryStore, persistenceService: LibraryStorePersistenceService) {
    this.libraryStore = libraryStore
    this.persistenceService = persistenceService
  }

  commit(fresh: Comic): Promise<void> {
    const result = BackupRestoreActivity.runWrite(() => this.pending.then(async (): Promise<void> => {
      const previous = findPreviousLocalImport(this.libraryStore, fresh)
      if (previous === undefined && this.libraryStore.getComic(fresh.id) !== undefined) {
        throw new Error('Local import identity collision')
      }
      const samePages = previous !== undefined && await sameOrderedLocalImportPages(previous, fresh)
      // Metadata can be edited while hashes run. Preserve the latest user row.
      const latest = previous === undefined ? undefined : this.libraryStore.getComic(previous.id)
      if (previous !== undefined && (latest === undefined || latest.chapters.length !== previous.chapters.length ||
        latest.chapters.some((chapter, index): boolean => chapter.id !== previous.chapters[index].id))) {
        throw new Error('Local import changed during commit')
      }
      const merged = mergeLocalImport(latest, fresh, samePages)
      upsertComicAndPersistLibraryStore(this.libraryStore, this.persistenceService, merged)
    }))
    this.pending = result.catch((_error: Error): void => {})
    return result
  }
}
