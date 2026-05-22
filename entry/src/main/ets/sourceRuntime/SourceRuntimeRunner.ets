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

const SOURCE_API_OPERATION_REQUESTS: string[] = [
  '{"type":"request","version":1,"requestId":"device-search-001","operation":"search","sourceId":"local.test.koma.fixture","args":{"query":"fixture","page":{"cursor":null,"limit":20},"filters":{"tags":["fixture"]}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-manga-001","operation":"get_manga","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-chapters-001","operation":"get_chapters","sourceId":"local.test.koma.fixture","args":{"mangaId":"manga:fixture-series","page":{"cursor":null,"limit":100}},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-pages-001","operation":"get_pages","sourceId":"local.test.koma.fixture","args":{"chapterId":"chapter:fixture-series:001"},"settings":{},"hostHints":{"network":false,"imageStrategy":"descriptor-only"}}',
]

const SOURCE_RUNTIME_NEGATIVE_EXECUTION_REQUESTS: string[] = [
  '{"type":"request","version":1,"requestId":"device-negative-unsupported-001","operation":"unknown_operation","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-negative-missing-operation-001","sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  '{"type":"request","version":1,"requestId":"device-negative-non-string-operation-001","operation":123,"sourceId":"local.test.koma.fixture","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
]

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
  return evidence
}

export function runSourceApiFixtureOperationsFromBytes(wasmBytes: Uint8Array): SourceRuntimeApiOperationsSummary {
  const operations: string[] = []
  const evidence: string[] = []
  let ok = true
  for (const requestJson of SOURCE_API_OPERATION_REQUESTS) {
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
