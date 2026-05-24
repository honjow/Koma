import { common } from '@kit.AbilityKit'
import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit'
import { resourceManager } from '@kit.LocalizationKit'
import {
  importLocalSourceArchive,
  LocalSourcePackageManifest,
} from './SourcePackageImporter'
import {
  runRegisteredSourceRequestById,
} from './SourceRuntimeService'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryEntry,
} from './SourceRuntimeRegistry'

const DEV_SOURCE_ROUTE: string = 'bundled-dev-rawfile-source'
const IMPORTED_SOURCE_ROUTE: string = 'app-local-source-package'
const APP_SOURCE_ROOT_NAME: string = 'source-runtime'
const APP_SOURCE_PACKAGES_DIR_NAME: string = 'packages'
const APP_SOURCE_METADATA_FILE_NAME: string = 'source-runtime-registry.json'
const SOURCE_ARCHIVE_SUFFIX_FILTER: string = 'Koma source packages(.koma-source.zip, .zip)|.koma-source.zip,.zip'

interface BundledDevSource {
  sourceId: string
  displayName: string
  version: string
  rawfilePath: string
}

export interface InstalledSourcePackage {
  id: string
  name: string
  version: string
  enabled: boolean
  status: string
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

const BUNDLED_DEV_SOURCES: BundledDevSource[] = [
  {
    sourceId: 'local.test.koma.fixture.browse',
    displayName: 'Koma Fixture',
    version: 'dev',
    rawfilePath: 'test/rust_source_runtime_fixture.wasm',
  },
]

export const appSourceRuntimeRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()

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

function createBundledDevManifest(source: BundledDevSource, wasmByteCount: number): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: source.sourceId,
      name: source.displayName,
      version: source.version,
      language: 'multi',
      type: 'wasm-source-dev',
      nsfw: false,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: source.rawfilePath,
      wasmSha256: '',
      wasmSizeBytes: wasmByteCount,
      maxWasmBytes: wasmByteCount,
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
  }
}

function sourcePackageFromEntry(entry: SourceRuntimeRegistryEntry): InstalledSourcePackage {
  return {
    id: entry.sourceId,
    name: entry.manifestName,
    version: entry.manifestVersion,
    enabled: entry.enabled,
    status: entry.importStatus,
    capabilities: entry.capabilities,
  }
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
      nsfw: false,
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
    contentPolicy: {
      publicIndex: false,
      marketplace: false,
      builtInSource: false,
      remoteInstall: false,
    },
  }
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
          nsfw: false,
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
      manifestPath: entry.manifestPath,
      wasmPath: entry.wasmPath,
      archivePath: entry.archivePath,
    })
  }
}

export function registerBundledDevSourcesForBrowse(resourceMgr: resourceManager.ResourceManager): number {
  for (let index = 0; index < BUNDLED_DEV_SOURCES.length; index += 1) {
    const source = BUNDLED_DEV_SOURCES[index]
    if (appSourceRuntimeRegistry.lookup(source.sourceId).ok) {
      continue
    }
    try {
      const wasmBytes = resourceMgr.getRawFileContentSync(source.rawfilePath)
      appSourceRuntimeRegistry.register({
        sourceId: source.sourceId,
        route: DEV_SOURCE_ROUTE,
        importStatus: 'staged',
        manifest: createBundledDevManifest(source, wasmBytes.byteLength),
        wasmBytes: new Uint8Array(wasmBytes.buffer),
        hashOk: true,
        network: false,
        enabled: true,
        wasmPath: source.rawfilePath,
      })
    } catch (error) {
      const e = error as Error
      console.error('register bundled browse source failed: ' + source.sourceId + ': ' + e.message)
    }
  }

  return appSourceRuntimeRegistry.count()
}

export function bootstrapSourceRuntimeAppRegistry(context: common.UIAbilityContext): number {
  reloadInstalledSourcePackages(context)
  return registerBundledDevSourcesForBrowse(context.resourceManager)
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

export async function installFromArchive(context: common.UIAbilityContext, uri: string): Promise<SourcePackageInstallResult> {
  console.info('[SourceManager] step=import_start')
  ensureDirSync(appSourceRoot(context))
  ensureDirSync(appSourcePackagesRoot(context))
  const packageDir = joinSourceRuntimePath(appSourcePackagesRoot(context), `import-${Date.now()}`)
  const archivePath = joinSourceRuntimePath(packageDir, 'source-package.zip')
  const importedRoot = joinSourceRuntimePath(packageDir, 'package')
  try {
    ensureDirSync(packageDir)
    await copyPickedArchiveUriToSandbox(uri, archivePath)
    const archiveBytes = readBytesSync(archivePath)
    const imported = await importLocalSourceArchive(archiveBytes, archivePath, importedRoot)
    if (!imported.ok || imported.manifest === undefined || imported.wasmBytes === undefined) {
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=' + (imported.reasonCode ?? 'validation_failed'))
      return { ok: false, reasonCode: imported.reasonCode ?? 'validation_failed' }
    }

    const sourceId = imported.manifest.package.id
    const existing = appSourceRuntimeRegistry.remove(sourceId)
    if (existing?.wasmPath !== undefined && existing.archivePath !== undefined) {
      const existingDir = existing.archivePath.replace(/\\/g, '/').replace(/\/[^/]*$/, '')
      try {
        await removeAppSourcePackageDir(context, existingDir)
      } catch (_err) {
      }
    }
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
      await removeAppSourcePackageDir(context, packageDir)
      console.error('[SourceManager] step=import_fail reason=' + (registered.reasonCode ?? 'register_failed'))
      return { ok: false, reasonCode: registered.reasonCode ?? 'register_failed' }
    }
    persistInstalledSources(context)
    console.info('[SourceManager] step=import_ok id=' + sourceId)
    return { ok: true, id: sourceId, name: imported.manifest.package.name }
  } catch (error) {
    const e = error as Error
    try {
      await removeAppSourcePackageDir(context, packageDir)
    } catch (_err) {
    }
    console.error('[SourceManager] step=import_fail reason=' + e.message)
    return { ok: false, reasonCode: 'import_failed' }
  }
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
    return { ok: false, id, reasonCode: result.reasonCode ?? 'smoke_failed' }
  }
  console.info('[SourceManager] step=smoke_ok id=' + id)
  return { ok: true, id, firstTitle: 'Fixture Series' }
}
