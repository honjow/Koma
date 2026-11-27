import archive from 'libkoma_archive.so'

export interface ComicZipEntry {
  path: string
  size: number
  hash: string
}

interface NativeComicArchive {
  extract(source: string, destination: string): Promise<void>
  listZip(source: string): Promise<ComicZipEntry[]>
  listZipSync(source: string, hash: boolean): ComicZipEntry[]
  readZipEntry(source: string | number, path: string, limit: number): Promise<ArrayBuffer>
  readZipPrefix(source: string, path: string, limit: number): Promise<ArrayBuffer>
  copyZipEntry(source: string, path: string, limit: number, destination: string): Promise<void>
  writeZip(destination: string, files: string[], metadata: string): Promise<void>
}

export const nativeComicArchive = archive as NativeComicArchive

export function extractNativeComicArchive(source: string, destination: string): Promise<void> {
  return nativeComicArchive.extract(source, destination)
}
