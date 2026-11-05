import { taskpool } from '@kit.ArkTS'
import { requiredDecodeTask } from './SourceRequiredImageDecodeWorker'
import { readSourceImageBytesTask } from './SourceRequiredImageDecodePrimitives'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { imageFileContentHash } from './ImageFileContent'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
export { restoreJmStripePixels } from './SourceRequiredImageDecodePrimitives'

/** Required source data, not an optional user-selected image plugin. */
export interface SourceRequiredImageDecode {
  kind: 'jm_stripes_v1'
  rows: number
}

export interface SourceRequiredDecodedImage {
  bytes: ArrayBuffer
  extension: string
}

export function sourceRequiredImageDecode(value: Object): SourceRequiredImageDecode {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('source_required_decode_invalid')
  const data = value as Record<string, Object>
  if (data['kind'] !== 'jm_stripes_v1' || typeof data['rows'] !== 'number' ||
    !Number.isInteger(data['rows']) || (data['rows'] as number) < 2 || (data['rows'] as number) > 20 ||
    (data['rows'] as number) % 2 !== 0 || Object.keys(data).some((key: string): boolean => key !== 'kind' && key !== 'rows')) {
    throw new Error('source_required_decode_invalid')
  }
  return { kind: 'jm_stripes_v1', rows: data['rows'] as number }
}

/** Shared background file reader for downloads; never performs full image I/O on the UI thread. */
export async function readSourceImageBytes(path: string): Promise<ArrayBuffer> {
  return taskpool.execute<[string], ArrayBuffer>(readSourceImageBytesTask, path)
}

@Concurrent
async function requiredDecodeFileTask(path: string, rows: number, expectedHash: string): Promise<SourceRequiredDecodedImage> {
  const bytes = readSourceImageBytesTask(path)
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new Uint8Array(bytes) })
  const actual = Array.from(digest.digestSync().data).map((v: number): string => v.toString(16).padStart(2, '0')).join('')
  if (actual !== expectedHash) throw new Error('source_required_decode_replaced')
  return requiredDecodeTask(bytes, rows)
}

/** Canonical source decoding precedes every optional plugin/crop. Never return scrambled input on failure. */
export class SourceRequiredImageDecodeService {
  private static inFlight: Map<string, Promise<string>> = new Map()
  private static tail: Promise<void> = Promise.resolve()

  static async decodeBytes(bytes: ArrayBuffer, rawHint: SourceRequiredImageDecode): Promise<SourceRequiredDecodedImage> {
    const hint = sourceRequiredImageDecode(rawHint)
    const prior = SourceRequiredImageDecodeService.tail
    let release: () => void = () => {}
    SourceRequiredImageDecodeService.tail = new Promise<void>((resolve) => { release = resolve })
    try {
      await prior
      return await taskpool.execute<[ArrayBuffer, number], SourceRequiredDecodedImage>(requiredDecodeTask, bytes, hint.rows)
    } finally { release() }
  }

  private static async decodeFile(path: string, rows: number, hash: string): Promise<SourceRequiredDecodedImage> {
    const prior = SourceRequiredImageDecodeService.tail
    let release: () => void = () => {}
    SourceRequiredImageDecodeService.tail = new Promise<void>((resolve) => { release = resolve })
    try {
      await prior
      return await taskpool.execute<[string, number, string], SourceRequiredDecodedImage>(requiredDecodeFileTask, path, rows, hash)
    } finally { release() }
  }

  static prepare(path: string, rawHint: SourceRequiredImageDecode, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const hint = sourceRequiredImageDecode(rawHint)
    const pendingKey = JSON.stringify([path, hint, identity])
    const existing = SourceRequiredImageDecodeService.inFlight.get(pendingKey)
    if (existing !== undefined) return existing
    const pending = SourceRequiredImageDecodeService.process(path, hint, store, identity)
    SourceRequiredImageDecodeService.inFlight.set(pendingKey, pending)
    const cleanup = (): void => {
      if (SourceRequiredImageDecodeService.inFlight.get(pendingKey) === pending) SourceRequiredImageDecodeService.inFlight.delete(pendingKey)
    }
    void pending.then(cleanup, cleanup)
    return pending
  }

  private static async process(path: string, hint: SourceRequiredImageDecode, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const hash = await taskpool.execute<[string], string>(imageFileContentHash, path)
    const key = JSON.stringify(['source-required-decode-v1', identity, hash, hint])
    for (const extension of ['gif', 'jpg']) {
      const cached = await store.get('source-required.' + extension, undefined, key)
      if (cached !== undefined) {
        if (await taskpool.execute<[string], string>(imageFileContentHash, path) !== hash) throw new Error('source_required_decode_replaced')
        return cached
      }
    }
    const decoded = await SourceRequiredImageDecodeService.decodeFile(path, hint.rows, hash)
    if (await taskpool.execute<[string], string>(imageFileContentHash, path) !== hash) throw new Error('source_required_decode_replaced')
    const name = 'source-required.' + decoded.extension
    return store.put(name, undefined, decoded.bytes, key)
  }
}
