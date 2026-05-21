import { Want } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { NativeSourceRuntime, SourceRuntimeCallResponse } from './NativeSourceRuntime'

const SMOKE_TRIGGER_PARAM: string = 'koma.sourceRuntimeSmoke'
const SMOKE_TRIGGER_VALUE: string = 'run'
const SMOKE_REQUEST_JSON: string = '{"query":"fixture","smoke":"koma-smoke"}'
const SMOKE_LOG_PREFIX: string = 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT '
const SMOKE_RAWFILE_PATH: string = 'test/source_runtime_fixture.wasm'

type WantParameterValue = Object | string | number | boolean | null | undefined
type WantParameters = Record<string, WantParameterValue>

export interface SourceRuntimeSmokeResult {
  ok: boolean
  route: string
  requestJson: string
  rawfilePath?: string
  rawfileBytes?: number
  response?: SourceRuntimeCallResponse
  resourceResponse?: SourceRuntimeCallResponse
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

export function maybeRunSourceRuntimeDeviceSmoke(want: Want, resourceMgr?: resourceManager.ResourceManager): void {
  if (!hasSmokeTrigger(want)) {
    return
  }

  const result: SourceRuntimeSmokeResult = {
    ok: false,
    route: 'entryability-want-test-only',
    requestJson: SMOKE_REQUEST_JSON,
    rawfilePath: SMOKE_RAWFILE_PATH,
  }

  try {
    const response = NativeSourceRuntime.runJsonCall(SMOKE_REQUEST_JSON)
    result.response = response
    let resourceResponse: SourceRuntimeCallResponse | undefined = undefined
    if (resourceMgr !== undefined) {
      const wasmBytes = resourceMgr.getRawFileContentSync(SMOKE_RAWFILE_PATH)
      result.rawfileBytes = wasmBytes.byteLength
      resourceResponse = NativeSourceRuntime.runJsonCallFromBytes(SMOKE_REQUEST_JSON, wasmBytes)
      result.resourceResponse = resourceResponse
    }
    result.ok = responseReachedFixture(response) &&
      resourceResponse !== undefined &&
      responseReachedFixture(resourceResponse)
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled and rawfile byte paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
