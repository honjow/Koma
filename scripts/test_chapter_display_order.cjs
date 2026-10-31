// Executes the real chapter component's non-UI methods. Native menu/Repeat
// rendering is accepted separately on device, not inferred from these checks.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base = path.join(__dirname, '../entry/src/main/ets')
const source = fs.readFileSync(path.join(base, 'components/ChapterListSection.ets'), 'utf8')
  .replace('export struct ChapterListSection', 'export class ChapterListSection')
const tree = ts.createSourceFile('chapter.ts', source, ts.ScriptTarget.Latest, true)
const owner = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'ChapterListSection')
const names = ['sortedChapterList','filteredChapterList','chapterNumberValue','setSortBasis','setSortDirection','hasActiveFilters',
  'resetFilters','normalizeMetadataValue','selectedIdsInFilter','filteredChapterIds']
const methods = owner.members.filter(n => ts.isMethodDeclaration(n) && names.includes(n.name.getText(tree)))
const getter = owner.members.find(n => ts.isGetAccessorDeclaration(n) && n.name.getText(tree) === 'sortedChapters')
const initial = name => owner.members.find(n => n.name?.getText(tree) === name).initializer.getText(tree)
const model = fs.readFileSync(path.join(base, 'model/MangaDetailModels.ets'), 'utf8')
const modelTree = ts.createSourceFile('models.ts', model, ts.ScriptTarget.Latest, true)
const enums = modelTree.statements.filter(n => ts.isEnumDeclaration(n) && ['ChapterSortBasis','ChapterSortDirection'].includes(n.name.text))
const js = ts.transpileModule(enums.map(n=>n.getText(modelTree)).join('\n') + '\nclass Owner {' +
  getter.getText(tree).replace(/@Computed\s+/g,'') + methods.map(n => n.getText(tree)).join('\n') +
  '} exports.make=()=>{ const o=new Owner();o.sortBasis=' + initial('sortBasis') + ';o.sortDirection=' + initial('sortDirection') + ';return o };',
  {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
const exported = {}
const readFilter = {ALL:'all',UNREAD:'unread',READ:'read',DOWNLOADED:'downloaded'}
new Function('exports','ChapterReadFilter',js)(exported,readFilter)
const SOURCE='source_order', NUMBER='chapter_number', FORWARD='forward', REVERSE='reverse'
function make(chapters) {
  const o=exported.make();o.chapters=chapters;o.readFilter='all';o.languageFilter='';o.groupFilter='';o.bookmarkFilter='all'
  o.selectedChapterIds=new Set();o.rebuilds=0
  o.rebuildDataSource=()=>{o.rebuilds++}
  o.savePreferences=()=>{} // Persistence is exercised by its store contract, not this projection test.
  return o
}
const chapter=(id,chapterNumber,extra={})=>Object.freeze({id,title:id,chapterNumber,isRead:false,isDownloaded:false,...extra})
for(const [label,chapters,numericForward] of [
  ['no numbers',[chapter('third'),chapter('first'),chapter('second')],['third','first','second']],
  ['duplicate numbers',[chapter('a',8),chapter('b',8),chapter('c',2)],['c','a','b']],
  ['mixed numbers',[chapter('noticeA'),chapter('two',2),chapter('noticeB'),chapter('nine',9)],['noticeA','noticeB','two','nine']],
  ['numbered',[chapter('two',2),chapter('zero',0),chapter('ten',10)],['zero','two','ten']],
  ['empty',[],[]],['one',[chapter('only')],['only']],
  ['nonfinite metadata',[chapter('nan',NaN),chapter('inf',Infinity),chapter('one',1)],['nan','inf','one']],
])test(label+': source order is independent of numbers; both modes reverse every entry without mutating the catalog',()=>{
  const input=Object.freeze(chapters.slice()),o=make(input),ids=()=>o.sortedChapters.map(c=>c.id)
  assert.deepEqual(ids(),input.map(c=>c.id))
  o.setSortDirection(REVERSE);assert.deepEqual(ids(),input.map(c=>c.id).reverse())
  o.setSortBasis(NUMBER);assert.equal(o.sortDirection,REVERSE)
  assert.deepEqual(ids(),numericForward.slice().reverse())
  o.setSortDirection(FORWARD);assert.deepEqual(ids(),numericForward)
  o.setSortDirection(REVERSE);o.setSortDirection(FORWARD);assert.deepEqual(ids(),numericForward)
  assert.deepEqual(o.chapters,input);for(const item of o.sortedChapters)assert.ok(input.includes(item))
})
test('default is source order, forward; reselecting current options does not create reset state',()=>{
  const o=make([chapter('a'),chapter('b')]);assert.equal(o.sortBasis,SOURCE);assert.equal(o.sortDirection,FORWARD)
  assert.equal(o.hasActiveFilters(),false);o.setSortBasis(SOURCE);o.setSortDirection(FORWARD)
  assert.equal(o.rebuilds,0);assert.equal(o.hasActiveFilters(),false)
  o.setSortBasis(NUMBER);o.setSortDirection(REVERSE);assert.equal(o.hasActiveFilters(),true);o.resetFilters()
  assert.equal(o.sortBasis,SOURCE);assert.equal(o.sortDirection,FORWARD);assert.equal(o.hasActiveFilters(),false)
})
test('filters and batch actions use the same reversed chapter identities without modifying reading state',()=>{
  const input=[chapter('a',undefined,{isRead:true,language:'zh'}),chapter('b',undefined,{language:'en'}),
    chapter('c',undefined,{language:'zh'}),chapter('d',undefined,{language:'zh'})]
  const o=make(input);o.readFilter='unread';o.languageFilter='zh';o.selectedChapterIds=new Set(['c','d','a'])
  o.setSortDirection(REVERSE);assert.deepEqual(o.filteredChapterIds(),['d','c']);assert.deepEqual(o.selectedIdsInFilter(),['d','c'])
  o.setSortDirection(FORWARD);assert.deepEqual(o.filteredChapterIds(),['c','d']);assert.equal(input[0].isRead,true)
})
test('each state domain has exactly the two exposed choices, without hidden legacy defaults',()=>{
  assert.deepEqual(Object.values(exported.ChapterSortBasis).sort(),[SOURCE,NUMBER].sort())
  assert.deepEqual(Object.values(exported.ChapterSortDirection).sort(),[FORWARD,REVERSE].sort())
})
test('new catalogs are projected through the current mode and direction without a separate mutable sorted copy',()=>{
  const o=make([chapter('old')]);o.setSortDirection(REVERSE)
  o.chapters=[chapter('first'),chapter('second'),chapter('third')]
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['third','second','first'])
})
