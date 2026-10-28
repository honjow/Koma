import { AppStrings } from '../i18n/AppStrings'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'

export interface SourceFailureDetails {
  reason: string
  code: string
  status: number
  kind: string
}

const SOURCE_FAILURE_CODES: string[] = [
  'timeout', 'network_error', 'http_error', 'region_restricted', 'permission_denied', 'challenge_required', 'auth_required',
  'unauthorized', 'forbidden', 'rate_limited', 'rate_limit', 'not_found', 'server_error', 'client_error', 'parse_error',
  'invalid_response', 'invalid_json', 'malformed_result', 'result_too_large', 'request_too_large',
  'source_disabled', 'source_changed', 'source_id_not_registered', 'wasm_missing', 'unsupported',
  'unsupported_operation', 'not_implemented', 'not_supported', 'wamr_runtime_error', 'runtime_error', 'source_worker_failed',
  'wasm_load_failed', 'wasm_instantiate_failed', 'wasm_environment_failed', 'missing_export',
  'wasm_call_failed', 'source_init_failed',
]

function knownCode(raw: Object | string | number | boolean | null | undefined): string {
  if (typeof raw !== 'string') return 'unknown'
  const code = raw.trim().toLowerCase()
  return SOURCE_FAILURE_CODES.includes(code) ? code : 'unknown'
}

export function sourceFailureDetails(response: SourceRuntimeCallResponse): SourceFailureDetails {
  const reason = knownCode(response.reasonCode)
  const code = knownCode(response.error?.['code'])
  const candidates = [code, reason]
  let status = 0
  const statusValue = response.error?.['status'] ?? response.error?.['statusCode'] ?? response.error?.['responseCode']
  if (typeof statusValue === 'number' && Number.isInteger(statusValue) && statusValue >= 400 && statusValue <= 599) {
    status = statusValue
  }
  if (status === 0) {
    const message = response.error?.['message']
    if (typeof message === 'string') {
      const match = /\b(?:HTTP(?:\s+status)?|status(?:Code)?|responseCode)\s*[:=]?\s*([45][0-9]{2})\b/i.exec(message)
      if (match !== null) status = Number(match[1])
    }
  }
  let kind = 'runtime'
  if (candidates.includes('challenge_required')) kind = 'challenge'
  else if (status === 401 || status === 403 || candidates.some((item: string): boolean =>
    ['permission_denied', 'challenge_required', 'auth_required', 'unauthorized', 'forbidden'].includes(item))) kind = 'access'
  else if (status === 429 || candidates.some((item: string): boolean => ['rate_limited', 'rate_limit'].includes(item))) kind = 'rate_limit'
  else if (status === 404 || candidates.includes('not_found')) kind = 'not_found'
  else if (status >= 500 || candidates.includes('server_error')) kind = 'server'
  else if ((status === 0 || status === 400) && candidates.includes('region_restricted')) kind = 'region'
  else if (candidates.includes('timeout')) kind = 'timeout'
  else if (candidates.some((item: string): boolean => ['network_error', 'http_error', 'client_error'].includes(item))) kind = 'network'
  else if (candidates.some((item: string): boolean =>
    ['parse_error', 'invalid_response', 'invalid_json', 'malformed_result'].includes(item))) kind = 'parse'
  else if (candidates.some((item: string): boolean => ['request_too_large', 'result_too_large'].includes(item))) kind = 'capacity'
  else if (candidates.some((item: string): boolean =>
    ['source_disabled', 'source_id_not_registered', 'wasm_missing'].includes(item))) kind = 'unavailable'
  else if (candidates.some((item: string): boolean => ['unsupported', 'unsupported_operation', 'not_implemented', 'not_supported'].includes(item))) kind = 'unsupported'
  else if (candidates.includes('wasm_load_failed') || candidates.includes('missing_export')) kind = 'load'
  else if (candidates.some((item: string): boolean =>
    ['wasm_instantiate_failed', 'wasm_environment_failed', 'source_init_failed'].includes(item))) kind = 'init'
  else if (candidates.includes('wasm_call_failed')) kind = 'execute'
  return { reason, code, status, kind }
}

export function sourceFailureText(details: SourceFailureDetails): string {
  const text = AppStrings.get('source_failure_' + details.kind)
  return details.status > 0 ? AppStrings.format('source_failure_http', text, details.status) : text
}

export class SourceRuntimeError extends Error {
  readonly diagnostic: SourceFailureDetails
  readonly userText: string
  readonly challengeRequestId: string | undefined

  constructor(response: SourceRuntimeCallResponse) {
    const diagnostic = sourceFailureDetails(response)
    const userText = sourceFailureText(diagnostic)
    super(userText)
    this.name = 'SourceRuntimeError'
    this.diagnostic = diagnostic
    this.userText = userText
    const challengeRequestId = response.error?.['challengeRequestId']
    this.challengeRequestId = typeof challengeRequestId === 'string' && challengeRequestId.length <= 64 ? challengeRequestId : undefined
  }
}
