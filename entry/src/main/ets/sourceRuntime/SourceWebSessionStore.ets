import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { url, util } from '@kit.ArkTS'
import { webview } from '@kit.ArkWeb'
import { deviceInfo } from '@kit.BasicServicesKit'
import { SourceRuntimeRegistry, SourceRuntimeRegistryEntry } from './SourceRuntimeRegistry'

/** Ask the engine for this URL's first-party partition; never enumerate the global jar. */
export function readSourceWebCookies(fullUrl: string): string {
  if (deviceInfo.sdkApiVersion >= 26) {
    return webview.WebCookieManager.fetchCookieSync(fullUrl, false, true)
  }
  return webview.WebCookieManager.fetchCookieSync(fullUrl, false)
}

export interface SourceWebSessionStatus {
  sourceId: string
  sessionId: string
  initialUrl: string
  origin: string
  state: string
}

export interface SourceHttpIdentity {
  sourceId: string
  sourceVersion: string
  packageIdentity: string
  webSessionOrigins: string[]
  privateCallId?: string
  operationGuardId?: string
  detailChapterContext?: boolean
  // Host-owned trace label only; never part of a grant, package identity or persisted session.
  diagnosticOperation?: string
}

export interface SourceWebRequestSession {
  userAgent: string
  cookie: string
}

/** Ephemeral proof from the current visible verification document, never a WASM field. */
export interface SourcePendingWebSessionRequest {
  sessionId: string
  initialUrl: string
  documentUrl: string
  userAgent: string
}

interface SourceWebSession {
  status: SourceWebSessionStatus
  registry: SourceRuntimeRegistry
  entry: SourceRuntimeRegistryEntry
  packageIdentity: string
  userAgent: string
}

export function sourceWebOrigin(fullUrl: string): string {
  try {
    const parsed = new url.URL(fullUrl)
    if (parsed.protocol !== 'https:' || parsed.username.length > 0 || parsed.password.length > 0 ||
      parsed.hostname.length === 0) return ''
    return parsed.origin
  } catch (_error) { return '' }
}

interface PersistedWebSession {
  sourceId: string
  sourceVersion: string
  packageIdentity: string
  origin: string
  userAgent: string
}

interface PersistedWebSessions {
  schemaVersion: number
  sessions: PersistedWebSession[]
}

export function sourceWebPackageIdentity(entry: SourceRuntimeRegistryEntry): string {
  return JSON.stringify([entry.sourceId, entry.manifestVersion, entry.wasmPath ?? entry.archivePath ?? '',
    JSON.stringify((entry.webSessionOrigins ?? []).slice().sort())])
}

export function sourceHttpIdentityJson(entry: SourceRuntimeRegistryEntry, operationGuardId?: string,
  detailChapterContext: boolean = false, diagnosticOperation?: string): string {
  const identity: SourceHttpIdentity = { sourceId: entry.sourceId, sourceVersion: entry.manifestVersion,
    packageIdentity: sourceWebPackageIdentity(entry), webSessionOrigins: entry.webSessionOrigins ?? [] }
  if (operationGuardId !== undefined) identity.operationGuardId = operationGuardId
  if (detailChapterContext) identity.detailChapterContext = true
  if (diagnosticOperation !== undefined && ['search', 'get_manga', 'get_chapters', 'get_pages',
    'get_manga_list', 'get_home', 'get_listings', 'get_filters', 'get_settings', 'get_image_request'].includes(diagnosticOperation)) {
    identity.diagnosticOperation = diagnosticOperation
  }
  return JSON.stringify(identity)
}

function emptyStatus(sourceId: string): SourceWebSessionStatus {
  return { sourceId, sessionId: '', initialUrl: '', origin: '', state: 'none' }
}

// Keep grants per exact origin; legacy persisted records already carry the origin.
function sourceSessionKey(sourceId: string, origin: string): string { return JSON.stringify([sourceId, origin]) }

export class SourceWebSessionStore {
  private sessions: Map<string, SourceWebSession> = new Map<string, SourceWebSession>()
  private pending: Map<string, SourceWebSession> = new Map<string, SourceWebSession>()
  private persisted: Map<string, PersistedWebSession> = new Map<string, PersistedWebSession>()
  private rejectedUrls: Map<string, string> = new Map<string, string>()
  private registry?: SourceRuntimeRegistry
  private storagePath: string = ''

  configure(context: common.UIAbilityContext, registry: SourceRuntimeRegistry): void {
    this.registry = registry
    const directory = context.filesDir + '/source-runtime'
    if (!fs.accessSync(directory)) fs.mkdirSync(directory, true)
    this.storagePath = directory + '/web-sessions.json'
    if (!fs.accessSync(this.storagePath)) return
    try {
      const document = JSON.parse(fs.readTextSync(this.storagePath)) as PersistedWebSessions
      if (document.schemaVersion !== 1 || !Array.isArray(document.sessions)) return
      document.sessions.forEach((record: PersistedWebSession) => {
        if (typeof record.sourceId === 'string' && typeof record.sourceVersion === 'string' &&
          typeof record.packageIdentity === 'string' && typeof record.origin === 'string' && sourceWebOrigin(record.origin) === record.origin &&
          typeof record.userAgent === 'string' && record.userAgent.trim().length > 0 && !/[\r\n]/.test(record.userAgent)) {
          this.persisted.set(sourceSessionKey(record.sourceId, record.origin), record)
        }
      })
    } catch (_error) {}
  }

  launchUrl(registry: SourceRuntimeRegistry, sourceId: string, exactRequestUrl?: string): string {
    const entry = registry.lookup(sourceId).entry
    if (entry === undefined || !entry.enabled) throw new Error('source_web_session_not_allowed')
    // A supplied empty string means this specific operation had no uniquely
    // identified GET; never borrow a different operation's last rejection.
    const previous = exactRequestUrl === undefined ? this.rejectedUrls.get(sourceId) : exactRequestUrl
    if (previous !== undefined && (entry.webSessionOrigins ?? []).includes(sourceWebOrigin(previous))) return previous
    const origin = (entry.webSessionOrigins ?? [])[0]
    if (origin === undefined) throw new Error('source_web_session_not_allowed')
    return origin + '/'
  }

  observeRejectedRequest(identity: SourceHttpIdentity, fullUrl: string): void {
    const origin = sourceWebOrigin(fullUrl)
    if (origin.length > 0 && identity.webSessionOrigins.includes(origin)) this.rejectedUrls.set(identity.sourceId, fullUrl)
  }

  begin(registry: SourceRuntimeRegistry, sourceId: string, fullUrl: string): SourceWebSessionStatus {
    const entry = registry.lookup(sourceId).entry
    const origin = sourceWebOrigin(fullUrl)
    if (entry === undefined || !entry.enabled || origin.length === 0 ||
      !(entry.webSessionOrigins ?? []).includes(origin)) throw new Error('source_web_session_not_allowed')
    const status: SourceWebSessionStatus = {
      sourceId, sessionId: util.generateRandomUUID(true), initialUrl: fullUrl, origin, state: 'pending',
    }
    this.pending.set(sourceId, { status, registry, entry, packageIdentity: sourceWebPackageIdentity(entry), userAgent: '' })
    return { sourceId, sessionId: status.sessionId, initialUrl: fullUrl, origin, state: 'pending' }
  }

  complete(sourceId: string, sessionId: string, currentFullUrl: string, actualUserAgent: string): SourceWebSessionStatus {
    const session = this.pending.get(sourceId)
    if (session === undefined || session.status.sessionId !== sessionId ||
      sourceWebPackageIdentity(session.registry.lookup(sourceId).entry ?? session.entry) !== session.packageIdentity ||
      session.registry.lookup(sourceId).entry?.enabled !== true ||
      sourceWebOrigin(currentFullUrl) !== session.status.origin || actualUserAgent.trim().length === 0 ||
      /[\r\n]/.test(actualUserAgent)) throw new Error('source_web_session_not_allowed')
    const key = sourceSessionKey(sourceId, session.status.origin)
    const previous = this.sessions.get(key)
    const previousRecord = this.persisted.get(key)
    session.userAgent = actualUserAgent
    session.status.state = 'available'
    this.sessions.set(key, session)
    this.persisted.set(key, { sourceId, sourceVersion: session.entry.manifestVersion,
      packageIdentity: session.packageIdentity, origin: session.status.origin, userAgent: actualUserAgent })
    try { this.persist() } catch (error) {
      this.sessions.delete(key)
      this.persisted.delete(key)
      if (previous !== undefined) this.sessions.set(key, previous)
      if (previousRecord !== undefined) this.persisted.set(key, previousRecord)
      session.status.state = 'pending'
      throw error as Error
    }
    this.pending.delete(sourceId)
    return this.status(sourceId, session.status.origin)
  }

  cancel(sourceId: string, sessionId: string): void {
    if (this.pending.get(sourceId)?.status.sessionId === sessionId) this.pending.delete(sourceId)
  }

  revoke(sourceId: string): void {
    this.pending.delete(sourceId)
    const keys: string[] = []
    this.persisted.forEach((record: PersistedWebSession, key: string) => { if (record.sourceId === sourceId) keys.push(key) })
    keys.forEach((key: string) => { this.sessions.delete(key); this.persisted.delete(key) })
    this.persist()
  }

  status(sourceId: string, origin?: string): SourceWebSessionStatus {
    const session = this.current(sourceId, origin)
    if (session === undefined) return emptyStatus(sourceId)
    return { sourceId, sessionId: session.status.sessionId, initialUrl: session.status.initialUrl,
      origin: session.status.origin, state: session.status.state }
  }

  requestSession(identity: SourceHttpIdentity, fullUrl: string): SourceWebRequestSession | undefined {
    const origin = sourceWebOrigin(fullUrl)
    const session = this.current(identity.sourceId, origin)
    if (session === undefined || session.status.state !== 'available' ||
      identity.sourceVersion !== session.entry.manifestVersion || identity.packageIdentity !== session.packageIdentity || origin !== session.status.origin ||
      !identity.webSessionOrigins.includes(origin)) return undefined
    // UI-runtime callback only. The Web engine enforces URL/path/secure/expiry.
    // Cookie is never persisted by this store, logged, or included in WASM results.
    let cookie = ''
    try { cookie = readSourceWebCookies(fullUrl) } catch (_error) {}
    return { userAgent: session.userAgent, cookie }
  }

  pendingRequestSession(identity: SourceHttpIdentity, fullUrl: string,
    proof: SourcePendingWebSessionRequest): SourceWebRequestSession | undefined {
    const session = this.pending.get(identity.sourceId)
    if (session === undefined || session.status.sessionId !== proof.sessionId ||
      session.status.initialUrl !== proof.initialUrl ||
      sourceWebOrigin(fullUrl) !== session.status.origin || sourceWebOrigin(proof.documentUrl) !== session.status.origin ||
      identity.sourceVersion !== session.entry.manifestVersion || identity.packageIdentity !== session.packageIdentity ||
      !identity.webSessionOrigins.includes(session.status.origin) ||
      sourceWebPackageIdentity(session.registry.lookup(identity.sourceId).entry ?? session.entry) !== session.packageIdentity ||
      session.registry.lookup(identity.sourceId).entry?.enabled !== true ||
      proof.userAgent.trim().length === 0 || /[\r\n]/.test(proof.userAgent)) return undefined
    // This does not publish or persist a grant. Ordinary requests still use requestSession.
    try { return { userAgent: proof.userAgent, cookie: readSourceWebCookies(fullUrl) } }
    catch (_error) { return undefined }
  }

  acceptPendingResponseCookies(identity: SourceHttpIdentity, fullUrl: string,
    proof: SourcePendingWebSessionRequest, values: string[]): void {
    if (this.pendingRequestSession(identity, fullUrl, proof) === undefined) return
    this.writeResponseCookies(fullUrl, values)
  }

  acceptResponseCookies(identity: SourceHttpIdentity, fullUrl: string, values: string[]): void {
    // Only a currently granted exact source/origin may update the system jar.
    if (this.requestSession(identity, fullUrl) === undefined) return
    this.writeResponseCookies(fullUrl, values)
  }

  private writeResponseCookies(fullUrl: string, values: string[]): void {
    let updated = false
    values.forEach((value: string) => {
      if (value.length === 0 || value.length > 40960 || /[\r\n]/.test(value)) return
      try {
        webview.WebCookieManager.configCookieSync(fullUrl, value, false, true)
        updated = true
      } catch (_error) { /* Invalid server cookies do not expose values or change the response. */ }
    })
    if (updated) {
      try { webview.WebCookieManager.saveCookieSync() } catch (_error) {}
    }
  }

  private current(sourceId: string, origin?: string): SourceWebSession | undefined {
    let key: string | undefined = origin === undefined ? undefined : sourceSessionKey(sourceId, origin)
    if (key === undefined) {
      this.persisted.forEach((record: PersistedWebSession, candidate: string) => {
        if (record.sourceId === sourceId) key = candidate
      })
    }
    if (key === undefined) return undefined
    let session = this.sessions.get(key)
    if (session === undefined) {
      const record = this.persisted.get(key)
      const registry = this.registry
      if (record === undefined || registry === undefined) return undefined
      const entry = registry.lookup(sourceId).entry
      if (entry === undefined || !entry.enabled || entry.manifestVersion !== record.sourceVersion ||
        sourceWebPackageIdentity(entry) !== record.packageIdentity ||
        !(entry.webSessionOrigins ?? []).includes(record.origin)) {
        this.revokeInvalid(sourceId)
        return undefined
      }
      const status: SourceWebSessionStatus = { sourceId, sessionId: util.generateRandomUUID(true),
        initialUrl: record.origin + '/', origin: record.origin, state: 'available' }
      session = { status, registry, entry, packageIdentity: record.packageIdentity, userAgent: record.userAgent }
      this.sessions.set(key, session)
    }
    const entry = session.registry.lookup(sourceId).entry
    if (entry === undefined || entry.enabled !== true || sourceWebPackageIdentity(entry) !== session.packageIdentity ||
      !(entry.webSessionOrigins ?? []).includes(session.status.origin)) {
      this.revokeInvalid(sourceId)
      return undefined
    }
    return session
  }

  private revokeInvalid(sourceId: string): void {
    try { this.revoke(sourceId) } catch (_error) {
      DiagnosticLogger.warn('source_web_session', 'revoke_persist_failed', 'reason=storage_write_failed')
    }
  }

  private persist(): void {
    if (this.storagePath.length === 0) return
    const records: PersistedWebSession[] = []
    this.persisted.forEach((record: PersistedWebSession) => { records.push(record) })
    const document: PersistedWebSessions = { schemaVersion: 1, sessions: records }
    writeAppTextFile(this.storagePath, JSON.stringify(document))
  }
}

export const appSourceWebSessionStore: SourceWebSessionStore = new SourceWebSessionStore()
