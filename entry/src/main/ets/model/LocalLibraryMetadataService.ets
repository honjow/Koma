import { isSupportedImagePath } from '../import/ImageSortUtils'

export const LOCAL_LIBRARY_METADATA_CONTRACT_VERSION = 1
export const LOCAL_LIBRARY_METADATA_IO_CONTRACT = 'MODEL_ONLY_NO_SIDECAR_RUNTIME_IO'
export const LOCAL_LIBRARY_METADATA_DESTRUCTIVE_ACTION_CONTRACT = 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES'
export const LOCAL_LIBRARY_METADATA_FALLBACK_ORDER: string[] = [
  'user_override',
  'valid_sidecar',
  'derived_folder_series',
  'existing_library_import',
]

export type LocalLibraryMetadataStatus = 'ongoing' | 'completed' | 'hiatus' | 'cancelled'
export type LocalLibraryMetadataSource = 'user_override' | 'valid_sidecar' | 'derived_folder_series' | 'existing_library_import' | 'none'
export type LocalLibraryMetadataParseStatus = 'ok' | 'failure'

export interface LocalLibraryStoredMetadata {
  titleOverride?: string
  authors?: string[]
  status?: LocalLibraryMetadataStatus
  coverOverridePath?: string
}

export interface LocalLibrarySidecarMetadata {
  title?: string
  authors?: string[]
  status?: LocalLibraryMetadataStatus
  coverPath?: string
}

export interface LocalLibraryMetadataValidationFailure {
  field: string
  reason: string
}

export interface LocalLibrarySidecarParseResult {
  status: LocalLibraryMetadataParseStatus
  metadata?: LocalLibrarySidecarMetadata
  failures: LocalLibraryMetadataValidationFailure[]
}

export interface LocalLibraryDerivedMetadata {
  title?: string
  authors?: string[]
  status?: LocalLibraryMetadataStatus
  coverPath?: string
}

export interface LocalLibraryExistingImportMetadata {
  title?: string
  author?: string
  coverUri?: string
}

export interface LocalLibraryMetadataResolutionInput {
  userOverride?: LocalLibraryStoredMetadata
  sidecar?: LocalLibrarySidecarMetadata
  derived: LocalLibraryDerivedMetadata
  existing?: LocalLibraryExistingImportMetadata
}

export interface LocalLibraryResolvedMetadata {
  title: string
  titleSource: LocalLibraryMetadataSource
  authors: string[]
  authorsSource: LocalLibraryMetadataSource
  status?: LocalLibraryMetadataStatus
  statusSource: LocalLibraryMetadataSource
  coverReference?: string
  coverReferenceSource: LocalLibraryMetadataSource
}

export interface LocalLibraryMetadataBackupEntry {
  comicId: string
  metadata: LocalLibraryStoredMetadata
}

export interface LocalLibraryMetadataSeriesInput {
  title: string
  relativePath: string
}

interface ResolvedMetadataField<T> {
  value?: T
  source: LocalLibraryMetadataSource
}

function normalizedText(value: string | undefined): string | undefined {
  if (value === undefined) {
    return undefined
  }
  const normalized = value.trim().replace(/\s+/g, ' ')
  return normalized.length === 0 ? undefined : normalized
}

function isMetadataStatus(value: string): boolean {
  return value === 'ongoing' || value === 'completed' || value === 'hiatus' || value === 'cancelled'
}

function normalizeStatus(value: Object | undefined, field: string, failures: LocalLibraryMetadataValidationFailure[]): LocalLibraryMetadataStatus | undefined {
  if (value === undefined) {
    return undefined
  }
  if (typeof value !== 'string' || !isMetadataStatus(value.trim())) {
    failures.push({ field, reason: 'invalid_status' })
    return undefined
  }
  return value.trim() as LocalLibraryMetadataStatus
}

function normalizeTitle(value: Object | undefined, field: string, failures: LocalLibraryMetadataValidationFailure[]): string | undefined {
  if (value === undefined) {
    return undefined
  }
  if (typeof value !== 'string') {
    failures.push({ field, reason: 'invalid_title' })
    return undefined
  }
  const normalized = normalizedText(value)
  if (normalized === undefined) {
    failures.push({ field, reason: 'blank_title' })
    return undefined
  }
  return normalized
}

function normalizeAuthors(value: Object | undefined, field: string, failures: LocalLibraryMetadataValidationFailure[]): string[] | undefined {
  if (value === undefined) {
    return undefined
  }
  const authors: string[] = []
  if (typeof value === 'string') {
    const normalized = normalizedText(value)
    if (normalized === undefined) {
      failures.push({ field, reason: 'blank_author' })
      return undefined
    }
    return [normalized]
  }
  if (!Array.isArray(value)) {
    failures.push({ field, reason: 'invalid_authors' })
    return undefined
  }
  value.forEach((item: Object, index: number) => {
    if (typeof item !== 'string') {
      failures.push({ field: `${field}.${index}`, reason: 'invalid_author' })
      return
    }
    const normalized = normalizedText(item)
    if (normalized === undefined) {
      failures.push({ field: `${field}.${index}`, reason: 'blank_author' })
      return
    }
    if (!authors.includes(normalized)) {
      authors.push(normalized)
    }
  })
  return authors.length === 0 ? undefined : authors
}

function hasHiddenPathSegment(path: string): boolean {
  return path.split('/').some((segment: string): boolean => segment.startsWith('.'))
}

function hasUnsafeControlCharacter(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    if (code < 32 || code === 127) {
      return true
    }
  }
  return false
}

function normalizeLocalLibraryMetadataRelativePath(path: string): string {
  const normalized = path.replace(/\\/g, '/').trim()
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('://') ||
    /^[A-Za-z]:/.test(normalized) ||
    hasUnsafeControlCharacter(normalized)
  ) {
    throw new Error(`Unsafe local library path: ${path}`)
  }
  const parts = normalized.split('/')
  const safeParts: string[] = []
  for (const part of parts) {
    const trimmed = part.trim()
    if (trimmed.length === 0 || trimmed === '.' || trimmed === '..' || trimmed.indexOf(':') >= 0) {
      throw new Error(`Unsafe local library path segment: ${path}`)
    }
    safeParts.push(trimmed)
  }
  return safeParts.join('/')
}

export function validateLocalLibraryCoverOverridePath(path: string): string {
  const normalized = normalizeLocalLibraryMetadataRelativePath(path)
  if (hasHiddenPathSegment(normalized)) {
    throw new Error(`Unsafe local metadata cover path: ${path}`)
  }
  if (!isSupportedImagePath(normalized)) {
    throw new Error(`Unsupported local metadata cover image: ${path}`)
  }
  return normalized
}

function normalizeCoverPath(value: Object | undefined, field: string, failures: LocalLibraryMetadataValidationFailure[]): string | undefined {
  if (value === undefined) {
    return undefined
  }
  if (typeof value !== 'string') {
    failures.push({ field, reason: 'invalid_cover_path' })
    return undefined
  }
  try {
    return validateLocalLibraryCoverOverridePath(value)
  } catch (_err) {
    failures.push({ field, reason: 'unsafe_cover_path' })
    return undefined
  }
}

function objectField(source: Record<string, Object>, keys: string[]): Object | undefined {
  for (let index = 0; index < keys.length; index += 1) {
    const value = source[keys[index]]
    if (value !== undefined) {
      return value
    }
  }
  return undefined
}

export function parseLocalLibrarySidecarMetadata(payload: string | Object | null): LocalLibrarySidecarParseResult {
  let source: Record<string, Object>
  if (typeof payload === 'string') {
    try {
      const parsed = JSON.parse(payload) as Object
      if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
        return { status: 'failure', failures: [{ field: 'document', reason: 'expected_object' }] }
      }
      source = parsed as Record<string, Object>
    } catch (_err) {
      return { status: 'failure', failures: [{ field: 'document', reason: 'malformed_json' }] }
    }
  } else if (payload === null || Array.isArray(payload) || typeof payload !== 'object') {
    return { status: 'failure', failures: [{ field: 'document', reason: 'expected_object' }] }
  } else {
    source = payload as Record<string, Object>
  }

  const failures: LocalLibraryMetadataValidationFailure[] = []
  const title = normalizeTitle(objectField(source, ['title', 'titleOverride']), 'title', failures)
  const authors = normalizeAuthors(objectField(source, ['authors', 'author']), 'authors', failures)
  const status = normalizeStatus(source['status'], 'status', failures)
  const coverPath = normalizeCoverPath(objectField(source, ['coverPath', 'cover', 'coverOverridePath']), 'coverPath', failures)

  if (failures.length > 0) {
    return { status: 'failure', failures }
  }

  const metadata: LocalLibrarySidecarMetadata = {}
  if (title !== undefined) {
    metadata.title = title
  }
  if (authors !== undefined) {
    metadata.authors = authors
  }
  if (status !== undefined) {
    metadata.status = status
  }
  if (coverPath !== undefined) {
    metadata.coverPath = coverPath
  }
  return { status: 'ok', metadata, failures: [] }
}

export function normalizeLocalLibraryStoredMetadata(value: Object | undefined): LocalLibraryStoredMetadata | undefined {
  if (value === undefined) {
    return undefined
  }
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error('Invalid local library metadata')
  }
  const source = value as Record<string, Object>
  const failures: LocalLibraryMetadataValidationFailure[] = []
  const titleOverride = normalizeTitle(source['titleOverride'], 'titleOverride', failures)
  const authors = normalizeAuthors(source['authors'], 'authors', failures)
  const status = normalizeStatus(source['status'], 'status', failures)
  const coverOverridePath = normalizeCoverPath(source['coverOverridePath'], 'coverOverridePath', failures)
  if (failures.length > 0) {
    throw new Error('Invalid local library metadata: ' + failures.map((failure: LocalLibraryMetadataValidationFailure): string => failure.field + ':' + failure.reason).join(','))
  }
  const metadata: LocalLibraryStoredMetadata = {}
  if (titleOverride !== undefined) {
    metadata.titleOverride = titleOverride
  }
  if (authors !== undefined) {
    metadata.authors = authors
  }
  if (status !== undefined) {
    metadata.status = status
  }
  if (coverOverridePath !== undefined) {
    metadata.coverOverridePath = coverOverridePath
  }
  return metadata
}

function firstTitle(input: LocalLibraryMetadataResolutionInput): ResolvedMetadataField<string> {
  const userTitle = normalizedText(input.userOverride?.titleOverride)
  if (userTitle !== undefined) {
    return { value: userTitle, source: 'user_override' }
  }
  const sidecarTitle = normalizedText(input.sidecar?.title)
  if (sidecarTitle !== undefined) {
    return { value: sidecarTitle, source: 'valid_sidecar' }
  }
  const derivedTitle = normalizedText(input.derived.title)
  if (derivedTitle !== undefined) {
    return { value: derivedTitle, source: 'derived_folder_series' }
  }
  const existingTitle = normalizedText(input.existing?.title)
  if (existingTitle !== undefined) {
    return { value: existingTitle, source: 'existing_library_import' }
  }
  return { value: 'Untitled', source: 'none' }
}

function firstAuthors(input: LocalLibraryMetadataResolutionInput): ResolvedMetadataField<string[]> {
  if (input.userOverride?.authors !== undefined && input.userOverride.authors.length > 0) {
    return { value: input.userOverride.authors, source: 'user_override' }
  }
  if (input.sidecar?.authors !== undefined && input.sidecar.authors.length > 0) {
    return { value: input.sidecar.authors, source: 'valid_sidecar' }
  }
  if (input.derived.authors !== undefined && input.derived.authors.length > 0) {
    return { value: input.derived.authors, source: 'derived_folder_series' }
  }
  const existingAuthor = normalizedText(input.existing?.author)
  if (existingAuthor !== undefined) {
    return { value: [existingAuthor], source: 'existing_library_import' }
  }
  return { value: [], source: 'none' }
}

function firstStatus(input: LocalLibraryMetadataResolutionInput): ResolvedMetadataField<LocalLibraryMetadataStatus> {
  if (input.userOverride?.status !== undefined) {
    return { value: input.userOverride.status, source: 'user_override' }
  }
  if (input.sidecar?.status !== undefined) {
    return { value: input.sidecar.status, source: 'valid_sidecar' }
  }
  if (input.derived.status !== undefined) {
    return { value: input.derived.status, source: 'derived_folder_series' }
  }
  return { source: 'none' }
}

function firstCover(input: LocalLibraryMetadataResolutionInput): ResolvedMetadataField<string> {
  if (input.userOverride?.coverOverridePath !== undefined) {
    return { value: input.userOverride.coverOverridePath, source: 'user_override' }
  }
  if (input.sidecar?.coverPath !== undefined) {
    return { value: input.sidecar.coverPath, source: 'valid_sidecar' }
  }
  if (input.derived.coverPath !== undefined) {
    return { value: input.derived.coverPath, source: 'derived_folder_series' }
  }
  const existingCover = normalizedText(input.existing?.coverUri)
  if (existingCover !== undefined) {
    return { value: existingCover, source: 'existing_library_import' }
  }
  return { source: 'none' }
}

export function resolveLocalLibraryMetadata(input: LocalLibraryMetadataResolutionInput): LocalLibraryResolvedMetadata {
  const title = firstTitle(input)
  const authors = firstAuthors(input)
  const status = firstStatus(input)
  const cover = firstCover(input)
  const resolved: LocalLibraryResolvedMetadata = {
    title: title.value ?? 'Untitled',
    titleSource: title.source,
    authors: authors.value ?? [],
    authorsSource: authors.source,
    status: status.value,
    statusSource: status.source,
    coverReference: cover.value,
    coverReferenceSource: cover.source,
  }
  return resolved
}

export function createDerivedLocalLibraryMetadata(series: LocalLibraryMetadataSeriesInput): LocalLibraryDerivedMetadata {
  const derived: LocalLibraryDerivedMetadata = {
    title: series.title,
  }
  return derived
}

export function resolveLocalLibrarySeriesCoverReference(series: LocalLibraryMetadataSeriesInput, coverOverridePath: string): string {
  const seriesPath = normalizeLocalLibraryMetadataRelativePath(series.relativePath)
  const coverPath = validateLocalLibraryCoverOverridePath(coverOverridePath)
  return `${seriesPath}/${coverPath}`
}

export function exportLocalLibraryMetadataBackupEntries(libraryStorePayload: string): LocalLibraryMetadataBackupEntry[] {
  const document = JSON.parse(libraryStorePayload) as Record<string, Object>
  const comics = document['comics']
  if (!Array.isArray(comics)) {
    return []
  }
  const entries: LocalLibraryMetadataBackupEntry[] = []
  comics.forEach((row: Object) => {
    if (row === null || Array.isArray(row) || typeof row !== 'object') {
      return
    }
    const comic = row as Record<string, Object>
    const id = comic['id']
    if (typeof id !== 'string') {
      return
    }
    const metadata = normalizeLocalLibraryStoredMetadata(comic['localMetadata'])
    if (metadata !== undefined) {
      entries.push({ comicId: id, metadata })
    }
  })
  return entries
}

export function restoreLocalLibraryMetadataBackupEntries(libraryStorePayload: string, entries: LocalLibraryMetadataBackupEntry[] | undefined): string {
  if (entries === undefined) {
    return libraryStorePayload
  }
  if (!Array.isArray(entries)) {
    throw new Error('Invalid local library metadata backup entries')
  }
  const metadataByComicId = new Map<string, LocalLibraryStoredMetadata>()
  entries.forEach((entry: LocalLibraryMetadataBackupEntry) => {
    if (entry === undefined || typeof entry.comicId !== 'string' || entry.comicId.trim().length === 0) {
      throw new Error('Invalid local library metadata backup entry')
    }
    metadataByComicId.set(entry.comicId, normalizeLocalLibraryStoredMetadata(entry.metadata as Object) ?? {})
  })

  const document = JSON.parse(libraryStorePayload) as Record<string, Object>
  const comics = document['comics']
  if (!Array.isArray(comics)) {
    return libraryStorePayload
  }
  comics.forEach((row: Object) => {
    if (row === null || Array.isArray(row) || typeof row !== 'object') {
      return
    }
    const comic = row as Record<string, Object>
    const id = comic['id']
    if (typeof id !== 'string') {
      return
    }
    const metadata = metadataByComicId.get(id)
    if (metadata !== undefined) {
      comic['localMetadata'] = metadata as Object
    }
  })
  return JSON.stringify(document)
}

export class LocalLibraryMetadataService {
  parseSidecarMetadata(payload: string | Object | null): LocalLibrarySidecarParseResult {
    return parseLocalLibrarySidecarMetadata(payload)
  }

  resolveMetadata(input: LocalLibraryMetadataResolutionInput): LocalLibraryResolvedMetadata {
    return resolveLocalLibraryMetadata(input)
  }

  validateCoverOverridePath(path: string): string {
    return validateLocalLibraryCoverOverridePath(path)
  }
}
