import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { SourcePrivateSessionScope } from './SourcePrivateSessionHost'

export interface SourceBodyRef { id: string; length: number }
interface BodyEntry extends SourceBodyRef {
  path: string
  sourceId: string
  packageIdentity: string
  callId: string
  timer?: number
}
interface BodyRequest { version: number; op: string; id?: string; offset?: number; length?: number; base64?: string }
interface BodyError { code: string }
interface BodyReply { ok: boolean; bodyRef?: SourceBodyRef; base64?: string; error?: BodyError }

export const SOURCE_BODY_CHUNK_BYTES: number = 65536
export const SOURCE_BODY_MAX_BYTES: number = 128 * 1024 * 1024
const CALL_BYTES: number = 256 * 1024 * 1024
const TOTAL_BYTES: number = 512 * 1024 * 1024

/** Opaque, call-owned data, never paths or pointers into a departed WASM module.
 * Only a successful image result can transfer ownership out of the call. The
 * consumer claims it once; cancellation/traps retire all other material.
 */
export class SourceBodyHost {
  private static root: string = ''
  private static bodies: Map<string, BodyEntry> = new Map()

  static configure(cacheDir: string): void {
    if (SourceBodyHost.root.length > 0) return
    const root = cacheDir + '/source-bodies-v1'
    try {
      if (!fs.accessSync(root)) fs.mkdirSync(root, true)
      // No references survive process death. Only our own flat, generated files.
      for (const name of fs.listFileSync(root)) {
        if (/^[0-9a-f-]+\.body$/.test(name)) fs.unlinkSync(root + '/' + name)
      }
      SourceBodyHost.root = root
    } catch (_error) {
      // A data-cache failure must not put the whole app behind backup recovery.
      // Worker capability negotiation then omits these optional data operations.
      DiagnosticLogger.warn('source_body', 'configure_failed', 'state=unavailable')
    }
  }

  static available(): boolean { return SourceBodyHost.root.length > 0 }

  static create(scope: SourcePrivateSessionScope): SourceBodyRef {
    if (!SourceBodyHost.available()) throw new Error('body_unavailable')
    let count = 0
    SourceBodyHost.bodies.forEach((entry: BodyEntry): void => { if (entry.callId === scope.callId) count++ })
    if (count >= 16 || SourceBodyHost.bodies.size >= 64) throw new Error('body_limit_exceeded')
    const id = util.generateRandomUUID(true)
    const path = SourceBodyHost.root + '/' + id + '.body'
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
    fs.closeSync(file)
    SourceBodyHost.bodies.set(id, { id, length: 0, path, sourceId: scope.sourceId,
      packageIdentity: scope.packageIdentity, callId: scope.callId })
    return { id, length: 0 }
  }

  private static owned(scope: SourcePrivateSessionScope, id: string): BodyEntry {
    const entry = SourceBodyHost.bodies.get(id)
    if (entry === undefined || entry.callId !== scope.callId || entry.sourceId !== scope.sourceId ||
      entry.packageIdentity !== scope.packageIdentity) throw new Error('body_not_found')
    return entry
  }

  static append(scope: SourcePrivateSessionScope, id: string, bytes: ArrayBuffer): void {
    const entry = SourceBodyHost.owned(scope, id)
    SourceBodyHost.write(scope, id, entry.length, bytes)
  }

  static write(scope: SourcePrivateSessionScope, id: string, offset: number, bytes: ArrayBuffer): void {
    const entry = SourceBodyHost.owned(scope, id)
    if (!Number.isSafeInteger(offset) || offset < 0 || offset > entry.length) throw new Error('invalid_body_range')
    const length = Math.max(entry.length, offset + bytes.byteLength)
    let total = 0
    let call = 0
    SourceBodyHost.bodies.forEach((body: BodyEntry): void => {
      total += body.length
      if (body.callId === scope.callId) call += body.length
    })
    const growth = length - entry.length
    if (length > SOURCE_BODY_MAX_BYTES || total + growth > TOTAL_BYTES || call + growth > CALL_BYTES) {
      throw new Error('body_limit_exceeded')
    }
    const file = fs.openSync(entry.path, fs.OpenMode.READ_WRITE)
    try {
      if (fs.writeSync(file.fd, bytes, { offset, length: bytes.byteLength }) !== bytes.byteLength) {
        throw new Error('body_write_failed')
      }
      entry.length = length
    } finally { fs.closeSync(file) }
  }

  static read(scope: SourcePrivateSessionScope, id: string, offset: number, length: number): ArrayBuffer {
    const entry = SourceBodyHost.owned(scope, id)
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 ||
      offset > entry.length || length < 0 || length > SOURCE_BODY_CHUNK_BYTES) throw new Error('invalid_body_range')
    return SourceBodyHost.readEntry(entry, offset, Math.min(length, entry.length - offset))
  }

  private static readEntry(entry: BodyEntry, offset: number, length: number): ArrayBuffer {
    const result = new ArrayBuffer(length)
    if (length === 0) return result
    const file = fs.openSync(entry.path, fs.OpenMode.READ_ONLY)
    try {
      if (fs.readSync(file.fd, result, { offset, length }) !== length) throw new Error('body_read_failed')
    } finally { fs.closeSync(file) }
    return result
  }

  static bytes(scope: SourcePrivateSessionScope, id: string): ArrayBuffer {
    const entry = SourceBodyHost.owned(scope, id)
    return SourceBodyHost.readEntry(entry, 0, entry.length)
  }

  static close(scope: SourcePrivateSessionScope, id: string): void {
    SourceBodyHost.remove(SourceBodyHost.owned(scope, id))
  }

  private static remove(entry: BodyEntry): void {
    SourceBodyHost.bodies.delete(entry.id)
    if (entry.timer !== undefined) clearTimeout(entry.timer)
    try { fs.unlinkSync(entry.path) } catch (_error) {}
  }

  static finishCall(callId: string): void {
    SourceBodyHost.bodies.forEach((entry: BodyEntry): void => {
      if (entry.callId === callId) SourceBodyHost.remove(entry)
    })
  }

  static execute(request: string, scope: SourcePrivateSessionScope): string {
    try {
      const value = JSON.parse(request) as BodyRequest
      if (value.version !== 1) throw new Error('unsupported')
      if (value.op === 'create') return JSON.stringify({ ok: true, bodyRef: SourceBodyHost.create(scope) })
      if (typeof value.id !== 'string') throw new Error('invalid_request')
      if (value.op === 'close') SourceBodyHost.close(scope, value.id)
      else if (value.op === 'read') {
        const bytes = SourceBodyHost.read(scope, value.id, value.offset as number, value.length as number)
        return JSON.stringify({ ok: true, base64: new util.Base64Helper().encodeToStringSync(new Uint8Array(bytes)) })
      } else if (value.op === 'write' && typeof value.base64 === 'string' &&
        value.base64.length <= Math.ceil(SOURCE_BODY_CHUNK_BYTES / 3) * 4 &&
        /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value.base64)) {
        const bytes = new util.Base64Helper().decodeSync(value.base64)
        if (bytes.byteLength > SOURCE_BODY_CHUNK_BYTES) throw new Error('invalid_body_range')
        SourceBodyHost.write(scope, value.id, value.offset as number, bytes.buffer as ArrayBuffer)
      } else throw new Error('invalid_request')
      return JSON.stringify({ ok: true })
    } catch (error) {
      const code = (error as Error).message
      const reply: BodyReply = { ok: false, error: { code: ['unsupported', 'invalid_request', 'invalid_body_range',
        'body_not_found', 'body_unavailable', 'body_limit_exceeded', 'body_read_failed', 'body_write_failed'].includes(code)
        ? code : 'body_io_failed' } }
      return JSON.stringify(reply)
    }
  }

  static handoff(response: string, request: string, scope: SourcePrivateSessionScope): string {
    const operation = (JSON.parse(request) as Record<string, Object>)['operation']
    if (operation !== 'get_image_request') return response
    const result = JSON.parse(response) as Record<string, Object>
    const data = result['data'] as Record<string, Object> | undefined
    if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) return response
    // Source JSON can never manufacture a host-side transfer ticket.
    data['hostImageBody'] = ''
    const image = data['image'] as Record<string, Object> | undefined
    if (result['ok'] === true && operation === 'get_image_request' && image?.['kind'] === 'body' &&
      typeof image['ref'] === 'string') {
      const entry = SourceBodyHost.owned(scope, image['ref'] as string)
      if (entry.length === 0) throw new Error('body_empty_image')
      entry.callId = ''
      entry.timer = setTimeout((): void => SourceBodyHost.remove(entry), 60000)
      data['hostImageBody'] = entry.id
    }
    return JSON.stringify(result)
  }

  static takeImage(id: string, sourceId: string, packageIdentity: string): ArrayBuffer {
    const entry = SourceBodyHost.bodies.get(id)
    if (entry === undefined || entry.callId !== '' || entry.sourceId !== sourceId ||
      entry.packageIdentity !== packageIdentity) throw new Error('body_image_expired')
    try { return SourceBodyHost.readEntry(entry, 0, entry.length) }
    finally { SourceBodyHost.remove(entry) }
  }
}
