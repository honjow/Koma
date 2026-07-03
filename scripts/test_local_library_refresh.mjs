import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const servicePath = resolve(root, 'entry/src/main/ets/model/LocalLibraryRefreshService.ets')
const settingsPath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const libraryUpdateServicePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets')

const serviceSource = readFileSync(servicePath, 'utf8')
const settingsSource = readFileSync(settingsPath, 'utf8')
const libraryUpdateServiceSource = readFileSync(libraryUpdateServicePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(serviceSource, 'LocalLibraryRefreshResultStatus')
assertExport(serviceSource, 'LocalLibraryRefreshComicResult')
assertExport(serviceSource, 'LocalLibraryRefreshSummary')
assertExport(serviceSource, 'formatLocalLibraryRefreshSummary')
assertExport(serviceSource, 'LocalLibraryRefreshService')

assert.match(
  serviceSource,
  /comic\.sourceKind === ComicSourceKind\.LOCAL_ARCHIVE \|\| comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER/,
  'local refresh must only target local archive and local folder comics',
)
assert.match(
  serviceSource,
  /this\.libraryStore\.listComics\(\)\.filter\(\(comic: Comic\): boolean => isLocalRefreshCandidate\(comic\)\)/,
  'local refresh must filter the store before producing results',
)
assert.doesNotMatch(
  serviceSource,
  /sourceRuntimeId|SourceRuntimeRegistry|KOMGA_REMOTE|OPDS_REMOTE|WEBDAV_REMOTE|PRIVATE_LIBRARY/,
  'local refresh must not conflate local refresh with source-runtime or remote refresh paths',
)
assert.match(
  serviceSource,
  /status: 'reselect_required'[\s\S]*localRefreshUnavailableMessage\(comic\.sourceKind\)/,
  'local refresh must honestly report reselect_required while persistent folder/archive handles are unavailable',
)
assert.match(
  serviceSource,
  /AppStrings\.get\('local_library_refresh_folder_unavailable'\)[\s\S]*AppStrings\.get\('local_library_refresh_archive_unavailable'\)/,
  'local refresh must explain unavailable local refresh through i18n strings',
)
assert.doesNotMatch(
  serviceSource,
  /fileIo|fs\.|unlink|rmdir|remove|delete|TRUNC|clearReaderRemoteImageCache|cacheDir/,
  'local refresh must not delete files, mutate external storage, or clear caches',
)
assert.doesNotMatch(
  serviceSource,
  /sourcePath|coverUri|uri:/,
  'local refresh logs/status fields must not expose paths or page URIs',
)

assert.match(
  settingsSource,
  /import \{[\s\S]*LocalLibraryRefreshService[\s\S]*LocalLibraryRefreshSummary[\s\S]*formatLocalLibraryRefreshSummary[\s\S]*\} from '..\/model\/LocalLibraryRefreshService'/,
  'SettingsPage must import the local refresh model separately from library update',
)
assert.match(
  settingsSource,
  /\{ key: 'local-library-refresh', titleKey: 'settings_row_local_library_refresh_title', detailKey: 'settings_row_local_library_refresh_detail' \}/,
  'SettingsPage must expose a dedicated local import refresh row',
)
assert.match(
  settingsSource,
  /row\.key === 'local-library-refresh'[\s\S]*formatLocalLibraryRefreshSummary\(this\.localLibraryRefreshSummary\)/,
  'SettingsPage must render local refresh status from the local refresh summary',
)
assert.match(
  settingsSource,
  /new LocalLibraryRefreshService\(this\.libraryStore\)\.checkLocalLibraryRefresh\(\)/,
  'SettingsPage must trigger local refresh through the local-only service',
)
assert.match(
  settingsSource,
  /row\.key === 'local-library-refresh'[\s\S]*this\.checkLocalLibraryRefresh\(\)/,
  'SettingsPage row click must initiate the local refresh check',
)
assert.match(
  settingsSource,
  /settings_local_library_refresh_reselect/,
  'SettingsPage must show honest user-facing reselect feedback',
)
assert.match(
  settingsSource,
  /step=local_library_refresh_failed code='\s*\+\s*safeSettingsErrorCode\(e\)/,
  'SettingsPage local refresh failure logs must use a bounded error code',
)
assert.doesNotMatch(
  settingsSource,
  /step=local_library_refresh_failed message=/,
  'SettingsPage local refresh failure logs must not emit raw exception messages',
)

assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.LOCAL_ARCHIVE \|\| comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER[\s\S]*AppStrings\.get\('library_update_skip_local_unsupported'\)/,
  'existing remote/source update service must continue to skip local imports',
)
