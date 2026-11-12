import { LocalLibraryFolderEntry, scanLocalLibraryFolderEntries } from '../model/LocalLibraryFolderContract'
import { compareNaturalPath, getBaseName, stripExtension } from './ImageSortUtils'

export interface ArchiveImageChapter {
  title: string
  paths: string[]
}

function explicitChapterFolder(title: string): boolean {
  const value = title.trim()
  return /^(?:第[0-9０-９零〇一二三四五六七八九十百千]+[话話章节節回卷部期集]|(?:chapter|chap|ch|episode|ep|volume|vol|book)[\s._-]*\d|\d+(?:\.\d+)?(?:$|[\s._-])|番外|特别篇|特別篇|序章|终章|終章|extra\b|special\b|prologue\b|epilogue\b)/i.test(value)
}

/** Reuse the folder importer's chapter rules. Split only when a single clear
 * series accounts for every image except an optional standalone cover. */
export function archiveImageChapters(paths: string[]): ArchiveImageChapter[] {
  const prefix = '__archive__/'
  const scan = scanLocalLibraryFolderEntries(paths.map((path: string): LocalLibraryFolderEntry =>
    ({ relativePath: `${prefix}${path}`, kind: 'file' })))
  const matches: ArchiveImageChapter[][] = []
  scan.series.forEach((series): void => {
    if (series.chapters.length < 2 || series.chapters.some((chapter): boolean => chapter.kind !== 'image_folder')) return
    const groups: ArchiveImageChapter[] = series.chapters.map((chapter): ArchiveImageChapter => ({
      title: chapter.title,
      paths: chapter.pages.map((page): string => page.relativePath.substring(prefix.length)),
    }))
    if (groups.some((group: ArchiveImageChapter): boolean => !explicitChapterFolder(group.title))) return
    const used = new Set<string>()
    groups.forEach((group: ArchiveImageChapter): void => group.paths.forEach((path: string): void => { used.add(path) }))
    const remaining = paths.filter((path: string): boolean => !used.has(path))
    if (remaining.length === 0 || (remaining.length === 1 &&
      stripExtension(getBaseName(remaining[0])).toLowerCase() === 'cover')) matches.push(groups)
  })
  if (matches.length === 1) return matches[0]
  if (matches.length > 1) return []

  // Some downloaders put an additional images/ folder under each chapter.
  // Only explicit chapter ancestors are sufficient to infer a boundary.
  const nested = new Map<string, ArchiveImageChapter>()
  const remaining: string[] = []
  paths.forEach((path: string): void => {
    const parts = path.split('/')
    const index = parts.findIndex((part: string, position: number): boolean =>
      position < parts.length - 1 && explicitChapterFolder(part))
    if (index < 0) { remaining.push(path); return }
    const key = parts.slice(0, index + 1).join('/')
    const group = nested.get(key) ?? { title: parts[index], paths: [] }
    group.paths.push(path)
    nested.set(key, group)
  })
  if (nested.size < 2 || !(remaining.length === 0 || (remaining.length === 1 &&
    stripExtension(getBaseName(remaining[0])).toLowerCase() === 'cover'))) return []
  return Array.from(nested.keys()).sort(compareNaturalPath).map((key: string): ArchiveImageChapter => {
    const group = nested.get(key) as ArchiveImageChapter
    group.paths.sort(compareNaturalPath)
    return group
  })
}
