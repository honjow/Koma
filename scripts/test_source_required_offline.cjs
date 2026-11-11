const assert = require('node:assert/strict')
const fs = require('node:fs')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || 'typescript')
const actual = { sourceTextOverlay: x => x }
const os = require('node:os'), path = require('node:path')
const base = 'entry/src/main/ets/model/'
const clean = value => value.replace(/import[\s\S]*?from '[^']+'\n/g, '')
function load(source, deps) {
  const out = {}
  new Function('exports', ...Object.keys(deps), ts.transpileModule(clean(source), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText)(out, ...Object.values(deps))
  return out
}
const io = { accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
  openSync: (p,m) => ({ fd: fs.openSync(p,m ? 'w' : 'r') }), closeSync: f => fs.closeSync(f.fd),
  writeSync: (fd,v) => fs.writeSync(fd, typeof v === 'string' ? v : Buffer.from(v)),
  readTextSync: p => fs.readFileSync(p,'utf8'), fsyncSync: fs.fsyncSync, renameSync: fs.renameSync,
  unlinkSync: fs.unlinkSync, statSync: p => typeof p === 'number' ? fs.fstatSync(p) : fs.statSync(p),
  listFileSync: p => fs.readdirSync(p), readSync: (fd,b) => fs.readSync(fd,Buffer.from(b),0,b.byteLength,null) }
const models = load(fs.readFileSync(base+'ComicModels.ets','utf8'), {})
const persistence = load(fs.readFileSync(base+'AppFileTextPersistence.ets','utf8'), { fs: io })
const directoryIndex = load(fs.readFileSync(base+'DownloadDirectoryIndex.ets','utf8'), { fs: io, ...persistence })
const offline = load(fs.readFileSync(base+'OfflineDownloadStore.ets','utf8'),
  { fs: io, ComicSourceKind: models.ComicSourceKind, sourceTextOverlay: actual.sourceTextOverlay,
    ...directoryIndex, ...persistence })
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-required-offline-'))
try {
  const store = new offline.OfflineDownloadStore(tmp)
  function make(id, resolved) {
    let manifest = store.createManifest(id,'chapter',1,'queued',
      { sourceKind: models.ComicSourceKind.PRIVATE_LIBRARY, sourceId:'jm',seriesId:id })
    const target = store.pageFilePath(id,'chapter','p1',0,'jpg')
    fs.writeFileSync(target, Buffer.from([1,2,3]))
    const page = {pageId:'p1',pageIndex:0,localPath:target,size:3,
      contentHash:offline.createOfflineDownloadFileContentHash(target),updatedAt:1}
    if (resolved) page.requiredImageDecodeResolved = true
    manifest = store.recordPage(manifest, page)
    manifest.status = 'downloaded'
    return store.saveManifest(manifest)
  }
  make('legacy', false)
  assert.equal(store.loadManifest('legacy','chapter').pages[0].requiredImageDecodeResolved, undefined)
  make('canonical', true)
  assert.equal(store.loadManifest('canonical','chapter').pages[0].requiredImageDecodeResolved, true)
  const file = store.manifestPath('canonical','chapter')
  const saved = JSON.parse(fs.readFileSync(file,'utf8'))
  delete saved.pages[0].requiredImageDecodeResolved
  fs.writeFileSync(file,JSON.stringify(saved))
  assert.equal(store.validateDownloadedChapter('canonical','chapter').reasonCode, 'integrity_mismatch')
  saved.pages[0].requiredImageDecodeResolved = false
  fs.writeFileSync(file,JSON.stringify(saved))
  assert.equal(store.validateDownloadedChapter('canonical','chapter').reasonCode, 'manifest_malformed')
  console.log('offline manifest preserves canonical marker, rejects tampering, reads legacy')
} finally { fs.rmSync(tmp,{recursive:true,force:true}) }

// Execute actual library serialization and hydration, including rejection of corrupt hints.
const hint = {kind:'jm_stripes_v1',rows:4}
const requiredSource=fs.readFileSync(base+'SourceRequiredImageDecode.ets','utf8')
const requiredTree=ts.createSourceFile('required.ets',requiredSource,ts.ScriptTarget.Latest,true)
const requiredNode=requiredTree.statements.find(node=>node.name?.text==='sourceRequiredImageDecode')
const required=load(requiredNode.getText(requiredTree),{})
const library = load(fs.readFileSync(base+'LibraryPersistence.ets','utf8'), {
  ...models, sourceTextOverlay: actual.sourceTextOverlay, sourceRequiredImageDecode:required.sourceRequiredImageDecode, fs:io,
})
const book = {id:'book',title:'Book',sourceKind:models.ComicSourceKind.PRIVATE_LIBRARY,sourcePath:'book',sortTitle:'book',
  preferredDirection:'left_to_right',chapterCount:1,pageCount:1,createdAt:1,updatedAt:1,lastImportedAt:1,
  chapters:[{id:'chapter',comicId:'book',title:'Chapter',index:0,sourcePath:'chapter',sortKey:'0',pageCount:1,
    createdAt:1,updatedAt:1,pages:[{id:'page',comicId:'book',chapterId:'chapter',index:0,fileName:'page',
      uri:'https://example.invalid/page',sortKey:'0',requiredImageDecode:hint}]}]}
const persisted = JSON.parse(JSON.stringify(library.persistComic(book)))
assert.deepEqual(library.hydrateComic(persisted).chapters[0].pages[0].requiredImageDecode,hint)
persisted.chapters[0].pages[0].requiredImageDecode.rows=3
assert.throws(()=>library.hydrateComic(persisted),/source_required_decode_invalid/)
console.log('library serialization preserves required decode and rejects invalid hints')

async function verifyHydration() {
  const source=fs.readFileSync(base+'SourceChapterPageHydrator.ets','utf8')
  const tree=ts.createSourceFile('hydrator.ets',source,ts.ScriptTarget.Latest,true)
  const names=['optionalSourceString','optionalSourceNumber','sourcePageImageRecord','sourcePageImageUrl',
    'sourcePageDimension','sourcePageId','pagesFromSourceRows']
  const body=names.map(name=>tree.statements.find(node=>node.name?.text===name).getText(tree)).join('\n')
  const js=ts.transpileModule(body,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
  const hydrate=new Function('sourceRequiredImageDecode','normalizeSourceImageUrl',js+';return pagesFromSourceRows')(
    required.sourceRequiredImageDecode,value=>value)
  const rows=[{id:'p1',image:{kind:'url',url:'https://example.invalid/1',requiredImageDecode:hint}}]
  const pages=await hydrate('book','chapter',rows)
  assert.deepEqual(pages[0].requiredImageDecode,hint)
  rows[0].image.kind='text'
  await assert.rejects(hydrate('book','chapter',rows),/source_required_decode_invalid/)
  console.log('source page hydration retains valid hint and rejects non-image hint')
}
verifyHydration().catch(error=>{console.error(error);process.exitCode=1})

async function verifyDownload() {
  const format=load(fs.readFileSync(base+'DownloadImageFormat.ets','utf8'), {})
  const source=fs.readFileSync(base+'OfflineDownloadService.ets','utf8')
  const tree=ts.createSourceFile('download.ets',source,ts.ScriptTarget.Latest,true)
  const cls=tree.statements.find(node=>node.name?.text==='OfflineDownloadService')
  const method=cls.members.find(node=>node.name?.text==='writePage').getText(tree)
  const js=ts.transpileModule('class Harness {'+method+'}; exports.Harness=Harness',
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
  const kinds={LOCAL_FILE_IMAGE:'local',REMOTE_URL_IMAGE:'remote',SOURCE_TEXT_REQUEST:'text'}
  let decoded=0
  const values={ReaderPageRenderKind:kinds,cacheSourceTextPageImage:async()=>'/text',
    ...format,
    copyLocalFile:async(_from,to)=>({localPath:to}),
    fetchReaderRemoteSourceBytes:async src=>{ if(src.descriptorHint) src.requiredImageDecode=hint;return Uint8Array.from([1]).buffer },
    SourceRequiredImageDecodeService:{decodeBytes:async(_bytes,h)=>{assert.deepEqual(h,hint);decoded++;return {bytes:Uint8Array.from([2]).buffer,extension:'gif'}}},
    writeDownloadPageBytes:async(file,bytes)=>({localPath:file,size:bytes.byteLength})}
  const out={}
  new Function('exports',...Object.keys(values),js)(out,...Object.values(values))
  const worker=new out.Harness()
  const fresh=await worker.writePage({kind:'remote',descriptorHint:true},'/pages/p1.jpg')
  assert.equal(fresh.localPath,'/pages/p1.gif');assert.equal(fresh.requiredImageDecodeResolved,true);assert.equal(decoded,1)
  const offline=await worker.writePage({kind:'local',imageUri:'/canonical.gif',requiredImageDecode:hint,
    requiredImageDecodeResolved:true},'/pages/p2.gif')
  assert.equal(offline.requiredImageDecodeResolved,true);assert.equal(decoded,1)
  for (const [bytes, original, expected] of [
    [[0xff,0xd8,0xff,0xe0], '/pages/001.img', '/pages/001.jpg'],
    [[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a], '/pages/002.jpg', '/pages/002.png'],
    [Array.from(Buffer.from('RIFF1234WEBP')), '/pages/003.img', '/pages/003.webp'],
    [Array.from(Buffer.from('GIF89a')), '/pages/004.img', '/pages/004.gif'],
    [[1,2,3], '/pages/005.img', '/pages/005.img'],
  ]) {
    values.fetchReaderRemoteSourceBytes=async()=>Uint8Array.from(bytes).buffer
    const dynamic = {}
    new Function('exports',...Object.keys(values),js)(dynamic,...Object.values(values))
    assert.equal((await new dynamic.Harness().writePage({kind:'remote'}, original)).localPath, expected)
  }
  const copyNode=tree.statements.find(node=>node.name?.text==='copyDownloadPageFileWorker')
  const copySource=copyNode.getText(tree).replace(/@Concurrent\s*/g,'')
  const workerJs=ts.transpileModule(copySource+'\nexports.copy=copyDownloadPageFileWorker',
    {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
  const copyOut={}, copyIo={...io,copyFileSync:fs.copyFileSync}
  new Function('exports','fs','downloadImagePathForBytes','createOfflineDownloadFileContentHash',workerJs)(
    copyOut,copyIo,format.downloadImagePathForBytes,()=> 'fixture-hash')
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'koma-copy-image-'))
  try {
    const from=path.join(temp,'source'), target=path.join(temp,'001.img')
    fs.writeFileSync(from,Buffer.from([0xff,0xd8,0xff,0xe0,0x11]))
    const copied=copyOut.copy(from,target)
    assert.equal(copied.localPath,path.join(temp,'001.jpg'))
    assert.deepEqual(fs.readFileSync(copied.localPath),fs.readFileSync(from))
  } finally { fs.rmSync(temp,{recursive:true,force:true}) }
  await assert.rejects(worker.writePage({kind:'text',requiredImageDecode:hint},'/pages/p3.png'),/source_required_decode_invalid/)
  console.log('download writes canonical descriptor output and does not decode resolved local image again')
}
verifyDownload().catch(error=>{console.error(error);process.exitCode=1})
