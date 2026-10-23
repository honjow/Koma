const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function subject(file, owner, methods, globals) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.getText(tree) === owner)
  const body = methods.map(name => cls.members.find(n => n.name?.getText(tree) === name).getText(tree)).join('\n')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject {${body}}`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, console, ...globals })
  return new exports.Subject()
}
const entry = id => ({ id, name: id, version: '1', icon: `${id}.png` })
const globals = {
  resolveIndexDocumentUrl: value => value,
  entryWithCachedIcon: (entry, iconUri) => ({ ...entry, iconUri }),
  SOURCE_INDEX_ICON_FETCH_CONCURRENCY: 4,
  DiagnosticLogger: { info() {}, error() {}, warn() {} },
}

test('usable index metadata returns without waiting for any icon download', async () => {
  let iconFetches = 0, destroyed = false
  const service = subject('sourceRuntime/SourceIndexService.ets', 'SourceIndexService', ['fetchIndex'], {
    ...globals, isValidHttpUrl: () => true, parseIndexEntriesDocument: value => value,
    parseIndexEntry: value => value, safeResolveIndexAssetUrl: (_url, icon) => icon,
    http: { RequestMethod: { GET: 'GET' }, HttpDataType: { STRING: 'string' }, createHttp: () => ({
      async request() { return { responseCode: 200, result: JSON.stringify([entry('A'), entry('B')]) } },
      destroy() { destroyed = true },
    }) },
  })
  service.cachedIconUriFor = () => { iconFetches++; return new Promise(() => {}) }
  const result = await service.fetchIndex('https://index.test/index.json')
  assert.equal(result.ok, true)
  assert.equal(result.entries.map(e => e.id).join(','), 'A,B')
  assert.equal(iconFetches, 0)
  assert.equal(destroyed, true)
})

test('one slow icon does not hold the next batch; every ready icon publishes independently within four workers', async () => {
  const service = subject('sourceRuntime/SourceIndexService.ets', 'SourceIndexService', ['loadIndexIcons'], globals)
  const pending = new Map(), published = []
  let active = 0, maxActive = 0
  service.cachedIconUriFor = (_url, item) => new Promise(resolve => {
    active++; maxActive = Math.max(maxActive, active)
    pending.set(item.id, () => { active--; resolve(`file://${item.id}.png`) })
  })
  const running = service.loadIndexIcons('https://index.test/index.json',
    ['A','B','C','D','E'].map(entry), item => published.push(item.id), () => true)
  assert.equal(active, 4)
  pending.get('B')()
  await new Promise(setImmediate)
  assert.equal(published.join(','), 'B')
  assert.equal(pending.has('E'), true)
  for (const id of ['A','C','D','E']) pending.get(id)()
  await running
  assert.equal(maxActive, 4)
  assert.equal([...published].sort().join(','), 'A,B,C,D,E')
})

test('changing the index retires old icon callbacks without overwriting the new list', async () => {
  let callback
  const manager = subject('pages/SourcePackageManagerPage.ets', 'SourcePackageManagerPage',
    ['showIndexEntries', 'setSourceIndexUrl'], { ...globals, tf: (_key, count) => String(count) })
  Object.assign(manager, {
    sourceIndexUrl: 'https://old.test/index.json', indexLoadRevision: 1, savedIndexLoadRevision: 0,
    sortedIndexEntries: entries => entries,
    sourceIndexService: { loadIndexIcons: async (_url, _entries, onReady) => { callback = onReady } },
  })
  manager.showIndexEntries(manager.sourceIndexUrl, [entry('A')], 1)
  manager.setSourceIndexUrl('https://new.test/index.json')
  manager.indexEntries = [entry('B')]
  callback({ ...entry('A'), iconUri: 'file://A.png' })
  assert.equal(manager.indexEntries[0].id, 'B')
  manager.showIndexEntries('https://old.test/index.json', [entry('C')], 1)
  assert.equal(manager.indexEntries[0].id, 'B')
})
