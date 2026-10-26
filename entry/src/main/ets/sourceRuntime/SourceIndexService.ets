import { parseSourceIndexCacheTask, parseSourceIndexDocumentTask, SourceIndexMetadataParseResult } from './SourceIndexMetadataWorker'
import { taskpool } from '@kit.ArkTS'
import {
  SourceIndexEntry, SourceIndexRepository, SourceIndexMetadataCacheRecord, SourceIndexMetadataCacheDocument,
  SOURCE_INDEX_METADATA_RECORD_LIMIT, SOURCE_INDEX_METADATA_CACHE_LIMIT,
  normalizeIndexUrl, resolveIndexDocumentUrl, isValidHttpUrl, normalizeSourceIndexRepository,
  normalizeSourceIndexRepositories, serializeSourceIndexRepositories, safeResolvePkgUrl,
  safeResolveIndexAssetUrl, entryWithCachedIcon, parseCachedIndexEntries,
} from './SourceIndexMetadata'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { isInvalidSourceLocalizedNames, normalizeSourceLocalizedNames } from './SourceLocalizedNames'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileUri } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import {
  installFromBytes,
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

const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'
const SOURCE_INDEX_REPOSITORIES_KEY: string = 'source_index.repositories.v1'
const SOURCE_INDEX_REPOSITORY_LIMIT: number = 12
const SOURCE_INDEX_METADATA_CACHE_KEY: string = 'source_index.metadata_cache.v1'
// Bound only the optional cache, never truncate a successful online index.
const SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME: string = 'source-index-icon-cache'
const SOURCE_INDEX_ICON_CACHE_MAX_BYTES: number = 16 * 1024 * 1024
const SOURCE_INDEX_ICON_FETCH_CONCURRENCY: number = 4

export interface SourceIndexFetchResult {
  ok: boolean
  reasonCode?: string
  entries: SourceIndexEntry[]
}

export interface SourceIndexInstallResult {
  ok: boolean
  reasonCode?: string
  install?: SourcePackageInstallResult
}

@ObservedV2
export class SourcePackageInstallState {
  @Trace phase: 'idle' | 'queued' | 'running' = 'idle'
}

// One process-wide install lane. Other sources remain enqueueable while a
// package is downloading; duplicate taps for one source share the same result.
@ObservedV2
export class SourcePackageInstallTasks {
  @Trace pendingIds: string[] = []
  @Trace runningId: string = ''
  private pending: Map<string, Promise<SourceIndexInstallResult>> = new Map()
  private tail: Promise<void> = Promise.resolve()
  private states: Map<string, SourcePackageInstallState> = new Map()

  stateFor(sourceId: string): SourcePackageInstallState {
    let state = this.states.get(sourceId)
    if (state === undefined) {
      state = new SourcePackageInstallState()
      this.states.set(sourceId, state)
    }
    return state
  }

  run(sourceId: string, work: () => Promise<SourceIndexInstallResult>): Promise<SourceIndexInstallResult> {
    const existing = this.pending.get(sourceId)
    if (existing !== undefined) return existing
    const state = this.stateFor(sourceId)
    state.phase = 'queued'
    this.pendingIds = this.pendingIds.concat(sourceId)
    const result = this.tail.then(async (): Promise<SourceIndexInstallResult> => {
      this.runningId = sourceId
      state.phase = 'running'
      return work()
    }).finally(() => {
      this.pending.delete(sourceId)
      this.pendingIds = this.pendingIds.filter((id: string): boolean => id !== sourceId)
      if (this.runningId === sourceId) this.runningId = ''
      state.phase = 'idle'
    })
    this.pending.set(sourceId, result)
    this.tail = result.then((): void => {}, (): void => {})
    return result
  }
}

export const appSourcePackageInstallTasks: SourcePackageInstallTasks = new SourcePackageInstallTasks()



function sha256Hex(bytes: Uint8Array): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: bytes })
  const digest = md.digestSync().data
  let result = ''
  for (let index = 0; index < digest.length; index += 1) {
    result += digest[index].toString(16).padStart(2, '0')
  }
  return result
}

// Shared across service instances belonging to the same application data store.
const sourceIndexMetadataRequests: Map<string, number> = new Map()
const sourceIndexPreferenceOperations: Map<string, Promise<void>> = new Map()

export class SourceIndexService {
  private context: common.UIAbilityContext
  private iconCacheStore: RemoteImageCacheStore

  constructor(context: common.UIAbilityContext) {
    this.context = context
    this.iconCacheStore = new RemoteImageCacheStore(this.context.cacheDir, SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME)
  }

  private async cachedIconUriFor(indexUrl: string, entry: SourceIndexEntry, allowNetwork: boolean = true): Promise<string> {
    const iconUrl = safeResolveIndexAssetUrl(indexUrl, entry.icon)
    if (iconUrl.length === 0) {
      return ''
    }
    // A release keeps a stable icon filename. Tie the cache identity to the
    // package identity/version so an updated source cannot keep an old logo.
    const cacheKeySeed = `source-index-icon-v1\n${entry.id}\n${entry.version}\n${iconUrl}`
    try {
      const cached = await this.iconCacheStore.get(iconUrl, undefined, cacheKeySeed)
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
      const cachedPath = await this.iconCacheStore.put(iconUrl, undefined, bytes, cacheKeySeed)
      if (!await validateSourcePackageIconFile(cachedPath)) {
        await this.iconCacheStore.clear()
        return ''
      }
      await this.iconCacheStore.evictIfOver(SOURCE_INDEX_ICON_CACHE_MAX_BYTES)
      const retainedPath = await this.iconCacheStore.get(iconUrl, undefined, cacheKeySeed)
      if (retainedPath === undefined || !await validateSourcePackageIconFile(retainedPath)) {
        if (retainedPath !== undefined) {
          await this.iconCacheStore.clear()
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

  private beginMetadataRequest(url: string): number {
    const key = this.metadataRequestKey(url)
    const revision = (sourceIndexMetadataRequests.get(key) ?? 0) + 1
    sourceIndexMetadataRequests.set(key, revision)
    return revision
  }

  // Cache absence/corruption is not a repository/network failure. No user
  // configuration or existing cache is cleared by a failed read.
  async loadCachedIndex(indexUrl: string): Promise<SourceIndexEntry[] | undefined> {
    const url = resolveIndexDocumentUrl(indexUrl)
    if (!isValidHttpUrl(url)) return undefined
    return this.ordered(async (): Promise<SourceIndexEntry[] | undefined> => {
      try {
        const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
        const records = await taskpool.execute(parseSourceIndexCacheTask, await store.get(SOURCE_INDEX_METADATA_CACHE_KEY, '')) as SourceIndexMetadataCacheRecord[]
        return records.find((record: SourceIndexMetadataCacheRecord): boolean => record.url === url)?.entries
      } catch (_error) {
        return undefined
      }
    })
  }

  private async persistIndexMetadata(url: string, revision: number, entries: SourceIndexEntry[]): Promise<void> {
    // Project before yielding so icon callbacks/callers cannot mutate the saved
    // snapshot. A cache too large to retain leaves the old cache untouched.
    const metadata = parseCachedIndexEntries(entries as Object[], url)
    if (metadata === undefined) return
    const record: SourceIndexMetadataCacheRecord = { url, entries: metadata }
    if (JSON.stringify(record).length > SOURCE_INDEX_METADATA_RECORD_LIMIT) return
    try {
      await this.ordered(async (): Promise<void> => {
        await BackupRestoreActivity.runWrite(async (): Promise<void> => {
          const key = this.metadataRequestKey(url)
          if (sourceIndexMetadataRequests.get(key) !== revision) return
          const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
          const previous = await store.get(SOURCE_INDEX_METADATA_CACHE_KEY, '')
          const previousRecords = await taskpool.execute(parseSourceIndexCacheTask, previous) as SourceIndexMetadataCacheRecord[]
          const records = previousRecords.filter((item: SourceIndexMetadataCacheRecord): boolean => item.url !== url)
          records.unshift(record)
          const document: SourceIndexMetadataCacheDocument = { schemaVersion: 1, records: records.slice(0, SOURCE_INDEX_REPOSITORY_LIMIT) }
          let payload = JSON.stringify(document)
          while (payload.length > SOURCE_INDEX_METADATA_CACHE_LIMIT && document.records.length > 1) {
            document.records.pop()
            payload = JSON.stringify(document)
          }
          if (sourceIndexMetadataRequests.get(key) !== revision) return
          try {
            await store.put(SOURCE_INDEX_METADATA_CACHE_KEY, payload)
            await store.flush()
          } catch (_error) {
            // Do not leave an unsuccessful write in the shared Preferences
            // memory cache. This touches only the metadata cache key.
            await store.put(SOURCE_INDEX_METADATA_CACHE_KEY, previous)
            await store.flush()
          }
        })
      })
    } catch (_error) {
      // Optional persistence cannot turn an online success into failure.
    }
  }

  private async savedUrl(store: preferences.Preferences): Promise<string> {
    const url = await store.get(SOURCE_INDEX_URL_KEY, '')
    if (typeof url !== 'string') throw new Error('source_index_preferences_invalid')
    return url.trim()
  }

  private async savedRepositories(store: preferences.Preferences): Promise<SourceIndexRepository[]> {
    const payload = await store.get(SOURCE_INDEX_REPOSITORIES_KEY, '')
    if (typeof payload !== 'string') throw new Error('source_index_preferences_invalid')
    let repositories: SourceIndexRepository[] = []
    if (payload.trim().length > 0) {
      const parsed = JSON.parse(payload) as Object
      if (!Array.isArray(parsed)) throw new Error('source_index_preferences_invalid')
      for (const value of parsed as Object[]) {
        if (normalizeSourceIndexRepository(value) === undefined) throw new Error('source_index_preferences_invalid')
      }
      repositories = normalizeSourceIndexRepositories(parsed as Object[])
    }
    const legacyUrl = normalizeIndexUrl(await this.savedUrl(store))
    if (isValidHttpUrl(legacyUrl) && !repositories.some((item: SourceIndexRepository): boolean => item.url === legacyUrl)) {
      repositories.push({ url: legacyUrl, lastUsedAt: 0 })
    }
    return normalizeSourceIndexRepositories(repositories as Object[])
  }

  async loadSavedUrl(): Promise<string> {
    return this.ordered(async (): Promise<string> => {
      try {
        const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
        return await this.savedUrl(store)
      } catch (_error) {
        throw new Error('source_index_preferences_read_failed')
      }
    })
  }

  async loadSavedRepositories(): Promise<SourceIndexRepository[]> {
    return this.ordered(async (): Promise<SourceIndexRepository[]> => {
      try {
        const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
        return await this.savedRepositories(store)
      } catch (_error) {
        throw new Error('source_index_preferences_read_failed')
      }
    })
  }

  private async commitSavedPreferences(
    store: preferences.Preferences,
    repositories?: SourceIndexRepository[],
    url?: string,
    removeUrl: boolean = false,
  ): Promise<void> {
    const urlExisted = await store.has(SOURCE_INDEX_URL_KEY)
    const previousUrl = await store.get(SOURCE_INDEX_URL_KEY, '')
    const repositoriesExisted = await store.has(SOURCE_INDEX_REPOSITORIES_KEY)
    const previousRepositories = await store.get(SOURCE_INDEX_REPOSITORIES_KEY, '')
    try {
      if (removeUrl) await store.delete(SOURCE_INDEX_URL_KEY)
      else if (url !== undefined) await store.put(SOURCE_INDEX_URL_KEY, url)
      if (repositories !== undefined) {
        await store.put(SOURCE_INDEX_REPOSITORIES_KEY, serializeSourceIndexRepositories(repositories))
      }
      await store.flush()
    } catch (_error) {
      if (urlExisted) await store.put(SOURCE_INDEX_URL_KEY, previousUrl)
      else await store.delete(SOURCE_INDEX_URL_KEY)
      if (repositoriesExisted) await store.put(SOURCE_INDEX_REPOSITORIES_KEY, previousRepositories)
      else await store.delete(SOURCE_INDEX_REPOSITORIES_KEY)
      await store.flush()
      throw new Error('source_index_preferences_commit_failed')
    }
  }

  async saveUrl(url: string): Promise<void> {
    return BackupRestoreActivity.runWrite(async (): Promise<void> => {
      return this.ordered(async (): Promise<void> => {
        try {
          const normalized = normalizeIndexUrl(url)
          const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
          const repositories = await this.savedRepositories(store)
          let next: SourceIndexRepository[] | undefined = undefined
          if (isValidHttpUrl(normalized)) {
            const updated: SourceIndexRepository[] = [{ url: normalized, lastUsedAt: Date.now() }]
            repositories.forEach((repository: SourceIndexRepository) => {
              if (repository.url !== normalized) updated.push(repository)
            })
            next = updated
          }
          await this.commitSavedPreferences(store, next, normalized)
          DiagnosticLogger.info('source_index', 'save_url', '[SourceIndex] step=save_url')
        } catch (_error) {
          throw new Error('source_index_preferences_save_failed')
        }
      })
    })
  }

  async clearUrl(): Promise<void> {
    return BackupRestoreActivity.runWrite(async (): Promise<void> => {
      return this.ordered(async (): Promise<void> => {
        try {
          const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
          await this.commitSavedPreferences(store, undefined, undefined, true)
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
          const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
          const repositories = (await this.savedRepositories(store))
            .filter((repository: SourceIndexRepository): boolean => repository.url !== normalized)
          const activeUrl = normalizeIndexUrl(await this.savedUrl(store))
          const removingActive = activeUrl === normalized
          await this.commitSavedPreferences(store, repositories,
            removingActive && repositories.length > 0 ? repositories[0].url : undefined,
            removingActive && repositories.length === 0)
          return repositories
        } catch (_error) {
          throw new Error('source_index_preferences_remove_failed')
        }
      })
    })
  }

  async fetchIndex(indexUrl: string): Promise<SourceIndexFetchResult> {
    const normalizedUrl = resolveIndexDocumentUrl(indexUrl)
    if (!isValidHttpUrl(normalizedUrl)) {
      return { ok: false, reasonCode: 'invalid_url', entries: [] }
    }

    const cacheRevision = this.beginMetadataRequest(normalizedUrl)
    const httpRequest = http.createHttp()
    try {
      const response = await httpRequest.request(normalizedUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        readTimeout: 30000,
        connectTimeout: 15000,
      })

      if (response.responseCode !== 200) {
        DiagnosticLogger.error('source_index_service', 'fetch_fail', '[SourceIndex] step=fetch_fail status=' + response.responseCode)
        return { ok: false, reasonCode: 'http_error', entries: [] }
      }

      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      const parsed = await taskpool.execute(parseSourceIndexDocumentTask, body, normalizedUrl) as SourceIndexMetadataParseResult
      if (!parsed.ok) return parsed
      const entries = parsed.entries
      DiagnosticLogger.info('source_index', 'fetch_ok', '[SourceIndex] step=fetch_ok count=' + entries.length)
      // Start persistence without awaiting disk IO before publishing metadata.
      this.persistIndexMetadata(normalizedUrl, cacheRevision, entries).catch((): void => {})
      return { ok: true, entries }
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
    let nextIndex = 0
    const worker = async (): Promise<void> => {
      while (isCurrent() && nextIndex < entries.length) {
        const entry = entries[nextIndex++]
        const iconUri = await this.cachedIconUriFor(normalizedUrl, entry, allowNetwork)
        if (!isCurrent()) return
        if (iconUri.length > 0) onIconReady(entryWithCachedIcon(entry, iconUri))
      }
    }
    const workers: Promise<void>[] = []
    for (let index = 0; index < Math.min(SOURCE_INDEX_ICON_FETCH_CONCURRENCY, entries.length); index += 1) {
      workers.push(worker())
    }
    await Promise.all(workers)
  }

  async installPackage(indexUrl: string, entry: SourceIndexEntry): Promise<SourceIndexInstallResult> {
    return appSourcePackageInstallTasks.run(entry.id, () => this.installPackageNow(indexUrl, entry))
  }

  private async installPackageNow(indexUrl: string, entry: SourceIndexEntry): Promise<SourceIndexInstallResult> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexInstallResult> => {
      if (!isSourcePackageMinAppVersionSatisfied(entry.minAppVersion)) {
        DiagnosticLogger.error('source_index_service', 'install_blocked', '[SourceIndex] step=install_blocked reason=app_version_unsupported')
        return { ok: false, reasonCode: 'app_version_unsupported' }
      }

      const pkgUrl = safeResolvePkgUrl(resolveIndexDocumentUrl(indexUrl), entry.pkg)
      if (!isValidHttpUrl(pkgUrl)) {
        return { ok: false, reasonCode: 'invalid_pkg_url' }
      }

      DiagnosticLogger.info('source_index', 'download_pkg', '[SourceIndex] step=download_pkg')

      const httpRequest = http.createHttp()
      try {
        const response = await httpRequest.request(pkgUrl, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingCache: false,
          readTimeout: 60000,
          connectTimeout: 30000,
        })

        if (response.responseCode !== 200) {
          DiagnosticLogger.error('source_index_service', 'download_fail', '[SourceIndex] step=download_fail status=' + response.responseCode)
          return { ok: false, reasonCode: 'http_error' }
        }

        let archiveBytes: Uint8Array
        if (response.result instanceof ArrayBuffer) {
          archiveBytes = new Uint8Array(response.result)
        } else {
          return { ok: false, reasonCode: 'invalid_response' }
        }

        if (archiveBytes.byteLength === 0) {
          return { ok: false, reasonCode: 'empty_package' }
        }
        if (entry.sha256.length > 0 && sha256Hex(archiveBytes) !== entry.sha256) {
          DiagnosticLogger.error('source_index_service', 'download_fail', '[SourceIndex] step=download_fail reason=checksum_mismatch')
          return { ok: false, reasonCode: 'checksum_mismatch' }
        }

        const install = await installFromBytes(this.context, archiveBytes, entry.pkg, entry.id)
        if (!install.ok) {
          DiagnosticLogger.error('source_index_service', 'install_fail', '[SourceIndex] step=install_fail reason=' + (install.reasonCode ?? 'unknown'))
          return { ok: false, reasonCode: install.reasonCode, install }
        }

        DiagnosticLogger.info('source_index', 'install_ok', '[SourceIndex] step=install_ok id=' + install.id)
        return { ok: true, install }
      } catch (error) {
        const e = error as BusinessError
        DiagnosticLogger.error('source_index_service', 'download_error', '[SourceIndex] step=download_error code=' + e.code)
        return { ok: false, reasonCode: 'network_error' }
      } finally {
        httpRequest.destroy()
      }
    })
  }
}
