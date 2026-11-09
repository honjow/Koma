/** The execution key comes only from the host-created HTTP context. */
export function sourceRuntimeExecutionSourceId(httpContextJson: string): string {
  try {
    const value = JSON.parse(httpContextJson) as Record<string, Object>
    return value !== null && !Array.isArray(value) && typeof value['sourceId'] === 'string'
      ? value['sourceId'] as string : ''
  } catch (_error) {
    return ''
  }
}

/** Only the host-created unified-search context enables request correlation. */
export function sourceRuntimeExecutionHasGuard(httpContextJson: string): boolean {
  try {
    const value = JSON.parse(httpContextJson) as Record<string, Object>
    return typeof value['operationGuardId'] === 'string' && (value['operationGuardId'] as string).length > 0
  } catch (_error) { return false }
}

export function sourceRuntimeExecutionHasDetailChapterContext(httpContextJson: string): boolean {
  try {
    const value = JSON.parse(httpContextJson) as Record<string, Object>
    return value['detailChapterContext'] === true
  } catch (_error) { return false }
}


export function sourceRuntimeExecutionHasRequestLimits(httpContextJson: string): boolean {
  try { return (JSON.parse(httpContextJson) as Record<string, Object>)['requestLimitsDeclared'] === true }
  catch (_error) { return false }
}

export const UNAVAILABLE_SOURCE_MANIFEST: string = '{"ok":false,"reasonCode":"source_manifest_unavailable"}'

export function sourceRuntimeExecutionManifestUnavailable(httpContextJson: string): boolean {
  try { return (JSON.parse(httpContextJson) as Record<string, Object>)['packageManifestUnavailable'] === true }
  catch (_error) { return false }
}

export function sourceRuntimeExecutionHasDnsBootstrap(httpContextJson: string): boolean {
  try { return (JSON.parse(httpContextJson) as Record<string, Object>)['dnsBootstrapDeclared'] === true }
  catch (_error) { return false }
}
