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
const names = ['sortedChapterList','filteredChapterList','setSortBasis','setSortDirection','hasActiveFilters',
  'resetFilters','normalizeMetadataValue','selectedIdsInFilter','reportDisplayOrder','storageSortDirection']
const methods = owner.members.filter(n => ts.isMethodDeclaration(n) && names.includes(n.name.getText(tree)))
const getters = owner.members.filter(n => ts.isGetAccessorDeclaration(n) &&
  ['sortedChapters', 'sortedChapterIds', 'sourceOrderDescending', 'defaultSortDirection'].includes(n.name.getText(tree)))
const presentation = tree.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'ChapterListPresentation')
const presentationSource = presentation.getText(tree).replace(/@(?:ObservedV2|Trace)\s+/g,'')
const model = fs.readFileSync(path.join(base, 'model/MangaDetailModels.ets'), 'utf8')
const modelTree = ts.createSourceFile('models.ts', model, ts.ScriptTarget.Latest, true)
const enums = modelTree.statements.filter(n => ts.isEnumDeclaration(n) && ['ChapterSortBasis','ChapterSortDirection'].includes(n.name.text))
const js = ts.transpileModule(enums.map(n=>n.getText(modelTree)).join('\n') + '\n' + presentationSource + '\nclass Owner {' +
  getters.map(n => n.getText(tree).replace(/@Computed\s+/g,'')).join('\n') +
  methods.map(n => n.getText(tree).replace(/@Monitor\([^)]*\)\s+/g,'')).join('\n') +
  '} exports.make=()=>{ const o=new Owner();o.presentation=new ChapterListPresentation();return o };',
  {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
const exported = {}
const comparison = {}
const comparatorSource = fs.readFileSync(path.join(base, 'model/ChapterSortOrder.ets'), 'utf8')
const comparatorJs = ts.transpileModule(comparatorSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
new Function('exports', comparatorJs)(comparison)
const readFilter = {ALL:'all',UNREAD:'unread',READ:'read',DOWNLOADED:'downloaded'}
const chronology = {}
new Function('exports', ts.transpileModule(fs.readFileSync(path.join(base, 'model/SourceChapterChronology.ets'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText)(chronology)
new Function('exports','ChapterReadFilter','compareChapterSort','sourceCatalogDirection',js)(
  exported,readFilter,comparison.compareChapterSort,chronology.sourceCatalogDirection)
const SOURCE='source_order', NUMBER='chapter_number', UPLOAD='upload_date', NAME='name', FORWARD='forward', REVERSE='reverse'
function make(chapters) {
  const o=exported.make();o.chapters=chapters
  o.languageState={effectiveLocale:'zh-CN'}
  o.presentation.selectedChapterIds=new Set();o.rebuilds=0
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
  o.setSortBasis(NUMBER);assert.equal(o.presentation.sortDirection,REVERSE)
  assert.deepEqual(ids(),numericForward.slice().reverse())
  o.setSortDirection(FORWARD);assert.deepEqual(ids(),numericForward)
  o.setSortDirection(REVERSE);o.setSortDirection(FORWARD);assert.deepEqual(ids(),numericForward)
  assert.deepEqual(o.chapters,input);for(const item of o.sortedChapters)assert.ok(input.includes(item))
})
test('default is source order, forward; reselecting current options does not create reset state',()=>{
  const o=make([chapter('a'),chapter('b')]);assert.equal(o.presentation.sortBasis,SOURCE);assert.equal(o.presentation.sortDirection,FORWARD)
  assert.equal(o.hasActiveFilters(),false);o.setSortBasis(SOURCE);o.setSortDirection(FORWARD)
  assert.equal(o.rebuilds,0);assert.equal(o.hasActiveFilters(),false)
  o.setSortBasis(NUMBER);o.setSortDirection(REVERSE);assert.equal(o.hasActiveFilters(),true);o.resetFilters()
  assert.equal(o.presentation.sortBasis,SOURCE);assert.equal(o.presentation.sortDirection,FORWARD);assert.equal(o.hasActiveFilters(),false)
})
test('filters and batch actions use the same reversed chapter identities without modifying reading state',()=>{
  const input=[chapter('a',undefined,{isRead:true,language:'zh'}),chapter('b',undefined,{language:'en'}),
    chapter('c',undefined,{language:'zh'}),chapter('d',undefined,{language:'zh'})]
  const o=make(input);o.presentation.readFilter='unread';o.presentation.languageFilter='zh';o.presentation.selectedChapterIds=new Set(['c','d','a'])
  let displayed
  o.onDisplayOrderChange = chapters => { displayed = chapters.map(chapter => chapter.id) }
  o.setSortDirection(REVERSE);o.reportDisplayOrder();assert.deepEqual(displayed,['d','c']);assert.deepEqual(o.selectedIdsInFilter(),['d','c'])
  o.setSortDirection(FORWARD);o.reportDisplayOrder();assert.deepEqual(displayed,['c','d']);assert.equal(input[0].isRead,true)
})
test('upload date and localized name sort the view without changing the source list',()=>{
  // The user requested the four Mihon sort choices in place of the old two-choice baseline.
  const input=Object.freeze([chapter('b',2,{title:'猫',dateUpload:300}),chapter('a',1,{title:'狗',dateUpload:500}),
    chapter('c',3,{title:'猪'})])
  const o=make(input), ids=()=>o.sortedChapters.map(c=>c.id)
  o.setSortBasis(UPLOAD);assert.deepEqual(ids(),['c','b','a'])
  o.setSortDirection(REVERSE);assert.deepEqual(ids(),['a','b','c'])
  o.setSortBasis(NAME);assert.deepEqual(ids(),['c','b','a'])
  o.setSortDirection(FORWARD);assert.deepEqual(ids(),['a','b','c'])
  o.setSortBasis(SOURCE);assert.deepEqual(ids(),['b','a','c'])
  assert.equal(o.chapters,input)
})
test('new catalogs are projected through the current mode and direction without a separate mutable sorted copy',()=>{
  const o=make([chapter('old')]);o.setSortDirection(REVERSE)
  o.chapters=[chapter('first'),chapter('second'),chapter('third')]
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['third','second','first'])
})

test('newest-first source records retain their view while menu ascending follows source positions, including unnumbered entries',()=>{
  const rows=[chapter('334',334,{readingOrder:2,readingGroup:'catalog'}),
    chapter('profile',undefined,{readingOrder:1,readingGroup:'catalog'}),
    chapter('001',1,{readingOrder:0,readingGroup:'catalog'})]
  const o=make(rows),ids=()=>o.sortedChapters.map(c=>c.id)
  assert.equal(o.storageSortDirection(o.presentation.sortDirection),REVERSE)
  assert.deepEqual(ids(),['334','profile','001'])
  o.setSortDirection(o.storageSortDirection(FORWARD))
  assert.deepEqual(ids(),['001','profile','334'])
  o.setSortBasis(NUMBER)
  assert.equal(o.storageSortDirection(o.presentation.sortDirection),FORWARD)
  o.setSortBasis(SOURCE)
  assert.deepEqual(ids(),['001','profile','334'])
  assert.equal(o.chapters,rows)
})

test('changing sort basis preserves the selected semantic direction; chapter numbers cannot override declared positions',()=>{
  const rows=[chapter('new',1,{readingOrder:1,readingGroup:'catalog'}),
    chapter('old',9,{readingOrder:0,readingGroup:'catalog'})]
  const o=make(rows)
  assert.equal(chronology.sourceCatalogDirection(rows),'newest_first')
  o.setSortBasis(NUMBER)
  assert.equal(o.presentation.sortDirection,REVERSE)
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['old','new'])
  o.setSortBasis(SOURCE)
  assert.equal(o.presentation.sortDirection,FORWARD)
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['new','old'])
  assert.equal(chronology.sourceCatalogDirection([chapter('numbered',10),chapter('lower',1)]),undefined)
})

test('oldest-first catalogs reset to chronological descending while saved raw-array choices remain selectable',()=>{
  const o=make([chapter('profile',undefined,{readingOrder:0,readingGroup:'catalog'}),
    chapter('001',1,{readingOrder:1,readingGroup:'catalog'})])
  o.sourceOrder='oldest_first'
  assert.equal(o.defaultSortDirection,REVERSE)
  assert.equal(o.hasActiveFilters(),true)
  o.resetFilters()
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['001','profile'])
  assert.equal(o.storageSortDirection(o.presentation.sortDirection),REVERSE)
  assert.equal(o.hasActiveFilters(),false)
  o.setSortDirection(o.storageSortDirection(FORWARD))
  assert.deepEqual(o.sortedChapters.map(c=>c.id),['profile','001'])
})
