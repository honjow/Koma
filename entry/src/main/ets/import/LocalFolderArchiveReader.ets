import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ArchiveExtractionService } from './ArchiveExtractionService'
import { copyPickedArchiveUriToSandbox } from './LocalImportCoordinator'
import { Chapter, Page } from '../model/ComicModels'
import { ComicArchiveBookmark } from './ComicArchiveBookmarkParser'

export interface LocalFolderArchivePages {
  rootDir: string
  pages: Page[]
  bookmarks: ComicArchiveBookmark[]
}

/** The selected folder owns the outer chapter identity. An archive may hold
 * several inner chapters; keep their pages in order and expose their offsets
 * as reader contents without persisting temporary extraction paths. */
export function flattenFolderArchiveChapters(chapters: Chapter[]): LocalFolderArchivePages {
  const pages: Page[] = []
  const bookmarks: ComicArchiveBookmark[] = []
  chapters.forEach((chapter: Chapter): void => {
    if (chapter.pages.length === 0) return
    if (chapters.length > 1) bookmarks.push({ title: chapter.title, pageIndex: pages.length })
    chapter.pages.forEach((page: Page): void => { pages.push(page) })
  })
  return { rootDir: '', pages, bookmarks }
}

/** The folder remains the authority. Extract a chapter only for this reader
 * session, so an updated archive is read again on the next open and no cache
 * path becomes part of the persistent library or reading history. */
export async function openLocalFolderArchive(cacheDir: string, sourceUri: string): Promise<LocalFolderArchivePages> {
  const parent = `${cacheDir}/local-folder-archives`
  try {
    await fs.mkdir(parent, true)
  } catch (error) {
    if ((error as BusinessError).code !== 13900015 || !(await fs.stat(parent)).isDirectory()) throw error as Error
  }
  const rootDir = `${parent}/${util.generateRandomUUID()}`
  await fs.mkdir(rootDir, false)
  try {
    const sandboxZipPath = `${rootDir}/archive.zip`
    await copyPickedArchiveUriToSandbox(sourceUri, sandboxZipPath)
    const result = await new ArchiveExtractionService().extractArchive({
      archivePath: sourceUri,
      sandboxZipPath,
      extractionDir: `${rootDir}/extract`,
      cleanOutputDir: false,
    })
    const opened = flattenFolderArchiveChapters(result.importResult.comic.chapters)
    opened.rootDir = rootDir
    return opened
  } catch (error) {
    await removeLocalFolderArchive(rootDir)
    throw error as Error
  }
}

export async function removeLocalFolderArchive(rootDir: string): Promise<void> {
  try { await fs.rmdir(rootDir) } catch (_error) { /* Cache may already be gone. */ }
}
