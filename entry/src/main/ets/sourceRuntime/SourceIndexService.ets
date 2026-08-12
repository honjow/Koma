import { bundleManager, common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { http } from '@kit.NetworkKit'
import {
  installFromBytes,
  setSourcePresentationMetadata,
  SourcePackageInstallResult,
} from './SourceRuntimeAppRegistry'

const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'
const SOURCE_INDEX_REPOSITORIES_KEY: string = 'source_index.repositories.v1'
const SOURCE_INDEX_REPOSITORY_LIMIT: number = 12

export interface SourceIndexEntry {
  id: string
  name: string
  version: string
  lang: string
  nsfw: boolean
  author: string
  description: string
  contentRating: string
  pkg: string
  sha256: string
  icon: string
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

function isValidHttpUrl(value: string): boolean {
  if (typeof value !== 'string' || value.length === 0) {
    return false
  }
  return value.startsWith('http://') || value.startsWith('https://')
}

function normalizeIndexUrl(value: string): string {
  return value.trim().replace(/\/+$/, '')
}

function resolveIndexDocumentUrl(value: string): string {
  const normalized = normalizeIndexUrl(value)
  if (!isValidHttpUrl(normalized) || normalized.endsWith('.json')) {
    return normalized
  }
  return `${normalized}/index.json`
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

function safeResolvePkgUrl(indexUrl: string, pkg: string): string {
  const normalizedPkg = pkg.replace(/\\/g, '/').replace(/^\/+/, '')
  if (normalizedPkg.length === 0) {
    return ''
  }
  if (normalizedPkg.startsWith('http://') || normalizedPkg.startsWith('https://')) {
    return ''
  }
  if (normalizedPkg.split('/').includes('..') || !normalizedPkg.endsWith('.koma')) {
    return ''
  }
  const base = indexUrl.replace(/\/+$/, '')
  const authorityStart = base.indexOf('://')
  const firstPathSlash = authorityStart >= 0 ? base.indexOf('/', authorityStart + 3) : base.indexOf('/')
  if (firstPathSlash < 0) {
    return `${base}/${normalizedPkg}`
  }
  const indexDir = base.substring(0, base.lastIndexOf('/') + 1)
  return `${indexDir}${normalizedPkg}`
}

function safeNonEmptyString(value: Object | undefined, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback
}

function safeString(value: Object | undefined): string {
  return typeof value === 'string' ? value : ''
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

function compareVersion(left: string, right: string): number {
  const leftParts = left.trim().split('.')
  const rightParts = right.trim().split('.')
  const count = Math.max(leftParts.length, rightParts.length)
  for (let index = 0; index < count; index += 1) {
    const leftValue = Number.parseInt(leftParts[index] ?? '0')
    const rightValue = Number.parseInt(rightParts[index] ?? '0')
    if (Number.isNaN(leftValue) || Number.isNaN(rightValue)) {
      return left === right ? 0 : left.localeCompare(right)
    }
    if (leftValue !== rightValue) {
      return leftValue > rightValue ? 1 : -1
    }
  }
  return 0
}

function currentAppVersionName(): string {
  try {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
    return info.versionName
  } catch (_err) {
    return ''
  }
}

function isMinAppVersionSatisfied(minAppVersion: string): boolean {
  const required = minAppVersion.trim()
  if (required.length === 0) {
    return true
  }
  const current = currentAppVersionName()
  if (current.length === 0) {
    return false
  }
  return compareVersion(current, required) >= 0
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
  return {
    id,
    name,
    version: safeString(record['version']),
    lang: safeString(record['lang']),
    nsfw: safeBoolean(record['nsfw']),
    author: safeString(record['author']),
    description: safeString(record['description']),
    contentRating: safeString(record['contentRating']),
    pkg,
    sha256: safeSha256(record['sha256']),
    icon: safeString(record['icon']),
    minAppVersion: safeString(record['minAppVersion']),
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

export class SourceIndexService {
  private context: common.UIAbilityContext

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  async loadSavedUrl(): Promise<string> {
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      const url = await store.get(SOURCE_INDEX_URL_KEY, '') as string
      return typeof url === 'string' && url.trim().length > 0 ? url.trim() : ''
    } catch (_err) {
      return ''
    }
  }

  async loadSavedRepositories(): Promise<SourceIndexRepository[]> {
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      const payload = await store.get(SOURCE_INDEX_REPOSITORIES_KEY, '') as string
      let repositories: SourceIndexRepository[] = []
      if (typeof payload === 'string' && payload.trim().length > 0) {
        const parsed = JSON.parse(payload) as Object
        if (Array.isArray(parsed)) {
          repositories = normalizeSourceIndexRepositories(parsed as Object[])
        }
      }
      const legacyUrl = await store.get(SOURCE_INDEX_URL_KEY, '') as string
      const normalizedLegacyUrl = typeof legacyUrl === 'string' ? normalizeIndexUrl(legacyUrl) : ''
      if (isValidHttpUrl(normalizedLegacyUrl) && !repositories.some((item: SourceIndexRepository): boolean => item.url === normalizedLegacyUrl)) {
        repositories.push({
          url: normalizedLegacyUrl,
          lastUsedAt: 0,
        })
      }
      return normalizeSourceIndexRepositories(repositories as Object[])
    } catch (_err) {
      return []
    }
  }

  async saveUrl(url: string): Promise<void> {
    const normalized = normalizeIndexUrl(url)
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      await store.put(SOURCE_INDEX_URL_KEY, normalized)
      if (isValidHttpUrl(normalized)) {
        const repositories = await this.loadSavedRepositories()
        const next: SourceIndexRepository[] = [{
          url: normalized,
          lastUsedAt: Date.now(),
        }]
        repositories.forEach((repository: SourceIndexRepository) => {
          if (repository.url !== normalized) {
            next.push(repository)
          }
        })
        await store.put(SOURCE_INDEX_REPOSITORIES_KEY, serializeSourceIndexRepositories(next))
      }
      await store.flush()
      console.info('[SourceIndex] step=save_url')
    } catch (error) {
      const e = error as BusinessError
      console.error('[SourceIndex] step=save_url_fail code=' + e.code)
    }
  }

  async clearUrl(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      await store.delete(SOURCE_INDEX_URL_KEY)
      await store.flush()
      console.info('[SourceIndex] step=clear_url')
    } catch (_err) {
    }
  }

  async removeSavedRepository(url: string): Promise<SourceIndexRepository[]> {
    const normalized = normalizeIndexUrl(url)
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      const repositories = (await this.loadSavedRepositories())
        .filter((repository: SourceIndexRepository): boolean => repository.url !== normalized)
      await store.put(SOURCE_INDEX_REPOSITORIES_KEY, serializeSourceIndexRepositories(repositories))
      const activeUrl = await store.get(SOURCE_INDEX_URL_KEY, '') as string
      if (typeof activeUrl === 'string' && normalizeIndexUrl(activeUrl) === normalized) {
        if (repositories.length > 0) {
          await store.put(SOURCE_INDEX_URL_KEY, repositories[0].url)
        } else {
          await store.delete(SOURCE_INDEX_URL_KEY)
        }
      }
      await store.flush()
      console.info('[SourceIndex] step=remove_saved_repository')
      return repositories
    } catch (error) {
      const e = error as BusinessError
      console.error('[SourceIndex] step=remove_saved_repository_fail code=' + e.code)
      return this.loadSavedRepositories()
    }
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
          entries.push(entry)
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
    if (!isMinAppVersionSatisfied(entry.minAppVersion)) {
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

      if (install.id !== undefined &&
        !setSourcePresentationMetadata(this.context, install.id, entry.description, entry.icon)) {
        console.warn('[SourceIndex] step=presentation_metadata_skip reason=metadata_persist_failed')
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
  }
}
