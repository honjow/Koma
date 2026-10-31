// Execute the production recorder, aggregation and reader document owner. Device UI is separate.
const test = require('node:test'), assert = require('node:assert/strict')
const fs = require('node:fs'), path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets')
function compile(file, dependencies = {}) {
  const module = { exports: {} }
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  new Function('require', 'module', 'exports', js)(name => {
    assert.ok(Object.hasOwn(dependencies, name), `Missing port ${name}`)
    return dependencies[name]
  }, module, module.exports)
  return module.exports
}
const stats = compile('model/ReadingStatistics')
const models = compile('model/ComicModels', { '../i18n/AppStrings': { AppStrings: {} } })
const owner = compile('model/ReaderSessionStore', {
  '../sourceRuntime/SourceRuntimeAppRegistry': {}, './SourceTextPageDescriptor': {},
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn() {} } }, './AppFileTextPersistence': {},
  '@kit.CoreFileKit': { fileIo: {} }, './ComicModels': models,
  './ReaderChapterSequence': compile('model/ReaderChapterSequence'), '../i18n/AppStrings': { AppStrings: {} },
  './RemoteReaderSession': {}, './ChapterReadStateStore': {},
})
test('foreground sessions exclude background, deduplicate pages and change chapter without double counting', () => {
  let now = 1000; const records = []
  const recorder = new stats.ReadingSessionRecorder(row => records.push(row), () => now)
  recorder.observe('a', '1', 0); assert.equal(records.length, 0)
  recorder.setActive(true)
  recorder.observe('a', '1', 0)
  now += 5000; recorder.observe('a', '1', 1); recorder.observe('a', '1', 0)
  now += 5000; recorder.observe('a', '2', 0)
  now += 2000; recorder.setActive(false)
  now += 3600000; recorder.setActive(false)
  recorder.setActive(true); now += 3000; recorder.close(); recorder.close()
  assert.deepEqual(records.map(r => [r.chapterId, r.endedAt-r.startedAt, r.pagesRead]), [
    ['1',10000,2],['2',2000,1],['2',3000,1],
  ])
  recorder.setActive(true); recorder.observePages('a','spread',[0,1]); now+=1000
  recorder.observePages('a','spread',[1,2]); now+=1000; recorder.setActive(false)
  recorder.setActive(true); now+=1000; recorder.close()
  assert.deepEqual(records.slice(-2).map(r=>r.pagesRead),[3,2], 'Spreads/continuous count actual unique pages, also after resume')
})
test('Shared Reader reports all visible pages after committing the new chapter, without rewriting fractional progress', () => {
  const source = fs.readFileSync(path.join(root,'readerLab/KomaReaderLabPage.ets'),'utf8')
    .replace('export struct KomaReaderLabPage','export class KomaReaderLabPage')
  const tree = ts.createSourceFile('page.ts',source,ts.ScriptTarget.Latest,true)
  const declaration = tree.statements.find(node=>ts.isClassDeclaration(node)&&node.name?.text==='KomaReaderLabPage')
  const method = declaration.members.find(node=>ts.isMethodDeclaration(node)&&node.name?.getText(tree)==='onObservedPosition')
  const module = { exports: {} }
  const js = ts.transpileModule('class Reader {'+method.getText(tree)+'} exports.Reader=Reader',{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS},
  }).outputText
  new Function('exports',js)(module.exports)
  const key={scope:'koma-local',work:'a',unit:'new',equals(other){return other?.unit===this.unit},copy(){return this}}
  let committed='old', writes=0, now=0;const records=[]
  const recorder=new stats.ReadingSessionRecorder(record=>records.push(record),()=>now)
  recorder.setActive(true)
  const reader=Object.assign(new module.exports.Reader(),{
    session:{snapshot:()=>({phase:'ready',unit:{key},policy:{firstPageAlone:false}}),setPreloadDepth(){}},
    readerClosed:false,routeActive:true,labVisibility:{foreground:true},hostPreferences:{columnMode:'odd_left'},
    request:{progressReadWrite:true},observedCatalogUnit:null,readerPreloadDepth:()=>2,
    adapter:{sessionConfig:()=>({chapterId:'new'})},catalogHost:{commit(_key,config){committed=config.chapterId}},
    syncChapterChoices(){},observeTranslationPosition(){},persistObserved(){writes++},
    observeReadingPages(work,chapter,pages){assert.equal(committed,chapter);recorder.observePages(work,chapter,pages)},
  })
  const position={anchor:{unit:key,pageKey:'0',sourceIndexHint:0},displayedSourceIndexes:[0,1],pageCount:4,terminalSourceDisplayed:false}
  reader.onObservedPosition(position);now+=1000
  reader.onObservedPosition({...position,displayedSourceIndexes:[0,1,2]});now+=1000;recorder.close()
  assert.equal(writes,1);assert.equal(records[0].pagesRead,3)
})
test('calendar/month/year statistics use actual sessions and keep zero-activity days', () => {
  const record = (book, year, month, day, pages = 1) => {
    const start = new Date(year, month-1, day, 12).getTime()
    return { comicId: book, chapterId: '1', startedAt: start, endedAt: start+60000, pagesRead: pages }
  }
  const now = new Date(2026,2,1,16).getTime()
  const rows = [record('a',2026,2,27,3),record('b',2026,2,28,2),record('a',2026,3,1,4),record('c',2025,12,31)]
  const month = stats.summarizeReadingSessions(rows, 'month', now, now)
  assert.deepEqual([month.durationMs,month.pagesRead,month.booksRead,month.currentStreak,month.longestStreak], [60000,4,1,3,3])
  assert.equal(stats.readingCalendarDays(month,'month',now,now).length,31)
  assert.equal(stats.readingCalendarDays(month,'month',now,now)[1].pagesRead,0)
  assert.equal(stats.summarizeReadingSessions(rows,'year',now,now).pagesRead,9)
  assert.equal(stats.summarizeReadingSessions(rows,'all',now,now).booksRead,3)
  assert.equal(stats.summarizeReadingSessions([], 'all', now, now).durationMs,0,'Old timestamps do not invent time')
  assert.equal(stats.summarizeReadingSessions(rows,'all',now,now+3*86400000).currentStreak,0)
})
test('sessions persist with the reader document, survive backup normalization and recover failed history deletion', () => {
  let disk = { progress: [], sourceHistory: [], chapters: [] }, fail = false
  const clone = value => JSON.parse(JSON.stringify(value))
  const adapter = { loadSnapshot: () => clone(disk), saveSnapshot(value) { if(fail) throw Error('disk full'); disk=clone(value) } }
  const store = new owner.PersistentReaderSessionStore(adapter)
  const record = { comicId:'a',chapterId:'1',startedAt:1000,endedAt:11000,pagesRead:2 }
  store.addReadingSession(record); assert.equal(store.flush(),true)
  const fresh = new owner.PersistentReaderSessionStore(adapter)
  assert.deepEqual(fresh.listReadingSessions(),[record])
  const backup = owner.normalizeReaderSessionBackupPayload(JSON.stringify({schemaVersion:4,...disk}))
  assert.deepEqual(JSON.parse(backup).readingSessions,[record])
  assert.deepEqual(JSON.parse(owner.normalizeReaderSessionBackupPayload('{"schemaVersion":1,"progress":[]}')).readingSessions,[])
  fail=true
  store.saveProgress({comicId:'a',chapterId:'1',pageIndex:0,totalPages:2,completed:false,updatedAt:1})
  assert.equal(store.removeHistoryEntries(['a']),false)
  assert.deepEqual(store.listReadingSessions(),[record])
  fail=false; assert.equal(store.removeHistoryEntries(['a']),true)
  assert.deepEqual(new owner.PersistentReaderSessionStore(adapter).listReadingSessions(),[])
  fresh.addReadingSession({ ...record, comicId: 'only-session' }); fresh.flush()
  assert.equal(fresh.removeHistoryEntries(['only-session']),true)
  assert.equal(fresh.listReadingSessions().some(row => row.comicId === 'only-session'),false)
  const memory = new owner.InMemoryReaderSessionStore()
  memory.addReadingSession(record); memory.removeHistoryEntries(['a'])
  assert.deepEqual(memory.listReadingSessions(),[])
})
