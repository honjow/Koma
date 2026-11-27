const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function load(file, ports = {}) {
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8').replace(/@Concurrent\s*/g, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exports = {}
  new Function('require', 'exports', js)(name => {
    if (!Object.hasOwn(ports, name)) throw Error('Unexpected import: ' + name)
    return ports[name]
  }, exports)
  return exports
}
const models = load('model/ComicModels')
const pdf = load('import/PdfPageService', { '@kit.ArkTS': {}, '@kit.PDFKit': {}, '@kit.ImageKit': {} })
const zipPage = load('import/ComicZipPage', {
  '@kit.ArkTS': {}, './ImageSortUtils': load('import/ImageSortUtils'), './NativeArchiveExtraction': { nativeComicArchive: {
    readZipEntry: async (_path, entry) => Uint8Array.from(Buffer.from(entry)).buffer,
  } },
})
const api = load('import/LocalImportCommitService', {
  '@kit.CoreFileKit': { hash: { hash: async path => Buffer.from(path.split('/').pop()).toString('hex') } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: { createMd() {
    let data
    return { update: async blob => { data = blob.data }, digest: async () => ({ data }) }
  } } },
  '@kit.ArkTS': { util: { generateRandomUUID: () => 'new-id' } },
  '../model/ComicModels': models, '../model/BackupRestoreActivity': {}, '../model/LibraryPersistence': {},
  './PdfPageService': pdf, './ComicZipPage': zipPage, './ImageSortUtils': load('import/ImageSortUtils'),
})
const sameOrder = () => new Map([[0, 0], [1, 1], [2, 2]])
function comic(id, root) {
  const chapters = ['one', 'two', 'three'].map((name, index) => ({ id: `${id}-${name}`, comicId:id,
    title:name,index,sourcePath:'file://book.zip#'+name,pages:[{ id:`${id}-${name}-p`,comicId:id,chapterId:`${id}-${name}`,index:0,
      uri:`file://${root}/${name}.jpg` }],pageCount:1,createdAt:1 }))
  return { id,title:'Title',sortTitle:'title',sourceKind:models.ComicSourceKind.LOCAL_ARCHIVE,
    localImportOrigin:{kind:'archive',sourceUris:['file://book.zip']},chapters,createdAt:1 }
}
test('reimporting the same multi-chapter archive keeps every chapter and page identity', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.author = 'Archive author'
  old.coverUri = old.chapters[1].pages[0].uri
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  const merged = api.mergeLocalImport(old,fresh,sameOrder())
  assert.deepEqual(merged.chapters.map(chapter => chapter.id),['old-one','old-two','old-three'])
  assert.deepEqual(merged.chapters.map(chapter => chapter.pages[0].id),['old-one-p','old-two-p','old-three-p'])
  assert.equal(merged.coverUri,'file:///new/two.jpg')
  assert.equal(merged.chapters[2].pages[0].comicId,'old')
  assert.equal(merged.author,'Archive author')
})
test('reimport does not replace a user-edited author', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.author = 'Custom'; fresh.author = 'Archive author'
  assert.equal(api.mergeLocalImport(old,fresh,sameOrder()).author,'Custom')
})
test('reimport fills a missing description but preserves an existing one', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(old,fresh,sameOrder()).subtitle,'Archive description')
  const oldWithDescription = comic('old','/old'), newer = comic('fresh','/new')
  oldWithDescription.subtitle = 'Previously saved'; newer.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(oldWithDescription,newer,sameOrder()).subtitle,'Previously saved')
})
test('PDF reimport compares the original document and keeps page identities', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  for (const [value, rootPath] of [[old, '/old'], [fresh, '/new']]) {
    value.chapters.forEach((chapter, index) => { chapter.pages[0].uri = pdf.pdfPageUri(rootPath + '/book.pdf', index) })
  }
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  assert.equal(api.mergeLocalImport(old, fresh, sameOrder()).chapters[1].pages[0].id, 'old-two-p')
  fresh.chapters[1].pages[0].uri = pdf.pdfPageUri('/new/book.pdf', 9)
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), new Map([[0, 0], [2, 2]]))
})
test('PDF reimport replaces its generated cover but retains a custom cover', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  old.coverUri = 'file:///old/extract/cover.jpg'; fresh.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(old, fresh, sameOrder()).coverUri, 'file:///new/extract/cover.jpg')
  const custom = comic('old','/old'), newer = comic('fresh','/new')
  custom.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  custom.coverUri = 'file:///custom.jpg'; custom.customCoverUri = custom.coverUri
  newer.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(custom, newer, sameOrder()).coverUri, custom.coverUri)
})

test('EPUB reimport updates the automatic cover and keeps a personal cover and page identity', () => {
  const old = comic('old', '/old')
  const fresh = comic('fresh', '/new')
  fresh.localImportOrigin.sourceUris = ['file://book.epub']
  const expectedCover = 'file:///new/cover.png'
  fresh.coverUri = expectedCover
  old.coverUri = old.chapters[0].pages[0].uri
  assert.equal(api.mergeLocalImport(old, structuredClone(fresh), sameOrder()).coverUri, expectedCover)
  old.customCoverUri = 'file:///personal.png'
  old.coverUri = old.customCoverUri
  old.personalNotes = 'Keep this note'
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.equal(merged.coverUri, old.customCoverUri)
  assert.equal(merged.sourceCoverUri, expectedCover)
  assert.equal(merged.personalNotes, old.personalNotes)
  assert.equal(merged.chapters[0].pages[0].id, old.chapters[0].pages[0].id)
})
test('a changed chapter is not mistaken for the same archive contents', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.chapters[1].pages[0].uri = 'file:///new/changed.jpg'
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), new Map([[0, 0], [2, 2]]))
})

test('a CBZ reimport keeps the personal cover, enhancement, and notes', () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  fresh.localImportOrigin.sourceUris = old.localImportOrigin.sourceUris = ['file://book.cbz']
  old.customCoverUri = old.coverUri = 'file:///personal-cover.png'
  old.sourceCoverUri = old.chapters[0].pages[0].uri
  old.enhancedCoverUri = 'file:///personal-enhanced.png'
  old.personalNotes = 'Keep this note'
  fresh.coverUri = fresh.chapters[0].pages[0].uri
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.equal(merged.customCoverUri, old.customCoverUri)
  assert.equal(merged.enhancedCoverUri, old.enhancedCoverUri)
  assert.equal(merged.personalNotes, old.personalNotes)
  assert.equal(merged.sourceCoverUri, 'file:///new/one.jpg')
})

test('reimporting a changed archive preserves unchanged chapters even when a new chapter shifts them', async () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  const added = structuredClone(fresh.chapters[0])
  added.sourcePath = 'file://book.zip#added'
  added.title = 'new chapter'
  added.pages[0].uri = 'file:///new/added.jpg'
  fresh.chapters[1].pages[0].uri = 'file:///new/replaced.jpg'
  fresh.chapters.unshift(added)
  const merged = api.mergeLocalImport(old, fresh, await api.matchLocalImportChapters(old, fresh))
  assert.equal(merged.chapters[1].pages[0].id, 'old-one-p')
  assert.notEqual(merged.chapters[2].id, 'old-two')
  assert.equal(merged.chapters[3].pages[0].id, 'old-three-p')
  const position = { comicId: old.id, chapterId: 'old-three', pageId: 'old-three-p', pageIndex: 0, totalPages: 1 }
  assert.equal(models.currentComicReadingProgress(merged, position), position)
  assert.equal(models.currentComicReadingProgress(merged, { ...position, chapterId: 'old-two', pageId: 'old-two-p' }), undefined)
})

test('ZIP reimport preserves page IDs when replacing an older extracted copy', async () => {
  const old = comic('old', '/old'), fresh = comic('fresh', '/new')
  for (const chapter of fresh.chapters) {
    const page = chapter.pages[0]
    page.uri = zipPage.comicZipPageUri('/new/archive.zip', page.uri.split('/').pop())
  }
  assert.deepEqual(await api.matchLocalImportChapters(old, fresh), sameOrder())
  const edited = comic('edited', '/old')
  edited.chapters[1].pages[0].uri = 'file:///old/replaced.jpg'
  assert.deepEqual(await api.matchLocalImportChapters(edited, fresh), new Map([[0, 0], [2, 2]]))
  const merged = api.mergeLocalImport(old, fresh, sameOrder())
  assert.deepEqual(merged.chapters.map(chapter => chapter.pages[0].id), ['old-one-p', 'old-two-p', 'old-three-p'])
})
