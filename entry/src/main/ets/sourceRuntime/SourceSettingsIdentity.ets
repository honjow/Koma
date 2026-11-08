import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { SourceSettingsRecord } from './SourceSettingsStore'

/** A page plan belongs to the exact source preference snapshot that produced it.
 * Keep empty legacy settings compatible without refreshing every cached book.
 * Persist only a digest, never another copy of settings or credentials.
 */
export function sourceSettingsFingerprint(values: SourceSettingsRecord): string {
  const keys = Object.keys(values).sort()
  if (keys.length === 0) return ''
  const entries: Object[] = keys.map((key: string): Object => [key, values[key]])
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new util.TextEncoder().encodeInto(JSON.stringify(entries)) })
  return Array.from(digest.digestSync().data)
    .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}

/** A prepared page plan is owned by the exact source package installation as
 * well as the preference snapshot. Updating the package can change page URLs,
 * expiring tickets and request headers, so settings alone cannot validate it. */
export function sourcePagePlanFingerprint(values: SourceSettingsRecord, packageIdentity: string): string {
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new util.TextEncoder().encodeInto(packageIdentity + '\n' + sourceSettingsFingerprint(values)) })
  return Array.from(digest.digestSync().data)
    .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}
