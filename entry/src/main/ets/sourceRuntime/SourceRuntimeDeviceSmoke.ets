import { common, Want } from '@kit.AbilityKit'
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
const PACKAGE_MANIFEST_ID: string = 'local.test.koma.fixture'
const PACKAGE_MANIFEST_VERSION: string = '0.1.0'
const PACKAGE_MANIFEST_FILE: string = 'manifest.generated.json'
const PACKAGE_WASM_FILE: string = 'rust_source_runtime_fixture.wasm'
const PACKAGE_WASM_SHA256: string = '6d06d3a936bd0316818ec9d5754ea96c9cb33110c520cede6f0945c3eedbb4f8'
const PACKAGE_WASM_MAX_BYTES: number = 131072

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
  resourceResponse?: SourceRuntimeCallResponse
  rustSourceResponse?: SourceRuntimeCallResponse
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

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
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
  result.packageResponse = packageResponse
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

export function maybeRunSourceRuntimeDeviceSmoke(
  want: Want,
  resourceMgr?: resourceManager.ResourceManager,
  context?: common.UIAbilityContext,
): void {
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

      const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
      result.rustRawfileBytes = rustWasmBytes.byteLength
      result.rustSourceResponse = NativeSourceRuntime.runJsonCallFromBytes(RUST_SMOKE_REQUEST_JSON, rustWasmBytes)
      if (context !== undefined) {
        stageAndRunLocalSourcePackageSmoke(context, resourceMgr, result)
      }
    }
    result.ok = responseReachedFixture(response) &&
      resourceResponse !== undefined &&
      responseReachedFixture(resourceResponse) &&
      result.rustSourceResponse !== undefined &&
      responseReachedRustFixture(result.rustSourceResponse) &&
      result.packageResponse !== undefined &&
      responseReachedRustFixture(result.packageResponse) &&
      result.packageHashOk === true &&
      result.packageNetwork === false
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled, legacy rawfile, Rust source rawfile, and local source package paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}
