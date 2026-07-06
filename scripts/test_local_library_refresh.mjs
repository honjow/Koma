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
assertExport(serviceSource, 'formatLocalLibraryRefreshDetail')
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
  /export interface LocalLibraryRefreshSummary \{[\s\S]*archiveCount: number[\s\S]*folderCount: number[\s\S]*chapterCount: number[\s\S]*pageCount: number[\s\S]*missingPageCount: number[\s\S]*reselectRequiredCount: number[\s\S]*unchangedCount: number/,
  'local refresh summary must split archive/folder counts and include bounded chapter/page totals',
)
assert.match(
  serviceSource,
  /function localFilePathFromUri\(uri: string\): string \| undefined \{[\s\S]*uri\.startsWith\('file:\/\/'\)[\s\S]*decodeURIComponent\(uri\.substring\('file:\/\/'\.length\)\)[\s\S]*function localPathExists\(path: string\): boolean \{[\s\S]*fs\.accessSync\(path\)[\s\S]*catch[\s\S]*return false[\s\S]*function countMissingLocalFolderPages\(comic: Comic\): number \{[\s\S]*comic\.pageCount <= 0[\s\S]*missingPageCount \+= 1[\s\S]*return missingPageCount[\s\S]*function localRefreshStatus\(comic: Comic, missingPageCount: number\): LocalLibraryRefreshResultStatus \{[\s\S]*comic\.sourceKind !== ComicSourceKind\.LOCAL_FOLDER[\s\S]*comic\.pageCount > 0 && missingPageCount === 0 \? 'unchanged' : 'reselect_required'[\s\S]*missingPageCount: results\.reduce\(\(total: number, result: LocalLibraryRefreshComicResult\): number => total \+ result\.missingPageCount, 0\)[\s\S]*const missingPageCount = comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER \? countMissingLocalFolderPages\(comic\) : 0[\s\S]*const status = localRefreshStatus\(comic, missingPageCount\)[\s\S]*missingPageCount,[\s\S]*localRefreshMessage\(comic, status, missingPageCount\)/,
  'local refresh must count missing app-readable local folder pages before requiring reselect while treating archive imports as unchanged',
)
assert.match(
  serviceSource,
  /checkLocalComicRefresh\(comic: Comic\): LocalLibraryRefreshComicResult[\s\S]*!isLocalRefreshCandidate\(comic\)[\s\S]*status: 'skipped'[\s\S]*return this\.checkLocalComic\(comic\)/,
  'local refresh must expose a single-comic check for detail-page actions without widening refresh scope',
)
assert.match(
  serviceSource,
  /AppStrings\.get\('local_library_refresh_archive_retained'\)[\s\S]*AppStrings\.get\('local_library_refresh_folder_cached_available'\)[\s\S]*local_library_refresh_folder_missing_pages_detail[\s\S]*AppStrings\.get\('local_library_refresh_folder_reselect_detail'\)/,
  'local refresh must explain cached folder availability, missing pages, folder reselect, and retained archive behavior through i18n strings',
)
assert.match(
  serviceSource,
  /formatLocalLibraryRefreshSummary\(summary\?: LocalLibraryRefreshSummary\): string[\s\S]*local_library_refresh_reselect_required_detail[\s\S]*summary\.reselectRequiredCount[\s\S]*summary\.archiveCount[\s\S]*local_library_refresh_clean_detail[\s\S]*summary\.archiveCount[\s\S]*formatLocalLibraryRefreshDetail\(summary: LocalLibraryRefreshSummary\): string[\s\S]*local_library_refresh_detail_empty[\s\S]*local_library_refresh_detail_reselect[\s\S]*local_library_refresh_detail_clean[\s\S]*summary\.chapterCount[\s\S]*summary\.pageCount[\s\S]*summary\.missingPageCount/,
  'local refresh summary text must expose actionable folder reselect counts, missing page counts, and retained archive counts',
)
assert.doesNotMatch(
  serviceSource,
  /unlink|rmdir|remove|delete|TRUNC|clearReaderRemoteImageCache|cacheDir/,
  'local refresh must not delete files, mutate external storage, or clear caches',
)
assert.doesNotMatch(
  serviceSource,
  /console\.(info|warn|error)\([^)]*(sourcePath|coverUri|uri|localPath|page\.uri)/,
  'local refresh logs must not expose paths or page URIs',
)
assert.doesNotMatch(
  serviceSource,
  /message:\s*(comic\.sourcePath|page\.uri|localPath)/,
  'local refresh status messages must not expose paths or page URIs',
)

function filePathFromUri(uri) {
  if (!uri.startsWith('file://')) return undefined
  try {
    const path = decodeURIComponent(uri.substring('file://'.length))
    return path.trim().length === 0 ? undefined : path
  } catch {
    return undefined
  }
}

function folderStatus(comic, existingPaths) {
  if (comic.sourceKind !== 'local_folder') return 'unchanged'
  if (comic.pageCount <= 0) return 'reselect_required'
  for (const chapter of comic.chapters) {
    for (const page of chapter.pages) {
      const localPath = filePathFromUri(page.uri)
      if (localPath === undefined || !existingPaths.has(localPath)) {
        return 'reselect_required'
      }
    }
  }
  return 'unchanged'
}

function missingFolderPages(comic, existingPaths) {
  if (comic.sourceKind !== 'local_folder' || comic.pageCount <= 0) return 0
  let missing = 0
  for (const chapter of comic.chapters) {
    for (const page of chapter.pages) {
      const localPath = filePathFromUri(page.uri)
      if (localPath === undefined || !existingPaths.has(localPath)) {
        missing += 1
      }
    }
  }
  return missing
}

const folderComic = {
  sourceKind: 'local_folder',
  pageCount: 2,
  chapters: [{ pages: [
    { uri: 'file:///data/storage/el2/base/haps/entry/cache/import/Page%201.jpg' },
    { uri: 'file:///data/storage/el2/base/haps/entry/cache/import/Page%202.jpg' },
  ] }],
}
assert.equal(folderStatus(folderComic, new Set([
  '/data/storage/el2/base/haps/entry/cache/import/Page 1.jpg',
  '/data/storage/el2/base/haps/entry/cache/import/Page 2.jpg',
])), 'unchanged', 'cached local folder imports with all pages present must stay clean')
assert.equal(folderStatus(folderComic, new Set([
  '/data/storage/el2/base/haps/entry/cache/import/Page 1.jpg',
])), 'reselect_required', 'cached local folder imports with missing pages must ask for reselect')
assert.equal(missingFolderPages(folderComic, new Set([
  '/data/storage/el2/base/haps/entry/cache/import/Page 1.jpg',
])), 1, 'cached local folder refresh must report how many saved pages are missing')
assert.equal(folderStatus({
  sourceKind: 'local_folder',
  pageCount: 1,
  chapters: [{ pages: [{ uri: 'content://picked/folder/page.jpg' }] }],
}, new Set()), 'reselect_required', 'non-file folder imports still require reselect')
assert.equal(missingFolderPages({
  sourceKind: 'local_folder',
  pageCount: 1,
  chapters: [{ pages: [{ uri: 'content://picked/folder/page.jpg' }] }],
}, new Set()), 1, 'non-file folder refresh must count unreadable page URIs as missing pages')
assert.equal(folderStatus({
  sourceKind: 'local_archive',
  pageCount: 0,
  chapters: [],
}, new Set()), 'unchanged', 'archive imports remain retained and unchanged')

assert.match(
  settingsSource,
  /import \{[\s\S]*LocalLibraryRefreshService[\s\S]*LocalLibraryRefreshSummary[\s\S]*formatLocalLibraryRefreshDetail[\s\S]*formatLocalLibraryRefreshSummary[\s\S]*\} from '..\/model\/LocalLibraryRefreshService'/,
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
  /summary\.reselectRequiredCount > 0[\s\S]*this\.showToast\(s\('settings_local_library_refresh_reselect'\)\)[\s\S]*this\.showLocalLibraryRefreshResult\(summary\)[\s\S]*showLocalLibraryRefreshResult\(summary: LocalLibraryRefreshSummary\): void[\s\S]*formatLocalLibraryRefreshDetail\(summary\)[\s\S]*showAlertDialog\([\s\S]*primaryButton:[\s\S]*value: s\('route_import_title'\)[\s\S]*this\.onOpenImportRequested\(\)/,
  'SettingsPage local refresh must show a bounded result dialog and route users to the import flow when reselect is required',
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
  /import \{[\s\S]*LocalLibraryRefreshComicResult[\s\S]*LocalLibraryRefreshService[\s\S]*\} from '\.\/LocalLibraryRefreshService'/,
  'LibraryUpdateService must reuse the local refresh model instead of duplicating local refresh status',
)
assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.LOCAL_ARCHIVE \|\| comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER[\s\S]*return this\.checkLocalLibraryComic\(comic, previousChapterCount\)/,
  'LibraryUpdateService must route local imports into the bounded local refresh check',
)
assert.match(
  libraryUpdateServiceSource,
  /checkLocalLibraryComic\(comic: Comic, previousChapterCount: number\): LibraryUpdateComicResult[\s\S]*new LocalLibraryRefreshService\(this\.libraryStore\)\.checkLocalComicRefresh\(comic\)[\s\S]*result\.status === 'unchanged'[\s\S]*status: 'unchanged'[\s\S]*return this\.skippedResult\(comic, previousChapterCount, result\.message\)/,
  'LibraryUpdateService must count retained local archives as unchanged while preserving folder reselect as skipped',
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
