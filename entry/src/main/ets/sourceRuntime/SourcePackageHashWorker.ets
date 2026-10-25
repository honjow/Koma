import { cryptoFramework } from '@kit.CryptoArchitectureKit'

// TaskPool loads transitive imports on its worker. Keep this entry Crypto-only:
// Importer and registry also own platform/UI state and must not be imported here.
// The synchronous restore validator uses the same digest primitive directly.
@Concurrent
export function computeSourcePackageSha256(bytes: Uint8Array): string {
  const startedAt = Date.now()
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: bytes })
  const digest = md.digestSync().data
  let result = ''
  for (let index = 0; index < digest.length; index += 1) {
    result += digest[index].toString(16).padStart(2, '0')
  }
  // Bounded operational evidence only: no paths, source IDs or digest values.
  console.info('[SourcePackageHash] step=digest_done bytes=' + bytes.byteLength +
    ' durationMs=' + Math.max(0, Date.now() - startedAt))
  return result
}
