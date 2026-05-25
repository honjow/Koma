import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { installFromBytes, SourcePackageInstallResult } from './SourceRuntimeAppRegistry'

const SOURCE_INDEX_PREFS_STORE_NAME: string = 'koma_source_package_manager_v1'
const SOURCE_INDEX_URL_KEY: string = 'source_index.url'

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

function isValidHttpUrl(value: string): boolean {
  if (typeof value !== 'string' || value.length === 0) {
    return false
  }
  return value.startsWith('http://') || value.startsWith('https://')
}

function normalizeIndexUrl(value: string): string {
  return value.trim().replace(/\/+$/, '')
}

function safeResolvePkgUrl(indexUrl: string, pkg: string): string {
  const normalizedPkg = pkg.replace(/\\/g, '/').replace(/^\/+/, '')
  if (normalizedPkg.length === 0) {
    return ''
  }
  if (normalizedPkg.startsWith('http://') || normalizedPkg.startsWith('https://')) {
    return normalizedPkg
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
    icon: safeString(record['icon']),
    minAppVersion: safeString(record['minAppVersion']),
  }
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

  async saveUrl(url: string): Promise<void> {
    const normalized = normalizeIndexUrl(url)
    try {
      const store = await preferences.getPreferences(this.context, SOURCE_INDEX_PREFS_STORE_NAME)
      await store.put(SOURCE_INDEX_URL_KEY, normalized)
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

  async fetchIndex(indexUrl: string): Promise<SourceIndexFetchResult> {
    const normalizedUrl = normalizeIndexUrl(indexUrl)
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
        if (!Array.isArray(raw)) {
          return { ok: false, reasonCode: 'invalid_index_format', entries: [] }
        }
        parsed = raw as Object[]
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
    const pkgUrl = safeResolvePkgUrl(normalizeIndexUrl(indexUrl), entry.pkg)
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

      const install = await installFromBytes(this.context, archiveBytes, entry.pkg)
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
  }
}
