import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const historyStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/SearchHistoryStore.ets'), 'utf8')
const stateMapperSource = readFileSync(resolve(root, 'entry/src/main/ets/model/SearchStateMapper.ets'), 'utf8')
const crossSearchSource = readFileSync(resolve(root, 'entry/src/main/ets/model/CrossSearchService.ets'), 'utf8')
const searchPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SearchPage.ets'), 'utf8')
const browseViewModelSource = readFileSync(resolve(root, 'entry/src/main/ets/viewmodel/BrowseViewModel.ets'), 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(historyStoreSource, 'SearchHistoryEntry')
assertExport(historyStoreSource, 'SearchHistoryRecord')
assertExport(historyStoreSource, 'SearchHistoryStore')
assertExport(historyStoreSource, 'SEARCH_HISTORY_STORE_NAME')
assertExport(historyStoreSource, 'SEARCH_HISTORY_QUERIES_KEY')
assertExport(historyStoreSource, 'MAX_SEARCH_HISTORY_COUNT')
assertExport(historyStoreSource, 'normalizeSearchHistoryEntries')
assertExport(historyStoreSource, 'addSearchHistoryEntry')
assert.match(historyStoreSource, /updatedAt:\s*number/, 'history entries must persist timestamps')
assert.match(historyStoreSource, /slice\(0,\s*MAX_SEARCH_HISTORY_COUNT\)/, 'history must be bounded')
assert.match(historyStoreSource, /toLocaleLowerCase\(\)[\s\S]*normalizedQuery\.toLocaleLowerCase\(\)/, 'history must dedupe repeated queries case-insensitively')
assert.match(historyStoreSource, /preferences\.getPreferences\(this\.context,\s*SEARCH_HISTORY_STORE_NAME\)/, 'history must use persistent preferences')
assert.match(historyStoreSource, /store\.put\(SEARCH_HISTORY_QUERIES_KEY,\s*JSON\.stringify/, 'history must serialize durable query records')

assertExport(stateMapperSource, 'CrossSearchSectionState')
assertExport(stateMapperSource, 'SearchDiagnostic')
assertExport(stateMapperSource, 'searchStateUserText')
assertExport(stateMapperSource, 'safeDiagnosticCode')
assertExport(stateMapperSource, 'safeSearchDiagnostic')
for (const state of ['pending', 'running', 'empty', 'timeout', 'failed', 'unsupported', 'ready']) {
  assert.match(stateMapperSource, new RegExp(`'${state}'`), `search state mapper must cover ${state}`)
}
assert.doesNotMatch(stateMapperSource, /error\.message\s*\}/, 'state mapper must not expose raw exception messages')
assert.match(stateMapperSource, /safeDiagnosticCode\(diagnosticCode\)/, 'failed UI text must include only a safe diagnostic code')

assert.match(crossSearchSource, /state:\s*CrossSearchSectionState/, 'cross-search sections must carry explicit state')
assert.match(crossSearchSource, /resultCount:\s*number/, 'cross-search sections must carry result count')
assert.match(crossSearchSource, /diagnosticCode:\s*string/, 'cross-search sections must carry safe diagnostic code')
assert.match(crossSearchSource, /pendingSections\(sourceFilter: CrossSearchSourceFilter = 'all'\): CrossSearchSection\[\]/, 'service must expose pending/running sections')
assert.match(crossSearchSource, /stateSection\('komga', AppStrings\.get\('route_komga_title'\), 'komga', 'unsupported', 'not_configured'\)/, 'unconfigured Komga must map to unsupported')
assert.match(crossSearchSource, /stateSection\('opds', AppStrings\.get\('route_opds_title'\), 'opds', 'unsupported', 'not_configured'\)/, 'unconfigured OPDS must map to unsupported')
assert.match(crossSearchSource, /stateSection\('webdav', AppStrings\.get\('route_webdav_title'\), 'webdav', 'unsupported', 'not_configured'\)/, 'unconfigured WebDAV must map to unsupported')
assert.match(crossSearchSource, /timeoutSection\(fallback\.id, fallback\.title, fallback\.sourceKind\)/, 'timeouts must be represented separately')
assert.match(crossSearchSource, /export type CrossSearchSourceFilter = 'all' \| 'local' \| 'private' \| 'source'/, 'cross-search must expose source filter buckets')
assert.match(
  crossSearchSource,
  /search\(query: string, sourceFilter: CrossSearchSourceFilter = 'all'\)[\s\S]*sourceMatchesFilter\('local', sourceFilter\)[\s\S]*sourceMatchesFilter\('komga', sourceFilter\)[\s\S]*sourceMatchesFilter\('opds', sourceFilter\)[\s\S]*sourceMatchesFilter\('webdav', sourceFilter\)[\s\S]*sourceMatchesFilter\('wasm', sourceFilter\)/,
  'cross-search must avoid launching providers outside the selected source filter',
)
assert.match(
  crossSearchSource,
  /private sourceMatchesFilter\(sourceKind: CrossSearchSourceKind, sourceFilter: CrossSearchSourceFilter\): boolean[\s\S]*sourceFilter === 'local'[\s\S]*sourceKind === 'wasm'[\s\S]*sourceKind === 'komga' \|\| sourceKind === 'opds' \|\| sourceKind === 'webdav'/,
  'cross-search source filter must split local, private library, and source package buckets',
)
assert.match(
  crossSearchSource,
  /webDavPathSegments: resource\.isCollection \?[\s\S]*this\.webDavRelativeSegments\(client, resource\.href\)[\s\S]*this\.webDavParentSegments\(client, resource\.href\)/,
  'WebDAV image search results must retain parent path segments so child images open from the right directory',
)
assert.match(
  crossSearchSource,
  /webDavParentSegments\(client: WebDavClient, href: string\): string\[\][\s\S]*this\.webDavRelativeSegments\(client, href\)[\s\S]*segments\.slice\(0, segments\.length - 1\)/,
  'WebDAV image search must derive a stable parent directory path for direct image hits',
)
assert.doesNotMatch(crossSearchSource, /errorText:\s*e\.message|message='\s*\+\s*e\.message|message=\$\{e\.message\}/, 'cross-search must not expose or log raw exception messages')

assert.match(searchPageSource, /@Local private history:\s*SearchHistoryEntry\[\]/, 'SearchPage must keep recent search history state')
assert.match(searchPageSource, /new SearchHistoryStore\(context\)/, 'SearchPage must create persistent history store')
assert.match(searchPageSource, /this\.recordHistory\(query\)/, 'SearchPage must record non-empty submitted searches')
assert.match(searchPageSource, /this\.HistoryPanel\(\)/, 'SearchPage must render history for an empty query')
assert.match(searchPageSource, /this\.runHistoryQuery\(entry\.query\)/, 'history rows must run searches when tapped')
assert.match(searchPageSource, /this\.clearHistory\(\)/, 'SearchPage must expose clear-history action')
assert.match(
  searchPageSource,
  /sourceFilter: CrossSearchSourceFilter = 'all'[\s\S]*service\.pendingSections\(this\.sourceFilter\)[\s\S]*service\.search\(query, this\.sourceFilter\)[\s\S]*private SourceFilterMenu\(\)[\s\S]*setSourceFilter\('local'\)[\s\S]*setSourceFilter\('private'\)[\s\S]*setSourceFilter\('source'\)[\s\S]*this\.SourceFilterBar\(\)/,
  'SearchPage must expose and apply a source filter menu to pending and submitted searches',
)
assert.match(searchPageSource, /section\.state === 'running' \|\| section\.state === 'pending'/, 'SearchPage must render running/pending source states')
assert.match(searchPageSource, /section\.state === 'empty' \|\| section\.state === 'timeout' \|\| section\.state === 'failed' \|\| section\.state === 'unsupported'/, 'SearchPage must distinguish terminal non-result states')
assert.doesNotMatch(searchPageSource, /feedbackText\s*=\s*e\.message|message='\s*\+\s*e\.message/, 'SearchPage must not expose or log raw exception messages')

assert.match(browseViewModelSource, /safeSearchDiagnostic\(e\)\.userText/, 'source search page errors must use redacted user text')
assert.doesNotMatch(
  browseViewModelSource.match(/runtimeErrorMessage\(response:[\s\S]*?\n  \}/)?.[0] ?? '',
  /errorMessage|error\?\.\['message'\]/,
  'source runtime search errors must not surface raw provider/runtime message bodies',
)
