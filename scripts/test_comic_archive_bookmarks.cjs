const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const file = path.resolve(__dirname, '../entry/src/main/ets/import/ComicArchiveBookmarkParser.ets')
const js = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
const parser = {}
new Function('exports', js)(parser)

test('ComicInfo bookmarks use sorted source page indexes and ignore invalid entries', () => {
  const root = { _name: 'ComicInfo', _elements: [{ _name: 'Pages', _elements: [
    { _name: 'Page', _attributes: { Image: '10', Bookmark: 'Chapter 2' } },
    { _name: 'Page', _attributes: { Image: '0', Bookmark: 'Cover' } },
    { _name: 'Page', _attributes: { Image: '4', Bookmark: '   ' } },
    { _name: 'Page', _attributes: { Image: '12', Bookmark: 'Outside' } },
    { _name: 'Page', _attributes: { Image: '-1', Bookmark: 'Invalid' } },
    { _name: 'Page', _attributes: { Image: '1.5', Bookmark: 'Invalid' } },
  ] }] }
  assert.deepEqual(parser.comicArchiveBookmarks(root, 12), [
    { title: 'Cover', pageIndex: 0 }, { title: 'Chapter 2', pageIndex: 10 },
  ])
})
