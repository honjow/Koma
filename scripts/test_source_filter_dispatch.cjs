const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

// Execute the page's actual handlers: the device regression sent a listing
// request while search results were visible. Do not substitute a parallel router.
const pageText = fs.readFileSync(path.join(__dirname,
  '../entry/src/main/ets/pages/SourceBrowsePage.ets'), 'utf8')
  .replace('export struct SourceBrowsePage', 'export class SourceBrowsePage')
const ast = ts.createSourceFile('page.ts', pageText, ts.ScriptTarget.Latest, true)
const owner = ast.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'SourceBrowsePage')
const names = ['isSearchActive', 'hasSearchFilterQuery', 'clearPendingSearchTimer', 'submitBrowseSearch',
  'submitFilterSearch', 'setRuntimeFilterValue', 'resetRuntimeFilters']
const handlers = names.map(name => owner.members.find(node => node.name?.text === name).getText(ast)).join('\n')
const compiled = ts.transpileModule(`export class Page { ${handlers} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText
const exportsObject = {}
new Function('exports', compiled)(exportsObject)

function fixture(searchQuery, useSearchForFilters = false) {
  const calls = []
  const page = new exportsObject.Page()
  Object.assign(page, {
    searchTimer: 0,
    chrome: { query: searchQuery },
    currentSource: () => 'source',
    viewModel: {
      searchQuery,
      useSearchForFilters,
      setSearchFilterValue: (id, value) => { calls.push(['search-filter', id, value]); return true },
      setBrowseFilterValue: (id, value) => calls.push(['browse-filter', id, value]),
      resetSearchFilters: () => calls.push(['reset-search']),
      resetBrowseFilters: () => calls.push(['reset-browse']),
      runSearch: (source, query, _recover, _guard, fromFilters) =>
        calls.push(query.length === 0 && fromFilters ? ['filter-only-search', source] : ['search', source, query]),
      clearSearch: source => calls.push(['clear-search', source]),
    },
  })
  return { page, calls }
}

test('source search filter changes and reset target search, using the current input', () => {
  const { page, calls } = fixture('previous query')
  page.chrome.query = 'current query'
  page.searchTimer = setTimeout(() => assert.fail('stale delayed search executed'), 100)
  page.setRuntimeFilterValue({ id: 'sort' }, '1')
  page.resetRuntimeFilters()
  assert.equal(page.searchTimer, 0)
  assert.deepEqual(calls, [
    ['search-filter', 'sort', '1'], ['search', 'source', 'current query'],
    ['reset-search'], ['search', 'source', 'current query'],
  ])
})

test('ordinary listing filter changes and reset retain their independent browse owner', () => {
  const { page, calls } = fixture('')
  page.setRuntimeFilterValue({ id: 'sort' }, '2')
  page.resetRuntimeFilters()
  assert.deepEqual(calls, [['browse-filter', 'sort', '2'], ['reset-browse']])
})

test('an opted-in source uses blank-query search only for applied filters and reset returns to the feed', () => {
  const { page, calls } = fixture('', true)
  page.setRuntimeFilterValue({ id: 'genre' }, 'mystery')
  page.resetRuntimeFilters()
  assert.deepEqual(calls, [
    ['search-filter', 'genre', 'mystery'], ['filter-only-search', 'source'],
    ['reset-search'], ['clear-search', 'source'],
  ])
})

test('filter-only search uses search scope through first-page retry and cursor continuation', async () => {
  const src = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/viewmodel/BrowseViewModel.ets'), 'utf8')
  const ast = ts.createSourceFile('model.ts', src, ts.ScriptTarget.Latest, true)
  const model = ast.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'BrowseViewModel')
  const methods = ['hasActiveSearch', 'runSearch', 'retrySearchPage', 'loadMoreSearch', 'searchSource',
    'clearSearch', 'filterValuesForQuery']
  const body = methods.map(name => model.members.find(node => node.name?.text === name).getText(ast))
    .join('\n').replace(/@Computed\s*/g, '')
  const output = ts.transpileModule(`export class Model { ${body} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}
  class SourceRuntimeError extends Error {}
  new Function('exports', 'appSourceSettingsStore', 'sourceFiltersForQuery', 'safeSearchDiagnostic',
    'SourceRuntimeError', 'appendUniqueSourceManga', 'SOURCE_OPERATION_PAGE_SIZE', output)(
    exports, { revisionForSource: () => 'current' },
    (rows, query, emptySearch) => rows.filter(filter => filter.scope === (query || emptySearch ? 'search' : 'browse')),
    error => ({ userText: error.message }), SourceRuntimeError, (left, right) => [...left, ...right], 20)
  const source = { sourceId: 'source' }, entry = {}, calls = []
  const vm = Object.assign(new exports.Model(), {
    selectedSource: source, registry: { lookup: () => ({ entry }) },
    searchQuery: '', searchRequestId: 0, searchResults: [], useSearchForFilters: true,
    searchFilterValues: { genre: 'mystery', feed: 'old' },
    filters: [{ id: 'genre', scope: 'search', type: 'select' }, { id: 'feed', scope: 'browse', type: 'select' }],
    filterRequestKey: filter => filter.id, clearWebChallenge: () => {}, webChallengeGuard: () => () => true,
    publishWebChallenge: () => {}, prepareSearchSource: () => {}, ensureSearchFilters: async () => {},
    isCurrentBrowseSource: () => true, searchResultFingerprint: () => 'current', pageCursor: (_page, cursor) => cursor,
    runSourceOperation: async (_id, operation, args) => {
      calls.push([operation, args.query, args.page.cursor, args.filters])
      if (calls.length === 1) throw new Error('temporary')
      return { manga: [{ id: String(calls.length) }], hasNextPage: calls.length === 2, nextCursor: 'next' }
    },
  })
  await vm.runSearch(source, '', false, undefined, true)
  assert.equal(vm.searchErrorMessage, 'temporary')
  await vm.retrySearchPage()
  await vm.loadMoreSearch()
  assert.deepEqual(calls, [
    ['search', '', '', { genre: 'mystery' }], ['search', '', '', { genre: 'mystery' }],
    ['search', '', 'next', { genre: 'mystery' }],
  ])
  vm.clearSearch(source)
  vm.useSearchForFilters = false
  await vm.runSearch(source, '', false, undefined, true)
  assert.equal(vm.hasActiveSearch, false)
  assert.equal(calls.length, 3)
})
