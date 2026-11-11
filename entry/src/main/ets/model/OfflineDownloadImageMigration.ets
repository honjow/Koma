import { fileIo as fs } from '@kit.CoreFileKit'
import { writeAppTextFile } from './AppFileTextPersistence'
import { downloadImagePathForBytes } from './DownloadImageFormat'
import { hasValidOfflineManifestIntegrity, OfflineDownloadStore } from './OfflineDownloadStore'

interface ImageRename {
  oldName: string
  newName: string
}

interface ImageRenameJournal {
  version: number
  renames: ImageRename[]
}

function safeName(name: string): boolean {
  return name.length > 0 && name !== '.' && name !== '..' && !name.includes('/') && !name.includes('\\')
}

function imageHeaderPath(path: string): string {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
  const header = new ArrayBuffer(32)
  try {
    const count = fs.readSync(file.fd, header)
    return downloadImagePathForBytes(path, new Uint8Array(header, 0, count))
  } finally { fs.closeSync(file) }
}

/** Resolve a rename interrupted before or after the atomic manifest commit. */
function recoverChapter(store: OfflineDownloadStore, comicId: string, chapterId: string, chapterDir: string): boolean {
  const path = chapterDir + '/.koma/image-suffix-migration.json'
  if (!fs.accessSync(path)) return true
  const journal = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as ImageRenameJournal
  if (journal.version !== 1 || !Array.isArray(journal.renames)) return false
  const manifest = store.loadManifest(comicId, chapterId)
  if (manifest === undefined || !hasValidOfflineManifestIntegrity(manifest)) return false
  for (const rename of journal.renames) {
    if (!safeName(rename.oldName) || !safeName(rename.newName) || !rename.oldName.toLowerCase().endsWith('.img')) return false
    const oldPath = chapterDir + '/' + rename.oldName
    const newPath = chapterDir + '/' + rename.newName
    const page = manifest.pages.find(item => item.localPath === oldPath || item.localPath === newPath)
    if (page === undefined) return false
    const expected = page.localPath
    const alternate = expected === oldPath ? newPath : oldPath
    if (!fs.accessSync(expected)) {
      if (!fs.accessSync(alternate)) return false
      fs.renameSync(alternate, expected)
    }
  }
  fs.unlinkSync(path)
  return true
}

// Older download layouts can leave unreferenced image files beside the current
// pages. Keep their contents and readable names too, without deleting duplicates.
function migrateUnreferencedImages(chapterDir: string, referencedPaths: string[]): number {
  let count = 0
  for (const name of fs.listFileSync(chapterDir)) {
    if (!safeName(name) || !name.toLowerCase().endsWith('.img')) continue
    const path = chapterDir + '/' + name
    if (referencedPaths.includes(path) || !fs.statSync(path).isFile()) continue
    const target = imageHeaderPath(path)
    if (target === path || fs.accessSync(target)) continue
    fs.renameSync(path, target)
    count++
  }
  return count
}

/** Migrate a single chapter. Originals are renamed only after a recovery journal is durable. */
export function migrateOfflineChapterImageSuffixes(store: OfflineDownloadStore, comicId: string, chapterId: string): number {
  const chapterDir = store.chapterDir(comicId, chapterId)
  if (!recoverChapter(store, comicId, chapterId, chapterDir)) throw new Error('image_suffix_recovery_pending')
  const manifest = store.loadManifest(comicId, chapterId)
  if (manifest === undefined || !hasValidOfflineManifestIntegrity(manifest)) return 0
  const renames: ImageRename[] = []
  for (const page of manifest.pages) {
    const oldName = page.localPath.substring(page.localPath.lastIndexOf('/') + 1)
    if (!safeName(oldName) || page.localPath !== chapterDir + '/' + oldName || !oldName.toLowerCase().endsWith('.img')) continue
    if (!fs.accessSync(page.localPath)) continue
    const newPath = imageHeaderPath(page.localPath)
    if (newPath === page.localPath) continue
    const newName = newPath.substring(newPath.lastIndexOf('/') + 1)
    if (!safeName(newName) || fs.accessSync(newPath)) continue
    renames.push({ oldName, newName })
  }
  if (renames.length === 0) return migrateUnreferencedImages(chapterDir, manifest.pages.map(page => page.localPath))
  const journalPath = chapterDir + '/.koma/image-suffix-migration.json'
  writeAppTextFile(journalPath, JSON.stringify({ version: 1, renames } as ImageRenameJournal))
  try {
    for (const rename of renames) {
      const oldPath = chapterDir + '/' + rename.oldName
      const newPath = chapterDir + '/' + rename.newName
      // Never replace a file that appeared after the plan was prepared.
      if (fs.accessSync(newPath)) throw new Error('image_suffix_target_exists')
      fs.renameSync(oldPath, newPath)
    }
    for (const page of manifest.pages) {
      const rename = renames.find(item => page.localPath === chapterDir + '/' + item.oldName)
      if (rename !== undefined) {
        page.localPath = chapterDir + '/' + rename.newName
        page.fileName = rename.newName
      }
    }
    store.saveManifest(manifest)
    fs.unlinkSync(journalPath)
    return renames.length + migrateUnreferencedImages(chapterDir, manifest.pages.map(page => page.localPath))
  } catch (error) {
    // The live manifest determines whether to finish the commit or roll back.
    try { recoverChapter(store, comicId, chapterId, chapterDir) } catch (_recoveryError) {}
    throw error as Error
  }
}

