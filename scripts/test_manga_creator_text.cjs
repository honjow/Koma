const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const input = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/components/MangaCreatorText.ets'), 'utf8')
const js = ts.transpileModule(input, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText
const exportsForTest = {}
new Function('exports', js)(exportsForTest)

test('creator names wrap at separators without altering punctuation inside parentheses', () => {
  const original = 'Team Argo,Monohumbug(Redice Studio),Name (Writer, Artist),极'
  const result = exportsForTest.formatMangaCreatorList(original)
  assert.equal(result, 'Team\u00a0Argo, Monohumbug(Redice\u00a0Studio), Name\u00a0(Writer,\u00a0Artist), 极')
  assert.equal(original, 'Team Argo,Monohumbug(Redice Studio),Name (Writer, Artist),极')
})
