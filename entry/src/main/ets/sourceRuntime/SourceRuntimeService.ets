import { common } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
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
  runSourceRuntimeNegativeExecutionFromBytes,
  SourceRuntimeApiOperationsSummary,
  SourceRuntimeNegativeExecutionSummary,
} from './SourceRuntimeRunner'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
  SourceRuntimeRegistryRegisterResult,
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

export interface SourceRuntimeServiceRegistryNegativeSummary {
  duplicateRejected: boolean
  duplicateReasonCode?: string
  missingSourceIdRejected: boolean
  missingSourceIdReasonCode?: string
  invalidRunRejected: boolean
  invalidRunReasonCode?: string
}

function joinSourceRuntimeServicePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
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
  const operations = runSourceApiFixtureOperationsForSourceIdFromBytes(lookup.entry.wasmBytes, lookup.entry.sourceId)
  return {
    ok: operations.ok,
    sourceId: lookup.entry.sourceId,
    sourceCount: lookup.sourceCount,
    sourceApiOperationsOk: operations.ok,
    sourceApiOperations: operations,
  }
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
