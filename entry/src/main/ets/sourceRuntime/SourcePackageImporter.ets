import { common } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { resourceManager } from '@kit.LocalizationKit'

export const SOURCE_PACKAGE_MANIFEST_ID: string = 'local.test.koma.fixture'
export const SOURCE_PACKAGE_MANIFEST_VERSION: string = '0.1.0'
export const SOURCE_PACKAGE_MANIFEST_FILE: string = 'manifest.generated.json'
export const SOURCE_PACKAGE_WASM_FILE: string = 'rust_source_runtime_fixture.wasm'
export const SOURCE_REPO_PACKAGE_MANIFEST_FILE: string = 'manifest.json'
export const SOURCE_REPO_PACKAGE_WASM_FILE: string = 'source.wasm'
export const SOURCE_PACKAGE_WASM_SHA256: string = '255163710202d77fa218f1ccf96fbdcc7ec954b8f8bd1a04e6f15426a2d00161'
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

interface SourceRepoPackageManifest {
  id: string
  name: string
  version: string
  lang?: string
  language?: string
  nsfw?: boolean
  runtime?: string
  entry?: string
  wasmSha256?: string
  sourceWasmSha256?: string
  maxWasmBytes?: number
  capabilities?: SourceRepoPackageCapabilities
  contentPolicy?: SourceRepoPackageContentPolicy
}

interface SourceRepoPackageCapabilities {
  network?: boolean
}

interface SourceRepoPackageContentPolicy {
  publicIndex?: boolean
  marketplace?: boolean
  builtInSource?: boolean
  remoteInstall?: boolean
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
  let hasInternalManifest = false
  let hasSourceRepoManifest = false
  const seen = new Set<string>()
  for (let index = 0; index < names.length; index += 1) {
    const name = names[index]
    if (seen.has(name) || !isSafeArchiveEntryName(name)) {
      return 'unsafe_archive_entry'
    }
    seen.add(name)
    if (name === SOURCE_PACKAGE_MANIFEST_FILE) {
      hasInternalManifest = true
    } else if (name === SOURCE_REPO_PACKAGE_MANIFEST_FILE) {
      hasSourceRepoManifest = true
    }
  }
  if (hasInternalManifest && hasSourceRepoManifest) {
    return 'unsafe_archive_entry'
  }
  if (!hasInternalManifest && !hasSourceRepoManifest) {
    return 'missing_manifest'
  }

  const expectedManifest = hasInternalManifest ? SOURCE_PACKAGE_MANIFEST_FILE : SOURCE_REPO_PACKAGE_MANIFEST_FILE
  const expectedWasm = hasInternalManifest ? SOURCE_PACKAGE_WASM_FILE : SOURCE_REPO_PACKAGE_WASM_FILE
  for (let index = 0; index < names.length; index += 1) {
    const name = names[index]
    if (name !== expectedManifest && name !== expectedWasm) {
      return 'unsafe_archive_entry'
    }
  }
  return undefined
}

function isPlainObject(value: Object | null): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function nonEmptyString(value: Object | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function optionalBoolean(value: Object | undefined, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function optionalNumber(value: Object | undefined, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function parseSourceRepoPackageManifest(raw: string, wasmSize: number): LocalSourcePackageManifest | undefined {
  const parsed = JSON.parse(raw) as SourceRepoPackageManifest
  const id = nonEmptyString(parsed.id)
  const name = nonEmptyString(parsed.name)
  const version = nonEmptyString(parsed.version)
  if (id === undefined || name === undefined || version === undefined || id.length > 96) {
    return undefined
  }

  const capabilities = isPlainObject(parsed.capabilities as Object | null) ? parsed.capabilities : undefined
  const contentPolicy = isPlainObject(parsed.contentPolicy as Object | null) ? parsed.contentPolicy : undefined
  const declaredSha256 = nonEmptyString(parsed.wasmSha256) ?? nonEmptyString(parsed.sourceWasmSha256) ?? ''
  const maxWasmBytes = optionalNumber(parsed.maxWasmBytes, Math.max(wasmSize, SOURCE_PACKAGE_WASM_MAX_BYTES))
  return {
    schemaVersion: 1,
    package: {
      id,
      name,
      version,
      language: nonEmptyString(parsed.language) ?? nonEmptyString(parsed.lang) ?? 'multi',
      type: nonEmptyString(parsed.runtime) ?? 'wasm-source',
      nsfw: optionalBoolean(parsed.nsfw, false),
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: SOURCE_REPO_PACKAGE_WASM_FILE,
      wasmSha256: declaredSha256,
      wasmSizeBytes: wasmSize,
      maxWasmBytes,
    },
    permissions: {
      network: optionalBoolean(capabilities?.network, false),
      hostImports: [],
    },
    contentPolicy: {
      publicIndex: optionalBoolean(contentPolicy?.publicIndex, false),
      marketplace: optionalBoolean(contentPolicy?.marketplace, false),
      builtInSource: optionalBoolean(contentPolicy?.builtInSource, false),
      remoteInstall: optionalBoolean(contentPolicy?.remoteInstall, false),
    },
  }
}

function validateNormalizedManifest(manifest: LocalSourcePackageManifest): SourceArchiveValidationReason | undefined {
  if (manifest.package.id.length === 0 || manifest.package.version.length === 0 || manifest.package.id.length > 96) {
    return 'manifest_invalid'
  }
  if (manifest.permissions.network !== false || manifest.permissions.hostImports.includes('koma_host.http_request')) {
    return 'network_not_allowed'
  }
  if (manifest.contentPolicy.marketplace || manifest.contentPolicy.builtInSource || manifest.contentPolicy.remoteInstall) {
    return 'network_not_allowed'
  }
  if (manifest.runtime.wasmPath !== SOURCE_PACKAGE_WASM_FILE && manifest.runtime.wasmPath !== SOURCE_REPO_PACKAGE_WASM_FILE) {
    return 'manifest_invalid'
  }
  return undefined
}

function validateImportedWasmBytes(manifest: LocalSourcePackageManifest, importedWasmBytes: Uint8Array): boolean {
  const importedHash = sha256Hex(importedWasmBytes)
  const sizeOk = importedWasmBytes.byteLength === manifest.runtime.wasmSizeBytes &&
    importedWasmBytes.byteLength <= manifest.runtime.maxWasmBytes
  const declaredHash = manifest.runtime.wasmSha256
  return sizeOk && (declaredHash.length === 0 || importedHash === declaredHash)
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

  let manifestPath = joinSourceRuntimePath(importedRoot, SOURCE_PACKAGE_MANIFEST_FILE)
  let sourceRepoLayout = false
  if (!fs.accessSync(manifestPath)) {
    manifestPath = joinSourceRuntimePath(importedRoot, SOURCE_REPO_PACKAGE_MANIFEST_FILE)
    sourceRepoLayout = true
  }
  if (!fs.accessSync(manifestPath)) {
    return { ok: false, reasonCode: 'missing_manifest', manifestPath, attemptedWamrExecution: false }
  }

  let manifest: LocalSourcePackageManifest
  try {
    if (sourceRepoLayout) {
      const sourceRepoWasmPath = joinSourceRuntimePath(importedRoot, SOURCE_REPO_PACKAGE_WASM_FILE)
      const wasmSize = fs.accessSync(sourceRepoWasmPath) ? fs.statSync(sourceRepoWasmPath).size : 0
      const normalizedManifest = parseSourceRepoPackageManifest(readTextSync(manifestPath), wasmSize)
      if (normalizedManifest === undefined) {
        return { ok: false, reasonCode: 'manifest_invalid', manifestPath, attemptedWamrExecution: false }
      }
      manifest = normalizedManifest
    } else {
      manifest = JSON.parse(readTextSync(manifestPath)) as LocalSourcePackageManifest
    }
  } catch (_err) {
    return { ok: false, reasonCode: 'manifest_invalid', manifestPath, attemptedWamrExecution: false }
  }

  const manifestReason = validateNormalizedManifest(manifest)
  if (manifestReason !== undefined) {
    return { ok: false, reasonCode: manifestReason, manifest, manifestPath, attemptedWamrExecution: false }
  }

  const importedWasmPath = joinSourceRuntimePath(importedRoot, manifest.runtime.wasmPath)
  if (!fs.accessSync(importedWasmPath)) {
    return { ok: false, reasonCode: 'missing_wasm', manifest, manifestPath, wasmPath: importedWasmPath, attemptedWamrExecution: false }
  }

  const importedWasmBytes = readBytesSync(importedWasmPath)
  const hashOk = validateImportedWasmBytes(manifest, importedWasmBytes)
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
