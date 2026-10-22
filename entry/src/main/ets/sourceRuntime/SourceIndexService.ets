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
  validateSourcePackageIconBytes,
  validateSourcePackageIconFile,
} from './SourcePackageImporter'

const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'
const SOURCE_INDEX_REPOSITORIES_KEY: string = 'source_index.repositories.v1'
const SOURCE_INDEX_REPOSITORY_LIMIT: number = 12
const SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME: string = 'source-index-icon-cache'
const SOURCE_INDEX_ICON_CACHE_MAX_BYTES: number = 16 * 1024 * 1024
const SOURCE_INDEX_ICON_FETCH_CONCURRENCY: number = 4

interface SourceIndexHttpUrl {
  origin: string
  path: string
}

export interface SourceIndexEntry {
  id: string
  name: string
  localizedNames?: Record<string, string>
  version: string
  lang: string
  nsfw: boolean
  author: string
  description: string
  contentRating: string
  pkg: string
  sha256: string
  icon: string
  iconUri?: string
  minAppVersion: string
}

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

export interface SourceIndexRepository {
  url: string
  lastUsedAt: number
}

function normalizeSourceIndexPath(value: string): string | undefined {
  if (value.length === 0) {
    return '/'
  }
  if (!value.startsWith('/') || value.includes('\\') || value.includes('%') || value.includes('?') || value.includes('#')) {
    return undefined
  }
  const segments = value.split('/')
  for (let index = 1; index < segments.length; index += 1) {
    const segment = segments[index]
    if (segment.length === 0) {
      if (index === segments.length - 1) {
        continue
      }
      return undefined
    }
    if (segment === '.' || segment === '..' || !/^[A-Za-z0-9._~-]+$/.test(segment)) {
      return undefined
    }
  }
  return value
}

function parseSourceIndexHttpUrl(value: string): SourceIndexHttpUrl | undefined {
  const normalized = value.trim()
  const protocolEnd = normalized.indexOf('://')
  if (protocolEnd <= 0 || normalized.includes('?') || normalized.includes('#')) {
    return undefined
  }
  const scheme = normalized.substring(0, protocolEnd).toLowerCase()
  if (scheme !== 'http' && scheme !== 'https') {
    return undefined
  }
  const afterProtocol = normalized.substring(protocolEnd + 3)
  const slashIndex = afterProtocol.indexOf('/')
  const authority = slashIndex < 0 ? afterProtocol : afterProtocol.substring(0, slashIndex)
  if (authority.length === 0 || authority.includes('@') || authority.includes('\\') || /\s/.test(authority)) {
    return undefined
  }
  const path = normalizeSourceIndexPath(slashIndex < 0 ? '/' : afterProtocol.substring(slashIndex))
  if (path === undefined) {
    return undefined
  }
  return {
    origin: `${scheme}://${authority.toLowerCase()}`,
    path,
  }
}

function isValidHttpUrl(value: string): boolean {
  return parseSourceIndexHttpUrl(value) !== undefined
}

function normalizeIndexUrl(value: string): string {
  const parsed = parseSourceIndexHttpUrl(value)
  if (parsed === undefined) {
    return value.trim()
  }
  if (parsed.path === '/') {
    return parsed.origin
  }
  const path = parsed.path.endsWith('/') ? parsed.path.substring(0, parsed.path.length - 1) : parsed.path
  return `${parsed.origin}${path}`
}

function resolveIndexDocumentUrl(value: string): string {
  const parsed = parseSourceIndexHttpUrl(value)
  if (parsed === undefined) {
    return ''
  }
  if (parsed.path.endsWith('.json')) {
    return `${parsed.origin}${parsed.path}`
  }
  const directory = parsed.path.endsWith('/') ? parsed.path : `${parsed.path}/`
  return `${parsed.origin}${directory}index.json`
}

function normalizeRepositoryLastUsedAt(value: Object | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? Math.floor(value) : 0
}

function normalizeSourceIndexRepository(value: Object): SourceIndexRepository | undefined {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return undefined
  }
  const record = value as Record<string, Object>
  const url = normalizeIndexUrl(safeString(record['url']))
  if (!isValidHttpUrl(url)) {
    return undefined
  }
  return {
    url,
    lastUsedAt: normalizeRepositoryLastUsedAt(record['lastUsedAt']),
  }
}

function normalizeSourceIndexRepositories(values: Object[]): SourceIndexRepository[] {
  const repositories: SourceIndexRepository[] = []
  values.forEach((value: Object) => {
    const repository = normalizeSourceIndexRepository(value)
    if (repository === undefined) {
      return
    }
    const existingIndex = repositories.findIndex((item: SourceIndexRepository): boolean => item.url === repository.url)
    if (existingIndex < 0) {
      repositories.push(repository)
      return
    }
    if (repository.lastUsedAt > repositories[existingIndex].lastUsedAt) {
      repositories[existingIndex] = repository
    }
  })
  return repositories
    .sort((left: SourceIndexRepository, right: SourceIndexRepository): number => right.lastUsedAt - left.lastUsedAt)
    .slice(0, SOURCE_INDEX_REPOSITORY_LIMIT)
}

function serializeSourceIndexRepositories(repositories: SourceIndexRepository[]): string {
  return JSON.stringify(normalizeSourceIndexRepositories(repositories as Object[]))
}

function safeRelativeIndexPath(value: string, requiredSuffix: string): string {
  const normalized = value.trim()
  if (normalized.length === 0 || normalized.length > 256 || normalized.startsWith('/') ||
    normalized.includes('\\') || normalized.includes('%') || normalized.includes('?') || normalized.includes('#') ||
    normalized.includes(':') || !normalized.toLowerCase().endsWith(requiredSuffix)) {
    return ''
  }
  const segments = normalized.split('/')
  if (segments.length === 0) {
    return ''
  }
  for (let index = 0; index < segments.length; index += 1) {
    const segment = segments[index]
    if (segment.length === 0 || segment === '.' || segment === '..' || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(segment)) {
      return ''
    }
  }
  return normalized
}

function safeResolveIndexRelativeUrl(indexUrl: string, relativePath: string, requiredSuffix: string): string {
  const documentUrl = resolveIndexDocumentUrl(indexUrl)
  const parsed = parseSourceIndexHttpUrl(documentUrl)
  const safePath = safeRelativeIndexPath(relativePath, requiredSuffix)
  if (parsed === undefined || safePath.length === 0) {
    return ''
  }
  const directory = parsed.path.substring(0, parsed.path.lastIndexOf('/') + 1)
  return `${parsed.origin}${directory}${safePath}`
}

function safeResolvePkgUrl(indexUrl: string, pkg: string): string {
  return safeResolveIndexRelativeUrl(indexUrl, pkg, '.koma')
}

function safeNonEmptyString(value: Object | undefined, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback
}

function safeString(value: Object | undefined): string {
  return typeof value === 'string' ? value : ''
}

function safeResolveIndexAssetUrl(indexUrl: string, assetPath: string): string {
  const suffix = assetPath.substring(assetPath.lastIndexOf('.')).toLowerCase()
  if (!SOURCE_REPO_PACKAGE_ICON_FILES.some((name: string): boolean => name.endsWith(suffix))) return ''
  return safeResolveIndexRelativeUrl(indexUrl, assetPath, suffix)
}

function safeBoolean(value: Object | undefined): boolean {
  return value === true
}

function safeSha256(value: Object | undefined): string {
  if (typeof value !== 'string') {
    return ''
  }
  const normalized = value.trim().toLowerCase()
  return /^[0-9a-f]{64}$/.test(normalized) ? normalized : ''
}

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

function parseIndexEntry(raw: Object): SourceIndexEntry | undefined {
  if (raw === null || raw === undefined || typeof raw !== 'object' || Array.isArray(raw)) {
    return undefined
  }
  const record = raw as Record<string, Object>
  const id = safeNonEmptyString(record['id'], '')
  const name = safeNonEmptyString(record['name'], '')
  const pkg = safeNonEmptyString(record['pkg'], '')
  if (id.length === 0 || name.length === 0 || pkg.length === 0) {
    return undefined
  }
  if (isInvalidSourceLocalizedNames(record['localizedNames'])) {
    return undefined
  }
  const rawMinAppVersion = record['minAppVersion']
  if (rawMinAppVersion !== undefined && typeof rawMinAppVersion !== 'string') {
    return undefined
  }
  const minAppVersion = safeString(rawMinAppVersion)
  if (!isValidSourcePackageMinAppVersion(minAppVersion)) {
    return undefined
  }
  return {
    id,
    name,
    localizedNames: normalizeSourceLocalizedNames(record['localizedNames']),
    version: safeString(record['version']),
    lang: safeString(record['lang']),
    nsfw: safeBoolean(record['nsfw']),
    author: safeString(record['author']),
    description: safeString(record['description']),
    contentRating: safeString(record['contentRating']),
    pkg,
    sha256: safeSha256(record['sha256']),
    icon: safeString(record['icon']),
    minAppVersion,
  }
}

function entryWithCachedIcon(entry: SourceIndexEntry, iconUri: string): SourceIndexEntry {
  return {
    id: entry.id,
    name: entry.name,
    localizedNames: normalizeSourceLocalizedNames(entry.localizedNames),
    version: entry.version,
    lang: entry.lang,
    nsfw: entry.nsfw,
    author: entry.author,
    description: entry.description,
    contentRating: entry.contentRating,
    pkg: entry.pkg,
    sha256: entry.sha256,
    icon: entry.icon,
    iconUri,
    minAppVersion: entry.minAppVersion,
  }
}

function parseIndexEntriesDocument(raw: Object): Object[] | undefined {
  if (Array.isArray(raw)) {
    return raw as Object[]
  }
  if (raw === null || raw === undefined || typeof raw !== 'object' || Array.isArray(raw)) {
    return undefined
  }
  const record = raw as Record<string, Object>
  const sources = record['sources']
  return Array.isArray(sources) ? sources as Object[] : undefined
}

const sourceIndexPreferenceOperations: Map<string, Promise<void>> = new Map()

export class SourceIndexService {
  private context: common.UIAbilityContext
  private iconCacheStore: RemoteImageCacheStore

  constructor(context: common.UIAbilityContext) {
    this.context = context
    this.iconCacheStore = new RemoteImageCacheStore(this.context.cacheDir, SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME)
  }

  private async cachedIconUriFor(indexUrl: string, entry: SourceIndexEntry): Promise<string> {
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
          console.info('[SourceIndex] step=save_url')
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
        console.error('[SourceIndex] step=fetch_fail status=' + response.responseCode)
        return { ok: false, reasonCode: 'http_error', entries: [] }
      }

      const body = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
      let parsed: Object[]
      try {
        const raw: Object = JSON.parse(body) as Object
        const entriesDocument = parseIndexEntriesDocument(raw)
        if (entriesDocument === undefined) {
          return { ok: false, reasonCode: 'invalid_index_format', entries: [] }
        }
        parsed = entriesDocument
      } catch (_err) {
        return { ok: false, reasonCode: 'invalid_json', entries: [] }
      }

      const entries: SourceIndexEntry[] = []
      for (let index = 0; index < parsed.length; index += 1) {
        const entry = parseIndexEntry(parsed[index])
        if (entry !== undefined) {
          if (entry.icon.trim().length === 0) return { ok: false, reasonCode: 'missing_icon', entries: [] }
          if (safeResolveIndexAssetUrl(normalizedUrl, entry.icon).length === 0) {
            return { ok: false, reasonCode: 'invalid_icon', entries: [] }
          }
          entries.push(entry)
        }
      }
      // Fetch independent icons together without changing the index order or validation.
      for (let offset = 0; offset < entries.length; offset += SOURCE_INDEX_ICON_FETCH_CONCURRENCY) {
        const end = Math.min(offset + SOURCE_INDEX_ICON_FETCH_CONCURRENCY, entries.length)
        const pending: Promise<string>[] = []
        for (let index = offset; index < end; index += 1) {
          pending.push(this.cachedIconUriFor(normalizedUrl, entries[index]))
        }
        const iconUris = await Promise.all(pending)
        for (let index = 0; index < iconUris.length; index += 1) {
          const iconUri = iconUris[index]
          if (iconUri.length > 0) {
            entries[offset + index] = entryWithCachedIcon(entries[offset + index], iconUri)
          }
        }
      }
      console.info('[SourceIndex] step=fetch_ok count=' + entries.length)
      return { ok: true, entries }
    } catch (error) {
      const e = error as BusinessError
      console.error('[SourceIndex] step=fetch_error code=' + e.code)
      return { ok: false, reasonCode: 'network_error', entries: [] }
    } finally {
      httpRequest.destroy()
    }
  }

  async installPackage(indexUrl: string, entry: SourceIndexEntry): Promise<SourceIndexInstallResult> {
    return BackupRestoreActivity.runWrite(async (): Promise<SourceIndexInstallResult> => {
      if (!isSourcePackageMinAppVersionSatisfied(entry.minAppVersion)) {
        console.error('[SourceIndex] step=install_blocked reason=app_version_unsupported')
        return { ok: false, reasonCode: 'app_version_unsupported' }
      }

      const pkgUrl = safeResolvePkgUrl(resolveIndexDocumentUrl(indexUrl), entry.pkg)
      if (!isValidHttpUrl(pkgUrl)) {
        return { ok: false, reasonCode: 'invalid_pkg_url' }
      }

      console.info('[SourceIndex] step=download_pkg')

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
          console.error('[SourceIndex] step=download_fail status=' + response.responseCode)
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
          console.error('[SourceIndex] step=download_fail reason=checksum_mismatch')
          return { ok: false, reasonCode: 'checksum_mismatch' }
        }

        const install = await installFromBytes(this.context, archiveBytes, entry.pkg, entry.id)
        if (!install.ok) {
          console.error('[SourceIndex] step=install_fail reason=' + (install.reasonCode ?? 'unknown'))
          return { ok: false, reasonCode: install.reasonCode, install }
        }

        console.info('[SourceIndex] step=install_ok id=' + install.id)
        return { ok: true, install }
      } catch (error) {
        const e = error as BusinessError
        console.error('[SourceIndex] step=download_error code=' + e.code)
        return { ok: false, reasonCode: 'network_error' }
      } finally {
        httpRequest.destroy()
      }
    })
  }
}
