import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const servicePath = resolve(root, 'entry/src/main/ets/model/LocalLibraryRefreshService.ets')
const settingsPath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const libraryUpdateServicePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')

const serviceSource = readFileSync(servicePath, 'utf8')
const settingsSource = readFileSync(settingsPath, 'utf8')
const libraryUpdateServiceSource = readFileSync(libraryUpdateServicePath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')
const indexSource = readFileSync(indexPath, 'utf8')

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
  /export interface LocalLibraryRefreshSummary \{[\s\S]*archiveCount: number[\s\S]*folderCount: number[\s\S]*reselectRequiredCount: number[\s\S]*unchangedCount: number/,
  'local refresh summary must split archive and folder counts instead of only exposing a generic total',
)
assert.match(
  serviceSource,
  /function localRefreshStatus\(sourceKind: ComicSourceKind\): LocalLibraryRefreshResultStatus \{[\s\S]*sourceKind === ComicSourceKind\.LOCAL_FOLDER \? 'reselect_required' : 'unchanged'[\s\S]*archiveCount: results\.filter\(\(result: LocalLibraryRefreshComicResult\): boolean => result\.sourceKind === ComicSourceKind\.LOCAL_ARCHIVE\)\.length[\s\S]*folderCount: results\.filter\(\(result: LocalLibraryRefreshComicResult\): boolean => result\.sourceKind === ComicSourceKind\.LOCAL_FOLDER\)\.length[\s\S]*status: localRefreshStatus\(comic\.sourceKind\)[\s\S]*localRefreshUnavailableMessage\(comic\.sourceKind\)/,
  'local refresh must require reselect only for folder handles while treating archive imports as unchanged',
)
assert.match(
  serviceSource,
  /checkLocalComicRefresh\(comic: Comic\): LocalLibraryRefreshComicResult[\s\S]*!isLocalRefreshCandidate\(comic\)[\s\S]*status: 'skipped'[\s\S]*return this\.checkLocalComic\(comic\)/,
  'local refresh must expose a single-comic check for detail-page actions without widening refresh scope',
)
assert.match(
  serviceSource,
  /AppStrings\.get\('local_library_refresh_folder_reselect_detail'\)[\s\S]*AppStrings\.get\('local_library_refresh_archive_retained'\)/,
  'local refresh must explain folder reselect and retained archive behavior through i18n strings',
)
assert.match(
  serviceSource,
  /formatLocalLibraryRefreshSummary\(summary\?: LocalLibraryRefreshSummary\): string[\s\S]*local_library_refresh_reselect_required_detail[\s\S]*summary\.reselectRequiredCount[\s\S]*summary\.archiveCount[\s\S]*local_library_refresh_clean_detail[\s\S]*summary\.archiveCount/,
  'local refresh summary text must expose actionable folder reselect counts and retained archive counts',
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
  /@Event onOpenImportRequested: \(\) => void = \(\) => \{\}/,
  'SettingsPage must expose a route callback for manual local folder reselect',
)
assert.match(
  settingsSource,
  /summary\.reselectRequiredCount > 0[\s\S]*this\.showToast\(s\('settings_local_library_refresh_reselect'\)\)[\s\S]*this\.onOpenImportRequested\(\)/,
  'SettingsPage local refresh must route users to the import flow when reselect is required',
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

assert.match(
  mangaDetailPageSource,
  /import \{[\s\S]*LocalLibraryRefreshComicResult[\s\S]*LocalLibraryRefreshService[\s\S]*\} from '..\/model\/LocalLibraryRefreshService'/,
  'MangaDetailPage must import the local refresh service for item-level checks',
)
assert.match(
  mangaDetailPageSource,
  /localRefreshBusy: boolean = false[\s\S]*localRefreshText: string = ''/,
  'MangaDetailPage must keep local refresh busy and visible result state',
)
assert.match(
  mangaDetailPageSource,
  /canCheckLocalLibraryRefresh\(\): boolean[\s\S]*ComicSourceKind\.LOCAL_ARCHIVE \|\| comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER/,
  'MangaDetailPage must only show local refresh for local archive/folder comics',
)
assert.match(
  mangaDetailPageSource,
  /new LocalLibraryRefreshService\(libraryStore\)\.checkLocalComicRefresh\(comic\)[\s\S]*step=detail_check status=\$\{result\.status\} chapters=\$\{result\.previousChapterCount\} pages=\$\{result\.previousPageCount\}/,
  'MangaDetailPage item-level refresh must use the service and log only bounded counts/status',
)
assert.doesNotMatch(
  mangaDetailPageSource,
  /step=detail_check[^\n]*(sourcePath|coverUri|uri|message|token|authorization)/i,
  'MangaDetailPage local refresh logs must not expose paths, URIs, raw messages, or secrets',
)
assert.match(
  mangaDetailPageSource,
  /manga_detail_menu_check_local_refresh[\s\S]*this\.checkLocalLibraryRefreshNow\(\)[\s\S]*this\.localRefreshText\.length > 0/,
  'MangaDetailPage must expose the local refresh menu item and render the result text',
)
assert.match(
  mangaDetailPageSource,
  /@Event onOpenImportRequested: \(\) => void = \(\) => \{\}/,
  'MangaDetailPage must expose a route callback for local folder reselect',
)
assert.match(
  mangaDetailPageSource,
  /result\.status === 'reselect_required'[\s\S]*this\.onOpenImportRequested\(\)/,
  'MangaDetailPage local refresh must route users to the import flow when reselect is required',
)

assert.match(
  indexSource,
  /onOpenImportRequested: \(\) => \{[\s\S]*this\.openImport\(\)[\s\S]*\}/,
  'Index must wire local refresh reselect callbacks to the existing import route',
)
