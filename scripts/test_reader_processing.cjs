const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')
const crop = {}
new Function('exports', ts.transpileModule(fs.readFileSync(path.join(root, 'model/ReaderPageCropBounds.ets'), 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText)(crop)

function borderedPage(background) {
  const pixels = new Uint8Array(100 * 100 * 4)
  for (let y = 0; y < 100; y++) for (let x = 0; x < 100; x++) {
    const edge = x < 12 || x >= 88 || y < 12 || y >= 88
    pixels.set(edge ? [background, background, background, 255] : [100, 0, 0, 255], (y * 100 + x) * 4)
  }
  return pixels
}

test('adopted strengths preserve uncertain/blank pages and distinguish a real gray margin', () => {
  const detector = crop.ReaderPageCropDetector
  const gray = borderedPage(210)
  assert.equal(detector.detect(100, 100, 400, gray, 100, 100, 'conservative').applied(), false)
  assert.equal(detector.detect(100, 100, 400, gray, 100, 100, 'standard').applied(), false)
  const strong = detector.detect(100, 100, 400, gray, 100, 100, 'strong')
  assert.deepEqual([strong.left, strong.top, strong.right, strong.bottom], [.12, .12, .12, .12])
  const white = new Uint8Array(100 * 100 * 4).fill(255)
  for (const strength of ['conservative', 'standard', 'strong']) {
    assert.equal(detector.detect(100, 100, 400, white, 100, 100, strength).applied(), false)
    assert.equal(detector.detect(100, 100, 1, gray, 100, 100, strength).applied(), false)
  }
  assert.equal(detector.normalizeStrength('invalid'), 'standard')
})

// Huawei PixelMap.readPixelsToBuffer exports no allocation padding. This runs
// the real production processing method with an aligned native PixelMap and a
// packed exported buffer: the 197 short_rgba_buffer counterexample.
test('native super resolution receives packed RGBA stride even when PixelMap allocation is aligned',async()=>{
  const relative='model/ReaderSuperResolutionService.ets'
  const source=process.env.KOMA_RGBA_BEFORE==='1'
    ? require('node:child_process').execFileSync('git',['show','85eac652:entry/src/main/ets/'+relative],{encoding:'utf8'})
    : fs.readFileSync(path.join(root,relative),'utf8')
  const payload=Uint8Array.from({length:24},(_,i)=>i),received=[],released=[]
  const pixel={getImageInfo:async()=>({size:{width:2,height:3},stride:16}),getPixelBytesNumber:()=>24,
    readPixelsToBuffer:async buffer=>new Uint8Array(buffer).set(payload),release:async()=>released.push('pixel')}
  const imports={
    '@kit.ImageKit':{image:{PixelMapFormat:{RGBA_8888:1},
      createImageSource:()=>({getImageInfo:async()=>({size:{width:2,height:3}}),createPixelMap:async()=>pixel,release:async()=>released.push('source')}),
      createPixelMap:async()=>({release:async()=>released.push('output')}),
      createImagePacker:()=>({packToFile:async()=>{},release:async()=>released.push('packer')})}},
    '@kit.CoreFileKit':{fileIo:{OpenMode:{READ_WRITE:1,CREATE:2,TRUNC:4},openSync:()=>({fd:1}),closeSync(){},renameSync(){}}},
    '../state/ReaderModeState':{READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT:8000},
    '../diagnostics/DiagnosticLogger':{DiagnosticLogger:{info(){},warn(){}}},
    './ReaderProcessingDiagnostics':{readerProcessingOwnerHash:()=>'',readerSuperResolutionFailureCode:()=> 'unclassified'},
    './ReaderSuperResolutionModelService':{ReaderSuperResolutionModelService:{pathsIfReady:async()=>({paramPath:'param',modelPath:'bin'})}},
    './ReaderNativeSuperResolution':{ReaderNativeSuperResolution:{async upscaleRgba(pixels,width,height,stride){
      received.push({width,height,stride,pixels:new Uint8Array(pixels)})
      if(pixels.byteLength<stride*height)throw Error('RGBA buffer is smaller than stride times height')
      return{pixels:new ArrayBuffer(96),backend:'cpu',modelLoadMs:0,inferenceMs:1,tileCount:1}
    }}},
  }
  const exports={}
  new Function('exports','require','setTimeout',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)
    (exports,name=>imports[name]??{},()=>0)
  const service=exports.ReaderSuperResolutionService
  Object.assign(service,{ensureTaskActive(){},nnrtModelPath:()=>null,nativeConfig:()=>({}),removeIfExists(){},writeBackendMetadata(){},fileSize:()=>96,pruneToLimit:async()=>{},displayUri:path=>path})
  const result=await service.processNow({},'source','key','output',2000,'photo','auto',{requestId:1,owners:new Set(['case'])})
  assert.equal(received.length,1);assert.equal(received[0].stride,8)
  assert.deepEqual(received[0].pixels,payload);assert.equal(result.applied,true)
  assert.deepEqual(released.sort(),['output','packer','pixel','source'])
})

function cropFileTask(source,image) {
  const tree=ts.createSourceFile('crop-file',source,ts.ScriptTarget.Latest,true)
  const fn=tree.statements.find(n=>ts.isFunctionDeclaration(n)&&n.name?.text==='detectReaderPageCropFile')
  const js=ts.transpileModule(fn.getText(tree).replace('@Concurrent',''),{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText
  return new Function('image','ReaderPageCropDetector','ReaderPageCropBounds',js+';return detectReaderPageCropFile;')(image,crop.ReaderPageCropDetector,crop.ReaderPageCropBounds)
}

test('source fingerprint preparation retires cancelled or changed enhancement before cache/native work', async () => {
  const readMode={superResolutionEnabled:true,superResolutionModel:'photo',superResolutionBackend:'auto',superResolutionMaxHeight:2000}
  let release,started,current=true,cacheReads=0
  const imports={
    '../state/ReaderModeState':{connectReaderModeState:()=>readMode,ReaderSuperResolutionModel:{NONE:'none',SYSTEM_CORE_VISION:'system'},READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT:8000},
    './ReaderSuperResolutionModelRegistry':{ReaderSuperResolutionModelRegistry:{find:()=>({})}},
    './ReaderImageFileIdentity':{readerImageFileSha256:()=>new Promise(resolve=>{release=resolve;started()})},
    '../diagnostics/DiagnosticLogger':{DiagnosticLogger:{info(){},warn(){}}},
    './ReaderProcessingDiagnostics':{readerProcessingOwnerHash:()=>''},
    '@kit.ImageKit':{image:{createImageSource:()=>({getImageInfo:async()=>({size:{width:2,height:3}}),release:async()=>{}})}},
  }
  const mod={}
  new Function('exports','require',ts.transpileModule(fs.readFileSync(path.join(root,'model/ReaderSuperResolutionService.ets'),'utf8'),
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(mod,name=>imports[name]??{})
  const service=mod.ReaderSuperResolutionService
  Object.assign(service,{fileStat:()=>({size:123}),releaseOwner(){},pipelineVersion:()=> 'pipeline',
    outputPath(_context,identity){cacheReads++;assert.ok(identity.includes('|123|verified-content|maxHeight=2000|backend=auto'));return '/cache/output'},
    fileSize:()=>42,touch(){},readBackendMetadata:()=> 'cpu'})
  const begin=async()=>{
    const ready=new Promise(resolve=>{started=resolve})
    const request=service.process({},'/source','page',()=>{},'owner',0,()=>current)
    await ready;return {request}
  }
  const cancelled=await begin();current=false;release('verified-content')
  assert.equal((await cancelled.request).reason,'cancelled');assert.equal(cacheReads,0)
  current=true
  const changed=await begin();readMode.superResolutionModel='art';release('verified-content')
  assert.equal((await changed.request).reason,'cancelled');assert.equal(cacheReads,0)
  readMode.superResolutionModel='photo'
  const valid=await begin();release('verified-content')
  const result=await valid.request
  assert.equal(result.applied,true);assert.equal(result.reason,'cache_hit:cpu');assert.equal(cacheReads,1)
})
test('packed PixelMap export keeps real border detection and translation-region native input valid',async()=>{
  const get=relative=>process.env.KOMA_RGBA_CONSUMERS_BEFORE==='1'
    ? require('node:child_process').execFileSync('git',['show','440c014f:entry/src/main/ets/'+relative],{encoding:'utf8'})
    :fs.readFileSync(path.join(root,relative),'utf8')
  const payload=borderedPage(210),released=[]
  const pixel={getImageInfo:async()=>({size:{width:100,height:100},stride:512}),getPixelBytesNumber:()=>payload.byteLength,
    readPixelsToBuffer:async buffer=>new Uint8Array(buffer).set(payload),release:async()=>released.push('pixel')}
  const task=cropFileTask(get('model/ReaderPageCropService.ets'),{PixelMapFormat:{RGBA_8888:1},createImageSource:()=>({
    getImageInfo:async()=>({size:{width:100,height:100}}),createPixelMap:async()=>pixel,release:async()=>released.push('source')})})
  const bounds=crop.ReaderPageCropBounds.parse(await task('file','strong'));assert.equal(bounds.applied(),true)
  assert.deepEqual([bounds.left,bounds.top,bounds.right,bounds.bottom],[.12,.12,.12,.12]);assert.deepEqual(released,['pixel','source'])
  const exports={},calls=[]
  new Function('exports','require',ts.transpileModule(get('readerTranslation/services/ComicNativeRegionDetector.ets'),
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText)(exports,name=>name==='libreader_enhancement.so'?{default:{
      async detectComicRegions(pixels,width,height,stride){calls.push({width,height,stride});assert.deepEqual(new Uint8Array(pixels),payload);return{regions:[],backend:'cpu',modelLoadMs:0,inferenceMs:0}}}}: {})
  const result=await new exports.ComicNcnnLocalRegionDetector('param','bin').detect(pixel)
  assert.deepEqual(calls,[{width:100,height:100,stride:400}]);assert.equal(result.backend,'cpu')
})
