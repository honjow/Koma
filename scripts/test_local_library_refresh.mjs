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
  /图片文件夹需要重新选择后才能刷新[\s\S]*本地压缩包需要重新选择后才能刷新/,
  'local refresh must explain that user re-selection is required',
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
  /\{ key: 'local-library-refresh', title: '刷新本地导入', detail: '需要重新选择本地文件' \}/,
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
  /刷新需要重新选择本地文件/,
  'SettingsPage must show honest user-facing reselect feedback',
)

assert.match(
  libraryUpdateServiceSource,
  /ComicSourceKind\.LOCAL_ARCHIVE \|\| comic\.sourceKind === ComicSourceKind\.LOCAL_FOLDER[\s\S]*本地导入暂不支持远程更新/,
  'existing remote/source update service must continue to skip local imports',
)
