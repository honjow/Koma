import { common, Want } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { resourceManager } from '@kit.LocalizationKit'
import { NativeSourceRuntime, SourceRuntimeCallResponse } from './NativeSourceRuntime'

const SMOKE_TRIGGER_PARAM: string = 'koma.sourceRuntimeSmoke'
const SMOKE_TRIGGER_VALUE: string = 'run'
const SMOKE_REQUEST_JSON: string = '{"query":"fixture","smoke":"koma-smoke"}'
const RUST_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-rust-smoke"}'
const PACKAGE_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-package-smoke"}'
const SMOKE_LOG_PREFIX: string = 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT '
const SMOKE_RAWFILE_PATH: string = 'test/source_runtime_fixture.wasm'
const RUST_SMOKE_RAWFILE_PATH: string = 'test/rust_source_runtime_fixture.wasm'
const PACKAGE_ROUTE_LABEL: string = 'app-local-source-package-test-only'
const ARCHIVE_ROUTE_LABEL: string = 'app-local-source-archive-import-test-only'
const PACKAGE_MANIFEST_ID: string = 'local.test.koma.fixture'
const PACKAGE_MANIFEST_VERSION: string = '0.1.0'
const PACKAGE_MANIFEST_FILE: string = 'manifest.generated.json'
const PACKAGE_WASM_FILE: string = 'rust_source_runtime_fixture.wasm'
const PACKAGE_WASM_SHA256: string = '6d06d3a936bd0316818ec9d5754ea96c9cb33110c520cede6f0945c3eedbb4f8'
const PACKAGE_WASM_MAX_BYTES: number = 131072
const ARCHIVE_RAWFILE_PATH: string = 'test/local_source_runtime_fixture.koma-source'
const ARCHIVE_SANDBOX_ZIP_FILE: string = 'local_source_runtime_fixture.zip'
const ARCHIVE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-archive-smoke"}'
const ARCHIVE_NEGATIVE_ROUTE_LABEL: string = 'app-local-source-archive-negative-test-only'
const ARCHIVE_NEGATIVE_CASES: ArchiveNegativeCaseFixture[] = [
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

type ArchiveValidationReason =
  'checksum_mismatch' |
  'network_not_allowed' |
  'unsafe_archive_entry' |
  'missing_manifest' |
  'missing_wasm' |
  'manifest_invalid'

interface ArchiveNegativeCaseFixture {
  id: string
  rawfilePath: string
  expectedReason: ArchiveValidationReason
}

interface ArchiveImportValidationResult {
  ok: boolean
  reasonCode?: ArchiveValidationReason
  manifest?: LocalSourcePackageManifest
  wasmBytes?: Uint8Array
  manifestPath?: string
  wasmPath?: string
  wasmBytesLength?: number
  hashOk?: boolean
  attemptedWamrExecution: boolean
}

export interface ArchiveNegativeSmokeCaseResult {
  id: string
  rawfilePath: string
  rejected: boolean
  reasonCode?: string
  expectedReasonCode: string
  reasonMatchesExpected: boolean
  attemptedWamrExecution: boolean
  rawfileBytes?: number
}

type WantParameterValue = Object | string | number | boolean | null | undefined
type WantParameters = Record<string, WantParameterValue>

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
  packageResponse?: SourceRuntimeCallResponse
  packageResponseOk?: boolean
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
  archiveNegativeCases?: ArchiveNegativeSmokeCaseResult[]
  error?: string
}

interface LocalSourcePackageInfo {
  id: string
  name: string
  version: string
  language: string
  type: string
  nsfw: boolean
}

interface LocalSourcePackageRuntime {
  abi: string
  hostAbi: string
  wasmPath: string
  wasmSha256: string
  wasmSizeBytes: number
  maxWasmBytes: number
}

interface LocalSourcePackagePermissions {
  network: boolean
  hostImports: string[]
}

interface LocalSourcePackageContentPolicy {
  publicIndex: boolean
  marketplace: boolean
  builtInSource: boolean
  remoteInstall: boolean
}

interface LocalSourcePackageManifest {
  schemaVersion: number
  package: LocalSourcePackageInfo
  runtime: LocalSourcePackageRuntime
  permissions: LocalSourcePackagePermissions
  contentPolicy: LocalSourcePackageContentPolicy
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

function responseReachedRustFixture(response: SourceRuntimeCallResponse): boolean {
  return response.ok === true &&
    response.operation === 'search' &&
    response.data !== undefined &&
    response.data.requestEcho === 'fixture' &&
    JSON.stringify(response).includes('Fixture Series') &&
    JSON.stringify(response).includes('"network":false')
}

function joinSmokePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
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

function bytesToExactArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const exact = new Uint8Array(bytes.byteLength)
  exact.set(bytes)
  return exact.buffer
}

function writeBytesSync(path: string, bytes: Uint8Array): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, bytesToExactArrayBuffer(bytes))
  } finally {
    closeFileQuietly(file)
  }
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
}

function readBytesSync(path: string): Uint8Array {
  let file: fs.File | undefined = undefined
  try {
    const stat = fs.statSync(path)
    const buffer = new ArrayBuffer(stat.size)
    file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    const readBytes = fs.readSync(file.fd, buffer)
    return new Uint8Array(buffer, 0, readBytes)
  } finally {
    closeFileQuietly(file)
  }
}

function readTextSync(path: string): string {
  return fs.readTextSync(path, { encoding: 'utf-8' })
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

async function removeDirectoryIfPresent(path: string): Promise<void> {
  try {
    await fs.rmdir(path)
  } catch (_err) {
  }
}

function sha256Hex(bytes: Uint8Array): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: bytes })
  const digest = md.digestSync().data
  let result = ''
  for (let index = 0; index < digest.length; index += 1) {
    result += digest[index].toString(16).padStart(2, '0')
  }
  return result
}

function readUInt16Le(bytes: Uint8Array, offset: number): number {
  return bytes[offset] | (bytes[offset + 1] << 8)
}

function readUInt32Le(bytes: Uint8Array, offset: number): number {
  return (bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)) >>> 0
}

function decodeAscii(bytes: Uint8Array, offset: number, length: number): string {
  let value = ''
  for (let index = 0; index < length; index += 1) {
    value += String.fromCharCode(bytes[offset + index])
  }
  return value
}

function isSafeArchiveEntryName(name: string): boolean {
  if (name.length === 0 || name.endsWith('/') || name.startsWith('/') || name.includes('\\')) {
    return false
  }
  const parts = name.split('/')
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index]
    if (part.length === 0 || part === '..' || part.startsWith('.')) {
      return false
    }
  }
  return true
}

function readArchiveEntryNames(archiveBytes: Uint8Array): string[] {
  const minEocdSize = 22
  if (archiveBytes.byteLength < minEocdSize) {
    throw new Error('zip_eocd_missing')
  }
  let eocdOffset = -1
  const firstPossible = Math.max(0, archiveBytes.byteLength - 65557)
  for (let offset = archiveBytes.byteLength - minEocdSize; offset >= firstPossible; offset -= 1) {
    if (readUInt32Le(archiveBytes, offset) === 0x06054b50) {
      eocdOffset = offset
      break
    }
  }
  if (eocdOffset < 0) {
    throw new Error('zip_eocd_missing')
  }
  const entryCount = readUInt16Le(archiveBytes, eocdOffset + 10)
  const centralDirectorySize = readUInt32Le(archiveBytes, eocdOffset + 12)
  const centralDirectoryOffset = readUInt32Le(archiveBytes, eocdOffset + 16)
  if (centralDirectoryOffset + centralDirectorySize > archiveBytes.byteLength) {
    throw new Error('zip_central_directory_invalid')
  }

  const names: string[] = []
  let offset = centralDirectoryOffset
  for (let index = 0; index < entryCount; index += 1) {
    if (offset + 46 > archiveBytes.byteLength || readUInt32Le(archiveBytes, offset) !== 0x02014b50) {
      throw new Error('zip_central_directory_invalid')
    }
    const nameLength = readUInt16Le(archiveBytes, offset + 28)
    const extraLength = readUInt16Le(archiveBytes, offset + 30)
    const commentLength = readUInt16Le(archiveBytes, offset + 32)
    const nameOffset = offset + 46
    const nextOffset = nameOffset + nameLength + extraLength + commentLength
    if (nextOffset > archiveBytes.byteLength) {
      throw new Error('zip_central_directory_invalid')
    }
    names.push(decodeAscii(archiveBytes, nameOffset, nameLength))
    offset = nextOffset
  }
  return names
}

function validateArchiveEntries(archiveBytes: Uint8Array): ArchiveValidationReason | undefined {
  let names: string[]
  try {
    names = readArchiveEntryNames(archiveBytes)
  } catch (_err) {
    return 'unsafe_archive_entry'
  }
  let hasManifest = false
  const seen = new Set<string>()
  for (let index = 0; index < names.length; index += 1) {
    const name = names[index]
    if (seen.has(name) || !isSafeArchiveEntryName(name)) {
      return 'unsafe_archive_entry'
    }
    seen.add(name)
    if (name === PACKAGE_MANIFEST_FILE) {
      hasManifest = true
    } else if (name !== PACKAGE_WASM_FILE) {
      return 'unsafe_archive_entry'
    }
  }
  return hasManifest ? undefined : 'missing_manifest'
}

function buildLocalSourcePackageManifest(wasmSize: number): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: PACKAGE_MANIFEST_ID,
      name: 'Koma Local WASM Fixture',
      version: PACKAGE_MANIFEST_VERSION,
      language: 'en',
      type: 'wasm-source-fixture',
      nsfw: false,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: PACKAGE_WASM_FILE,
      wasmSha256: PACKAGE_WASM_SHA256,
      wasmSizeBytes: wasmSize,
      maxWasmBytes: PACKAGE_WASM_MAX_BYTES,
    },
    permissions: {
      network: false,
      hostImports: ['koma_host.log', 'koma_host.check_cancel'],
    },
    contentPolicy: {
      publicIndex: false,
      marketplace: false,
      builtInSource: false,
      remoteInstall: false,
    },
  }
}

function firstItemTitle(response: SourceRuntimeCallResponse): string | undefined {
  const items = response.data?.items
  if (items === undefined || items.length === 0) {
    return undefined
  }
  const title = items[0]['title']
  return typeof title === 'string' ? title : undefined
}

function stageAndRunLocalSourcePackageSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): void {
  const packageRoot = joinSmokePath(context.filesDir, 'source-runtime-package-smoke')
  const wasmPath = joinSmokePath(packageRoot, PACKAGE_WASM_FILE)
  const manifestPath = joinSmokePath(packageRoot, PACKAGE_MANIFEST_FILE)

  ensureDirSync(packageRoot)
  const rawfileBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
  const manifest = buildLocalSourcePackageManifest(rawfileBytes.byteLength)
  writeBytesSync(wasmPath, rawfileBytes)
  writeTextSync(manifestPath, JSON.stringify(manifest))

  const stagedBytes = readBytesSync(wasmPath)
  const stagedHash = sha256Hex(stagedBytes)
  const packageHashOk = stagedHash === manifest.runtime.wasmSha256 &&
    stagedBytes.byteLength === manifest.runtime.wasmSizeBytes &&
    stagedBytes.byteLength <= PACKAGE_WASM_MAX_BYTES
  if (!packageHashOk || manifest.package.id !== PACKAGE_MANIFEST_ID ||
    manifest.package.version !== PACKAGE_MANIFEST_VERSION ||
    manifest.permissions.network !== false) {
    throw new Error('local source package manifest/hash validation failed')
  }

  const packageResponse = NativeSourceRuntime.runJsonCallFromBytes(PACKAGE_SMOKE_REQUEST_JSON, stagedBytes)
  result.packageResponseOk = responseReachedRustFixture(packageResponse)
  result.packageOperation = packageResponse.operation
  result.packageRequestEcho = packageResponse.data?.requestEcho
  result.packageFirstTitle = firstItemTitle(packageResponse)
  result.packageNetwork = packageResponse.hostHints?.['network'] === false ? false : undefined
  result.packageWasmBytes = stagedBytes.byteLength
  result.packageManifestId = manifest.package.id
  result.packageManifestVersion = manifest.package.version
  result.packageManifestPath = manifestPath
  result.packageWasmPath = wasmPath
  result.packageHashOk = packageHashOk
  result.packageRoute = PACKAGE_ROUTE_LABEL
}

async function stageImportAndRunLocalSourceArchiveSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const archiveRoot = joinSmokePath(context.filesDir, 'source-runtime-archive-smoke')
  const importedRoot = joinSmokePath(archiveRoot, 'imported-package')
  const archivePath = joinSmokePath(archiveRoot, ARCHIVE_SANDBOX_ZIP_FILE)

  ensureDirSync(archiveRoot)
  const archiveBytes = resourceMgr.getRawFileContentSync(ARCHIVE_RAWFILE_PATH)
  const validated = await validateLocalSourceArchive(archiveBytes, archivePath, importedRoot)
  if (!validated.ok || validated.manifest === undefined || validated.wasmBytes === undefined) {
    throw new Error(`local source archive import rejected: ${validated.reasonCode}`)
  }

  validated.attemptedWamrExecution = true
  const archiveResponse = NativeSourceRuntime.runJsonCallFromBytes(ARCHIVE_REQUEST_JSON, validated.wasmBytes)
  result.archiveResponseOk = responseReachedRustFixture(archiveResponse)
  result.archiveOperation = archiveResponse.operation
  result.archiveRequestEcho = archiveResponse.data?.requestEcho
  result.archiveFirstTitle = firstItemTitle(archiveResponse)
  result.archiveNetwork = archiveResponse.hostHints?.['network'] === false ? false : undefined
  result.archiveWasmBytes = validated.wasmBytes.byteLength
  result.archiveManifestId = validated.manifest.package.id
  result.archiveManifestVersion = validated.manifest.package.version
  result.archiveManifestPath = validated.manifestPath
  result.archiveImportedWasmPath = validated.wasmPath
  result.archiveHashOk = validated.hashOk
  result.archiveImportOk = true
  result.archivePath = archivePath
  result.archiveRoute = ARCHIVE_ROUTE_LABEL
}

async function validateLocalSourceArchive(
  archiveBytes: Uint8Array,
  archivePath: string,
  importedRoot: string,
): Promise<ArchiveImportValidationResult> {
  const unsafeReason = validateArchiveEntries(archiveBytes)
  if (unsafeReason !== undefined) {
    return { ok: false, reasonCode: unsafeReason, attemptedWamrExecution: false }
  }

  await removeDirectoryIfPresent(importedRoot)
  ensureDirSync(importedRoot)
  writeBytesSync(archivePath, archiveBytes)
  await zlib.decompressFile(archivePath, importedRoot)

  const manifestPath = joinSmokePath(importedRoot, PACKAGE_MANIFEST_FILE)
  if (!fs.accessSync(manifestPath)) {
    return { ok: false, reasonCode: 'missing_manifest', manifestPath, attemptedWamrExecution: false }
  }

  let manifest: LocalSourcePackageManifest
  try {
    manifest = JSON.parse(readTextSync(manifestPath)) as LocalSourcePackageManifest
  } catch (_err) {
    return { ok: false, reasonCode: 'manifest_invalid', manifestPath, attemptedWamrExecution: false }
  }

  if (manifest.package.id !== PACKAGE_MANIFEST_ID || manifest.package.version !== PACKAGE_MANIFEST_VERSION) {
    return { ok: false, reasonCode: 'manifest_invalid', manifest, manifestPath, attemptedWamrExecution: false }
  }
  if (manifest.permissions.network !== false || manifest.permissions.hostImports.includes('koma_host.http_request')) {
    return { ok: false, reasonCode: 'network_not_allowed', manifest, manifestPath, attemptedWamrExecution: false }
  }
  if (manifest.runtime.wasmPath !== PACKAGE_WASM_FILE) {
    return { ok: false, reasonCode: 'manifest_invalid', manifest, manifestPath, attemptedWamrExecution: false }
  }

  const importedWasmPath = joinSmokePath(importedRoot, manifest.runtime.wasmPath)
  if (!fs.accessSync(importedWasmPath)) {
    return { ok: false, reasonCode: 'missing_wasm', manifest, manifestPath, wasmPath: importedWasmPath, attemptedWamrExecution: false }
  }

  const importedWasmBytes = readBytesSync(importedWasmPath)
  const importedHash = sha256Hex(importedWasmBytes)
  const hashOk = importedHash === manifest.runtime.wasmSha256 &&
    importedWasmBytes.byteLength === manifest.runtime.wasmSizeBytes &&
    importedWasmBytes.byteLength <= manifest.runtime.maxWasmBytes
  if (!hashOk) {
    return {
      ok: false,
      reasonCode: 'checksum_mismatch',
      manifest,
      manifestPath,
      wasmPath: importedWasmPath,
      wasmBytesLength: importedWasmBytes.byteLength,
      hashOk,
      attemptedWamrExecution: false,
    }
  }

  return {
    ok: true,
    manifest,
    wasmBytes: importedWasmBytes,
    manifestPath,
    wasmPath: importedWasmPath,
    wasmBytesLength: importedWasmBytes.byteLength,
    hashOk,
    attemptedWamrExecution: false,
  }
}

async function runArchiveNegativeSmokeCases(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
): Promise<ArchiveNegativeSmokeCaseResult[]> {
  const archiveRoot = joinSmokePath(context.filesDir, 'source-runtime-archive-negative-smoke')
  ensureDirSync(archiveRoot)
  const results: ArchiveNegativeSmokeCaseResult[] = []
  for (let index = 0; index < ARCHIVE_NEGATIVE_CASES.length; index += 1) {
    const fixture = ARCHIVE_NEGATIVE_CASES[index]
    const archiveBytes = resourceMgr.getRawFileContentSync(fixture.rawfilePath)
    const caseRoot = joinSmokePath(archiveRoot, fixture.id)
    const archivePath = joinSmokePath(caseRoot, `${fixture.id}.zip`)
    const importedRoot = joinSmokePath(caseRoot, 'imported-package')
    ensureDirSync(caseRoot)
    const validated = await validateLocalSourceArchive(archiveBytes, archivePath, importedRoot)
    const rejected = !validated.ok
    results.push({
      id: fixture.id,
      rawfilePath: fixture.rawfilePath,
      rejected,
      reasonCode: validated.reasonCode,
      expectedReasonCode: fixture.expectedReason,
      reasonMatchesExpected: rejected && validated.reasonCode === fixture.expectedReason,
      attemptedWamrExecution: validated.attemptedWamrExecution,
      rawfileBytes: archiveBytes.byteLength,
    })
  }
  return results
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
    const response = NativeSourceRuntime.runJsonCall(SMOKE_REQUEST_JSON)
    result.responseOk = responseReachedFixture(response)
    let resourceResponse: SourceRuntimeCallResponse | undefined = undefined
    let rustSourceResponseOk = false
    if (resourceMgr !== undefined) {
      const wasmBytes = resourceMgr.getRawFileContentSync(SMOKE_RAWFILE_PATH)
      result.rawfileBytes = wasmBytes.byteLength
      resourceResponse = NativeSourceRuntime.runJsonCallFromBytes(SMOKE_REQUEST_JSON, wasmBytes)
      result.resourceResponseOk = responseReachedFixture(resourceResponse)

      const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
      result.rustRawfileBytes = rustWasmBytes.byteLength
      const rustSourceResponse = NativeSourceRuntime.runJsonCallFromBytes(RUST_SMOKE_REQUEST_JSON, rustWasmBytes)
      rustSourceResponseOk = responseReachedRustFixture(rustSourceResponse)
      result.rustSourceResponseOk = rustSourceResponseOk
      if (context !== undefined) {
        stageAndRunLocalSourcePackageSmoke(context, resourceMgr, result)
        await stageImportAndRunLocalSourceArchiveSmoke(context, resourceMgr, result)
        result.archiveNegativeCases = await runArchiveNegativeSmokeCases(context, resourceMgr)
        result.archiveNegativeOk = result.archiveNegativeCases.length === ARCHIVE_NEGATIVE_CASES.length &&
          result.archiveNegativeCases.every((item: ArchiveNegativeSmokeCaseResult) =>
            item.rejected && item.reasonMatchesExpected && item.attemptedWamrExecution === false)
      }
    }
    result.ok = result.responseOk === true &&
      resourceResponse !== undefined &&
      result.resourceResponseOk === true &&
      rustSourceResponseOk &&
      result.packageResponseOk === true &&
      result.packageHashOk === true &&
      result.packageNetwork === false &&
      result.archiveImportOk === true &&
      result.archiveResponseOk === true &&
      result.archiveHashOk === true &&
      result.archiveNetwork === false &&
      result.archiveNegativeOk === true
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled, legacy rawfile, Rust source rawfile, local source package, local source archive import, and archive negative rejection paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
