import { signalDeviceSyncChange, signalDeviceSyncSubscriptionRemoved } from '../deviceSync/DeviceSyncSignals'
import { encodeSourceIndexCacheTask, parseSourceIndexCacheTask, parseSourceIndexDocumentTask,
  prepareSourceIndexCacheRecordTask, SourceIndexMetadataParseResult, writeSourceIndexCacheTask } from './SourceIndexMetadataWorker'
import { assembleSourcePackageBytes, computeSourcePackageSha256 } from './SourcePackageHashWorker'
import { taskpool } from '@kit.ArkTS'
import {
  SourceIndexEntry, SourceIndexRepository, SourceRepositoryMetadata, parseSourceRepositoryMetadata, SourceIndexMetadataCacheRecord,
  normalizeIndexUrl, resolveIndexDocumentUrl, isValidHttpUrl,
  normalizeSourceIndexRepositories, effectiveSourceIndexRepositories, safeResolvePkgUrl,
  safeResolveIndexAssetUrl, entryWithCachedIcon, subscriptionIdentity,
} from './SourceIndexMetadata'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { isInvalidSourceLocalizedNames, normalizeSourceLocalizedNames } from './SourceLocalizedNames'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { applyCloudSubscriptionRemovals, loadSourceSubscriptionPreferences, saveSourceSubscriptionPreferences, SOURCE_INDEX_PREFERENCES,
  SourceSubscriptionPreferences } from './SourceSubscriptionStorage'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import {
  installFromArchive,
  installFromBytes,
  getInstalledSourcePackage,
  isSourcePackageMinAppVersionSatisfied,
  SourcePackageInstallResult,
} from './SourceRuntimeAppRegistry'
import { RemoteImageCacheStore } from '../model/RemoteImageCacheStore'
import {
  SOURCE_REPO_PACKAGE_ICON_MAX_BYTES,
  SOURCE_REPO_PACKAGE_ICON_FILES,
  isValidSourcePackageMinAppVersion,
  normalizeSourceHomepage,
  validateSourcePackageIconBytes,
  validateSourcePackageIconFile,
} from './SourcePackageImporter'
export { SourceIndexEntry, SourceIndexRepository } from './SourceIndexMetadata'

const SOURCE_INDEX_REPOSITORY_LIMIT: number = 12
const SOURCE_PACKAGE_DOWNLOAD_MAX_BYTES: number = 50 * 1024 * 1024
const SOURCE_PACKAGE_READ_TIMEOUT_MS: number = 60000
export interface SourceIndexDeviceSyncSnapshot {
  repositories: SourceIndexRepository[]
  activeUrl: string
}
const SOURCE_INDEX_METADATA_CACHE_KEY: string = 'source_index.metadata_cache.v1'
// Bound only the optional cache, never truncate a successful online index.
const SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME: string = 'source-index-icon-cache'
const SOURCE_INDEX_ICON_CACHE_MAX_BYTES: number = 16 * 1024 * 1024
const SOURCE_INDEX_ICON_FETCH_CONCURRENCY: number = 4

export interface SourceIndexFetchResult {
  ok: boolean
  reasonCode?: string
  entries: SourceIndexEntry[]
  metadata?: SourceRepositoryMetadata
}

export interface SourceIndexInstallResult {
  ok: boolean
  reasonCode?: string
  requiredAppVersion?: string
  install?: SourcePackageInstallResult
  actualEntry?: SourceIndexEntry
  actualIndexUrl?: string
}

@ObservedV2
export class SourcePackageInstallState {
  @Trace phase: 'idle' | 'queued' | 'running' = 'idle'
  @Trace downloadProgress: number = 0
}

interface SourcePackageQueuedTask {
  sourceId: string
  exclusive: boolean
  start: () => void
}

// Two independent online installs may prepare concurrently. Local archives have
// no known source ID until validated, so they remain an exclusive barrier.
// CURRENT_STATUS SOURCE_INSTALL_PIPELINE_SERIAL preserves same-source replacement
// and rollback isolation without serializing unrelated package preparation.
@ObservedV2
export class SourcePackageInstallTasks {
  @Trace pendingIds: string[] = []
  @Trace runningId: string = ''
  private pending: Map<string, Promise<SourceIndexInstallResult>> = new Map()
  private states: Map<string, SourcePackageInstallState> = new Map()
  private queue: SourcePackageQueuedTask[] = []
  private running: string[] = []
  private exclusiveRunning: boolean = false

  stateFor(sourceId: string): SourcePackageInstallState {
    let state = this.states.get(sourceId)
    if (state === undefined) {
      state = new SourcePackageInstallState()
      this.states.set(sourceId, state)
    }
    return state
  }

  private pump(): void {
    while (!this.exclusiveRunning && this.running.length < 2 && this.queue.length > 0) {
      const next = this.queue[0]
      if (next.exclusive && this.running.length > 0) return
      this.queue.shift()
      this.running.push(next.sourceId)
      this.runningId = this.running[0]
      if (next.exclusive) this.exclusiveRunning = true
      next.start()
      if (next.exclusive) return
    }
  }

  run(sourceId: string, work: () => Promise<SourceIndexInstallResult>, retainState: boolean = true,
    exclusive: boolean = false): Promise<SourceIndexInstallResult> {
    const existing = this.pending.get(sourceId)
    if (existing !== undefined) return existing
    const state = this.stateFor(sourceId)
    state.phase = 'queued'
    this.pendingIds = this.pendingIds.concat(sourceId)
    let startTask: () => void = (): void => {}
    const admission = new Promise<void>((resolve: () => void): void => { startTask = resolve })
    const result = admission.then(async (): Promise<SourceIndexInstallResult> => {
      state.phase = 'running'
      return work()
    }).finally(() => {
      this.pending.delete(sourceId)
      this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== sourceId)
      this.running = this.running.filter((id: string): boolean => id !== sourceId)
      this.runningId = this.running.length > 0 ? this.running[0] : ''
      if (exclusive) this.exclusiveRunning = false
      state.downloadProgress = 0
      state.phase = 'idle'
      if (!retainState) this.states.delete(sourceId)
      this.pump()
    })
    this.pending.set(sourceId, result)
    this.queue.push({ sourceId, exclusive, start: startTask })
    this.pump()
    return result
  }
}

export const appSourcePackageInstallTasks: SourcePackageInstallTasks = new SourcePackageInstallTasks()
let localArchiveTaskSequence: number = 0

// Shared across service instances belonging to the same application data store.
const sourceIndexMetadataRequests: Map<string, number> = new Map()
const sourceSubscriptionEpochs: Map<string, number> = new Map()
const disabledSourceSubscriptions: Set<string> = new Set()
const lastSourceDownload: Map<string, string> = new Map()
const sourceIndexPreferenceOperations: Map<string, Promise<void>> = new Map()
const sourceIndexIconStores: Map<string, RemoteImageCacheStore> = new Map()

export class SourceIndexService {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private iconCache(): RemoteImageCacheStore {
    const directory = this.context.cacheDir
    let cache = sourceIndexIconStores.get(directory)
    if (cache === undefined) {
      cache = new RemoteImageCacheStore(directory, SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME, true)
      sourceIndexIconStores.set(directory, cache)
    }
    return cache
  }

  private async cachedIconUriFor(indexUrl: string, entry: SourceIndexEntry, allowNetwork: boolean = true): Promise<string> {
    const iconUrl = safeResolveIndexAssetUrl(indexUrl, entry.icon)
    if (iconUrl.length === 0) {
      return ''
    }
    // A release keeps a stable icon filename. Tie the cache identity to the
    // package identity/version so an updated source cannot keep an old logo.
    const cacheKeySeed = `source-index-icon-v1\n${entry.id}\n${entry.version}\n${iconUrl}`
    const cache = this.iconCache()
    try {
      const cached = await cache.get(iconUrl, undefined, cacheKeySeed)
      if (cached !== undefined && cached.length > 0) {
        if (await validateSourcePackageIconFile(cached)) {
          return fileUri.getUriFromPath(cached)
        }
      }
    } catch (_err) {
    }

    if (!allowNetwork) return ''

    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(iconUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        readTimeout: 15000,
        connectTimeout: 10000,
      })
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
        return ''
      }
      const bytes = response.result as ArrayBuffer
      if (bytes.byteLength === 0 || bytes.byteLength > SOURCE_REPO_PACKAGE_ICON_MAX_BYTES ||
        !validateSourcePackageIconBytes(new Uint8Array(bytes))) {
        return ''
      }
      const cachedPath = await cache.put(iconUrl, undefined, bytes, cacheKeySeed)
      if (!await validateSourcePackageIconFile(cachedPath)) {
        await cache.clear()
        return ''
      }
      await cache.evictIfOver(SOURCE_INDEX_ICON_CACHE_MAX_BYTES)
      const retainedPath = await cache.get(iconUrl, undefined, cacheKeySeed)
      if (retainedPath === undefined || !await validateSourcePackageIconFile(retainedPath)) {
        if (retainedPath !== undefined) {
          await cache.clear()
        }
        return ''
      }
      return fileUri.getUriFromPath(retainedPath)
    } catch (_err) {
      return ''
    } finally {
      httpRequest.destroy()
    }
  }

  private ordered<T>(operation: () => Promise<T>): Promise<T> {
    const key = this.context.filesDir
    const result = (sourceIndexPreferenceOperations.get(key) ?? Promise.resolve()).then(operation)
    sourceIndexPreferenceOperations.set(key, result.then(() => {}, () => {}))
    return result
  }

  private metadataRequestKey(url: string): string {
    return `${this.context.filesDir}\n${url}`
  }

  private subscriptionEpoch(key: string): number {
    return (sourceSubscriptionEpochs.get(this.metadataRequestKey('')) ?? 0) + (sourceSubscriptionEpochs.get(key) ?? 0)
  }

  restoreGuard(): () => void {
    const key = this.metadataRequestKey('')
    const epoch = sourceSubscriptionEpochs.get(key) ?? 0
    return (): void => {
      if (BackupRestoreActivity.isRestoring() || epoch !== (sourceSubscriptionEpochs.get(key) ?? 0)) {
        throw new Error('backup_restore_busy')
      }
    }
  }

  invalidateForBackupRestore(): void {
    const prefix = this.metadataRequestKey('')
    sourceSubscriptionEpochs.set(prefix, (sourceSubscriptionEpochs.get(prefix) ?? 0) + 1)
    sourceIndexMetadataRequests.forEach((revision: number, key: string): void => {
      if (key.startsWith(prefix)) sourceIndexMetadataRequests.set(key, revision + 1)
    })
    lastSourceDownload.forEach((_url: string, key: string): void => {
      if (key.startsWith(prefix)) lastSourceDownload.delete(key)
    })
  }

  async reloadAfterBackupRestore(): Promise<void> {
    this.invalidateForBackupRestore()
    const prefix = this.metadataRequestKey('')
    disabledSourceSubscriptions.forEach((key: string): void => {
      if (key.startsWith(prefix)) disabledSourceSubscriptions.delete(key)
    })
    await this.loadSavedRepositories()
  }

  private retireSubscription(url: string): void {
    const document = resolveIndexDocumentUrl(url)
    this.beginMetadataRequest(document)
    const key = this.metadataRequestKey(document)
    sourceSubscriptionEpochs.set(key, (sourceSubscriptionEpochs.get(key) ?? 0) + 1)
  }

  private rememberSubscriptionState(repository: SourceIndexRepository): void {
    const key = this.metadataRequestKey(resolveIndexDocumentUrl(repository.url))
    if (repository.disabled) disabledSourceSubscriptions.add(key)
    else disabledSourceSubscriptions.delete(key)
  }

  private beginMetadataRequest(url: string): number {
    const key = this.metadataRequestKey(url)
    const revision = (sourceIndexMetadataRequests.get(key) ?? 0) + 1
    sourceIndexMetadataRequests.set(key, revision)
    return revision
  }

  // Cache absence/corruption is not a repository/network failure. No user
  // configuration or existing cache is cleared by a failed read.
  private metadataCachePath(): string { return this.context.cacheDir + '/source-index-metadata.v1.json' }

  private async readMetadataCache(): Promise<string> {
    const path = this.metadataCachePath()
    if (await fs.access(path)) return fs.readText(path)
    const legacy = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFERENCES)
    const payload = await legacy.get(SOURCE_INDEX_METADATA_CACHE_KEY, '')
    if (typeof payload !== 'string' || payload.length === 0) return ''
    try {
      await taskpool.execute(writeSourceIndexCacheTask, path, payload)
      await legacy.delete(SOURCE_INDEX_METADATA_CACHE_KEY)
      await legacy.flush()
    } catch (_error) {
      // Cache migration is optional and the legacy read can still serve this request.
    }
    return payload
  }

  async loadCachedIndex(indexUrl: string): Promise<SourceIndexEntry[] | undefined> {
    const url = resolveIndexDocumentUrl(indexUrl)
    if (!isValidHttpUrl(url)) return undefined
    return this.ordered(async (): Promise<SourceIndexEntry[] | undefined> => {
      try {
        const records = await taskpool.execute(parseSourceIndexCacheTask, await this.readMetadataCache()) as SourceIndexMetadataCacheRecord[]
        return records.find((record: SourceIndexMetadataCacheRecord): boolean => record.url === url)?.entries
      } catch (_error) {
        return undefined
      }
    })
  }

  private async persistIndexMetadata(url: string, revision: number, entries: SourceIndexEntry[]): Promise<void> {
    // Project before yielding so icon callbacks/callers cannot mutate the saved
    // snapshot. A cache too large to retain leaves the old cache untouched.
    const record = await taskpool.execute(prepareSourceIndexCacheRecordTask, url, entries) as SourceIndexMetadataCacheRecord | undefined
    if (record === undefined) return
    try {
      await BackupRestoreActivity.runWrite(async (): Promise<void> => {
        await this.ordered(async (): Promise<void> => {
          const key = this.metadataRequestKey(url)
          if (sourceIndexMetadataRequests.get(key) !== revision) return
          const previous = await this.readMetadataCache()
          const payload = await taskpool.execute(encodeSourceIndexCacheTask, previous, record, SOURCE_INDEX_REPOSITORY_LIMIT) as string
          if (sourceIndexMetadataRequests.get(key) !== revision) return
          await taskpool.execute(writeSourceIndexCacheTask, this.metadataCachePath(), payload)
        })
      })
    } catch (_error) {
      // Optional persistence cannot turn an online success into failure.
    }
  }

  private savedRepositories(saved: SourceSubscriptionPreferences): SourceIndexRepository[] {
    const normalized = effectiveSourceIndexRepositories(saved.repositories ?? [], saved.url ?? '')
    normalized.forEach((item: SourceIndexRepository): void => this.rememberSubscriptionState(item))
    return normalized
  }

  async loadSavedUrl(): Promise<string> {
    return this.ordered(async (): Promise<string> => {
      try {
        return (await loadSourceSubscriptionPreferences(this.context)).url?.trim() ?? ''
      } catch (_error) {
        throw new Error('source_index_preferences_read_failed')
      }
    })
  }

  async loadSavedRepositories(): Promise<SourceIndexRepository[]> {
    return this.ordered(async (): Promise<SourceIndexRepository[]> => {
      try {
        return this.savedRepositories(await loadSourceSubscriptionPreferences(this.context))
      } catch (_error) {
        throw new Error('source_index_preferences_read_failed')
      }
    })
  }

  private async commitSavedPreferences(
    repositories?: SourceIndexRepository[],
    url?: string,
    removeUrl: boolean = false,
    notifySync: boolean = true,
  ): Promise<void> {
    try {
      await saveSourceSubscriptionPreferences(this.context, { repositories, url: removeUrl ? undefined : url },
        removeUrl || url !== undefined, repositories !== undefined)
      if (repositories !== undefined && notifySync) signalDeviceSyncChange('source-subscriptions')
    } catch (_error) {
      throw new Error('source_index_preferences_commit_failed')
    }
  }

  async captureDeviceSyncSnapshot(): Promise<SourceIndexDeviceSyncSnapshot> {
    return this.ordered(async (): Promise<SourceIndexDeviceSyncSnapshot> => {
      const stored = await loadSourceSubscriptionPreferences(this.context)
      return { repositories: this.savedRepositories(stored), activeUrl: stored.url?.trim() ?? '' }
    })
  }

  // Called by the local sync transaction and its crash recovery. It doesn't
  // fetch a catalog, install a package, or publish a remote change as local.
  async applyDeviceSyncSnapshot(snapshot: SourceIndexDeviceSyncSnapshot): Promise<void> {
    await this.ordered(async (): Promise<void> => {
      const stored = await loadSourceSubscriptionPreferences(this.context)
      const before = this.savedRepositories(stored)
      await this.commitSavedPreferences(snapshot.repositories, snapshot.activeUrl || undefined,
        snapshot.activeUrl === '', false)
      before.forEach((repo: SourceIndexRepository): void => {
        if (!snapshot.repositories.some((saved: SourceIndexRepository): boolean => saved.url === repo.url)) {
          this.retireSubscription(repo.url)
        }
      })
      snapshot.repositories.forEach((repo: SourceIndexRepository): void => this.rememberSubscriptionState(repo))
    })
  }

  async applyCloudRemovals(addresses: Set<string>): Promise<void> {
    if (addresses.size === 0) return
    await this.ordered(async (): Promise<void> => {
      const removed = await applyCloudSubscriptionRemovals(this.context, addresses)
      removed.forEach((url: string): void => { this.retireSubscription(url) })
    })
  }

  async saveUrl(url: string): Promise<void> {
    return BackupRestoreActivity.runWrite(async (): Promise<void> => {
      return this.ordered(async (): Promise<void> => {
        try {
          const normalized = normalizeIndexUrl(url)
          const stored = await loadSourceSubscriptionPreferences(this.context)
          const repositories = this.savedRepositories(stored)
          let next: SourceIndexRepository[] | undefined = undefined
          if (isValidHttpUrl(normalized)) {
            const saved = repositories.find((item: SourceIndexRepository): boolean => item.url === normalized)
            const updated: SourceIndexRepository[] = [{ url: normalized, lastUsedAt: Date.now(),
              disabled: saved?.disabled, customName: saved?.customName, name: saved?.name, website: saved?.website }]
            repositories.forEach((repository: SourceIndexRepository) => {
              if (repository.url !== normalized) updated.push(repository)
            })
            next = updated
          }
          await this.commitSavedPreferences(next, normalized)
          DiagnosticLogger.info('source_index', 'save_url', '[SourceIndex] step=save_url')
        } catch (_error) {
          throw new Error('source_index_preferences_save_failed')
        }
      })
    })
  }

  // Same-directory, optional repository metadata (Mihon-style field names).
  // It cannot change catalog/package provenance and never blocks installation.
  async fetchRepositoryMetadata(indexUrl: string): Promise<SourceRepositoryMetadata | undefined> {
    const current = this.restoreGuard()
    current()
    const documentUrl = resolveIndexDocumentUrl(indexUrl)
    if (!isValidHttpUrl(documentUrl) || disabledSourceSubscriptions.has(this.metadataRequestKey(documentUrl))) return undefined
    const request = http.createHttp()
    try {
      const response = await request.request(documentUrl.substring(0, documentUrl.lastIndexOf('/') + 1) + 'repo.json', {
        method: http.RequestMethod.GET, expectDataType: http.HttpDataType.STRING,
        usingCache: false, readTimeout: 5000, connectTimeout: 5000,
      })
      current()
      if (response.responseCode !== 200) return undefined
      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      if (body.length > 16384) return undefined
      return parseSourceRepositoryMetadata(JSON.parse(body) as Object)
    } catch (_error) { current(); return undefined } finally { request.destroy() }
  }

  async saveRepository(url: string, customName: string, metadata?: SourceRepositoryMetadata,
    previousUrl?: string): Promise<SourceIndexRepository[]> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexRepository[]> => this.ordered(async (): Promise<SourceIndexRepository[]> => {
      const normalized = normalizeIndexUrl(url)
      const previous = previousUrl === undefined ? undefined : normalizeIndexUrl(previousUrl)
      if (!isValidHttpUrl(normalized)) throw new Error('invalid_url')
      const stored = await loadSourceSubscriptionPreferences(this.context)
      const repositories = this.savedRepositories(stored)
      const original = previous === undefined ? undefined : repositories.find((item: SourceIndexRepository): boolean => item.url === previous)
      if (previous !== undefined && original === undefined) throw new Error('repository_removed')
      if (repositories.some((item: SourceIndexRepository): boolean => item.url !== previous &&
        resolveIndexDocumentUrl(item.url) === resolveIndexDocumentUrl(normalized))) throw new Error('repository_exists')
      const sameDocument = original !== undefined && resolveIndexDocumentUrl(original.url) === resolveIndexDocumentUrl(normalized)
      const repository: SourceIndexRepository = { url: normalized, lastUsedAt: original?.lastUsedAt ?? Date.now(),
        disabled: original?.disabled,
        customName: customName.trim().slice(0, 120) || undefined,
        name: metadata !== undefined ? metadata.name : (sameDocument ? original?.name : undefined),
        website: metadata !== undefined ? metadata.website : (sameDocument ? original?.website : undefined) }
      const next = original === undefined ? repositories.concat(repository) : repositories.map((item: SourceIndexRepository): SourceIndexRepository =>
        item.url === previous ? repository : item)
      const active = normalizeIndexUrl(stored.url?.trim() ?? '')
      await this.commitSavedPreferences(next, previous === undefined || active === previous ? normalized : undefined)
      this.rememberSubscriptionState(repository)
      if (previous !== undefined && !sameDocument) this.retireSubscription(previous)
      if (previous !== undefined && !next.some((item: SourceIndexRepository): boolean =>
        subscriptionIdentity(item.url) === subscriptionIdentity(previous))) signalDeviceSyncSubscriptionRemoved(previous)
      return next
    }))
  }

  async refreshRepositoryMetadata(repository: SourceIndexRepository): Promise<void> {
    if (repository.disabled) return
    const current = this.restoreGuard()
    const metadata = await this.fetchRepositoryMetadata(repository.url)
    current()
    if (metadata === undefined) return
    await BackupRestoreActivity.runWrite(async (): Promise<void> => this.ordered(async (): Promise<void> => {
      current()
      const stored = await loadSourceSubscriptionPreferences(this.context)
      const saved = this.savedRepositories(stored)
      const next = saved.map((item: SourceIndexRepository): SourceIndexRepository => item.url !== repository.url || item.disabled ? item : {
        url: item.url, lastUsedAt: item.lastUsedAt, customName: item.customName,
        name: metadata.name, website: metadata.website,
      })
      if (JSON.stringify(next) !== JSON.stringify(saved)) await this.commitSavedPreferences(next)
    }))
  }

  async setSubscriptionDisabled(url: string, disabled: boolean): Promise<SourceIndexRepository[]> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexRepository[]> => this.ordered(async (): Promise<SourceIndexRepository[]> => {
      const stored = await loadSourceSubscriptionPreferences(this.context)
      const saved = this.savedRepositories(stored)
      const item = saved.find((repository: SourceIndexRepository): boolean => repository.url === url)
      if (item === undefined) throw new Error('repository_removed')
      item.disabled = disabled || undefined
      await this.commitSavedPreferences(saved)
      this.rememberSubscriptionState(item)
      this.retireSubscription(url)
      return saved
    }))
  }

  async clearUrl(): Promise<void> {
    return BackupRestoreActivity.runWrite(async (): Promise<void> => {
      return this.ordered(async (): Promise<void> => {
        try {
          await this.commitSavedPreferences(undefined, undefined, true)
        } catch (_error) {
          throw new Error('source_index_preferences_clear_failed')
        }
      })
    })
  }

  async removeSavedRepository(url: string): Promise<SourceIndexRepository[]> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexRepository[]> => {
      return this.ordered(async (): Promise<SourceIndexRepository[]> => {
        try {
          const normalized = normalizeIndexUrl(url)
          const stored = await loadSourceSubscriptionPreferences(this.context)
          const repositories = this.savedRepositories(stored)
            .filter((repository: SourceIndexRepository): boolean => repository.url !== normalized)
          const activeUrl = normalizeIndexUrl(stored.url?.trim() ?? '')
          const removingActive = activeUrl === normalized
          await this.commitSavedPreferences(repositories,
            removingActive && repositories.length > 0 ? repositories[0].url : undefined,
            removingActive && repositories.length === 0)
          this.retireSubscription(normalized)
          if (!repositories.some((item: SourceIndexRepository): boolean =>
            subscriptionIdentity(item.url) === subscriptionIdentity(normalized))) signalDeviceSyncSubscriptionRemoved(normalized)
          return repositories
        } catch (_error) {
          throw new Error('source_index_preferences_remove_failed')
        }
      })
    })
  }

  async fetchIndex(indexUrl: string, prefetchedBody?: string): Promise<SourceIndexFetchResult> {
    if (BackupRestoreActivity.isRestoring()) return { ok: false, reasonCode: 'subscription_unavailable', entries: [] }
    const normalizedUrl = resolveIndexDocumentUrl(indexUrl)
    if (!isValidHttpUrl(normalizedUrl)) {
      return { ok: false, reasonCode: 'invalid_url', entries: [] }
    }

    const key = this.metadataRequestKey(normalizedUrl)
    const epoch = this.subscriptionEpoch(key)
    if (prefetchedBody === undefined && disabledSourceSubscriptions.has(key))
      return { ok: false, reasonCode: 'subscription_unavailable', entries: [] }
    const cacheRevision = this.beginMetadataRequest(normalizedUrl)
    const httpRequest = http.createHttp()
    try {
      const response = prefetchedBody === undefined ? await httpRequest.request(normalizedUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        readTimeout: 30000,
        connectTimeout: 15000,
      }) : undefined

      if (response !== undefined && response.responseCode !== 200) {
        DiagnosticLogger.error('source_index_service', 'fetch_fail', '[SourceIndex] step=fetch_fail status=' + response.responseCode)
        return { ok: false, reasonCode: 'http_error', entries: [] }
      }

      const body = prefetchedBody ?? (typeof response!.result === 'string' ? response!.result : JSON.stringify(response!.result))
      const parsed = await taskpool.execute(parseSourceIndexDocumentTask, body, normalizedUrl) as SourceIndexMetadataParseResult
      if (epoch !== this.subscriptionEpoch(key) || BackupRestoreActivity.isRestoring())
        return { ok: false, reasonCode: 'subscription_unavailable', entries: [] }
      if (!parsed.ok) return parsed
      const entries = parsed.entries
      DiagnosticLogger.info('source_index', 'fetch_ok', '[SourceIndex] step=fetch_ok count=' + entries.length)
      // Start persistence without awaiting disk IO before publishing metadata.
      this.persistIndexMetadata(normalizedUrl, cacheRevision, entries).catch((): void => {})
      return { ok: true, entries, metadata: parsed.metadata }
    } catch (error) {
      const e = error as BusinessError
      DiagnosticLogger.error('source_index_service', 'fetch_error', '[SourceIndex] step=fetch_error code=' + e.code)
      return { ok: false, reasonCode: 'network_error', entries: [] }
    } finally {
      httpRequest.destroy()
    }
  }

  async loadIndexIcons(
    indexUrl: string,
    entries: SourceIndexEntry[],
    onIconReady: (entry: SourceIndexEntry) => void,
    isCurrent: () => boolean,
    allowNetwork: boolean = true,
  ): Promise<void> {
    const normalizedUrl = resolveIndexDocumentUrl(indexUrl)
    const key = this.metadataRequestKey(normalizedUrl)
    if (disabledSourceSubscriptions.has(key)) return
    const epoch = this.subscriptionEpoch(key)
    let nextIndex = 0
    const worker = async (): Promise<void> => {
      while (isCurrent() && epoch === this.subscriptionEpoch(key) && !BackupRestoreActivity.isRestoring() && nextIndex < entries.length) {
        const entry = entries[nextIndex++]
        const iconUri = await this.cachedIconUriFor(normalizedUrl, entry, allowNetwork)
        if (!isCurrent() || epoch !== this.subscriptionEpoch(key) || BackupRestoreActivity.isRestoring()) return
        if (iconUri.length > 0) onIconReady(entryWithCachedIcon(entry, iconUri))
      }
    }
    const workers: Promise<void>[] = []
    for (let index = 0; index < Math.min(SOURCE_INDEX_ICON_FETCH_CONCURRENCY, entries.length); index += 1) {
      workers.push(worker())
    }
    await Promise.all(workers)
  }

  async installPackage(indexUrl: string, entry: SourceIndexEntry, requireSaved: boolean = false): Promise<SourceIndexInstallResult> {
    return appSourcePackageInstallTasks.run(entry.id, () => this.installPackageNow(indexUrl, entry, requireSaved))
  }

  async installLocalArchive(uri: string, expectedSourceId?: string,
    isCurrent?: () => boolean): Promise<SourcePackageInstallResult> {
    // The archive's source ID is unknown until validation. Give this request a
    // private identity without a file URI; run it as an exclusive barrier so
    // it cannot race an online installation of the same source.
    const taskId = 'local-archive:' + (++localArchiveTaskSequence)
    const result = await appSourcePackageInstallTasks.run(taskId, async (): Promise<SourceIndexInstallResult> => {
      if (isCurrent !== undefined && !isCurrent()) return { ok: false, reasonCode: 'import_canceled' }
      const install = await installFromArchive(this.context, uri, expectedSourceId, isCurrent)
      return { ok: install.ok, reasonCode: install.reasonCode, install }
    }, false, true)
    return result.install ?? { ok: false, reasonCode: result.reasonCode ?? 'import_failed' }
  }

  private async installPackageNow(indexUrl: string, entry: SourceIndexEntry, requireSaved: boolean): Promise<SourceIndexInstallResult> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexInstallResult> => {
      if (!isSourcePackageMinAppVersionSatisfied(entry.minAppVersion)) {
        DiagnosticLogger.error('source_index_service', 'install_blocked', '[SourceIndex] step=install_blocked reason=app_version_unsupported')
        return { ok: false, reasonCode: 'app_version_unsupported', requiredAppVersion: entry.minAppVersion }
      }

      const document = resolveIndexDocumentUrl(indexUrl)
      const identity = subscriptionIdentity(document)
      // A stale or unavailable old subscription cache must never block an
      // update from the user's selected, enabled subscription.
      const preserveSessionOnUpdate = requireSaved && getInstalledSourcePackage(entry.id) !== undefined
      const routeKey = this.metadataRequestKey(identity)
      const selectionKey = this.metadataRequestKey(document)
      const selectionEpoch = this.subscriptionEpoch(selectionKey)
      const selectionCurrent = (): boolean => selectionEpoch === this.subscriptionEpoch(selectionKey) &&
        !BackupRestoreActivity.isRestoring()
      const saved = await this.loadSavedRepositories()
      const primary = saved.find((item: SourceIndexRepository): boolean => resolveIndexDocumentUrl(item.url) === document)
      const routes: SourceIndexMetadataCacheRecord[] = []
      if (primary?.disabled !== true && (!requireSaved || primary !== undefined)) routes.push({ url: document, entries: [entry] })
      // The pinned complete archive digest makes another saved endpoint safe
      // to try. A same-ID release without a digest cannot substitute bytes.
      if (entry.sha256.length > 0) {
        for (const item of saved) {
          const url = resolveIndexDocumentUrl(item.url)
          if (item.disabled || url === document || subscriptionIdentity(url) !== identity) continue
          const cached = await this.loadCachedIndex(url)
          const equivalent = cached?.find((offer: SourceIndexEntry): boolean =>
            offer.id === entry.id && offer.version === entry.version && offer.sha256 === entry.sha256)
          if (equivalent !== undefined) routes.push({ url, entries: [equivalent] })
        }
      }
      const recent = lastSourceDownload.get(routeKey)
      if (recent !== undefined) routes.sort((a: SourceIndexMetadataCacheRecord, b: SourceIndexMetadataCacheRecord): number =>
        Number(b.url === recent) - Number(a.url === recent))
      let result: SourceIndexInstallResult = { ok: false, reasonCode: 'subscription_unavailable' }
      let refreshAllowed = false
      for (const route of routes) {
        const key = this.metadataRequestKey(route.url)
        const epoch = this.subscriptionEpoch(key)
        const current = (): boolean => epoch === this.subscriptionEpoch(key) && !BackupRestoreActivity.isRestoring()
        if (requireSaved) {
          const live = (await this.loadSavedRepositories()).find((item: SourceIndexRepository): boolean =>
            resolveIndexDocumentUrl(item.url) === route.url)
          if (live === undefined || live.disabled || !current()) continue
        }
        result = await this.downloadAndInstall(route.url, route.entries[0], current, preserveSessionOnUpdate)
        if (result.ok) {
          lastSourceDownload.set(routeKey, route.url)
          return result
        }
        if (result.install !== undefined) return result
        // Both layers use checksum_mismatch. An importer result means archive
        // validation/installation already began: never recover an inner WASM or
        // image-processor rejection by fetching a different package.
        const downloadFailure = result.install === undefined &&
          (result.reasonCode === 'checksum_mismatch' || result.reasonCode === 'http_error')
        if (downloadFailure) refreshAllowed = true
        if (result.reasonCode !== 'http_error' && result.reasonCode !== 'network_error' &&
          result.reasonCode !== 'subscription_unavailable' && !downloadFailure) return result
      }
      if (refreshAllowed && selectionCurrent()) {
        result = await this.recoverChangedPackage(document, entry, result, selectionCurrent, preserveSessionOnUpdate)
        if (result.ok) lastSourceDownload.set(routeKey, document)
      }
      return result
    })
  }

  private recoveryVersionAtLeast(candidate: string, baseline: string): boolean {
    // Recovery must not turn parseInt's partial/locale comparisons into consent
    // to install an invalid or older version. Keep ordinary legacy installs as-is.
    const numeric = /^(0|[1-9][0-9]{0,8})(\.(0|[1-9][0-9]{0,8})){0,3}$/
    if (!numeric.test(candidate) || !numeric.test(baseline)) return false
    const left = candidate.split('.')
    const right = baseline.split('.')
    for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
      const order = Number(left[index] ?? '0') - Number(right[index] ?? '0')
      if (order !== 0) return order > 0
    }
    return true
  }

  private async recoverChangedPackage(indexUrl: string, selected: SourceIndexEntry, original: SourceIndexInstallResult,
    isCurrent: () => boolean, preserveSessionOnUpdate: boolean): Promise<SourceIndexInstallResult> {
    // #346, user counterexample (2026-11-23): an old latest index pins the old ZIP,
    // while the same filename/version (90漫画/肉漫 among 91 entries) now serves
    // a repacked ZIP. Try verified same-digest mirrors first, then refresh only
    // the selected enabled subscription once. Never trust downloaded bytes to
    // replace the expected digest, or recursively enter the same-source queue.
    const enabled = async (): Promise<boolean> => {
      if (!isCurrent()) return false
      const saved = await this.loadSavedRepositories()
      return isCurrent() && saved.some((item: SourceIndexRepository): boolean =>
        resolveIndexDocumentUrl(item.url) === indexUrl && !item.disabled)
    }
    let refreshed: SourceIndexFetchResult
    try {
      if (!await enabled()) return original
      refreshed = await this.fetchIndex(indexUrl)
      if (!await enabled()) return { ok: false, reasonCode: 'subscription_unavailable' }
    } catch (_error) { return original }
    if (!refreshed.ok) return original
    const matches = refreshed.entries.filter((item: SourceIndexEntry): boolean => item.id === selected.id)
    if (matches.length !== 1) return original
    const fresh = matches[0]
    const installedVersion = getInstalledSourcePackage(selected.id)?.version
    if (!/^[0-9a-f]{64}$/.test(fresh.sha256) || !this.recoveryVersionAtLeast(fresh.version, selected.version) ||
      (installedVersion !== undefined && !this.recoveryVersionAtLeast(fresh.version, installedVersion)) ||
      !isValidHttpUrl(safeResolvePkgUrl(indexUrl, fresh.pkg)) ||
      (fresh.version === selected.version && fresh.pkg === selected.pkg && fresh.sha256 === selected.sha256)) return original
    const actualEntry = entryWithCachedIcon(fresh, fresh.iconUri ?? '')
    actualEntry.repositoryUrl = indexUrl
    if (!isSourcePackageMinAppVersionSatisfied(fresh.minAppVersion)) {
      return { ok: false, reasonCode: 'app_version_unsupported', requiredAppVersion: fresh.minAppVersion,
        actualEntry, actualIndexUrl: indexUrl }
    }
    DiagnosticLogger.info('source_index', 'install_metadata_recovery', '[SourceIndex] step=install_metadata_recovery')
    const result = await this.downloadAndInstall(indexUrl, actualEntry, isCurrent, preserveSessionOnUpdate)
    return { ok: result.ok, reasonCode: result.reasonCode, requiredAppVersion: result.requiredAppVersion,
      install: result.install, actualEntry, actualIndexUrl: indexUrl }
  }

  private async downloadAndInstall(indexUrl: string, entry: SourceIndexEntry,
    isCurrent: () => boolean, preserveSessionOnUpdate: boolean): Promise<SourceIndexInstallResult> {
    const pkgUrl = safeResolvePkgUrl(indexUrl, entry.pkg)
    if (!isValidHttpUrl(pkgUrl)) {
      return { ok: false, reasonCode: 'invalid_pkg_url' }
    }

    DiagnosticLogger.info('source_index', 'download_pkg', '[SourceIndex] step=download_pkg')

    const httpRequest = http.createHttp()
    const state = appSourcePackageInstallTasks.stateFor(entry.id)
    state.downloadProgress = 0
    const chunks: ArrayBuffer[] = []
    let received = 0
    let lastProgressAt = 0
    let waitingForEnd = false
    let failureReason = 'network_error'
    let endTimer = -1
    let finishStream: () => void = (): void => {}
    let failStream: (error: Error) => void = (_error: Error): void => {}
    const ended = new Promise<void>((resolve) => { finishStream = resolve })
    const failure = new Promise<never>((_resolve, reject) => { failStream = reject })
    const armEndTimeout = (): void => {
      if (endTimer >= 0) clearTimeout(endTimer)
      endTimer = setTimeout((): void => { failStream(new Error('source_package_download_timeout')) },
        SOURCE_PACKAGE_READ_TIMEOUT_MS)
    }
    try {
      httpRequest.on('dataReceive', (chunk: ArrayBuffer): void => {
        if (received + chunk.byteLength > SOURCE_PACKAGE_DOWNLOAD_MAX_BYTES) {
          failStream(new Error('source_package_download_too_large'))
          return
        }
        chunks.push(chunk)
        received += chunk.byteLength
        if (waitingForEnd) armEndTimeout()
      })
      httpRequest.on('dataEnd', finishStream)
      httpRequest.on('dataReceiveProgress', (info: http.DataReceiveProgressInfo): void => {
        if (info === undefined || info.totalSize <= 0 || !isCurrent()) return
        const percent = Math.floor(100 * info.receiveSize / info.totalSize)
        const now = Date.now()
        if (!Number.isFinite(percent) || percent <= state.downloadProgress || percent >= 100 ||
          now - lastProgressAt < 100) return
        state.downloadProgress = percent
        lastProgressAt = now
      })
      const status = await Promise.race([httpRequest.requestInStream(pkgUrl, {
        method: http.RequestMethod.GET,
        usingCache: false,
        readTimeout: SOURCE_PACKAGE_READ_TIMEOUT_MS,
        connectTimeout: 30000,
      }), failure])

      if (status !== 200) {
        DiagnosticLogger.error('source_index_service', 'download_fail', '[SourceIndex] step=download_fail status=' + status)
        return { ok: false, reasonCode: 'http_error' }
      }

      waitingForEnd = true
      armEndTimeout()
      await Promise.race([ended, failure])
      waitingForEnd = false
      clearTimeout(endTimer)
      failureReason = 'invalid_response'
      if (received === 0) {
        return { ok: false, reasonCode: 'empty_package' }
      }
      // A full bar belongs to a completed download. Validation and install
      // still run before the queue marks this source idle.
      state.downloadProgress = 100
      const archiveBytes = chunks.length === 1 ? new Uint8Array(chunks[0])
        : await taskpool.execute(assembleSourcePackageBytes, chunks, received) as Uint8Array
      chunks.length = 0
      if (entry.sha256.length > 0) {
        failureReason = 'validation_failed'
        // Keep the downloaded bytes owned by the installer while TaskPool hashes
        // its copy; a failed or incomplete digest must never publish the package.
        const hashBytes = new Uint8Array(archiveBytes.byteLength)
        hashBytes.set(archiveBytes)
        const digest = await taskpool.execute(computeSourcePackageSha256, hashBytes) as string
        if (digest !== entry.sha256) {
          DiagnosticLogger.error('source_index_service', 'download_fail', '[SourceIndex] step=download_fail reason=checksum_mismatch')
          return { ok: false, reasonCode: 'checksum_mismatch' }
        }
      }

      if (!isCurrent()) return { ok: false, reasonCode: 'subscription_unavailable' }
      failureReason = 'import_failed'
      const install = await installFromBytes(this.context, archiveBytes, entry.pkg, entry.id, indexUrl, isCurrent, preserveSessionOnUpdate)
      if (!install.ok) {
        DiagnosticLogger.error('source_index_service', 'install_fail', '[SourceIndex] step=install_fail reason=' + (install.reasonCode ?? 'unknown'))
        // After download the validated archive can require a newer App than the index advertises.
        return { ok: false, reasonCode: install.reasonCode, requiredAppVersion: install.requiredAppVersion, install }
      }

      DiagnosticLogger.info('source_index', 'install_ok', '[SourceIndex] step=install_ok id=' + install.id)
      return { ok: true, install }
    } catch (error) {
      const e = error as BusinessError
      if (e.message === 'source_package_download_timeout') failureReason = 'download_timeout'
      if (e.message === 'source_package_download_too_large') failureReason = 'package_too_large'
      DiagnosticLogger.error('source_index_service', 'install_error', '[SourceIndex] step=install_error reason=' + failureReason + ' code=' + e.code)
      return { ok: false, reasonCode: failureReason }
    } finally {
      if (endTimer >= 0) clearTimeout(endTimer)
      try { httpRequest.destroy() } catch (_error) {}
    }
  }
}
