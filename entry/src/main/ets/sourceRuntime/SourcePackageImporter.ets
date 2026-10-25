import { SourceChapterOrder, isValidSourceChapterOrder } from './SourceChapterOrder'
import { taskpool, url } from '@kit.ArkTS'
import { computeSourcePackageSha256 } from './SourcePackageHashWorker'
import { isInvalidSourceLocalizedNames, normalizeSourceLocalizedNames } from './SourceLocalizedNames'
import { common } from '@kit.AbilityKit'
import { zlib } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { resourceManager } from '@kit.LocalizationKit'

export const SOURCE_PACKAGE_MANIFEST_ID: string = 'local.test.koma.fixture'
export const SOURCE_PACKAGE_MANIFEST_VERSION: string = '0.1.0'
export const SOURCE_PACKAGE_MANIFEST_FILE: string = 'manifest.generated.json'
export const SOURCE_PACKAGE_WASM_FILE: string = 'rust_source_runtime_fixture.wasm'
export const SOURCE_REPO_PACKAGE_MANIFEST_FILE: string = 'manifest.json'
export const SOURCE_REPO_PACKAGE_WASM_FILE: string = 'source.wasm'
// Production packages require exactly one package-owned root identity asset.
// Retain the image format; display cropping belongs to the UI, not these bytes.
export const SOURCE_REPO_PACKAGE_ICON_FILE: string = 'icon.png'
export const SOURCE_REPO_PACKAGE_ICON_MAX_BYTES: number = 1024 * 1024
export const SOURCE_REPO_PACKAGE_ICON_MAX_PIXELS: number = 1024 * 1024
export const SOURCE_REPO_PACKAGE_ICON_FILES: string[] = [
  'icon.png', 'icon.jpg', 'icon.jpeg', 'icon.gif', 'icon.webp', 'icon.ico',
]
export const SOURCE_PACKAGE_WASM_SHA256: string = '255163710202d77fa218f1ccf96fbdcc7ec954b8f8bd1a04e6f15426a2d00161'
export const SOURCE_PACKAGE_WASM_MAX_BYTES: number = 131072

// Source packages deliberately use the same compact version shape as the
// host app's versionName. Keeping this parser here makes archive import,
// backup restore, index checks, and cold reload reject the same malformed
// value instead of each path interpreting it differently.
const SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN: RegExp = /^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})$/

export type SourceArchiveValidationReason =
  'checksum_mismatch' |
  'network_not_allowed' |
  'unsafe_archive_entry' |
  'missing_manifest' |
  'missing_wasm' |
  'manifest_invalid' |
  'invalid_icon' |
  'missing_icon'

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
  chapterOrder?: SourceChapterOrder
  id: string
  name: string
  localizedNames?: Record<string, string>
  version: string
  language: string
  type: string
  nsfw: boolean
  // Optional package-owned identity metadata. These are deliberately
  // independent from the source-index presentation fields kept by the host.
  homepage?: string
  author?: string
  description?: string
  contentRating?: string
  minAppVersion?: string
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
  webSessionOrigins?: string[]
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
  operationCapabilities?: string[]
}

interface SourceRepoPackageManifest {
  chapterOrder?: SourceChapterOrder
  webSessionOrigins?: string[]
  icon?: string
  id: string
  name: string
  localizedNames?: Record<string, string>
  version: string
  lang?: string
  language?: string
  nsfw?: boolean
  homepage?: string
  author?: string
  description?: string
  contentRating?: string
  minAppVersion?: string
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
  operations?: string[]
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
  iconPath?: string
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
  return computeSourcePackageSha256(bytes)
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

interface SourceArchiveEntry {
  name: string
  uncompressedSize: number
  externalAttributes: number
}

function archiveEntryIsSymlink(entry: SourceArchiveEntry): boolean {
  const unixMode = (entry.externalAttributes >>> 16) & 0o777777
  return (unixMode & 0o170000) === 0o120000
}

function readArchiveEntries(archiveBytes: Uint8Array): SourceArchiveEntry[] {
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

  const entries: SourceArchiveEntry[] = []
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
    entries.push({
      name: decodeAscii(archiveBytes, nameOffset, nameLength),
      uncompressedSize: readUInt32Le(archiveBytes, offset + 24),
      externalAttributes: readUInt32Le(archiveBytes, offset + 38),
    })
    offset = nextOffset
  }
  return entries
}

function validateArchiveEntries(archiveBytes: Uint8Array): SourceArchiveValidationReason | undefined {
  let entries: SourceArchiveEntry[]
  try {
    entries = readArchiveEntries(archiveBytes)
  } catch (_err) {
    return 'unsafe_archive_entry'
  }
  let hasInternalManifest = false
  let hasSourceRepoManifest = false
  let iconEntry: SourceArchiveEntry | undefined = undefined
  const seen = new Set<string>()
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index]
    const name = entry.name
    if (seen.has(name) || !isSafeArchiveEntryName(name) || archiveEntryIsSymlink(entry)) {
      return 'unsafe_archive_entry'
    }
    seen.add(name)
    if (name === SOURCE_PACKAGE_MANIFEST_FILE) {
      hasInternalManifest = true
    } else if (name === SOURCE_REPO_PACKAGE_MANIFEST_FILE) {
      hasSourceRepoManifest = true
    } else if (isSourcePackageIconFileName(name)) {
      if (iconEntry !== undefined) return 'invalid_icon'
      iconEntry = entry
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
  const expectedIcon = hasSourceRepoManifest && iconEntry !== undefined ? iconEntry.name : ''
  for (let index = 0; index < entries.length; index += 1) {
    const name = entries[index].name
    if (name !== expectedManifest && name !== expectedWasm && name !== expectedIcon) {
      return 'unsafe_archive_entry'
    }
  }
  if (hasSourceRepoManifest && iconEntry === undefined) return 'missing_icon'
  if (iconEntry !== undefined &&
    (iconEntry.uncompressedSize <= 0 || iconEntry.uncompressedSize > SOURCE_REPO_PACKAGE_ICON_MAX_BYTES)) {
    return 'invalid_icon'
  }
  return undefined
}

export function isSourcePackageIconFileName(name: string): boolean {
  return SOURCE_REPO_PACKAGE_ICON_FILES.includes(name)
}

// Identify formats, not a hand-selected subset of their internal layouts.
// The platform decoder validates the complete image before any publication.
export function sourcePackageIconFileName(bytes: Uint8Array): string | undefined {
  if (bytes.byteLength === 0 || bytes.byteLength > SOURCE_REPO_PACKAGE_ICON_MAX_BYTES) return undefined
  if (bytes.length >= 8 && bytes[0] === 0x89 && decodeAscii(bytes, 1, 3) === 'PNG' &&
    bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10) return 'icon.png'
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'icon.jpg'
  if (bytes.length >= 6 && (decodeAscii(bytes, 0, 6) === 'GIF87a' ||
    decodeAscii(bytes, 0, 6) === 'GIF89a')) return 'icon.gif'
  if (bytes.length >= 12 && decodeAscii(bytes, 0, 4) === 'RIFF' &&
    decodeAscii(bytes, 8, 4) === 'WEBP') return 'icon.webp'
  if (bytes.length >= 6 && bytes[0] === 0 && bytes[1] === 0 && bytes[2] === 1 && bytes[3] === 0 &&
    (bytes[4] !== 0 || bytes[5] !== 0)) return 'icon.ico'
  return undefined
}

export function sourcePackageIconMatchesFileName(bytes: Uint8Array, name: string): boolean {
  const detected = sourcePackageIconFileName(bytes)
  return detected !== undefined && (detected === name || (detected === 'icon.jpg' && name === 'icon.jpeg'))
}

export function validateSourcePackageIconBytes(iconBytes: Uint8Array): boolean {
  return sourcePackageIconFileName(iconBytes) !== undefined
}

// The byte-level boundary keeps archive extraction bounded; this second
// boundary asks ImageKit to decode the extracted file before it is published
// to the source list. ImageSource calls stay sequential and are released only
// after both metadata and pixel decoding have finished.
export async function validateSourcePackageIconFile(iconPath: string): Promise<boolean> {
  let imageSource: image.ImageSource | undefined = undefined
  let pixelMap: image.PixelMap | undefined = undefined
  try {
    imageSource = image.createImageSource(iconPath)
    const info = await imageSource.getImageInfo()
    const width = info.size.width
    const height = info.size.height
    if (width <= 0 || height <= 0 ||
      width * height > SOURCE_REPO_PACKAGE_ICON_MAX_PIXELS) {
      return false
    }
    pixelMap = await imageSource.createPixelMap({
      desiredSize: {
        width: 1,
        height: 1,
      },
    })
    return true
  } catch (_err) {
    return false
  } finally {
    if (pixelMap !== undefined) {
      try {
        await pixelMap.release()
      } catch (_err) {
      }
    }
    if (imageSource !== undefined) {
      try {
        await imageSource.release()
      } catch (_err) {
      }
    }
  }
}

function isPlainObject(value: Object | null): boolean {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function nonEmptyString(value: Object | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function optionalPackageMetadataText(value: Object | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  const normalized = value.trim()
  return normalized.length > 0 ? normalized : undefined
}

function packageMetadataValueInvalid(value: Object | undefined): boolean {
  return value !== undefined && typeof value !== 'string'
}

export function isValidSourcePackageMinAppVersion(value: string | undefined): boolean {
  return value === undefined || value.length === 0 || SOURCE_PACKAGE_MIN_APP_VERSION_PATTERN.test(value)
}

function optionalBoolean(value: Object | undefined, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function optionalNumber(value: Object | undefined, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback
}

function optionalStringArray(value: Object | undefined): string[] {
  if (!Array.isArray(value)) {
    return []
  }
  const result: string[] = []
  const values = value as Object[]
  values.forEach((item: Object) => {
    if (typeof item === 'string') {
      result.push(item)
    }
  })
  return result
}

export function normalizeSourceOperationCapabilityToken(value: string): string | undefined {
  switch (value.trim()) {
    case 'source_info':
    case 'sourceInfo':
      return 'sourceInfo'
    case 'search':
      return 'search'
    case 'get_manga':
    case 'mangaDetail':
    case 'detail':
      return 'detail'
    case 'get_chapters':
    case 'chapters':
      return 'chapters'
    case 'get_pages':
    case 'pages':
      return 'pages'
    case 'get_listings':
    case 'listings':
      return 'listings'
    case 'get_manga_list':
    case 'mangaList':
      return 'mangaList'
    case 'get_home':
    case 'home':
      return 'home'
    case 'get_filters':
    case 'filters':
      return 'filters'
    case 'get_settings':
    case 'settings':
      return 'settings'
    case 'get_image_request':
    case 'image_request':
    case 'modify_image_request':
    case 'imageRequest':
      return 'imageRequest'
    default:
      return undefined
  }
}

export function normalizeSourceOperationCapabilityTokens(input: string[] | undefined): string[] {
  if (input === undefined || input.length === 0) {
    return []
  }
  const tokens: string[] = []
  input.forEach((item: string) => {
    const token = normalizeSourceOperationCapabilityToken(item)
    if (token !== undefined && tokens.indexOf(token) < 0) {
      tokens.push(token)
    }
  })
  return tokens
}

export function validSourceWebSessionOrigins(value: Object | undefined): boolean {
  if (value === undefined) return true
  if (!Array.isArray(value)) return false
  const declared = value as string[]
  for (const raw of declared) {
    if (typeof raw !== 'string') return false
    try {
      const parsed = new url.URL(raw)
      if (parsed.protocol !== 'https:' || parsed.origin !== raw ||
        parsed.username.length > 0 || parsed.password.length > 0 || parsed.hostname.length === 0) return false
    } catch (_error) { return false }
  }
  return true
}

/** Descriptive navigation only; this never grants network or cookie access. */
export function normalizeSourceHomepage(value: Object | undefined): string | undefined {
  if (typeof value !== 'string' || value.length === 0 || value.length > 2048 ||
    /[\s\u0000-\u001f\u007f\\<>"]/.test(value) || !/^https?:\/\//i.test(value)) return undefined
  try {
    const parsed = url.URL.parseURL(value)
    if ((parsed.protocol !== 'http:' && parsed.protocol !== 'https:') || parsed.hostname.length === 0 ||
      parsed.hostname.includes('%') || parsed.username.length > 0 || parsed.password.length > 0) return undefined
    return value
  } catch (_error) {
    return undefined
  }
}

function parseSourceRepoPackageManifest(raw: string, wasmSize: number): LocalSourcePackageManifest | undefined {
  const parsed = JSON.parse(raw) as SourceRepoPackageManifest
  const id = nonEmptyString(parsed.id)
  const name = nonEmptyString(parsed.name)
  const version = nonEmptyString(parsed.version)
  if (id === undefined || name === undefined || version === undefined || id.length > 96) {
    return undefined
  }
  if (!isValidSourceChapterOrder(parsed.chapterOrder) || isInvalidSourceLocalizedNames(parsed.localizedNames)) {
    return undefined
  }
  if (packageMetadataValueInvalid(parsed.author) || packageMetadataValueInvalid(parsed.description) ||
    packageMetadataValueInvalid(parsed.contentRating) || packageMetadataValueInvalid(parsed.minAppVersion)) {
    return undefined
  }
  if (typeof parsed.minAppVersion === 'string' && !isValidSourcePackageMinAppVersion(parsed.minAppVersion)) {
    return undefined
  }

  const capabilities = isPlainObject(parsed.capabilities as Object | null) ? parsed.capabilities : undefined
  const contentPolicy = isPlainObject(parsed.contentPolicy as Object | null) ? parsed.contentPolicy : undefined
  if (!validSourceWebSessionOrigins(parsed.webSessionOrigins)) return undefined
  const declaredSha256 = nonEmptyString(parsed.wasmSha256) ?? nonEmptyString(parsed.sourceWasmSha256) ?? ''
  const maxWasmBytes = optionalNumber(parsed.maxWasmBytes, Math.max(wasmSize, SOURCE_PACKAGE_WASM_MAX_BYTES))
  return {
    schemaVersion: 1,
    package: {
      id,
      name,
      localizedNames: normalizeSourceLocalizedNames(parsed.localizedNames),
      chapterOrder: parsed.chapterOrder,
      version,
      language: nonEmptyString(parsed.language) ?? nonEmptyString(parsed.lang) ?? 'multi',
      type: nonEmptyString(parsed.runtime) ?? 'wasm-source',
      nsfw: optionalBoolean(parsed.nsfw, false),
      homepage: normalizeSourceHomepage(parsed.homepage),
      author: optionalPackageMetadataText(parsed.author),
      description: optionalPackageMetadataText(parsed.description),
      contentRating: optionalPackageMetadataText(parsed.contentRating),
      minAppVersion: optionalPackageMetadataText(parsed.minAppVersion),
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
      webSessionOrigins: parsed.webSessionOrigins ?? [],
      network: optionalBoolean(capabilities?.network, false),
      hostImports: [],
    },
    operationCapabilities: normalizeSourceOperationCapabilityTokens(optionalStringArray(capabilities?.operations as Object | undefined)),
    contentPolicy: {
      publicIndex: optionalBoolean(contentPolicy?.publicIndex, false),
      marketplace: optionalBoolean(contentPolicy?.marketplace, false),
      builtInSource: optionalBoolean(contentPolicy?.builtInSource, false),
      remoteInstall: optionalBoolean(contentPolicy?.remoteInstall, false),
    },
  }
}

export function validateNormalizedManifest(manifest: LocalSourcePackageManifest): SourceArchiveValidationReason | undefined {
  if (manifest.permissions === undefined || manifest.permissions === null ||
    !validSourceWebSessionOrigins(manifest.permissions.webSessionOrigins)) return 'manifest_invalid'
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
  if (!isValidSourceChapterOrder(manifest.package.chapterOrder) || isInvalidSourceLocalizedNames(manifest.package.localizedNames)) {
    return 'manifest_invalid'
  }
  if (packageMetadataValueInvalid(manifest.package.author) || packageMetadataValueInvalid(manifest.package.description) ||
    packageMetadataValueInvalid(manifest.package.contentRating) || packageMetadataValueInvalid(manifest.package.minAppVersion)) {
    return 'manifest_invalid'
  }
  if (!isValidSourcePackageMinAppVersion(manifest.package.minAppVersion)) {
    return 'manifest_invalid'
  }
  if (manifest.operationCapabilities !== undefined &&
    normalizeSourceOperationCapabilityTokens(manifest.operationCapabilities).length !== manifest.operationCapabilities.length) {
    return 'manifest_invalid'
  }
  return undefined
}

export function validateImportedWasmBytes(manifest: LocalSourcePackageManifest, importedWasmBytes: Uint8Array): boolean {
  return importedWasmDigestMatches(manifest, importedWasmBytes, sha256Hex(importedWasmBytes))
}

function importedWasmDigestMatches(
  manifest: LocalSourcePackageManifest, importedWasmBytes: Uint8Array, importedHash: string,
): boolean {
  const sizeOk = importedWasmBytes.byteLength === manifest.runtime.wasmSizeBytes &&
    importedWasmBytes.byteLength <= manifest.runtime.maxWasmBytes
  const declaredHash = manifest.runtime.wasmSha256
  return sizeOk && (declaredHash.length === 0 || importedHash === declaredHash)
}

export async function validateImportedWasmBytesAsync(
  manifest: LocalSourcePackageManifest, importedWasmBytes: Uint8Array,
): Promise<boolean> {
  // Import already awaits extraction/decoding under the writer admission. Only
  // move the digest work; validated bytes must remain owned by the importer for
  // capability probing/registration. Never publish or fall back while awaiting.
  const workerBytes = new Uint8Array(importedWasmBytes.byteLength)
  workerBytes.set(importedWasmBytes)
  const importedHash = await taskpool.execute(computeSourcePackageSha256, workerBytes) as string
  return importedWasmDigestMatches(manifest, importedWasmBytes, importedHash)
}

export function validateRestoredSourcePackage(
  manifest: LocalSourcePackageManifest,
  wasmBytes: Uint8Array,
): SourceArchiveValidationReason | undefined {
  const manifestReason = validateNormalizedManifest(manifest)
  if (manifestReason !== undefined) {
    return manifestReason
  }
  if (!validateImportedWasmBytes(manifest, wasmBytes)) {
    return 'checksum_mismatch'
  }
  return undefined
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
    operationCapabilities: [
      'sourceInfo',
      'search',
      'detail',
      'chapters',
      'pages',
      'listings',
      'mangaList',
      'home',
      'filters',
      'settings',
      'imageRequest',
    ],
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

  let iconPath: string | undefined = undefined
  if (sourceRepoLayout) {
    const iconName = SOURCE_REPO_PACKAGE_ICON_FILES.find((name: string): boolean => {
      return fs.accessSync(joinSourceRuntimePath(importedRoot, name))
    })
    if (iconName === undefined) {
      return { ok: false, reasonCode: 'missing_icon', manifest, manifestPath, attemptedWamrExecution: false }
    }
    const declaredIcon = (JSON.parse(readTextSync(manifestPath)) as SourceRepoPackageManifest).icon
    if (declaredIcon !== undefined && declaredIcon !== iconName) {
      return { ok: false, reasonCode: 'invalid_icon', manifest, manifestPath, attemptedWamrExecution: false }
    }
    const candidateIconPath = joinSourceRuntimePath(importedRoot, iconName)
    try {
      const iconBytes = readBytesSync(candidateIconPath)
      if (!sourcePackageIconMatchesFileName(iconBytes, iconName) ||
        !await validateSourcePackageIconFile(candidateIconPath)) {
        return { ok: false, reasonCode: 'invalid_icon', manifest, manifestPath, attemptedWamrExecution: false }
      }
      iconPath = candidateIconPath
    } catch (_err) {
      return { ok: false, reasonCode: 'invalid_icon', manifest, manifestPath, attemptedWamrExecution: false }
    }
  }

  const importedWasmBytes = readBytesSync(importedWasmPath)
  const hashOk = await validateImportedWasmBytesAsync(manifest, importedWasmBytes)
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
    iconPath,
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
