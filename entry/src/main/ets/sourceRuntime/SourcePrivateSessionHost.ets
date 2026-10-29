import { asset } from '@kit.AssetStoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

export interface SourcePrivateSessionScope { sourceId: string; packageIdentity: string; callId: string }
export interface SourcePrivateSessionCall { id: string; httpContextJson: string }

interface PrivateError { code: string }
interface PrivateFailureFields { fixedCode?: string; name?: string }
interface PrivateErrorResponse { ok: boolean; error: PrivateError }
interface PrivateClock { nowMs: string; gts: string }
interface PrivateResponse { ok: boolean; state?: string; value?: string; versionTag?: string; lease?: string; randomHex?: string; nowMs?: string; gts?: string }
interface PrivateRequest { type: string; version: number; op: string; lease?: string; value?: string; versionTag?: string; publicKey?: string; plaintext?: string }
interface PrivateManifest { format: string; id: string; chunks: number; bytes: number; sha256: string }
interface PrivateValue { value: string; versionTag: string }
interface BeginResult { response: string; wait: Promise<boolean> | null }
interface PrivateOwner { callId: string; lease: string; done: Promise<boolean>; resolve: (ok: boolean) => void }
class PrivateReadFailure extends Error {
  fixedCode: string
  constructor(code: string) { super('private_read_failed'); this.fixedCode = code }
}
class PrivateState {
  key: string = ''
  root: string = ''
  loaded: boolean = false
  value: PrivateValue | null = null
  manifest: PrivateManifest | null = null
  owner: PrivateOwner | null = null
  queue: Promise<void> = Promise.resolve()
}

// This namespace belongs exclusively to source-private sessions. A package identity
// is part of the key: a replacement package must never inherit its predecessor's value.
const PRIVATE_PREFIX: string = 'koma.source.private.v1.'
const MAX_VALUE_BYTES: number = 65536
const CHUNK_BYTES: number = 1024

export class SourcePrivateSessionHost {
  private static calls: Map<string, SourcePrivateSessionScope> = new Map()
  private static states: Map<string, PrivateState> = new Map()
  private static nextCall: number = 0

  static beginCall(httpContextJson: string): SourcePrivateSessionCall {
    try {
      const context = JSON.parse(httpContextJson) as Record<string, Object>
      if (context === null || typeof context.sourceId !== 'string' || context.sourceId.length === 0 ||
        typeof context.packageIdentity !== 'string' || context.packageIdentity.length === 0) {
        return { id: '', httpContextJson }
      }
      const id = `${Date.now().toString(36)}-${(++SourcePrivateSessionHost.nextCall).toString(36)}`
      const scope: SourcePrivateSessionScope = { sourceId: context.sourceId, packageIdentity: context.packageIdentity, callId: id }
      SourcePrivateSessionHost.calls.set(id, scope)
      context.privateCallId = id
      return { id, httpContextJson: JSON.stringify(context) }
    } catch (_error) { return { id: '', httpContextJson } }
  }

  static finishCall(id: string): void {
    SourcePrivateSessionHost.calls.delete(id)
    SourcePrivateSessionHost.states.forEach((state: PrivateState): void => {
      if (state.owner?.callId === id) {
        const owner = state.owner
        state.owner = null
        owner.resolve(false)
      }
    })
  }

  static callIsActive(scope: SourcePrivateSessionScope): boolean {
    const live = SourcePrivateSessionHost.calls.get(scope.callId)
    return live !== undefined && live.sourceId === scope.sourceId && live.packageIdentity === scope.packageIdentity
  }

  private static active(scope: SourcePrivateSessionScope, current: () => boolean): boolean {
    try { return SourcePrivateSessionHost.callIsActive(scope) && current() } catch (_error) { return false }
  }
  private static fail(code: string): string { const error: PrivateError = { code }; const response: PrivateErrorResponse = { ok: false, error }; return JSON.stringify(response) }
  // Never expose platform messages, aliases or arbitrary thrown values.
  private static platformCode(error: Object): string {
    if (error === null || error === undefined) return 'unknown'
    const code = (error as BusinessError).code
    const value = typeof code === 'number' || typeof code === 'string' ? String(code) : ''
    if (value === '201' || value === '401' || /^240000[0-9]{2}$/.test(value) || /^176200[0-9]{2}$/.test(value)) return value
    return 'unknown'
  }
  private static stageFailure(stage: string, error: Object): string {
    if (error !== null && error !== undefined) {
      const fields = error as PrivateFailureFields
      const fixed = fields.fixedCode
      if (typeof fixed === 'string' && (['read_identity', 'read_options', 'read_secret_shape',
        'load_manifest_parse', 'load_manifest_validation', 'load_chunk_shape', 'load_chunk_sha'].includes(fixed) ||
        /^read_query_(?:201|401|240000[0-9]{2}|176200[0-9]{2}|unknown)$/.test(fixed))) {
        return SourcePrivateSessionHost.fail(fixed)
      }
      const code = SourcePrivateSessionHost.platformCode(error)
      if (code !== 'unknown') return SourcePrivateSessionHost.fail(`${stage}_${code}`)
      const name = fields.name
      if (name === 'Error' || name === 'TypeError' || name === 'BusinessError') {
        return SourcePrivateSessionHost.fail(`${stage}_unknown_${name}`)
      }
    }
    return SourcePrivateSessionHost.fail(`${stage}_unknown`)
  }
  private static bytes(s: string): Uint8Array {
    // OpenHarmony Buffer.buffer copies the active slice, unlike Node's pooled buffer.
    // https://github.com/openharmony/commonlibrary_ets_utils/blob/master/js_api_module/buffer/src/js_buffer.ts#L504
    // https://github.com/openharmony/commonlibrary_ets_utils/blob/master/js_api_module/buffer/native_module_buffer.cpp#L705
    return new Uint8Array(buffer.from(s, 'utf8').buffer)
  }
  private static text(b: Uint8Array): string { return buffer.from(b).toString('utf8') }
  private static hex(b: Uint8Array): string { return Array.from(b).map((v: number): string => v.toString(16).padStart(2, '0')).join('') }
  private static async random(n: number): Promise<string> { return SourcePrivateSessionHost.hex((await cryptoFramework.createRandom().generateRandom(n)).data) }
  private static async hash(b: Uint8Array): Promise<string> {
    const md = cryptoFramework.createMd('SHA256')
    await md.update({ data: b })
    return SourcePrivateSessionHost.hex((await md.digest()).data)
  }
  private static identity(alias: string): asset.AssetMap {
    const m: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    m.set(asset.Tag.ALIAS, SourcePrivateSessionHost.bytes(alias)); return m
  }
  private static async read(alias: string): Promise<Uint8Array | null> {
    let q: asset.AssetMap
    try { q = SourcePrivateSessionHost.identity(alias) }
    catch (_error) { throw new PrivateReadFailure('read_identity') }
    try { q.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL); q.set(asset.Tag.RETURN_LIMIT, 1) }
    catch (_error) { throw new PrivateReadFailure('read_options') }
    let rows: asset.AssetMap[]
    try { rows = await asset.query(q) }
    catch (error) {
      const code = SourcePrivateSessionHost.platformCode(error as Object)
      if (code === '24000002') return null
      throw new PrivateReadFailure(`read_query_${code}`)
    }
    if (!Array.isArray(rows)) throw new PrivateReadFailure('read_secret_shape')
    if (rows.length === 0) return null
    if (!(rows[0] instanceof Map)) throw new PrivateReadFailure('read_secret_shape')
    const bytes = rows[0].get(asset.Tag.SECRET) as Uint8Array | undefined
    if (!(bytes instanceof Uint8Array) || bytes.byteLength === 0 || bytes.byteLength > CHUNK_BYTES) {
      throw new PrivateReadFailure('read_secret_shape')
    }
    return bytes
  }
  private static async write(alias: string, bytes: Uint8Array): Promise<void> {
    if (bytes.byteLength === 0 || bytes.byteLength > CHUNK_BYTES) throw new Error('invalid')
    const attrs = SourcePrivateSessionHost.identity(alias)
    attrs.set(asset.Tag.SECRET, bytes); attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attrs.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    await asset.add(attrs)
  }
  private static chunk(state: PrivateState, id: string, index: number): string { return `${state.root}.${id}.${index}` }
  private static async removeChunks(state: PrivateState, manifest: PrivateManifest): Promise<void> {
    for (let i = 0; i < manifest.chunks; i++) {
      try { await asset.remove(SourcePrivateSessionHost.identity(SourcePrivateSessionHost.chunk(state, manifest.id, i))) } catch (_error) {}
    }
  }
  private static async load(state: PrivateState): Promise<void> {
    if (state.loaded) return
    const raw = await SourcePrivateSessionHost.read(state.root)
    if (raw === null) { state.loaded = true; return }
    let m: PrivateManifest
    try { m = JSON.parse(SourcePrivateSessionHost.text(raw)) as PrivateManifest }
    catch (_error) { throw new PrivateReadFailure('load_manifest_parse') }
    if (m === null || typeof m !== 'object' || m.format !== 'private-v1' || !/^[0-9a-f]{32}$/.test(m.id) || !/^[0-9a-f]{64}$/.test(m.sha256) ||
      !Number.isInteger(m.bytes) || m.bytes < 1 || m.bytes > MAX_VALUE_BYTES || m.chunks !== Math.ceil(m.bytes / CHUNK_BYTES)) throw new PrivateReadFailure('load_manifest_validation')
    const bytes = new Uint8Array(m.bytes)
    for (let i = 0; i < m.chunks; i++) {
      const chunk = await SourcePrivateSessionHost.read(SourcePrivateSessionHost.chunk(state, m.id, i))
      if (chunk === null || chunk.byteLength !== Math.min(CHUNK_BYTES, m.bytes - i * CHUNK_BYTES)) throw new PrivateReadFailure('load_chunk_shape')
      bytes.set(chunk, i * CHUNK_BYTES)
    }
    if (await SourcePrivateSessionHost.hash(bytes) !== m.sha256) throw new PrivateReadFailure('load_chunk_sha')
    state.value = { value: SourcePrivateSessionHost.text(bytes), versionTag: m.id }; state.manifest = m; state.loaded = true
  }
  private static async locked<T>(state: PrivateState, fn: () => Promise<T>): Promise<T> {
    const task = state.queue.then(fn)
    state.queue = task.then((): void => {}, (): void => {})
    return task
  }
  private static clock(): PrivateClock {
    const d = new Date(); const pad = (v: number): string => v.toString().padStart(2, '0')
    return { nowMs: d.getTime().toString(), gts: `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}+${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}` }
  }
  static async execute(requestJson: string, scope: SourcePrivateSessionScope, isCurrent: () => boolean): Promise<string> {
    if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
    try {
      const req = JSON.parse(requestJson) as PrivateRequest
      if (req === null || req.type !== 'private_session' || req.version !== 1 || typeof req.op !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
      if (req.op === 'clock') {
        const randomHex = await SourcePrivateSessionHost.random(16)
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        const clock = SourcePrivateSessionHost.clock()
        const response: PrivateResponse = { ok: true, randomHex, nowMs: clock.nowMs, gts: clock.gts }
        return JSON.stringify(response)
      }
      if (req.op === 'rsa_pkcs1') {
        if (typeof req.publicKey !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(req.publicKey) || req.publicKey.length > 1024 ||
          typeof req.plaintext !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
        const plain = SourcePrivateSessionHost.bytes(req.plaintext)
        const pub = new Uint8Array(buffer.from(req.publicKey, 'base64').buffer)
        if (plain.length < 1 || plain.length > 245 || pub.length < 256 || pub.length > 512) return SourcePrivateSessionHost.fail('invalid_request')
        const keys = await cryptoFramework.createAsyKeyGenerator('RSA2048').convertKey({ data: pub }, null)
        const cipher = cryptoFramework.createCipher('RSA2048|PKCS1')
        await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, keys.pubKey, null)
        const out = await cipher.doFinal({ data: plain })
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        if (out === null || out.data.length !== 256) return SourcePrivateSessionHost.fail('crypto_failed')
        return JSON.stringify({ ok: true, value: buffer.from(out.data).toString('base64') })
      }
      const key = JSON.stringify([scope.sourceId, scope.packageIdentity])
      let state = SourcePrivateSessionHost.states.get(key)
      if (state === undefined) {
        state = new PrivateState(); state.key = key
        try { state.root = PRIVATE_PREFIX + await SourcePrivateSessionHost.hash(SourcePrivateSessionHost.bytes(key)) }
        catch (error) { return SourcePrivateSessionHost.stageFailure('key_digest', error as Object) }
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        const existing = SourcePrivateSessionHost.states.get(key)
        if (existing !== undefined) state = existing
        else SourcePrivateSessionHost.states.set(key, state)
      }
      const selected = state
      if (req.op === 'begin') {
        const result = await SourcePrivateSessionHost.locked(selected, async (): Promise<BeginResult> => {
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          try { await SourcePrivateSessionHost.load(selected) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('cache_read', error as Object), wait: null } }
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          if (selected.value !== null) {
            const clock = SourcePrivateSessionHost.clock()
            const response: PrivateResponse = { ok: true, state: 'ready', value: selected.value.value, versionTag: selected.value.versionTag, nowMs: clock.nowMs, gts: clock.gts }
            return { response: JSON.stringify(response), wait: null }
          }
          if (selected.owner !== null) return { response: '', wait: selected.owner.done }
          let lease: string
          let randomHex: string
          try { lease = await SourcePrivateSessionHost.random(16) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('lease_random', error as Object), wait: null } }
          try { randomHex = await SourcePrivateSessionHost.random(48) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('client_random', error as Object), wait: null } }
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          let resolve: (ok: boolean) => void = (_ok: boolean): void => {}
          const done = new Promise<boolean>((r: (ok: boolean) => void): void => { resolve = r })
          selected.owner = { callId: scope.callId, lease, done, resolve }
          const clock = SourcePrivateSessionHost.clock()
          const response: PrivateResponse = { ok: true, state: 'owner', lease, randomHex, nowMs: clock.nowMs, gts: clock.gts }
          return { response: JSON.stringify(response), wait: null }
        })
        if (result.wait === null) return result.response
        if (!await result.wait || !SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('owner_aborted')
        return SourcePrivateSessionHost.execute(requestJson, scope, isCurrent)
      }
      return await SourcePrivateSessionHost.locked(selected, async (): Promise<string> => {
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        await SourcePrivateSessionHost.load(selected)
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        if (req.op === 'invalidate') {
          if (typeof req.versionTag !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
          if (selected.value?.versionTag === req.versionTag && selected.manifest !== null) {
            const previous = selected.manifest
            await asset.remove(SourcePrivateSessionHost.identity(selected.root))
            selected.value = null; selected.manifest = null
            await SourcePrivateSessionHost.removeChunks(selected, previous)
          }
          return JSON.stringify({ ok: true })
        }
        const owner = selected.owner
        if (owner === null || owner.callId !== scope.callId || typeof req.lease !== 'string' || owner.lease !== req.lease) return SourcePrivateSessionHost.fail('invalid_lease')
        if (req.op === 'abort') { selected.owner = null; owner.resolve(false); return JSON.stringify({ ok: true }) }
        if (req.op !== 'commit' || typeof req.value !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
        const bytes = SourcePrivateSessionHost.bytes(req.value)
        if (bytes.byteLength === 0 || bytes.byteLength > MAX_VALUE_BYTES) return SourcePrivateSessionHost.fail('invalid_request')
        const id = await SourcePrivateSessionHost.random(16)
        const m: PrivateManifest = { format: 'private-v1', id, chunks: Math.ceil(bytes.length / CHUNK_BYTES), bytes: bytes.length, sha256: await SourcePrivateSessionHost.hash(bytes) }
        let staged = 0
        try {
          for (let i = 0; i < m.chunks; i++) {
            if (!SourcePrivateSessionHost.active(scope, isCurrent) || selected.owner !== owner) throw new Error('inactive')
            staged = i + 1
            await SourcePrivateSessionHost.write(SourcePrivateSessionHost.chunk(selected, id, i), bytes.slice(i * CHUNK_BYTES, Math.min(bytes.length, (i + 1) * CHUNK_BYTES)))
          }
          if (!SourcePrivateSessionHost.active(scope, isCurrent) || selected.owner !== owner) throw new Error('inactive')
          await SourcePrivateSessionHost.write(selected.root, SourcePrivateSessionHost.bytes(JSON.stringify(m)))
          // Asset writes cannot be canceled. If the call ended during the root write,
          // restore the previous root before allowing a later owner into this queue.
          if (!SourcePrivateSessionHost.active(scope, isCurrent) || selected.owner !== owner) {
            try {
              const currentRoot = await SourcePrivateSessionHost.read(selected.root)
              const currentManifest = currentRoot === null ? null : JSON.parse(SourcePrivateSessionHost.text(currentRoot)) as PrivateManifest
              if (currentManifest === null || currentManifest.id !== m.id) throw new Error('generation_changed')
              if (selected.manifest === null) await asset.remove(SourcePrivateSessionHost.identity(selected.root))
              else await SourcePrivateSessionHost.write(selected.root, SourcePrivateSessionHost.bytes(JSON.stringify(selected.manifest)))
            } catch (_restoreError) {
              // Keep both generations: deleting a possibly published generation would corrupt it.
              selected.loaded = false; selected.value = null; selected.manifest = null
              return SourcePrivateSessionHost.fail('rollback_failed')
            }
            throw new Error('inactive')
          }
        } catch (_error) {
          await SourcePrivateSessionHost.removeChunks(selected, { format: m.format, id: m.id, chunks: staged, bytes: m.bytes, sha256: m.sha256 })
          if (selected.owner === owner) { selected.owner = null; owner.resolve(false) }
          return SourcePrivateSessionHost.fail('storage_failed')
        }
        const previous = selected.manifest
        selected.manifest = m; selected.value = { value: req.value, versionTag: id }
        if (selected.owner === owner) { selected.owner = null; owner.resolve(true) }
        if (previous !== null) await SourcePrivateSessionHost.removeChunks(selected, previous)
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        return JSON.stringify({ ok: true, versionTag: id })
      })
    } catch (_error) { return SourcePrivateSessionHost.fail('operation_failed') }
  }
}
