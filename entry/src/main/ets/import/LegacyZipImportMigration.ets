import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs, fileUri, hash } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { Chapter, Comic, ComicSourceKind, Page, copyComicShell } from '../model/ComicModels'
import { komaContentStorageBase } from '../model/KomaContentStorage'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { localLibraryFolderRootUriFromComic } from '../model/LocalLibraryFolderContract'
import { ArchiveExtractionService, createArchiveExtractionCachePaths } from './ArchiveExtractionService'
import { comicZipPageUri, isComicZip, parseComicZipPage } from './ComicZipPage'
import { createManagedImportPaths, createManagedImportRoot } from './LocalImportCoordinator'
import { LocalImportCommitService, localImportImageHash } from './LocalImportCommitService'
import { parsePdfPageUri, pdfPageUri } from './PdfPageService'

const MANAGED_IMPORT_NAME = /^v1-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i
const EXTRACTED_ENTRY = /^((?:extract\.chapters\/[0-9]+\/)*)extract\/([\s\S]+)$/
const NOT_FOUND = 13900002

interface MigrationJournal {
  comicId: string
  origin: string
  oldRoot: string
  newRoot: string
}

function filePath(uri: string): string {
  if (uri.startsWith('/')) return uri
  if (!uri.startsWith('file://')) return ''
  try {
    return uri.startsWith('file:///') ? decodeURIComponent(uri.substring(7)) : new fileUri.FileUri(uri).path
  } catch (_error) { return '' }
}

function referencePath(uri: string): string {
  return parseComicZipPage(uri)?.archive ?? parsePdfPageUri(uri)?.path ?? filePath(uri)
}

function within(path: string, root: string): boolean {
  return path === root || path.startsWith(root + '/')
}

function managedRoot(path: string, bases: string[]): string | undefined {
  if (path.includes('\\') || path.includes('\u0000') || /\/(?:\.{1,2})(?:\/|$)/.test(path)) return undefined
  for (const base of bases) {
    const prefix = base.replace(/\/+$/, '') + '/import/'
    if (!path.startsWith(prefix)) continue
    const name = path.substring(prefix.length).split('/')[0]
    if (MANAGED_IMPORT_NAME.test(name)) return prefix + name
  }
  return undefined
}

function migrationRoot(path: string, context: common.Context, bases: string[], origin: string): string | undefined {
  const current = managedRoot(path, bases)
  if (current !== undefined) return current
  // Pre-UUID imports used this exact origin-derived directory in cacheDir.
  const cache = createArchiveExtractionCachePaths(context.cacheDir, origin, origin).rootDir
  return within(path, cache) ? cache : undefined
}

function coverUris(comic: Comic): string[] {
  return [comic.coverUri ?? '', comic.sourceCoverUri ?? '', comic.customCoverUri ?? '', comic.enhancedCoverUri ?? '']
}

function sourceUris(comic: Comic): string[] {
  return [comic.sourcePath, ...(comic.localImportOrigin?.sourceUris ?? []), localLibraryFolderRootUriFromComic(comic) ?? '']
}

function referenceUnder(comic: Comic, root: string): boolean {
  return sourceUris(comic).concat(coverUris(comic)).some((uri: string): boolean => within(referencePath(uri), root)) ||
    comic.chapters.some((chapter: Chapter): boolean => within(referencePath(chapter.sourcePath), root) ||
      chapter.pages.some((page: Page): boolean => within(referencePath(page.uri), root)))
}

async function statIfPresent(path: string): Promise<fs.Stat | undefined> {
  try { return await fs.lstat(path) }
  catch (error) {
    if ((error as BusinessError).code === NOT_FOUND) return undefined
    throw error as Error
  }
}

async function checkedDirectory(path: string): Promise<boolean> {
  const stat = await statIfPresent(path)
  if (stat === undefined) return false
  if (!stat.isDirectory()) throw new Error('zip_migration_not_managed_directory')
  return true
}

async function removeGeneration(root: string): Promise<void> {
  const parent = root.substring(0, root.lastIndexOf('/'))
  if (await checkedDirectory(parent) && await checkedDirectory(root)) await fs.rmdir(root)
}

async function removeLegacyFiles(root: string, canRemove: () => boolean): Promise<boolean> {
  const parent = root.substring(0, root.lastIndexOf('/'))
  if (!await checkedDirectory(parent) || !await checkedDirectory(root)) return true
  // The top level may also contain files placed there via the file manager.
  // Only the exact outputs of the old import pipeline belong to this upgrade.
  for (const name of ['extract', 'extract.chapters']) {
    const path = root + '/' + name
    if (await checkedDirectory(path)) {
      if (!canRemove()) return false
      await fs.rmdir(path)
    }
  }
  const archivePath = root + '/archive.zip'
  if ((await statIfPresent(archivePath))?.isFile() === true) {
    if (!canRemove()) return false
    await fs.unlink(archivePath)
  }
  if ((await fs.listFile(root)).length === 0) {
    if (!canRemove()) return false
    await fs.rmdir(root)
  }
  return true
}

function originOf(comic: Comic): string | undefined {
  const origin = comic.localImportOrigin
  if (origin === undefined) return isComicZip(comic.sourcePath) ? comic.sourcePath : undefined
  const uri = origin.sourceUris[0] ?? ''
  return origin.kind === 'archive' && origin.sourceUris.length === 1 && isComicZip(uri) ? uri : undefined
}

function oldGeneration(comic: Comic, context: common.Context, bases: string[], origin: string): string | undefined {
  const first = comic.chapters[0]?.pages[0]
  if (first === undefined) return undefined
  const root = migrationRoot(referencePath(first.uri), context, bases, origin)
  if (root === undefined || sourceUris(comic).some((uri: string): boolean => within(referencePath(uri), root))) return undefined
  const privateRoot = managedRoot(root, [context.filesDir]) !== undefined
  const needsMigration = !privateRoot || comic.chapters.some((chapter: Chapter): boolean =>
    isComicZip(chapter.sourcePath) && chapter.pages.some((page: Page): boolean => filePath(page.uri) !== ''))
  return needsMigration ? root : undefined
}

async function copyVerifiedArchive(source: string, target: string): Promise<void> {
  if (!(await fs.lstat(source)).isFile()) throw new Error('zip_migration_original_missing')
  await fs.copyFile(source, target)
  const file = await fs.open(target, fs.OpenMode.READ_WRITE)
  try { await fs.fsync(file.fd) } finally { await fs.close(file) }
  if (await hash.hash(source, 'sha256') !== await hash.hash(target, 'sha256')) throw new Error('zip_migration_copy_mismatch')
}

class MigratedArchivePages {
  private readonly indexedArchives = new Set<string>()
  private readonly verified = new Map<string, string>()
  private readonly verifiedPdfs = new Set<string>()
  private readonly oldRoot: string
  private readonly newRoot: string

  constructor(oldRoot: string, newRoot: string, fresh: Comic) {
    this.oldRoot = oldRoot
    this.newRoot = newRoot
    this.indexedArchives.add(newRoot + '/archive.zip')
    for (const chapter of fresh.chapters) {
      for (const page of chapter.pages) {
        const zip = parseComicZipPage(page.uri)
        if (zip !== undefined) this.indexedArchives.add(zip.archive)
      }
    }
  }

  async replace(uri: string): Promise<string> {
    const path = referencePath(uri)
    if (!within(path, this.oldRoot)) throw new Error('zip_migration_page_outside_import')
    const cached = this.verified.get(uri)
    if (cached !== undefined) return cached
    const relative = path.substring(this.oldRoot.length + 1)
    if (relative.includes('\\') || relative.includes('\u0000') ||
      relative.split('/').some((part: string): boolean => part === '' || part === '.' || part === '..')) {
      throw new Error('zip_migration_invalid_entry')
    }
    let target: string
    const pdf = parsePdfPageUri(uri)
    if (pdf !== undefined) {
      const next = this.newRoot + '/' + relative
      if (!this.verifiedPdfs.has(path)) {
        if (await hash.hash(path, 'sha256') !== await hash.hash(next, 'sha256')) throw new Error('zip_migration_pdf_mismatch')
        this.verifiedPdfs.add(path)
      }
      target = pdfPageUri(next, pdf.index)
    } else {
      const zip = parseComicZipPage(uri)
      if (zip !== undefined) {
        target = comicZipPageUri(this.newRoot + '/' + relative, zip.entry)
      } else {
        const entry = EXTRACTED_ENTRY.exec(relative)
        if (entry === null) throw new Error('zip_migration_unmapped_file')
        const archive = this.newRoot + '/' + entry[1] + 'archive.zip'
        target = this.indexedArchives.has(archive) ? comicZipPageUri(archive, entry[2]) :
          'file://' + (this.newRoot + '/' + relative).split('/').map((segment: string): string => encodeURIComponent(segment)).join('/')
      }
      if (await localImportImageHash(uri) !== await localImportImageHash(target)) throw new Error('zip_migration_image_mismatch')
    }
    this.verified.set(uri, target)
    return target
  }
}

function journalPath(directory: string, root: string): string {
  return directory + '/' + root.substring(root.lastIndexOf('/') + 1) + '.json'
}

/** Automatic upgrade of Koma's extracted copies. The RDB paths decide which
 * generation survived a stop. The old generation remains readable until the
 * new original, every page and the persisted work have all been verified. */
export class LegacyZipImportMigration {
  private running = false
  private resumeRequested = false
  private scanned = false
  private storageBase = ''
  private mayHaveJournal = true
  private readonly considered = new Set<string>()
  private readonly extraction = new ArchiveExtractionService()
  private readonly library: LibraryStore
  private readonly persistence: LibraryStorePersistenceService
  private readonly imports: LocalImportCommitService

  constructor(library: LibraryStore, persistence: LibraryStorePersistenceService, imports: LocalImportCommitService) {
    this.library = library
    this.persistence = persistence
    this.imports = imports
  }

  async run(context: common.UIAbilityContext, idle: () => boolean, published: () => void): Promise<void> {
    if (!idle() || BackupRestoreActivity.isRestoring()) return
    if (this.running) {
      this.resumeRequested = true
      return
    }
    const storageBase = komaContentStorageBase(context)
    if (this.storageBase !== storageBase) {
      this.storageBase = storageBase
      this.scanned = false
      this.considered.clear()
    }
    if (this.scanned && !this.mayHaveJournal) return
    this.running = true
    const bases = [context.filesDir, storageBase]
    const directory = context.filesDir + '/.koma-zip-import-migration'
    try {
      await this.recover(context, bases, directory, idle)
      if (this.scanned) return
      const summaries = this.library.listComicSummariesByKind([ComicSourceKind.LOCAL_ARCHIVE])
      for (const summary of summaries) {
        if (!idle() || BackupRestoreActivity.isRestoring()) return
        const origin = originOf(summary)
        if (origin === undefined || this.considered.has(summary.id)) continue
        const sourceCover = summary.customCoverUri ? summary.sourceCoverUri : summary.coverUri
        const zipCover = parseComicZipPage(sourceCover ?? '')
        if (zipCover !== undefined && managedRoot(zipCover.archive, [context.filesDir]) !== undefined) continue
        this.considered.add(summary.id)
        try {
          const previous = this.library.getComic(summary.id)
          if (previous === undefined) continue
          const oldRoot = oldGeneration(previous, context, bases, origin)
          if (oldRoot === undefined) continue
          const done = await this.migrate(context, directory, previous, origin, oldRoot, idle)
          if (done) published()
          else {
            this.considered.delete(summary.id)
            return
          }
          await this.recover(context, bases, directory, idle)
        } catch (error) {
          DiagnosticLogger.exception('import', 'zip_upgrade_retained_original', error as Error)
        }
      }
      this.scanned = true
    } catch (error) {
      DiagnosticLogger.exception('import', 'zip_upgrade_recovery_deferred', error as Error)
    } finally {
      this.running = false
      const resume = this.resumeRequested || storageBase !== komaContentStorageBase(context)
      this.resumeRequested = false
      if (resume && idle()) void this.run(context, idle, published)
    }
  }

  private async migrate(context: common.Context, directory: string, previous: Comic, origin: string,
    oldRoot: string, idle: () => boolean): Promise<boolean> {
    return await BackupRestoreActivity.runWrite(async (): Promise<boolean> => {
      const oldParent = oldRoot.substring(0, oldRoot.lastIndexOf('/'))
      if (!await checkedDirectory(oldParent) || !await checkedDirectory(oldRoot)) return true
      const oldArchive = oldRoot + '/archive.zip'
      if ((await statIfPresent(oldArchive))?.isFile() !== true) return true
      if (!await checkedDirectory(directory)) await fs.mkdir(directory)
      const paths = createManagedImportPaths(context.filesDir, origin)
      await createManagedImportRoot(context.filesDir, paths.rootDir)
      const journal: MigrationJournal = { comicId: previous.id, origin, oldRoot, newRoot: paths.rootDir }
      const marker = journalPath(directory, paths.rootDir)
      let committing = false
      try {
        writeAppTextFile(marker, JSON.stringify(journal))
        this.mayHaveJournal = true
        await copyVerifiedArchive(oldArchive, paths.archiveZipPath)
        const prepared = await this.extraction.extractArchive({ archivePath: origin, sandboxZipPath: paths.archiveZipPath,
          extractionDir: paths.extractionDir, cleanOutputDir: false })
        const replacements = new MigratedArchivePages(oldRoot, paths.rootDir, prepared.importResult.comic)
        const next = copyComicShell(previous, 'clone_chapters')
        for (const chapter of next.chapters) {
          const pages: Page[] = []
          for (const page of chapter.pages) {
            if (!idle()) return false
            const uri = await replacements.replace(page.uri)
            const migrated: Page = {
              id: page.id, comicId: page.comicId, chapterId: page.chapterId, index: page.index, fileName: page.fileName,
              uri, sortKey: page.sortKey, width: page.width, height: page.height, byteSize: page.byteSize,
              sourceText: page.sourceText, sourceTextRequest: page.sourceTextRequest,
              sourceTextOverlay: page.sourceTextOverlay, requiredImageDecode: page.requiredImageDecode,
            }
            pages.push(migrated)
          }
          chapter.pages = pages
        }
        const effective = await this.replaceCover(previous.coverUri, oldRoot, replacements)
        const source = await this.replaceCover(previous.sourceCoverUri, oldRoot, replacements)
        return await this.imports.runExclusive(async (): Promise<boolean> => {
          const latest = this.library.getComic(previous.id)
          if (!idle() || latest === undefined || latest.chapters !== previous.chapters || originOf(latest) !== origin ||
            latest.coverUri !== previous.coverUri || latest.sourceCoverUri !== previous.sourceCoverUri) return false
          const committed = copyComicShell(latest)
          committed.chapters = next.chapters
          committed.coverUri = effective
          committed.sourceCoverUri = source
          // Cleanup verifies live references independently of the catalog write.
          committing = true
          this.persistence.persistExistingWorks([committed])
          this.library.upsertComic(committed)
          return true
        })
      } finally {
        if (!committing) {
          await removeGeneration(paths.rootDir)
          if (await statIfPresent(marker) !== undefined) await fs.unlink(marker)
        }
      }
    })
  }

  private async replaceCover(uri: string | undefined, oldRoot: string, replacements: MigratedArchivePages): Promise<string | undefined> {
    if (uri === undefined || !within(referencePath(uri), oldRoot)) return uri
    return await replacements.replace(uri)
  }

  private async recover(context: common.Context, bases: string[], directory: string, idle: () => boolean): Promise<void> {
    if (!idle() || !this.mayHaveJournal) return
    if (!await checkedDirectory(directory)) {
      this.mayHaveJournal = false
      return
    }
    const journals = (await fs.listFile(directory)).filter((name: string): boolean =>
      name.endsWith('.json') && MANAGED_IMPORT_NAME.test(name.slice(0, -5)))
    let remaining = journals.length
    for (const name of journals) {
      if (!idle() || BackupRestoreActivity.isRestoring()) return
      try {
        await this.imports.runExclusive(async (): Promise<void> => {
          const marker = directory + '/' + name
          const row = JSON.parse(await fs.readText(marker, { encoding: 'utf-8' })) as MigrationJournal
          if (typeof row.comicId !== 'string' || typeof row.origin !== 'string' || !isComicZip(row.origin) ||
            typeof row.oldRoot !== 'string' || typeof row.newRoot !== 'string' || row.oldRoot === row.newRoot ||
            migrationRoot(row.oldRoot, context, bases, row.origin) !== row.oldRoot ||
            row.newRoot !== context.filesDir + '/import/' + name.slice(0, -5)) return
          const current = this.library.getComic(row.comicId)
          if (current === undefined || originOf(current) !== row.origin) return
          const newArchive = await statIfPresent(row.newRoot + '/archive.zip')
          if (!idle()) return
          if (referenceUnder(current, row.newRoot)) {
            if (newArchive?.isFile() !== true || this.otherReferences(row.oldRoot, current.id) ||
              referenceUnder(current, row.oldRoot)) return
            if (!await removeLegacyFiles(row.oldRoot, idle)) return
          } else if (referenceUnder(current, row.oldRoot) && !this.otherReferences(row.newRoot, current.id)) {
            await removeGeneration(row.newRoot)
          } else return
          await fs.unlink(marker)
          remaining -= 1
        })
      } catch (error) {
        DiagnosticLogger.exception('import', 'zip_upgrade_cleanup_deferred', error as Error)
      }
    }
    this.mayHaveJournal = remaining > 0
  }

  private otherReferences(root: string, comicId: string): boolean {
    return this.library.listComicSummaries(false).some((summary: Comic): boolean => {
      if (summary.id === comicId) return false
      const folder = filePath(localLibraryFolderRootUriFromComic(summary) ?? '')
      if (folder !== '' && within(root, folder.replace(/\/+$/, ''))) return true
      if (referenceUnder(summary, root)) return true
      const pathsCanBeLocal = summary.sourceKind === ComicSourceKind.LOCAL_ARCHIVE || summary.sourceKind === ComicSourceKind.LOCAL_FOLDER
      const work = pathsCanBeLocal ? this.library.getComic(summary.id) : undefined
      return work !== undefined && work !== summary && referenceUnder(work, root)
    })
  }
}
