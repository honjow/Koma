const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

// Execute the production destination handlers with only transport/storage boundaries replaced.
const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/viewmodel/BrowseViewModel.ets'), 'utf8')
const tree = ts.createSourceFile('browse.ts', source, ts.ScriptTarget.Latest, true)
const owner = tree.statements.find(row => ts.isClassDeclaration(row) && row.name?.text === 'BrowseViewModel')
const methods = ['loadBrowseHome', 'selectBrowseDestination', 'clearBrowseListing', 'applyBrowseListing',
  'defaultListingForBrowse', 'hasBrowseContent', 'resolveBrowseLoad']
const enums = tree.statements.filter(row => ts.isEnumDeclaration(row)).map(row => row.getText(tree)).join('\n')
const code = ts.transpileModule(`${enums}\nexport class Model { ${methods.map(name =>
  owner.members.find(row => row.name?.text === name).getText(tree)).join('\n')} }`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
}).outputText
const listings = [{ id: 'popular', kind: 'popular' }, { id: 'latest', kind: 'latest' }]

function fixture(saved = new Map(), home = true) {
  const calls = [], exported = {}
  const preferences = { load: id => saved.get(id), save: (id, value) => saved.set(id, value), clear: id => saved.delete(id) }
  new Function('exports', 'appSourceBrowseDestinationPreferences', code)(exported, preferences)
  const vm = new exported.Model()
  Object.assign(vm, {
    browseRequestId: 0, selectedListingId: '', homeSections: [], browseSections: [], browseDestinationCache: new Map(),
    listings, filters: [], browseFilterValues: {}, loadingBrowse: false,
    isCurrentBrowseSource: item => vm.selectedSource?.sourceId === item.sourceId,
    isSameBrowseSource: item => vm.selectedSource?.sourceId === item.sourceId,
    setSelectedSource: item => { vm.selectedSource = item; vm.clearBrowseListing(); vm.homeSections = []; vm.browseRequestId++ },
    beginBrowseLoad: intent => { vm.loadingBrowse = true; vm.browseLoadIntent = intent },
    webChallengeGuard: () => () => true,
    loadSourceListings: async () => listings,
    loadSourceFilters: async () => ({ filters: [] }),
    defaultSourceFilterValues: () => ({}), mergeSavedSourceFilterValues: () => ({}), publishFilterSchema: () => {},
    sourceSupportsOperation: (_source, kind) => kind === 'mangaList' || (kind === 'home' && home),
    browseDestinationCacheKey: (_source, listing) => listing?.id ?? 'home', rememberBrowseDestination: () => {},
    loadSourceHomeSections: async () => { calls.push('home'); return [{ manga: [{ id: 'home' }] }] },
    loadMangaListing: async (_source, id) => { calls.push(id); return { manga: [{ id }], hasNextPage: false } },
    failBrowseLoad: error => { vm.error = error.message }, publishWebChallenge: () => {},
  })
  return { vm, calls, saved, source: { sourceId: 'a', capabilities: home ? ['sourceInfo', 'home'] : ['sourceInfo', 'mangaList'] } }
}

test('restores a saved stable listing directly, while first visit and saved Home keep Home', async () => {
  const saved = new Map([['a', 'latest'], ['b', '']])
  const a = fixture(saved)
  await a.vm.loadBrowseHome(a.source)
  assert.deepEqual(a.calls, ['latest'])
  assert.equal(a.vm.selectedListingId, 'latest')
  const b = fixture(saved)
  await b.vm.loadBrowseHome({ ...b.source, sourceId: 'b' })
  assert.deepEqual(b.calls, ['home'])
  const first = fixture(saved)
  await first.vm.loadBrowseHome({ ...first.source, sourceId: 'c' })
  assert.deepEqual(first.calls, ['home'])
  assert.equal(saved.has('c'), false)
})

test('removed listing falls back to the original Home or Popular without requesting the removed ID', async () => {
  for (const home of [true, false]) {
    const f = fixture(new Map([['a', 'removed']]), home)
    await f.vm.loadBrowseHome(f.source)
    assert.deepEqual(f.calls, [home ? 'home' : 'popular'])
    assert.equal(f.saved.has('a'), false)
  }
})

test('failed selection remains remembered per source; recovery cannot overwrite a newer choice', async () => {
  const f = fixture(new Map([['b', 'popular']]))
  await f.vm.loadBrowseHome(f.source)
  f.vm.loadMangaListing = async () => { throw new Error('temporary network failure') }
  await f.vm.selectBrowseDestination(listings[1])
  assert.equal(f.vm.error, 'temporary network failure')
  assert.equal(f.saved.get('a'), 'latest')
  assert.equal(f.saved.get('b'), 'popular')
  f.saved.set('a', 'popular')
  await f.vm.selectBrowseDestination(listings[1], true, 'verification-replay')
  assert.equal(f.saved.get('a'), 'popular')
  await f.vm.selectBrowseDestination()
  assert.equal(f.saved.get('a'), '')
})
