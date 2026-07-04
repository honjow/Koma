import { common } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import {
  importLocalSourceArchive,
  LocalSourcePackageManifest,
  normalizeSourceOperationCapabilityTokens,
  SOURCE_PACKAGE_WASM_FILE,
  SOURCE_REPO_PACKAGE_WASM_FILE,
  validateRestoredSourcePackage,
} from './SourcePackageImporter'
import {
  runRegisteredSourceRequestById,
} from './SourceRuntimeService'
import { appSourceSettingsStore } from './SourceSettingsStore'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
} from './SourceRuntimeRegistry'

const IMPORTED_SOURCE_ROUTE: string = 'app-local-source-package'
const APP_SOURCE_ROOT_NAME: string = 'source-runtime'
const APP_SOURCE_PACKAGES_DIR_NAME: string = 'packages'
const APP_SOURCE_METADATA_FILE_NAME: string = 'source-runtime-registry.json'
const SOURCE_ARCHIVE_SUFFIX_FILTER: string = 'Koma source packages(.koma, .koma-source, .koma-source.zip, .zip)|.koma,.koma-source,.koma-source.zip,.zip'

export interface InstalledSourcePackage {
  id: string
  name: string
  version: string
  lang: string
  nsfw: boolean
  enabled: boolean
  status: string
  smokeStatus: string
  lastDiagnosticMessage: string
  capabilities: string[]
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
}

export interface SourcePackageRestoreResult {
  ok: boolean
  restoredCount: number
  reasonCode?: string
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

function sourcePackageFromEntry(entry: SourceRuntimeRegistryEntry): InstalledSourcePackage {
  const diagnostic = getSourceRuntimeDiagnostic(entry.sourceId)
  return {
    id: entry.sourceId,
    name: entry.manifestName,
    version: entry.manifestVersion,
    lang: entry.language,
    nsfw: entry.nsfw,
    enabled: entry.enabled,
    status: entry.importStatus,
    smokeStatus: diagnostic === undefined ? AppStrings.get('source_pkg_not_run') : (diagnostic.ok ? 'PASS' : 'FAIL'),
    lastDiagnosticMessage: diagnostic === undefined ? '' : (diagnostic.reasonCode ?? 'ok'),
    capabilities: entry.capabilities,
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
    packages.push({
      sourceId: entry.sourceId,
      version: entry.manifestVersion,
      enabled: entry.enabled,
      manifest: manifestFromRegistryEntry(entry),
      wasmBase64: bytesToBase64(entry.wasmBytes),
      wasmByteCount: entry.wasmByteCount,
    })
  }
  return packages
}

export async function restoreSourcePackagesFromBackup(
  context: common.UIAbilityContext,
  packages: SourcePackageBackupEntry[],
): Promise<SourcePackageRestoreResult> {
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  let restoredCount = 0
  for (let index = 0; index < packages.length; index += 1) {
    const sourcePackage = packages[index]
    if (sourcePackage === undefined ||
      typeof sourcePackage.sourceId !== 'string' ||
      typeof sourcePackage.version !== 'string' ||
      typeof sourcePackage.enabled !== 'boolean' ||
      typeof sourcePackage.wasmBase64 !== 'string' ||
      typeof sourcePackage.wasmByteCount !== 'number') {
      return { ok: false, restoredCount, reasonCode: 'invalid_source_package_backup' }
    }
    const manifest = sourcePackage.manifest
    if (manifest === undefined || manifest === null || Array.isArray(manifest) || typeof manifest !== 'object') {
      return { ok: false, restoredCount, reasonCode: 'invalid_source_package_manifest' }
    }
    if (manifest.package === undefined || manifest.runtime === undefined ||
      manifest.permissions === undefined || manifest.contentPolicy === undefined) {
      return { ok: false, restoredCount, reasonCode: 'invalid_source_package_manifest' }
    }
    if (manifest.package.id !== sourcePackage.sourceId || manifest.package.version !== sourcePackage.version) {
      return { ok: false, restoredCount, reasonCode: 'source_package_identity_mismatch' }
    }

    const wasmBytes = base64ToBytes(sourcePackage.wasmBase64)
    if (wasmBytes.byteLength !== sourcePackage.wasmByteCount) {
      return { ok: false, restoredCount, reasonCode: 'source_package_byte_count_mismatch' }
    }
    const validationReason = validateRestoredSourcePackage(manifest, wasmBytes)
    if (validationReason !== undefined) {
      return { ok: false, restoredCount, reasonCode: validationReason }
    }

    const packageDir = joinSourceRuntimePath(appSourcePackagesRoot(context), `backup-${Date.now()}-${index}`)
    const archivePath = joinSourceRuntimePath(packageDir, 'backup-source-package.json')
    const importedRoot = joinSourceRuntimePath(packageDir, 'package')
    const manifestPath = joinSourceRuntimePath(importedRoot, 'manifest.generated.json')
    const wasmPath = joinSourceRuntimePath(importedRoot, manifest.runtime.wasmPath)
    ensureDirSync(packageDir)
    ensureDirSync(importedRoot)
    writeTextSync(archivePath, JSON.stringify({
      sourceId: sourcePackage.sourceId,
      version: sourcePackage.version,
      restoredAt: Date.now(),
    }))
    writeTextSync(manifestPath, JSON.stringify(manifest))
    writeBytesSync(wasmPath, wasmBytes)

    const existing = appSourceRuntimeRegistry.remove(sourcePackage.sourceId)
    if (existing?.archivePath !== undefined) {
      const existingDir = existing.archivePath.replace(/\\/g, '/').replace(/\/[^/]*$/, '')
      try {
        await removeAppSourcePackageDir(context, existingDir)
      } catch (_err) {
      }
    }
    const registered = appSourceRuntimeRegistry.register({
      sourceId: sourcePackage.sourceId,
      route: IMPORTED_SOURCE_ROUTE,
      importStatus: 'imported',
      manifest,
      wasmBytes,
      hashOk: true,
      network: false,
      enabled: sourcePackage.enabled,
      manifestPath,
      wasmPath,
      archivePath,
    })
    if (!registered.ok) {
      try {
        await removeAppSourcePackageDir(context, packageDir)
      } catch (_err) {
      }
      return { ok: false, restoredCount, reasonCode: registered.reasonCode ?? 'source_package_register_failed' }
    }
    restoredCount += 1
  }
  persistInstalledSources(context)
  return { ok: true, restoredCount }
}

export function reloadInstalledSourcePackages(context: common.UIAbilityContext): void {
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  const reloaded = SourceRuntimeRegistry.reloadFromAppLocalMetadata(appSourceMetadataPath(context))
  if (!reloaded.ok) {
    return
  }
  const entries = reloaded.registry.list()
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index]
    if (appSourceRuntimeRegistry.lookup(entry.sourceId).ok) {
      continue
    }
    appSourceRuntimeRegistry.register({
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
    })
  }
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
    removedExisting = appSourceRuntimeRegistry.remove(sourceId)
    const registered = appSourceRuntimeRegistry.register({
      sourceId,
      route: IMPORTED_SOURCE_ROUTE,
      importStatus: 'imported',
      manifest: imported.manifest,
      wasmBytes: imported.wasmBytes,
      hashOk: imported.hashOk === true,
      network: false,
      enabled: true,
      manifestPath: imported.manifestPath,
      wasmPath: imported.wasmPath,
      archivePath,
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

export function setEnabled(context: common.UIAbilityContext, id: string, enabled: boolean): boolean {
  const changed = appSourceRuntimeRegistry.setEnabled(id, enabled)
  if (!changed) {
    return false
  }
  persistInstalledSources(context)
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
  clearSourceRuntimeDiagnostic(id)
  persistInstalledSources(context)
  console.info('[SourceManager] step=remove id=' + id)
  return true
}

export function runSmoke(id: string): SourcePackageSmokeResult {
  const result = runRegisteredSourceRequestById(
    appSourceRuntimeRegistry,
    id,
    `{"type":"request","version":1,"requestId":"source-manager-smoke-${Date.now()}","operation":"search","sourceId":"${id}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`,
  )
  if (!result.ok) {
    const failed: SourcePackageSmokeResult = { ok: false, id, reasonCode: result.reasonCode ?? 'smoke_failed' }
    setSourceRuntimeDiagnostic(failed)
    return failed
  }
  console.info('[SourceManager] step=smoke_ok id=' + id)
  const passed: SourcePackageSmokeResult = { ok: true, id, firstTitle: 'Fixture Series' }
  setSourceRuntimeDiagnostic(passed)
  return passed
}
