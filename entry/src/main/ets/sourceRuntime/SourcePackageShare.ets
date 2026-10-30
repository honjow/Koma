import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { zlib } from '@kit.BasicServicesKit'
import { appSourceRuntimeRegistry, sourceDisplayName } from './SourceRuntimeAppRegistry'
import { SourceRuntimeRegistryEntry } from './SourceRuntimeRegistry'
import {
  LocalSourcePackageManifest, sourceRepoManifestForShare,
  SOURCE_PACKAGE_MANIFEST_FILE, SOURCE_PACKAGE_WASM_FILE,
  SOURCE_REPO_PACKAGE_MANIFEST_FILE, SOURCE_REPO_PACKAGE_WASM_FILE,
} from './SourcePackageImporter'

export interface SourcePackageShareFile {
  fileName: string
  uri: string
}

export function canShareInstalledSourcePackage(sourceId: string): boolean {
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  return entry?.importStatus === 'imported' && ((entry.archivePath?.length ?? 0) > 0 ||
    ((entry.manifestPath?.length ?? 0) > 0 && (entry.wasmPath?.length ?? 0) > 0))
}

async function writeManifest(path: string, text: string): Promise<void> {
  const file = await fileIo.open(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  try { await fileIo.write(file.fd, text) } finally { await fileIo.close(file) }
}

async function rebuildRestoredPackage(entry: SourceRuntimeRegistryEntry, directory: string, path: string): Promise<void> {
  if (!entry.manifestPath || !entry.wasmPath) throw new Error('source_package_files_unavailable')
  const staging = directory + '/package'
  await fileIo.mkdir(staging)
  const files: string[] = []
  try {
    const raw = await fileIo.readText(entry.manifestPath)
    const iconName = entry.packageIconPath?.split('/').pop()
    let manifestName: string
    let wasmName: string
    let text: string
    if (entry.manifestPath.endsWith('/' + SOURCE_REPO_PACKAGE_MANIFEST_FILE)) {
      manifestName = SOURCE_REPO_PACKAGE_MANIFEST_FILE
      wasmName = SOURCE_REPO_PACKAGE_WASM_FILE
      text = raw
    } else {
      const manifest = JSON.parse(raw) as LocalSourcePackageManifest
      if (iconName && entry.packageIconPath) {
        // A restored repository package has a normalized manifest. Recreate the
        // public layout so reimport keeps its actual identity image as well.
        manifestName = SOURCE_REPO_PACKAGE_MANIFEST_FILE
        wasmName = SOURCE_REPO_PACKAGE_WASM_FILE
        text = sourceRepoManifestForShare(manifest, iconName)
      } else {
        // Older backups without an image retain the existing internal format.
        manifest.runtime.wasmPath = SOURCE_PACKAGE_WASM_FILE
        manifestName = SOURCE_PACKAGE_MANIFEST_FILE
        wasmName = SOURCE_PACKAGE_WASM_FILE
        text = JSON.stringify(manifest)
      }
    }
    files.push(staging + '/' + manifestName)
    await writeManifest(files[files.length - 1], text)
    files.push(staging + '/' + wasmName)
    await fileIo.copyFile(entry.wasmPath, files[files.length - 1])
    if (manifestName === SOURCE_REPO_PACKAGE_MANIFEST_FILE && iconName && entry.packageIconPath) {
      files.push(staging + '/' + iconName)
      await fileIo.copyFile(entry.packageIconPath, files[files.length - 1])
    }
    // The system compressor appends .zip to a custom suffix. Produce that real
    // file first, then rename it to the .koma URI handed to the share panel.
    await zlib.compressFile(staging, path + '.zip', {})
    await fileIo.rename(path + '.zip', path)
  } finally {
    try { await fileIo.unlink(path + '.zip') } catch (_) {}
    for (const file of files) { try { await fileIo.unlink(file) } catch (_) {} }
    try { await fileIo.rmdir(staging) } catch (_) {}
  }
}

export async function prepareInstalledSourcePackageShare(
  context: common.UIAbilityContext, sourceId: string,
): Promise<SourcePackageShareFile> {
  // Share source package contents, never the registry, settings or web session.
  // Resolve after the details sheet closes to export the currently installed version.
  const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
  if (entry?.importStatus !== 'imported') throw new Error('source_archive_unavailable')
  const name = sourceDisplayName(entry.sourceId, entry.manifestName).replace(/[\\/:*?"<>|\u0000-\u001F]/g, '_')
  const fileName = name + '-' + entry.manifestVersion + '.koma'
  const directory = await fileIo.mkdtemp(context.cacheDir + '/source-package-share-XXXXXX')
  const path = directory + '/' + fileName
  try {
    if (entry.archivePath && !entry.archivePath.endsWith('/backup-source-package.json')) {
      await fileIo.copyFile(entry.archivePath, path)
    } else {
      await rebuildRestoredPackage(entry, directory, path)
    }
    // The receiver can read after the panel closes. Keep this immutable cache copy;
    // source updates/removal and subsequent shares must not replace its bytes.
    return { fileName, uri: fileUri.getUriFromPath(path) }
  } catch (error) {
    try { await fileIo.unlink(path) } catch (_) {}
    try { await fileIo.rmdir(directory) } catch (_) {}
    throw error as Error
  }
}
