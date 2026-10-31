const fs = require('node:fs'), assert = require('node:assert/strict');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
function load(file, deps={}) {
 const out=ts.transpileModule(fs.readFileSync('entry/src/main/ets/model/'+file+'.ets','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 const exp={};new Function('exports','require',out)(exp,n=>{if(n in deps)return deps[n];throw Error(n)});return exp;
}
const model=load('ReaderDisplaySettings');
const tick=()=>new Promise(r=>setImmediate(r));
(async()=>{
 const defaults=new model.ReaderDisplaySettings();
 assert.equal(model.readerWindowBrightness(defaults),-1);assert.equal(model.readerDisplayDimOpacity(defaults),0);
 for(const [value,window,dim] of [[-75,.01,.75],[-1,.01,.01],[0,-1,0],[42,.42,0],[100,1,0]]) {
  const settings=Object.assign(new model.ReaderDisplaySettings(),{brightnessEnabled:true,brightness:value});
  assert.equal(model.readerWindowBrightness(settings),window);assert.equal(model.readerDisplayDimOpacity(settings),dim);
 }
 const parsed=model.parseReaderDisplaySettings(JSON.stringify({...defaults,grayscale:true,alpha:64,red:222}));
 assert.deepEqual(model.normalizeReaderDisplaySettings(parsed),parsed);
 let release;let value=.37;const writes=[];
 const target={getWindowProperties:()=>({brightness:value}),setWindowBrightness:async n=>{writes.push(n);value=n}};
 const win={getLastWindow:()=>new Promise(r=>{release=()=>r(target)})};
 const C=load('ReaderBrightnessController',{'@kit.ArkUI':{window:win},'../diagnostics/DiagnosticLogger':{DiagnosticLogger:{warn(){}}},'./ReaderDisplaySettings':model}).ReaderBrightnessController;
 const c=new C();const on=Object.assign(new model.ReaderDisplaySettings(),{brightnessEnabled:true,brightness:42});
 c.update({},true,on);c.update({},false,on);release();await tick();assert.deepEqual(writes,[],'late window lookup must not change a closed reader');
 c.update({},true,on);release();await tick();assert.equal(value,.42);
 c.update({},false,on);await tick();assert.equal(value,.37,'restore exact original window value');
 console.log('PASS: display defaults/range, portable roundtrip, late lookup cancellation and exact window restoration');
})().catch(e=>{console.error(e);process.exitCode=1});
