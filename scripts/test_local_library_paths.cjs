const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function load(file, ports = {}) {
  const source = fs.readFileSync(path.join(root, file + '.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  const exports = {}
  new Function('require', 'exports', js)(name => {
    if (!Object.hasOwn(ports, name)) throw new Error('Unexpected import: ' + name)
    return ports[name]
  }, exports)
  return exports
}
const sort = load('import/ImageSortUtils')
const metadata = load('model/LocalLibraryMetadataService', { '../import/ImageSortUtils': sort })
const models = load('model/ComicModels')
const folder = load('model/LocalLibraryFolderContract', {
  '@kit.ArkTS': { util: {} }, '../import/ImageSortUtils': sort,
  './ComicModels': models, './LocalLibraryMetadataService': metadata,
})
test('ordinary colon filenames scan and resolve to encoded local folder paths', () => {
  const original = 'A: Series/Chapter: Start/page: 01.jpg'
  const scan = folder.scanLocalLibraryFolderEntries([{ relativePath: original, kind: 'file' }])
  assert.equal(scan.rejectedEntries.length, 0)
  assert.equal(scan.series.length, 1)
  assert.equal(scan.series[0].chapters[0].pages[0].relativePath, original)
  assert.equal(folder.localLibraryFolderUri('file://picked/root', original),
    'file://picked/root/A%3A%20Series/Chapter%3A%20Start/page%3A%2001.jpg')
  assert.equal(metadata.validateLocalLibraryCoverOverridePath('covers/cover: front.jpg'), 'covers/cover: front.jpg')
  for (const bad of ['../outside.jpg', '/absolute.jpg', 'C:/outside.jpg', 'series/../outside.jpg']) {
    assert.throws(() => folder.normalizeLocalLibraryRelativePath(bad))
    assert.throws(() => metadata.validateLocalLibraryCoverOverridePath(bad))
  }
})

test('unopened folder archives retain reading progress while their page catalog is deferred', () => {
  const scan = folder.scanLocalLibraryFolderEntries([{ relativePath: 'Series/Chapter 1.cbz', kind: 'file' }])
  const comic = folder.buildComicFromLocalLibraryFolderSeries(scan.series[0], { rootUri: 'file://picked/root' })
  const progress = { comicId: comic.id, chapterId: comic.chapters[0].id, pageId: 'saved-page',
    pageIndex: 5, totalPages: 20, progressRatio: 0.3, completed: false, updatedAt: 1 }
  assert.deepEqual(models.currentComicReadingProgress(comic, progress), progress)
})
