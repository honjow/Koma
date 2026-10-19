// Production HTTP/section contracts on host bindings; not native UI acceptance.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
const compile = source => ts.transpileModule(source, { compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText
const clientExports = {}
vm.runInNewContext(compile(fs.readFileSync(path.join(root, 'remote/KavitaClient.ets'), 'utf8')), {
  exports: clientExports, encodeURIComponent,
})
const { KavitaClient } = clientExports
const source = fs.readFileSync(path.join(root, 'model/CrossSearchService.ets'), 'utf8')
const tree = ts.createSourceFile('CrossSearchService', source, ts.ScriptTarget.Latest, true)
const owner = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'CrossSearchService')
const names = ['searchKavita', 'kavitaSeriesTitle', 'kavitaSeriesSubtitle', 'sortSearchResultItems',
  'searchResultWithMatchQuality', 'searchResultMatchQuality', 'searchResultScoreForQuality',
  'normalizeSearchText', 'compactSearchText', 'section', 'stateSection', 'errorSection']
const members = names.map(name => {
  const member = owner.members.find(node => node.name?.getText(tree) === name)
  assert.ok(member, name)
  return member.getText(tree)
})
const normalizer = tree.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'normalizeCrossSearchText')
const sectionExports = {}
vm.runInNewContext(compile(normalizer.getText(tree) + '\nexport class Subject {' + members.join('\n') + '}'), {
  exports: sectionExports, SOURCE_PAGE_SIZE: 20,
  AppStrings: { get: key => key === 'kavita_series_pages_progress' ? '%s/%s' : key },
  safeSearchDiagnostic: error => ({ code: error.message, userText: error.message }),
  searchStateUserText: (_state, code) => code,
  console: { info() {}, error() {} },
})
const record = { server: { id: 'owned-search', baseUrl: 'http://owned.invalid/', credentialRef: 'fixture' },
  credential: { credentialRef: 'fixture', apiKey: 'public-test-only' } }
const clone = value => JSON.parse(JSON.stringify(value))
const requests = []
let matches = [{ seriesId: 41, libraryId: 11, libraryName: 'Later library' },
  { seriesId: 21, libraryId: 1, libraryName: 'First library' }]
let rows = [{ id: 21, name: 'Owned second', pages: 9, pagesRead: 2, coverImage: 'owned-cover-21' },
  { id: 41, name: 'Owned first', pages: 12, pagesRead: 3, coverImage: 'owned-cover-41' }]
let searchStatus = 200, bulkStatus = 200, malformed = false
const client = new KavitaClient({ ...record, http: { async request(request) {
  requests.push(clone(request))
  if (request.url.includes('/Search/search?')) {
    return { status: searchStatus, body: JSON.stringify(malformed ? {} : { series: matches }) }
  }
  if (request.url.endsWith('/series-by-ids')) return { status: bulkStatus, body: JSON.stringify(rows) }
  if (request.url.includes('/all-v2?')) return { status: 200, body: '[]' }
  throw Error('Unexpected catalog enumeration or request')
} } })
const subject = new sectionExports.Subject()
subject.remoteStore = { loadKavita: async () => record, createKavitaClient: () => client }
async function run() {
  const result = clone((await subject.searchKavita('Owned')).section)
  assert.equal(result.state, 'ready')
  assert.deepEqual(result.items.map(item => [item.kavitaSeriesId, item.kavitaLibraryId]), [['41', 11], ['21', 1]])
  assert.equal(result.items[0].subtitle, 'Later library · 3/12')
  assert.equal(result.items[0].coverUri, 'owned-cover-41')
  assert.equal(result.items[0].id, 'kavita:owned-search:11:41')
  assert.equal(result.items[0].remoteServerId, record.server.id)
  assert.equal(requests.length, 2)
  assert.deepEqual(JSON.parse(requests[1].body), { seriesIds: [41, 21] })
  assert.equal(requests[1].headers.xApiKey, 'public-test-only')

  requests.length = 0
  matches = []
  assert.equal((await subject.searchKavita('nothing')).section.state, 'empty')
  assert.equal(requests.length, 1)
  await client.searchSeries('name & query=other /汉字')
  const queryUrl = new URL(requests[1].url)
  assert.equal(queryUrl.searchParams.get('queryString'), 'name & query=other /汉字')
  assert.equal(queryUrl.searchParams.get('includeChapterAndFiles'), 'false')
  assert.equal([...queryUrl.searchParams].length, 2)

  matches = [{ seriesId: 41, libraryId: 11, libraryName: 'Later library' }]
  rows = [] // Deleted/access-revoked after candidate search: no invented metadata.
  assert.equal((await subject.searchKavita('Owned')).section.items.length, 0)
  bulkStatus = 403
  assert.equal((await subject.searchKavita('Owned')).section.state, 'failed')
  bulkStatus = 200
  searchStatus = 401
  assert.equal((await subject.searchKavita('Owned')).section.state, 'failed')
  searchStatus = 200
  malformed = true
  assert.equal((await subject.searchKavita('Owned')).section.state, 'failed')

  malformed = false
  matches = Array.from({ length: 25 }, (_, i) => ({ seriesId: i + 1, libraryId: 1, libraryName: 'Library' }))
  rows = matches.map(match => ({ id: match.seriesId, name: `Owned ${String(match.seriesId).padStart(2, '0')}` }))
  const complete = (await subject.searchKavita('Owned')).section
  assert.equal(complete.items.length, 25)
  assert.equal(complete.resultCount, 25)
  assert.equal(complete.items[24].kavitaSeriesId, '25')

  await client.listSeries(7, 2, 50)
  const browse = requests.at(-1)
  assert.ok(browse.url.endsWith('/api/Series/all-v2?PageNumber=2&PageSize=50'))
  assert.deepEqual(JSON.parse(browse.body), { statements: [{ comparison: 0, field: 19, value: '7' }],
    combination: 1, sortOptions: { sortField: 1, isAscending: true }, limitTo: 0 })
  console.log('PASS: bounded cross-library candidates, hydration identity/metadata, empty/error, query encoding, existing browse request')
}
run().catch(error => { console.error(error); process.exitCode = 1 })
