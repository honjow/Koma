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
const sourceBrowsePagePath = resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets')
const sourceSearchPagePath = resolve(root, 'entry/src/main/ets/pages/SourceSearchPage.ets')
const sourceFilterControlsPath = resolve(root, 'entry/src/main/ets/components/SourceFilterControls.ets')
const sourceModelsPath = resolve(root, 'entry/src/main/ets/model/SourceModels.ets')
const sourceSettingsStorePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets')
const sourceFilterPreferencesStorePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceFilterPreferencesStore.ets')
const smokePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets')
const sourceRuntimeRegistryPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeRegistry.ets')
const sourcePackageTrustPolicyPath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourcePackageTrustPolicy.ets')
const abiDocPath = resolve(root, 'docs/source-runtime-abi.md')
const sdkDocPath = resolve(root, 'docs/source-package-sdk.md')
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
const sourceBrowsePageSource = readFileSync(sourceBrowsePagePath, 'utf8')
const sourceSearchPageSource = readFileSync(sourceSearchPagePath, 'utf8')
const sourceFilterControlsSource = readFileSync(sourceFilterControlsPath, 'utf8')
const sourceModelsSource = readFileSync(sourceModelsPath, 'utf8')
const sourceSettingsStoreSource = readFileSync(sourceSettingsStorePath, 'utf8')
const sourceFilterPreferencesStoreSource = readFileSync(sourceFilterPreferencesStorePath, 'utf8')
const smokeSource = readFileSync(smokePath, 'utf8')
const sourceRuntimeRegistrySource = readFileSync(sourceRuntimeRegistryPath, 'utf8')
const sourcePackageTrustPolicySource = readFileSync(sourcePackageTrustPolicyPath, 'utf8')
const abiDocSource = readFileSync(abiDocPath, 'utf8')
const sdkDocSource = readFileSync(sdkDocPath, 'utf8')

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
  /registerSourcePackageFromBytes[\s\S]*importLocalSourceArchive\(archiveBytes, archivePath, importedRoot\)/,
  'app import core path must pass archive bytes to content validator for both picker and bytes install',
)
assert.match(
  appRegistrySource,
  /export async function installFromBytes\(\s*context: common\.UIAbilityContext,\s*archiveBytes: Uint8Array,\s*pkgFileName: string,\s*expectedSourceId\?: string,\s*\): Promise<SourcePackageInstallResult>/,
  'app registry must expose installFromBytes for source index service to use',
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
  /operationCapabilities: normalizeSourceOperationCapabilityTokens\(optionalStringArray\(capabilities\?\.operations as Object \| undefined\)\)/,
  'source package importer must normalize manifest capabilities.operations into bounded operation capability tokens',
)
assert.match(
  importerSource,
  /normalizeSourceOperationCapabilityToken[\s\S]*case 'get_home':[\s\S]*return 'home'[\s\S]*case 'get_settings':[\s\S]*return 'settings'[\s\S]*case 'get_image_request':[\s\S]*return 'imageRequest'/,
  'source operation capability normalization must cover browse, settings, and image-request operations',
)
assert.match(
  importerSource,
  /validateNormalizedManifest[\s\S]*manifest\.operationCapabilities[\s\S]*normalizeSourceOperationCapabilityTokens\(manifest\.operationCapabilities\)\.length !== manifest\.operationCapabilities\.length[\s\S]*manifest_invalid/,
  'source package validation must reject unnormalized operation capability metadata',
)
assert.match(
  appRegistrySource,
  /manifestFromRegistryEntry[\s\S]*operationCapabilities: normalizeSourceOperationCapabilityTokens\(entry\.capabilities\)/,
  'source package backup manifests must preserve normalized operation capability summaries',
)
assert.match(
  appRegistrySource,
  /appSourceSettingsStore\.removeSource\(id\)[\s\S]*appSourceFilterPreferencesStore\.removeSource\(id\)[\s\S]*clearSourceRuntimeDiagnostic\(id\)/,
  'removing an installed source package must clear source settings and saved source filter preferences',
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
assert.match(managerPageSource, /source_pkg_empty_message/, 'manager UI copy must mention supported source package import suffixes through localized copy')
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
assert.match(sourceSettingsStoreSource, /export interface SourceSettingDescriptor\s*{[\s\S]*minValue\?: number[\s\S]*maxValue\?: number[\s\S]*step\?: number/, 'source setting descriptors must carry optional range min, max, and step metadata')
assert.match(sourceSettingsStoreSource, /minValue: optionalNumber\(record\['min'\]\)[\s\S]*maxValue: optionalNumber\(record\['max'\]\)[\s\S]*step: optionalNumber\(record\['step'\]\)/, 'source settings normalization must parse range min, max, and step metadata')
assert.match(
  sourceSettingsStoreSource,
  /sanitizeDescriptorSettingValue[\s\S]*descriptor\.kind === 'boolean'[\s\S]*typeof value === 'boolean'[\s\S]*descriptor\.kind === 'select'[\s\S]*optionIds\.includes\(value\)[\s\S]*descriptor\.kind === 'multiselect'[\s\S]*!selected\.includes\(item\)[\s\S]*descriptor\.kind === 'range'[\s\S]*normalizedRangeValue\(value, descriptor\)/,
  'source settings persistence must validate values against descriptor kind and option ids before saving',
)
assert.match(
  sourceSettingsStoreSource,
  /normalizedRangeValue\(value: SourceSettingValue, descriptor: SourceSettingDescriptor\)[\s\S]*Math\.max\(descriptor\.minValue, normalized\)[\s\S]*Math\.min\(descriptor\.maxValue, normalized\)/,
  'source settings range values must be clamped to descriptor min and max',
)
assert.match(
  sourceSettingsStoreSource,
  /filterSafeValues[\s\S]*const sanitized = sanitizeDescriptorSettingValue\(safe, descriptor\)[\s\S]*safeValues\[key\] = sanitized/,
  'source settings store must apply descriptor-specific sanitization inside persistence filtering',
)
assert.match(sourceFilterPreferencesStoreSource, /export class SourceFilterPreferencesStore[\s\S]*loadForSource\(sourceId: string, kind: SourceFilterPreferenceKind, filters: SourceFilter\[\]\)[\s\S]*saveForSource\(\s*sourceId: string,\s*kind: SourceFilterPreferenceKind,\s*values: SourceFilterPreferenceRecord,\s*filters: SourceFilter\[\]/, 'source filter preferences store must persist browse/search filter values by sourceId')
assert.match(sourceFilterPreferencesStoreSource, /SOURCE_FILTER_PREFS_FILE_NAME:\s*string = 'source-filter-preferences\.json'[\s\S]*schemaVersion:\s*SOURCE_FILTER_PREFS_SCHEMA_VERSION[\s\S]*sources:/, 'source filter preferences store must persist a schema-versioned per-source document')
assert.match(sourceFilterPreferencesStoreSource, /clearForSource\(sourceId: string, kind: SourceFilterPreferenceKind\): void[\s\S]*if \(kind === 'browse'[\s\S]*nextRecord\.search = sourceRecord\.search[\s\S]*if \(kind === 'search'[\s\S]*nextRecord\.browse = sourceRecord\.browse[\s\S]*document\.sources = nextSources/, 'source filter preferences reset must clear only the requested browse/search scope without dropping the sibling scope')
assert.match(
  sourceFilterPreferencesStoreSource,
  /filterRequestKey\(filter: SourceFilter\)[\s\S]*raw\.startsWith\('filter:'\)[\s\S]*filterOptionValue\(filter: SourceFilter, index: number\)[\s\S]*raw\.startsWith\(keyPrefix\)/,
  'source filter preferences must normalize filter request keys and option ids before saving',
)
assert.match(
  sourceFilterPreferencesStoreSource,
  /sanitizeFilterValue\(value: SourceFilterPreferenceValue, filter: SourceFilter\)[\s\S]*filter\.type === 'check'[\s\S]*typeof value === 'boolean'[\s\S]*filter\.type === 'text'[\s\S]*substring\(0, 160\)[\s\S]*filter\.type === 'select' \|\| filter\.type === 'sort'[\s\S]*filter\.type === 'multiselect'[\s\S]*filter\.type === 'range'/,
  'source filter preferences must sanitize persisted values by source filter type',
)
assert.match(
  sourceFilterPreferencesStoreSource,
  /sanitizeChoiceFilterValue[\s\S]*const allowed = filterOptionValues\(filter\)[\s\S]*allowed\.includes\(normalized\)[\s\S]*sanitizeMultiSelectFilterValue[\s\S]*selected\.includes\(normalized\)[\s\S]*allowed\.includes\(normalized\)/,
  'source filter preferences must validate select and multiselect values against source option ids',
)
assert.match(
  sourceFilterPreferencesStoreSource,
  /normalizedRangeFilterValue\(value: SourceFilterPreferenceValue, filter: SourceFilter\)[\s\S]*Math\.max\(filter\.minValue, next\)[\s\S]*Math\.min\(filter\.maxValue, next\)/,
  'source filter preferences must clamp persisted range values to source-provided bounds',
)
assert.match(
  sourceFilterPreferencesStoreSource,
  /filterSafeValues\(values: SourceFilterPreferenceRecord, filters: SourceFilter\[\]\)[\s\S]*filterByKey\[filterRequestKey\(filter\)\] = filter[\s\S]*const sanitized = sanitizeFilterValue\(safe, filter\)[\s\S]*safeValues\[key\] = sanitized/,
  'source filter preferences must drop values that no longer match active source filter descriptors',
)
assert.match(
  sourceFilterPreferencesStoreSource,
  /exportAll\(\): Record<string, SourceFilterPreferenceSourceRecord>[\s\S]*importAll\(sources: Record<string, SourceFilterPreferenceSourceRecord> \| undefined\)[\s\S]*filterSafeStoredValues\(sourceRecord\.browse\)[\s\S]*filterSafeStoredValues\(sourceRecord\.search\)[\s\S]*SOURCE_FILTER_PREFS_SCHEMA_VERSION/,
  'source filter preferences must support backup export/import without trusting raw document values',
)
assert.match(managerPageSource, /KomaActionButton\(\{[\s\S]*label: t\('source_pkg_settings'\)[\s\S]*this\.openSettings\(source\)/, 'SourcePackageManagerPage must expose a settings action on package cards')
assert.match(managerPageSource, /fetchSourceSettingDescriptors\(appSourceRuntimeRegistry, source\.id\)/, 'SourcePackageManagerPage settings action must fetch get_settings descriptors')
assert.match(managerPageSource, /descriptor\.sensitive \? t\('source_pkg_login_required'\) : t\('source_pkg_unsupported'\)/, 'SourcePackageManagerPage must show auth-required placeholder for credential-like descriptors')
assert.match(managerPageSource, /descriptor\.kind === 'boolean'[\s\S]*hasSwitch: true[\s\S]*this\.updateSettingValue\(descriptor\.id, isOn\)/, 'SourcePackageManagerPage must render safe boolean source settings as switches')
assert.match(managerPageSource, /descriptor\.kind === 'select'[\s\S]*trailingDropdown: true[\s\S]*this\.SettingSelectMenu\(descriptor\)/, 'SourcePackageManagerPage must render safe select source settings as a menu')
assert.match(managerPageSource, /descriptor\.kind === 'multiselect'[\s\S]*trailingDropdown: true[\s\S]*this\.SettingMultiSelectMenu\(descriptor\)/, 'SourcePackageManagerPage must render safe multiselect source settings as a reusable menu')
assert.match(managerPageSource, /toggleMultiSelectSetting\(descriptor: SourceSettingDescriptor, optionId: string\)[\s\S]*selected\.includes\(optionId\)[\s\S]*this\.updateSettingValue\(descriptor\.id, selected\.filter[\s\S]*next\.push\(optionId\)/, 'SourcePackageManagerPage multiselect settings must toggle individual option ids without collapsing into text input')
assert.match(managerPageSource, /descriptor\.kind === 'range'[\s\S]*this\.SettingRangeRow\(descriptor\)/, 'SourcePackageManagerPage must render safe range source settings with a dedicated control')
assert.match(managerPageSource, /rangeMin\(descriptor: SourceSettingDescriptor\): number[\s\S]*descriptor\.minValue \?\? 0[\s\S]*rangeMax\(descriptor: SourceSettingDescriptor\): number[\s\S]*descriptor\.maxValue \?\? fallbackMax/, 'SourcePackageManagerPage range settings must derive safe slider bounds from descriptors')
assert.match(managerPageSource, /setRangeSetting\(descriptor: SourceSettingDescriptor, value: number\)[\s\S]*this\.normalizeRangeSetting\(descriptor, value\)[\s\S]*this\.updateSettingValue\(descriptor\.id, next\)/, 'SourcePackageManagerPage range settings must normalize slider values before saving')
assert.match(managerPageSource, /SettingRangeRow\(descriptor: SourceSettingDescriptor\)[\s\S]*Slider\(\{[\s\S]*value: this\.settingNumberValue\(descriptor\)[\s\S]*min: this\.rangeMin\(descriptor\)[\s\S]*max: this\.rangeMax\(descriptor\)[\s\S]*step: this\.rangeStep\(descriptor\)[\s\S]*this\.setRangeSetting\(descriptor, value\)/, 'SourcePackageManagerPage range settings must use a Slider instead of hand-rolled buttons')
assert.match(managerPageSource, /appSourceSettingsStore\.saveForSource\(this\.settingsSourceId, this\.settingDraft, this\.settingDescriptors\)/, 'SourcePackageManagerPage must save settings through the source settings store')
assert.match(managerPageSource, /clearSavedSettings\(\): void[\s\S]*appSourceSettingsStore\.removeSource\(this\.settingsSourceId\)[\s\S]*savedCount: 0[\s\S]*source_pkg_settings_cleared[\s\S]*this\.closeSettings\(\)/, 'SourcePackageManagerPage must expose a real clear action for saved per-source settings')
assert.match(managerPageSource, /confirmClearSavedSettings\(\): void[\s\S]*source_pkg_clear_settings_title[\s\S]*source_pkg_clear_settings_message[\s\S]*primaryButton:[\s\S]*source_pkg_clear_settings[\s\S]*this\.clearSavedSettings\(\)/, 'SourcePackageManagerPage must confirm before clearing saved per-source settings')
assert.match(managerPageSource, /source_pkg_clear_settings[\s\S]*kind: 'danger'[\s\S]*this\.confirmClearSavedSettings\(\)[\s\S]*source_pkg_save_settings[\s\S]*this\.saveSettings\(\)/, 'SourcePackageManagerPage settings panel must show confirmed clear and save actions together')
assert.match(managerPageSource, /removePackage\(source: InstalledSourcePackage\): Promise<void>[\s\S]*await remove\(this\.context\(\), source\.id\)[\s\S]*this\.clearUpdateStatus\(source\.id\)[\s\S]*this\.clearSettingsValidationStatus\(source\.id\)/, 'SourcePackageManagerPage must still remove source packages and clear related status state')
assert.match(managerPageSource, /confirmRemovePackage\(source: InstalledSourcePackage\): void[\s\S]*source_pkg_remove_title[\s\S]*source_pkg_remove_message[\s\S]*primaryButton:[\s\S]*source_pkg_delete[\s\S]*this\.removePackage\(source\)/, 'SourcePackageManagerPage must confirm before deleting an installed source package')
assert.match(managerPageSource, /label: t\('source_pkg_delete'\)[\s\S]*kind: 'danger'[\s\S]*this\.confirmRemovePackage\(source\)/, 'SourcePackageManagerPage package delete button must route through confirmation')
assert.match(
  browseViewModelSource,
  /loadInstalledSources\(\): void \{[\s\S]*this\.sources = this\.registry\.listInstalledSourceSummaries\(\)[\s\S]*\}/,
  'Browse loadInstalledSources must use the registry inventory directly',
)
assert.match(
  browseViewModelSource,
  /sourceLanguageBadgeFromLanguage\(language: string\)[\s\S]*language\.trim\(\)[\s\S]*split\(\/\[-_\]\/\)\[0\][\s\S]*primary === 'zh'[\s\S]*return 'ZH'[\s\S]*primary === 'ja'[\s\S]*return 'JA'[\s\S]*primary === 'en'[\s\S]*return 'EN'/,
  'Browse source badges must normalize manifest language values before falling back to source id heuristics',
)
assert.match(
  browseViewModelSource,
  /sourceLanguageBadge\(source: SourceRuntimeRegistryInstalledSourceSummary\): string \{[\s\S]*sourceLanguageBadgeFromLanguage\(source\.language\)[\s\S]*manifestLanguageBadge !== undefined[\s\S]*return manifestLanguageBadge[\s\S]*source\.sourceId\.toLocaleLowerCase\(\)/,
  'BrowseViewModel sourceLanguageBadge must prefer the source manifest language over guessing from source id',
)
assert.match(
  browseViewModelSource,
  /appSourceSettingsStore\.loadForSource\(sourceId\)[\s\S]*settings,/,
  'BrowseViewModel must load and inject per-source settings into source runtime requests',
)
assert.match(
  browseViewModelSource,
  /parseSourceListingsFromResponse[\s\S]*data\?\.\['listings'\][\s\S]*SourceListingDescriptor/,
  'BrowseViewModel must normalize source-defined get_listings descriptors',
)
assert.match(
  browseViewModelSource,
  /parseSourceHomeSectionsFromResponse\(sourceId: string[\s\S]*data\?\.\['sections'\][\s\S]*parseSourceMangaFromItem\(sourceId, item\)/,
  'BrowseViewModel must normalize source-defined get_home manga sections',
)
assert.match(
  browseViewModelSource,
  /loadSourceListings\(source: SourceRuntimeRegistryInstalledSourceSummary\)[\s\S]*runSourceOperationResponse\(source\.sourceId, 'get_listings'[\s\S]*defaultListings\(\)/,
  'BrowseViewModel must load runtime listings and keep a safe popular/latest fallback',
)
assert.match(
  browseViewModelSource,
  /loadSourceHomeSections\(source: SourceRuntimeRegistryInstalledSourceSummary\)[\s\S]*runSourceOperationResponse\(source\.sourceId, 'get_home'[\s\S]*section\.kind === 'mangaList'[\s\S]*catch \(_error\)[\s\S]*return \[\]/,
  'BrowseViewModel must load source home sections as a fail-soft enhancement',
)
assert.match(
  browseViewModelSource,
  /loadMangaListing\([\s\S]*listingId: string[\s\S]*listingId,[\s\S]*runSourceOperation\(source\.sourceId, 'get_manga_list'/,
  'BrowseViewModel must request manga lists by source-defined listing id',
)
assert.match(
  browseViewModelSource,
  /parseSourceMangaListFromResponse[\s\S]*page\?\.\['hasMore'\] === true[\s\S]*nextCursor !== undefined/,
  'BrowseViewModel must honor source runtime page.hasMore and nextCursor pagination',
)
assert.match(
  browseViewModelSource,
  /function sourceMangaIdentityKey\(manga: SourceManga\): string \{[\s\S]*manga\.sourceId[\s\S]*manga\.id[\s\S]*function appendUniqueSourceManga\(current: SourceManga\[\], incoming: SourceManga\[\]\): SourceManga\[\] \{[\s\S]*new Set<string>\(\)[\s\S]*seen\.has\(key\)[\s\S]*merged\.push\(manga\)/,
  'BrowseViewModel must keep a shared source manga identity de-duplication helper',
)
assert.match(
  browseViewModelSource,
  /parseSourceMangaListFromResponse[\s\S]*return \{ manga: appendUniqueSourceManga\(\[\], manga\), hasNextPage, nextCursor \}/,
  'BrowseViewModel must remove duplicate source manga items within each runtime page response',
)
assert.match(
  browseViewModelSource,
  /pageCursor\(page: number, cursor: string\)[\s\S]*cursor\.length > 0 \? cursor : `\$\{page\}`/,
  'BrowseViewModel must prefer source-owned cursors with numeric-page fallback',
)
assert.match(
  browseViewModelSource,
  /loadMoreBrowse\(\): Promise<void> \{[\s\S]*const source = this\.selectedSource[\s\S]*const page = this\.browsePage \+ 1[\s\S]*const cursor = this\.browseNextCursor[\s\S]*loadMangaListing\(source, listing\.id, page, cursor\)/,
  'BrowseViewModel must send source-owned cursors for browse pagination',
)
{
  const start = browseViewModelSource.indexOf('async loadMoreBrowse()')
  const end = browseViewModelSource.indexOf('async runSearch(', start)
  const block = browseViewModelSource.slice(start, end)
  assert.match(
    block,
    /catch \(error\)[\s\S]*this\.errorMessage = safeSourceBrowseErrorText\(e, 'browse_error_load_more'\)/,
    'BrowseViewModel browse pagination failures must use the safe load-more error copy',
  )
  assert.doesNotMatch(
    block,
    /catch \(error\)[\s\S]*this\.hasMoreBrowse = false/,
    'BrowseViewModel must keep browse pagination retryable after a load-more failure',
  )
}
assert.match(
  browseViewModelSource,
  /loadMoreSearch\(\): Promise<void> \{[\s\S]*const source = this\.selectedSource[\s\S]*const query = this\.searchQuery\.trim\(\)[\s\S]*const page = this\.searchPage \+ 1[\s\S]*const cursor = this\.searchNextCursor[\s\S]*searchSource\(source, query, page, cursor\)/,
  'BrowseViewModel must send source-owned cursors for search pagination',
)
assert.match(
  browseViewModelSource,
  /loadMoreSearch\(\): Promise<void> \{[\s\S]*this\.searchResults = appendUniqueSourceManga\(this\.searchResults, more\.manga\)/,
  'BrowseViewModel must append source search pagination without duplicating overlapping manga results',
)
assert.match(
  browseViewModelSource,
  /mergeBrowseListingPage\([\s\S]*appendUniqueSourceManga\(current === undefined \? \[\] : current\.manga, more\.manga\)[\s\S]*this\.browseSections = \[\{/,
  'BrowseViewModel must append source browse pagination without duplicating overlapping manga results',
)
assert.match(
  browseViewModelSource,
  /safeSourceBrowseErrorText\(error: Error, fallbackKey: string\): string \{[\s\S]*safeSearchDiagnostic\(error\)[\s\S]*AppStrings\.get\(fallbackKey\)[\s\S]*diagnostic\.userText/,
  'BrowseViewModel must map source browse failures to safe user-facing text with localized fallbacks',
)
assert.match(
  browseViewModelSource,
  /loadBrowseHome[\s\S]*safeSourceBrowseErrorText\(e, 'browse_error_load_home'\)[\s\S]*selectBrowseListing[\s\S]*safeSourceBrowseErrorText\(e, 'browse_error_load_home'\)[\s\S]*loadMoreBrowse[\s\S]*safeSourceBrowseErrorText\(e, 'browse_error_load_more'\)/,
  'BrowseViewModel browse home, listing changes, and load-more failures must use safe error text',
)
assert.doesNotMatch(
  browseViewModelSource,
  /errorMessage\s*=\s*e\.message|e\.message\.length\s*>\s*0\s*\?\s*e\.message/,
  'BrowseViewModel must not surface raw Error.message values in source browse/search UI state',
)
assert.match(
  browseViewModelSource,
  /interface SourceSearchArgs \{[\s\S]*query: string[\s\S]*page: SourceOperationPageArg[\s\S]*filters: SourceMangaListFilters[\s\S]*searchSource\([\s\S]*const args: SourceSearchArgs = \{[\s\S]*query,[\s\S]*page: pageArg,[\s\S]*filters: this\.searchFilterValues/,
  'BrowseViewModel must pass active source-defined filters into source search requests',
)
assert.match(
  browseViewModelSource,
  /@Trace searchFilterValues: SourceMangaListFilters = \{\}[\s\S]*ensureSearchFilters\(source: SourceRuntimeRegistryInstalledSourceSummary\): Promise<void>[\s\S]*this\.filters = await this\.loadSourceFilters\(source\)[\s\S]*this\.searchFilterValues = this\.defaultSourceFilterValues\(this\.filters\)[\s\S]*setSearchFilterValue\(filterId: string, value: SourceFilterValue \| undefined\): boolean[\s\S]*this\.searchFilterValues = nextValues[\s\S]*resetSearchFilters\(\): void \{[\s\S]*this\.searchFilterValues = this\.defaultSourceFilterValues\(this\.filters\)/,
  'BrowseViewModel must expose search-safe source filter loading, updates, and reset without forcing browse listing reloads',
)
assert.match(
  browseViewModelSource,
  /@Trace browseFilterValues: SourceMangaListFilters = \{\}[\s\S]*@Trace searchFilterValues: SourceMangaListFilters = \{\}[\s\S]*setBrowseFilterValue\(filterId: string, value: SourceFilterValue \| undefined\): Promise<void>[\s\S]*this\.updateFilterValue\(this\.browseFilterValues, filterId, value\)[\s\S]*setSearchFilterValue\(filterId: string, value: SourceFilterValue \| undefined\): boolean[\s\S]*this\.updateFilterValue\(this\.searchFilterValues, filterId, value\)/,
  'BrowseViewModel must keep browse and search filter values isolated while sharing source descriptors',
)
assert.match(
  browseViewModelSource,
  /appSourceFilterPreferencesStore[\s\S]*restoreSavedBrowseFilterValues\(source\.sourceId\)[\s\S]*restoreSavedSearchFilterValues\(source\.sourceId\)[\s\S]*mergeSavedSourceFilterValues\([\s\S]*sourceId: string,[\s\S]*appSourceFilterPreferencesStore\.loadForSource\(sourceId, kind, this\.filters\)/,
  'BrowseViewModel must restore saved source filter preferences after loading source descriptors',
)
assert.match(
  browseViewModelSource,
  /setBrowseFilterValue\(filterId: string, value: SourceFilterValue \| undefined\): Promise<void>[\s\S]*this\.browseFilterValues = nextValues[\s\S]*this\.saveSourceFilterValues\('browse', nextValues\)[\s\S]*resetBrowseFilters\(\): Promise<void>[\s\S]*this\.browseFilterValues = this\.defaultSourceFilterValues\(this\.filters\)[\s\S]*this\.clearSavedSourceFilterValues\('browse'\)/,
  'BrowseViewModel must save browse filter changes and clear saved browse preferences on reset',
)
assert.match(
  browseViewModelSource,
  /setSearchFilterValue\(filterId: string, value: SourceFilterValue \| undefined\): boolean[\s\S]*this\.searchFilterValues = nextValues[\s\S]*this\.saveSourceFilterValues\('search', nextValues\)[\s\S]*resetSearchFilters\(\): void \{[\s\S]*this\.searchFilterValues = this\.defaultSourceFilterValues\(this\.filters\)[\s\S]*this\.clearSavedSourceFilterValues\('search'\)/,
  'BrowseViewModel must save search filter changes and clear saved search preferences on reset',
)
assert.match(
  browseViewModelSource,
  /hasSearchFilterChanges\(\): boolean \{[\s\S]*sourceFilterValuesEqual\(this\.searchFilterValues, this\.defaultSourceFilterValues\(this\.filters\)\)[\s\S]*sourceFilterValueEqual\(left: SourceFilterValue \| undefined, right: SourceFilterValue \| undefined\)[\s\S]*Array\.isArray\(left\) \|\| Array\.isArray\(right\)[\s\S]*sourceFilterValuesEqual\(left: SourceMangaListFilters, right: SourceMangaListFilters\)[\s\S]*Object\.keys\(left\)\.sort\(\)[\s\S]*Object\.keys\(right\)\.sort\(\)/,
  'BrowseViewModel must distinguish changed search filters from source-provided default values',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8'),
  /configureSourceSettingsStore\(context\)[\s\S]*configureSourceFilterPreferencesStore\(context\)[\s\S]*bootstrapSourceRuntimeAppRegistry\(context\)/,
  'Index must configure source filter preferences before source runtime bootstrap',
)
assert.match(
  sourceSearchPageSource,
  /SourceFilterControls\(\{[\s\S]*filters: this\.viewModel\.filters,[\s\S]*values: this\.viewModel\.searchFilterValues/,
  'SourceSearchPage must render source filters from search-specific values instead of browse state',
)
assert.match(
  browseViewModelSource,
  /clearSearch\(source\?: SourceRuntimeRegistryInstalledSourceSummary\): void \{[\s\S]*this\.searchQuery = ''[\s\S]*this\.searchResults = \[\][\s\S]*this\.hasMoreSearch = false[\s\S]*this\.loadingSearch = false[\s\S]*this\.errorMessage = ''[\s\S]*this\.searchNextCursor = ''/,
  'BrowseViewModel must expose an immediate clear path so blank source searches cannot leave stale results visible',
)
assert.match(
  browseViewModelSource,
  /ensureSearchFilters\(source: SourceRuntimeRegistryInstalledSourceSummary\): Promise<void> \{[\s\S]*const sourceChanged = this\.selectedSource === undefined \|\| this\.selectedSource\.sourceId !== source\.sourceId[\s\S]*if \(sourceChanged\) \{[\s\S]*this\.clearSearch\(source\)[\s\S]*this\.filters = \[\][\s\S]*this\.searchFilterValues = \{\}/,
  'BrowseViewModel must clear stale source search results when the search page switches to another source',
)
assert.match(
  browseViewModelSource,
  /private searchRequestId: number = 0[\s\S]*runSearch\(source: SourceRuntimeRegistryInstalledSourceSummary, query: string\): Promise<void> \{[\s\S]*const requestId = this\.searchRequestId \+ 1[\s\S]*this\.searchRequestId = requestId[\s\S]*await this\.searchSource\(source, normalizedQuery, 1\)[\s\S]*requestId !== this\.searchRequestId[\s\S]*catch \(error\)[\s\S]*requestId !== this\.searchRequestId[\s\S]*finally[\s\S]*requestId === this\.searchRequestId[\s\S]*clearSearch\(source\?: SourceRuntimeRegistryInstalledSourceSummary\): void \{[\s\S]*this\.searchRequestId \+= 1/,
  'BrowseViewModel must ignore stale source search completions after newer searches or immediate clear',
)
assert.match(
  browseViewModelSource,
  /private browseRequestId: number = 0[\s\S]*setSelectedSource\(source: SourceRuntimeRegistryInstalledSourceSummary\): void \{[\s\S]*this\.browseRequestId \+= 1[\s\S]*loadBrowseHome\(source: SourceRuntimeRegistryInstalledSourceSummary\): Promise<void> \{[\s\S]*const requestId = this\.browseRequestId[\s\S]*await this\.loadSourceListings\(source\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*await this\.loadSourceFilters\(source\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*await this\.loadSourceHomeSections\(source\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*loadBrowseListing\(source, listing, 1, requestId\)[\s\S]*finally[\s\S]*requestId === this\.browseRequestId/,
  'BrowseViewModel must ignore stale source home/listing completions after switching sources',
)
assert.match(
  browseViewModelSource,
  /selectBrowseListing\(listing: SourceListingDescriptor\): Promise<void> \{[\s\S]*const requestId = this\.browseRequestId \+ 1[\s\S]*this\.browseRequestId = requestId[\s\S]*loadBrowseListing\(this\.selectedSource, listing, 1, requestId\)[\s\S]*if \(!loaded\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*finally[\s\S]*requestId === this\.browseRequestId[\s\S]*loadBrowseListing\([\s\S]*requestId: number = this\.browseRequestId[\s\S]*await this\.loadMangaListing\(source, listing\.id, page\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*return false/,
  'BrowseViewModel must guard stale manual listing selection writes through the shared listing loader',
)
assert.match(
  browseViewModelSource,
  /loadMoreBrowse\(\): Promise<void> \{[\s\S]*const requestId = this\.browseRequestId[\s\S]*const source = this\.selectedSource[\s\S]*const page = this\.browsePage \+ 1[\s\S]*const cursor = this\.browseNextCursor[\s\S]*await this\.loadMangaListing\(source, listing\.id, page, cursor\)[\s\S]*requestId !== this\.browseRequestId[\s\S]*this\.browsePage = page[\s\S]*finally[\s\S]*requestId === this\.browseRequestId/,
  'BrowseViewModel must not append stale browse pagination after source/listing changes',
)
assert.match(
  browseViewModelSource,
  /loadMoreSearch\(\): Promise<void> \{[\s\S]*const requestId = this\.searchRequestId[\s\S]*const source = this\.selectedSource[\s\S]*const query = this\.searchQuery\.trim\(\)[\s\S]*const page = this\.searchPage \+ 1[\s\S]*const cursor = this\.searchNextCursor[\s\S]*await this\.searchSource\(source, query, page, cursor\)[\s\S]*requestId !== this\.searchRequestId[\s\S]*this\.searchPage = page[\s\S]*finally[\s\S]*requestId === this\.searchRequestId/,
  'BrowseViewModel must not append stale search pagination after newer searches or clear',
)
assert.match(
  sourceSearchPageSource,
  /clearPendingSearchTimer\(\): void \{[\s\S]*clearTimeout\(this\.searchTimer\)[\s\S]*scheduleSearch\(value: string\): void \{[\s\S]*this\.clearPendingSearchTimer\(\)[\s\S]*if \(value\.trim\(\)\.length === 0\) \{[\s\S]*this\.viewModel\.clearSearch\(this\.source\)[\s\S]*return[\s\S]*setTimeout/,
  'SourceSearchPage must clear source search results immediately when the query becomes blank instead of waiting for debounce',
)
assert.match(
  sourceSearchPageSource,
  /submitSearch\(value: string\): void \{[\s\S]*this\.query = value[\s\S]*this\.clearPendingSearchTimer\(\)[\s\S]*if \(value\.trim\(\)\.length === 0\) \{[\s\S]*this\.viewModel\.clearSearch\(this\.source\)[\s\S]*return[\s\S]*this\.viewModel\.runSearch\(this\.source, value\)/,
  'SourceSearchPage must run submitted source searches immediately instead of waiting for the debounce timer',
)
assert.match(
  sourceSearchPageSource,
  /\.onSubmit\(\(value: string\) => \{[\s\S]*this\.submitSearch\(value\)/,
  'SourceSearchPage submit handler must use the immediate search path',
)
assert.match(
  sourceModelsSource,
  /type: 'select' \| 'text' \| 'check' \| 'sort' \| 'multiselect' \| 'range' \| 'group'[\s\S]*value\?: string \| number \| boolean \| string\[\][\s\S]*minValue\?: number[\s\S]*maxValue\?: number[\s\S]*step\?: number[\s\S]*filters\?: SourceRuntimeFilterPayload\[\][\s\S]*items\?: SourceRuntimeFilterPayload\[\][\s\S]*value === 'multiselect' \|\| value === 'multi-select' \|\| value === 'multiSelect'[\s\S]*appendSourceFilters\(filters, payload\.filters \?\? \(payload\.items \?\? \[\]\)\)[\s\S]*if \(type === 'group'\)[\s\S]*appendSourceFilters\(target, row\.filters \?\? \[\]\)[\s\S]*minValue: optionalNumber\(row\.min\)[\s\S]*maxValue: optionalNumber\(row\.max\)[\s\S]*step: optionalNumber\(row\.step\)/,
  'SourceModels must parse source multi-select and range filter descriptors and values',
)
assert.match(
  browseViewModelSource,
  /type SourceFilterValue = string \| number \| boolean \| string\[\][\s\S]*Array\.isArray\(value\)[\s\S]*normalized\.push\(next\)[\s\S]*return normalized[\s\S]*normalizeFilterStringRequestValue/,
  'BrowseViewModel must preserve multi-select source filters as normalized string arrays in runtime requests',
)
assert.match(
  sourceFilterControlsSource,
  /export type SourceFilterControlValue = string \| number \| boolean \| string\[\][\s\S]*filter\.type === 'multiselect'[\s\S]*toggleMultiSelectFilter\(filter, index\)[\s\S]*bindMenu\(this\.activeFilterMenuId === filter\.id, this\.FilterOptionMenu\(filter\)/,
  'SourceFilterControls must expose source-defined filters with single-select and multi-select menu controls',
)
assert.match(
  sourceFilterControlsSource,
  /rangeMin\(filter: SourceFilter\)[\s\S]*rangeMax\(filter: SourceFilter\)[\s\S]*setRangeFilter\(filter: SourceFilter, value: number\)[\s\S]*filter\.type === 'range'[\s\S]*Slider\(\{[\s\S]*this\.setRangeFilter\(filter, value\)/,
  'SourceFilterControls must expose source-defined range filters with a slider control',
)
assert.match(
  sourceFilterControlsSource,
  /filter\.type === 'check'[\s\S]*Toggle\(\{ type: ToggleType\.Switch[\s\S]*filter\.type === 'text'[\s\S]*TextInput\(/,
  'SourceFilterControls must keep switch and text controls for boolean and text source filters',
)
assert.match(
  sourceSearchPageSource,
  /resetSearchFilters\(\): void \{[\s\S]*this\.viewModel\.resetSearchFilters\(\)[\s\S]*this\.rerunSearchIfReady\(\)[\s\S]*SourceFilterControls\(\{[\s\S]*filters: this\.viewModel\.filters[\s\S]*values: this\.viewModel\.searchFilterValues[\s\S]*busy: this\.viewModel\.loadingSearch[\s\S]*onFilterChange:[\s\S]*this\.setSearchFilterValue\(filter, value\)[\s\S]*onReset:[\s\S]*this\.resetSearchFilters\(\)[\s\S]*aboutToAppear\(\): void \{[\s\S]*this\.viewModel\.ensureSearchFilters\(this\.source\)/,
  'SourceSearchPage must rerun the current search when a source filter changes or resets',
)
assert.match(
  sourceSearchPageSource,
  /hasActiveSearchFilters\(\): boolean \{[\s\S]*this\.viewModel\.hasSearchFilterChanges\(\)[\s\S]*isFilteredEmptySearch\(\): boolean \{[\s\S]*this\.query\.trim\(\)\.length > 0 && this\.hasActiveSearchFilters\(\)[\s\S]*resetSearchFilters\(\): void \{[\s\S]*this\.viewModel\.resetSearchFilters\(\)[\s\S]*this\.rerunSearchIfReady\(\)[\s\S]*emptySearchTitle\(\): string \{[\s\S]*source_search_filtered_empty_title[\s\S]*emptySearchMessage\(\): string \{[\s\S]*source_search_filtered_empty_message[\s\S]*EmptySearch\(\)[\s\S]*actionLabel: s\('common_reset'\)[\s\S]*showAction: this\.isFilteredEmptySearch\(\)[\s\S]*this\.resetSearchFilters\(\)/,
  'SourceSearchPage filtered-empty search state must explain active filters and expose a reset action',
)
assert.match(
  sourceSearchPageSource,
  /if \(this\.viewModel\.hasMoreSearch\) \{[\s\S]*label: this\.viewModel\.loadingSearch \? s\('common_loading_more'\) : s\('common_load_more'\)[\s\S]*isEnabled: !this\.viewModel\.loadingSearch[\s\S]*this\.viewModel\.loadMoreSearch\(\)/,
  'SourceSearchPage load-more action must expose a busy label and disable repeat taps while loading',
)
assert.match(
  browseViewModelSource,
  /selectBrowseListing\(listing: SourceListingDescriptor\)[\s\S]*const requestId = this\.browseRequestId \+ 1[\s\S]*loadBrowseListing\(this\.selectedSource, listing, 1, requestId\)/,
  'BrowseViewModel must expose listing selection for SourceBrowsePage',
)
assert.match(
  browseViewModelSource,
  /resetBrowseFilters\(\): Promise<void> \{[\s\S]*this\.browseFilterValues = this\.defaultSourceFilterValues\(this\.filters\)[\s\S]*const listing = this\.currentListing\(\)[\s\S]*await this\.selectBrowseListing\(listing\)/,
  'BrowseViewModel must let users restore source-defined default filters and reload the current listing',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets'), 'utf8'),
  /ListingSelector\(\)[\s\S]*ForEach\(this\.viewModel\.listings[\s\S]*selectBrowseListing\(listing\)[\s\S]*RuntimeFilterControls\(\)[\s\S]*SourceFilterControls\(\{[\s\S]*onFilterChange:[\s\S]*this\.setBrowseFilterValue\(filter, value\)[\s\S]*onReset:[\s\S]*resetBrowseFilters\(\)[\s\S]*EmptyBrowseResults\(\)[\s\S]*source_browse_empty_results_title[\s\S]*resetBrowseFilters\(\)[\s\S]*ForEach\(this\.viewModel\.homeSections[\s\S]*ForEach\(this\.viewModel\.browseSections/,
  'SourceBrowsePage must render source-defined listing selectors, empty state, home sections, and browse sections',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets'), 'utf8'),
  /shouldLoadBrowseOnAppear\(\): boolean[\s\S]*selectedSource\?\.sourceId !== this\.source\.sourceId[\s\S]*!this\.hasBrowseContent\(\)[\s\S]*reloadBrowse\(\): void[\s\S]*this\.viewModel\.loadBrowseHome\(this\.source\)[\s\S]*aboutToAppear\(\): void \{[\s\S]*this\.shouldLoadBrowseOnAppear\(\)[\s\S]*this\.reloadBrowse\(\)/,
  'SourceBrowsePage must preserve loaded browse state on return and only reload when the current source has no loaded state',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/SourceBrowsePage.ets'), 'utf8'),
  /retryBrowseError\(\): void \{[\s\S]*this\.hasBrowseContent\(\)[\s\S]*this\.viewModel\.loadMoreBrowse\(\)[\s\S]*this\.reloadBrowse\(\)[\s\S]*BrowseErrorState\(\)[\s\S]*common_retry[\s\S]*this\.retryBrowseError\(\)[\s\S]*KomaIconButton\(\{[\s\S]*sys\.symbol\.arrow_clockwise[\s\S]*isEnabled: !this\.viewModel\.loadingBrowse[\s\S]*this\.reloadBrowse\(\)/,
  'SourceBrowsePage must expose explicit refresh and content-aware retry controls for source browse failures',
)
assert.match(
  sourceBrowsePageSource,
  /retryBrowseError\(\): void \{[\s\S]*this\.hasBrowseContent\(\)[\s\S]*this\.viewModel\.loadMoreBrowse\(\)[\s\S]*this\.reloadBrowse\(\)[\s\S]*BrowseErrorState\(\)[\s\S]*browse_error_load_more[\s\S]*common_retry[\s\S]*this\.retryBrowseError\(\)[\s\S]*this\.viewModel\.errorMessage\.length > 0 && !this\.hasBrowseContent\(\)[\s\S]*this\.BrowseErrorState\(\)[\s\S]*this\.viewModel\.errorMessage\.length > 0[\s\S]*this\.BrowseErrorState\(\)[\s\S]*else if \(this\.viewModel\.hasMoreBrowse\)/,
  'SourceBrowsePage must keep existing browse content visible and expose retry when pagination fails',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/SourceSearchPage.ets'), 'utf8'),
  /bottomContentInset\(\): number \{[\s\S]*this\.safeArea\.bottomAvoidHeight \+ ThemeConstants\.FLOAT_BAR_HEIGHT[\s\S]*bottomFloatingTabViewportClearance\(\): number \{[\s\S]*return this\.bottomContentInset\(\)[\s\S]*Scroll\(\)[\s\S]*\.padding\(\{\s*bottom:\s*this\.bottomFloatingTabViewportClearance\(\)\s*\}\)[\s\S]*\.clipContent\(ContentClipMode\.CONTENT_ONLY\)/,
  'SourceSearchPage must reserve bottom viewport clearance so source search results and load-more controls are not hidden behind floating tab chrome',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/SourceSearchPage.ets'), 'utf8'),
  /retrySearch\(\): void \{[\s\S]*clearPendingSearchTimer\(\)[\s\S]*query\.trim\(\)\.length === 0[\s\S]*this\.viewModel\.runSearch\(this\.source, this\.query\)[\s\S]*SearchErrorState\(\)[\s\S]*source_search_error_title[\s\S]*common_retry[\s\S]*this\.retrySearch\(\)[\s\S]*errorMessage\.length > 0 && this\.viewModel\.searchResults\.length === 0[\s\S]*this\.SearchErrorState\(\)[\s\S]*this\.ResultsGrid\(this\.viewModel\.searchResults\)[\s\S]*errorMessage\.length > 0[\s\S]*this\.SearchErrorState\(\)/,
  'SourceSearchPage must expose retry for failed searches and keep existing results visible when later pagination fails',
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
  /KomaEmptyState\(\{[\s\S]*title: s\('browse_empty_title'\)[\s\S]*message: s\('browse_empty_message'\)[\s\S]*actionLabel: s\('browse_empty_action_manage_sources'\)[\s\S]*this\.onOpenSourcePackageManager\(\)/,
  'empty Browse source inventory must offer a real route into source package management',
)
assert.match(
  readFileSync(resolve(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8'),
  /BrowsePage\(\{[\s\S]*onOpenSourcePackageManager:\s*\(\) => \{[\s\S]*this\.openSettingsSecondary\(RouteName\.SOURCE_PACKAGE_MANAGER\)/,
  'Browse empty source action must route to the existing SourcePackageManagerPage',
)
assert.match(smokeSource, /local_source_runtime_fixture\.koma/, 'device smoke must cover a .koma source archive')
assert.match(abiDocSource, /`\.koma`、`\.koma-source`、`\.koma-source\.zip` 和 `\.zip`/, 'source ABI docs must document supported import suffixes')

const indexServicePath = resolve(root, 'entry/src/main/ets/sourceRuntime/SourceIndexService.ets')
const indexServiceSource = readFileSync(indexServicePath, 'utf8')

assert.match(indexServiceSource, /isValidHttpUrl/, 'SourceIndexService must validate URLs')
assert.match(indexServiceSource, /safeResolvePkgUrl/, 'SourceIndexService must resolve relative pkg URLs against index URL')
assert.match(indexServiceSource, /authorityStart/, 'SourceIndexService must handle bare-domain index URLs without replacing host during pkg resolution')
assert.match(indexServiceSource, /firstPathSlash < 0/, 'SourceIndexService must resolve bare-domain index URL pkg paths under the same host root')
assert.match(indexServiceSource, /installFromBytes/, 'SourceIndexService must delegate install to app registry installFromBytes')
assert.match(indexServiceSource, /parseIndexEntry/, 'SourceIndexService must parse index entries safely')
assert.match(
  indexServiceSource,
  /isMinAppVersionSatisfied\(entry\.minAppVersion\)[\s\S]*reasonCode: 'app_version_unsupported'[\s\S]*const pkgUrl = safeResolvePkgUrl/,
  'SourceIndexService must reject source index entries whose minAppVersion is newer before downloading the package',
)
assert.match(
  indexServiceSource,
  /importLocalSourceArchive|installFromBytes/,
  'SourceIndexService must not bypass archive validation',
)
assert.doesNotMatch(
  indexServiceSource,
  /http:\/\/localhost|http:\/\/127\.0\.0\.1/,
  'SourceIndexService must not include any default or hardcoded source index URL',
)
assert.doesNotMatch(
  managerPageSource,
  /https?:\/\/[^/\s]+\/source-index|https?:\/\/[^/\s]+\/index\.json/,
  'SourcePackageManagerPage must not include any default source index URL',
)
assert.match(managerPageSource, /source_pkg_load_sources/, 'SourcePackageManagerPage must provide load sources action')
assert.match(managerPageSource, /source_pkg_local_import/, 'SourcePackageManagerPage must keep local import as secondary fallback')
assert.match(managerPageSource, /source_pkg_index_url_heading/, 'SourcePackageManagerPage must surface source index URL input')
assert.match(managerPageSource, /label: t\('source_pkg_index_url_label'\)[\s\S]*placeholder: t\('source_pkg_index_url_placeholder'\)/, 'SourcePackageManagerPage source index URL field must use i18n label and placeholder')
assert.match(
  managerPageSource,
  /SourceIndexService/,
  'SourcePackageManagerPage must import SourceIndexService',
)
assert.match(
  managerPageSource,
  /installIndexEntry/,
  'SourcePackageManagerPage must wire install from index entry',
)
assert.match(
  managerPageSource,
  /source_pkg_empty_message/,
  'empty state must mention source index URL first, local package import second',
)
assert.match(
  managerPageSource,
  /type SourcePackageUpdateState = 'unknown' \| 'checking' \| 'latest' \| 'update' \| 'missing' \| 'failed'/,
  'SourcePackageManagerPage must model unknown/checking/latest/update/missing/failed update states',
)
assert.match(
  managerPageSource,
  /checkInstalledUpdates\(\): Promise<void>[\s\S]*this\.sourceIndexService\.fetchIndex\(url\)[\s\S]*status: 'missing'[\s\S]*status: 'update'[\s\S]*status: 'latest'/,
  'installed update refresh must derive missing/update/latest from the configured source index',
)
assert.match(
  managerPageSource,
  /updateInstalledPackage\(source: InstalledSourcePackage\): Promise<void>[\s\S]*this\.sourceIndexService\.installPackage\(url, entry\)[\s\S]*setEnabled\(this\.context\(\), source\.id, false\)/,
  'selected source update must reuse SourceIndexService install validation and preserve disabled state',
)
assert.match(
  managerPageSource,
  /capabilityLabel\(capability: string\)[\s\S]*source_pkg_capability_host_imports[\s\S]*source_pkg_capability_search[\s\S]*source_pkg_capability_detail[\s\S]*source_pkg_capability_chapters[\s\S]*source_pkg_capability_pages[\s\S]*source_pkg_capability_home[\s\S]*source_pkg_capability_filters[\s\S]*source_pkg_capability_settings[\s\S]*source_pkg_capability_image_request/,
  'source capability UI must translate runtime capability tokens into user-facing labels including browse, settings, and image-request features',
)
assert.match(
  sourcePackageTrustPolicySource,
  /installedSourceTrustSummary[\s\S]*source_pkg_provenance_imported[\s\S]*source_pkg_verification_unsigned[\s\S]*source_pkg_label_package_id[\s\S]*source_pkg_label_version[\s\S]*source_pkg_capability_summary_prefix/,
  'installed source trust policy must use honest user-imported, unverified, id/version, and manifest-derived capability labels',
)
assert.match(
  sourcePackageTrustPolicySource,
  /sourceIndexCandidateTrustSummary[\s\S]*source_pkg_provenance_index_update[\s\S]*source_pkg_provenance_index[\s\S]*source_pkg_verification_unsigned[\s\S]*source_pkg_capability_summary_pending/,
  'source index update candidates must be labeled as unverified user-configured index candidates until manifest validation',
)
assert.match(
  sourcePackageTrustPolicySource,
  /source_pkg_boundary_notice/,
  'source trust policy must warn that Koma has no default public source list',
)
assert.match(
  managerPageSource,
  /sourcePackageTrustBoundaryNotice[\s\S]*RemoteIndexCard\(entry: SourceIndexEntry\)[\s\S]*sourceIndexTrustMetaText\(entry\)[\s\S]*sourceIndexTrustCapabilityText\(entry\)[\s\S]*PackageCard\(source: InstalledSourcePackage\)[\s\S]*installedTrustMetaText\(source\)[\s\S]*installedTrustCapabilityText\(source\)/,
  'source package manager must render trust metadata for update/index candidates and installed packages',
)
assert.doesNotMatch(
  sourcePackageTrustPolicySource + managerPageSource,
  /官方源|已认证|已验证签名|安全源|可信源|verified signature/i,
  'source trust UI must not claim official/certified/safe/verified status without real verification',
)
assert.doesNotMatch(
  sourcePackageTrustPolicySource,
  /verifySignature|signatureVerified|realVerification|isSignatureValid|cryptoFramework|publicKey|certificate/i,
  'source trust policy must not introduce fake cryptographic signature verification',
)
assert.match(
  sourceRuntimeRegistrySource,
  /capabilities\?: string\[\][\s\S]*normalizedCapabilityList[\s\S]*capabilities: normalizedCapabilityList\(input\.capabilities, input\.manifest\)[\s\S]*capabilities: entry\.capabilities/,
  'source registry must preserve sanitized capability summaries through persistence reload',
)
assert.match(
  sourceRuntimeRegistrySource,
  /displayCapabilityTokenAllowed\(token: string\)[\s\S]*normalizeSourceOperationCapabilityToken\(token\) === token[\s\S]*token === 'network'[\s\S]*token\.startsWith\('hostImports:'\)/,
  'source registry capability display tokens must be bounded by an explicit allowlist',
)
assert.match(
  sourceRuntimeRegistrySource,
  /const manifestCapabilities = capabilitiesFromManifest\(manifest\)[\s\S]*displayCapabilityTokenAllowed\(trimmed\)[\s\S]*manifestCapabilities\.indexOf\(trimmed\) >= 0[\s\S]*return capabilities\.length > 0 \? capabilities : manifestCapabilities/,
  'persisted capability summaries must be intersected with manifest-derived capabilities',
)
assert.match(
  sourceRuntimeRegistrySource,
  /reloadFromAppLocalMetadata[\s\S]*manifest: manifestForReload\(entry\)[\s\S]*capabilities: entry\.capabilities/,
  'metadata reload may pass persisted capabilities only through manifest-bound registry sanitization',
)
{
  const manifestDerivedCapabilities = ['search', 'detail', 'chapters', 'pages', 'home', 'settings']
  const tamperedPersistedCapabilities = ['search', ' network ', 'home', 'settings', 'hostImports:2', 'sourceSecrets', '']
  const allowedDisplayCapability = (token) => (
    ['sourceInfo', 'search', 'detail', 'chapters', 'pages', 'listings', 'mangaList', 'home', 'filters', 'settings', 'imageRequest'].includes(token) ||
    token === 'network' ||
    token.startsWith('hostImports:')
  )
  const sanitizedCapabilities = tamperedPersistedCapabilities
    .map((item) => item.trim())
    .filter((item, index, list) => (
      allowedDisplayCapability(item) &&
      manifestDerivedCapabilities.includes(item) &&
      list.indexOf(item) === index
    ))
  assert.deepEqual(
    sanitizedCapabilities,
    ['search', 'home', 'settings'],
    'tampered persisted capabilities must drop unknown, network, and hostImports while preserving manifest-granted operation capabilities',
  )
}

assert.match(
  backupServiceSource,
  /sourceIndexUrl/,
  'backup schema v3 must export/import source index URL',
)

for (const marker of [
  'Manifest shape',
  'Runtime request envelope',
  'Settings descriptor rules',
  'capabilities.operations',
  'Package archive layout',
  'Compatibility notes',
  'No built-in source market',
]) {
  assert.match(sdkDocSource, new RegExp(marker), `source package SDK doc must include ${marker}`)
}

assertSourceRepoShape(localKomaFixturePath)

for (const sourcePackage of externalSourcePackages) {
  if (existsSync(sourcePackage)) {
    assertSourceRepoShape(sourcePackage)
  }
}

console.log('source package .koma compatibility checks PASS')
