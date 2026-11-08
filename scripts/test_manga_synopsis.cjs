const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const ets = path.join(__dirname, '../entry/src/main/ets')

function load(file, dependencies = {}) {
  const source = fs.readFileSync(path.join(ets, file + '.ets'), 'utf8')
  const js = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}
  new Function('exports', 'require', js)(exports, name => {
    assert.ok(name in dependencies, name)
    return dependencies[name]
  })
  return exports
}

test('native synopsis keeps nested links, emphasis and quotes without executing HTML', async () => {
  const { lexer } = await import('../entry/src/main/ets/parser/vendor/marked/marked.esm.js')
  const { MarkdownSynopsis } = load('parser/MarkdownSynopsis', {
    './MarkdownDocument': load('parser/MarkdownDocument'),
    './vendor/marked/marked.esm': { lexer },
  })
  const alias = MarkdownSynopsis.spans('***别名**：腦洞學生會*')
  assert.equal(alias.map(span => span.text).join(''), '别名：腦洞學生會')
  assert(alias.some(span => span.text === '别名' && span.bold && span.italic))

  const address = 'https://example.test/path_(a)?a=1&b=2'
  const quote = MarkdownSynopsis.spans(`> ***[原站](${address})***\n> 第二行\n\n後段`)
  assert.equal(quote.map(span => span.text).join(''), '原站\n第二行\n\n後段')
  assert(quote.some(span => span.text === '原站' && span.bold && span.italic && span.quote && span.url === address))
  assert(quote.some(span => span.text === '第二行' && span.quote))
  assert(quote.some(span => span.text === '後段' && !span.quote))
  const refused = MarkdownSynopsis.spans('[危险](javascript:evil)')
  assert.equal(refused[0].url, '')
  assert.deepEqual(MarkdownSynopsis.spans('普通简介\n\n第二段'), [])
})

test('synopsis expansion immediately follows its comic and persists both toggles', async () => {
  const local = new Map()
  let disk = new Map()
  const store = {
    getSync: (key, fallback) => local.get(key) ?? fallback,
    putSync: (key, value) => local.set(key, value),
    deleteSync: key => local.delete(key),
    flush: async () => { disk = new Map(local) },
  }
  const { MangaSynopsisPreferences } = load('model/MangaSynopsisPreferences', {
    '@kit.ArkData': { preferences: { getPreferencesSync: () => store } },
  })
  const context = {}
  assert.equal(MangaSynopsisPreferences.isExpanded(context, 'first'), false)
  const save = MangaSynopsisPreferences.save(context, 'first', true)
  assert.equal(MangaSynopsisPreferences.isExpanded(context, 'first'), true)
  assert.equal(MangaSynopsisPreferences.isExpanded(context, 'second'), false)
  await save
  assert.equal(disk.get('first'), true)
  await MangaSynopsisPreferences.save(context, 'first', false)
  assert.equal(MangaSynopsisPreferences.isExpanded(context, 'first'), false)
  assert(!disk.has('first'))
})
