import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { resourceManager } from '@kit.LocalizationKit'
import { SourceRuntimeCallRequest, SourceRuntimeCallResponse } from './NativeSourceRuntime'
import {
  importArchiveNegativeFixtures,
  importLocalSourceArchive,
  SourceArchiveNegativeCaseFixture,
  SourceArchiveNegativeImportResult,
  stageRawfileSourcePackage,
} from './SourcePackageImporter'
import {
  runSearchFixtureFromBytes,
  runSourceApiFixtureOperationsForSourceIdFromBytes,
  runSourceApiFixtureOperationsFromBytes,
  runSourceOperationFromBytes,
  runSourceRuntimeNegativeExecutionFromBytes,
  SourceRuntimeApiOperationsSummary,
  SourceRuntimeNegativeExecutionSummary,
} from './SourceRuntimeRunner'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
  SourceRuntimeRegistryInstalledSourceSummary,
  SourceRuntimeRegistryPersistResult,
  SourceRuntimeRegistryRegisterResult,
  SourceRuntimeRegistryReloadResult,
  sourceRuntimeEntryEnabled,
} from './SourceRuntimeRegistry'

export interface SourceRuntimeServiceRunSummary {
  route: string
  importStatus: string
  manifestId: string
  manifestVersion: string
  wasmBytes: number
  manifestPath?: string
  wasmPath?: string
  archivePath?: string
  hashOk: boolean
  network: boolean
  response: SourceRuntimeCallResponse
  responseOk: boolean
  operation?: string
  requestEcho?: string
  firstTitle?: string
  searchResponseCompatible: boolean
  sourceApiOperationsOk: boolean
  sourceApiOperations: SourceRuntimeApiOperationsSummary
  sourceRuntimeExecutionNegativeOk: boolean
  sourceRuntimeExecutionNegativeCases: SourceRuntimeNegativeExecutionSummary
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeServiceRegistrationSummary {
  ok: boolean
  reasonCode?: string
  entry?: SourceRuntimeRegistryEntry
  sourceCount: number
}

export interface SourceRuntimeServiceRunByIdSummary {
  ok: boolean
  sourceId: string
  reasonCode?: string
  sourceCount: number
  sourceApiOperationsOk: boolean
  sourceApiOperations: SourceRuntimeApiOperationsSummary
}

export interface SourceRuntimeServiceRunRequestByIdSummary {
  ok: boolean
  sourceId: string
  operation?: string
  reasonCode?: string
  sourceCount: number
  response?: SourceRuntimeCallResponse
  responseOk: boolean
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeServiceRegistryNegativeSummary {
  duplicateRejected: boolean
  duplicateReasonCode?: string
  missingSourceIdRejected: boolean
  missingSourceIdReasonCode?: string
  invalidRunRejected: boolean
  invalidRunReasonCode?: string
}

export interface SourceRuntimeServiceRegistryReloadNegativeSummary {
  rejected: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeServiceRegistryReloadSummary {
  ok: boolean
  reasonCode?: string
  metadataPath: string
  persistedSourceCount: number
  reloadedSourceCount: number
  packageRunByIdOk: boolean
  packageRunByIdOperations: SourceRuntimeApiOperationsSummary
  archiveRunByIdOk: boolean
  archiveRunByIdOperations: SourceRuntimeApiOperationsSummary
  packageRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  archiveRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  nonSearchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  unknownSourceRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  sourceIdMismatchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  malformedRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  nullRequestRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  arrayRequestRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  missingOperationRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  negative: SourceRuntimeServiceRegistryReloadNegativeSummary
  corruptNegative: SourceRuntimeServiceRegistryReloadNegativeSummary
}

export interface SourceRuntimeServiceArchiveIngestionRunSummary {
  ok: boolean
  sourceId: string
  route: string
  reasonCode?: string
  metadataPath: string
  archivePath?: string
  importRegister: SourceRuntimeServiceRegistrationSummary
  persistedSourceCount: number
  reloadedSourceCount: number
  installedSourceInventory: SourceRuntimeRegistryInstalledSourceSummary[]
  installedSourceInventoryOk: boolean
  inventoryExpectedSourceIdCount: number
  inventorySafetyOk: boolean
  selectedSourceId?: string
  hashOk: boolean
  network: boolean
  searchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  nonSearchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  unknownSourceRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  sourceIdMismatchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
}

export interface SourceRuntimeServicePersistedInventoryReloadSummary {
  ok: boolean
  sourceId: string
  route: string
  reasonCode?: string
  metadataPath: string
  reloadOnlyDidNotImportArchive: boolean
  reloadedSourceCount: number
  installedSourceInventory: SourceRuntimeRegistryInstalledSourceSummary[]
  installedSourceInventoryOk: boolean
  inventoryExpectedSourceIdCount: number
  inventorySafetyOk: boolean
  selectedSourceId?: string
  searchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  nonSearchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  unknownSourceRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
  sourceIdMismatchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
}

export interface SourceRuntimeServicePersistedPayloadMissingSummary {
  ok: boolean
  sourceId: string
  route: string
  reasonCode?: string
  metadataPath: string
  archivePath?: string
  importRegister: SourceRuntimeServiceRegistrationSummary
  persistedSourceCount: number
  payloadMutationApplied: boolean
  reloadOnlyDidNotImportArchive: boolean
  metadataReloadRejected: boolean
  reloadedSourceCount: number
  searchRunRequestById: SourceRuntimeServiceRunRequestByIdSummary
}

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function joinSourceRuntimeServicePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
}

function responseReasonCode(response: SourceRuntimeCallResponse): string | undefined {
  if (typeof response.reasonCode === 'string' && response.reasonCode.trim().length > 0) {
    return response.reasonCode
  }
  const code = response.error?.['code']
  return typeof code === 'string' && code.trim().length > 0 ? code : undefined
}

function sourceRuntimeRequestResponseOk(operation: string, response: SourceRuntimeCallResponse): boolean {
  if (response.ok !== true || response.operation !== operation || response.hostHints?.['network'] !== false) {
    return false
  }
  const responseText = JSON.stringify(response)
  if (operation === 'source_info') {
    return responseText.includes('"sourceInfo"') &&
      responseText.includes('"capabilities"')
  }
  if (operation === 'search') {
    return responseText.includes('Fixture Series') && response.data?.requestEcho === 'fixture'
  }
  if (operation === 'get_manga') {
    return responseText.includes('Fixture Series') && responseText.includes('manga:fixture-series')
  }
  return responseText.includes('fixture')
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

export function runStagedRawfileSourcePackage(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  packageRootName: string,
  requestJson: string,
  route: string,
): SourceRuntimeServiceRunSummary {
  const staged = stageRawfileSourcePackage(context, resourceMgr, rawfilePath, packageRootName)
  const run = runSearchFixtureFromBytes(requestJson, staged.wasmBytes)
  const operations = runSourceApiFixtureOperationsFromBytes(staged.wasmBytes)
  const negativeExecution = runSourceRuntimeNegativeExecutionFromBytes(staged.wasmBytes)
  const network = run.network === false ? false : true
  return {
    route,
    importStatus: 'staged',
    manifestId: staged.manifest.package.id,
    manifestVersion: staged.manifest.package.version,
    wasmBytes: staged.wasmBytes.byteLength,
    manifestPath: staged.manifestPath,
    wasmPath: staged.wasmPath,
    hashOk: staged.hashOk,
    network,
    response: run.response,
    responseOk: run.responseOk,
    operation: run.operation,
    requestEcho: run.requestEcho,
    firstTitle: run.firstTitle,
    searchResponseCompatible: run.responseOk,
    sourceApiOperationsOk: operations.ok,
    sourceApiOperations: operations,
    sourceRuntimeExecutionNegativeOk: negativeExecution.ok,
    sourceRuntimeExecutionNegativeCases: negativeExecution,
    attemptedWamrExecution: true,
  }
}

export function stageAndRegisterRawfileSourcePackage(
  registry: SourceRuntimeRegistry,
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  packageRootName: string,
  sourceId: string,
  route: string,
): SourceRuntimeServiceRegistrationSummary {
  const staged = stageRawfileSourcePackage(context, resourceMgr, rawfilePath, packageRootName)
  const registered = registry.register({
    sourceId,
    route,
    importStatus: 'staged',
    manifest: staged.manifest,
    wasmBytes: staged.wasmBytes,
    hashOk: staged.hashOk,
    network: false,
    manifestPath: staged.manifestPath,
    wasmPath: staged.wasmPath,
  })
  return sourceRuntimeServiceRegistrationSummary(registered)
}

export async function importAndRunLocalSourceArchive(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  archiveRootName: string,
  archiveFileName: string,
  requestJson: string,
  route: string,
): Promise<SourceRuntimeServiceRunSummary> {
  const archiveRoot = joinSourceRuntimeServicePath(context.filesDir, archiveRootName)
  const importedRoot = joinSourceRuntimeServicePath(archiveRoot, 'imported-package')
  const archivePath = joinSourceRuntimeServicePath(archiveRoot, archiveFileName)
  const archiveBytes = resourceMgr.getRawFileContentSync(rawfilePath)
  const imported = await importLocalSourceArchive(archiveBytes, archivePath, importedRoot)
  if (!imported.ok || imported.manifest === undefined || imported.wasmBytes === undefined) {
    throw new Error(`local source archive import rejected: ${imported.reasonCode}`)
  }

  const run = runSearchFixtureFromBytes(requestJson, imported.wasmBytes)
  const operations = runSourceApiFixtureOperationsFromBytes(imported.wasmBytes)
  const negativeExecution = runSourceRuntimeNegativeExecutionFromBytes(imported.wasmBytes)
  const network = run.network === false ? false : true
  return {
    route,
    importStatus: 'imported',
    manifestId: imported.manifest.package.id,
    manifestVersion: imported.manifest.package.version,
    wasmBytes: imported.wasmBytes.byteLength,
    manifestPath: imported.manifestPath,
    wasmPath: imported.wasmPath,
    archivePath,
    hashOk: imported.hashOk === true,
    network,
    response: run.response,
    responseOk: run.responseOk,
    operation: run.operation,
    requestEcho: run.requestEcho,
    firstTitle: run.firstTitle,
    searchResponseCompatible: run.responseOk,
    sourceApiOperationsOk: operations.ok,
    sourceApiOperations: operations,
    sourceRuntimeExecutionNegativeOk: negativeExecution.ok,
    sourceRuntimeExecutionNegativeCases: negativeExecution,
    attemptedWamrExecution: true,
  }
}

export async function importAndRegisterLocalSourceArchive(
  registry: SourceRuntimeRegistry,
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  archiveRootName: string,
  archiveFileName: string,
  sourceId: string,
  route: string,
): Promise<SourceRuntimeServiceRegistrationSummary> {
  const archiveRoot = joinSourceRuntimeServicePath(context.filesDir, archiveRootName)
  const importedRoot = joinSourceRuntimeServicePath(archiveRoot, 'imported-package')
  const archivePath = joinSourceRuntimeServicePath(archiveRoot, archiveFileName)
  const archiveBytes = resourceMgr.getRawFileContentSync(rawfilePath)
  const imported = await importLocalSourceArchive(archiveBytes, archivePath, importedRoot)
  if (!imported.ok || imported.manifest === undefined || imported.wasmBytes === undefined) {
    return {
      ok: false,
      reasonCode: imported.reasonCode,
      sourceCount: registry.count(),
    }
  }

  const registered = registry.register({
    sourceId,
    route,
    importStatus: 'imported',
    manifest: imported.manifest,
    wasmBytes: imported.wasmBytes,
    hashOk: imported.hashOk === true,
    network: false,
    manifestPath: imported.manifestPath,
    wasmPath: imported.wasmPath,
    archivePath,
  })
  return sourceRuntimeServiceRegistrationSummary(registered)
}

export function runRegisteredSourceApiOperationsById(
  registry: SourceRuntimeRegistry,
  sourceId: string,
): SourceRuntimeServiceRunByIdSummary {
  const lookup = registry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined) {
    return {
      ok: false,
      sourceId,
      reasonCode: lookup.reasonCode,
      sourceCount: lookup.sourceCount,
      sourceApiOperationsOk: false,
      sourceApiOperations: { ok: false, operations: [], evidence: [] },
    }
  }
  if (!sourceRuntimeEntryEnabled(lookup.entry)) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      reasonCode: 'source_disabled',
      sourceCount: lookup.sourceCount,
      sourceApiOperationsOk: false,
      sourceApiOperations: { ok: false, operations: [], evidence: [] },
    }
  }
  const operations = runSourceApiFixtureOperationsForSourceIdFromBytes(lookup.entry.wasmBytes, lookup.entry.sourceId)
  return {
    ok: operations.ok,
    sourceId: lookup.entry.sourceId,
    sourceCount: lookup.sourceCount,
    sourceApiOperationsOk: operations.ok,
    sourceApiOperations: operations,
  }
}

export function runRegisteredSourceRequestById(
  registry: SourceRuntimeRegistry,
  sourceId: string,
  requestJson: string,
): SourceRuntimeServiceRunRequestByIdSummary {
  const lookup = registry.lookup(sourceId)
  if (!lookup.ok || lookup.entry === undefined) {
    return {
      ok: false,
      sourceId,
      reasonCode: lookup.reasonCode,
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }
  if (!sourceRuntimeEntryEnabled(lookup.entry)) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      reasonCode: 'source_disabled',
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }

  let request: SourceRuntimeCallRequest
  try {
    request = JSON.parse(requestJson) as SourceRuntimeCallRequest
  } catch (_err) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      reasonCode: 'malformed_json',
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }
  if (request === null || typeof request !== 'object' || Array.isArray(request)) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      reasonCode: 'missing_or_invalid_operation',
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }

  const operation = request['operation']
  if (typeof operation !== 'string' || operation.trim().length === 0) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      reasonCode: 'missing_or_invalid_operation',
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }

  const requestSourceId = request['sourceId']
  if (requestSourceId !== undefined && (typeof requestSourceId !== 'string' || requestSourceId !== lookup.entry.sourceId)) {
    return {
      ok: false,
      sourceId: lookup.entry.sourceId,
      operation,
      reasonCode: 'source_id_mismatch',
      sourceCount: lookup.sourceCount,
      responseOk: false,
      attemptedWamrExecution: false,
    }
  }

  const response = runSourceOperationFromBytes(requestJson, lookup.entry.wasmBytes)
  const responseOk = sourceRuntimeRequestResponseOk(operation, response)
  return {
    ok: responseOk,
    sourceId: lookup.entry.sourceId,
    operation,
    reasonCode: responseOk ? undefined : (responseReasonCode(response) ?? 'operation_response_mismatch'),
    sourceCount: lookup.sourceCount,
    response,
    responseOk,
    attemptedWamrExecution: true,
  }
}

export function listInstalledSourceSummaries(
  registry: SourceRuntimeRegistry,
): SourceRuntimeRegistryInstalledSourceSummary[] {
  return registry.listInstalledSourceSummaries()
}

export function runSourceRuntimeRegistryNegativeEvidence(
  registry: SourceRuntimeRegistry,
  existingEntry: SourceRuntimeRegistryEntry,
): SourceRuntimeServiceRegistryNegativeSummary {
  const duplicate = registry.register({
    sourceId: existingEntry.sourceId,
    route: existingEntry.route,
    importStatus: existingEntry.importStatus,
    manifest: {
      schemaVersion: 1,
      package: {
        id: existingEntry.manifestId,
        name: 'Koma Local WASM Fixture',
        version: existingEntry.manifestVersion,
        language: 'en',
        type: 'wasm-source-fixture',
        nsfw: false,
      },
      runtime: {
        abi: 'koma-source-abi-v0.1',
        hostAbi: 'koma-host-v0.1',
        wasmPath: 'rust_source_runtime_fixture.wasm',
        wasmSha256: '',
        wasmSizeBytes: existingEntry.wasmByteCount,
        maxWasmBytes: existingEntry.wasmByteCount,
      },
      permissions: {
        network: false,
        hostImports: [],
      },
      contentPolicy: {
        publicIndex: false,
        marketplace: false,
        builtInSource: false,
        remoteInstall: false,
      },
    },
    wasmBytes: existingEntry.wasmBytes,
    hashOk: true,
    network: false,
    manifestPath: existingEntry.manifestPath,
    wasmPath: existingEntry.wasmPath,
    archivePath: existingEntry.archivePath,
  })
  const missing = registry.register({
    sourceId: '',
    route: existingEntry.route,
    importStatus: existingEntry.importStatus,
    manifest: {
      schemaVersion: 1,
      package: {
        id: existingEntry.manifestId,
        name: 'Koma Local WASM Fixture',
        version: existingEntry.manifestVersion,
        language: 'en',
        type: 'wasm-source-fixture',
        nsfw: false,
      },
      runtime: {
        abi: 'koma-source-abi-v0.1',
        hostAbi: 'koma-host-v0.1',
        wasmPath: 'rust_source_runtime_fixture.wasm',
        wasmSha256: '',
        wasmSizeBytes: existingEntry.wasmByteCount,
        maxWasmBytes: existingEntry.wasmByteCount,
      },
      permissions: {
        network: false,
        hostImports: [],
      },
      contentPolicy: {
        publicIndex: false,
        marketplace: false,
        builtInSource: false,
        remoteInstall: false,
      },
    },
    wasmBytes: existingEntry.wasmBytes,
    hashOk: true,
    network: false,
  })
  const invalidRun = runRegisteredSourceApiOperationsById(registry, 'missing.source.id.test-only')
  return {
    duplicateRejected: !duplicate.ok && duplicate.reasonCode === 'duplicate_source_id',
    duplicateReasonCode: duplicate.reasonCode,
    missingSourceIdRejected: !missing.ok && missing.reasonCode === 'missing_source_id',
    missingSourceIdReasonCode: missing.reasonCode,
    invalidRunRejected: !invalidRun.ok && invalidRun.reasonCode === 'source_id_not_registered',
    invalidRunReasonCode: invalidRun.reasonCode,
  }
}

export function persistReloadAndRunRegisteredSourcesById(
  registry: SourceRuntimeRegistry,
  metadataPath: string,
  missingMetadataPath: string,
  corruptMetadataPath: string,
  packageSourceId: string,
  archiveSourceId: string,
): SourceRuntimeServiceRegistryReloadSummary {
  const persist = persistSourceRuntimeRegistryMetadata(registry, metadataPath)
  const missingNegative = runSourceRuntimeRegistryReloadNegativeEvidence(missingMetadataPath)
  const corruptNegative = runSourceRuntimeRegistryReloadCorruptMetadataEvidence(corruptMetadataPath)
  if (!persist.ok) {
    return {
      ok: false,
      reasonCode: persist.reasonCode,
      metadataPath,
      persistedSourceCount: persist.persistedSourceCount,
      reloadedSourceCount: 0,
      packageRunByIdOk: false,
      packageRunByIdOperations: { ok: false, operations: [], evidence: [] },
      archiveRunByIdOk: false,
      archiveRunByIdOperations: { ok: false, operations: [], evidence: [] },
      packageRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      archiveRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(archiveSourceId, persist.persistedSourceCount, persist.reasonCode),
      nonSearchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      unknownSourceRunRequestById: sourceRuntimeServiceRunRequestByIdRejected('missing.source.id.test-only', persist.persistedSourceCount, persist.reasonCode),
      sourceIdMismatchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      malformedRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      nullRequestRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      arrayRequestRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      missingOperationRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, persist.persistedSourceCount, persist.reasonCode),
      negative: missingNegative,
      corruptNegative,
    }
  }

  const reloaded = reloadSourceRuntimeRegistryFromMetadata(metadataPath)
  if (!reloaded.ok) {
    return {
      ok: false,
      reasonCode: reloaded.reasonCode,
      metadataPath,
      persistedSourceCount: persist.persistedSourceCount,
      reloadedSourceCount: reloaded.reloadedSourceCount,
      packageRunByIdOk: false,
      packageRunByIdOperations: { ok: false, operations: [], evidence: [] },
      archiveRunByIdOk: false,
      archiveRunByIdOperations: { ok: false, operations: [], evidence: [] },
      packageRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      archiveRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(archiveSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      nonSearchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      unknownSourceRunRequestById: sourceRuntimeServiceRunRequestByIdRejected('missing.source.id.test-only', reloaded.reloadedSourceCount, reloaded.reasonCode),
      sourceIdMismatchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      malformedRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      nullRequestRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      arrayRequestRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      missingOperationRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(packageSourceId, reloaded.reloadedSourceCount, reloaded.reasonCode),
      negative: missingNegative,
      corruptNegative,
    }
  }

  const packageRunById = runRegisteredSourceApiOperationsById(reloaded.registry, packageSourceId)
  const archiveRunById = runRegisteredSourceApiOperationsById(reloaded.registry, archiveSourceId)
  const packageRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    `{"type":"request","version":1,"requestId":"device-run-request-by-id-package-search-001","operation":"search","sourceId":"${packageSourceId}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`,
  )
  const archiveRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    archiveSourceId,
    `{"type":"request","version":1,"requestId":"device-run-request-by-id-archive-search-001","operation":"search","sourceId":"${archiveSourceId}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`,
  )
  const nonSearchRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    `{"type":"request","version":1,"requestId":"device-run-request-by-id-package-manga-001","operation":"get_manga","sourceId":"${packageSourceId}","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}`,
  )
  const unknownSourceRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    'missing.source.id.test-only',
    '{"type":"request","version":1,"requestId":"device-run-request-by-id-unknown-001","operation":"search","sourceId":"missing.source.id.test-only","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  )
  const sourceIdMismatchRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    `{"type":"request","version":1,"requestId":"device-run-request-by-id-mismatch-001","operation":"search","sourceId":"${archiveSourceId}","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}`,
  )
  const malformedRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    '{"type":"request","version":1,"requestId":"device-run-request-by-id-malformed-001","operation":"search"',
  )
  const nullRequestRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    'null',
  )
  const arrayRequestRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    '[]',
  )
  const missingOperationRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    packageSourceId,
    `{"type":"request","version":1,"requestId":"device-run-request-by-id-missing-operation-001","sourceId":"${packageSourceId}","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}`,
  )
  return {
    ok: packageRunById.ok && packageRunById.sourceApiOperationsOk &&
      archiveRunById.ok && archiveRunById.sourceApiOperationsOk &&
      packageRunRequestById.ok &&
      archiveRunRequestById.ok &&
      nonSearchRunRequestById.ok &&
      !unknownSourceRunRequestById.ok &&
      unknownSourceRunRequestById.reasonCode === 'source_id_not_registered' &&
      unknownSourceRunRequestById.attemptedWamrExecution === false &&
      !sourceIdMismatchRunRequestById.ok &&
      sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch' &&
      sourceIdMismatchRunRequestById.attemptedWamrExecution === false &&
      !malformedRunRequestById.ok &&
      malformedRunRequestById.reasonCode === 'malformed_json' &&
      malformedRunRequestById.attemptedWamrExecution === false &&
      !nullRequestRunRequestById.ok &&
      nullRequestRunRequestById.reasonCode === 'missing_or_invalid_operation' &&
      nullRequestRunRequestById.attemptedWamrExecution === false &&
      !arrayRequestRunRequestById.ok &&
      arrayRequestRunRequestById.reasonCode === 'missing_or_invalid_operation' &&
      arrayRequestRunRequestById.attemptedWamrExecution === false &&
      !missingOperationRunRequestById.ok &&
      missingOperationRunRequestById.reasonCode === 'missing_or_invalid_operation' &&
      missingOperationRunRequestById.attemptedWamrExecution === false &&
      missingNegative.rejected &&
      corruptNegative.rejected,
    metadataPath,
    persistedSourceCount: persist.persistedSourceCount,
    reloadedSourceCount: reloaded.reloadedSourceCount,
    packageRunByIdOk: packageRunById.ok && packageRunById.sourceApiOperationsOk,
    packageRunByIdOperations: packageRunById.sourceApiOperations,
    archiveRunByIdOk: archiveRunById.ok && archiveRunById.sourceApiOperationsOk,
    archiveRunByIdOperations: archiveRunById.sourceApiOperations,
    packageRunRequestById,
    archiveRunRequestById,
    nonSearchRunRequestById,
    unknownSourceRunRequestById,
    sourceIdMismatchRunRequestById,
    malformedRunRequestById,
    nullRequestRunRequestById,
    arrayRequestRunRequestById,
    missingOperationRunRequestById,
    negative: missingNegative,
    corruptNegative,
  }
}

export async function importRegisterPersistReloadAndRunLocalSourceArchiveRequest(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  archiveRootName: string,
  archiveFileName: string,
  metadataPath: string,
  sourceId: string,
  route: string,
  searchRequestJson: string,
  nonSearchRequestJson: string,
): Promise<SourceRuntimeServiceArchiveIngestionRunSummary> {
  const registry = new SourceRuntimeRegistry()
  const importedRegistered = await importAndRegisterLocalSourceArchive(
    registry,
    context,
    resourceMgr,
    rawfilePath,
    archiveRootName,
    archiveFileName,
    sourceId,
    route,
  )
  if (!importedRegistered.ok || importedRegistered.entry === undefined) {
    return sourceRuntimeServiceArchiveIngestionRunRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      0,
      0,
      importedRegistered.reasonCode,
    )
  }

  const persist = persistSourceRuntimeRegistryMetadata(registry, metadataPath)
  if (!persist.ok) {
    return sourceRuntimeServiceArchiveIngestionRunRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      persist.persistedSourceCount,
      0,
      persist.reasonCode,
    )
  }

  const reloaded = reloadSourceRuntimeRegistryFromMetadata(metadataPath)
  if (!reloaded.ok) {
    return sourceRuntimeServiceArchiveIngestionRunRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      persist.persistedSourceCount,
      reloaded.reloadedSourceCount,
      reloaded.reasonCode,
    )
  }

  const installedSourceInventory = listInstalledSourceSummaries(reloaded.registry)
  const inventoryExpectedSourceIdCount = installedSourceInventory.filter(
    (item: SourceRuntimeRegistryInstalledSourceSummary) => item.sourceId === sourceId,
  ).length
  const inventorySafetyOk = sourceRuntimeInstalledSourceInventorySafetyOk(installedSourceInventory)
  const selectedSourceId = inventoryExpectedSourceIdCount === 1 ? sourceId : undefined
  const selectedSourceIdRunRequestById = selectedSourceId === undefined ?
    sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloaded.reloadedSourceCount, 'source_id_not_registered') :
    runRegisteredSourceRequestById(reloaded.registry, selectedSourceId, searchRequestJson)
  const nonSearchRunRequestById = runRegisteredSourceRequestById(reloaded.registry, sourceId, nonSearchRequestJson)
  const unknownSourceRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    'missing.source.id.archive-ingestion-test-only',
    '{"type":"request","version":1,"requestId":"device-archive-ingestion-unknown-001","operation":"search","sourceId":"missing.source.id.archive-ingestion-test-only","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  )
  const sourceIdMismatchRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    sourceId,
    `{"type":"request","version":1,"requestId":"device-archive-ingestion-mismatch-001","operation":"search","sourceId":"${sourceId}.mismatch","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}`,
  )

  return {
    ok: importedRegistered.ok &&
      importedRegistered.entry.importStatus === 'imported' &&
      importedRegistered.entry.hashOk &&
      importedRegistered.entry.network === false &&
      persist.ok &&
      reloaded.ok &&
      persist.persistedSourceCount === 1 &&
      reloaded.reloadedSourceCount === 1 &&
      inventoryExpectedSourceIdCount === 1 &&
      inventorySafetyOk &&
      selectedSourceIdRunRequestById.ok &&
      selectedSourceIdRunRequestById.operation === 'search' &&
      nonSearchRunRequestById.ok &&
      nonSearchRunRequestById.operation === 'get_manga' &&
      !unknownSourceRunRequestById.ok &&
      unknownSourceRunRequestById.reasonCode === 'source_id_not_registered' &&
      unknownSourceRunRequestById.attemptedWamrExecution === false &&
      !sourceIdMismatchRunRequestById.ok &&
      sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch' &&
      sourceIdMismatchRunRequestById.attemptedWamrExecution === false,
    sourceId,
    route,
    metadataPath,
    archivePath: importedRegistered.entry.archivePath,
    importRegister: importedRegistered,
    persistedSourceCount: persist.persistedSourceCount,
    reloadedSourceCount: reloaded.reloadedSourceCount,
    installedSourceInventory,
    installedSourceInventoryOk: inventoryExpectedSourceIdCount === 1 &&
      inventorySafetyOk &&
      selectedSourceIdRunRequestById.ok &&
      selectedSourceIdRunRequestById.operation === 'search',
    inventoryExpectedSourceIdCount,
    inventorySafetyOk,
    selectedSourceId,
    hashOk: importedRegistered.entry.hashOk,
    network: importedRegistered.entry.network,
    searchRunRequestById: selectedSourceIdRunRequestById,
    nonSearchRunRequestById,
    unknownSourceRunRequestById,
    sourceIdMismatchRunRequestById,
  }
}

export async function importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  archiveRootName: string,
  archiveFileName: string,
  metadataPath: string,
  sourceId: string,
  route: string,
  searchRequestJson: string,
): Promise<SourceRuntimeServicePersistedPayloadMissingSummary> {
  const registry = new SourceRuntimeRegistry()
  const importedRegistered = await importAndRegisterLocalSourceArchive(
    registry,
    context,
    resourceMgr,
    rawfilePath,
    archiveRootName,
    archiveFileName,
    sourceId,
    route,
  )
  if (!importedRegistered.ok || importedRegistered.entry === undefined) {
    return sourceRuntimeServicePersistedPayloadMissingRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      0,
      false,
      0,
      importedRegistered.reasonCode,
    )
  }

  const persist = persistSourceRuntimeRegistryMetadata(registry, metadataPath)
  if (!persist.ok) {
    return sourceRuntimeServicePersistedPayloadMissingRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      persist.persistedSourceCount,
      false,
      0,
      persist.reasonCode,
    )
  }

  const wasmPath = importedRegistered.entry.wasmPath
  if (wasmPath === undefined || wasmPath.trim().length === 0 || !fs.accessSync(wasmPath)) {
    return sourceRuntimeServicePersistedPayloadMissingRejected(
      sourceId,
      route,
      metadataPath,
      importedRegistered,
      persist.persistedSourceCount,
      false,
      0,
      'wasm_missing',
    )
  }

  await fs.unlink(wasmPath)
  const reloaded = reloadPersistedSourceInventoryAndRunRequestById(
    metadataPath,
    sourceId,
    route,
    searchRequestJson,
    searchRequestJson,
  )
  const missingPayloadRejected =
    !reloaded.ok &&
      reloaded.reasonCode === 'wasm_missing' &&
      reloaded.searchRunRequestById.reasonCode === 'wasm_missing' &&
      reloaded.searchRunRequestById.attemptedWamrExecution === false
  return {
    ok: missingPayloadRejected && reloaded.reloadOnlyDidNotImportArchive,
    sourceId,
    route,
    reasonCode: reloaded.reasonCode,
    metadataPath,
    archivePath: importedRegistered.entry.archivePath,
    importRegister: importedRegistered,
    persistedSourceCount: persist.persistedSourceCount,
    payloadMutationApplied: !fs.accessSync(wasmPath),
    reloadOnlyDidNotImportArchive: reloaded.reloadOnlyDidNotImportArchive,
    metadataReloadRejected: reloaded.reasonCode === 'wasm_missing',
    reloadedSourceCount: reloaded.reloadedSourceCount,
    searchRunRequestById: reloaded.searchRunRequestById,
  }
}

export function reloadPersistedSourceInventoryAndRunRequestById(
  metadataPath: string,
  sourceId: string,
  route: string,
  searchRequestJson: string,
  nonSearchRequestJson: string,
): SourceRuntimeServicePersistedInventoryReloadSummary {
  const reloaded = reloadSourceRuntimeRegistryFromMetadata(metadataPath)
  if (!reloaded.ok) {
    return sourceRuntimeServicePersistedInventoryReloadRejected(
      sourceId,
      route,
      metadataPath,
      reloaded.reloadedSourceCount,
      reloaded.reasonCode,
    )
  }

  const installedSourceInventory = listInstalledSourceSummaries(reloaded.registry)
  const inventoryExpectedSourceIdCount = installedSourceInventory.filter(
    (item: SourceRuntimeRegistryInstalledSourceSummary) => item.sourceId === sourceId,
  ).length
  const inventorySafetyOk = sourceRuntimeInstalledSourceInventorySafetyOk(installedSourceInventory)
  const selectedSourceId = inventoryExpectedSourceIdCount === 1 ? sourceId : undefined
  const selectedSourceIdRunRequestById = selectedSourceId === undefined ?
    sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloaded.reloadedSourceCount, 'source_id_not_registered') :
    runRegisteredSourceRequestById(reloaded.registry, selectedSourceId, searchRequestJson)
  const nonSearchRunRequestById = runRegisteredSourceRequestById(reloaded.registry, sourceId, nonSearchRequestJson)
  const unknownSourceRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    'missing.source.id.persisted-inventory-reload-test-only',
    '{"type":"request","version":1,"requestId":"device-persisted-inventory-reload-unknown-001","operation":"search","sourceId":"missing.source.id.persisted-inventory-reload-test-only","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}',
  )
  const sourceIdMismatchRunRequestById = runRegisteredSourceRequestById(
    reloaded.registry,
    sourceId,
    `{"type":"request","version":1,"requestId":"device-persisted-inventory-reload-mismatch-001","operation":"search","sourceId":"${sourceId}.mismatch","args":{"query":"fixture"},"settings":{},"hostHints":{"network":false}}`,
  )

  return {
    ok: reloaded.ok &&
      reloaded.reloadedSourceCount === 1 &&
      inventoryExpectedSourceIdCount === 1 &&
      inventorySafetyOk &&
      selectedSourceIdRunRequestById.ok &&
      selectedSourceIdRunRequestById.operation === 'search' &&
      nonSearchRunRequestById.ok &&
      nonSearchRunRequestById.operation === 'get_manga' &&
      !unknownSourceRunRequestById.ok &&
      unknownSourceRunRequestById.reasonCode === 'source_id_not_registered' &&
      unknownSourceRunRequestById.attemptedWamrExecution === false &&
      !sourceIdMismatchRunRequestById.ok &&
      sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch' &&
      sourceIdMismatchRunRequestById.attemptedWamrExecution === false,
    sourceId,
    route,
    metadataPath,
    reloadOnlyDidNotImportArchive: true,
    reloadedSourceCount: reloaded.reloadedSourceCount,
    installedSourceInventory,
    installedSourceInventoryOk: inventoryExpectedSourceIdCount === 1 &&
      inventorySafetyOk &&
      selectedSourceIdRunRequestById.ok &&
      selectedSourceIdRunRequestById.operation === 'search',
    inventoryExpectedSourceIdCount,
    inventorySafetyOk,
    selectedSourceId,
    searchRunRequestById: selectedSourceIdRunRequestById,
    nonSearchRunRequestById,
    unknownSourceRunRequestById,
    sourceIdMismatchRunRequestById,
  }
}

function sourceRuntimeServicePersistedPayloadMissingRejected(
  sourceId: string,
  route: string,
  metadataPath: string,
  importRegister: SourceRuntimeServiceRegistrationSummary,
  persistedSourceCount: number,
  payloadMutationApplied: boolean,
  reloadedSourceCount: number,
  reasonCode?: string,
): SourceRuntimeServicePersistedPayloadMissingSummary {
  return {
    ok: false,
    sourceId,
    route,
    reasonCode,
    metadataPath,
    archivePath: importRegister.entry?.archivePath,
    importRegister,
    persistedSourceCount,
    payloadMutationApplied,
    reloadOnlyDidNotImportArchive: true,
    metadataReloadRejected: reasonCode === 'wasm_missing',
    reloadedSourceCount,
    searchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
  }
}

function sourceRuntimeServicePersistedInventoryReloadRejected(
  sourceId: string,
  route: string,
  metadataPath: string,
  reloadedSourceCount: number,
  reasonCode?: string,
): SourceRuntimeServicePersistedInventoryReloadSummary {
  return {
    ok: false,
    sourceId,
    route,
    reasonCode,
    metadataPath,
    reloadOnlyDidNotImportArchive: true,
    reloadedSourceCount,
    installedSourceInventory: [],
    installedSourceInventoryOk: false,
    inventoryExpectedSourceIdCount: 0,
    inventorySafetyOk: false,
    selectedSourceId: undefined,
    searchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
    nonSearchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
    unknownSourceRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(
      'missing.source.id.persisted-inventory-reload-test-only',
      reloadedSourceCount,
      reasonCode,
    ),
    sourceIdMismatchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
  }
}

function sourceRuntimeServiceArchiveIngestionRunRejected(
  sourceId: string,
  route: string,
  metadataPath: string,
  importRegister: SourceRuntimeServiceRegistrationSummary,
  persistedSourceCount: number,
  reloadedSourceCount: number,
  reasonCode?: string,
): SourceRuntimeServiceArchiveIngestionRunSummary {
  return {
    ok: false,
    sourceId,
    route,
    reasonCode,
    metadataPath,
    importRegister,
    persistedSourceCount,
    reloadedSourceCount,
    installedSourceInventory: [],
    installedSourceInventoryOk: false,
    inventoryExpectedSourceIdCount: 0,
    inventorySafetyOk: false,
    selectedSourceId: undefined,
    hashOk: false,
    network: false,
    searchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
    nonSearchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
    unknownSourceRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(
      'missing.source.id.archive-ingestion-test-only',
      reloadedSourceCount,
      reasonCode,
    ),
    sourceIdMismatchRunRequestById: sourceRuntimeServiceRunRequestByIdRejected(sourceId, reloadedSourceCount, reasonCode),
  }
}

function sourceRuntimeInstalledSourceInventorySafetyOk(
  summaries: SourceRuntimeRegistryInstalledSourceSummary[],
): boolean {
  const serialized = JSON.stringify(summaries)
  return !serialized.includes('manifestPath') &&
    !serialized.includes('wasmPath') &&
    !serialized.includes('archivePath') &&
    !serialized.includes('wasmBytes') &&
    !serialized.includes('runtime') &&
    !serialized.includes('permissions') &&
    !serialized.includes('contentPolicy') &&
    summaries.every((item: SourceRuntimeRegistryInstalledSourceSummary) =>
      item.sourceId.length > 0 &&
        item.displayName.length > 0 &&
        item.version.length > 0 &&
        item.wasmByteCount > 0 &&
        item.importStatus === 'imported' &&
        item.networkEnabled === false &&
        item.httpEnabled === false)
}

function sourceRuntimeServiceRunRequestByIdRejected(
  sourceId: string,
  sourceCount: number,
  reasonCode?: string,
): SourceRuntimeServiceRunRequestByIdSummary {
  return {
    ok: false,
    sourceId,
    reasonCode,
    sourceCount,
    responseOk: false,
    attemptedWamrExecution: false,
  }
}

export function persistSourceRuntimeRegistryMetadata(
  registry: SourceRuntimeRegistry,
  metadataPath: string,
): SourceRuntimeRegistryPersistResult {
  return registry.persistToAppLocalMetadata(metadataPath)
}

export function reloadSourceRuntimeRegistryFromMetadata(metadataPath: string): SourceRuntimeRegistryReloadResult {
  return SourceRuntimeRegistry.reloadFromAppLocalMetadata(metadataPath)
}

export function runSourceRuntimeRegistryReloadNegativeEvidence(
  missingMetadataPath: string,
): SourceRuntimeServiceRegistryReloadNegativeSummary {
  const reloaded = reloadSourceRuntimeRegistryFromMetadata(missingMetadataPath)
  return {
    rejected: !reloaded.ok && reloaded.reasonCode === 'metadata_missing',
    reasonCode: reloaded.reasonCode,
    attemptedWamrExecution: false,
  }
}

export function runSourceRuntimeRegistryReloadCorruptMetadataEvidence(
  corruptMetadataPath: string,
): SourceRuntimeServiceRegistryReloadNegativeSummary {
  try {
    writeTextSync(
      corruptMetadataPath,
      '{"schemaVersion":1,"entries":[{"sourceId":123,"manifestId":"koma.fixture.corrupt-metadata","manifestVersion":"1.0.0","route":"app-local-source-corrupt-metadata-test-only","importStatus":"imported","wasmByteCount":-1,"hashOk":true,"network":false,"wasmPath":"corrupt-metadata-fixture.wasm"}]}',
    )
    const reloaded = reloadSourceRuntimeRegistryFromMetadata(corruptMetadataPath)
    return {
      rejected: !reloaded.ok && reloaded.reasonCode === 'metadata_invalid',
      reasonCode: reloaded.reasonCode,
      attemptedWamrExecution: false,
    }
  } catch (_err) {
    return {
      rejected: false,
      reasonCode: 'metadata_invalid',
      attemptedWamrExecution: false,
    }
  }
}

function sourceRuntimeServiceRegistrationSummary(
  registered: SourceRuntimeRegistryRegisterResult,
): SourceRuntimeServiceRegistrationSummary {
  return {
    ok: registered.ok,
    reasonCode: registered.reasonCode,
    entry: registered.entry,
    sourceCount: registered.sourceCount,
  }
}

export async function importArchiveNegativeFixturesWithoutExecution(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  fixtures: SourceArchiveNegativeCaseFixture[],
  archiveRootName: string,
): Promise<SourceArchiveNegativeImportResult[]> {
  return importArchiveNegativeFixtures(context, resourceMgr, fixtures, archiveRootName)
}
