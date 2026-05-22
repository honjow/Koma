import { common, Want } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import {
  SourceArchiveNegativeCaseFixture,
  SourceArchiveNegativeImportResult,
} from './SourcePackageImporter'
import {
  importAndRegisterLocalSourceArchive,
  importAndRunLocalSourceArchive,
  importArchiveNegativeFixturesWithoutExecution,
  persistReloadAndRunRegisteredSourcesById,
  runRegisteredSourceApiOperationsById,
  runStagedRawfileSourcePackage,
  runSourceRuntimeRegistryNegativeEvidence,
  stageAndRegisterRawfileSourcePackage,
  SourceRuntimeServiceRegistrationSummary,
  SourceRuntimeServiceRegistryNegativeSummary,
  SourceRuntimeServiceRegistryReloadSummary,
  SourceRuntimeServiceRunByIdSummary,
  SourceRuntimeServiceRunRequestByIdSummary,
  SourceRuntimeServiceRunSummary,
} from './SourceRuntimeService'
import { SourceRuntimeRegistry } from './SourceRuntimeRegistry'
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
const PACKAGE_REGISTRY_ROUTE_LABEL: string = 'app-local-source-package-registry-test-only'
const ARCHIVE_REGISTRY_ROUTE_LABEL: string = 'app-local-source-archive-registry-test-only'
const PACKAGE_REGISTRY_SOURCE_ID: string = 'local.test.koma.fixture.package.registry'
const ARCHIVE_REGISTRY_SOURCE_ID: string = 'local.test.koma.fixture.archive.registry'
const REGISTRY_RELOAD_METADATA_FILE: string = 'registry-metadata.json'
const REGISTRY_RELOAD_MISSING_METADATA_FILE: string = 'missing-registry-metadata.json'
const REGISTRY_RELOAD_CORRUPT_METADATA_FILE: string = 'corrupt-registry-metadata.json'
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

export interface SourceRuntimeRegistryEntryEvidence {
  sourceId: string
  manifestId: string
  manifestVersion: string
  route: string
  importStatus: string
  wasmBytes: number
  hashOk: boolean
  network: boolean
  validationEvidence: string[]
}

export interface SourceRuntimeRunRequestByIdEvidence {
  sourceId: string
  operation?: string
  ok: boolean
  responseOk: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
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
  sourceRuntimeExecutionNegativeCaseCount?: number
  sourceRuntimeRegistryOk?: boolean
  sourceRuntimeRegistrySourceCount?: number
  sourceRuntimeRegistryPackageSourceId?: string
  sourceRuntimeRegistryArchiveSourceId?: string
  sourceRuntimeRegistryPackageEntry?: SourceRuntimeRegistryEntryEvidence
  sourceRuntimeRegistryArchiveEntry?: SourceRuntimeRegistryEntryEvidence
  sourceRuntimeRegistryPackageRunByIdOk?: boolean
  sourceRuntimeRegistryPackageRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryArchiveRunByIdOk?: boolean
  sourceRuntimeRegistryArchiveRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryDuplicateRejected?: boolean
  sourceRuntimeRegistryDuplicateReasonCode?: string
  sourceRuntimeRegistryMissingSourceIdRejected?: boolean
  sourceRuntimeRegistryMissingSourceIdReasonCode?: string
  sourceRuntimeRegistryInvalidRunRejected?: boolean
  sourceRuntimeRegistryInvalidRunReasonCode?: string
  sourceRuntimeRegistryReloadOk?: boolean
  sourceRuntimeRegistryReloadMetadataPath?: string
  sourceRuntimeRegistryPersistedSourceCount?: number
  sourceRuntimeRegistryReloadedSourceCount?: number
  sourceRuntimeRegistryPackageReloadRunByIdOk?: boolean
  sourceRuntimeRegistryPackageReloadRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryArchiveReloadRunByIdOk?: boolean
  sourceRuntimeRegistryArchiveReloadRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryReloadNegativeRejected?: boolean
  sourceRuntimeRegistryReloadNegativeReasonCode?: string
  sourceRuntimeRegistryReloadNegativeAttemptedWamrExecution?: boolean
  sourceRuntimeRegistryReloadCorruptMetadataRejected?: boolean
  sourceRuntimeRegistryReloadCorruptMetadataReasonCode?: string
  sourceRuntimeRegistryReloadCorruptMetadataAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdOk?: boolean
  sourceRuntimeRunRequestByIdPackageSearchOk?: boolean
  sourceRuntimeRunRequestByIdPackageSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdArchiveSearchOk?: boolean
  sourceRuntimeRunRequestByIdArchiveSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdNonSearchOk?: boolean
  sourceRuntimeRunRequestByIdNonSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdUnknownSourceRejected?: boolean
  sourceRuntimeRunRequestByIdUnknownSourceReasonCode?: string
  sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdSourceIdMismatchRejected?: boolean
  sourceRuntimeRunRequestByIdSourceIdMismatchReasonCode?: string
  sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdMalformedRejected?: boolean
  sourceRuntimeRunRequestByIdMalformedReasonCode?: string
  sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdNullRequestRejected?: boolean
  sourceRuntimeRunRequestByIdNullRequestReasonCode?: string
  sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdArrayRequestRejected?: boolean
  sourceRuntimeRunRequestByIdArrayRequestReasonCode?: string
  sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdMissingOperationRejected?: boolean
  sourceRuntimeRunRequestByIdMissingOperationReasonCode?: string
  sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution?: boolean
  error?: string
}

function joinSourceRuntimeSmokePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
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

function compactRegistryEntry(summary: SourceRuntimeServiceRegistrationSummary): SourceRuntimeRegistryEntryEvidence | undefined {
  if (!summary.ok || summary.entry === undefined) {
    return undefined
  }
  return {
    sourceId: summary.entry.sourceId,
    manifestId: summary.entry.manifestId,
    manifestVersion: summary.entry.manifestVersion,
    route: summary.entry.route,
    importStatus: summary.entry.importStatus,
    wasmBytes: summary.entry.wasmByteCount,
    hashOk: summary.entry.hashOk,
    network: summary.entry.network,
    validationEvidence: [],
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
  const combined = existing.concat(nextCases)
  result.sourceRuntimeExecutionNegativeCaseCount = combined.length
  result.sourceRuntimeExecutionNegativeOk =
    (result.sourceRuntimeExecutionNegativeOk !== false) &&
      summary.sourceRuntimeExecutionNegativeOk &&
      combined.length >= 3 &&
      combined.every((item: SourceRuntimeExecutionNegativeCaseEvidence) =>
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

async function runSourceRuntimeRegistrySmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const registry = new SourceRuntimeRegistry()
  const packageRegistered = stageAndRegisterRawfileSourcePackage(
    registry,
    context,
    resourceMgr,
    RUST_SMOKE_RAWFILE_PATH,
    'source-runtime-package-registry-smoke',
    PACKAGE_REGISTRY_SOURCE_ID,
    PACKAGE_REGISTRY_ROUTE_LABEL,
  )
  const archiveRegistered = await importAndRegisterLocalSourceArchive(
    registry,
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-archive-registry-smoke',
    'local_source_runtime_registry_fixture.zip',
    ARCHIVE_REGISTRY_SOURCE_ID,
    ARCHIVE_REGISTRY_ROUTE_LABEL,
  )
  const packageRunById = runRegisteredSourceApiOperationsById(registry, PACKAGE_REGISTRY_SOURCE_ID)
  const archiveRunById = runRegisteredSourceApiOperationsById(registry, ARCHIVE_REGISTRY_SOURCE_ID)
  const metadataRoot = joinSourceRuntimeSmokePath(context.filesDir, 'source-runtime-registry-reload-smoke')
  const reloadSummary = persistReloadAndRunRegisteredSourcesById(
    registry,
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_METADATA_FILE),
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_MISSING_METADATA_FILE),
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_CORRUPT_METADATA_FILE),
    PACKAGE_REGISTRY_SOURCE_ID,
    ARCHIVE_REGISTRY_SOURCE_ID,
  )
  result.sourceRuntimeRegistrySourceCount = registry.count()
  result.sourceRuntimeRegistryPackageSourceId = PACKAGE_REGISTRY_SOURCE_ID
  result.sourceRuntimeRegistryArchiveSourceId = ARCHIVE_REGISTRY_SOURCE_ID
  result.sourceRuntimeRegistryPackageEntry = compactRegistryEntry(packageRegistered)
  result.sourceRuntimeRegistryArchiveEntry = compactRegistryEntry(archiveRegistered)
  applyRunByIdEvidence(result, packageRunById, true)
  applyRunByIdEvidence(result, archiveRunById, false)
  applyRegistryReloadEvidence(result, reloadSummary)
  if (packageRegistered.entry !== undefined) {
    const negative = runSourceRuntimeRegistryNegativeEvidence(registry, packageRegistered.entry)
    applyRegistryNegativeEvidence(result, negative)
  }
  result.sourceRuntimeRegistryOk = packageRegistered.ok &&
    archiveRegistered.ok &&
    result.sourceRuntimeRegistrySourceCount >= 2 &&
    result.sourceRuntimeRegistryPackageEntry !== undefined &&
    result.sourceRuntimeRegistryArchiveEntry !== undefined &&
    result.sourceRuntimeRegistryPackageRunByIdOk === true &&
    result.sourceRuntimeRegistryArchiveRunByIdOk === true &&
    result.sourceRuntimeRegistryDuplicateRejected === true &&
    result.sourceRuntimeRegistryMissingSourceIdRejected === true &&
    result.sourceRuntimeRegistryInvalidRunRejected === true &&
    result.sourceRuntimeRegistryReloadOk === true &&
    result.sourceRuntimeRunRequestByIdOk === true
}

function applyRunByIdEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunByIdSummary,
  isPackage: boolean,
): void {
  if (isPackage) {
    result.sourceRuntimeRegistryPackageRunByIdOk = summary.ok && summary.sourceApiOperationsOk
    result.sourceRuntimeRegistryPackageRunByIdOperations = compactSourceApiOperations(summary.sourceApiOperations)
    return
  }
  result.sourceRuntimeRegistryArchiveRunByIdOk = summary.ok && summary.sourceApiOperationsOk
  result.sourceRuntimeRegistryArchiveRunByIdOperations = compactSourceApiOperations(summary.sourceApiOperations)
}

function applyRegistryNegativeEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRegistryNegativeSummary,
): void {
  result.sourceRuntimeRegistryDuplicateRejected = summary.duplicateRejected
  result.sourceRuntimeRegistryDuplicateReasonCode = summary.duplicateReasonCode
  result.sourceRuntimeRegistryMissingSourceIdRejected = summary.missingSourceIdRejected
  result.sourceRuntimeRegistryMissingSourceIdReasonCode = summary.missingSourceIdReasonCode
  result.sourceRuntimeRegistryInvalidRunRejected = summary.invalidRunRejected
  result.sourceRuntimeRegistryInvalidRunReasonCode = summary.invalidRunReasonCode
}

function applyRegistryReloadEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRegistryReloadSummary,
): void {
  result.sourceRuntimeRegistryReloadMetadataPath = summary.metadataPath
  result.sourceRuntimeRegistryPersistedSourceCount = summary.persistedSourceCount
  result.sourceRuntimeRegistryReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimeRegistryPackageReloadRunByIdOk = summary.packageRunByIdOk
  result.sourceRuntimeRegistryPackageReloadRunByIdOperations = compactSourceApiOperations(summary.packageRunByIdOperations)
  result.sourceRuntimeRegistryArchiveReloadRunByIdOk = summary.archiveRunByIdOk
  result.sourceRuntimeRegistryArchiveReloadRunByIdOperations = compactSourceApiOperations(summary.archiveRunByIdOperations)
  result.sourceRuntimeRegistryReloadNegativeRejected = summary.negative.rejected
  result.sourceRuntimeRegistryReloadNegativeReasonCode = summary.negative.reasonCode
  result.sourceRuntimeRegistryReloadNegativeAttemptedWamrExecution = summary.negative.attemptedWamrExecution
  result.sourceRuntimeRegistryReloadCorruptMetadataRejected = summary.corruptNegative.rejected
  result.sourceRuntimeRegistryReloadCorruptMetadataReasonCode = summary.corruptNegative.reasonCode
  result.sourceRuntimeRegistryReloadCorruptMetadataAttemptedWamrExecution = summary.corruptNegative.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdPackageSearchOk = summary.packageRunRequestById.ok
  result.sourceRuntimeRunRequestByIdPackageSearch = compactRunRequestByIdEvidence(summary.packageRunRequestById)
  result.sourceRuntimeRunRequestByIdArchiveSearchOk = summary.archiveRunRequestById.ok
  result.sourceRuntimeRunRequestByIdArchiveSearch = compactRunRequestByIdEvidence(summary.archiveRunRequestById)
  result.sourceRuntimeRunRequestByIdNonSearchOk = summary.nonSearchRunRequestById.ok
  result.sourceRuntimeRunRequestByIdNonSearch = compactRunRequestByIdEvidence(summary.nonSearchRunRequestById)
  result.sourceRuntimeRunRequestByIdUnknownSourceRejected = !summary.unknownSourceRunRequestById.ok &&
    summary.unknownSourceRunRequestById.reasonCode === 'source_id_not_registered'
  result.sourceRuntimeRunRequestByIdUnknownSourceReasonCode = summary.unknownSourceRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution =
    summary.unknownSourceRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdSourceIdMismatchRejected = !summary.sourceIdMismatchRunRequestById.ok &&
    summary.sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch'
  result.sourceRuntimeRunRequestByIdSourceIdMismatchReasonCode = summary.sourceIdMismatchRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution =
    summary.sourceIdMismatchRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdMalformedRejected = !summary.malformedRunRequestById.ok &&
    summary.malformedRunRequestById.reasonCode === 'malformed_json'
  result.sourceRuntimeRunRequestByIdMalformedReasonCode = summary.malformedRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution =
    summary.malformedRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdNullRequestRejected = !summary.nullRequestRunRequestById.ok &&
    summary.nullRequestRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdNullRequestReasonCode = summary.nullRequestRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution =
    summary.nullRequestRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdArrayRequestRejected = !summary.arrayRequestRunRequestById.ok &&
    summary.arrayRequestRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdArrayRequestReasonCode = summary.arrayRequestRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution =
    summary.arrayRequestRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdMissingOperationRejected = !summary.missingOperationRunRequestById.ok &&
    summary.missingOperationRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdMissingOperationReasonCode = summary.missingOperationRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution =
    summary.missingOperationRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdOk =
    summary.packageRunRequestById.ok &&
      summary.packageRunRequestById.operation === 'search' &&
      summary.archiveRunRequestById.ok &&
      summary.archiveRunRequestById.operation === 'search' &&
      summary.nonSearchRunRequestById.ok &&
      summary.nonSearchRunRequestById.operation === 'get_manga' &&
      result.sourceRuntimeRunRequestByIdUnknownSourceRejected === true &&
      summary.unknownSourceRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdSourceIdMismatchRejected === true &&
      summary.sourceIdMismatchRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdMalformedRejected === true &&
      summary.malformedRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdNullRequestRejected === true &&
      summary.nullRequestRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdArrayRequestRejected === true &&
      summary.arrayRequestRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdMissingOperationRejected === true &&
      summary.missingOperationRunRequestById.attemptedWamrExecution === false
  result.sourceRuntimeRegistryReloadOk = summary.ok &&
    summary.persistedSourceCount >= 2 &&
    summary.reloadedSourceCount >= 2 &&
    summary.packageRunByIdOk &&
    summary.archiveRunByIdOk &&
    summary.negative.rejected &&
    summary.negative.reasonCode === 'metadata_missing' &&
    summary.negative.attemptedWamrExecution === false &&
    summary.corruptNegative.rejected &&
    summary.corruptNegative.reasonCode === 'metadata_invalid' &&
    summary.corruptNegative.attemptedWamrExecution === false
}

function compactRunRequestByIdEvidence(
  summary: SourceRuntimeServiceRunRequestByIdSummary,
): SourceRuntimeRunRequestByIdEvidence {
  return {
    sourceId: summary.sourceId,
    operation: summary.operation,
    ok: summary.ok,
    responseOk: summary.responseOk,
    reasonCode: summary.reasonCode,
    attemptedWamrExecution: summary.attemptedWamrExecution,
  }
}

function compactSmokeResultForHilog(result: SourceRuntimeSmokeResult): void {
  result.route = ''
  result.requestJson = ''
  result.rawfilePath = undefined
  result.rawfileBytes = undefined
  result.rustRequestJson = undefined
  result.rustRawfilePath = undefined
  result.rustRawfileBytes = undefined
  result.packageRoute = undefined
  result.packageOperation = undefined
  result.packageRequestEcho = undefined
  result.packageFirstTitle = undefined
  result.packageWasmBytes = undefined
  result.packageManifestId = undefined
  result.packageManifestVersion = undefined
  result.packageManifestPath = undefined
  result.packageWasmPath = undefined
  result.archiveRoute = undefined
  result.archiveRawfilePath = undefined
  result.archivePath = undefined
  result.archiveOperation = undefined
  result.archiveRequestEcho = undefined
  result.archiveFirstTitle = undefined
  result.archiveWasmBytes = undefined
  result.archiveManifestId = undefined
  result.archiveManifestVersion = undefined
  result.archiveManifestPath = undefined
  result.archiveImportedWasmPath = undefined
  result.archiveNegativeRoute = undefined
  result.rustSourceApiOperations = undefined
  result.packageSourceApiOperations = undefined
  result.archiveSourceApiOperations = undefined
  result.sourceRuntimeRegistrySourceCount = undefined
  result.sourceRuntimeRegistryPackageSourceId = undefined
  result.sourceRuntimeRegistryArchiveSourceId = undefined
  result.sourceRuntimeRegistryPackageRunByIdOperations = undefined
  result.sourceRuntimeRegistryArchiveRunByIdOperations = undefined
  result.sourceRuntimeRegistryReloadMetadataPath = undefined
  result.sourceRuntimeRegistryPersistedSourceCount = undefined
  result.sourceRuntimeRegistryReloadedSourceCount = undefined
  result.sourceRuntimeRegistryPackageReloadRunByIdOperations = undefined
  result.sourceRuntimeRegistryArchiveReloadRunByIdOperations = undefined
  result.sourceRuntimeRegistryPackageEntry = undefined
  result.sourceRuntimeRegistryArchiveEntry = undefined
  result.sourceRuntimeExecutionNegativeCases = undefined
  result.archiveNegativeCases = undefined
  result.sourceRuntimeRunRequestByIdPackageSearch = undefined
  result.sourceRuntimeRunRequestByIdArchiveSearch = undefined
  result.sourceRuntimeRunRequestByIdNonSearch = undefined
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
        await runSourceRuntimeRegistrySmoke(context, resourceMgr, result)
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
      result.sourceRuntimeExecutionNegativeOk === true &&
      result.sourceRuntimeRegistryOk === true &&
      result.sourceRuntimeRegistryReloadOk === true
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled, legacy rawfile, Rust source rawfile, local source package, local source archive import, archive negative rejection, negative execution, registry run-by-id, and registry persistence/reload paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  compactSmokeResultForHilog(result)
  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
