import { SourceAuthenticationDescriptor, sourceAuthenticationDescriptor, sourceAuthenticationIdentity,
  sourceAuthenticationOrigin } from './SourceAuthenticationDescriptor'
import { appSourceRuntimeRegistry, sourceDisplayName } from './SourceRuntimeAppRegistry'
import { SourceRuntimeRegistryEntry, sourceRuntimeEntryEnabled } from './SourceRuntimeRegistry'
import { appSourceSettingsStore, SourceSettingsRecord } from './SourceSettingsStore'
import { appSourceSettingObservationStore } from './SourceSettingObservationStore'
import { SourceSettingObservations } from './SourceSettingObservations'
import { SourcePrivateSessionHost } from './SourcePrivateSessionHost'
import { sourceHttpIdentityJson, SourceHttpIdentity, sourceWebPackageIdentity } from './SourceWebSessionStore'
import { executeSourceRequestInWorker, SourceWorkerPriority } from './SourceRuntimeWorkerClient'
import { sourceRequestWithHostFeatures } from './SourceHostFeatures'
import { configureSourceRequestPolicy } from './SourceRequestPolicy'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import { SourceRuntimeError } from '../model/SourceRuntimeError'

interface AuthenticationArgs { settingObservations: SourceSettingObservations }
interface AuthenticationHostHints { network: boolean }
interface AuthenticationOperationRequest {
  type: string
  version: number
  operation: string
  sourceId: string
  args: AuthenticationArgs
  settings: SourceSettingsRecord
  hostHints: AuthenticationHostHints
}

export interface SourceAuthenticationSnapshot {
  authenticated: boolean
  loginUrl: string
  needsRefresh: boolean
}

interface AuthenticationCacheEntry {
  authenticated: boolean
  loginUrl: string
  packageIdentity: string
  settingsRevision: string
  sessionRevision: string
  checkedAt: number
}

const AUTHENTICATION_REFRESH_MS: number = 30000

export class SourceAuthenticationRequest {
  sourceId: string
  current: () => boolean
  complete: () => Promise<void>
  cancel: () => void
  constructor(sourceId: string, current: () => boolean, complete: () => Promise<void>, cancel: () => void = () => {}) {
    this.sourceId = sourceId; this.current = current; this.complete = complete; this.cancel = cancel
  }
}

export function sourceHasAuthentication(sourceId: string): boolean {
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  return entry !== undefined && sourceRuntimeEntryEnabled(entry) &&
    sourceAuthenticationDescriptor(entry.authentication) !== undefined
}

export class SourceAuthenticationService {
  private static snapshots: Map<string, AuthenticationCacheEntry> = new Map()
  readonly entry: SourceRuntimeRegistryEntry
  readonly descriptor: SourceAuthenticationDescriptor
  readonly title: string
  loginUrl: string = ''
  private settingsRevision: string
  private packageIdentity: string
  private alive: boolean = true
  private grantId: string = ''
  private current: () => boolean
  constructor(sourceId: string, current: () => boolean) {
    const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
    const descriptor = sourceAuthenticationDescriptor(entry?.authentication)
    if (entry === undefined || !sourceRuntimeEntryEnabled(entry) || descriptor === undefined) throw new Error('source_login_not_allowed')
    this.entry = entry; this.descriptor = descriptor; this.title = sourceDisplayName(sourceId, entry.manifestName)
    this.loginUrl = descriptor.loginUrls === undefined ? descriptor.loginUrl : ''
    this.settingsRevision = appSourceSettingsStore.revisionForSource(sourceId)
    this.packageIdentity = sourceWebPackageIdentity(entry); this.current = current
  }
  isCurrent(): boolean {
    try {
      const entry = appSourceRuntimeRegistry.lookup(this.entry.sourceId).entry
      return this.alive && this.current() && entry === this.entry && sourceRuntimeEntryEnabled(entry) &&
        sourceWebPackageIdentity(entry) === this.packageIdentity &&
        appSourceSettingsStore.revisionForSource(entry.sourceId) === this.settingsRevision
    } catch (_error) { return false }
  }
  cancel(): void {
    this.alive = false
    if (this.grantId.length > 0) SourcePrivateSessionHost.cancelCredentialGrant(this.grantId)
    this.grantId = ''
  }
  private sessionRevision(): string {
    return SourcePrivateSessionHost.authenticationRevision(this.entry.sourceId, this.packageIdentity)
  }
  /** The account sheet may paint a confirmed state immediately on re-entry.
   * Only display metadata is cached. Private mutations, mirror/settings changes
   * and package replacement invalidate it without a storage read on opening.
   */
  cachedStatus(): SourceAuthenticationSnapshot | undefined {
    if (this.descriptor.kind !== 'credentials' || !this.isCurrent()) return undefined
    const snapshot = SourceAuthenticationService.snapshots.get(this.entry.sourceId)
    if (snapshot === undefined || snapshot.packageIdentity !== this.packageIdentity ||
      snapshot.settingsRevision !== this.settingsRevision || snapshot.sessionRevision !== this.sessionRevision()) return undefined
    this.loginUrl = snapshot.loginUrl
    return { authenticated: snapshot.authenticated, loginUrl: snapshot.loginUrl,
      needsRefresh: Date.now() - snapshot.checkedAt >= AUTHENTICATION_REFRESH_MS }
  }
  async run(operation: 'get_authentication' | 'authenticate' | 'logout', username: string = '', password: string = ''): Promise<boolean> {
    if (!this.isCurrent() || this.grantId.length > 0 ||
      (this.descriptor.kind !== 'credentials' && operation !== 'get_authentication')) throw new Error('source_login_not_allowed')
    const target = operation === 'get_authentication' ? this.descriptor.loginUrl : this.loginUrl
    if (target.length === 0) throw new Error('source_login_not_allowed')
    // A failed descriptor validation must not leave an older mirror armed for credentials.
    if (operation === 'get_authentication' && this.descriptor.loginUrls !== undefined) this.loginUrl = ''
    const beforeSession = this.sessionRevision()
    const current = (): boolean => this.isCurrent()
    const grantId = SourcePrivateSessionHost.grantCredentials(this.entry.sourceId, this.packageIdentity,
      sourceAuthenticationOrigin(target), operation, username, password, current)
    this.grantId = grantId
    try {
      const context = JSON.parse(sourceHttpIdentityJson(this.entry)) as SourceHttpIdentity
      context.credentialGrantId = grantId
      const settings = appSourceSettingsStore.loadForSource(this.entry.sourceId)
      configureSourceRequestPolicy(this.entry.sourceId, settings)
      const payload: AuthenticationOperationRequest = { type: 'request', version: 1,
        operation, sourceId: this.entry.sourceId,
        args: { settingObservations: appSourceSettingObservationStore.snapshotForSource(this.entry.sourceId) },
        settings, hostHints: { network: operation !== 'get_authentication' } }
      const request = sourceRequestWithHostFeatures(JSON.stringify(payload))
      // TaskPool may transfer the buffer. Keep the installed WASM available for the next source operation.
      const wasmBytes = new Uint8Array(this.entry.wasmBytes.byteLength)
      wasmBytes.set(this.entry.wasmBytes)
      // No credential is in requestJson, Worker messages, ordinary settings or a diagnostic record.
      const raw = await executeSourceRequestInWorker(request, wasmBytes, JSON.stringify(context), SourceWorkerPriority.FOREGROUND, current)
      if (!current()) throw new Error('source_login_cancelled')
      const response = JSON.parse(raw) as SourceRuntimeCallResponse
      if (response === null || response.operation !== operation) throw new Error('source_login_invalid_response')
      if (response.ok !== true) throw new SourceRuntimeError(response)
      const data = response.data as Record<string, Object> | undefined
      if (typeof data?.['authenticated'] !== 'boolean') throw new Error('source_login_invalid_response')
      if (operation === 'get_authentication') {
        const descriptor = sourceAuthenticationDescriptor(data?.['authentication'])
        if (descriptor === undefined || descriptor.kind !== this.descriptor.kind) {
          throw new Error('source_login_invalid_response')
        }
        if (descriptor.kind === 'web') {
          if (descriptor.userAgent !== this.descriptor.userAgent) throw new Error('source_login_invalid_response')
          if (!(this.entry.webSessionOrigins ?? []).includes(sourceAuthenticationOrigin(descriptor.loginUrl))) {
            throw new Error('source_login_origin_not_allowed')
          }
        } else {
          // A source may choose only a package-declared destination. All other fields must match.
          const allowed = this.descriptor.loginUrls ?? [this.descriptor.loginUrl]
          if (!allowed.includes(descriptor.loginUrl) ||
            sourceAuthenticationIdentity(descriptor, this.descriptor.loginUrl) !== sourceAuthenticationIdentity(this.descriptor)) {
            throw new Error('source_login_invalid_response')
          }
        }
        this.loginUrl = descriptor.loginUrl
      }
      if (operation === 'authenticate' && data['authenticated'] !== true) throw new Error('source_login_failed')
      if (operation === 'logout' && data['authenticated'] !== false) throw new Error('source_login_failed')
      const authenticated = data['authenticated'] as boolean
      if (this.descriptor.kind === 'credentials') {
        const sessionRevision = this.sessionRevision()
        if (operation === 'get_authentication' && beforeSession !== sessionRevision) {
          throw new Error('source_login_status_changed')
        }
        SourceAuthenticationService.snapshots.set(this.entry.sourceId, { authenticated, loginUrl: this.loginUrl,
          packageIdentity: this.packageIdentity, settingsRevision: this.settingsRevision, sessionRevision, checkedAt: Date.now() })
      }
      return authenticated
    } finally {
      SourcePrivateSessionHost.cancelCredentialGrant(grantId)
      if (this.grantId === grantId) this.grantId = ''
    }
  }
}
