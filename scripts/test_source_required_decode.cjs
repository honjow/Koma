const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const crypto = require('node:crypto')
const z = require('node:zlib')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || 'typescript')
const file = path.join(__dirname, '../entry/src/main/ets/model/SourceRequiredImageDecode.ets')
function load(imageMock = {}) {
  const exports = {}, nativeFs = { OpenMode: { READ_ONLY: 0 }, openSync: p => ({ fd: fs.openSync(p, 'r') }),
    closeSync: f => fs.closeSync(f.fd), statSync: fd => fs.fstatSync(fd), readSync: (fd, b) => fs.readSync(fd, new Uint8Array(b)) }
  const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')
  const fakeZlib = { CompressFlushMode: { FINISH: 4 }, ReturnStatus: { OK: 0, STREAM_END: 1 }, createZipSync: () => {
    let stream, state
    return { inflateInit2: async s => { stream = s; return 0 }, inflate: async () => {
      const raw = z.gunzipSync(Buffer.from(stream.nextIn)); new Uint8Array(stream.nextOut).set(raw)
      state = { totalOut: raw.length, availableIn: 0 }; return 1
    }, getZStream: async () => state, inflateEnd: async () => 0 }
  } }
  const imports = { '@kit.ArkTS': { taskpool: { execute: async (f, ...args) => f(...args) } },
    '@kit.ImageKit': { image: imageMock }, '@kit.CoreFileKit': { fileIo: nativeFs },
    '@kit.BasicServicesKit': { zlib: fakeZlib }, '@kit.CryptoArchitectureKit': { cryptoFramework: {
      createMd: () => { const d=crypto.createHash('sha256'); return { updateSync: x => d.update(x.data), digestSync: () => ({ data: d.digest() }) } },
    } }, './ImageFileContent': { imageFileContentHash: hash }, './ImageProcessingPlugins': { imagePluginStraightAlpha() {} } }
  const modules={}
  function loadModule(moduleFile) {
    if (modules[moduleFile]) return modules[moduleFile]
    const out={};modules[moduleFile]=out
    const js=ts.transpileModule(fs.readFileSync(moduleFile,'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
    new Function('exports','require',js)(out,name=>imports[name] ?? (name.startsWith('./SourceRequiredImageDecode') ?
      loadModule(path.join(path.dirname(file),name+'.ets')) : {}))
    return out
  }
  Object.assign(exports,loadModule(file))
  return exports
}
const asBuffer = b => b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength)

test('strict required hint rejects malformed or unknown rules', () => {
  const m = load(); assert.deepEqual(m.sourceRequiredImageDecode({ kind: 'jm_stripes_v1', rows: 10 }), { kind: 'jm_stripes_v1', rows: 10 })
  for (const bad of [null, {}, {kind:'jm_stripes_v1',rows:1}, {kind:'jm_stripes_v1',rows:3}, {kind:'jm_stripes_v1',rows:22},
    {kind:'unknown',rows:10}, {kind:'jm_stripes_v1',rows:'10'}, {kind:'jm_stripes_v1',rows:10,extra:1}]) {
    assert.throws(() => m.sourceRequiredImageDecode(bad), /source_required_decode_invalid/)
  }
})

test('stripe scanlines match the fixed reference with nonzero remainder', () => {
  const m=load(),input=new Uint8Array(11*4)
  for(let y=0;y<11;y++) input.set([y,y,y,255],y*4)
  const actual=new Uint8Array(m.restoreJmStripePixels(input.buffer,1,11,4))
  assert.deepEqual(Array.from({length:11},(_,y)=>actual[y*4]),[6,7,8,9,10,4,5,2,3,0,1])
  assert.throws(()=>m.restoreJmStripePixels(new ArrayBuffer(16),2,2,10),/dimensions/)
})

test('non-GIF image path restores pixels, packs JPEG and propagates failures', async () => {
  const expected = [6,7,8,9,10,4,5,2,3,0,1]
  let broken = false, released = 0
  const mock = { PixelMapFormat:{RGBA_8888:3}, AlphaType:{PREMUL:1,UNPREMUL:2},
    createImageSource: () => ({ getImageInfo:async()=>({size:{width:1,height:11}}),
      createPixelMap:async()=>({ getImageInfo:async()=>({size:{width:1,height:11},alphaType:2}),
        readPixelsToBuffer:async buffer=>{ if(broken) throw Error('decode failed');
          const bytes=new Uint8Array(buffer); for(let y=0;y<11;y++) bytes.set([y,y,y,255],y*4) },
        release:async()=>{released++} }), release:async()=>{released++} }),
    createPixelMap:async pixels=>{assert.deepEqual(Array.from({length:11},(_,y)=>new Uint8Array(pixels)[y*4]),expected);
      return {release:async()=>{released++}}},
    createImagePacker:()=>({packing:async(_map,options)=>{assert.equal(options.format,'image/jpeg');assert.equal(options.quality,90);
      return Uint8Array.from([1,2,3]).buffer},release:async()=>{released++}}) }
  const m=load(mock),hint={kind:'jm_stripes_v1',rows:4}
  for(const input of [[0x89,0x50,0x4e,0x47],[0xff,0xd8,0xff]]) {
    const out=await m.SourceRequiredImageDecodeService.decodeBytes(Uint8Array.from(input).buffer,hint)
    assert.equal(out.extension,'jpg');assert.deepEqual([...new Uint8Array(out.bytes)],[1,2,3])
  }
  broken=true
  await assert.rejects(m.SourceRequiredImageDecodeService.decodeBytes(Uint8Array.from([1]).buffer,hint),/decode failed/)
  broken=false
  assert.equal((await m.SourceRequiredImageDecodeService.decodeBytes(Uint8Array.from([1]).buffer,hint)).extension,'jpg')
  assert.equal(released,14)
})

test('raw and gzip GIF remain byte-exact; malformed gzip fails closed', async () => {
  const m=load(),gif=Buffer.from('GIF89a\x01\x00\x01\x00sample','binary'),hint={kind:'jm_stripes_v1',rows:10}
  for(const input of [gif,z.gzipSync(gif)]) {
    const out=await m.SourceRequiredImageDecodeService.decodeBytes(asBuffer(input),hint)
    assert.equal(out.extension,'gif');assert.deepEqual(Buffer.from(out.bytes),gif)
  }
  await assert.rejects(m.SourceRequiredImageDecodeService.decodeBytes(asBuffer(Buffer.from([0x1f,0x8b,0])),hint),/gzip/)
  await assert.rejects(m.SourceRequiredImageDecodeService.decodeBytes(asBuffer(Buffer.from('GIFbogus')),hint))
})

test('decoded cache uses original bytes and required rows; cache hit avoids image decode', async () => {
  const m=load(),tmp=fs.mkdtempSync(path.join(os.tmpdir(),'koma-jm-cache-')),f=path.join(tmp,'wire')
  const values=new Map(),store={get:async(name,_headers,key)=>values.get(name+key),put:async(name,_headers,bytes,key)=>{const v=name+':'+Buffer.from(bytes).toString('hex');values.set(name+key,v);return v}}
  try {
    fs.writeFileSync(f,Buffer.from('GIF89a one'))
    const hint={kind:'jm_stripes_v1',rows:10},a=await m.SourceRequiredImageDecodeService.prepare(f,hint,store,'install1')
    assert.equal(await m.SourceRequiredImageDecodeService.prepare(f,hint,store,'install1'),a)
    fs.writeFileSync(f,Buffer.from('GIF89a two'))
    assert.notEqual(await m.SourceRequiredImageDecodeService.prepare(f,hint,store,'install1'),a)
    assert.equal(values.size,2)
  } finally { fs.rmSync(tmp,{recursive:true,force:true}) }
})
