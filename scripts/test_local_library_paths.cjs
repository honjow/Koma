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
const archives = load('import/ArchiveImageChapters', {
  '../model/LocalLibraryFolderContract': folder, './ImageSortUtils': sort,
})
const folderBookmarks = load('import/ComicArchiveFolderBookmarks', {
  './ArchiveImageChapters': archives,
})
const folderArchive = load('import/LocalFolderArchiveReader', {
  '@kit.ArkTS': { util: {} }, '@kit.BasicServicesKit': {}, '@kit.CoreFileKit': {},
  './ArchiveExtractionService': {}, './LocalImportCoordinator': {},
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

test('HEIC and HEIF pages remain available in archives and local folders', () => {
  const pages = ['Series/Chapter/002.HEIF', 'Series/Chapter/001.heic']
  assert.deepEqual(sort.sortImageEntryPaths(pages), [pages[1], pages[0]])
  const scan = folder.scanLocalLibraryFolderEntries(pages.map(relativePath => ({ relativePath, kind: 'file' })))
  assert.deepEqual(scan.series[0].chapters[0].pages.map(page => page.relativePath), [pages[1], pages[0]])
})

test('ComicInfo retains the series description and tags along with the author', () => {
  const result = metadata.parseLocalLibrarySidecarMetadata('<ComicInfo><Writer>Alice</Writer>' +
    '<Summary>A &amp; B</Summary><Tags>Comedy, 中文，Adventure</Tags></ComicInfo>')
  assert.equal(result.status, 'ok')
  assert.deepEqual(result.metadata.authors, ['Alice'])
  assert.equal(result.metadata.description, 'A & B')
  assert.deepEqual(result.metadata.tags, ['Comedy', '中文', 'Adventure'])
})

test('unopened folder archives retain reading progress while their page catalog is deferred', () => {
  const scan = folder.scanLocalLibraryFolderEntries([{ relativePath: 'Series/Chapter 1.cbz', kind: 'file' }])
  const comic = folder.buildComicFromLocalLibraryFolderSeries(scan.series[0], { rootUri: 'file://picked/root' })
  const progress = { comicId: comic.id, chapterId: comic.chapters[0].id, pageId: 'saved-page',
    pageIndex: 5, totalPages: 20, progressRatio: 0.3, completed: false, updatedAt: 1 }
  assert.deepEqual(models.currentComicReadingProgress(comic, progress), progress)
})

test('folder discovery recognizes the same archive formats the reader opens', () => {
  const formats = ['cbz', 'zip', 'cbr', 'rar', 'cb7', '7z', 'cbt', 'tar', 'epub', 'pdf']
  const scan = folder.scanLocalLibraryFolderEntries(formats.map((ext, i) => ({
    relativePath: `Series/Chapter ${i + 1}.${ext}`, kind: 'file',
  })))
  assert.equal(scan.series.length, 1)
  assert.equal(scan.series[0].chapters.length, formats.length)
  const comic = folder.buildComicFromLocalLibraryFolderSeries(scan.series[0], { rootUri: 'file://picked/root' })
  assert.ok(comic.chapters.every(models.isDeferredFolderArchiveChapter))
})

test('nested archive chapters retain page order and expose exact reader offsets', () => {
  const pages = ids => ids.map(id => ({ id }))
  const opened = folderArchive.flattenFolderArchiveChapters([
    { title: '第1话', pages: pages(['a1', 'a2']) },
    { title: '第2话', pages: pages(['b1', 'b2', 'b3']) },
    { title: '第3话', pages: pages(['c1']) },
  ])
  assert.deepEqual(opened.pages.map(page => page.id), ['a1', 'a2', 'b1', 'b2', 'b3', 'c1'])
  assert.deepEqual(opened.bookmarks, [
    { title: '第1话', pageIndex: 0 }, { title: '第2话', pageIndex: 2 }, { title: '第3话', pageIndex: 5 },
  ])
  assert.deepEqual(folderArchive.flattenFolderArchiveChapters([{ title: 'One', pages: pages(['1']) }]).bookmarks, [])
})

test('image archive splits explicit chapter folders but leaves ambiguous folders together', () => {
  assert.deepEqual(archives.archiveImageChapters([
    'book/cover.jpg', 'book/第1话/001.jpg', 'book/第1话/002.jpg', 'book/第2话/001.jpg',
  ]), [
    { title: '第1话', paths: ['book/第1话/001.jpg', 'book/第1话/002.jpg'] },
    { title: '第2话', paths: ['book/第2话/001.jpg'] },
  ])
  assert.deepEqual(archives.archiveImageChapters(['book/images/001.jpg', 'book/extras/002.jpg']), [])
  assert.deepEqual(archives.archiveImageChapters(['book/images/001.jpg', 'book/images/002.jpg']), [])
  const nested = ['book/chapter-1/images/001.jpg', 'book/chapter-1/images/002.jpg', 'book/chapter-2/img/001.jpg']
  assert.deepEqual(archives.archiveImageChapters(nested), [
    { title: 'chapter-1', paths: nested.slice(0, 2) }, { title: 'chapter-2', paths: nested.slice(2) },
  ])
  assert.deepEqual(folderBookmarks.comicArchiveFolderBookmarks('/extract', nested.map(p => `file:///extract/${p}`)), [
    { title: 'chapter-1', pageIndex: 0 }, { title: 'chapter-2', pageIndex: 2 },
  ])
})
