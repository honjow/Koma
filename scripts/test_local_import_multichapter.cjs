const assert = require('node:assert/strict')
const test = require('node:test')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function load(file, ports = {}) {
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8'), {
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
const api = load('import/LocalImportCommitService', {
  '@kit.CoreFileKit': { hash: { hash: async path => path.split('/').pop() } },
  '@kit.ArkTS': { util: { generateRandomUUID: () => 'new-id' } },
  '../model/ComicModels': models, '../model/BackupRestoreActivity': {}, '../model/LibraryPersistence': {},
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
test('a changed chapter is not mistaken for the same archive contents', async () => {
  const old = comic('old','/old'), fresh = comic('fresh','/new')
  fresh.chapters[1].pages[0].uri = 'file:///new/changed.jpg'
  assert.equal(await api.sameOrderedLocalImportPages(old,fresh),false)
})
