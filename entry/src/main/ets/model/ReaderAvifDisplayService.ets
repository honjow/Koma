import { taskpool } from '@kit.ArkTS'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { imageFileContentHash, isAvifFileType } from './ImageFileContent'
import { prepareReaderAvifTask } from './ReaderAvifDisplayWorker'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'

const AVIF_DISPLAY_NAME: string = 'reader-avif-display.png'
const MAX_AVIF_INPUT: number = 64 * 1024 * 1024

async function boundedAvifFile(path: string): Promise<boolean> {
  const file = await fs.open(path, fs.OpenMode.READ_ONLY)
  try {
    const head = new ArrayBuffer(128)
    const size = await fs.read(file.fd, head)
    if (!isAvifFileType(head, size)) return false
    const stat = await fs.stat(file.fd)
    return stat.size <= MAX_AVIF_INPUT
  } finally { await fs.close(file) }
}

/** A render-only conversion. Reader assets and exports keep their own original file identity. */
export class ReaderAvifDisplayService {
  private static inFlight: Map<string, Promise<string>> = new Map()
  private static nativeDecodable: Set<string> = new Set()
  private static tail: Promise<void> = Promise.resolve()

  static prepare(original: string, cache: RemoteImageCacheStore, afterWrite: (path: string) => Promise<void>,
    forceReload: boolean): Promise<string> {
    const requestKey = JSON.stringify([original, forceReload])
    const pending = ReaderAvifDisplayService.inFlight.get(requestKey)
    if (pending !== undefined) return pending
    const request = ReaderAvifDisplayService.process(original, cache, afterWrite, forceReload)
    ReaderAvifDisplayService.inFlight.set(requestKey, request)
    const retire = (): void => {
      if (ReaderAvifDisplayService.inFlight.get(requestKey) === request) ReaderAvifDisplayService.inFlight.delete(requestKey)
    }
    void request.then(retire, retire)
    return request
  }

  private static async process(original: string, cache: RemoteImageCacheStore,
    afterWrite: (path: string) => Promise<void>, forceReload: boolean): Promise<string> {
    let avif = false
    try {
      const path = original.startsWith('file://') ? new fileUri.FileUri(original).path : original
      if (!path.startsWith('/')) return original
      if (cache.avifAtPath(path) === false) return original
      avif = await boundedAvifFile(path)
      if (!avif) return original
      const hash = await taskpool.execute<[string], string>(imageFileContentHash, path)
      const key = JSON.stringify(['reader-avif-display-v1', hash])
      // An explicit retry must regenerate the display file even if the server
      // returns identical original bytes. The cached PNG may be what failed.
      if (!forceReload) {
        if (ReaderAvifDisplayService.nativeDecodable.has(hash)) return original
        const cached = await cache.get(AVIF_DISPLAY_NAME, undefined, key)
        if (cached !== undefined) return cached
      }

      // Preloading stays on the raw path. Limit the memory used by concurrent display requests.
      const prior = ReaderAvifDisplayService.tail
      let release: () => void = () => {}
      ReaderAvifDisplayService.tail = new Promise<void>((resolve) => { release = resolve })
      try {
        await prior
        const bytes = await taskpool.execute<[string, string], ArrayBuffer>(prepareReaderAvifTask, path, hash)
        if (await taskpool.execute<[string], string>(imageFileContentHash, path) !== hash) return original
        if (bytes.byteLength === 0) {
          if (ReaderAvifDisplayService.nativeDecodable.size >= 128) ReaderAvifDisplayService.nativeDecodable.clear()
          ReaderAvifDisplayService.nativeDecodable.add(hash)
          return original
        }
        const result = await cache.put(AVIF_DISPLAY_NAME, undefined, bytes, key)
        await afterWrite(result)
        DiagnosticLogger.info('reader', 'avif_display_compatible', 'format=png')
        return result
      } finally { release() }
    } catch (error) {
      if (avif) {
        const message = (error as Error).message ?? ''
        const reason = /\breader_avif_[a-z_]+\b/.exec(message)?.[0] ?? 'compatibility_failed'
        DiagnosticLogger.warn('reader', 'avif_display_unavailable', `reason=${reason}`)
      }
      // A corrupt, animated or unrepresentable file keeps the existing native error/retry route.
      return original
    }
  }
}
