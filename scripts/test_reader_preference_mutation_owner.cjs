const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root = require('node:path').resolve(__dirname, '..') + '/';
const data = new Map(), published = []; let failFlush = false, failChangedOverride = false, stableOverride; let flushCount = 0;
const ReadingDirection = { LEFT_TO_RIGHT:'left_to_right', RIGHT_TO_LEFT:'right_to_left', WEBTOON:'webtoon' };
function evaluate(file, deps) {
 const exp={}; const source=fs.readFileSync(root+file,'utf8').replace(/@ObservedV2\s*|@Trace\s+/g,''); const out=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 new Function('exports','require',out)(exp,n=>{if(n in deps)return deps[n];throw Error('unexpected import '+n)});return exp;
}
const activity = evaluate('entry/src/main/ets/model/BackupRestoreActivity.ets',{}).BackupRestoreActivity;
let backendSelection;
const backendModule = evaluate('entry/src/main/ets/state/KomaReaderBackendSelectionState.ets',{
 '@kit.ArkUI':{AppStorageV2:{connect:(type,key,factory)=>backendSelection ??= factory()}}
});
const mod = evaluate('entry/src/main/ets/model/ReaderPreferencesStore.ets',{
 '../state/KomaReaderBackendSelectionState':backendModule,
 './BackupRestoreActivity':{BackupRestoreActivity:activity}, '@kit.AbilityKit':{ConfigurationConstant:{ColorMode:{COLOR_MODE_DARK:0,COLOR_MODE_LIGHT:1,COLOR_MODE_NOT_SET:-1}}},
 '@kit.ArkData':{preferences:{async getPreferences(context){
  let row=data.get(context.filesDir);if(!row){row=new Map();data.set(context.filesDir,row)}
  return {async has(k){return row.has(k)},async delete(k){row.delete(k)},async get(k,d){return row.has(k)?row.get(k):d},async put(k,v){row.set(k,v)},async flush(){flushCount++;const changed=failChangedOverride && row.get('reader.seriesModeOverrides.v1')!==stableOverride;if(failFlush || changed){failFlush=false;failChangedOverride=false;throw Error('fixture_flush_failed')}}};
 }}}, '../i18n/AppStrings':{AppStrings:{get:s=>s}},'./ComicModels':{ReadingDirection},
 '../state/ReaderModeState':{ReaderModeSnapshot:class{constructor(...a){this.args=a}},ReaderModeStateBridge:{publish:v=>published.push(v),snapshot:columnMode=>({...mod.DEFAULT_READER_PREFERENCES,columnMode})}}
});
const ctx={filesDir:'/owned-memory/preferences'}, store=new mod.ReaderPreferencesStore(ctx), other=new mod.ReaderPreferencesStore(ctx);
(async()=>{
 let applied=[];ctx.getApplicationContext=()=>({setColorMode:n=>{if(n===0 && ctx.failTheme)throw Error('platform_fail');applied.push(n)}});
 await store.save(mod.DEFAULT_READER_PREFERENCES);assert.deepEqual(applied,[]);
 mod.bindReaderThemeWindow(ctx);await store.load();assert.deepEqual(applied,[-1]);
 await store.saveThemeMode('dark');await store.saveThemeMode('light');await store.saveThemeMode('system');assert.deepEqual(applied,[-1,0,1,-1]);
 failFlush=true;await assert.rejects(()=>store.saveThemeMode('dark'));assert.equal((await store.load()).themeMode,'system');assert.equal(applied.at(-1),-1);
 ctx.failTheme=true;await assert.rejects(()=>store.saveThemeMode('dark'),/platform_fail/);assert.equal((await store.load()).themeMode,'system');ctx.failTheme=false;
 mod.unbindReaderThemeWindow();await store.saveThemeMode('dark');assert.equal(applied.at(-1),-1);mod.bindReaderThemeWindow(ctx);await store.load();assert.equal(applied.at(-1),0);
 await store.save(mod.DEFAULT_READER_PREFERENCES);published.length=0;
 await store.savePreloadWifiOnly(true);
 assert.equal((await new mod.ReaderPreferencesStore(ctx).load()).preloadWifiOnly,true);
 await Promise.all([store.saveDoubleTapZoomEnabled(false),other.saveDoubleTapIntervalMs(200)]);
 const tapPrefs=await new mod.ReaderPreferencesStore(ctx).load();
 assert.equal(tapPrefs.doubleTapZoomEnabled,false);assert.equal(tapPrefs.doubleTapIntervalMs,200);
 assert.equal((await store.loadForComic('tap-book')).doubleTapIntervalMs,200);
 failFlush=true;await assert.rejects(()=>store.saveDoubleTapZoomEnabled(true),/fixture_flush_failed/);
 assert.equal((await store.load()).doubleTapZoomEnabled,false);
 await Promise.all([store.savePreloadPages(5),other.saveAutoPageSeconds(9)]);
 const both=await store.load();const preserved=both.preloadPages===5 && both.autoPageSeconds===9;
 console.log(JSON.stringify({crossInstanceFieldsPreserved:preserved,preloadPages:both.preloadPages,autoPageSeconds:both.autoPageSeconds}));
 assert.ok(preserved,'different setting writes must both survive');
 const before=await store.load();const one={...before,showPageNumber:false};const two={...before,preloadPages:3};
 await Promise.all([store.saveChanges(before,one),other.saveChanges(before,two)]);
 const merged=await store.load();assert.equal(merged.showPageNumber,false);assert.equal(merged.preloadPages,3);
 // Adopted crop strength uses the same serialized delta owner, not a shadow preference store.
 const cropBefore=await store.load();
 await Promise.all([
  store.saveChanges(cropBefore,{...cropBefore,trimPageMarginsEnabled:true,cropStrength:'strong'}),
  other.saveChanges(cropBefore,{...cropBefore,autoPageSeconds:8})
 ]);
 const cropped=await store.load();assert.equal(cropped.trimPageMarginsEnabled,true);assert.equal(cropped.cropStrength,'strong');assert.equal(cropped.autoPageSeconds,8);
 assert.equal((await store.loadForComic('crop-book')).cropStrength,'strong');
 const baseline=await store.load();
 await Promise.all([
  store.saveChangesForComic('A',baseline,{...baseline,pageMode:'double_page',readingDirection:ReadingDirection.RIGHT_TO_LEFT,columnMode:'even_left'}),
  other.saveChangesForComic('B',baseline,{...baseline,pageMode:'vertical_page',autoPageSeconds:11})
 ]);
 const a=await store.loadForComic('A'), b=await other.loadForComic('B'), global=await store.load();
 assert.equal(a.pageMode,'double_page');assert.equal(a.readingDirection,ReadingDirection.RIGHT_TO_LEFT);
 assert.equal(b.pageMode,'vertical_page');assert.equal(global.pageMode,baseline.pageMode);assert.equal(global.columnMode,baseline.columnMode);assert.equal(global.autoPageSeconds,11);
 // A stale reader changing a global option must not rewrite another current option or another book.
 await store.saveChangesForComic('A',a,{...a,keepScreenAwake:false});
 assert.equal((await store.load()).autoPageSeconds,11);assert.equal((await store.loadForComic('B')).pageMode,'vertical_page');
 await store.clearSeriesOverride('A');assert.equal((await store.loadForComic('A')).pageMode,baseline.pageMode);assert.equal((await store.loadForComic('B')).pageMode,'vertical_page');
 const pending=store.savePreloadPages(4);assert.throws(()=>activity.beginRestore(),/backup_restore_busy/);await pending;
 published.length=0;failFlush=true;await assert.rejects(()=>other.savePreloadPages(2),/fixture_flush_failed/);assert.equal(published.length,0,'failed flush must not publish committed runtime state');
 await store.savePreloadPages(5);assert.equal((await store.load()).preloadPages,5,'rejected operation must not poison owner');
 activity.beginRestore();await assert.rejects(()=>store.savePreloadPages(1),/backup_restore_busy/);await store.saveForBackupRestore(baseline);activity.finishRestore();
 assert.equal((await store.load()).preloadPages,baseline.preloadPages);
 // The committed preference owner also drives the backend captured by future opens.
 await store.saveReaderImplementation('legacy');
 assert.equal(backendSelection.current(true),'legacy');
 const runtimeView=mod.readerPreferencesFromRuntimeState('odd_left');
 assert.equal(runtimeView.readerImplementation,'legacy','runtime snapshot must preserve the committed backend');
 await store.saveChangesForComic('A',runtimeView,{...runtimeView,showPageNumber:!runtimeView.showPageNumber});
 assert.equal((await store.load()).readerImplementation,'legacy','editing reader controls must retain the selected backend');
 failFlush=true;await assert.rejects(()=>store.saveReaderImplementation('shared'),/fixture_flush_failed/);
 assert.equal(backendSelection.current(true),'legacy','failed persistence must not change the backend');
 await store.load();assert.equal(backendSelection.current(true),'legacy');
 activity.beginRestore();
 await store.saveForBackupRestore({...baseline,readerImplementation:'shared'});
 assert.equal(backendSelection.current(true),'shared','committed restore must override a previous in-process selection');
 activity.finishRestore();
 // A rejected per-book edit must not enter the Preferences cache or a later unrelated save.
 await store.save(mod.DEFAULT_READER_PREFERENCES);
 const seed=await store.loadForComic('book-B');
 await store.saveChangesForComic('book-B',seed,{...seed,pageMode:'vertical_page'});
 const cache=data.get(ctx.filesDir), beforeBookEdit=new Map(cache);
 const aBefore=await store.loadForComic('book-A');
 stableOverride=cache.get(mod.SERIES_MODE_OVERRIDES_KEY);failChangedOverride=true;published.length=0;
 await assert.rejects(()=>store.saveChangesForComic('book-A',aBefore,{...aBefore,pageMode:'double_page'}),/fixture_flush_failed/);
 assert.deepEqual(cache,beforeBookEdit,'failed book commit must restore all cached values');
 assert.equal(published.length,0,'failed book commit must not publish new reader mode');
 await other.savePreloadPages(4);
 assert.equal(cache.get(mod.SERIES_MODE_OVERRIDES_KEY),beforeBookEdit.get(mod.SERIES_MODE_OVERRIDES_KEY),'unrelated commit must not resurrect failed book override');
 assert.equal((await store.loadForComic('book-A')).pageMode,aBefore.pageMode);
 assert.equal((await store.loadForComic('book-B')).pageMode,'vertical_page');
 const successFlushes=flushCount;
 await store.saveChangesForComic('book-A',aBefore,{...aBefore,pageMode:'double_page'});
 assert.equal(flushCount-successFlushes,1,'global fields and per-book override must commit together');
 const beforeReset=new Map(cache);stableOverride=cache.get(mod.SERIES_MODE_OVERRIDES_KEY);failChangedOverride=true;
 await assert.rejects(()=>store.clearSeriesOverride('book-A'),/fixture_flush_failed/);
 assert.deepEqual(cache,beforeReset,'failed reset must restore original per-book payload');
 await other.saveAutoPageSeconds(7);
 assert.equal((await store.loadForComic('book-A')).pageMode,'double_page','unrelated save must not commit a failed reset');
 assert.equal((await store.loadForComic('book-B')).pageMode,'vertical_page');
 await store.clearSeriesOverride('book-A');
 assert.equal((await store.loadForComic('book-A')).pageMode,(await store.load()).pageMode);
 assert.equal((await store.loadForComic('book-B')).pageMode,'vertical_page');

 // Explicit commands reconcile legacy WEBTOON, while merely reopening does not migrate records.
 const modeBase={...await store.load(),pageMode:'single_page',readingDirection:ReadingDirection.RIGHT_TO_LEFT};
 await store.save(modeBase);
 await store.savePageMode('continuous_scroll');
 assert.equal((await store.load()).readingDirection,ReadingDirection.RIGHT_TO_LEFT,'vertical mode retains dormant RTL');
 await store.savePageMode('double_page');
 assert.equal((await store.load()).readingDirection,ReadingDirection.RIGHT_TO_LEFT);
 await store.saveReadingDirection(ReadingDirection.WEBTOON);
 assert.equal((await store.load()).pageMode,'continuous_scroll');
 await store.savePageMode('single_page');
 assert.equal((await store.load()).readingDirection,ReadingDirection.LEFT_TO_RIGHT,'explicit non-continuous command clears legacy WEBTOON');
 const globalChoice=await store.load();
 await store.saveChangesForComic('mode-reopen',globalChoice,{...globalChoice,pageMode:'continuous_scroll',readingDirection:ReadingDirection.RIGHT_TO_LEFT});
 const reopened=new mod.ReaderPreferencesStore(ctx);
 assert.equal((await reopened.loadForComic('mode-reopen')).pageMode,'continuous_scroll');
 assert.equal((await reopened.loadForComic('mode-reopen')).readingDirection,ReadingDirection.RIGHT_TO_LEFT);
 await reopened.clearSeriesOverride('mode-reopen');
 assert.equal((await reopened.loadForComic('mode-reopen')).pageMode,globalChoice.pageMode);
 assert.equal((await reopened.loadForComic('mode-reopen')).readingDirection,globalChoice.readingDirection);
 await reopened.save({...globalChoice,pageMode:'single_page',readingDirection:ReadingDirection.WEBTOON});
 const unchanged=new Map(data.get(ctx.filesDir));
 const legacyReopened=new mod.ReaderPreferencesStore(ctx);
 assert.equal((await legacyReopened.load()).readingDirection,ReadingDirection.WEBTOON);
 assert.deepEqual(data.get(ctx.filesDir),unchanged,'loading does not migrate persistent mode records');
 console.log('PASS: mode commands, dormant RTL, legacy WEBTOON, global restore and fresh store reopen');
 console.log('PASS: one book commit, rejected override/reset cache rollback, later unrelated commits and other-book isolation');
 console.log('PASS: committed backend selection, rejected save and backup restore publication');
 console.log('PASS: common mutation owner, field deltas, two book overrides, reset, restore admission, flush publication and rejection recovery');
})().catch(e=>{console.error(e);process.exitCode=1});
