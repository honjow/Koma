// Executes production store and failure-path method with owned temporary files; no device acceptance.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const ts=require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const root=path.resolve(__dirname,'../entry/src/main/ets');
const clean=s=>s.replace(/import[\s\S]*?from '[^']+'\n/g,'');
function run(s,g){const e={};new Function('exports',...Object.keys(g),ts.transpileModule(s,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText)(e,...Object.values(g));return e;}
const io={accessSync:fs.existsSync,mkdirSync:(p)=>fs.mkdirSync(p,{recursive:true}),OpenMode:{READ_ONLY:0,WRITE_ONLY:1,CREATE:2,TRUNC:4},openSync:(p,m)=>({fd:fs.openSync(p,m?'w':'r')}),closeSync:f=>fs.closeSync(f.fd),writeSync:(fd,v)=>fs.writeSync(fd,typeof v==='string'?v:Buffer.from(v)),readTextSync:p=>fs.readFileSync(p,'utf8'),fsyncSync:fs.fsyncSync,renameSync:fs.renameSync,unlinkSync:fs.unlinkSync,statSync:fs.statSync,readSync:(fd,a)=>fs.readSync(fd,Buffer.from(a),0,a.byteLength,null)};
const models=run(clean(fs.readFileSync(root+'/model/ComicModels.ets','utf8')),{});
const storeCode=fs.readFileSync(root+'/model/OfflineDownloadStore.ets','utf8');
const persistence=run(clean(fs.readFileSync(root+'/model/AppFileTextPersistence.ets','utf8')),{fs:io});
const storeExports=run(clean(storeCode),{fs:io,ComicSourceKind:models.ComicSourceKind,...persistence});
const serviceCode=fs.readFileSync(root+'/model/OfflineDownloadService.ets','utf8');
const tree=ts.createSourceFile('Service.ts',serviceCode,ts.ScriptTarget.Latest,true);
const helpers=tree.statements.filter(n=>ts.isFunctionDeclaration(n)&&['manifestIdentityFromComic','manifestLabelsFromDownload','applyManifestLabels'].includes(n.name?.getText(tree))).map(n=>n.getText(tree)).join('\n');
const cls=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name.getText(tree)==='OfflineDownloadService');
const method=cls.members.find(n=>n.name?.getText(tree)==='saveBlockedChapter').getText(tree);
const {Subject}=run(helpers+'\nexport class Subject { '+method+' }',storeExports);
let results=[];
for(const kind of ['partial','downloaded','empty','new']){
 for(const reason of ['source_pages_failed','source_disabled','source_not_installed']){
 const dir=fs.mkdtempSync('/private/tmp/koma-blocked-fixture-');const store=new storeExports.OfflineDownloadStore(dir);const comic={id:'owned-comic',title:'Owned fixture',sourceRuntimeId:'owned-source',sourceKind:models.ComicSourceKind.PRIVATE_LIBRARY,chapters:[{id:'owned-chapter',title:'Owned chapter',pages:[],pageCount:3}]};
 let original;
 if(kind!=='new'){
  let m=store.createManifest(comic.id,'owned-chapter',3,kind==='empty'?'queued':kind,{sourceKind:comic.sourceKind,sourceId:'owned-source',seriesId:comic.id});
  const count=kind==='partial'?1:kind==='empty'?0:3;
  for(let i=0;i<count;i++){const p=store.pageFilePath(comic.id,'owned-chapter','p'+i,i,'img');fs.writeFileSync(p,Buffer.from([10+i,20,30]));m=store.recordPage(m,{pageId:'p'+i,pageIndex:i,localPath:p,size:3,contentHash:storeExports.createOfflineDownloadFileContentHash(p),updatedAt:1});}
  original=store.loadManifest(comic.id,'owned-chapter');
 }
 const queue=[];const s=new Subject();s.store=store;s.queueStore={upsert:e=>queue.push(e),fromManifest:m=>JSON.parse(JSON.stringify(m))};s.publishNotification=()=>{};
 const result=s.saveBlockedChapter(comic,'owned-chapter',reason);const loaded=store.loadManifest(comic.id,'owned-chapter');
 const preserved=kind==='new'?loaded.status==='blocked'&&loaded.pageCount===0:JSON.stringify(loaded.pages)===JSON.stringify(original.pages)&&loaded.pageCount===original.pageCount&&(kind==='empty'?loaded.status==='blocked':['partial','downloaded'].includes(loaded.status));
 const row={kind,preserved,before:original?{count:original.downloadedPageCount,total:original.pageCount,status:original.status}:null,after:{count:loaded.downloadedPageCount,total:loaded.pageCount,status:loaded.status},physicalFilesStillExist:original?.pages.every(p=>fs.existsSync(p.localPath))??true,dir};results.push(row);
 assert.ok(preserved,JSON.stringify(row));
 assert.equal(loaded.failureReasonCode,reason);
 assert.deepEqual(queue[0],JSON.parse(JSON.stringify(loaded)));
 for(const p of original?.pages??[]) assert.equal(storeExports.createOfflineDownloadFileContentHash(p.localPath),p.contentHash);
 fs.rmSync(dir,{recursive:true});
 }
}
const out={method:'Actual production store with Node fileIo binding plus AST-extracted unmodified saveBlockedChapter and helpers; synthetic owned files only',serviceSHA256:crypto.createHash('sha256').update(serviceCode).digest('hex'),results,nativeVerified:false};
console.log(JSON.stringify(out,null,2));
