import { SourceIndexEntry, SourceIndexMetadataCacheRecord, entryWithCachedIcon } from './SourceIndexMetadata'

// Each chosen version travels with its repository. An active subscription in an
// editor must never redirect an unrelated package's relative download URL.
export function mergeSourceIndexCatalog(records: SourceIndexMetadataCacheRecord[],
  compareVersion: (left: string, right: string) => number): SourceIndexEntry[] {
  const chosen = new Map<string, SourceIndexEntry>()
  records.forEach((record: SourceIndexMetadataCacheRecord): void => {
    record.entries.forEach((entry: SourceIndexEntry): void => {
      const previous = chosen.get(entry.id)
      const order = previous === undefined ? 1 : compareVersion(entry.version, previous.version)
      if (previous === undefined || order > 0 ||
        (order === 0 && entry.icon.trim().length > 0 && previous.icon.trim().length === 0)) {
        const candidate = entryWithCachedIcon(entry, entry.iconUri ?? '')
        candidate.repositoryUrl = record.url
        chosen.set(entry.id, candidate)
      }
    })
  })
  return Array.from(chosen.values())
}
