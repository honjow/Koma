import { common, Want } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import {
  SourceArchiveNegativeCaseFixture,
  SourceArchiveNegativeImportResult,
} from './SourcePackageImporter'
import {
  importAndRunLocalSourceArchive,
  importArchiveNegativeFixturesWithoutExecution,
  runStagedRawfileSourcePackage,
  SourceRuntimeServiceRunSummary,
} from './SourceRuntimeService'
import {
  responseReachedFixture,
  runBundledSourceOperation,
  runSourceApiFixtureOperationsFromBytes,
  runSearchFixtureFromBytes,
  runSourceOperationFromBytes,
  SourceRuntimeApiOperationsSummary,
  SourceRuntimeNegativeExecutionCaseSummary,
} from './SourceRuntimeRunner'

const SMOKE_TRIGGER_PARAM: string = 'koma.sourceRuntimeSmoke'
const SMOKE_TRIGGER_VALUE: string = 'run'
const SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-smoke"}'
const RUST_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-rust-smoke"}'
const PACKAGE_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-package-smoke"}'
const SMOKE_LOG_PREFIX: string = 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT '
const SMOKE_RAWFILE_PATH: string = 'test/source_runtime_fixture.wasm'
const RUST_SMOKE_RAWFILE_PATH: string = 'test/rust_source_runtime_fixture.wasm'
const PACKAGE_ROUTE_LABEL: string = 'app-local-source-package-test-only'
const ARCHIVE_ROUTE_LABEL: string = 'app-local-source-archive-import-test-only'
const ARCHIVE_RAWFILE_PATH: string = 'test/local_source_runtime_fixture.koma-source'
const ARCHIVE_SANDBOX_ZIP_FILE: string = 'local_source_runtime_fixture.zip'
const ARCHIVE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-archive-smoke"}'
const ARCHIVE_NEGATIVE_ROUTE_LABEL: string = 'app-local-source-archive-negative-test-only'
const ARCHIVE_NEGATIVE_CASES: SourceArchiveNegativeCaseFixture[] = [
  {
    id: 'checksum_mismatch',
    rawfilePath: 'test/archive-negative/checksum_mismatch.koma-source',
    expectedReason: 'checksum_mismatch',
  },
  {
    id: 'network_not_allowed',
    rawfilePath: 'test/archive-negative/network_not_allowed.koma-source',
    expectedReason: 'network_not_allowed',
  },
  {
    id: 'unsafe_archive_entry',
    rawfilePath: 'test/archive-negative/unsafe_archive_entry.koma-source',
    expectedReason: 'unsafe_archive_entry',
  },
  {
    id: 'missing_manifest',
    rawfilePath: 'test/archive-negative/missing_manifest.koma-source',
    expectedReason: 'missing_manifest',
  },
  {
    id: 'missing_wasm',
    rawfilePath: 'test/archive-negative/missing_wasm.koma-source',
    expectedReason: 'missing_wasm',
  },
]

type WantParameterValue = Object | string | number | boolean | null | undefined
type WantParameters = Record<string, WantParameterValue>

export interface SourceArchiveNegativeCaseEvidence {
  id: string
  reasonCode?: string
  reasonMatchesExpected: boolean
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeExecutionNegativeCaseEvidence {
  route: string
  id: string
  rejected: boolean
  didNotDefaultToSearch: boolean
  responseOk: boolean
  responseOperation?: string
  responseFirstTitle?: string
  error?: string
}

export interface SourceRuntimeSmokeResult {
  ok: boolean
  route: string
  requestJson: string
  rawfilePath?: string
  rawfileBytes?: number
  rustRequestJson?: string
  rustRawfilePath?: string
  rustRawfileBytes?: number
  response?: SourceRuntimeCallResponse
  responseOk?: boolean
  resourceResponse?: SourceRuntimeCallResponse
  resourceResponseOk?: boolean
  rustSourceResponse?: SourceRuntimeCallResponse
  rustSourceResponseOk?: boolean
  rustSourceApiOperationsOk?: boolean
  rustSourceApiOperations?: SourceRuntimeApiOperationsSummary
  packageResponse?: SourceRuntimeCallResponse
  packageResponseOk?: boolean
  packageSourceApiOperationsOk?: boolean
  packageSourceApiOperations?: SourceRuntimeApiOperationsSummary
  packageOperation?: string
  packageRequestEcho?: string
  packageFirstTitle?: string
  packageNetwork?: boolean
  packageWasmBytes?: number
  packageManifestId?: string
  packageManifestVersion?: string
  packageManifestPath?: string
  packageWasmPath?: string
  packageHashOk?: boolean
  packageRoute?: string
  archiveRoute?: string
  archiveRawfilePath?: string
  archivePath?: string
  archiveImportOk?: boolean
  archiveResponse?: SourceRuntimeCallResponse
  archiveResponseOk?: boolean
  archiveSourceApiOperationsOk?: boolean
  archiveSourceApiOperations?: SourceRuntimeApiOperationsSummary
  archiveOperation?: string
  archiveRequestEcho?: string
  archiveFirstTitle?: string
  archiveNetwork?: boolean
  archiveWasmBytes?: number
  archiveManifestId?: string
  archiveManifestVersion?: string
  archiveManifestPath?: string
  archiveImportedWasmPath?: string
  archiveHashOk?: boolean
  archiveNegativeRoute?: string
  archiveNegativeOk?: boolean
  archiveNegativeCases?: SourceArchiveNegativeCaseEvidence[]
  sourceRuntimeExecutionNegativeOk?: boolean
  sourceRuntimeExecutionNegativeCases?: SourceRuntimeExecutionNegativeCaseEvidence[]
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

function applyPackageServiceSummary(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  result.packageResponseOk = summary.responseOk
  result.packageSourceApiOperationsOk = summary.sourceApiOperationsOk
  result.packageSourceApiOperations = compactSourceApiOperations(summary.sourceApiOperations)
  result.packageOperation = summary.operation
  result.packageRequestEcho = summary.requestEcho
  result.packageFirstTitle = summary.firstTitle
  result.packageNetwork = summary.network
  result.packageWasmBytes = summary.wasmBytes
  result.packageManifestId = summary.manifestId
  result.packageManifestVersion = summary.manifestVersion
  result.packageHashOk = summary.hashOk
  result.packageRoute = summary.route
  appendSourceRuntimeExecutionNegativeCases(result, summary)
}

function applyArchiveServiceSummary(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  result.archiveResponseOk = summary.responseOk
  result.archiveSourceApiOperationsOk = summary.sourceApiOperationsOk
  result.archiveSourceApiOperations = compactSourceApiOperations(summary.sourceApiOperations)
  result.archiveOperation = summary.operation
  result.archiveRequestEcho = summary.requestEcho
  result.archiveFirstTitle = summary.firstTitle
  result.archiveNetwork = summary.network
  result.archiveWasmBytes = summary.wasmBytes
  result.archiveManifestId = summary.manifestId
  result.archiveManifestVersion = summary.manifestVersion
  result.archiveHashOk = summary.hashOk
  result.archiveImportOk = summary.importStatus === 'imported'
  result.archiveRoute = summary.route
  appendSourceRuntimeExecutionNegativeCases(result, summary)
}

function compactSourceApiOperations(summary: SourceRuntimeApiOperationsSummary): SourceRuntimeApiOperationsSummary {
  return {
    ok: summary.ok,
    operations: summary.operations,
    evidence: [],
  }
}

function appendSourceRuntimeExecutionNegativeCases(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  const existing = result.sourceRuntimeExecutionNegativeCases ?? []
  const nextCases = summary.sourceRuntimeExecutionNegativeCases.cases.map(
    (item: SourceRuntimeNegativeExecutionCaseSummary) => {
      const evidence: SourceRuntimeExecutionNegativeCaseEvidence = {
        route: summary.route,
        id: item.id,
        rejected: item.rejected,
        didNotDefaultToSearch: item.didNotDefaultToSearch,
        responseOk: item.responseOk,
        responseOperation: item.responseOperation,
        responseFirstTitle: item.responseFirstTitle,
        error: item.error,
      }
      return evidence
    },
  )
  result.sourceRuntimeExecutionNegativeCases = existing.concat(nextCases)
  result.sourceRuntimeExecutionNegativeOk =
    (result.sourceRuntimeExecutionNegativeOk !== false) &&
      summary.sourceRuntimeExecutionNegativeOk &&
      result.sourceRuntimeExecutionNegativeCases.length >= 3 &&
      result.sourceRuntimeExecutionNegativeCases.every((item: SourceRuntimeExecutionNegativeCaseEvidence) =>
        item.rejected && item.didNotDefaultToSearch && item.responseOk === false)
}

function runLocalSourcePackageSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): void {
  const summary = runStagedRawfileSourcePackage(
    context,
    resourceMgr,
    RUST_SMOKE_RAWFILE_PATH,
    'source-runtime-package-smoke',
    PACKAGE_SMOKE_REQUEST_JSON,
    PACKAGE_ROUTE_LABEL,
  )
  applyPackageServiceSummary(result, summary)
}

async function runLocalSourceArchiveSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const summary = await importAndRunLocalSourceArchive(
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-archive-smoke',
    ARCHIVE_SANDBOX_ZIP_FILE,
    ARCHIVE_REQUEST_JSON,
    ARCHIVE_ROUTE_LABEL,
  )
  applyArchiveServiceSummary(result, summary)
}

export async function maybeRunSourceRuntimeDeviceSmoke(
  want: Want,
  resourceMgr?: resourceManager.ResourceManager,
  context?: common.UIAbilityContext,
): Promise<void> {
  if (!hasSmokeTrigger(want)) {
    return
  }

  const result: SourceRuntimeSmokeResult = {
    ok: false,
    route: 'entryability-want-test-only',
    requestJson: SMOKE_REQUEST_JSON,
    rawfilePath: SMOKE_RAWFILE_PATH,
    rustRequestJson: RUST_SMOKE_REQUEST_JSON,
    rustRawfilePath: RUST_SMOKE_RAWFILE_PATH,
    packageRoute: PACKAGE_ROUTE_LABEL,
    archiveRoute: ARCHIVE_ROUTE_LABEL,
    archiveRawfilePath: ARCHIVE_RAWFILE_PATH,
    archiveNegativeRoute: ARCHIVE_NEGATIVE_ROUTE_LABEL,
  }

  try {
    const response = runBundledSourceOperation(SMOKE_REQUEST_JSON)
    result.responseOk = responseReachedFixture(response)
    let resourceResponse: SourceRuntimeCallResponse | undefined = undefined
    let rustSourceResponseOk = false
    if (resourceMgr !== undefined) {
      const wasmBytes = resourceMgr.getRawFileContentSync(SMOKE_RAWFILE_PATH)
      result.rawfileBytes = wasmBytes.byteLength
      resourceResponse = runSourceOperationFromBytes(SMOKE_REQUEST_JSON, wasmBytes)
      result.resourceResponseOk = responseReachedFixture(resourceResponse)

      const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
      result.rustRawfileBytes = rustWasmBytes.byteLength
      const rustSourceRun = runSearchFixtureFromBytes(RUST_SMOKE_REQUEST_JSON, rustWasmBytes)
      const rustSourceOperations = runSourceApiFixtureOperationsFromBytes(rustWasmBytes)
      rustSourceResponseOk = rustSourceRun.responseOk
      result.rustSourceResponseOk = rustSourceResponseOk
      result.rustSourceApiOperationsOk = rustSourceOperations.ok
      result.rustSourceApiOperations = compactSourceApiOperations(rustSourceOperations)
      if (context !== undefined) {
        runLocalSourcePackageSmoke(context, resourceMgr, result)
        await runLocalSourceArchiveSmoke(context, resourceMgr, result)
        const archiveNegativeCases = await importArchiveNegativeFixturesWithoutExecution(
          context,
          resourceMgr,
          ARCHIVE_NEGATIVE_CASES,
          'source-runtime-archive-negative-smoke',
        )
        result.archiveNegativeCases = archiveNegativeCases.map((item: SourceArchiveNegativeImportResult) => {
          const evidence: SourceArchiveNegativeCaseEvidence = {
            id: item.id,
            reasonCode: item.reasonCode,
            reasonMatchesExpected: item.reasonMatchesExpected,
            attemptedWamrExecution: item.attemptedWamrExecution,
          }
          return evidence
        })
        result.archiveNegativeOk = archiveNegativeCases.length === ARCHIVE_NEGATIVE_CASES.length &&
          archiveNegativeCases.every((item: SourceArchiveNegativeImportResult) =>
            item.rejected && item.reasonMatchesExpected && item.attemptedWamrExecution === false)
      }
    }
    result.ok = result.responseOk === true &&
      resourceResponse !== undefined &&
      result.resourceResponseOk === true &&
      rustSourceResponseOk &&
      result.packageResponseOk === true &&
      result.packageSourceApiOperationsOk === true &&
      result.packageHashOk === true &&
      result.packageNetwork === false &&
      result.archiveImportOk === true &&
      result.archiveResponseOk === true &&
      result.archiveSourceApiOperationsOk === true &&
      result.archiveHashOk === true &&
      result.archiveNetwork === false &&
      result.rustSourceApiOperationsOk === true &&
      result.archiveNegativeOk === true &&
      result.sourceRuntimeExecutionNegativeOk === true
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled, legacy rawfile, Rust source rawfile, local source package, local source archive import, archive negative rejection, and negative execution paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
