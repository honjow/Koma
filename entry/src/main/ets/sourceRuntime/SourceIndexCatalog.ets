import { SourceIndexEntry, SourceIndexMetadataCacheRecord, entryWithCachedIcon } from './SourceIndexMetadata'

// Each chosen version travels with its repository. An active subscription in an
// editor must never redirect an unrelated package's relative download URL.
export function mergeSourceIndexCatalog(records: SourceIndexMetadataCacheRecord[],
  compareVersion: (left: string, right: string) => number,
  supported: (entry: SourceIndexEntry) => boolean = (): boolean => true): SourceIndexEntry[] {
  const chosen = new Map<string, SourceIndexEntry>()
  const offers = new Map<string, SourceIndexEntry[]>()
  records.forEach((record: SourceIndexMetadataCacheRecord): void => {
    record.entries.forEach((entry: SourceIndexEntry): void => {
      const previous = chosen.get(entry.id)
      const candidate = entryWithCachedIcon(entry, entry.iconUri ?? '')
      candidate.repositoryUrl = record.url
      const versions = offers.get(entry.id) ?? []
      versions.push(candidate)
      offers.set(entry.id, versions)
      const order = previous === undefined ? 1 : Number(supported(entry)) - Number(supported(previous)) ||
        compareVersion(entry.version, previous.version)
      if (previous === undefined || order > 0 ||
        (order === 0 && entry.icon.trim().length > 0 && previous.icon.trim().length === 0)) {
        chosen.set(entry.id, candidate)
      }
    })
  })
  chosen.forEach((entry: SourceIndexEntry, id: string): void => {
    const sameVersion = (offers.get(id) ?? []).filter((offer: SourceIndexEntry): boolean =>
      offer.version === entry.version && offer.sha256.length > 0)
    if (new Set(sameVersion.map((offer: SourceIndexEntry): string => offer.sha256)).size > 1)
      entry.conflictingRepositories = sameVersion.map((offer: SourceIndexEntry): string => offer.repositoryUrl ?? '')
  })
  return Array.from(chosen.values())
}
