import { parseMetadataCache, parseIndexEntriesDocument, parseIndexEntry, safeResolveIndexAssetUrl, SourceIndexMetadataCacheRecord, SourceIndexEntry } from './SourceIndexMetadata'

// TaskPool entry points import their shared pure rules; no registry/UI imports.
@Concurrent
export function parseSourceIndexCacheTask(payload: Object): SourceIndexMetadataCacheRecord[] {
  return parseMetadataCache(payload)
}

@Concurrent
export function parseSourceIndexDocumentTask(body: string, indexUrl: string): SourceIndexMetadataParseResult {
  let parsed: Object[]
  try {
    const document = parseIndexEntriesDocument(JSON.parse(body) as Object)
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
  return { ok: true, entries }
}

export interface SourceIndexMetadataParseResult {
  ok: boolean
  reasonCode?: string
  entries: SourceIndexEntry[]
}
