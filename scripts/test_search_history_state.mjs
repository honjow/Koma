import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const historyStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/SearchHistoryStore.ets'), 'utf8')
const stateMapperSource = readFileSync(resolve(root, 'entry/src/main/ets/model/SearchStateMapper.ets'), 'utf8')
const crossSearchSource = readFileSync(resolve(root, 'entry/src/main/ets/model/CrossSearchService.ets'), 'utf8')
const searchPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SearchPage.ets'), 'utf8')
const browseViewModelSource = readFileSync(resolve(root, 'entry/src/main/ets/viewmodel/BrowseViewModel.ets'), 'utf8')
const komgaSeriesPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/KomgaSeriesPage.ets'), 'utf8')
const opdsBrowsePageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/OpdsBrowsePage.ets'), 'utf8')

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
  /!isCrossSearchQueryMeaningful\(normalizedQuery\)[\s\S]*return \[\]/,
  'punctuation-only search queries must not fan out into all providers',
)
assert.match(
  crossSearchSource,
  /export function isCrossSearchQueryMeaningful\(value: string\): boolean[\s\S]*normalizeCrossSearchText\(value\)\.length > 0/,
  'cross-search must expose the same meaningful-query gate used by the service and UI',
)
assert.match(
  crossSearchSource,
  /export function normalizeCrossSearchText\(value: string\): string[\s\S]*isAsciiLetter[\s\S]*isDigit[\s\S]*isNonAsciiText[\s\S]*previousWasSpace[\s\S]*private normalizeSearchText\(value: string\): string[\s\S]*return normalizeCrossSearchText\(value\)/,
  'cross-search must normalize punctuation and spacing before local ranking/matching',
)
assert.match(
  crossSearchSource,
  /private compactSearchText\(value: string\): string[\s\S]*normalizeSearchText\(value\)\.replace\(/,
  'cross-search must support compact matching such as onepiece against One Piece',
)
assert.match(
  crossSearchSource,
  /private textMatchesQuery\(value: string, normalizedQuery: string, compactQuery: string\): boolean[\s\S]*normalizeSearchText\(value\)[\s\S]*compactSearchText\(value\)/,
  'cross-search providers must share normalized and compact matching',
)
assert.match(
  crossSearchSource,
  /private localComicMatches\(comic: Comic, normalizedQuery: string, compactQuery: string\)[\s\S]*textMatchesQuery\(comic\.title[\s\S]*this\.localMatchedChapterTitle\(comic, normalizedQuery, compactQuery\) !== undefined[\s\S]*private localMatchedChapterTitle\(comic: Comic, normalizedQuery: string, compactQuery: string\): string \| undefined[\s\S]*textMatchesQuery\(item\.title/,
  'local search must match title, metadata, and chapter names through normalized search text',
)
assert.match(
  crossSearchSource,
  /subtitle: this\.localSearchSubtitle\(comic, normalizedQuery, compactQuery\)[\s\S]*private localSearchSubtitle\(comic: Comic, normalizedQuery: string, compactQuery: string\): string[\s\S]*matchedChapterTitle !== undefined[\s\S]*return matchedChapterTitle/,
  'local search results must expose chapter-only matches in the scored subtitle field',
)
assert.match(
  crossSearchSource,
  /filterOpdsPublications\(client: OpdsClient, catalog: OpdsParseResult, query: string\)[\s\S]*textMatchesQuery\(publication\.title[\s\S]*textMatchesQuery\(publication\.author[\s\S]*textMatchesQuery\(publication\.summary/,
  'OPDS search filtering must use the same normalized matching as local search',
)
assert.match(
  crossSearchSource,
  /davResourceName\(resource\), normalizedQuery, compactQuery\)/,
  'WebDAV search filtering must use normalized matching for file and folder names',
)
assert.match(
  crossSearchSource,
  /searchResultScore\(item: CrossSearchResultItem, normalizedQuery: string, compactQuery: string\)[\s\S]*titleCompact === compactQuery[\s\S]*subtitleCompact\.indexOf\(compactQuery\)/,
  'cross-search ranking must score compact title and subtitle matches',
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
assert.match(crossSearchSource, /komgaSeriesId: series\.id/, 'Komga search results must retain the target series id')
assert.match(crossSearchSource, /opdsFeedUrl: catalog\.feedUrl/, 'OPDS search results must retain the source feed url')
assert.match(crossSearchSource, /opdsPublicationId: publication\.id/, 'OPDS search results must retain the target publication id')
assert.doesNotMatch(crossSearchSource, /errorText:\s*e\.message|message='\s*\+\s*e\.message|message=\$\{e\.message\}/, 'cross-search must not expose or log raw exception messages')

assert.match(searchPageSource, /@Local private history:\s*SearchHistoryEntry\[\]/, 'SearchPage must keep recent search history state')
assert.match(searchPageSource, /new SearchHistoryStore\(context\)/, 'SearchPage must create persistent history store')
assert.match(searchPageSource, /this\.recordHistory\(query\)/, 'SearchPage must record non-empty submitted searches')
assert.match(
  searchPageSource,
  /isCrossSearchQueryMeaningful[\s\S]*query\.length === 0 \|\| !isCrossSearchQueryMeaningful\(query\)[\s\S]*return[\s\S]*this\.recordHistory\(query\)/,
  'SearchPage must not record or submit punctuation-only queries that the service will ignore',
)
assert.match(searchPageSource, /this\.HistoryPanel\(\)/, 'SearchPage must render history for an empty query')
assert.match(searchPageSource, /this\.runHistoryQuery\(entry\.query\)/, 'history rows must run searches when tapped')
assert.match(searchPageSource, /this\.clearHistory\(\)/, 'SearchPage must expose clear-history action')
assert.match(
  searchPageSource,
  /sourceFilter: CrossSearchSourceFilter = 'all'[\s\S]*service\.pendingSections\(this\.sourceFilter\)[\s\S]*service\.search\(query, this\.sourceFilter\)[\s\S]*private SourceFilterMenu\(\)[\s\S]*setSourceFilter\('local'\)[\s\S]*setSourceFilter\('private'\)[\s\S]*setSourceFilter\('source'\)[\s\S]*this\.SourceFilterBar\(\)/,
  'SearchPage must expose and apply a source filter menu to pending and submitted searches',
)
assert.match(
  searchPageSource,
  /seriesId: item\.komgaSeriesId[\s\S]*seriesTitle: item\.title[\s\S]*pushPath\(\{ name: KOMGA_ROUTE_NAME, param: param \}\)/,
  'Komga search result taps must route with the target series identity',
)
assert.match(
  searchPageSource,
  /feedUrl: item\.opdsFeedUrl[\s\S]*publicationId: item\.opdsPublicationId[\s\S]*pushPath\(\{ name: OPDS_ROUTE_NAME, param: param \}\)/,
  'OPDS search result taps must route with the target feed and publication identity',
)
assert.match(
  searchPageSource,
  /private SearchDestination\(name: string, param: Object\)[\s\S]*KomgaSeriesPage\(\{[\s\S]*params: param as SearchKomgaRouteParam[\s\S]*OpdsBrowsePage\(\{[\s\S]*params: param as SearchOpdsRouteParam/,
  'Search destinations must pass remote search route params into target pages',
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

assert.match(komgaSeriesPageSource, /seriesId\?: string/, 'Komga route params must accept a target series id')
assert.match(komgaSeriesPageSource, /seriesTitle\?: string/, 'Komga route params must accept a fallback series title')
assert.match(
  komgaSeriesPageSource,
  /await this\.reloadSeries\(\)[\s\S]*await this\.openInitialSeriesIfNeeded\(\)/,
  'Komga search entry must auto-open the target series after initial loading',
)
assert.match(
  komgaSeriesPageSource,
  /private async openInitialSeriesIfNeeded\(\): Promise<void>[\s\S]*this\.params\.seriesId[\s\S]*this\.series\.find[\s\S]*await this\.openSeries/,
  'Komga initial target opening must find or synthesize the selected series',
)
assert.match(opdsBrowsePageSource, /publicationId\?: string/, 'OPDS route params must accept a target publication id')
assert.match(opdsBrowsePageSource, /feedUrl\?: string/, 'OPDS route params must accept a target feed url')
assert.match(
  opdsBrowsePageSource,
  /const initialUrl = this\.initialCatalogUrl\(saved\.server\.rootUrl\)[\s\S]*await this\.loadCatalog\(initialUrl, false\)/,
  'OPDS search entry must load the result feed instead of always loading root',
)
assert.match(
  opdsBrowsePageSource,
  /this\.applyCatalog\(catalog\)[\s\S]*await this\.openInitialPublicationIfNeeded\(\)/,
  'OPDS search entry must auto-open the target publication after loading the feed',
)
