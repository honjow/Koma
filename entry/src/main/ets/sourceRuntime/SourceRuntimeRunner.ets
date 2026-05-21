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
