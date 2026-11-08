/**
 * A cover is a small, disposable request. Retry one transient failure after a
 * short delay, but never turn authentication, quota, missing-content or source
 * contract failures into repeated network traffic.
 */
export const COVER_IMAGE_AUTOMATIC_RETRY_DELAY_MS: number = 1200
const COVER_IMAGE_AUTOMATIC_RETRY_LIMIT: number = 1

const RETRYABLE_TRANSPORT_CODES: string[] = [
  '2300006', '2300007', '2300018', '2300028', '2300052', '2300055', '2300056', '2300999', 'unknown',
]
const RETRYABLE_HTTP_STATUSES: number[] = [408, 425, 429, 500, 502, 503, 504]
const RETRYABLE_SOURCE_KINDS: string[] = ['timeout', 'network', 'server', 'rate_limit']

interface CoverFailureDiagnostic {
  kind?: string
  status?: number
}

interface CoverFailureWithDiagnostic extends Error {
  code?: number | string
  diagnostic?: CoverFailureDiagnostic
}

export function coverImageFailureRetryable(error: Error): boolean {
  const failure = error as CoverFailureWithDiagnostic
  const sourceKind = failure.diagnostic?.kind ?? ''
  if (sourceKind.length > 0) return RETRYABLE_SOURCE_KINDS.includes(sourceKind)

  const code = failure.code === undefined ? '' : String(failure.code)
  if (RETRYABLE_TRANSPORT_CODES.includes(code)) return true

  const httpStatus = /^(?:reader_remote_image|cover_image)_http_(\d+)$/.exec(error.message)
  if (httpStatus !== null) return RETRYABLE_HTTP_STATUSES.includes(Number(httpStatus[1]))

  const transport = /^(?:reader_remote_image|cover_image)_fetch_failed_(.+)$/.exec(error.message)
  return transport !== null && RETRYABLE_TRANSPORT_CODES.includes(transport[1])
}

/** Negative means no further automatic attempt. completedRetries starts at zero. */
export function coverImageAutomaticRetryDelayMs(error: Error, completedRetries: number,
  decodedCacheFailure: boolean = false): number {
  if (completedRetries < 0 || completedRetries >= COVER_IMAGE_AUTOMATIC_RETRY_LIMIT ||
    (!decodedCacheFailure && !coverImageFailureRetryable(error))) return -1
  return COVER_IMAGE_AUTOMATIC_RETRY_DELAY_MS
}
