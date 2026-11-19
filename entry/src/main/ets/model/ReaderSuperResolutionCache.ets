import { fileIo } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

class ReaderSuperResolutionCacheEntry {
  path: string = ''
  bytes: number = 0
  mtime: number = 0

  constructor(path: string, bytes: number, mtime: number) {
    this.path = path
    this.bytes = bytes
    this.mtime = mtime
  }
}

export function removeSuperResolutionCacheFile(path: string): void {
  try {
    fileIo.unlinkSync(path)
  } catch (_error) {}
}

export function readSuperResolutionCache(dir: string, cleanScratch: boolean): ReaderSuperResolutionCacheEntry[] {
  const entries: ReaderSuperResolutionCacheEntry[] = []
  try {
    if (!fileIo.accessSync(dir)) return entries
    for (const name of fileIo.listFileSync(dir)) {
      const path = `${dir}/${name}`
      if (name.endsWith('.part') && cleanScratch) removeSuperResolutionCacheFile(path)
      if (!name.endsWith('.jpg')) continue
      try {
        const stat = fileIo.statSync(path)
        if (stat.size > 0) entries.push(new ReaderSuperResolutionCacheEntry(path, stat.size, stat.mtime))
      } catch (_error) {}
    }
  } catch (error) {
    DiagnosticLogger.warn('reader-super-resolution', 'cache_scan_failed', (error as Error).message)
  }
  return entries
}

export function pruneSuperResolutionCache(dir: string, protectedPath: string, maxBytes: number, maxFiles: number): void {
  const entries = readSuperResolutionCache(dir, true)
  let totalBytes = entries.reduce((sum: number, entry: ReaderSuperResolutionCacheEntry): number => sum + entry.bytes, 0)
  let remaining = entries.length
  if (totalBytes <= maxBytes && remaining <= maxFiles) return
  entries.sort((left: ReaderSuperResolutionCacheEntry, right: ReaderSuperResolutionCacheEntry): number =>
    left.mtime - right.mtime)
  for (const entry of entries) {
    if ((totalBytes <= maxBytes && remaining <= maxFiles) || remaining <= 1) break
    if (entry.path === protectedPath) continue
    removeSuperResolutionCacheFile(entry.path)
    removeSuperResolutionCacheFile(`${entry.path}.backend`)
    totalBytes -= entry.bytes
    remaining--
  }
}
