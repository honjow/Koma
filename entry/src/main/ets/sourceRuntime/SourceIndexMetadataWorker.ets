import { parseCachedIndexEntries, parseMetadataCache, parseIndexEntriesDocument, parseIndexEntry, parseSourceRepositoryMetadata,
  SourceRepositoryMetadata, safeResolveIndexAssetUrl, SourceIndexMetadataCacheDocument, SourceIndexMetadataCacheRecord,
  SourceIndexEntry, SOURCE_INDEX_METADATA_RECORD_LIMIT, SOURCE_INDEX_METADATA_CACHE_LIMIT } from './SourceIndexMetadata'

// TaskPool entry points import their shared pure rules; no registry/UI imports.
@Concurrent
export function parseSourceIndexCacheTask(payload: Object): SourceIndexMetadataCacheRecord[] {
  return parseMetadataCache(payload)
}

@Concurrent
export function prepareSourceIndexCacheRecordTask(url: string, entries: SourceIndexEntry[]): SourceIndexMetadataCacheRecord | undefined {
  const metadata = parseCachedIndexEntries(entries as Object[], url)
  if (metadata === undefined) return undefined
  const record: SourceIndexMetadataCacheRecord = { url, entries: metadata }
  return JSON.stringify(record).length <= SOURCE_INDEX_METADATA_RECORD_LIMIT ? record : undefined
}

@Concurrent
export function encodeSourceIndexCacheTask(previous: Object, record: SourceIndexMetadataCacheRecord,
  repositoryLimit: number): string {
  const records = parseMetadataCache(previous).filter((item: SourceIndexMetadataCacheRecord): boolean => item.url !== record.url)
  records.unshift(record)
  const document: SourceIndexMetadataCacheDocument = { schemaVersion: 1, records: records.slice(0, repositoryLimit) }
  let payload = JSON.stringify(document)
  while (payload.length > SOURCE_INDEX_METADATA_CACHE_LIMIT && document.records.length > 1) {
    document.records.pop()
    payload = JSON.stringify(document)
  }
  return payload
}

@Concurrent
export function parseSourceIndexDocumentTask(body: string, indexUrl: string): SourceIndexMetadataParseResult {
  let parsed: Object[]
  let metadata: SourceRepositoryMetadata | undefined
  try {
    const raw = JSON.parse(body) as Object
    const document = parseIndexEntriesDocument(raw)
    metadata = parseSourceRepositoryMetadata(raw)
    if (document === undefined) return { ok: false, reasonCode: 'invalid_index_format', entries: [] }
    parsed = document
  } catch (_error) { return { ok: false, reasonCode: 'invalid_json', entries: [] } }
  const entries: SourceIndexEntry[] = []
  for (const value of parsed) {
    const entry = parseIndexEntry(value)
    if (entry === undefined) continue
    if (entry.icon.trim().length === 0) return { ok: false, reasonCode: 'missing_icon', entries: [] }
    if (safeResolveIndexAssetUrl(indexUrl, entry.icon).length === 0) return { ok: false, reasonCode: 'invalid_icon', entries: [] }
    entries.push(entry)
  }
  return { ok: true, entries, metadata }
}

export interface SourceIndexMetadataParseResult {
  ok: boolean
  reasonCode?: string
  entries: SourceIndexEntry[]
  metadata?: SourceRepositoryMetadata
}
