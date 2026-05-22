import {
  NativeSourceRuntime,
  SourceRuntimeCallRequest,
  SourceRuntimeCallResponse,
} from './NativeSourceRuntime'

export interface SourceRuntimeSearchFixtureSummary {
  response: SourceRuntimeCallResponse
  responseOk: boolean
  operation?: string
  requestEcho?: string
  firstTitle?: string
  network?: boolean
}

export interface SourceRuntimeApiOperationsSummary {
  ok: boolean
  operations: string[]
  evidence: string[]
}

export interface SourceRuntimeV02SurfaceSummary {
  ok: boolean
  sourceInfoOk: boolean
  coreOpsOk: boolean
  browseOpsOk: boolean
  settingsImageRefsOk: boolean
  networkFalse: boolean
  noSecretOrPathLeak: boolean
  operations: string[]
  unsupportedOperations: string[]
  evidence: string[]
}

export interface SourceRuntimeNegativeExecutionCaseSummary {
  id: string
  requestJson: string
  rejected: boolean
  didNotDefaultToSearch: boolean
  responseOk: boolean
  responseOperation?: string
  responseFirstTitle?: string
  error?: string
}

export interface SourceRuntimeNegativeExecutionSummary {
  ok: boolean
  cases: SourceRuntimeNegativeExecutionCaseSummary[]
  evidence: string[]
}

export interface SourceRuntimeSizeLimitNegativeCaseSummary {
  id: string
  rejected: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
  requestBytes?: number
  resultBytes?: number
  noRawPayloadOrPathLeak: boolean
}

export interface SourceRuntimeSizeLimitNegativeSummary {
  ok: boolean
  oversizedRequest: SourceRuntimeSizeLimitNegativeCaseSummary
  oversizedResult: SourceRuntimeSizeLimitNegativeCaseSummary
  malformedResult: SourceRuntimeSizeLimitNegativeCaseSummary
  stableReasonCodes: string[]
  noRawPayloadOrPathLeak: boolean
  evidence: string[]
}

export interface SourceRuntimeCancelTimeoutNegativeCaseSummary {
  id: string
  rejected: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
  noRawPayloadOrPathLeak: boolean
}

export interface SourceRuntimeCancelTimeoutNegativeSummary {
  ok: boolean
  cancelled: SourceRuntimeCancelTimeoutNegativeCaseSummary
  timeout: SourceRuntimeCancelTimeoutNegativeCaseSummary
  stableReasonCodes: string[]
  noRawPayloadOrPathLeak: boolean
  evidence: string[]
}

const SOURCE_API_OPERATION_REQUESTS: string[] = [
  '{"type":"request","version":1,"requestId":"device-search-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture","page":{"cursor":null,"limit":20},"filters":{"tags":["fixture"]}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-manga-001","operation":"get_manga","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-chapters-001","operation":"get_chapters","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series","page":{"cursor":null,"limit":100}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-pages-001","operation":"get_pages","sourceId":"local.test.koma.fixture","args":{"chapterId":"chapter:fixture-series:001"},"settings":{},"hostHints":{"network":false,"imageStrategy":"descriptor-only"}}',
]

const SOURCE_API_V02_OPERATION_REQUESTS: string[] = [
  '{"type":"request","version":1,"requestId":"device-source-info-001","operation":"source_info","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-search-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture","page":{"cursor":null,"limit":20},"filters":{"tags":["fixture"]}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-manga-001","operation":"get_manga","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-chapters-001","operation":"get_chapters","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series","page":{"cursor":null,"limit":100}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-pages-001","operation":"get_pages","sourceId":"local.test.koma.fixture","args":{"chapterId":"chapter:fixture-series:001"},"settings":{},"hostHints":{"network":false,"imageStrategy":"descriptor-only"}}',
  '{"type":"request","version":1,"requestId":"device-listings-001","operation":"get_listings","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-manga-list-001","operation":"get_manga_list","sourceId":"local.test.koma.fixture","args":{"listingId":"listing:popular","page":{"cursor":null,"limit":20},"filters":{}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-home-001","operation":"get_home","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-filters-001","operation":"get_filters","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-settings-001","operation":"get_settings","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-image-request-001","operation":"get_image_request","sourceId":"local.test.koma.fixture","args":{"pageId":"page:fixture-series:001:0001"},"settings":{},"hostHints":{"network":false}}',
]

function buildSourceApiOperationRequests(sourceId: string): string[] {
  const safeSourceId = sourceId.trim()
  return [
    `{"type":"request","version":1,"requestId":"device-search-001","operation":"search","sourceId":"${safeSourceId}","args":{"query":"fixture","page":{"cursor":null,"limit":20},"filters":{"tags":["fixture"]}},"settings":{},"hostHints":{"network":false}}`,
    `{"type":"request","version":1,"requestId":"device-manga-001","operation":"get_manga","sourceId":"${safeSourceId}","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}`,
    `{"type":"request","version":1,"requestId":"device-chapters-001","operation":"get_chapters","sourceId":"${safeSourceId}","args":{"mangaId":"manga:fixture-series","page":{"cursor":null,"limit":100}},"settings":{},"hostHints":{"network":false}}`,
    `{"type":"request","version":1,"requestId":"device-pages-001","operation":"get_pages","sourceId":"${safeSourceId}","args":{"chapterId":"chapter:fixture-series:001"},"settings":{},"hostHints":{"network":false,"imageStrategy":"descriptor-only"}}`,
  ]
}

const SOURCE_RUNTIME_NEGATIVE_EXECUTION_REQUESTS: string[] = [
  '{"type":"request","version":1,"requestId":"device-negative-unsupported-001","operation":"unknown_operation","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-negative-missing-operation-001","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-negative-non-string-operation-001","operation":123,"sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
]

const SOURCE_RUNTIME_MAX_PAYLOAD_BYTES: number = 1024 * 1024
const SOURCE_RUNTIME_OVERSIZED_RESULT_REQUEST: string =
  '{"type":"request","version":1,"requestId":"device-size-limit-result-001","operation":"test_oversized_result","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}'
const SOURCE_RUNTIME_MALFORMED_RESULT_REQUEST: string =
  '{"type":"request","version":1,"requestId":"device-size-limit-malformed-001","operation":"test_malformed_result","sourceId":"local.test.koma.fixture","args":{},"settings":{},"hostHints":{"network":false}}'
const SOURCE_RUNTIME_CANCEL_GUARD_REQUEST: string =
  '{"type":"request","version":1,"requestId":"device-cancel-guard-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false},"komaTestOnly":true,"testGuard":"cancel"}'
const SOURCE_RUNTIME_TIMEOUT_GUARD_REQUEST: string =
  '{"type":"request","version":1,"requestId":"device-timeout-guard-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false},"komaTestOnly":true,"testGuard":"timeout"}'

export function runBundledSourceOperation(request: SourceRuntimeCallRequest | string): SourceRuntimeCallResponse {
  return NativeSourceRuntime.runJsonCall(request)
}

export function runSourceOperationFromBytes(
  request: SourceRuntimeCallRequest | string,
  wasmBytes: Uint8Array,
): SourceRuntimeCallResponse {
  return NativeSourceRuntime.runJsonCallFromBytes(request, wasmBytes)
}

export function responseReachedFixture(response: SourceRuntimeCallResponse): boolean {
  return response.ok === true &&
    response.data !== undefined &&
    response.data.requestEcho === 'fixture' &&
    JSON.stringify(response).includes('Fixture Series')
}

export function responseReachedSearchFixture(response: SourceRuntimeCallResponse): boolean {
  return responseReachedFixture(response) &&
    response.operation === 'search' &&
    JSON.stringify(response).includes('"network":false')
}

export function firstItemTitle(response: SourceRuntimeCallResponse): string | undefined {
  const items = response.data?.items
  if (items === undefined || items.length === 0) {
    return undefined
  }
  const title = items[0]['title']
  return typeof title === 'string' ? title : undefined
}

export function runSearchFixtureFromBytes(
  request: SourceRuntimeCallRequest | string,
  wasmBytes: Uint8Array,
): SourceRuntimeSearchFixtureSummary {
  const response = runSourceOperationFromBytes(request, wasmBytes)
  return {
    response,
    responseOk: responseReachedSearchFixture(response),
    operation: response.operation,
    requestEcho: response.data?.requestEcho,
    firstTitle: firstItemTitle(response),
    network: response.hostHints?.['network'] === false ? false : undefined,
  }
}

function operationFromRequest(requestJson: string): string {
  const request = JSON.parse(requestJson) as SourceRuntimeCallRequest
  const operation = request['operation']
  return typeof operation === 'string' ? operation : ''
}

function includesEvidence(response: SourceRuntimeCallResponse, expected: string): boolean {
  return JSON.stringify(response).includes(expected)
}

function validateOperationResponse(operation: string, response: SourceRuntimeCallResponse): string[] {
  const evidence: string[] = []
  if (response.ok === true) {
    evidence.push('ok:true')
  }
  if (response.operation === operation) {
    evidence.push(`operation:${operation}`)
  }
  if (response.hostHints?.['network'] === false) {
    evidence.push('network:false')
  }
  if (operation === 'search' &&
    firstItemTitle(response) === 'Fixture Series' &&
    response.data?.requestEcho === 'fixture') {
    evidence.push('search:Fixture Series:fixture')
  }
  if (operation === 'get_manga' &&
    includesEvidence(response, 'Fixture Series') &&
    includesEvidence(response, 'manga:fixture-series')) {
    evidence.push('get_manga:manga:fixture-series:Fixture Series')
  }
  if (operation === 'get_chapters' &&
    includesEvidence(response, 'chapter:fixture-series:001') &&
    includesEvidence(response, 'Chapter 1')) {
    evidence.push('get_chapters:chapter:fixture-series:001:Chapter 1')
  }
  if (operation === 'get_pages' &&
    includesEvidence(response, 'chapter:fixture-series:001') &&
    includesEvidence(response, 'page:fixture-series:001:0001') &&
    includesEvidence(response, 'fixture-page-1') &&
    includesEvidence(response, 'placeholder')) {
    evidence.push('get_pages:chapter:fixture-series:001:page:fixture-series:001:0001:fixture-page-1')
  }
  if (operation === 'source_info' &&
    includesEvidence(response, '"sourceInfo"') &&
    includesEvidence(response, '"apiVersion":"0.2"') &&
    includesEvidence(response, '"capabilities"') &&
    includesEvidence(response, '"search":true') &&
    includesEvidence(response, '"imageRequest":true')) {
    evidence.push('source_info:apiVersion:0.2:capabilities')
  }
  if (operation === 'get_listings' &&
    includesEvidence(response, 'listing:popular') &&
    includesEvidence(response, 'listing:latest')) {
    evidence.push('get_listings:listing:popular:listing:latest')
  }
  if (operation === 'get_manga_list' &&
    includesEvidence(response, 'listing:popular') &&
    includesEvidence(response, 'Fixture Series')) {
    evidence.push('get_manga_list:listing:popular:Fixture Series')
  }
  if (operation === 'get_home' &&
    includesEvidence(response, 'home:featured') &&
    includesEvidence(response, 'home:latest-link')) {
    evidence.push('get_home:home:featured:home:latest-link')
  }
  if (operation === 'get_filters' &&
    includesEvidence(response, 'filter:query') &&
    includesEvidence(response, 'filter:sort')) {
    evidence.push('get_filters:filter:query:filter:sort')
  }
  if (operation === 'get_settings' &&
    includesEvidence(response, 'setting:language') &&
    includesEvidence(response, 'login:primary') &&
    !includesForbiddenCompactEvidence(response)) {
    evidence.push('get_settings:safe-setting-descriptors')
  }
  if (operation === 'get_image_request' &&
    includesEvidence(response, 'fixture-image:fixture-page-1') &&
    includesEvidence(response, 'headers:image:fixture-page-1') &&
    includesEvidence(response, 'credentials:image:primary') &&
    !includesForbiddenCompactEvidence(response)) {
    evidence.push('get_image_request:host-owned-refs')
  }
  return evidence
}

function includesForbiddenCompactEvidence(response: SourceRuntimeCallResponse): boolean {
  const raw = JSON.stringify(response)
  const lower = raw.toLowerCase()
  return raw.includes('/data/') ||
    raw.includes('/home/') ||
    raw.includes('file://') ||
    raw.includes('picker://') ||
    raw.includes('datashare://') ||
    lower.includes('authorization') ||
    lower.includes('cookie') ||
    lower.includes('password') ||
    lower.includes('rawtoken') ||
    lower.includes('bearer ')
}

function buildOversizedRequestJson(): string {
  const prefix = '{"type":"request","version":1,"requestId":"device-size-limit-request-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture","padding":"'
  const suffix = '"},"settings":{},"hostHints":{"network":false}}'
  const paddingBytes = SOURCE_RUNTIME_MAX_PAYLOAD_BYTES + 128 - prefix.length - suffix.length
  let padding = ''
  for (let index = 0; index < paddingBytes; index += 1) {
    padding += 'x'
  }
  return prefix + padding + suffix
}

function responseReasonCode(response: SourceRuntimeCallResponse): string | undefined {
  if (typeof response.reasonCode === 'string') {
    return response.reasonCode
  }
  const code = response.error?.['code']
  return typeof code === 'string' ? code : undefined
}

function responseHasNoRawPayloadOrPathLeak(response: SourceRuntimeCallResponse): boolean {
  const raw = JSON.stringify(response)
  return !raw.includes('/data/') &&
    !raw.includes('/home/') &&
    !raw.includes('/storage/') &&
    !raw.includes('/sdcard/') &&
    !raw.includes('.wasm') &&
    !raw.includes('.koma-source') &&
    !raw.includes('manifest') &&
    !raw.includes('wasmBytes') &&
    !raw.includes('padding') &&
    !raw.includes('xxxxxxxx') &&
    !raw.includes('local_source_runtime_fixture') &&
    !raw.includes('rust_source_runtime_fixture')
}

function summarizeSizeLimitNegativeCase(
  id: string,
  requestJson: string,
  wasmBytes: Uint8Array,
  expectedReasonCode: string,
  attemptedWamrExecution: boolean,
  resultBytes?: number,
): SourceRuntimeSizeLimitNegativeCaseSummary {
  try {
    const response = runSourceOperationFromBytes(requestJson, wasmBytes)
    const reasonCode = responseReasonCode(response)
    return {
      id,
      rejected: response.ok === false && reasonCode === expectedReasonCode,
      reasonCode,
      attemptedWamrExecution,
      requestBytes: requestJson.length,
      resultBytes,
      noRawPayloadOrPathLeak: responseHasNoRawPayloadOrPathLeak(response),
    }
  } catch (_err) {
    return {
      id,
      rejected: false,
      attemptedWamrExecution,
      requestBytes: requestJson.length,
      resultBytes,
      noRawPayloadOrPathLeak: false,
    }
  }
}

function summarizeCancelTimeoutNegativeCase(
  id: string,
  requestJson: string,
  wasmBytes: Uint8Array,
  expectedReasonCode: string,
  attemptedWamrExecution: boolean,
): SourceRuntimeCancelTimeoutNegativeCaseSummary {
  try {
    const response = runSourceOperationFromBytes(requestJson, wasmBytes)
    const reasonCode = responseReasonCode(response)
    return {
      id,
      rejected: response.ok === false && reasonCode === expectedReasonCode,
      reasonCode,
      attemptedWamrExecution,
      noRawPayloadOrPathLeak: responseHasNoRawPayloadOrPathLeak(response),
    }
  } catch (_err) {
    return {
      id,
      rejected: false,
      attemptedWamrExecution,
      noRawPayloadOrPathLeak: false,
    }
  }
}

export function runSourceApiFixtureOperationsFromBytes(wasmBytes: Uint8Array): SourceRuntimeApiOperationsSummary {
  return runSourceApiFixtureOperationsRequestsFromBytes(wasmBytes, SOURCE_API_OPERATION_REQUESTS)
}

export function runSourceApiFixtureOperationsForSourceIdFromBytes(
  wasmBytes: Uint8Array,
  sourceId: string,
): SourceRuntimeApiOperationsSummary {
  return runSourceApiFixtureOperationsRequestsFromBytes(wasmBytes, buildSourceApiOperationRequests(sourceId))
}

export function runSourceApiV02SurfaceFromBytes(wasmBytes: Uint8Array): SourceRuntimeV02SurfaceSummary {
  const operations: string[] = []
  const unsupportedOperations: string[] = []
  const evidence: string[] = []
  let sourceInfoOk = false
  let coreOpsOk = true
  let browseOpsOk = true
  let settingsImageRefsOk = true
  let networkFalse = true
  let noSecretOrPathLeak = true

  for (const requestJson of SOURCE_API_V02_OPERATION_REQUESTS) {
    const operation = operationFromRequest(requestJson)
    try {
      const response = runSourceOperationFromBytes(requestJson, wasmBytes)
      const operationEvidence = validateOperationResponse(operation, response)
      const operationOk = response.ok === true &&
        response.operation === operation &&
        response.hostHints?.['network'] === false &&
        !includesForbiddenCompactEvidence(response) &&
        operationEvidence.length >= 4
      operations.push(operation)
      evidence.push(`${operation}:${operationOk ? 'ok' : 'fail'}`)
      evidence.push(operationEvidence.length > 0 ? operationEvidence[operationEvidence.length - 1] : `${operation}:missing`)
      networkFalse = networkFalse && response.hostHints?.['network'] === false
      noSecretOrPathLeak = noSecretOrPathLeak && !includesForbiddenCompactEvidence(response)
      if (operation === 'source_info') {
        sourceInfoOk = operationOk
      } else if (operation === 'search' || operation === 'get_manga' ||
        operation === 'get_chapters' || operation === 'get_pages') {
        coreOpsOk = coreOpsOk && operationOk
      } else if (operation === 'get_listings' || operation === 'get_manga_list' ||
        operation === 'get_home' || operation === 'get_filters') {
        browseOpsOk = browseOpsOk && operationOk
      } else if (operation === 'get_settings' || operation === 'get_image_request') {
        settingsImageRefsOk = settingsImageRefsOk && operationOk
      }
    } catch (error) {
      const e = error as Error
      unsupportedOperations.push(operation)
      evidence.push(`${operation}:unsupported:${e.message}`)
      if (operation === 'source_info') {
        sourceInfoOk = false
      } else if (operation === 'search' || operation === 'get_manga' ||
        operation === 'get_chapters' || operation === 'get_pages') {
        coreOpsOk = false
      } else if (operation === 'get_listings' || operation === 'get_manga_list' ||
        operation === 'get_home' || operation === 'get_filters') {
        browseOpsOk = false
      } else if (operation === 'get_settings' || operation === 'get_image_request') {
        settingsImageRefsOk = false
      }
    }
  }

  const ok = sourceInfoOk &&
    coreOpsOk &&
    browseOpsOk &&
    settingsImageRefsOk &&
    networkFalse &&
    noSecretOrPathLeak &&
    unsupportedOperations.length === 0
  return {
    ok,
    sourceInfoOk,
    coreOpsOk,
    browseOpsOk,
    settingsImageRefsOk,
    networkFalse,
    noSecretOrPathLeak,
    operations,
    unsupportedOperations,
    evidence,
  }
}

function runSourceApiFixtureOperationsRequestsFromBytes(
  wasmBytes: Uint8Array,
  requests: string[],
): SourceRuntimeApiOperationsSummary {
  const operations: string[] = []
  const evidence: string[] = []
  let ok = true
  for (const requestJson of requests) {
    const operation = operationFromRequest(requestJson)
    const response = runSourceOperationFromBytes(requestJson, wasmBytes)
    const operationEvidence = validateOperationResponse(operation, response)
    const responseOk = response.ok === true &&
      response.operation === operation &&
      response.hostHints?.['network'] === false &&
      operationEvidence.length >= 4
    operations.push(operation)
    evidence.push(`${operation}:${responseOk ? 'ok' : 'fail'}`)
    evidence.push(operationEvidence.length > 0 ? operationEvidence[operationEvidence.length - 1] : `${operation}:missing`)
    ok = ok && responseOk
  }
  return {
    ok: operations.length === 4 && ok,
    operations,
    evidence,
  }
}

function negativeExecutionCaseId(requestJson: string): string {
  if (requestJson.includes('"requestId":"device-negative-missing-operation-001"')) {
    return 'missing_operation'
  }
  const request = JSON.parse(requestJson) as SourceRuntimeCallRequest
  const operation = request['operation']
  if (typeof operation !== 'string') {
    return 'non_string_operation'
  }
  return operation === 'unknown_operation' ? 'unsupported_operation' : `unsupported_${operation}`
}

function summarizeNegativeExecutionCase(
  requestJson: string,
  wasmBytes: Uint8Array,
): SourceRuntimeNegativeExecutionCaseSummary {
  const id = negativeExecutionCaseId(requestJson)
  try {
    const response = runSourceOperationFromBytes(requestJson, wasmBytes)
    const defaultedToSearchFixture = responseReachedSearchFixture(response)
    const responseOk = response.ok === true
    return {
      id,
      requestJson,
      rejected: !responseOk,
      didNotDefaultToSearch: !defaultedToSearchFixture,
      responseOk,
      responseOperation: response.operation,
      responseFirstTitle: firstItemTitle(response),
    }
  } catch (error) {
    const e = error as Error
    return {
      id,
      requestJson,
      rejected: true,
      didNotDefaultToSearch: true,
      responseOk: false,
      error: e.message,
    }
  }
}

export function runSourceRuntimeNegativeExecutionFromBytes(
  wasmBytes: Uint8Array,
): SourceRuntimeNegativeExecutionSummary {
  const cases: SourceRuntimeNegativeExecutionCaseSummary[] = []
  const evidence: string[] = []
  let ok = true
  for (const requestJson of SOURCE_RUNTIME_NEGATIVE_EXECUTION_REQUESTS) {
    const caseSummary = summarizeNegativeExecutionCase(requestJson, wasmBytes)
    const caseOk = caseSummary.rejected &&
      caseSummary.didNotDefaultToSearch &&
      caseSummary.responseOk === false
    cases.push(caseSummary)
    evidence.push(`${caseSummary.id}:${caseOk ? 'rejected' : 'failed-open'}`)
    ok = ok && caseOk
  }
  return {
    ok: cases.length === 3 && ok,
    cases,
    evidence,
  }
}

export function runSourceRuntimeSizeLimitNegativesFromBytes(
  wasmBytes: Uint8Array,
): SourceRuntimeSizeLimitNegativeSummary {
  const oversizedRequestJson = buildOversizedRequestJson()
  const oversizedRequest = summarizeSizeLimitNegativeCase(
    'oversized_request',
    oversizedRequestJson,
    wasmBytes,
    'request_too_large',
    false,
  )
  const oversizedResult = summarizeSizeLimitNegativeCase(
    'oversized_result',
    SOURCE_RUNTIME_OVERSIZED_RESULT_REQUEST,
    wasmBytes,
    'result_too_large',
    true,
    SOURCE_RUNTIME_MAX_PAYLOAD_BYTES + 1,
  )
  const malformedResult = summarizeSizeLimitNegativeCase(
    'malformed_result',
    SOURCE_RUNTIME_MALFORMED_RESULT_REQUEST,
    wasmBytes,
    'malformed_result',
    true,
  )
  const stableReasonCodes = [
    oversizedRequest.reasonCode ?? '',
    oversizedResult.reasonCode ?? '',
    malformedResult.reasonCode ?? '',
  ].filter((item: string) => item.length > 0)
  const noRawPayloadOrPathLeak = oversizedRequest.noRawPayloadOrPathLeak &&
    oversizedResult.noRawPayloadOrPathLeak &&
    malformedResult.noRawPayloadOrPathLeak
  const ok = oversizedRequest.rejected &&
    oversizedRequest.attemptedWamrExecution === false &&
    oversizedResult.rejected &&
    oversizedResult.attemptedWamrExecution === true &&
    malformedResult.rejected &&
    malformedResult.attemptedWamrExecution === true &&
    stableReasonCodes.includes('request_too_large') &&
    stableReasonCodes.includes('result_too_large') &&
    stableReasonCodes.includes('malformed_result') &&
    noRawPayloadOrPathLeak
  return {
    ok,
    oversizedRequest,
    oversizedResult,
    malformedResult,
    stableReasonCodes,
    noRawPayloadOrPathLeak,
    evidence: [
      `oversized_request:${oversizedRequest.reasonCode ?? 'missing'}:${oversizedRequest.rejected ? 'rejected' : 'failed-open'}`,
      `oversized_result:${oversizedResult.reasonCode ?? 'missing'}:${oversizedResult.rejected ? 'rejected' : 'failed-open'}`,
      `malformed_result:${malformedResult.reasonCode ?? 'missing'}:${malformedResult.rejected ? 'rejected' : 'failed-open'}`,
      `no_raw_payload_or_path_leak:${noRawPayloadOrPathLeak ? 'ok' : 'fail'}`,
    ],
  }
}

export function runSourceRuntimeCancelTimeoutNegativesFromBytes(
  wasmBytes: Uint8Array,
): SourceRuntimeCancelTimeoutNegativeSummary {
  const cancelled = summarizeCancelTimeoutNegativeCase(
    'cancelled_guard',
    SOURCE_RUNTIME_CANCEL_GUARD_REQUEST,
    wasmBytes,
    'cancelled',
    true,
  )
  const timeout = summarizeCancelTimeoutNegativeCase(
    'timeout_guard',
    SOURCE_RUNTIME_TIMEOUT_GUARD_REQUEST,
    wasmBytes,
    'timeout',
    false,
  )
  const stableReasonCodes = [
    cancelled.reasonCode ?? '',
    timeout.reasonCode ?? '',
  ].filter((item: string) => item.length > 0)
  const noRawPayloadOrPathLeak = cancelled.noRawPayloadOrPathLeak && timeout.noRawPayloadOrPathLeak
  const ok = cancelled.rejected &&
    cancelled.attemptedWamrExecution === true &&
    timeout.rejected &&
    timeout.attemptedWamrExecution === false &&
    stableReasonCodes.includes('cancelled') &&
    stableReasonCodes.includes('timeout') &&
    noRawPayloadOrPathLeak
  return {
    ok,
    cancelled,
    timeout,
    stableReasonCodes,
    noRawPayloadOrPathLeak,
    evidence: [
      `cancelled_guard:${cancelled.reasonCode ?? 'missing'}:${cancelled.rejected ? 'rejected' : 'failed-open'}`,
      `timeout_guard:${timeout.reasonCode ?? 'missing'}:${timeout.rejected ? 'rejected' : 'failed-open'}`,
      `no_raw_payload_or_path_leak:${noRawPayloadOrPathLeak ? 'ok' : 'fail'}`,
    ],
  }
}
