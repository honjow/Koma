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
const names = ['isSearchActive', 'clearPendingSearchTimer', 'submitBrowseSearch',
  'setRuntimeFilterValue', 'resetRuntimeFilters']
const handlers = names.map(name => owner.members.find(node => node.name?.text === name).getText(ast)).join('\n')
const compiled = ts.transpileModule(`export class Page { ${handlers} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText
const exportsObject = {}
new Function('exports', compiled)(exportsObject)

function fixture(searchQuery) {
  const calls = []
  const page = new exportsObject.Page()
  Object.assign(page, {
    searchTimer: 0,
    chrome: { query: searchQuery },
    currentSource: () => 'source',
    viewModel: {
      searchQuery,
      setSearchFilterValue: (id, value) => { calls.push(['search-filter', id, value]); return true },
      setBrowseFilterValue: (id, value) => calls.push(['browse-filter', id, value]),
      resetSearchFilters: () => calls.push(['reset-search']),
      resetBrowseFilters: () => calls.push(['reset-browse']),
      runSearch: (source, query) => calls.push(['search', source, query]),
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
