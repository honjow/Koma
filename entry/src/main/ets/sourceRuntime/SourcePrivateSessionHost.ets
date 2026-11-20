import { asset } from '@kit.AssetStoreKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer, util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { SourceWebTokenDescriptor, sourceAuthenticationOrigin } from './SourceAuthenticationDescriptor'
import { parseSourceWebAccessToken, SourceWebTokenValue } from './SourceWebToken'

export interface SourcePrivateSessionScope {
  sourceId: string; packageIdentity: string; callId: string; privateSessionIdentity?: string
  webToken?: SourceWebTokenDescriptor
  operation?: string
}
export interface SourcePrivateSessionCall { id: string; httpContextJson: string }
export interface SourceWebTokenHttpIdentity {
  sourceId: string
  packageIdentity: string
  privateCallId?: string
}
export interface SourceWebTokenRequestGrant {
  authorization: string
  current: () => boolean
  rejectUnauthorized: () => Promise<void>
}

interface PrivateError { code: string }
interface PrivateFailureFields { fixedCode?: string; name?: string }
interface PrivateErrorResponse { ok: boolean; error: PrivateError }
interface PrivateClock { nowMs: string; gts: string }
interface PrivateResponse { ok: boolean; state?: string; value?: string; versionTag?: string; lease?: string; randomHex?: string; nowMs?: string; gts?: string }
interface PrivateRequest { type: string; version: number; op: string; lease?: string; value?: string; versionTag?: string; replaceVersionTag?: string; publicKey?: string; plaintext?: string; deriveImageKey?: boolean }
interface WebTokenReply {
  ok: boolean
  state: 'empty' | 'expired' | 'ready'
  generation?: string
  imageKeyHex?: string
  imageIvHex?: string
}
interface WebTokenPin {
  state: PrivateState
  value: PrivateValue | null
  expiresAt: number
}
interface PrivateManifest { format: string; id: string; chunks: number; bytes: number; sha256: string }
interface PrivateValue { value: string; versionTag: string; webToken?: SourceWebTokenValue }
interface PrivatePublish { error: string; previous: PrivateManifest | null }
interface BeginResult { response: string; wait: Promise<boolean> | null }
interface PrivateOwner { callId: string; lease: string; done: Promise<boolean>; resolve: (ok: boolean) => void; expectedVersionTag?: string }
interface SourceCredentialGrant {
  sourceId: string; packageIdentity: string; origin: string; operation: string
  username: string; password: string; callId: string; current: () => boolean
}
interface SourceCredentialInput { username: string; password: string }
interface SourceCredentialInputResponse { ok: boolean; credentials: SourceCredentialInput }
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
  revision: number = 0
  owner: PrivateOwner | null = null
  blockedWebGeneration: string = ''
  webToken: boolean = false
  queue: Promise<void> = Promise.resolve()
}

// The source ID and host-approved session identity address secure storage. The
// installed package identity still guards each individual call.
const PRIVATE_PREFIX: string = 'koma.source.private.v1.'
const MAX_VALUE_BYTES: number = 65536
const CHUNK_BYTES: number = 1024

export class SourcePrivateSessionHost {
  private static calls: Map<string, SourcePrivateSessionScope> = new Map()
  private static publicInitializationCalls: Set<string> = new Set()
  private static states: Map<string, PrivateState> = new Map()
  private static nextCall: number = 0
  private static processTag: string = ''
  private static credentialGrants: Map<string, SourceCredentialGrant> = new Map()
  private static callCredentialGrants: Map<string, string> = new Map()
  private static removingScopes: Set<string> = new Set()
  private static removalVersions: Map<string, number> = new Map()
  private static webTokenPins: Map<string, WebTokenPin> = new Map()
  private static retiredWebCalls: Set<string> = new Set()

  private static storageKey(sourceId: string, storageIdentity: string, webToken: boolean): string {
    return webToken ? JSON.stringify([sourceId, storageIdentity, 'web_token']) : JSON.stringify([sourceId, storageIdentity])
  }

  /** In-process cache fence. This exposes neither the private value nor its storage identifier. */
  static authenticationRevision(sourceId: string, packageIdentity: string): string {
    const key = JSON.stringify([sourceId, packageIdentity])
    return `${SourcePrivateSessionHost.removalVersions.get(key) ?? 0}:${SourcePrivateSessionHost.states.get(key)?.revision ?? 0}`
  }

  /** Non-secret cache fence for opt-in web-token sources. */
  static webTokenRevision(sourceId: string, storageIdentity: string): string {
    const state = SourcePrivateSessionHost.states.get(SourcePrivateSessionHost.storageKey(sourceId, storageIdentity, true))
    if (state?.loaded !== true) return 'unloaded'
    const value = state?.value
    return value !== null && value !== undefined && state?.blockedWebGeneration !== value.versionTag &&
      (value.webToken?.expiresAt ?? 0) > Date.now() ? value.versionTag : 'guest'
  }

  /** Uninstall retires queued calls even when the same package is reinstalled.
   * The current package check in the transport separately fences updates. */
  static callAdmission(httpContextJson: string): () => boolean {
    try {
      const context = JSON.parse(httpContextJson) as Record<string, Object>
      if (typeof context?.sourceId !== 'string' || typeof context.packageIdentity !== 'string') return (): boolean => true
      const storageIdentity = typeof context.privateSessionIdentity === 'string' ?
        context.privateSessionIdentity : context.packageIdentity
      const key = JSON.stringify([context.sourceId, storageIdentity])
      const version = SourcePrivateSessionHost.removalVersions.get(key) ?? 0
      return (): boolean => !SourcePrivateSessionHost.removingScopes.has(key) &&
        (SourcePrivateSessionHost.removalVersions.get(key) ?? 0) === version
    } catch (_error) { return (): boolean => true }
  }

  /** Ordinary uninstall only. No RPC can select or remove a scope. The caller commits
   * public files/registry inside mutation; failures restore this exact generation in memory/Asset. */
  static async withScopeRemoved(sourceId: string, packageIdentity: string, mutation: () => Promise<void>,
    storageIdentity: string = packageIdentity, webToken: boolean = false): Promise<void> {
    if (sourceId.length === 0 || packageIdentity.length === 0) throw new Error('source_remove_private_identity_invalid')
    const key = JSON.stringify([sourceId, storageIdentity])
    if (SourcePrivateSessionHost.removingScopes.has(key)) throw new Error('source_remove_private_busy')
    SourcePrivateSessionHost.removingScopes.add(key)
    SourcePrivateSessionHost.removalVersions.set(key, (SourcePrivateSessionHost.removalVersions.get(key) ?? 0) + 1)
    SourcePrivateSessionHost.retirePackageCalls(sourceId, packageIdentity)
    try {
      const stateKey = SourcePrivateSessionHost.storageKey(sourceId, storageIdentity, webToken)
      let state = SourcePrivateSessionHost.states.get(stateKey)
      if (state === undefined) {
        state = new PrivateState(); state.key = stateKey
        state.webToken = webToken
        try { state.root = PRIVATE_PREFIX + await SourcePrivateSessionHost.hash(SourcePrivateSessionHost.bytes(stateKey)) }
        catch (_error) { throw new Error('source_remove_private_read_failed') }
        const existing = SourcePrivateSessionHost.states.get(stateKey)
        if (existing !== undefined) state = existing
        else SourcePrivateSessionHost.states.set(stateKey, state)
      }
      const selected = state
      await SourcePrivateSessionHost.locked(selected, async (): Promise<void> => {
        // A commit already inside the queue observes the retired call and restores its
        // previous root before this task may read/delete anything.
        const rememberedLoaded = selected.loaded
        const rememberedValue = selected.value
        const rememberedManifest = selected.manifest
        selected.loaded = false; selected.value = null; selected.manifest = null
        try { await SourcePrivateSessionHost.load(selected) }
        catch (_error) {
          selected.loaded = rememberedLoaded; selected.value = rememberedValue; selected.manifest = rememberedManifest
          throw new Error('source_remove_private_read_failed')
        }
        const manifest = selected.manifest as PrivateManifest | null
        const value = selected.value as PrivateValue | null
        const bytes = value === null ? null : SourcePrivateSessionHost.bytes(value.value)
        let root: Uint8Array | null = null
        try { root = manifest === null ? null : await SourcePrivateSessionHost.read(selected.root) }
        catch (_error) { throw new Error('source_remove_private_read_failed') }
        if (manifest !== null && (bytes === null || root === null)) throw new Error('source_remove_private_read_failed')
        let changed = false
        let publicMutation = false
        try {
          if (manifest !== null) {
            changed = true
            await SourcePrivateSessionHost.removeExact(selected.root)
            for (let i = 0; i < manifest.chunks; i += 1) {
              await SourcePrivateSessionHost.removeExact(SourcePrivateSessionHost.chunk(selected, manifest.id, i))
            }
          }
          publicMutation = true
          await mutation()
          selected.value = null; selected.manifest = null; selected.loaded = true
        } catch (error) {
          if (changed && manifest !== null && bytes !== null && root !== null) {
            try {
              for (let i = 0; i < manifest.chunks; i += 1) {
                await SourcePrivateSessionHost.write(SourcePrivateSessionHost.chunk(selected, manifest.id, i),
                  bytes.slice(i * CHUNK_BYTES, Math.min(bytes.length, (i + 1) * CHUNK_BYTES)))
              }
              await SourcePrivateSessionHost.write(selected.root, root)
              selected.loaded = false; selected.value = null; selected.manifest = null
              await SourcePrivateSessionHost.load(selected)
              const restored = selected.value as PrivateValue | null
              if (restored?.versionTag !== manifest.id || restored?.value !== value?.value) {
                throw new Error('private_restore_mismatch')
              }
            } catch (_restoreError) {
              selected.loaded = false; selected.value = null; selected.manifest = null
              throw new Error('source_remove_private_rollback_failed')
            }
          }
          if (publicMutation) throw error as Error
          throw new Error('source_remove_private_delete_failed')
        }
      })
    } finally { SourcePrivateSessionHost.removingScopes.delete(key) }
  }

  /** UI action only. The reference travels in trusted Native context, never source args/settings. */
  static grantCredentials(sourceId: string, packageIdentity: string, origin: string, operation: string,
    username: string, password: string, current: () => boolean): string {
    if (!['get_authentication', 'authenticate', 'logout'].includes(operation) ||
      sourceAuthenticationOrigin(origin) !== origin || sourceId.length === 0 || packageIdentity.length === 0 ||
      SourcePrivateSessionHost.bytes(username + password).length > MAX_VALUE_BYTES || !current()) throw new Error('source_login_not_allowed')
    const id = util.generateRandomUUID(true)
    SourcePrivateSessionHost.credentialGrants.set(id, { sourceId, packageIdentity, origin, operation,
      username, password, callId: '', current })
    return id
  }

  static cancelCredentialGrant(id: string): void {
    const grant = SourcePrivateSessionHost.credentialGrants.get(id)
    if (grant !== undefined) { grant.username = ''; grant.password = '' }
    SourcePrivateSessionHost.credentialGrants.delete(id)
  }

  static credentialRequestAllowed(callId: string | undefined, grantId: string | undefined, fullUrl: string): boolean {
    if (grantId === undefined) return true
    const grant = SourcePrivateSessionHost.credentialGrants.get(grantId)
    if (grant === undefined || callId === undefined || grant.callId !== callId ||
      SourcePrivateSessionHost.callCredentialGrants.get(callId) !== grantId || grant.operation === 'get_authentication') return false
    try { return grant.current() && sourceAuthenticationOrigin(fullUrl) === grant.origin } catch (_error) { return false }
  }

  static beginCall(httpContextJson: string, publicInitializationAllowed: boolean = false): SourcePrivateSessionCall {
    try {
      const context = JSON.parse(httpContextJson) as Record<string, Object>
      if (context === null || typeof context.sourceId !== 'string' || context.sourceId.length === 0 ||
        typeof context.packageIdentity !== 'string' || context.packageIdentity.length === 0) {
        return { id: '', httpContextJson }
      }
      const id = `${Date.now().toString(36)}-${(++SourcePrivateSessionHost.nextCall).toString(36)}`
      const storageIdentity = typeof context.privateSessionIdentity === 'string' ?
        context.privateSessionIdentity : context.packageIdentity
      const scope: SourcePrivateSessionScope = { sourceId: context.sourceId, packageIdentity: context.packageIdentity,
        privateSessionIdentity: storageIdentity, callId: id }
      if (context.webToken !== undefined) scope.webToken = context.webToken as SourceWebTokenDescriptor
      if (typeof context.diagnosticOperation === 'string') scope.operation = context.diagnosticOperation
      if (SourcePrivateSessionHost.removingScopes.has(JSON.stringify([scope.sourceId, storageIdentity]))) return { id: '', httpContextJson }
      if (context.credentialGrantId !== undefined) {
        if (typeof context.credentialGrantId !== 'string') return { id: '', httpContextJson }
        const grant = SourcePrivateSessionHost.credentialGrants.get(context.credentialGrantId)
        if (grant === undefined || grant.callId.length > 0 || grant.sourceId !== scope.sourceId ||
          grant.packageIdentity !== scope.packageIdentity || !grant.current()) return { id: '', httpContextJson }
        grant.callId = id
        SourcePrivateSessionHost.callCredentialGrants.set(id, context.credentialGrantId)
      }
      SourcePrivateSessionHost.calls.set(id, scope)
      context.privateCallId = id
      if (publicInitializationAllowed) SourcePrivateSessionHost.publicInitializationCalls.add(id)
      return { id, httpContextJson: JSON.stringify(context) }
    } catch (_error) { return { id: '', httpContextJson } }
  }

  static finishCall(id: string): void {
    SourcePrivateSessionHost.retiredWebCalls.delete(id)
    SourcePrivateSessionHost.webTokenPins.delete(id)
    SourcePrivateSessionHost.publicInitializationCalls.delete(id)
    const grantId = SourcePrivateSessionHost.callCredentialGrants.get(id)
    if (grantId !== undefined) SourcePrivateSessionHost.cancelCredentialGrant(grantId)
    SourcePrivateSessionHost.callCredentialGrants.delete(id)
    SourcePrivateSessionHost.calls.delete(id)
    SourcePrivateSessionHost.states.forEach((state: PrivateState): void => {
      if (state.owner?.callId === id) {
        const owner = state.owner
        state.owner = null
        owner.resolve(false)
      }
    })
  }

  static retirePackageCalls(sourceId: string, packageIdentity: string): void {
    SourcePrivateSessionHost.calls.forEach((scope: SourcePrivateSessionScope, id: string): void => {
      if (scope.sourceId === sourceId && scope.packageIdentity === packageIdentity) {
        SourcePrivateSessionHost.finishCall(id)
        if (scope.webToken !== undefined) SourcePrivateSessionHost.retiredWebCalls.add(id)
      }
    })
  }

  static retireWebTokenPackage(sourceId: string, packageIdentity: string, storageIdentity: string): void {
    const key = SourcePrivateSessionHost.storageKey(sourceId, storageIdentity, false)
    SourcePrivateSessionHost.removalVersions.set(key, (SourcePrivateSessionHost.removalVersions.get(key) ?? 0) + 1)
    SourcePrivateSessionHost.retirePackageCalls(sourceId, packageIdentity)
  }

  static callIsActive(scope: SourcePrivateSessionScope): boolean {
    const live = SourcePrivateSessionHost.calls.get(scope.callId)
    if (live === undefined || live.sourceId !== scope.sourceId || live.packageIdentity !== scope.packageIdentity) return false
    const grantId = SourcePrivateSessionHost.callCredentialGrants.get(scope.callId)
    if (grantId === undefined) return true
    const grant = SourcePrivateSessionHost.credentialGrants.get(grantId)
    try { return grant !== undefined && grant.callId === scope.callId && grant.current() } catch (_error) { return false }
  }

  /** Only a trusted, network-enabled operation may start the separate unsigned
   * channel preparation. This never grants credential_input or another HTTP origin. */
  static publicInitializationIsAllowed(scope: SourcePrivateSessionScope): boolean {
    return SourcePrivateSessionHost.publicInitializationCalls.has(scope.callId) &&
      SourcePrivateSessionHost.callIsActive(scope)
  }

  private static active(scope: SourcePrivateSessionScope, current: () => boolean): boolean {
    try { return SourcePrivateSessionHost.callIsActive(scope) && current() } catch (_error) { return false }
  }
  private static isAuthenticationCall(scope: SourcePrivateSessionScope): boolean {
    const id = SourcePrivateSessionHost.callCredentialGrants.get(scope.callId)
    return id !== undefined && SourcePrivateSessionHost.credentialGrants.get(id)?.operation === 'authenticate'
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
  private static async removeExact(alias: string): Promise<void> {
    try { await asset.remove(SourcePrivateSessionHost.identity(alias)) }
    catch (error) {
      if (SourcePrivateSessionHost.platformCode(error as Object) !== '24000002') throw new Error('private_delete_failed')
    }
    if (await SourcePrivateSessionHost.read(alias) !== null) throw new Error('private_delete_failed')
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
    const value: PrivateValue = { value: SourcePrivateSessionHost.text(bytes), versionTag: m.id }
    if (state.webToken) {
      value.webToken = parseSourceWebAccessToken(value.value)
      if (value.webToken === undefined) throw new PrivateReadFailure('load_manifest_validation')
    }
    state.value = value; state.manifest = m; state.loaded = true
  }
  private static async locked<T>(state: PrivateState, fn: () => Promise<T>): Promise<T> {
    const task = state.queue.then(fn)
    state.queue = task.then((): void => {}, (): void => {})
    return task
  }

  private static async webTokenState(sourceId: string, storageIdentity: string): Promise<PrivateState> {
    const key = SourcePrivateSessionHost.storageKey(sourceId, storageIdentity, true)
    let state = SourcePrivateSessionHost.states.get(key)
    if (state !== undefined) return state
    const root = PRIVATE_PREFIX + await SourcePrivateSessionHost.hash(SourcePrivateSessionHost.bytes(key))
    state = SourcePrivateSessionHost.states.get(key)
    if (state !== undefined) return state
    state = new PrivateState(); state.key = key; state.root = root; state.webToken = true
    SourcePrivateSessionHost.states.set(key, state)
    return state
  }

  static async loadWebTokenRevision(sourceId: string, storageIdentity: string): Promise<string> {
    const state = await SourcePrivateSessionHost.webTokenState(sourceId, storageIdentity)
    if (!state.loaded) await SourcePrivateSessionHost.locked(state, (): Promise<void> => SourcePrivateSessionHost.load(state))
    return SourcePrivateSessionHost.webTokenRevision(sourceId, storageIdentity)
  }

  /** Only the native login presenter can publish a verified token. Guest RPCs have no write path. */
  static async installWebToken(sourceId: string, storageIdentity: string, token: SourceWebTokenValue,
    current: () => boolean): Promise<boolean> {
    const state = await SourcePrivateSessionHost.webTokenState(sourceId, storageIdentity)
    const active = (): boolean => current() && token.expiresAt > Date.now() &&
      !SourcePrivateSessionHost.removingScopes.has(SourcePrivateSessionHost.storageKey(sourceId, storageIdentity, false))
    return SourcePrivateSessionHost.locked(state, async (): Promise<boolean> => {
      if (!active()) return false
      await SourcePrivateSessionHost.load(state)
      if (!active()) return false
      if (state.value?.value === token.token && state.blockedWebGeneration !== state.value.versionTag) return true
      const result = await SourcePrivateSessionHost.publish(state, token.token, active, token)
      if (result.error.length > 0) return false
      if (result.previous !== null) await SourcePrivateSessionHost.removeChunks(state, result.previous)
      return active()
    })
  }

  private static async deleteWebToken(state: PrivateState, expected?: PrivateValue): Promise<void> {
    await SourcePrivateSessionHost.locked(state, async (): Promise<void> => {
      await SourcePrivateSessionHost.load(state)
      const previous = state.manifest
      const value = state.value
      if (previous === null || value === null || (expected !== undefined && value !== expected)) return
      state.blockedWebGeneration = value.versionTag
      await SourcePrivateSessionHost.removeExact(state.root)
      state.value = null; state.manifest = null; state.revision += 1
      await SourcePrivateSessionHost.removeChunks(state, previous)
    })
  }

  static async disconnectWebToken(sourceId: string, storageIdentity: string): Promise<void> {
    await SourcePrivateSessionHost.deleteWebToken(await SourcePrivateSessionHost.webTokenState(sourceId, storageIdentity))
  }

  private static pinIsCurrent(pin: WebTokenPin): boolean {
    return pin.state.loaded && pin.state.value === pin.value &&
      (pin.expiresAt === 0 || (pin.expiresAt > Date.now() && pin.state.blockedWebGeneration !== pin.value?.versionTag))
  }

  /** Callers must also keep their existing exact operation/installation guard active.
   * The returned Authorization value is for the single native request, never the guest response. */
  static resolveWebTokenRequest(identity: SourceWebTokenHttpIdentity | undefined, fullUrl: string,
    generation: string): SourceWebTokenRequestGrant | undefined {
    const id = identity?.privateCallId
    if (identity === undefined || id === undefined) return undefined
    const call = SourcePrivateSessionHost.calls.get(id)
    const pin = SourcePrivateSessionHost.webTokenPins.get(id)
    const value = pin?.value
    const token = value?.webToken
    if (call === undefined || pin === undefined || value === undefined || value === null || token === undefined ||
      pin.expiresAt === 0 || value.versionTag !== generation || call.sourceId !== identity.sourceId ||
      call.packageIdentity !== identity.packageIdentity || call.webToken === undefined ||
      sourceAuthenticationOrigin(fullUrl) !== call.webToken.apiOrigin) return undefined
    const current = (): boolean => SourcePrivateSessionHost.callIsActive(call) && SourcePrivateSessionHost.pinIsCurrent(pin)
    if (!current()) return undefined
    return { authorization: 'Bearer ' + token.token, current, rejectUnauthorized: async (): Promise<void> => {
      if (!current()) return
      pin.state.blockedWebGeneration = value.versionTag
      await SourcePrivateSessionHost.deleteWebToken(pin.state, value)
    } }
  }

  static webTokenResultIsCurrent(callId: string): boolean {
    const pin = SourcePrivateSessionHost.webTokenPins.get(callId)
    return !SourcePrivateSessionHost.retiredWebCalls.has(callId) && (pin === undefined || SourcePrivateSessionHost.pinIsCurrent(pin))
  }

  private static async webTokenReply(req: PrivateRequest, scope: SourcePrivateSessionScope,
    isCurrent: () => boolean): Promise<string> {
    const call = SourcePrivateSessionHost.calls.get(scope.callId)
    if (call?.webToken === undefined || (req.deriveImageKey !== undefined && req.deriveImageKey !== true) ||
      (req.deriveImageKey === true && (call.webToken.imageKeyDerivation !== 'sha512_cbc' ||
        call.operation !== 'get_image_request'))) {
      return SourcePrivateSessionHost.fail('web_token_unavailable')
    }
    const state = await SourcePrivateSessionHost.webTokenState(scope.sourceId, call.privateSessionIdentity ?? scope.packageIdentity)
    if (!state.loaded) await SourcePrivateSessionHost.locked(state, (): Promise<void> => SourcePrivateSessionHost.load(state))
    if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
    const value = state.value
    const token = value?.webToken
    const expiresAt = token !== undefined && token.expiresAt > Date.now() &&
      state.blockedWebGeneration !== value?.versionTag ? token.expiresAt : 0
    const existing = SourcePrivateSessionHost.webTokenPins.get(scope.callId)
    if (existing !== undefined && !SourcePrivateSessionHost.pinIsCurrent(existing)) return SourcePrivateSessionHost.fail('stale_version')
    const pin: WebTokenPin = existing ?? { state, value, expiresAt }
    SourcePrivateSessionHost.webTokenPins.set(scope.callId, pin)
    const reply: WebTokenReply = { ok: true, state: value === null ? 'empty' : pin.expiresAt === 0 ? 'expired' : 'ready' }
    if (reply.state === 'ready' && value !== null && token !== undefined) {
      reply.generation = value.versionTag
      if (req.deriveImageKey === true) {
        const md = cryptoFramework.createMd('SHA512')
        await md.update({ data: SourcePrivateSessionHost.bytes(token.token) })
        const digest = (await md.digest()).data
        if (!SourcePrivateSessionHost.active(scope, isCurrent) || !SourcePrivateSessionHost.pinIsCurrent(pin)) {
          return SourcePrivateSessionHost.fail('stale_version')
        }
        reply.imageKeyHex = SourcePrivateSessionHost.hex(digest.slice(0, 32))
        reply.imageIvHex = SourcePrivateSessionHost.hex(digest.slice(15, 31))
      }
    }
    return JSON.stringify(reply)
  }
  // Every private value uses the same commit point. A canceled writer restores
  // the previous index before another operation in this queue can read it.
  private static async publish(state: PrivateState, value: string, current: () => boolean,
    webToken?: SourceWebTokenValue): Promise<PrivatePublish> {
    const bytes = SourcePrivateSessionHost.bytes(value)
    const id = await SourcePrivateSessionHost.random(16)
    const manifest: PrivateManifest = { format: 'private-v1', id, chunks: Math.ceil(bytes.length / CHUNK_BYTES),
      bytes: bytes.length, sha256: await SourcePrivateSessionHost.hash(bytes) }
    let staged = 0
    try {
      for (let i = 0; i < manifest.chunks; i++) {
        if (!current()) throw new Error('inactive')
        staged = i + 1
        await SourcePrivateSessionHost.write(SourcePrivateSessionHost.chunk(state, id, i),
          bytes.slice(i * CHUNK_BYTES, Math.min(bytes.length, (i + 1) * CHUNK_BYTES)))
      }
      if (!current()) throw new Error('inactive')
      await SourcePrivateSessionHost.write(state.root, SourcePrivateSessionHost.bytes(JSON.stringify(manifest)))
      if (!current()) {
        try {
          const currentRoot = await SourcePrivateSessionHost.read(state.root)
          const currentManifest = currentRoot === null ? null :
            JSON.parse(SourcePrivateSessionHost.text(currentRoot)) as PrivateManifest
          if (currentManifest?.id !== manifest.id) throw new Error('generation_changed')
          if (state.manifest === null) await asset.remove(SourcePrivateSessionHost.identity(state.root))
          else await SourcePrivateSessionHost.write(state.root, SourcePrivateSessionHost.bytes(JSON.stringify(state.manifest)))
        } catch (_restoreError) {
          // Keep both sets of chunks if the index could not be restored.
          state.loaded = false; state.value = null; state.manifest = null
          if (state.webToken) state.blockedWebGeneration = id
          return { error: 'rollback_failed', previous: null }
        }
        throw new Error('inactive')
      }
    } catch (_error) {
      await SourcePrivateSessionHost.removeChunks(state, { format: manifest.format, id, chunks: staged,
        bytes: manifest.bytes, sha256: manifest.sha256 })
      return { error: 'storage_failed', previous: null }
    }
    const previous = state.manifest
    state.manifest = manifest
    state.value = { value, versionTag: id, webToken }
    state.revision += 1
    return { error: '', previous }
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
      if (req.op === 'web_token') return await SourcePrivateSessionHost.webTokenReply(req, scope, isCurrent)
      if (req.op === 'process_scope') {
        if (SourcePrivateSessionHost.processTag.length === 0) SourcePrivateSessionHost.processTag = util.generateRandomUUID(true)
        return JSON.stringify({ ok: true, processTag: SourcePrivateSessionHost.processTag })
      }
      if (req.op === 'credential_input') {
        const id = SourcePrivateSessionHost.callCredentialGrants.get(scope.callId)
        const grant = id === undefined ? undefined : SourcePrivateSessionHost.credentialGrants.get(id)
        if (grant === undefined || grant.operation !== 'authenticate' || grant.sourceId !== scope.sourceId ||
          grant.packageIdentity !== scope.packageIdentity || !SourcePrivateSessionHost.active(scope, isCurrent)) {
          return SourcePrivateSessionHost.fail('credential_input_unavailable')
        }
        const response: SourceCredentialInputResponse = { ok: true,
          credentials: { username: grant.username, password: grant.password } }
        return JSON.stringify(response)
      }
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
      const storageIdentity = SourcePrivateSessionHost.calls.get(scope.callId)?.privateSessionIdentity ?? scope.packageIdentity
      const key = JSON.stringify([scope.sourceId, storageIdentity])
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
      if (req.op === 'peek') {
        // Readers use the last committed generation without waiting for a login or renewal owner.
        if (!selected.loaded) {
          try { await SourcePrivateSessionHost.locked(selected, (): Promise<void> => SourcePrivateSessionHost.load(selected)) }
          catch (error) { return SourcePrivateSessionHost.stageFailure('cache_read', error as Object) }
        }
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        const currentValue = selected.value
        const response: PrivateResponse = currentValue === null ? { ok: true, state: 'empty' } :
          { ok: true, state: 'ready', value: currentValue.value, versionTag: currentValue.versionTag, nowMs: Date.now().toString() }
        return JSON.stringify(response)
      }
      if (req.op === 'begin') {
        const result = await SourcePrivateSessionHost.locked(selected, async (): Promise<BeginResult> => {
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          try { await SourcePrivateSessionHost.load(selected) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('cache_read', error as Object), wait: null } }
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          const replacing = req.replaceVersionTag !== undefined
          // Replace only the version this live source/install call already owns. Keeping the
          // previous index until commit also preserves public source caches on cancellation.
          if (replacing && (typeof req.replaceVersionTag !== 'string' || req.replaceVersionTag.length === 0)) {
            return { response: SourcePrivateSessionHost.fail('invalid_request'), wait: null }
          }
          if (replacing && selected.value?.versionTag !== req.replaceVersionTag) {
            return { response: SourcePrivateSessionHost.fail('stale_version'), wait: null }
          }
          if (selected.value !== null && !replacing) {
            const clock = SourcePrivateSessionHost.clock()
            const response: PrivateResponse = { ok: true, state: 'ready', value: selected.value.value, versionTag: selected.value.versionTag, nowMs: clock.nowMs, gts: clock.gts }
            return { response: JSON.stringify(response), wait: null }
          }
          if (selected.owner !== null) {
            if (replacing && selected.owner.callId === scope.callId) return { response: SourcePrivateSessionHost.fail('initializer_owned'), wait: null }
            return { response: '', wait: selected.owner.done }
          }
          let lease: string
          let randomHex: string
          try { lease = await SourcePrivateSessionHost.random(16) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('lease_random', error as Object), wait: null } }
          try { randomHex = await SourcePrivateSessionHost.random(48) }
          catch (error) { return { response: SourcePrivateSessionHost.stageFailure('client_random', error as Object), wait: null } }
          if (!SourcePrivateSessionHost.active(scope, isCurrent)) return { response: SourcePrivateSessionHost.fail('inactive'), wait: null }
          let resolve: (ok: boolean) => void = (_ok: boolean): void => {}
          const done = new Promise<boolean>((r: (ok: boolean) => void): void => { resolve = r })
          selected.owner = { callId: scope.callId, lease, done, resolve,
            expectedVersionTag: replacing ? req.replaceVersionTag : undefined }
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
          // Account replacement cannot delete the working account before its new index commits.
          // Ordinary source invalidation and an explicit logout keep their existing semantics.
          if (SourcePrivateSessionHost.isAuthenticationCall(scope)) return SourcePrivateSessionHost.fail('authentication_requires_replace')
          if (typeof req.versionTag !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
          if (selected.value?.versionTag === req.versionTag && selected.manifest !== null) {
            const previous = selected.manifest
            await asset.remove(SourcePrivateSessionHost.identity(selected.root))
            selected.value = null; selected.manifest = null
            selected.revision += 1
            await SourcePrivateSessionHost.removeChunks(selected, previous)
          }
          return JSON.stringify({ ok: true })
        }
        const owner = selected.owner
        if (owner === null || owner.callId !== scope.callId || typeof req.lease !== 'string' || owner.lease !== req.lease) return SourcePrivateSessionHost.fail('invalid_lease')
        if (req.op === 'abort') { selected.owner = null; owner.resolve(false); return JSON.stringify({ ok: true }) }
        if (req.op !== 'commit' || typeof req.value !== 'string') return SourcePrivateSessionHost.fail('invalid_request')
        if (owner.expectedVersionTag !== undefined && selected.value?.versionTag !== owner.expectedVersionTag) {
          return SourcePrivateSessionHost.fail('stale_version')
        }
        const bytes = SourcePrivateSessionHost.bytes(req.value)
        if (bytes.byteLength === 0 || bytes.byteLength > MAX_VALUE_BYTES) return SourcePrivateSessionHost.fail('invalid_request')
        const current = (): boolean => SourcePrivateSessionHost.active(scope, isCurrent) && selected.owner === owner
        const result = await SourcePrivateSessionHost.publish(selected, req.value, current)
        if (result.error === 'rollback_failed') return SourcePrivateSessionHost.fail(result.error)
        if (selected.owner === owner) { selected.owner = null; owner.resolve(result.error.length === 0) }
        if (result.error.length > 0) return SourcePrivateSessionHost.fail(result.error)
        const versionTag = selected.value?.versionTag
        if (result.previous !== null) await SourcePrivateSessionHost.removeChunks(selected, result.previous)
        if (!SourcePrivateSessionHost.active(scope, isCurrent)) return SourcePrivateSessionHost.fail('inactive')
        return JSON.stringify({ ok: true, versionTag })
      })
    } catch (_error) { return SourcePrivateSessionHost.fail('operation_failed') }
  }
}
