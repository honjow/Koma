import { common } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { resourceManager } from '@kit.LocalizationKit'

export const SOURCE_PACKAGE_MANIFEST_ID: string = 'local.test.koma.fixture'
export const SOURCE_PACKAGE_MANIFEST_VERSION: string = '0.1.0'
export const SOURCE_PACKAGE_MANIFEST_FILE: string = 'manifest.generated.json'
export const SOURCE_PACKAGE_WASM_FILE: string = 'rust_source_runtime_fixture.wasm'
export const SOURCE_PACKAGE_WASM_SHA256: string = '6d06d3a936bd0316818ec9d5754ea96c9cb33110c520cede6f0945c3eedbb4f8'
export const SOURCE_PACKAGE_WASM_MAX_BYTES: number = 131072

export type SourceArchiveValidationReason =
  'checksum_mismatch' |
  'network_not_allowed' |
  'unsafe_archive_entry' |
  'missing_manifest' |
  'missing_wasm' |
  'manifest_invalid'

export interface SourceArchiveNegativeCaseFixture {
  id: string
  rawfilePath: string
  expectedReason: SourceArchiveValidationReason
}

export interface SourceArchiveNegativeImportResult {
  id: string
  rawfilePath: string
  rejected: boolean
  reasonCode?: string
  expectedReasonCode: string
  reasonMatchesExpected: boolean
  attemptedWamrExecution: boolean
  rawfileBytes?: number
}

export interface LocalSourcePackageInfo {
  id: string
  name: string
  version: string
  language: string
  type: string
  nsfw: boolean
}

export interface LocalSourcePackageRuntime {
  abi: string
  hostAbi: string
  wasmPath: string
  wasmSha256: string
  wasmSizeBytes: number
  maxWasmBytes: number
}

export interface LocalSourcePackagePermissions {
  network: boolean
  hostImports: string[]
}

export interface LocalSourcePackageContentPolicy {
  publicIndex: boolean
  marketplace: boolean
  builtInSource: boolean
  remoteInstall: boolean
}

export interface LocalSourcePackageManifest {
  schemaVersion: number
  package: LocalSourcePackageInfo
  runtime: LocalSourcePackageRuntime
  permissions: LocalSourcePackagePermissions
  contentPolicy: LocalSourcePackageContentPolicy
}

export interface SourcePackageStageResult {
  manifest: LocalSourcePackageManifest
  wasmBytes: Uint8Array
  manifestPath: string
  wasmPath: string
  hashOk: boolean
}

export interface SourceArchiveImportResult {
  ok: boolean
  reasonCode?: SourceArchiveValidationReason
  manifest?: LocalSourcePackageManifest
  wasmBytes?: Uint8Array
  manifestPath?: string
  wasmPath?: string
  wasmBytesLength?: number
  hashOk?: boolean
  attemptedWamrExecution: boolean
}

function joinSourceRuntimePath(parent: string, child: string): string {
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

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
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

function validateArchiveEntries(archiveBytes: Uint8Array): SourceArchiveValidationReason | undefined {
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
    if (name === SOURCE_PACKAGE_MANIFEST_FILE) {
      hasManifest = true
    } else if (name !== SOURCE_PACKAGE_WASM_FILE) {
      return 'unsafe_archive_entry'
    }
  }
  return hasManifest ? undefined : 'missing_manifest'
}

function buildLocalSourcePackageManifest(wasmSize: number): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: SOURCE_PACKAGE_MANIFEST_ID,
      name: 'Koma Local WASM Fixture',
      version: SOURCE_PACKAGE_MANIFEST_VERSION,
      language: 'en',
      type: 'wasm-source-fixture',
      nsfw: false,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: SOURCE_PACKAGE_WASM_FILE,
      wasmSha256: SOURCE_PACKAGE_WASM_SHA256,
      wasmSizeBytes: wasmSize,
      maxWasmBytes: SOURCE_PACKAGE_WASM_MAX_BYTES,
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

export function stageRawfileSourcePackage(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  rawfilePath: string,
  packageRootName: string,
): SourcePackageStageResult {
  const packageRoot = joinSourceRuntimePath(context.filesDir, packageRootName)
  const wasmPath = joinSourceRuntimePath(packageRoot, SOURCE_PACKAGE_WASM_FILE)
  const manifestPath = joinSourceRuntimePath(packageRoot, SOURCE_PACKAGE_MANIFEST_FILE)

  ensureDirSync(packageRoot)
  const rawfileBytes = resourceMgr.getRawFileContentSync(rawfilePath)
  const manifest = buildLocalSourcePackageManifest(rawfileBytes.byteLength)
  writeBytesSync(wasmPath, rawfileBytes)
  writeTextSync(manifestPath, JSON.stringify(manifest))

  const stagedBytes = readBytesSync(wasmPath)
  const stagedHash = sha256Hex(stagedBytes)
  const hashOk = stagedHash === manifest.runtime.wasmSha256 &&
    stagedBytes.byteLength === manifest.runtime.wasmSizeBytes &&
    stagedBytes.byteLength <= SOURCE_PACKAGE_WASM_MAX_BYTES
  if (!hashOk || manifest.package.id !== SOURCE_PACKAGE_MANIFEST_ID ||
    manifest.package.version !== SOURCE_PACKAGE_MANIFEST_VERSION ||
    manifest.permissions.network !== false) {
    throw new Error('local source package manifest/hash validation failed')
  }

  return {
    manifest,
    wasmBytes: stagedBytes,
    manifestPath,
    wasmPath,
    hashOk,
  }
}

export async function importLocalSourceArchive(
  archiveBytes: Uint8Array,
  archivePath: string,
  importedRoot: string,
): Promise<SourceArchiveImportResult> {
  const unsafeReason = validateArchiveEntries(archiveBytes)
  if (unsafeReason !== undefined) {
    return { ok: false, reasonCode: unsafeReason, attemptedWamrExecution: false }
  }

  await removeDirectoryIfPresent(importedRoot)
  ensureDirSync(importedRoot)
  writeBytesSync(archivePath, archiveBytes)
  await zlib.decompressFile(archivePath, importedRoot)

  const manifestPath = joinSourceRuntimePath(importedRoot, SOURCE_PACKAGE_MANIFEST_FILE)
  if (!fs.accessSync(manifestPath)) {
    return { ok: false, reasonCode: 'missing_manifest', manifestPath, attemptedWamrExecution: false }
  }

  let manifest: LocalSourcePackageManifest
  try {
    manifest = JSON.parse(readTextSync(manifestPath)) as LocalSourcePackageManifest
  } catch (_err) {
    return { ok: false, reasonCode: 'manifest_invalid', manifestPath, attemptedWamrExecution: false }
  }

  if (manifest.package.id !== SOURCE_PACKAGE_MANIFEST_ID || manifest.package.version !== SOURCE_PACKAGE_MANIFEST_VERSION) {
    return { ok: false, reasonCode: 'manifest_invalid', manifest, manifestPath, attemptedWamrExecution: false }
  }
  if (manifest.permissions.network !== false || manifest.permissions.hostImports.includes('koma_host.http_request')) {
    return { ok: false, reasonCode: 'network_not_allowed', manifest, manifestPath, attemptedWamrExecution: false }
  }
  if (manifest.runtime.wasmPath !== SOURCE_PACKAGE_WASM_FILE) {
    return { ok: false, reasonCode: 'manifest_invalid', manifest, manifestPath, attemptedWamrExecution: false }
  }

  const importedWasmPath = joinSourceRuntimePath(importedRoot, manifest.runtime.wasmPath)
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

export async function importArchiveNegativeFixtures(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  fixtures: SourceArchiveNegativeCaseFixture[],
  archiveRootName: string,
): Promise<SourceArchiveNegativeImportResult[]> {
  const archiveRoot = joinSourceRuntimePath(context.filesDir, archiveRootName)
  ensureDirSync(archiveRoot)
  const results: SourceArchiveNegativeImportResult[] = []
  for (let index = 0; index < fixtures.length; index += 1) {
    const fixture = fixtures[index]
    const archiveBytes = resourceMgr.getRawFileContentSync(fixture.rawfilePath)
    const caseRoot = joinSourceRuntimePath(archiveRoot, fixture.id)
    const archivePath = joinSourceRuntimePath(caseRoot, `${fixture.id}.zip`)
    const importedRoot = joinSourceRuntimePath(caseRoot, 'imported-package')
    ensureDirSync(caseRoot)
    const imported = await importLocalSourceArchive(archiveBytes, archivePath, importedRoot)
    const rejected = !imported.ok
    results.push({
      id: fixture.id,
      rawfilePath: fixture.rawfilePath,
      rejected,
      reasonCode: imported.reasonCode,
      expectedReasonCode: fixture.expectedReason,
      reasonMatchesExpected: rejected && imported.reasonCode === fixture.expectedReason,
      attemptedWamrExecution: imported.attemptedWamrExecution,
      rawfileBytes: archiveBytes.byteLength,
    })
  }
  return results
}
