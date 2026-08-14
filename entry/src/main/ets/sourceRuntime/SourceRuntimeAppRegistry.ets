import { bundleManager, common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  importLocalSourceArchive,
  LocalSourcePackageManifest,
  normalizeSourceOperationCapabilityTokens,
  SOURCE_PACKAGE_MANIFEST_FILE,
  SOURCE_PACKAGE_WASM_FILE,
  SOURCE_REPO_PACKAGE_ICON_FILE,
  SOURCE_REPO_PACKAGE_ICON_MAX_BYTES,
  SOURCE_REPO_PACKAGE_WASM_FILE,
  isValidSourcePackageMinAppVersion,
  validateSourcePackageIconFile,
  validateSourcePackageIconBytes,
  validateRestoredSourcePackage,
} from './SourcePackageImporter'
import {
  runRegisteredSourceRequestById,
} from './SourceRuntimeService'
import {
  runSourceOperationFromBytes,
} from './SourceRuntimeRunner'
import { appSourceSettingsStore } from './SourceSettingsStore'
import { appSourceFilterPreferencesStore } from './SourceFilterPreferencesStore'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
  sourceRuntimePackageIconPath,
  sourceRuntimePackageIconUri,
} from './SourceRuntimeRegistry'
import { SourceRuntimeStateBridge } from '../state/SourceRuntimeState'

const IMPORTED_SOURCE_ROUTE: string = 'app-local-source-package'
const APP_SOURCE_ROOT_NAME: string = 'source-runtime'
const APP_SOURCE_PACKAGES_DIR_NAME: string = 'packages'
const APP_SOURCE_METADATA_FILE_NAME: string = 'source-runtime-registry.json'
const SOURCE_ARCHIVE_SUFFIX_FILTER: string = 'Koma source packages(.koma, .koma-source, .koma-source.zip, .zip)|.koma,.koma-source,.koma-source.zip,.zip'

function compareSourcePackageVersions(left: string, right: string): number {
  const leftParts = left.split('.')
  const rightParts = right.split('.')
  for (let index = 0; index < 3; index += 1) {
    const leftValue = Number(leftParts[index])
    const rightValue = Number(rightParts[index])
    if (leftValue !== rightValue) {
      return leftValue > rightValue ? 1 : -1
    }
  }
  return 0
}

export function isSourcePackageMinAppVersionSatisfied(minAppVersion: string | undefined): boolean {
  const required = minAppVersion ?? ''
  if (required.length === 0) {
    return true
  }
  if (!isValidSourcePackageMinAppVersion(required)) {
    return false
  }
  try {
    const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
    const current = info.versionName
    return isValidSourcePackageMinAppVersion(current) && compareSourcePackageVersions(current, required) >= 0
  } catch (_err) {
    return false
  }
}

export interface InstalledSourcePackage {
  id: string
  name: string
  version: string
  lang: string
  nsfw: boolean
  author: string
  description: string
  contentRating: string
  minAppVersion: string
  enabled: boolean
  status: string
  smokeStatus: string
  lastDiagnosticMessage: string
  capabilities: string[]
  icon?: string
}

export interface SourcePackageInstallResult {
  ok: boolean
  id?: string
  name?: string
  reasonCode?: string
}

export interface SourcePackageSmokeResult {
  ok: boolean
  id: string
  reasonCode?: string
  firstTitle?: string
}

export interface SourcePackageBackupEntry {
  sourceId: string
  version: string
  enabled: boolean
  manifest: LocalSourcePackageManifest
  wasmBase64: string
  wasmByteCount: number
  iconPngBase64?: string
  iconByteCount?: number
  presentationDescription?: string
  presentationIcon?: string
}

export interface SourcePackageRestoreResult {
  ok: boolean
  restoredCount: number
  reasonCode?: string
}

interface ValidatedSourcePackageBackup {
  sourcePackage: SourcePackageBackupEntry
  manifest: LocalSourcePackageManifest
  wasmBytes: Uint8Array
  iconBytes?: Uint8Array
  sourceRepoLayout: boolean
}

interface SourcePackageBackupValidationResult {
  value?: ValidatedSourcePackageBackup
  reasonCode?: string
}

interface StagedSourcePackageBackup extends ValidatedSourcePackageBackup {
  packageDir: string
  archivePath: string
  manifestPath: string
  wasmPath: string
  iconPath?: string
}

interface SourceInfoCapabilityRequestArgs {}

interface SourceInfoCapabilityRequestSettings {}

interface SourceInfoCapabilityRequestHostHints {
  network: boolean
}

interface SourceInfoCapabilityRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceInfoCapabilityRequestArgs
  settings: SourceInfoCapabilityRequestSettings
  hostHints: SourceInfoCapabilityRequestHostHints
}

export const appSourceRuntimeRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
let sourceRuntimeDiagnostics: SourcePackageSmokeResult[] = []

function getSourceRuntimeDiagnostic(id: string): SourcePackageSmokeResult | undefined {
  return sourceRuntimeDiagnostics.find((item: SourcePackageSmokeResult): boolean => item.id === id)
}

function setSourceRuntimeDiagnostic(result: SourcePackageSmokeResult): void {
  sourceRuntimeDiagnostics = sourceRuntimeDiagnostics.filter((item: SourcePackageSmokeResult): boolean => item.id !== result.id)
  sourceRuntimeDiagnostics.push(result)
}

function clearSourceRuntimeDiagnostic(id: string): void {
  sourceRuntimeDiagnostics = sourceRuntimeDiagnostics.filter((item: SourcePackageSmokeResult): boolean => item.id !== id)
}

function joinSourceRuntimePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
}

function appSourceRoot(context: common.UIAbilityContext): string {
  return joinSourceRuntimePath(context.filesDir, APP_SOURCE_ROOT_NAME)
}

function appSourcePackagesRoot(context: common.UIAbilityContext): string {
  return joinSourceRuntimePath(appSourceRoot(context), APP_SOURCE_PACKAGES_DIR_NAME)
}

function appSourceMetadataPath(context: common.UIAbilityContext): string {
  return joinSourceRuntimePath(appSourceRoot(context), APP_SOURCE_METADATA_FILE_NAME)
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
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

function compareDeepestPathFirst(left: string, right: string): number {
  const leftDepth = left.split('/').length
  const rightDepth = right.split('/').length
  if (leftDepth !== rightDepth) {
    return rightDepth - leftDepth
  }
  return right.localeCompare(left)
}

async function pathExists(path: string): Promise<boolean> {
  try {
    return await fs.access(path)
  } catch (_err) {
    return false
  }
}

async function removeAppSourcePackageDir(context: common.UIAbilityContext, packageDir: string): Promise<void> {
  const packagesRoot = appSourcePackagesRoot(context)
  const normalizedRoot = packagesRoot.replace(/\\/g, '/').replace(/\/+$/, '')
  const normalizedPackage = packageDir.replace(/\\/g, '/').replace(/\/+$/, '')
  if (normalizedPackage.length === 0 || normalizedPackage === normalizedRoot || !normalizedPackage.startsWith(`${normalizedRoot}/`)) {
    throw new Error('refuse_remove_outside_source_package_dir')
  }
  if (!(await pathExists(normalizedPackage))) {
    return
  }
  const options: ListFileOptions = {
    recursion: true,
    listNum: 0,
  }
  const entries = (await fs.listFile(normalizedPackage, options))
    .map((entry: string): string => entry.replace(/\\/g, '/').replace(/^\/+/, '').replace(/\/+$/, ''))
    .filter((entry: string): boolean => entry.length > 0 && entry.indexOf('..') < 0)
    .sort(compareDeepestPathFirst)
  for (let index = 0; index < entries.length; index += 1) {
    const entryPath = joinSourceRuntimePath(normalizedPackage, entries[index])
    const stat = await fs.stat(entryPath)
    if (stat.isDirectory()) {
      await fs.rmdir(entryPath)
    } else {
      await fs.unlink(entryPath)
    }
  }
  await fs.rmdir(normalizedPackage)
}

async function copyPickedArchiveUriToSandbox(sourceUri: string, sandboxPath: string): Promise<void> {
  let sourceFile: fs.File | undefined = undefined
  let targetFile: fs.File | undefined = undefined
  try {
    sourceFile = await fs.open(sourceUri, fs.OpenMode.READ_ONLY)
    targetFile = await fs.open(sandboxPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
  } finally {
    closeFileQuietly(sourceFile)
    closeFileQuietly(targetFile)
  }
}

function sourceArchiveSandboxFileName(sourceUri: string): string {
  const withoutFragment = sourceUri.split('#')[0]
  const withoutQuery = withoutFragment.split('?')[0]
  const leaf = withoutQuery.split('/').pop() ?? ''
  const sanitized = leaf
    .replace(/%20/g, ' ')
    .replace(/[^A-Za-z0-9._ -]/g, '_')
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '')
  const candidate = sanitized.length > 0 ? sanitized : 'source-package'
  const lower = candidate.toLowerCase()
  if (lower.endsWith('.koma-source.zip') || lower.endsWith('.zip')) {
    return candidate
  }
  if (lower.endsWith('.koma') || lower.endsWith('.koma-source')) {
    return candidate + '.zip'
  }
  return 'source-package.zip'
}

function sourceInfoCapabilityToken(key: string): string | undefined {
  switch (key) {
    case 'sourceInfo':
    case 'source_info':
      return 'sourceInfo'
    case 'search':
      return 'search'
    case 'mangaDetail':
    case 'get_manga':
    case 'detail':
      return 'detail'
    case 'chapters':
    case 'get_chapters':
      return 'chapters'
    case 'pages':
    case 'get_pages':
      return 'pages'
    case 'listings':
    case 'get_listings':
      return 'listings'
    case 'mangaList':
    case 'get_manga_list':
      return 'mangaList'
    case 'home':
    case 'get_home':
      return 'home'
    case 'filters':
    case 'get_filters':
      return 'filters'
    case 'settings':
    case 'get_settings':
      return 'settings'
    case 'imageRequest':
    case 'get_image_request':
    case 'image_request':
    case 'modify_image_request':
      return 'imageRequest'
    default:
      return undefined
  }
}

function detectSourceRuntimeCapabilities(sourceId: string, wasmBytes: Uint8Array): string[] | undefined {
  const args: SourceInfoCapabilityRequestArgs = {}
  const settings: SourceInfoCapabilityRequestSettings = {}
  const hostHints: SourceInfoCapabilityRequestHostHints = { network: false }
  const request: SourceInfoCapabilityRequest = {
    type: 'request',
    version: 1,
    requestId: `source-info-${Date.now()}`,
    operation: 'source_info',
    sourceId,
    args,
    settings,
    hostHints,
  }
  try {
    const response = runSourceOperationFromBytes(JSON.stringify(request), wasmBytes)
    if (response.ok !== true || response.operation !== 'source_info') {
      return undefined
    }
    const data = response.data as Record<string, Object> | undefined
    const capabilities = data?.['capabilities'] as Record<string, Object> | undefined
    if (capabilities === undefined || capabilities === null || Array.isArray(capabilities) || typeof capabilities !== 'object') {
      return undefined
    }
    const tokens: string[] = ['sourceInfo']
    Object.keys(capabilities).forEach((key: string) => {
      if (capabilities[key] !== true) {
        return
      }
      const token = sourceInfoCapabilityToken(key)
      if (token !== undefined && tokens.indexOf(token) < 0) {
        tokens.push(token)
      }
    })
    return tokens.length > 1 ? tokens : undefined
  } catch (_error) {
    return undefined
  }
}

function sourceManagerSmokeSourceInfoRequest(id: string): string {
  const args: SourceInfoCapabilityRequestArgs = {}
  const settings: SourceInfoCapabilityRequestSettings = {}
  const hostHints: SourceInfoCapabilityRequestHostHints = { network: false }
  const request: SourceInfoCapabilityRequest = {
    type: 'request',
    version: 1,
    requestId: `source-manager-source-info-smoke-${Date.now()}`,
    operation: 'source_info',
    sourceId: id,
    args,
    settings,
    hostHints,
  }
  return JSON.stringify(request)
}

function sourceManagerSmokeFixtureSearchRequest(id: string): string {
  return `{"type":"request","version":1,"requestId":"source-manager-fixture-smoke-${Date.now()}","operation":"search","sourceId":"${id}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`
}

function sourcePackageFromEntry(entry: SourceRuntimeRegistryEntry): InstalledSourcePackage {
  const diagnostic = getSourceRuntimeDiagnostic(entry.sourceId)
  return {
    id: entry.sourceId,
    name: entry.manifestName,
    version: entry.manifestVersion,
    lang: entry.language,
    nsfw: entry.nsfw,
    author: entry.packageAuthor,
    description: entry.packageDescription,
    contentRating: entry.packageContentRating,
    minAppVersion: entry.packageMinAppVersion,
    enabled: entry.enabled,
    status: entry.importStatus,
    smokeStatus: diagnostic === undefined ? AppStrings.get('source_pkg_not_run') : (diagnostic.ok ? 'PASS' : 'FAIL'),
    lastDiagnosticMessage: diagnostic === undefined ? '' : (diagnostic.reasonCode ?? 'ok'),
    capabilities: entry.capabilities,
    icon: sourceRuntimePackageIconUri(entry),
  }
}

function sourcePackageIconBytes(entry: SourceRuntimeRegistryEntry): Uint8Array | undefined {
  const iconPath = sourceRuntimePackageIconPath(entry)
  if (iconPath === undefined) {
    return undefined
  }
  try {
    const bytes = readBytesSync(iconPath)
    return validateSourcePackageIconBytes(bytes) ? bytes : undefined
  } catch (_err) {
    return undefined
  }
}

function restoredSourcePackageIconBytes(sourcePackage: SourcePackageBackupEntry): Uint8Array | undefined {
  const encoded = sourcePackage.iconPngBase64
  const byteCount = sourcePackage.iconByteCount
  if (encoded === undefined && byteCount === undefined) {
    return undefined
  }
  if (typeof encoded !== 'string' || typeof byteCount !== 'number' || !Number.isInteger(byteCount) || byteCount <= 0) {
    return undefined
  }
  const maxEncodedLength = Math.ceil(SOURCE_REPO_PACKAGE_ICON_MAX_BYTES / 3) * 4 + 4
  if (byteCount > SOURCE_REPO_PACKAGE_ICON_MAX_BYTES || encoded.length > maxEncodedLength) {
    return undefined
  }
  try {
    const bytes = base64ToBytes(encoded)
    return bytes.byteLength === byteCount && validateSourcePackageIconBytes(bytes) ? bytes : undefined
  } catch (_err) {
    return undefined
  }
}

function validateSourcePackageBackupPayload(
  sourcePackage: SourcePackageBackupEntry,
): SourcePackageBackupValidationResult {
  if (sourcePackage === undefined ||
    typeof sourcePackage.sourceId !== 'string' ||
    typeof sourcePackage.version !== 'string' ||
    typeof sourcePackage.enabled !== 'boolean' ||
    typeof sourcePackage.wasmBase64 !== 'string' ||
    typeof sourcePackage.wasmByteCount !== 'number' ||
    !Number.isInteger(sourcePackage.wasmByteCount) || sourcePackage.wasmByteCount <= 0) {
    return { reasonCode: 'invalid_source_package_backup' }
  }

  const manifest = sourcePackage.manifest
  if (manifest === undefined || manifest === null || Array.isArray(manifest) || typeof manifest !== 'object' ||
    manifest.package === undefined || manifest.runtime === undefined ||
    manifest.permissions === undefined || manifest.contentPolicy === undefined ||
    typeof manifest.package.id !== 'string' || typeof manifest.package.version !== 'string') {
    return { reasonCode: 'invalid_source_package_manifest' }
  }
  if (manifest.package.id !== sourcePackage.sourceId || manifest.package.version !== sourcePackage.version) {
    return { reasonCode: 'source_package_identity_mismatch' }
  }

  const hasIconPayload = sourcePackage.iconPngBase64 !== undefined || sourcePackage.iconByteCount !== undefined
  const iconBytes = restoredSourcePackageIconBytes(sourcePackage)
  if (hasIconPayload && iconBytes === undefined) {
    return { reasonCode: 'invalid_icon' }
  }

  let wasmBytes: Uint8Array
  try {
    wasmBytes = base64ToBytes(sourcePackage.wasmBase64)
  } catch (_err) {
    return { reasonCode: 'invalid_source_package_backup' }
  }
  if (wasmBytes.byteLength !== sourcePackage.wasmByteCount) {
    return { reasonCode: 'source_package_byte_count_mismatch' }
  }

  let validationReason: string | undefined
  try {
    validationReason = validateRestoredSourcePackage(manifest, wasmBytes)
  } catch (_err) {
    return { reasonCode: 'invalid_source_package_manifest' }
  }
  if (validationReason !== undefined) {
    return { reasonCode: validationReason }
  }
  if (!isSourcePackageMinAppVersionSatisfied(manifest.package.minAppVersion)) {
    return { reasonCode: 'app_version_unsupported' }
  }

  const sourceRepoLayout = manifest.runtime.wasmPath === SOURCE_REPO_PACKAGE_WASM_FILE
  if (iconBytes !== undefined && !sourceRepoLayout) {
    return { reasonCode: 'invalid_icon' }
  }
  return {
    value: {
      sourcePackage,
      manifest,
      wasmBytes,
      iconBytes,
      sourceRepoLayout,
    },
  }
}

async function removeStagedSourcePackageBackups(
  context: common.UIAbilityContext,
  packages: StagedSourcePackageBackup[],
): Promise<void> {
  for (let index = 0; index < packages.length; index += 1) {
    try {
      await removeAppSourcePackageDir(context, packages[index].packageDir)
    } catch (_err) {
    }
  }
}

function manifestWasmPathFromRegistryEntry(entry: SourceRuntimeRegistryEntry): string {
  const wasmPath = entry.wasmPath ?? ''
  if (wasmPath.endsWith(SOURCE_REPO_PACKAGE_WASM_FILE)) {
    return SOURCE_REPO_PACKAGE_WASM_FILE
  }
  return SOURCE_PACKAGE_WASM_FILE
}

function manifestFromRegistryEntry(entry: SourceRuntimeRegistryEntry): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: entry.manifestId,
      name: entry.manifestName,
      version: entry.manifestVersion,
      language: entry.language,
      type: entry.type,
      nsfw: entry.nsfw,
      author: entry.packageAuthor,
      description: entry.packageDescription,
      contentRating: entry.packageContentRating,
      minAppVersion: entry.packageMinAppVersion,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: manifestWasmPathFromRegistryEntry(entry),
      wasmSha256: sha256Hex(entry.wasmBytes),
      wasmSizeBytes: entry.wasmByteCount,
      maxWasmBytes: entry.wasmByteCount,
    },
    permissions: {
      network: false,
      hostImports: [],
    },
    operationCapabilities: normalizeSourceOperationCapabilityTokens(entry.capabilities),
    contentPolicy: {
      publicIndex: false,
      marketplace: false,
      builtInSource: false,
      remoteInstall: false,
    },
  }
}

function restoreRuntimeRegistryEntry(entry: SourceRuntimeRegistryEntry | undefined): void {
  if (entry === undefined) {
    return
  }
  if (appSourceRuntimeRegistry.lookup(entry.sourceId).ok) {
    return
  }
  appSourceRuntimeRegistry.register({
    sourceId: entry.sourceId,
    route: entry.route,
    importStatus: entry.importStatus,
    manifest: manifestFromRegistryEntry(entry),
    wasmBytes: entry.wasmBytes,
    hashOk: entry.hashOk,
    network: entry.network,
    enabled: entry.enabled,
    capabilities: entry.capabilities,
    manifestPath: entry.manifestPath,
    wasmPath: entry.wasmPath,
    archivePath: entry.archivePath,
    packageIconPath: entry.packageIconPath,
    presentationDescription: entry.presentationDescription,
    presentationIcon: entry.presentationIcon,
  })
}

function bytesToBase64(bytes: Uint8Array): string {
  return buffer.from(bytesToExactArrayBuffer(bytes)).toString('base64')
}

function base64ToBytes(payload: string): Uint8Array {
  const decoded = buffer.from(payload, 'base64')
  const bytes = new Uint8Array(decoded.length)
  for (let index = 0; index < decoded.length; index += 1) {
    bytes[index] = decoded[index]
  }
  return bytes
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

function persistInstalledSources(context: common.UIAbilityContext): void {
  const persistedRegistry = new SourceRuntimeRegistry()
  const entries = appSourceRuntimeRegistry.list()
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index]
    if (entry.importStatus !== 'imported' || entry.archivePath === undefined) {
      continue
    }
    persistedRegistry.register({
      sourceId: entry.sourceId,
      route: entry.route,
      importStatus: entry.importStatus,
      manifest: manifestFromRegistryEntry(entry),
      wasmBytes: entry.wasmBytes,
      hashOk: entry.hashOk,
      network: false,
      enabled: entry.enabled,
      capabilities: entry.capabilities,
      manifestPath: entry.manifestPath,
      wasmPath: entry.wasmPath,
      archivePath: entry.archivePath,
      packageIconPath: entry.packageIconPath,
      presentationDescription: entry.presentationDescription,
      presentationIcon: entry.presentationIcon,
    })
  }
  const persist = persistedRegistry.persistToAppLocalMetadata(appSourceMetadataPath(context))
  if (!persist.ok) {
    throw new Error(persist.reasonCode ?? 'source_registry_persist_failed')
  }
}

export function exportInstalledSourcePackages(): SourcePackageBackupEntry[] {
  const entries = appSourceRuntimeRegistry.list()
  const packages: SourcePackageBackupEntry[] = []
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index]
    if (entry.importStatus !== 'imported') {
      continue
    }
    const iconBytes = sourcePackageIconBytes(entry)
    const sourcePackage: SourcePackageBackupEntry = {
      sourceId: entry.sourceId,
      version: entry.manifestVersion,
      enabled: entry.enabled,
      manifest: manifestFromRegistryEntry(entry),
      wasmBase64: bytesToBase64(entry.wasmBytes),
      wasmByteCount: entry.wasmByteCount,
      presentationDescription: entry.presentationDescription,
      presentationIcon: entry.presentationIcon,
    }
    if (iconBytes !== undefined) {
      sourcePackage.iconPngBase64 = bytesToBase64(iconBytes)
      sourcePackage.iconByteCount = iconBytes.byteLength
    }
    packages.push(sourcePackage)
  }
  return packages
}

export async function restoreSourcePackagesFromBackup(
  context: common.UIAbilityContext,
  packages: SourcePackageBackupEntry[],
): Promise<SourcePackageRestoreResult> {
  // Validate the complete backup before replacing any existing package. A
  // later incompatibility must not leave earlier replacements unpersisted.
  const validatedPackages: ValidatedSourcePackageBackup[] = []
  const sourceIds: string[] = []
  for (let index = 0; index < packages.length; index += 1) {
    const validation = validateSourcePackageBackupPayload(packages[index])
    if (validation.value === undefined) {
      return { ok: false, restoredCount: 0, reasonCode: validation.reasonCode ?? 'invalid_source_package_backup' }
    }
    const sourceId = validation.value.manifest.package.id.trim()
    if (sourceIds.indexOf(sourceId) >= 0) {
      return { ok: false, restoredCount: 0, reasonCode: 'invalid_source_package_backup' }
    }
    sourceIds.push(sourceId)
    validatedPackages.push(validation.value)
  }

  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  // Stage every new package, including ImageKit's decode check, before the
  // installed registry or an existing package directory is touched.
  const stagedPackages: StagedSourcePackageBackup[] = []
  const restoreRunId = Date.now()
  for (let index = 0; index < validatedPackages.length; index += 1) {
    const validated = validatedPackages[index]
    const sourcePackage = validated.sourcePackage
    const manifest = validated.manifest
    const packageDir = joinSourceRuntimePath(appSourcePackagesRoot(context), `backup-${restoreRunId}-${index}`)
    const archivePath = joinSourceRuntimePath(packageDir, 'backup-source-package.json')
    const importedRoot = joinSourceRuntimePath(packageDir, 'package')
    // Backup payloads retain the normalized host manifest, not the original
    // source-repo manifest schema. Keep that host-owned filename on restore;
    // the trusted runtime wasm path remains the sole layout discriminator.
    const manifestPath = joinSourceRuntimePath(importedRoot, SOURCE_PACKAGE_MANIFEST_FILE)
    const wasmPath = joinSourceRuntimePath(importedRoot, manifest.runtime.wasmPath)
    const iconPath = validated.sourceRepoLayout && validated.iconBytes !== undefined ?
      joinSourceRuntimePath(importedRoot, SOURCE_REPO_PACKAGE_ICON_FILE) : undefined
    try {
      ensureDirSync(packageDir)
      ensureDirSync(importedRoot)
      writeTextSync(archivePath, JSON.stringify({
        sourceId: sourcePackage.sourceId,
        version: sourcePackage.version,
        restoredAt: restoreRunId,
      }))
      writeTextSync(manifestPath, JSON.stringify(manifest))
      writeBytesSync(wasmPath, validated.wasmBytes)
      if (validated.iconBytes !== undefined && iconPath !== undefined) {
        writeBytesSync(iconPath, validated.iconBytes)
        if (!await validateSourcePackageIconFile(iconPath)) {
          await removeStagedSourcePackageBackups(context, stagedPackages)
          try {
            await removeAppSourcePackageDir(context, packageDir)
          } catch (_err) {
          }
          return { ok: false, restoredCount: 0, reasonCode: 'invalid_icon' }
        }
      }
      stagedPackages.push({
        sourcePackage,
        manifest,
        wasmBytes: validated.wasmBytes,
        iconBytes: validated.iconBytes,
        sourceRepoLayout: validated.sourceRepoLayout,
        packageDir,
        archivePath,
        manifestPath,
        wasmPath,
        iconPath,
      })
    } catch (_err) {
      await removeStagedSourcePackageBackups(context, stagedPackages)
      try {
        await removeAppSourcePackageDir(context, packageDir)
      } catch (_cleanupErr) {
      }
      return { ok: false, restoredCount: 0, reasonCode: 'invalid_source_package_backup' }
    }
  }

  // Keep old package directories until the new registry is persisted so a
  // failed replacement can restore the previous in-memory entries.
  const previousEntries: SourceRuntimeRegistryEntry[] = []
  const registeredSourceIds: string[] = []
  let restoreFailureReason: string | undefined
  for (let index = 0; index < stagedPackages.length; index += 1) {
    const staged = stagedPackages[index]
    const sourceId = staged.sourcePackage.sourceId
    const existing = appSourceRuntimeRegistry.remove(sourceId)
    if (existing !== undefined) {
      previousEntries.push(existing)
    }
    const registered = appSourceRuntimeRegistry.register({
      sourceId,
      route: IMPORTED_SOURCE_ROUTE,
      importStatus: 'imported',
      manifest: staged.manifest,
      wasmBytes: staged.wasmBytes,
      hashOk: true,
      network: false,
      enabled: staged.sourcePackage.enabled,
      presentationDescription: staged.sourcePackage.presentationDescription,
      presentationIcon: staged.sourcePackage.presentationIcon,
      manifestPath: staged.manifestPath,
      wasmPath: staged.wasmPath,
      archivePath: staged.archivePath,
      packageIconPath: staged.iconPath,
    })
    if (!registered.ok) {
      restoreFailureReason = registered.reasonCode ?? 'source_package_register_failed'
      break
    }
    registeredSourceIds.push(sourceId)
  }

  if (restoreFailureReason !== undefined) {
    for (let index = 0; index < registeredSourceIds.length; index += 1) {
      appSourceRuntimeRegistry.remove(registeredSourceIds[index])
    }
    for (let index = 0; index < previousEntries.length; index += 1) {
      restoreRuntimeRegistryEntry(previousEntries[index])
    }
    await removeStagedSourcePackageBackups(context, stagedPackages)
    return { ok: false, restoredCount: 0, reasonCode: restoreFailureReason }
  }

  try {
    persistInstalledSources(context)
  } catch (_err) {
    for (let index = 0; index < registeredSourceIds.length; index += 1) {
      appSourceRuntimeRegistry.remove(registeredSourceIds[index])
    }
    for (let index = 0; index < previousEntries.length; index += 1) {
      restoreRuntimeRegistryEntry(previousEntries[index])
    }
    try {
      persistInstalledSources(context)
    } catch (_restoreErr) {
    }
    await removeStagedSourcePackageBackups(context, stagedPackages)
    return { ok: false, restoredCount: 0, reasonCode: 'source_registry_persist_failed' }
  }

  for (let index = 0; index < previousEntries.length; index += 1) {
    const archivePath = previousEntries[index].archivePath
    if (archivePath === undefined) {
      continue
    }
    const existingDir = archivePath.replace(/\\/g, '/').replace(/\/[^/]*$/, '')
    try {
      await removeAppSourcePackageDir(context, existingDir)
    } catch (_err) {
    }
  }

  const restoredCount = stagedPackages.length
  if (restoredCount > 0) {
    SourceRuntimeStateBridge.notifyChanged()
  }
  return { ok: true, restoredCount }
}

// `metadata_missing` is the expected fresh-install state. Other reload failures
// are returned so an interactive caller can report that it kept stale data.
export function reloadInstalledSourcePackages(context: common.UIAbilityContext): boolean {
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  const reloaded = SourceRuntimeRegistry.reloadFromAppLocalMetadata(appSourceMetadataPath(context))
  if (!reloaded.ok) {
    return reloaded.reasonCode === 'metadata_missing'
  }
  const entries = reloaded.registry.list()
  let changed: boolean = false
  let allRegistered: boolean = true
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index]
    if (!isSourcePackageMinAppVersionSatisfied(entry.packageMinAppVersion)) {
      allRegistered = false
      continue
    }
    const existing = appSourceRuntimeRegistry.lookup(entry.sourceId).entry
    if (existing !== undefined) {
      const unchanged = existing.importStatus === entry.importStatus &&
        existing.manifestVersion === entry.manifestVersion &&
        existing.wasmByteCount === entry.wasmByteCount &&
        existing.packageIconPath === entry.packageIconPath &&
        existing.packageAuthor === entry.packageAuthor &&
        existing.packageDescription === entry.packageDescription &&
        existing.packageContentRating === entry.packageContentRating &&
        existing.packageMinAppVersion === entry.packageMinAppVersion
      if (unchanged) {
        continue
      }
      if (appSourceRuntimeRegistry.remove(entry.sourceId) !== undefined) {
        changed = true
      }
    }
    const registered = appSourceRuntimeRegistry.register({
      sourceId: entry.sourceId,
      route: entry.route,
      importStatus: entry.importStatus,
      manifest: {
        schemaVersion: 1,
        package: {
          id: entry.manifestId,
          name: entry.manifestName,
          version: entry.manifestVersion,
          language: entry.language,
          type: entry.type,
          nsfw: entry.nsfw,
          author: entry.packageAuthor,
          description: entry.packageDescription,
          contentRating: entry.packageContentRating,
          minAppVersion: entry.packageMinAppVersion,
        },
        runtime: {
          abi: 'koma-source-abi-v0.1',
          hostAbi: 'koma-host-v0.1',
          wasmPath: entry.wasmPath ?? '',
          wasmSha256: '',
          wasmSizeBytes: entry.wasmByteCount,
          maxWasmBytes: entry.wasmByteCount,
        },
        permissions: {
          network: false,
          hostImports: [],
        },
        operationCapabilities: normalizeSourceOperationCapabilityTokens(entry.capabilities),
        contentPolicy: {
          publicIndex: false,
          marketplace: false,
          builtInSource: false,
          remoteInstall: false,
        },
      },
      wasmBytes: entry.wasmBytes,
      hashOk: entry.hashOk,
      network: false,
      enabled: entry.enabled,
      capabilities: entry.capabilities,
      manifestPath: entry.manifestPath,
      wasmPath: entry.wasmPath,
      archivePath: entry.archivePath,
      packageIconPath: entry.packageIconPath,
      presentationDescription: entry.presentationDescription,
      presentationIcon: entry.presentationIcon,
    })
    if (!registered.ok) {
      // Preserve the existing best-effort reload behavior: one invalid entry
      // must not prevent later installed packages from being restored.
      allRegistered = false
      continue
    }
    changed = true
  }
  if (changed) {
    SourceRuntimeStateBridge.notifyChanged()
  }
  return allRegistered
}

// Read through the persisted registry without mutating the live app registry.
// Test-only callers use this to verify the same package-icon ownership rules a
// cold app start will use before they exercise the visible source rows.
export function persistedInstalledSourcePackageIconUri(
  context: common.UIAbilityContext,
  id: string,
): string | undefined {
  const reloaded = SourceRuntimeRegistry.reloadFromAppLocalMetadata(appSourceMetadataPath(context))
  if (!reloaded.ok) {
    return undefined
  }
  const entry = reloaded.registry.lookup(id).entry
  return entry === undefined ? undefined : sourceRuntimePackageIconUri(entry)
}

export function bootstrapSourceRuntimeAppRegistry(context: common.UIAbilityContext): number {
  reloadInstalledSourcePackages(context)
  return appSourceRuntimeRegistry.count()
}

export function listInstalled(): InstalledSourcePackage[] {
  return appSourceRuntimeRegistry.list().map(sourcePackageFromEntry)
}

export async function pickSourcePackageArchive(context: common.UIAbilityContext): Promise<string | undefined> {
  const options = new picker.DocumentSelectOptions()
  options.maxSelectNumber = 1
  options.fileSuffixFilters = [SOURCE_ARCHIVE_SUFFIX_FILTER]
  const documentPicker = new picker.DocumentViewPicker(context)
  const result = await documentPicker.select(options)
  return result.length > 0 ? result[0] : undefined
}

async function registerSourcePackageFromBytes(
  context: common.UIAbilityContext,
  archiveBytes: Uint8Array,
  archiveFileName: string,
  expectedSourceId?: string,
): Promise<SourcePackageInstallResult> {
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  const packageDir = joinSourceRuntimePath(appSourcePackagesRoot(context), `import-${Date.now()}`)
  const archivePath = joinSourceRuntimePath(packageDir, archiveFileName)
  const importedRoot = joinSourceRuntimePath(packageDir, 'package')
  let removedExisting: SourceRuntimeRegistryEntry | undefined = undefined
  let registeredReplacementSourceId: string = ''
  try {
    ensureDirSync(packageDir)
    writeBytesSync(archivePath, archiveBytes)
    const imported = await importLocalSourceArchive(archiveBytes, archivePath, importedRoot)
    if (!imported.ok || imported.manifest === undefined || imported.wasmBytes === undefined) {
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=' + (imported.reasonCode ?? 'validation_failed'))
      return { ok: false, reasonCode: imported.reasonCode ?? 'validation_failed' }
    }

    const sourceId = imported.manifest.package.id
    if (expectedSourceId !== undefined && expectedSourceId.length > 0 && sourceId !== expectedSourceId) {
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=source_id_mismatch expected=' + expectedSourceId + ' actual=' + sourceId)
      return { ok: false, reasonCode: 'source_id_mismatch' }
    }
    if (!isSourcePackageMinAppVersionSatisfied(imported.manifest.package.minAppVersion)) {
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=app_version_unsupported')
      return { ok: false, reasonCode: 'app_version_unsupported' }
    }
    removedExisting = appSourceRuntimeRegistry.remove(sourceId)
    const replacementEnabled = removedExisting?.enabled ?? true
    const detectedCapabilities = detectSourceRuntimeCapabilities(sourceId, imported.wasmBytes)
    const registered = appSourceRuntimeRegistry.register({
      sourceId,
      route: IMPORTED_SOURCE_ROUTE,
      importStatus: 'imported',
      manifest: imported.manifest,
      wasmBytes: imported.wasmBytes,
      hashOk: imported.hashOk === true,
      network: false,
      enabled: replacementEnabled,
      capabilities: detectedCapabilities,
      manifestPath: imported.manifestPath,
      wasmPath: imported.wasmPath,
      archivePath,
      packageIconPath: imported.iconPath,
      presentationDescription: removedExisting?.presentationDescription,
      presentationIcon: removedExisting?.presentationIcon,
    })
    if (!registered.ok) {
      restoreRuntimeRegistryEntry(removedExisting)
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=' + (registered.reasonCode ?? 'register_failed'))
      return { ok: false, reasonCode: registered.reasonCode ?? 'register_failed' }
    }
    registeredReplacementSourceId = sourceId
    persistInstalledSources(context)
    if (removedExisting?.archivePath !== undefined) {
      const existingDir = removedExisting.archivePath.replace(/\\/g, '/').replace(/\/[^/]*$/, '')
      try {
        await removeAppSourcePackageDir(context, existingDir)
      } catch (_err) {
      }
    }
    console.info('[SourceManager] step=import_ok id=' + sourceId)
    SourceRuntimeStateBridge.notifyChanged()
    return { ok: true, id: sourceId, name: imported.manifest.package.name }
  } catch (_error) {
    if (registeredReplacementSourceId.length > 0) {
      appSourceRuntimeRegistry.remove(registeredReplacementSourceId)
    }
    restoreRuntimeRegistryEntry(removedExisting)
    try {
      await removeAppSourcePackageDir(context, packageDir)
    } catch (_err) {
    }
    console.error('[SourceManager] step=import_fail reason=import_failed')
    return { ok: false, reasonCode: 'import_failed' }
  }
}

export async function installFromArchive(context: common.UIAbilityContext, uri: string): Promise<SourcePackageInstallResult> {
  console.info('[SourceManager] step=import_start')
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  const packageDir = joinSourceRuntimePath(appSourcePackagesRoot(context), `import-${Date.now()}`)
  const archiveFileName = sourceArchiveSandboxFileName(uri)
  const archivePath = joinSourceRuntimePath(packageDir, archiveFileName)
  try {
    ensureDirSync(packageDir)
    await copyPickedArchiveUriToSandbox(uri, archivePath)
    const archiveBytes = readBytesSync(archivePath)
    return await registerSourcePackageFromBytes(context, archiveBytes, archiveFileName)
  } catch (_error) {
    try {
      await removeAppSourcePackageDir(context, packageDir)
    } catch (_err) {
    }
    console.error('[SourceManager] step=import_fail reason=import_failed')
    return { ok: false, reasonCode: 'import_failed' }
  }
}

export async function installFromBytes(
  context: common.UIAbilityContext,
  archiveBytes: Uint8Array,
  pkgFileName: string,
  expectedSourceId?: string,
): Promise<SourcePackageInstallResult> {
  console.info('[SourceManager] step=import_start source=bytes pkg=' + pkgFileName)
  const sanitized = pkgFileName.replace(/[\\/]/g, '_').replace(/^_+|_+$/g, '') || 'source-package.koma'
  const archiveFileName = sanitized.endsWith('.koma') || sanitized.endsWith('.koma-source') ||
    sanitized.endsWith('.koma-source.zip') || sanitized.endsWith('.zip') ? sanitized : sanitized + '.koma'
  return await registerSourcePackageFromBytes(context, archiveBytes, archiveFileName, expectedSourceId)
}

export function setSourcePresentationMetadata(
  context: common.UIAbilityContext,
  id: string,
  description: string,
  icon: string,
): boolean {
  const existing = appSourceRuntimeRegistry.lookup(id).entry
  if (existing === undefined) {
    return false
  }
  const previousDescription = existing.presentationDescription
  const previousIcon = existing.presentationIcon
  if (!appSourceRuntimeRegistry.setPresentationMetadata(id, description, icon)) {
    return false
  }
  try {
    persistInstalledSources(context)
  } catch (_error) {
    appSourceRuntimeRegistry.setPresentationMetadata(id, previousDescription, previousIcon)
    return false
  }
  SourceRuntimeStateBridge.notifyChanged()
  return true
}

export function setEnabled(context: common.UIAbilityContext, id: string, enabled: boolean): boolean {
  const changed = appSourceRuntimeRegistry.setEnabled(id, enabled)
  if (!changed) {
    return false
  }
  persistInstalledSources(context)
  SourceRuntimeStateBridge.notifyChanged()
  console.info('[SourceManager] step=' + (enabled ? 'enable' : 'disable') + ' id=' + id)
  return true
}

export async function remove(context: common.UIAbilityContext, id: string): Promise<boolean> {
  const entry = appSourceRuntimeRegistry.remove(id)
  if (entry === undefined) {
    return false
  }
  if (entry.archivePath !== undefined) {
    const packageDir = entry.archivePath.replace(/\\/g, '/').replace(/\/[^/]*$/, '')
    try {
      await removeAppSourcePackageDir(context, packageDir)
    } catch (_err) {
    }
  }
  appSourceSettingsStore.removeSource(id)
  appSourceFilterPreferencesStore.removeSource(id)
  clearSourceRuntimeDiagnostic(id)
  persistInstalledSources(context)
  SourceRuntimeStateBridge.notifyChanged()
  console.info('[SourceManager] step=remove id=' + id)
  return true
}

export function runSmoke(id: string): SourcePackageSmokeResult {
  const sourceInfoResult = runRegisteredSourceRequestById(
    appSourceRuntimeRegistry,
    id,
    sourceManagerSmokeSourceInfoRequest(id),
  )
  if (sourceInfoResult.ok) {
    console.info('[SourceManager] step=smoke_ok id=' + id + ' operation=source_info')
    const passed: SourcePackageSmokeResult = { ok: true, id, firstTitle: 'source_info' }
    setSourceRuntimeDiagnostic(passed)
    return passed
  }
  if (!sourceInfoResult.attemptedWamrExecution) {
    const failed: SourcePackageSmokeResult = { ok: false, id, reasonCode: sourceInfoResult.reasonCode ?? 'smoke_failed' }
    setSourceRuntimeDiagnostic(failed)
    return failed
  }

  const fixtureResult = runRegisteredSourceRequestById(
    appSourceRuntimeRegistry,
    id,
    sourceManagerSmokeFixtureSearchRequest(id),
  )
  if (!fixtureResult.ok) {
    const failed: SourcePackageSmokeResult = { ok: false, id, reasonCode: sourceInfoResult.reasonCode ?? fixtureResult.reasonCode ?? 'smoke_failed' }
    setSourceRuntimeDiagnostic(failed)
    return failed
  }
  console.info('[SourceManager] step=smoke_ok id=' + id + ' operation=search')
  const passed: SourcePackageSmokeResult = { ok: true, id, firstTitle: 'Fixture Series' }
  setSourceRuntimeDiagnostic(passed)
  return passed
}
