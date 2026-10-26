/** The NextE processing logs use bounded owner hashes, never page/work identities. */
export function readerProcessingOwnerHash(value: string): string {
  const clean = (value || '').trim()
  if (clean.length === 0) return ''
  let hash = 2166136261
  for (let index = 0; index < clean.length; index += 1) {
    hash ^= clean.charCodeAt(index)
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return `${clean.length}:${hash.toString(16)}`
}
