import { util } from '@kit.ArkTS'
import { getBaseName, isSafeArchiveEntryPath } from './ImageSortUtils'
import { nativeComicArchive } from './NativeArchiveExtraction'

const PAGE_PREFIX = 'koma-zip-page://'

export interface ComicZipPage {
  archive: string
  entry: string
}

export function isComicZip(path: string): boolean {
  try { return /\.(zip|cbz)$/i.test(decodeURIComponent(path)) } catch (_error) { return /\.(zip|cbz)$/i.test(path) }
}

export function comicZipPageUri(archive: string, entry: string, revision?: string): string {
  const base = PAGE_PREFIX + encodeURIComponent(archive) + '/' + encodeURIComponent(entry)
  return revision === undefined ? base : base + '/' + encodeURIComponent(revision)
}

export function parseComicZipPage(uri: string): ComicZipPage | undefined {
  if (!uri.startsWith(PAGE_PREFIX)) return undefined
  const parts = uri.substring(PAGE_PREFIX.length).split('/')
  if (parts.length !== 2 && parts.length !== 3) return undefined
  try {
    const archive = decodeURIComponent(parts[0])
    const entry = decodeURIComponent(parts[1])
    if (!archive.startsWith('/') || !isComicZip(archive) || archive.includes('\\') ||
      archive.split('/').includes('..') || archive.includes('\u0000') || !isSafeArchiveEntryPath(entry)) return undefined
    return { archive, entry }
  } catch (_error) {
    return undefined
  }
}

export function readComicZipPage(page: ComicZipPage): Promise<ArrayBuffer> {
  return nativeComicArchive.readZipEntry(page.archive, page.entry, 128 * 1024 * 1024)
}

export async function readComicZipInfo(archive: string): Promise<string> {
  const bytes = await nativeComicArchive.readZipEntry(archive, 'ComicInfo.xml', 4 * 1024 * 1024)
  return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(bytes))
}

export function comicZipPageFilename(page: ComicZipPage): string {
  return getBaseName(page.entry)
}
