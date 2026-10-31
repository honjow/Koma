import archive from 'libkoma_archive.so'

interface NativeComicArchive { extract(source: string, destination: string): Promise<void> }
const codec = archive as NativeComicArchive

export function extractNativeComicArchive(source: string, destination: string): Promise<void> {
  return codec.extract(source, destination)
}
