import { hash } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { Chapter, Comic, ComicSourceKind, Page, copyLocalImportOrigin, copyComicPersonalFields,
  assignComicSourceCover } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService, upsertComicAndPersistLibraryStore } from '../model/LibraryPersistence'
import { parsePdfPageUri } from './PdfPageService'
import { parseComicZipPage, readComicZipPage } from './ComicZipPage'
import { isEpubArchivePath } from './ImageSortUtils'

function sameSourceUris(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((uri: string, index: number): boolean => uri === right[index])
}

export function findPreviousLocalImport(libraryStore: LibraryStore, fresh: Comic): Comic | undefined {
  const origin = fresh.localImportOrigin
  if (origin === undefined) throw new Error('Local import origin missing')
  const matches = libraryStore.listComicSummariesByKind([fresh.sourceKind]).filter((comic: Comic): boolean => {
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
  return matches[0] === undefined ? undefined : libraryStore.getComic(matches[0].id)
}

function localPagePath(uri: string): string {
  if (!uri.startsWith('file://')) throw new Error('Local import page is not a sandbox file')
  return decodeURIComponent(uri.substring('file://'.length))
}

export async function localImportImageHash(uri: string): Promise<string> {
  const zip = parseComicZipPage(uri)
  if (zip === undefined) return hash.hash(localPagePath(uri), 'sha256')
  const bytes = await readComicZipPage(zip)
  const digest = cryptoFramework.createMd('SHA256')
  await digest.update({ data: new Uint8Array(bytes) })
  const result = await digest.digest()
  return Array.from(result.data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}

export async function matchLocalImportChapters(previous: Comic, fresh: Comic): Promise<Map<number, number>> {
  const hashes = new Map<string, string>()
  const archiveHash = async (path: string): Promise<string> => {
    const cached = hashes.get(path)
    if (cached !== undefined) return cached
    const digest = await hash.hash(path, 'sha256')
    hashes.set(path, digest)
    return digest
  }
  const samePages = async (oldPages: Page[], newPages: Page[]): Promise<boolean> => {
    if (oldPages.length !== newPages.length) return false
    for (let index = 0; index < newPages.length; index += 1) {
      const newPdf = parsePdfPageUri(newPages[index].uri)
      const oldPdf = parsePdfPageUri(oldPages[index].uri)
      if (newPdf !== undefined || oldPdf !== undefined) {
        if (newPdf === undefined || oldPdf === undefined || newPdf.index !== oldPdf.index) return false
        const newHash = await archiveHash(newPdf.path)
        try {
          if (await archiveHash(oldPdf.path) !== newHash) return false
        } catch (_error) { return false }
        continue
      }
      const newZip = parseComicZipPage(newPages[index].uri)
      const oldZip = parseComicZipPage(oldPages[index].uri)
      if (newZip !== undefined && oldZip !== undefined && newZip.entry === oldZip.entry) {
        const newHash = await archiveHash(newZip.archive)
        try {
          if (await archiveHash(oldZip.archive) === newHash) continue
        } catch (_error) { return false }
      }
      // New content must be readable. Missing old content can only invalidate
      // resume; it is never a reason to discard a valid newly selected copy.
      const newHash = await localImportImageHash(newPages[index].uri)
      let oldHash: string
      try {
        oldHash = await localImportImageHash(oldPages[index].uri)
      } catch (_error) {
        return false
      }
      if (oldHash !== newHash) return false
    }
    return true
  }

  // A nested archive has its own source path. ZIP folders can share the
  // outer path, so include the chapter title when matching shifted entries.
  const key = (chapter: Chapter): string => `${chapter.sourcePath}\n${chapter.title}`
  const uniqueIndices = (chapters: Chapter[]): Map<string, number> => {
    const indices = new Map<string, number>()
    chapters.forEach((chapter: Chapter, index: number): void => {
      const origin = key(chapter)
      indices.set(origin, indices.has(origin) ? -1 : index)
    })
    return indices
  }
  const oldIndices = uniqueIndices(previous.chapters)
  const newIndices = uniqueIndices(fresh.chapters)
  const matched = new Map<number, number>()
  const usedOld = new Set<number>()
  for (let index = 0; index < fresh.chapters.length; index += 1) {
    const chapter = fresh.chapters[index]
    const origin = key(chapter)
    const oldIndex = oldIndices.get(origin)
    if (oldIndex === undefined || oldIndex < 0 || newIndices.get(origin) !== index) continue
    if (await samePages(previous.chapters[oldIndex].pages, chapter.pages)) {
      matched.set(index, oldIndex)
      usedOld.add(oldIndex)
    }
  }
  // When the list size is unchanged, also retain byte-identical chapters at
  // the same position, such as an older import with a different title.
  if (previous.chapters.length === fresh.chapters.length) {
    for (let index = 0; index < fresh.chapters.length; index += 1) {
      if (matched.has(index) || usedOld.has(index)) continue
      const old = previous.chapters[index]
      const chapter = fresh.chapters[index]
      const origin = key(chapter)
      if (oldIndices.get(origin) === index && newIndices.get(origin) === index) continue
      if (old.sourcePath === chapter.sourcePath && await samePages(old.pages, chapter.pages)) {
        matched.set(index, index)
      }
    }
  }
  return matched
}

export function mergeLocalImport(previous: Comic | undefined, fresh: Comic, matches: Map<number, number>): Comic {
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
    const oldIndex = matches.get(chapterIndex)
    const oldChapter = oldIndex === undefined ? undefined : previous.chapters[oldIndex]
    chapter.comicId = previous.id
    chapter.id = oldChapter?.id ?? `${previous.id}-chapter-${util.generateRandomUUID()}`
    chapter.createdAt = oldChapter?.createdAt ?? chapter.createdAt
    chapter.pages.forEach((page: Page, index: number): void => {
      page.comicId = previous.id
      page.chapterId = chapter.id
      page.id = oldChapter?.pages[index].id ?? `${chapter.id}-page-${index + 1}`
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

  const epub = fresh.sourceKind === ComicSourceKind.LOCAL_ARCHIVE && isEpubArchivePath(fresh.localImportOrigin.sourceUris[0] ?? '')
  const oldCover = previous.customCoverUri ? previous.sourceCoverUri : previous.coverUri
  if (!epub && oldCover !== undefined) {
    const firstPdf = parsePdfPageUri(previous.chapters[0]?.pages[0]?.uri ?? '')
    const pdfDir = firstPdf?.path.substring(0, firstPdf.path.lastIndexOf('/'))
    const generatedPdfCover = pdfDir !== undefined && oldCover === `file://${pdfDir}/extract/cover.jpg`
    const oldCoverChapter = previous.chapters.findIndex((chapter): boolean =>
      chapter.pages.some((page: Page): boolean => page.uri === oldCover))
    const oldCoverIndex = oldCoverChapter < 0 ? -1 : previous.chapters[oldCoverChapter].pages.findIndex(
      (page: Page): boolean => page.uri === oldCover)
    const replacement = fresh.chapters.find((_chapter: Chapter, index: number): boolean => matches.get(index) === oldCoverChapter)
    if (replacement !== undefined && oldCoverIndex >= 0) {
      fresh.coverUri = replacement.pages[oldCoverIndex].uri
    } else if (!previous.customCoverUri && !generatedPdfCover && (oldCoverChapter !== 0 || oldCoverIndex !== 0)) {
      // Explicit cover remains reachable in the retained previous generation.
      fresh.coverUri = oldCover
    }
  }
  const sourceCover = fresh.coverUri
  copyComicPersonalFields(previous, fresh)
  if (sourceCover !== undefined) assignComicSourceCover(fresh, sourceCover)
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

  runExclusive<T>(write: () => Promise<T>): Promise<T> {
    const previous = this.pending
    const result = BackupRestoreActivity.runWrite((): Promise<T> => previous.then(write))
    this.pending = result.then((): void => {}, (_error: Error): void => {})
    return result
  }

  commit(fresh: Comic): Promise<void> {
    return this.runExclusive(async (): Promise<void> => {
      const previous = findPreviousLocalImport(this.libraryStore, fresh)
      if (previous === undefined && this.libraryStore.getComic(fresh.id) !== undefined) {
        throw new Error('Local import identity collision')
      }
      const matches = previous === undefined ? new Map<number, number>() : await matchLocalImportChapters(previous, fresh)
      // Metadata can be edited while hashes run. Preserve the latest user row.
      const latest = previous === undefined ? undefined : this.libraryStore.getComic(previous.id)
      if (previous !== undefined && (latest === undefined || latest.chapters.length !== previous.chapters.length ||
        latest.chapters.some((chapter, index): boolean => chapter.id !== previous.chapters[index].id))) {
        throw new Error('Local import changed during commit')
      }
      const merged = mergeLocalImport(latest, fresh, matches)
      upsertComicAndPersistLibraryStore(this.libraryStore, this.persistenceService, merged)
    })
  }
}
