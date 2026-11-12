const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const file = path.resolve(__dirname, '../entry/src/main/ets/import/LegacyEpubOrder.ets')
const js = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
const api = {}
new Function('exports', js)(api)

function fixture() {
  const pages = ['one.jpg', 'two.jpg', 'two.jpg', 'aux.jpg', 'three.jpg'].map((name, index) => ({
    id: `old-${index}`, comicId: 'book', chapterId: 'chapter', index, fileName: name,
    uri: `file:///data/import/book/extract/OEBPS/${name}`, sortKey: name,
  }))
  const comic = { id: 'book', sourcePath: 'book.epub', pageCount: pages.length,
    chapters: [{ id: 'chapter', pageCount: pages.length, pages }],
    localImportOrigin: { kind: 'archive', sourceUris: ['book.epub'] } }
  const position = { comicId: 'book', chapterId: 'chapter', pageId: 'old-2', pageIndex: 2,
    totalPages: 5, progressRatio: 0.6, completed: false, updatedAt: 123 }
  return { comic, position }
}
const root = '/data/import/book/extract'
const ordered = ['OEBPS/one.jpg', 'OEBPS/two.jpg', 'OEBPS/three.jpg']

test('legacy EPUB preserves current image and chapter identity while removing auxiliary pages', () => {
  const { comic, position } = fixture()
  const plan = api.planLegacyEpubOrder(comic, root, ordered, [position])
  assert.deepEqual(plan.anchoredPageIds, ['old-2'])
  assert.deepEqual(plan.comic.chapters[0].pages.map(page => page.id), ['old-0', 'old-2', 'old-4'])
  assert.deepEqual(plan.comic.chapters[0].pages.map(page => page.index), [0, 1, 2])
  assert.equal(plan.comic.chapters[0].id, 'chapter')
  assert.equal(plan.comic.localImportOrigin.epubOrderRevision, 1)
  assert.equal(comic.pageCount, 5)
  assert.equal(position.updatedAt, 123)
})

test('legacy EPUB stays unchanged if its saved page is missing or ambiguous', () => {
  const { comic, position } = fixture()
  const absent = { ...position, pageId: 'old-3', pageIndex: 3 }
  assert.equal(api.planLegacyEpubOrder(comic, root, ordered, [absent]), undefined)
  const other = { ...position, pageId: 'old-1', pageIndex: 1 }
  assert.equal(api.planLegacyEpubOrder(comic, root, ordered, [position, other]), undefined)
  assert.equal(api.planLegacyEpubOrder(comic, root, [...ordered, ordered[1]], []), undefined)
  assert.equal(comic.pageCount, 5)
})

test('legacy progress without a page ID anchors its old visible page', () => {
  const { comic, position } = fixture()
  const legacy = { ...position, pageId: undefined }
  assert.deepEqual(api.planLegacyEpubOrder(comic, root, ordered, [legacy]).anchoredPageIds, ['old-2'])
})
