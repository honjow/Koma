import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const appRegistryPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeAppRegistry.ets')
const importerPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourcePackageImporter.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')
const managerPagePath = resolve(root, 'entry/src/main/ets/pages/SourcePackageManagerPage.ets')
const browseViewModelPath = resolve(root, 'entry/src/main/ets/viewmodel/BrowseViewModel.ets')
const browsePagePath = resolve(root, 'entry/src/main/ets/pages/BrowsePage.ets')
const sourceSettingsStorePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets')
const smokePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets')
const abiDocPath = resolve(root, 'docs/source-runtime-abi.md')
const localKomaFixturePath = resolve(root, 'entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma')
const externalSourcePackages = [
  '/home/gamer/git/koma-sources/dist/sources/mangadex/mangadex-0.1.0.koma',
  '/home/gamer/git/koma-sources/dist/sources/baozimh/baozimh-0.1.0.koma',
]

const appRegistrySource = readFileSync(appRegistryPath, 'utf8')
const importerSource = readFileSync(importerPath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')
const managerPageSource = readFileSync(managerPagePath, 'utf8')
const browseViewModelSource = readFileSync(browseViewModelPath, 'utf8')
const browsePageSource = readFileSync(browsePagePath, 'utf8')
const sourceSettingsStoreSource = readFileSync(sourceSettingsStorePath, 'utf8')
const smokeSource = readFileSync(smokePath, 'utf8')
const abiDocSource = readFileSync(abiDocPath, 'utf8')

function readUInt16Le(bytes, offset) {
  return bytes[offset] | (bytes[offset + 1] << 8)
}

function readUInt32Le(bytes, offset) {
  return (bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24)) >>> 0
}

function readZipEntryNames(path) {
  const bytes = readFileSync(path)
  let eocdOffset = -1
  for (let offset = bytes.length - 22; offset >= Math.max(0, bytes.length - 65557); offset -= 1) {
    if (readUInt32Le(bytes, offset) === 0x06054b50) {
      eocdOffset = offset
      break
    }
  }
  assert.notEqual(eocdOffset, -1, `${path} must be a zip archive`)
  const entryCount = readUInt16Le(bytes, eocdOffset + 10)
  let offset = readUInt32Le(bytes, eocdOffset + 16)
  const names = []
  for (let index = 0; index < entryCount; index += 1) {
    assert.equal(readUInt32Le(bytes, offset), 0x02014b50, `${path} central directory entry ${index} must be valid`)
    const nameLength = readUInt16Le(bytes, offset + 28)
    const extraLength = readUInt16Le(bytes, offset + 30)
    const commentLength = readUInt16Le(bytes, offset + 32)
    const nameOffset = offset + 46
    names.push(bytes.subarray(nameOffset, nameOffset + nameLength).toString('utf8'))
    offset = nameOffset + nameLength + extraLength + commentLength
  }
  return names
}

function assertSourceRepoShape(path) {
  const names = readZipEntryNames(path).sort()
  assert.deepEqual(names, ['manifest.json', 'source.wasm'], `${path} must use source-repo package shape`)
}

assert.match(
  appRegistrySource,
  /Koma source packages\([^)]*\.koma[^)]*\.koma-source[^)]*\.koma-source\.zip[^)]*\.zip[^)]*\)\|\.koma,\.koma-source,\.koma-source\.zip,\.zip/,
  'source package picker must advertise and filter .koma, .koma-source, .koma-source.zip, and .zip',
)
assert.match(
  appRegistrySource,
  /sourceArchiveSandboxFileName[\s\S]*endsWith\('\.koma'\)[\s\S]*\.zip/,
  'copy/import path must preserve the picked .koma suffix in a .zip sandbox filename',
)
assert.match(
  appRegistrySource,
  /const archiveBytes = readBytesSync\(archivePath\)[\s\S]*importLocalSourceArchive\(archiveBytes, archivePath, importedRoot\)/,
  'app import path must pass archive bytes to content validator after copying',
)
assert.match(
  appRegistrySource,
  /export interface SourcePackageBackupEntry \{[\s\S]*sourceId: string[\s\S]*version: string[\s\S]*enabled: boolean[\s\S]*manifest: LocalSourcePackageManifest[\s\S]*wasmBase64: string[\s\S]*wasmByteCount: number[\s\S]*\}/,
  'source package backup entries must use manifest plus base64 wasm bytes',
)
assert.match(
  appRegistrySource,
  /exportInstalledSourcePackages\(\): SourcePackageBackupEntry\[\][\s\S]*manifest: manifestFromRegistryEntry\(entry\)[\s\S]*wasmBase64: bytesToBase64\(entry\.wasmBytes\)[\s\S]*wasmByteCount: entry\.wasmByteCount/,
  'source package backup export must capture bytes and manifest from the registry',
)
assert.doesNotMatch(
  appRegistrySource.match(/exportInstalledSourcePackages\(\): SourcePackageBackupEntry\[\][\s\S]*?return packages\n\}/)?.[0] ?? '',
  /archivePath|wasmPath|manifestPath/,
  'source package backup export must not depend on old sandbox absolute paths',
)
assert.match(
  appRegistrySource,
  /manifestWasmPathFromRegistryEntry[\s\S]*SOURCE_REPO_PACKAGE_WASM_FILE[\s\S]*return SOURCE_PACKAGE_WASM_FILE/,
  'source package backup manifests must store a package-relative wasm path',
)
assert.match(
  appRegistrySource,
  /restoreSourcePackagesFromBackup[\s\S]*base64ToBytes\(sourcePackage\.wasmBase64\)[\s\S]*validateRestoredSourcePackage\(manifest, wasmBytes\)[\s\S]*appSourceRuntimeRegistry\.register/,
  'source package backup restore must decode base64, validate fail-closed, and rebuild registry entries',
)
assert.match(
  importerSource,
  /export function validateRestoredSourcePackage[\s\S]*validateNormalizedManifest\(manifest\)[\s\S]*validateImportedWasmBytes\(manifest, wasmBytes\)[\s\S]*checksum_mismatch/,
  'backup source restore must reuse source package manifest and wasm validation helpers',
)
assert.match(
  backupServiceSource,
  /sourcePackages:\s*exportInstalledSourcePackages\(\)/,
  'backup schema v2 must include source package payloads',
)
assert.doesNotMatch(
  appRegistrySource,
  /BUNDLED_DEV_SOURCES|registerBundledDevSourcesForBrowse|local\.test\.koma\.fixture\.browse|Koma Fixture|bundled-dev-rawfile-source|wasm-source-dev/,
  'production Browse registry must not define or register bundled dev fixture sources',
)
assert.match(
  appRegistrySource,
  /bootstrapSourceRuntimeAppRegistry\(context: common\.UIAbilityContext\): number \{\s*reloadInstalledSourcePackages\(context\)\s*return appSourceRuntimeRegistry\.count\(\)\s*\}/,
  'bootstrapSourceRuntimeAppRegistry must only reload persisted/imported source packages',
)
assert.doesNotMatch(
  importerSource,
  /archivePath\.endsWith|\.koma\)\s*\{/,
  'source package importer must not trust archive filename extensions',
)
assert.match(importerSource, /SOURCE_REPO_PACKAGE_MANIFEST_FILE:\s*string = 'manifest\.json'/, 'importer must support manifest.json')
assert.match(importerSource, /SOURCE_REPO_PACKAGE_WASM_FILE:\s*string = 'source\.wasm'/, 'importer must support source.wasm')
assert.match(importerSource, /validateArchiveEntries[\s\S]*seen\.has\(name\)[\s\S]*unsafe_archive_entry/, 'duplicate or unsafe zip entries must stay rejected')
assert.match(importerSource, /checksum_mismatch/, 'checksum mismatch rejection must stay wired')
assert.match(importerSource, /network_not_allowed/, 'network permission rejection must stay wired')
assert.match(managerPageSource, /\.koma \/ \.koma-source\.zip \/ \.zip/, 'manager UI copy must mention .koma / .koma-source.zip / .zip')
assert.match(sourceSettingsStoreSource, /export class SourceSettingsStore[\s\S]*loadForSource\(sourceId: string\)[\s\S]*saveForSource\(sourceId: string, values: SourceSettingsRecord/, 'source settings store must exist and scope values by sourceId')
assert.match(sourceSettingsStoreSource, /SOURCE_SETTINGS_FILE_NAME:\s*string = 'source-settings\.json'[\s\S]*schemaVersion:\s*SOURCE_SETTINGS_SCHEMA_VERSION[\s\S]*sources:/, 'source settings store must persist a simple schema-versioned per-source document')
assert.match(sourceSettingsStoreSource, /function descriptorIsCredentialLike[\s\S]*SECRET_ID_MARKERS[\s\S]*some/, 'source settings store must recognize credential-like descriptor ids')
for (const marker of ['password', 'authorization', 'api_key', 'cookie', 'token']) {
  assert.match(sourceSettingsStoreSource, new RegExp(`'${marker}'`), `source settings secret marker ${marker} must be blocked`)
}
assert.match(sourceSettingsStoreSource, /filterSafeValues[\s\S]*!descriptor\.supported \|\| descriptor\.sensitive[\s\S]*descriptorIsCredentialLike\(key, ''\)/, 'source settings persistence must block raw credential-like values')
assert.match(sourceSettingsStoreSource, /fetchSourceSettingDescriptors[\s\S]*operation: 'get_settings'[\s\S]*normalizeSourceSettingDescriptors\(summary\.response\)/, 'source settings helper must call get_settings and normalize descriptors')
assert.match(sourceSettingsStoreSource, /data\?\.\['settings'\] \?\? data\?\.\['items'\]/, 'source settings helper must accept data.settings and data.items response shapes')
assert.match(sourceSettingsStoreSource, /SAFE_SETTING_KINDS:\s*string\[\] = \['string', 'boolean', 'select', 'multiselect', 'range'\]/, 'source settings persistence must limit saved descriptor kinds to safe non-secret values')
assert.match(managerPageSource, /Button\('设置'\)[\s\S]*this\.openSettings\(source\)/, 'SourcePackageManagerPage must expose a 设置 action on package cards')
assert.match(managerPageSource, /fetchSourceSettingDescriptors\(appSourceRuntimeRegistry, source\.id\)/, 'SourcePackageManagerPage settings action must fetch get_settings descriptors')
assert.match(managerPageSource, /需要登录配置（暂未启用）/, 'SourcePackageManagerPage must show auth-required placeholder for credential-like descriptors')
assert.match(managerPageSource, /appSourceSettingsStore\.saveForSource\(this\.settingsSourceId, this\.settingDraft, this\.settingDescriptors\)/, 'SourcePackageManagerPage must save settings through the source settings store')
assert.match(
  browseViewModelSource,
  /loadInstalledSources\(\): void \{[\s\S]*this\.sources = this\.registry\.listInstalledSourceSummaries\(\)[\s\S]*\}/,
  'Browse loadInstalledSources must use the registry inventory directly',
)
assert.match(
  browseViewModelSource,
  /appSourceSettingsStore\.loadForSource\(sourceId\)[\s\S]*settings,/,
  'BrowseViewModel must load and inject per-source settings into source runtime requests',
)
assert.doesNotMatch(
  browseViewModelSource,
  /const settings[^=]*=\s*\{\}/,
  'BrowseViewModel must not hardcode empty source runtime settings',
)
assert.doesNotMatch(
  browseViewModelSource,
  /MOCK_SOURCE_SUMMARY|Mock Source|mock\.source\.browse|useMockData|_mockSourceMangaList|_mockSearchSourceMangaList|this\.sources\s*=\s*\[[^\]\n]+/,
  'Browse production path must not inject a mock source when the registry is empty',
)
assert.match(
  browsePageSource,
  /Text\('未安装源包'\)[\s\S]*Text\('从设置导入 \.koma 源包'\)/,
  'empty Browse source inventory must guide users to import a .koma source package',
)
assert.match(smokeSource, /local_source_runtime_fixture\.koma/, 'device smoke must cover a .koma source archive')
assert.match(abiDocSource, /`\.koma`、`\.koma-source`、`\.koma-source\.zip` 和 `\.zip`/, 'source ABI docs must document supported import suffixes')

assertSourceRepoShape(localKomaFixturePath)

for (const sourcePackage of externalSourcePackages) {
  if (existsSync(sourcePackage)) {
    assertSourceRepoShape(sourcePackage)
  }
}

console.log('source package .koma compatibility checks PASS')
