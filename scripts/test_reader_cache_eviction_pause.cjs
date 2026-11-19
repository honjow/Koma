const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const vm = require('node:vm')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function loadCache(directory) {
  const io = {
    accessSync: fs.existsSync,
    mkdirSync: (dir, recursive) => fs.mkdirSync(dir, { recursive }),
    OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
    openSync: (file, mode) => ({ fd: fs.openSync(file, mode ? 'w' : 'r') }),
    writeSync: (fd, bytes) => fs.writeSync(fd, typeof bytes === 'string' ? bytes : new Uint8Array(bytes)),
    fsyncSync: fd => fs.fsyncSync(fd),
    closeSync: file => fs.closeSync(file.fd),
    statSync: fs.statSync,
    renameSync: fs.renameSync,
    unlinkSync: fs.unlinkSync,
    readTextSync: file => fs.readFileSync(file, 'utf8'),
    listFile: fs.promises.readdir,
    unlink: fs.promises.unlink,
    access: async file => fs.existsSync(file),
    stat: fs.promises.stat,
    open: async (file, mode) => ({ fd: fs.openSync(file, mode ? 'w' : 'r') }),
    write: async (fd, bytes) => fs.writeSync(fd, typeof bytes === 'string' ? bytes : new Uint8Array(bytes)),
    close: async file => fs.closeSync(file.fd),
    rename: fs.promises.rename,
  }
  class Task {
    constructor(work, ...args) { this.run = () => work(...args) }
    setCloneList() {}
  }
  const exports = {}
  const imports = {
    '@kit.CoreFileKit': { fileIo: io },
    '@kit.ArkTS': { buffer: Buffer, taskpool: { Task,
      execute: async (work, ...args) => typeof work === 'function' ? work(...args) : work.run() } },
  }
  const imageFileContent = {}
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/ImageFileContent.ets'), 'utf8').replace(/^@Concurrents*$/gm, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: imageFileContent, require: name => imports[name] })
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/RemoteImageCacheStore.ets'), 'utf8')
    .replace(/^@Concurrent$/gm, ''), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, {
    exports, require: name => name === './ImageFileContent' ? imageFileContent : imports[name],
    console: { info() {} }, setTimeout, clearTimeout,
  })
  return new exports.RemoteImageCacheStore(directory)
}

test('continuous reader cache eviction waits for interaction and keeps the newest quota', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-reader-eviction-pause-'))
  const cache = loadCache(directory)
  const bytes = new Uint8Array(4).buffer
  const first = await cache.put('https://cache.invalid/a.jpg', undefined, bytes)
  await cache.put('https://cache.invalid/b.jpg', undefined, bytes)
  const current = await cache.put('https://cache.invalid/c.jpg', undefined, bytes)
  cache.setEvictionPaused(true)
  cache.maintainIfOver(8, current)
  cache.maintainIfOver(4, current)
  assert.equal(fs.existsSync(first), true, 'interaction must not run directory cleanup')
  cache.setEvictionPaused(false)
  await cache.stats()
  assert.equal(fs.existsSync(first), false, 'the latest quota runs after interaction settles')
  assert.equal(fs.existsSync(current), true, 'the displayed page stays protected')
  await cache.clear()
  fs.rmSync(directory, { recursive: true, force: true })
})

test('reader page lookup keeps the body usable after cached metadata is evicted', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-reader-cache-page-'))
  const cache = loadCache(directory)
  try {
    const image = await cache.put('https://cache.invalid/page.jpg', undefined, new Uint8Array(4).buffer, 'page')
    const metadata = await cache.put('source-image-processing.json', undefined, new Uint8Array(8).buffer, 'metadata')
    const cachedPage = await cache.getReaderPage('page', 'metadata')
    assert.equal(cachedPage.imagePath, image)
    assert.equal(cachedPage.metadataPath, metadata)

    fs.unlinkSync(metadata)
    const imageOnly = await cache.getReaderPage('page', 'metadata')
    assert.equal(imageOnly.imagePath, image)
    assert.equal(imageOnly.metadataPath, undefined)
    assert.equal((await cache.stats()).entryCount, 1)

    fs.unlinkSync(image)
    const unavailable = await cache.getReaderPage('page', 'metadata')
    assert.equal(unavailable.imagePath, undefined)
    assert.equal(unavailable.metadataPath, undefined)
    assert.equal((await cache.stats()).entryCount, 0)
  } finally {
    await cache.clear()
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
