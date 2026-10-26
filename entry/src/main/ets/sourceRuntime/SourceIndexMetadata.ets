import { isInvalidSourceLocalizedNames, normalizeSourceLocalizedNames } from './SourceLocalizedNames'
import { SOURCE_REPO_PACKAGE_ICON_FILES, isValidSourcePackageMinAppVersion, normalizeSourceHomepage } from './SourcePackageMetadata'

const SOURCE_INDEX_REPOSITORY_LIMIT: number = 12
export const SOURCE_INDEX_METADATA_ENTRY_LIMIT: number = 4096
export const SOURCE_INDEX_METADATA_RECORD_LIMIT: number = 1024 * 1024
export const SOURCE_INDEX_METADATA_CACHE_LIMIT: number = 4 * 1024 * 1024

export interface SourceIndexMetadataCacheRecord {
  url: string
  entries: SourceIndexEntry[]
}

export interface SourceIndexMetadataCacheDocument {
  schemaVersion: number
  records: SourceIndexMetadataCacheRecord[]
}
export interface SourceIndexRepository {
  url: string
  lastUsedAt: number
}

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
  homepage?: string
  author: string
  description: string
  contentRating: string
  pkg: string
  sha256: string
  icon: string
  iconUri?: string
  minAppVersion: string
}

export function normalizeSourceIndexPath(value: string): string | undefined {
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

export function parseSourceIndexHttpUrl(value: string): SourceIndexHttpUrl | undefined {
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

export function isValidHttpUrl(value: string): boolean {
  return parseSourceIndexHttpUrl(value) !== undefined
}

export function normalizeIndexUrl(value: string): string {
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

export function resolveIndexDocumentUrl(value: string): string {
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

export function normalizeRepositoryLastUsedAt(value: Object | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? Math.floor(value) : 0
}

export function normalizeSourceIndexRepository(value: Object): SourceIndexRepository | undefined {
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

export function normalizeSourceIndexRepositories(values: Object[]): SourceIndexRepository[] {
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

export function serializeSourceIndexRepositories(repositories: SourceIndexRepository[]): string {
  return JSON.stringify(normalizeSourceIndexRepositories(repositories as Object[]))
}

export function safeRelativeIndexPath(value: string, requiredSuffix: string): string {
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

export function safeResolveIndexRelativeUrl(indexUrl: string, relativePath: string, requiredSuffix: string): string {
  const documentUrl = resolveIndexDocumentUrl(indexUrl)
  const parsed = parseSourceIndexHttpUrl(documentUrl)
  const safePath = safeRelativeIndexPath(relativePath, requiredSuffix)
  if (parsed === undefined || safePath.length === 0) {
    return ''
  }
  const directory = parsed.path.substring(0, parsed.path.lastIndexOf('/') + 1)
  return `${parsed.origin}${directory}${safePath}`
}

export function safeResolvePkgUrl(indexUrl: string, pkg: string): string {
  return safeResolveIndexRelativeUrl(indexUrl, pkg, '.koma')
}

export function safeNonEmptyString(value: Object | undefined, fallback: string): string {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : fallback
}

export function safeString(value: Object | undefined): string {
  return typeof value === 'string' ? value : ''
}

export function safeResolveIndexAssetUrl(indexUrl: string, assetPath: string): string {
  const suffix = assetPath.substring(assetPath.lastIndexOf('.')).toLowerCase()
  if (!SOURCE_REPO_PACKAGE_ICON_FILES.some((name: string): boolean => name.endsWith(suffix))) return ''
  return safeResolveIndexRelativeUrl(indexUrl, assetPath, suffix)
}

export function safeBoolean(value: Object | undefined): boolean {
  return value === true
}

export function safeSha256(value: Object | undefined): string {
  if (typeof value !== 'string') {
    return ''
  }
  const normalized = value.trim().toLowerCase()
  return /^[0-9a-f]{64}$/.test(normalized) ? normalized : ''
}

export function parseIndexEntry(raw: Object): SourceIndexEntry | undefined {
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
    homepage: normalizeSourceHomepage(record['homepage']),
    author: safeString(record['author']),
    description: safeString(record['description']),
    contentRating: safeString(record['contentRating']),
    pkg,
    sha256: safeSha256(record['sha256']),
    icon: safeString(record['icon']),
    minAppVersion,
  }
}

export function entryWithCachedIcon(entry: SourceIndexEntry, iconUri: string): SourceIndexEntry {
  return {
    id: entry.id,
    name: entry.name,
    localizedNames: normalizeSourceLocalizedNames(entry.localizedNames),
    version: entry.version,
    lang: entry.lang,
    nsfw: entry.nsfw,
    homepage: normalizeSourceHomepage(entry.homepage),
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

export function parseIndexEntriesDocument(raw: Object): Object[] | undefined {
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

export function parseCachedIndexEntries(raw: Object, url: string): SourceIndexEntry[] | undefined {
  if (!Array.isArray(raw) || raw.length > SOURCE_INDEX_METADATA_ENTRY_LIMIT) return undefined
  const entries: SourceIndexEntry[] = []
  for (const value of raw as Object[]) {
    // parseIndexEntry projects metadata only; persisted iconUri is never trusted.
    const entry = parseIndexEntry(value)
    if (entry === undefined || safeResolveIndexAssetUrl(url, entry.icon).length === 0) return undefined
    entries.push(entry)
  }
  return entries
}

export function parseMetadataCache(payload: Object): SourceIndexMetadataCacheRecord[] {
  if (typeof payload !== 'string' || payload.length === 0 || payload.length > SOURCE_INDEX_METADATA_CACHE_LIMIT) return []
  try {
    const document = JSON.parse(payload) as Record<string, Object>
    if (document === null || document['schemaVersion'] !== 1 || !Array.isArray(document['records'])) return []
    const values = document['records'] as Object[]
    if (values.length > SOURCE_INDEX_REPOSITORY_LIMIT) return []
    const records: SourceIndexMetadataCacheRecord[] = []
    for (const value of values) {
      if (value === null || typeof value !== 'object' || Array.isArray(value)) continue
      const record = value as Record<string, Object>
      const url = safeString(record['url'])
      if (!isValidHttpUrl(url) || resolveIndexDocumentUrl(url) !== url || JSON.stringify(value).length > SOURCE_INDEX_METADATA_RECORD_LIMIT) continue
      const entries = parseCachedIndexEntries(record['entries'], url)
      if (entries === undefined || records.some((item: SourceIndexMetadataCacheRecord): boolean => item.url === url)) continue
      records.push({ url, entries })
    }
    return records
  } catch (_error) {
    return []
  }
}
