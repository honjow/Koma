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
const api = load('import/LocalImportCommitService', {
  '@kit.CoreFileKit': { hash: { hash: async path => path.split('/').pop() } },
  '@kit.ArkTS': { util: { generateRandomUUID: () => 'new-id' } },
  '../model/ComicModels': models, '../model/BackupRestoreActivity': {}, '../model/LibraryPersistence': {}, './PdfPageService': pdf,
})
function comic(id, root) {
  const chapters = ['one', 'two', 'three'].map((name, index) => ({ id: `${id}-${name}`, comicId:id,
    title:name,index,pages:[{ id:`${id}-${name}-p`,comicId:id,chapterId:`${id}-${name}`,index:0,
      uri:`file://${root}/${name}.jpg` }],pageCount:1,createdAt:1 }))
  return { id,title:'Title',sortTitle:'title',sourceKind:models.ComicSourceKind.LOCAL_ARCHIVE,
    localImportOrigin:{kind:'archive',sourceUris:['file://book.zip']},chapters,createdAt:1 }
}
test('reimporting the same multi-chapter archive keeps every chapter and page identity', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.author = 'Archive author'
  old.coverUri = old.chapters[1].pages[0].uri
  assert.equal(await api.sameOrderedLocalImportPages(old,fresh),true)
  const merged = api.mergeLocalImport(old,fresh,true)
  assert.deepEqual(merged.chapters.map(chapter => chapter.id),['old-one','old-two','old-three'])
  assert.deepEqual(merged.chapters.map(chapter => chapter.pages[0].id),['old-one-p','old-two-p','old-three-p'])
  assert.equal(merged.coverUri,'file:///new/two.jpg')
  assert.equal(merged.chapters[2].pages[0].comicId,'old')
  assert.equal(merged.author,'Archive author')
})
test('reimport does not replace a user-edited author', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.author = 'Custom'; fresh.author = 'Archive author'
  assert.equal(api.mergeLocalImport(old,fresh,true).author,'Custom')
})
test('reimport fills a missing description but preserves an existing one', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(old,fresh,true).subtitle,'Archive description')
  const oldWithDescription = comic('old','/old'), newer = comic('fresh','/new')
  oldWithDescription.subtitle = 'Previously saved'; newer.subtitle = 'Archive description'
  assert.equal(api.mergeLocalImport(oldWithDescription,newer,true).subtitle,'Previously saved')
})
test('PDF reimport compares the original document and keeps page identities', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  for (const [value, rootPath] of [[old, '/old'], [fresh, '/new']]) {
    value.chapters.forEach((chapter, index) => { chapter.pages[0].uri = pdf.pdfPageUri(rootPath + '/book.pdf', index) })
  }
  assert.equal(await api.sameOrderedLocalImportPages(old, fresh), true)
  assert.equal(api.mergeLocalImport(old, fresh, true).chapters[1].pages[0].id, 'old-two-p')
  fresh.chapters[1].pages[0].uri = pdf.pdfPageUri('/new/book.pdf', 9)
  assert.equal(await api.sameOrderedLocalImportPages(old, fresh), false)
})
test('PDF reimport replaces its generated cover but retains a custom cover', () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  old.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  old.coverUri = 'file:///old/extract/cover.jpg'; fresh.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(old, fresh, true).coverUri, 'file:///new/extract/cover.jpg')
  const custom = comic('old','/old'), newer = comic('fresh','/new')
  custom.chapters[0].pages[0].uri = pdf.pdfPageUri('/old/archive.zip', 0)
  custom.coverUri = 'file:///custom.jpg'; custom.customCoverUri = custom.coverUri
  newer.coverUri = 'file:///new/extract/cover.jpg'
  assert.equal(api.mergeLocalImport(custom, newer, true).coverUri, custom.coverUri)
})
test('a changed chapter is not mistaken for the same archive contents', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.chapters[1].pages[0].uri = 'file:///new/changed.jpg'
  assert.equal(await api.sameOrderedLocalImportPages(old,fresh),false)
})
