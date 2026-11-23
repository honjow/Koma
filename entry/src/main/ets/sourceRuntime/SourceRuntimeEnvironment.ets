import { connectLanguageState } from '../state/LanguageState'
import { normalizeSourceEnvironment, sourceEnvironmentForLocale } from './SourceLocale'

/** Calling-runtime only. Never import UI state into SourceHostFeatures/Worker. */
export function sourceRequestWithEnvironment(requestJson: string): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    if (request === null || Array.isArray(request) || request['type'] !== 'request' ||
      typeof request['operation'] !== 'string' || request['operation'] === 'source_info') return requestJson
    // An original interaction retry or queued cover fallback keeps its snapshot.
    // Unknown versions are not rewritten into a newly authorized environment.
    if (request['environment'] !== undefined) return requestJson
    const environment = sourceEnvironmentForLocale(connectLanguageState().effectiveLocale)
    if (environment === undefined) return requestJson
    request['environment'] = environment
    return JSON.stringify(request)
  } catch (_error) { return requestJson }
}

export function sourceRuntimeLocale(): string {
  return sourceEnvironmentForLocale(connectLanguageState().effectiveLocale)?.uiLocale ?? ''
}

export function sourceRequestLocale(requestJson: string): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    return normalizeSourceEnvironment(request['environment'])?.uiLocale ?? ''
  } catch (_error) { return '' }
}
