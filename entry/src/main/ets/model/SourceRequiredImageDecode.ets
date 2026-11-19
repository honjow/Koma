import { taskpool, util } from '@kit.ArkTS'
import { requiredDecodeTask, sourceImageProcessorTask } from './SourceRequiredImageDecodeWorker'
import { readSourceImageBytesTask } from './SourceRequiredImageDecodePrimitives'
import { SOURCE_IMAGE_PROCESSOR_KIND, sourceImageProcessorModule } from '../sourceRuntime/SourceRequiredImageDecodeDeclaration'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { imageFileContentHash } from './ImageFileContent'
import { RemoteImageCacheStore } from './RemoteImageCacheStore'
export { restoreJmStripePixels } from './SourceRequiredImageDecodePrimitives'

/** Required source data, not an optional user-selected image plugin. */
interface JmRequiredImageDecode {
  kind: 'jm_stripes_v1'
  rows: number
}

interface WasmRequiredImageDecode {
  kind: 'wasm_image_v1'
  bytes?: string
  pixels?: string
}

export type SourceRequiredImageDecode = JmRequiredImageDecode | WasmRequiredImageDecode

export interface SourceRequiredDecodedImage {
  bytes: ArrayBuffer
  extension: string
}

export function sourceRequiredImageDecode(value: Object): SourceRequiredImageDecode {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('source_required_decode_invalid')
  const data = value as Record<string, Object>
  if (data['kind'] === SOURCE_IMAGE_PROCESSOR_KIND) {
    if (Object.keys(data).some((key: string): boolean => key !== 'kind' && key !== 'bytes' && key !== 'pixels') ||
      (data['bytes'] === undefined && data['pixels'] === undefined)) throw new Error('source_required_decode_invalid')
    return { kind: 'wasm_image_v1', bytes: processorConfiguration(data['bytes']), pixels: processorConfiguration(data['pixels']) }
  }
  if (data['kind'] !== 'jm_stripes_v1' || typeof data['rows'] !== 'number' ||
    !Number.isInteger(data['rows']) || (data['rows'] as number) < 2 || (data['rows'] as number) > 20 ||
    (data['rows'] as number) % 2 !== 0 || Object.keys(data).some((key: string): boolean => key !== 'kind' && key !== 'rows')) {
    throw new Error('source_required_decode_invalid')
  }
  return { kind: 'jm_stripes_v1', rows: data['rows'] as number }
}

function processorConfiguration(config?: Object): string | undefined {
  if (config === undefined) return undefined
  if (typeof config !== 'string' || config.length === 0 || config.length > 64 * 1024 ||
    new util.TextEncoder().encodeInto(config).byteLength > 64 * 1024) throw new Error('source_required_decode_invalid')
  return config
}

function requiredProcessor(hint: SourceRequiredImageDecode, owner?: SourceRuntimeRegistryEntry): Uint8Array | undefined {
  if (hint.kind === 'jm_stripes_v1') return undefined
  if (owner?.enabled !== true || !owner.requiredImageDecodes?.includes(SOURCE_IMAGE_PROCESSOR_KIND)) {
    throw new Error('source_required_decode_module_undeclared')
  }
  // Transfer only the processor, never the source module held by the registry.
  return new Uint8Array(sourceImageProcessorModule(owner.wasmBytes))
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
  // The TaskPool worker must finish decoding before it returns its result.
  return await requiredDecodeTask(bytes, rows)
}

/** Canonical source decoding precedes every optional plugin/crop. Never return scrambled input on failure. */
export class SourceRequiredImageDecodeService {
  private static inFlight: Map<string, Promise<string>> = new Map()
  private static tail: Promise<void> = Promise.resolve()

  static async decodeBytes(bytes: ArrayBuffer, rawHint: SourceRequiredImageDecode,
    owner?: SourceRuntimeRegistryEntry): Promise<SourceRequiredDecodedImage> {
    const hint = sourceRequiredImageDecode(rawHint)
    const processor = requiredProcessor(hint, owner)
    return SourceRequiredImageDecodeService.runSerial((): Promise<SourceRequiredDecodedImage> => {
      if (hint.kind === 'jm_stripes_v1') {
        return taskpool.execute<[ArrayBuffer, number], SourceRequiredDecodedImage>(requiredDecodeTask, bytes, hint.rows)
      }
      if (processor === undefined) throw new Error('source_required_decode_module_missing')
      return taskpool.execute<[ArrayBuffer, Uint8Array, string, string], SourceRequiredDecodedImage>(
        sourceImageProcessorTask, bytes, processor, hint.bytes ?? '', hint.pixels ?? '')
    })
  }

  private static async runSerial(run: () => Promise<SourceRequiredDecodedImage>): Promise<SourceRequiredDecodedImage> {
    const prior = SourceRequiredImageDecodeService.tail
    let release: () => void = () => {}
    SourceRequiredImageDecodeService.tail = new Promise<void>((resolve) => { release = resolve })
    try {
      await prior
      return await run()
    } finally { release() }
  }

  static prepare(path: string, rawHint: SourceRequiredImageDecode, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const hint = sourceRequiredImageDecode(rawHint)
    if (hint.kind !== 'jm_stripes_v1') throw new Error('source_required_decode_invalid')
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

  private static async process(path: string, hint: JmRequiredImageDecode, store: RemoteImageCacheStore,
    identity: string): Promise<string> {
    const hash = await taskpool.execute<[string], string>(imageFileContentHash, path)
    const key = JSON.stringify(['source-required-decode-v1', identity, hash, hint])
    const cached = await store.get('', undefined, key)
    if (cached !== undefined) {
      if (await taskpool.execute<[string], string>(imageFileContentHash, path) !== hash) throw new Error('source_required_decode_replaced')
      return cached
    }
    const decoded = await SourceRequiredImageDecodeService.runSerial((): Promise<SourceRequiredDecodedImage> =>
      taskpool.execute<[string, number, string], SourceRequiredDecodedImage>(requiredDecodeFileTask, path, hint.rows, hash))
    if (await taskpool.execute<[string], string>(imageFileContentHash, path) !== hash) throw new Error('source_required_decode_replaced')
    const name = 'source-required.' + decoded.extension
    return store.put(name, undefined, decoded.bytes, key)
  }
}
