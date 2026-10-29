const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
function load(file, imports = {}) {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', js)(exports, name => imports[name] ?? {})
  return exports
}
const tri = load('model/SourceTriStateFilters.ets')
const models = load('model/SourceModels.ets', { '../i18n/AppStrings': { AppStrings: { get: key => key } } })
const preference = load('sourceRuntime/SourceFilterPreferencesStore.ets', {
  '../model/SourceTriStateFilters': tri,
})
const source = fs.readFileSync(path.join(root, 'viewmodel/BrowseViewModel.ets'), 'utf8')
const ast = ts.createSourceFile('model.ts', source, ts.ScriptTarget.Latest, true)
const owner = ast.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'BrowseViewModel')
const methods = ['fetchSourceFilterData', 'cancelFilterDataLoad', 'publishFilterSchema', 'loadSourceFilters']
const body = methods.map(name => owner.members.find(n => n.name?.text === name).getText(ast)).join('\n')
const js = ts.transpileModule(`export class Model { ${body} }`, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
const exportsObject = {}
new Function('exports', 'appSourceSettingsStore', 'parseSourceFilterSchemaJson', 'safeSourceBrowseErrorText', js)(
  exportsObject, { revisionForSource: () => 1 }, models.parseSourceFilterSchemaJson, error => error.message)
function fixture() {
  const source = { sourceId: 'source', capabilities: ['filters'] }
  const entry = {}
  const model = Object.assign(new exportsObject.Model(), {
    selectedSource: source, registry: { lookup: () => ({ entry }) },
    filterDataRevision: 0, loadingFilterData: false, filterDataReady: false,
    sourceSupportsOperation: () => true,
    filters: [], browseSections: [{ manga: [{ id: 'retained' }] }],
    browseFilterValues: { tags: ['action', '!romance'] },
  })
  return model
}

test('one tag cycles through include, exclude and ignore and saved choices survive deferred options', () => {
  let values = tri.nextSourceTriStateValues([], 'action')
  assert.deepEqual(values, ['action'])
  values = tri.nextSourceTriStateValues(values, 'action')
  assert.deepEqual(values, ['!action'])
  assert.deepEqual(tri.nextSourceTriStateValues(values, 'action'), [])
  const store = new preference.SourceFilterPreferencesStore()
  const saved = { tags: ['action', '!romance'] }
  const initial = [{ id: 'tags', type: 'tristate', name: 'Genre' }]
  assert.deepEqual(store.filterSafeValues(saved, initial), saved)
  assert.deepEqual(store.filterSafeValues(saved, [{ ...initial[0], options: ['Action'], optionIds: ['action'] }]),
    { tags: ['action'] })
})

test('initial schema is independent; failed optional metadata retains results and choices and can retry', async () => {
  const model = fixture()
  const base = [{ id: 'tags', type: 'tristate', name: 'Genre' }]
  const calls = []
  model.runSourceOperationResponse = async (_id, _op, args) => {
    calls.push(args)
    if (args.fetchFilterData) throw new Error('tag endpoint failed')
    return { data: { filters: base, supportsFilterFetching: true } }
  }
  model.publishFilterSchema(await model.loadSourceFilters(model.selectedSource))
  assert.deepEqual(calls, [{}])
  const results = model.browseSections
  const choices = model.browseFilterValues
  const filtersBefore = model.filters
  assert.equal(await model.fetchSourceFilterData(), 'tag endpoint failed')
  assert.equal(model.browseSections, results)
  assert.equal(model.browseFilterValues, choices)
  assert.equal(model.filters, filtersBefore)
  assert.equal(model.loadingFilterData, false)
  model.runSourceOperationResponse = async () => ({ data: { filters: [
    { ...base[0], options: [{ id: 'action', name: 'Action' }] },
  ] } })
  assert.equal(await model.fetchSourceFilterData(), '')
  assert.deepEqual(model.filters[0].optionIds, ['action'])
  assert.equal(model.filterDataReady, true)
})

test('leaving the page rejects late metadata publication', async () => {
  const model = fixture()
  model.supportsFilterFetching = true
  const before = model.filters
  let finish
  model.runSourceOperationResponse = () => new Promise(resolve => { finish = resolve })
  const pending = model.fetchSourceFilterData()
  model.cancelFilterDataLoad()
  finish({ data: { filters: [{ id: 'late', type: 'select', options: ['late'] }] } })
  assert.equal(await pending, '')
  assert.equal(model.filters, before)
  assert.equal(model.loadingFilterData, false)
})
