const test=require('node:test'), assert=require('node:assert/strict')
const fs=require('node:fs'), path=require('node:path')
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const base=path.resolve(__dirname,'../entry/src/main/ets')
const read=name=>fs.readFileSync(path.join(base,name+'.ets'),'utf8')
const compile=source=>ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
const ReadingDirection={LEFT_TO_RIGHT:'left_to_right',RIGHT_TO_LEFT:'right_to_left',WEBTOON:'webtoon'}
const storeAst=ts.createSourceFile('store.ts',read('model/ReaderPreferencesStore'),ts.ScriptTarget.Latest,true)
const pair={}
new Function('exports','ReadingDirection',compile(['readerModeSelection','readerDirectionSelection'].map(name=>storeAst.statements.find(node=>node.name?.text===name).getText(storeAst)).join('\n')))(pair,ReadingDirection)
function moduleFrom(name,dependencies){const exports={};new Function('exports','require',compile(read(name)))(exports,name=>{assert.ok(name in dependencies,name);return dependencies[name]});return exports}
class Policy { constructor(){this.layout='single';this.pagingAxis='horizontal';this.direction='ltr'} copy(){return Object.assign(new Policy(),this)} }
const dependencies={'@reader-kit/core':{ReaderDisplayPolicy:Policy},'../model/ComicModels':{ReadingDirection},
  '../model/ReaderPreferencesStore':{...pair,normalizeReaderPreferences:value=>({...value})}}
const {KomaReaderPreferenceBridge:Bridge}=moduleFrom('readerLab/KomaReaderPreferenceBridge',dependencies)
const {KomaReaderInitialPolicy:Initial}=moduleFrom('readerLab/KomaReaderInitialPolicy',dependencies)
function method(file,owner,name){const source=read(file).replace(/\bstruct /g,'class '),ast=ts.createSourceFile('ui.ts',source,ts.ScriptTarget.Latest,true);return ast.statements.find(node=>ts.isClassDeclaration(node)&&node.name?.text===owner).members.find(node=>node.name?.text===name).getText(ast).replace(/@Builder\s*/g,'')}
const controls={}
new Function('exports','readerModeSelection','readerDirectionSelection',compile(`export class Settings { ${['setPageMode','setDirection'].map(name=>method('components/ReaderSettingsContent','ReaderSettingsContent',name)).join('\n')} }`))(controls,pair.readerModeSelection,pair.readerDirectionSelection)
function settings(current){const ui=new controls.Settings();ui.copyPreferences=()=>({...current});ui.update=next=>{current=next};return {ui,get:()=>current}}
let captured
const host={}
new Function('exports','ReaderDirectionControl',compile(`export class Host { ${method('readerLab/KomaReaderLabPage','KomaReaderLabPage','HostModeControl')} }`))(host,params=>{captured=params})
function bottom(current,direction){let policy=Initial.resolveHost(current,'odd_left');new host.Host().HostModeControl({policy,enabled:true,onChange:next=>{policy=next},onMenuVisible(){}});captured.onDirectionChange(direction);return Bridge.applyPolicy(current,policy)}
for(const initialDirection of [ReadingDirection.LEFT_TO_RIGHT,ReadingDirection.RIGHT_TO_LEFT,ReadingDirection.WEBTOON]) {
 for(const destination of ['single_page','double_page','vertical_page']) test(`settings leaves continuous for ${destination} from ${initialDirection}`,()=>{
  const f=settings({pageMode:'continuous_scroll',readingDirection:initialDirection,columnMode:'odd_left'})
  f.ui.setPageMode(destination)
  const policy=Initial.resolveHost(f.get(),'odd_left')
  assert.notEqual(policy.layout,'continuous')
  assert.equal(f.get().pageMode,destination)
  assert.equal(f.get().readingDirection,initialDirection==='webtoon'?'left_to_right':initialDirection)
 })
}
for(const direction of [ReadingDirection.LEFT_TO_RIGHT,ReadingDirection.RIGHT_TO_LEFT]) test(`both entry points preserve dormant ${direction} across vertical modes`,()=>{
 let fromBottom={pageMode:'single_page',readingDirection:direction,columnMode:'odd_left'}
 const fromSettings=settings({...fromBottom})
 fromSettings.ui.setPageMode('continuous_scroll');fromBottom=bottom(fromBottom,'continuous')
 assert.equal(fromBottom.pageMode,fromSettings.get().pageMode)
 assert.equal(fromBottom.readingDirection,direction)
 fromSettings.ui.setPageMode('vertical_page');fromBottom=bottom(fromBottom,'vertical_page')
 assert.equal(fromBottom.readingDirection,direction)
 fromSettings.ui.setPageMode('single_page');fromBottom=bottom(fromBottom,direction==='right_to_left'?'rtl':'ltr')
 assert.equal(fromBottom.pageMode,'single_page')
 assert.equal(fromBottom.readingDirection,fromSettings.get().readingDirection)
 assert.equal(Initial.resolveHost(fromBottom,'odd_left').layout,'single')
})
test('legacy WEBTOON direction command explicitly selects continuous and a later mode command releases it',()=>{
 const f=settings({pageMode:'double_page',readingDirection:ReadingDirection.RIGHT_TO_LEFT})
 f.ui.setDirection(ReadingDirection.WEBTOON)
 assert.equal(f.get().pageMode,'continuous_scroll')
 f.ui.setPageMode('double_page')
 assert.equal(Initial.resolveHost(f.get(),'odd_left').layout,'spread')
})

test('legacy bottom mode command shares the same dormant-direction and WEBTOON release rule',()=>{
 const exports={}, modes={DUAL_PAGE:'dual',CONTINUOUS_SCROLL:'continuous',VERTICAL_PAGE:'vertical',SINGLE_PAGE:'single'}
 new Function('exports','readerModeSelection','ReaderMode','setTimeout',compile(`export class Legacy { ${method('pages/ReaderPage','ReaderPage','onModeChange')} }`))(exports,pair.readerModeSelection,modes,()=>0)
 for(const direction of Object.values(ReadingDirection)) {
  const page=new exports.Legacy()
  Object.assign(page,{preferences:{pageMode:'single_page',readingDirection:direction},preferenceRevision:0,pageIndex:0,
   copyPreferences:()=>({...page.preferences}),refreshPageDataSources(){},emitWebtoonMode(){},persistPreferences(){},resetZoomState(){},routeVisible:false})
  page.onModeChange(modes.CONTINUOUS_SCROLL)
  assert.equal(page.preferences.readingDirection,direction)
  page.onModeChange(modes.DUAL_PAGE)
  assert.equal(page.preferences.readingDirection,direction==='webtoon'?'left_to_right':direction)
  assert.equal(Initial.resolveHost(page.preferences,'odd_left').layout,'spread')
 }
})


const modes={SINGLE_PAGE:'single',DUAL_PAGE:'dual',CONTINUOUS_SCROLL:'continuous',VERTICAL_PAGE:'vertical'}
const labels={}
new Function('exports','ReadingDirection','AppStrings',compile(storeAst.statements.find(node=>node.name?.text==='getReadingDirectionLabel').getText(storeAst)))(labels,ReadingDirection,{get:key=>key})
const display={}
new Function('exports','ReaderMode','ReadingDirection','getReadingDirectionLabel','s',compile(`export class Display { ${['isHorizontalDirectionApplicable','effectiveDirectionLabel'].map(name=>method('components/ReaderSettingsContent','ReaderSettingsContent',name)).join('\n')} }`))(display,modes,ReadingDirection,labels.getReadingDirectionLabel,key=>key)
const hostMode={}
new Function('exports','ReaderMode',compile(`export class HostMode { ${method('readerLab/KomaReaderLabPage','KomaReaderLabPage','currentReaderMode')} }`))(hostMode,modes)
for(const direction of Object.values(ReadingDirection)) for(const mode of ['single_page','double_page','vertical_page','continuous_scroll']) {
 test(`effective direction applicability follows rendered policy for ${mode}/${direction}`,()=>{
  const preferences={pageMode:mode,readingDirection:direction}
  const policy=Initial.resolveHost(preferences,'odd_left')
  const host=new hostMode.HostMode();host.hostPreferences=preferences;host.session={snapshot:()=>({policy})}
  const ui=new display.Display();ui.preferences=preferences;ui.readerMode=host.currentReaderMode()
  const horizontal=policy.layout!=='continuous'&&policy.pagingAxis!=='vertical'
  assert.equal(ui.isHorizontalDirectionApplicable(),horizontal)
  assert.equal(ui.effectiveDirectionLabel(),horizontal?labels.getReadingDirectionLabel(direction):'reader_direction_effective_top_to_bottom')
  assert.equal(preferences.readingDirection,direction,'projection must not mutate dormant persisted choice')
 })
}

test('effective vertical direction has its own three-language label without changing WEBTOON labels',()=>{
 const expectations={base:'Top to bottom',en_US:'Top to bottom',zh_CN:'从上到下'}
 for(const [locale,text] of Object.entries(expectations)) {
  const rows=JSON.parse(fs.readFileSync(path.resolve(base,'../resources',locale,'element/string.json'),'utf8')).string
  assert.equal(rows.filter(row=>row.name==='reader_direction_effective_top_to_bottom').length,1)
  assert.equal(rows.find(row=>row.name==='reader_direction_effective_top_to_bottom').value,text)
  assert.equal(rows.find(row=>row.name==='reader_direction_vertical').value,locale==='zh_CN'?'纵向滚动':'Vertical')
 }
})
