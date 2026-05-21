import { Want } from '@kit.AbilityKit'
import { NativeSourceRuntime, SourceRuntimeCallResponse } from './NativeSourceRuntime'

const SMOKE_TRIGGER_PARAM: string = 'koma.sourceRuntimeSmoke'
const SMOKE_TRIGGER_VALUE: string = 'run'
const SMOKE_REQUEST_JSON: string = '{"query":"fixture","smoke":"koma-smoke"}'
const SMOKE_LOG_PREFIX: string = 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT '

type WantParameterValue = Object | string | number | boolean | null | undefined
type WantParameters = Record<string, WantParameterValue>

export interface SourceRuntimeSmokeResult {
  ok: boolean
  route: string
  requestJson: string
  response?: SourceRuntimeCallResponse
  error?: string
}

function wantParameters(want: Want): WantParameters {
  const rawParameters = want.parameters as WantParameters | undefined
  return rawParameters === undefined ? {} : rawParameters
}

function hasSmokeTrigger(want: Want): boolean {
  const parameters = wantParameters(want)
  return parameters[SMOKE_TRIGGER_PARAM] === SMOKE_TRIGGER_VALUE
}

function responseReachedFixture(response: SourceRuntimeCallResponse): boolean {
  return response.ok === true &&
    response.data !== undefined &&
    response.data.requestEcho === 'fixture' &&
    JSON.stringify(response).includes('Fixture Series')
}

export function maybeRunSourceRuntimeDeviceSmoke(want: Want): void {
  if (!hasSmokeTrigger(want)) {
    return
  }

  const result: SourceRuntimeSmokeResult = {
    ok: false,
    route: 'entryability-want-test-only',
    requestJson: SMOKE_REQUEST_JSON,
  }

  try {
    const response = NativeSourceRuntime.runJsonCall(SMOKE_REQUEST_JSON)
    result.response = response
    result.ok = responseReachedFixture(response)
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
