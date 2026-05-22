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
  runSourceApiFixtureOperationsFromBytes,
  SourceRuntimeApiOperationsSummary,
} from './SourceRuntimeRunner'

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
  attemptedWamrExecution: boolean
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
    attemptedWamrExecution: true,
  }
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
    attemptedWamrExecution: true,
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
