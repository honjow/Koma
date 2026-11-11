// Execute production stores/export planning with owned files. Platform UI is verified separately.
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '../entry/src/main/ets/model')
function load(name, deps = {}) {
  const code = fs.readFileSync(path.join(root, name + '.ets'), 'utf8').replace(/@Concurrent\s*/g, '')
  const module = { exports: {} }
  new Function('require', 'module', 'exports', ts.transpileModule(code, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText)(key => { assert.ok(Object.hasOwn(deps, key), key); return deps[key] }, module, module.exports)
  return module.exports
}
const io = {
  accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
  openSync: (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }), closeSync: f => fs.closeSync(f.fd),
  readTextSync: p => fs.readFileSync(p, 'utf8'), writeSync: fs.writeSync, fsyncSync: fs.fsyncSync,
  renameSync: fs.renameSync, unlinkSync: fs.unlinkSync, statSync: fs.statSync,
  rmdirSync: fs.rmdirSync,
  listFileSync: p => fs.readdirSync(p),
  readSync: (fd, data) => fs.readSync(fd, Buffer.from(data), 0, data.byteLength, null),
}
const logger = { exception() {} }
const directoryIndex = load('DownloadDirectoryIndex', { '@kit.CoreFileKit': { fileIo: io } })
const persistence = load('AppFileTextPersistence', { '@kit.CoreFileKit': { fileIo: io }, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger } })
const activity = load('BackupRestoreActivity')
const overlays = load('SourceTextOverlay')
const comicModels = load('ComicModels', {
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
})
const downloads = load('OfflineDownloadStore', { './SourceTextOverlay': overlays, './AppFileTextPersistence': persistence,
  '@kit.CoreFileKit': { fileIo: io }, './DownloadDirectoryIndex': directoryIndex, './ComicModels': comicModels })
const queues = load('OfflineDownloadQueueStore', {
  './BackupRestoreActivity': activity, './AppFileTextPersistence': persistence,
  '@kit.CoreFileKit': { fileIo: io }, './OfflineDownloadRuntime': { OfflineDownloadRuntime: { publish() {} } },
  './OfflineDownloadStore': downloads,
})
async function main() {
  const dir = fs.mkdtempSync('/private/tmp/koma-chapter-management-')
  try {
    const queue = new queues.OfflineDownloadQueueStore(dir)
    const entry = (comicId, chapterId) => ({ comicId, chapterId, status: 'queued', pageCount: 1, downloadedPageCount: 0, updatedAt: 1 })
    queue.addNewEntries([entry('a', '1'), entry('a', '2'), entry('b', '3')])
    queue.move('a', '1', true)
    const ordered = () => queue.load().map(e => e.chapterId)
    assert.deepEqual(ordered(), ['1', '3', '2'])
    queue.upsert({ ...entry('b', '3'), status: 'downloading' })
    assert.deepEqual(ordered(), ['1', '3', '2'], 'Progress cannot undo queue order')
    queue.move('a', '1', false, true)
    assert.deepEqual(ordered(), ['3', '1', '2'], 'Whole-series move retains the series internal order')
    assert.deepEqual(new queues.OfflineDownloadQueueStore(dir).load().map(e => e.chapterId), ordered())
    const execution = load('OfflineDownloadQueueExecution', { './OfflineDownloadStore': downloads })
    const started = []; let finishCurrent
    const current = new Promise(resolve => { finishCurrent = resolve })
    const running = execution.runOrderedDownloadQueueBatch(queue, queue.load(), async e => {
      started.push(e.chapterId)
      if (started.length === 1) await current
    }, () => true)
    await Promise.resolve()
    assert.deepEqual(started, ['3'])
    queue.move('a', '2', true)
    assert.deepEqual(started, ['3'], 'Reorder does not restart or cancel the active chapter')
    finishCurrent(); await running
    assert.deepEqual(started, ['3', '2', '1'], 'The next slot consumes the new persisted order')
    queue.upsert({ ...entry('a', 'done'), status: 'downloaded' })
    queue.move('a', '2', false, true)
    assert.equal(queue.load()[0].comicId, 'b')
    assert.deepEqual(queue.load().slice(1).map(e => e.chapterId), ['done', '2', '1'],
      'Whole-series ordering keeps completed rows in the visible group without re-executing them')

    const values = new Map(); let fail = false
    const prefs = { getSync: (key, fallback) => values.get(key) ?? fallback,
      get: async (key, fallback) => values.get(key) ?? fallback,
      put: async (key, value) => { values.set(key, value) },
      flush: async () => { if (fail) { fail = false; throw Error('disk full') } },
    }
    const models = { ChapterSortBasis: { SOURCE_ORDER: 'source_order', CHAPTER_NUMBER: 'chapter_number' }, ChapterSortDirection: { FORWARD: 'forward', REVERSE: 'reverse' } }
    const preferences = load('ChapterListPreferencesStore', {
      '@kit.ArkData': { preferences: { getPreferences: async () => prefs, getPreferencesSync: () => prefs } },
      './MangaDetailModels': models, './BackupRestoreActivity': activity,
    })
    const store = new preferences.ChapterListPreferencesStore({ filesDir: dir })
    const first = { ...store.load('a'), sortDirection: 'reverse', groupFilter: 'Group A' }
    await Promise.all([store.save('a', first), store.save('b', { ...store.load('b'), readFilter: 'unread' })])
    assert.equal(store.load('a').groupFilter, 'Group A')
    assert.equal(store.load('b').readFilter, 'unread')
    fail = true
    await assert.rejects(store.save('a', { ...first, readFilter: 'read' }), /disk full/)
    assert.equal(new preferences.ChapterListPreferencesStore({}).load('a').readFilter, 'all')

    const disk = new downloads.OfflineDownloadStore(dir)
    const sameNameA = disk.createManifest('same-name-a', 'chapter', 1, 'queued',
      { sourceKind: comicModels.ComicSourceKind.PRIVATE_LIBRARY, sourceId: 'source-a', seriesId: 'same-name-a' },
      { comicTitle: '同名作品', chapterTitle: '第01话', sourceName: '书源甲' })
    const sameNameB = disk.createManifest('same-name-b', 'chapter', 1, 'queued',
      { sourceKind: comicModels.ComicSourceKind.PRIVATE_LIBRARY, sourceId: 'source-b', seriesId: 'same-name-b' },
      { comicTitle: '同名作品', chapterTitle: '第01话', sourceName: '书源乙' })
    assert.equal(path.basename(disk.comicDir(sameNameA.comicId)), '同名作品 [书源甲]')
    assert.equal(path.basename(disk.comicDir(sameNameB.comicId)), '同名作品 [书源乙]')
    assert.equal(disk.loadManifest(sameNameA.comicId, 'chapter').sourceName, '书源甲')
    assert.equal(disk.loadManifest(sameNameB.comicId, 'chapter').sourceName, '书源乙')

    const layoutRoot = path.join(dir, 'layout')
    const writeLegacyLayout = (comicDirectory, chapterDirectory, comicId, sourceId) => {
      const chapterDir = path.join(layoutRoot, comicDirectory, chapterDirectory)
      fs.mkdirSync(path.join(chapterDir, '.koma'), { recursive: true })
      fs.writeFileSync(path.join(chapterDir, '.koma', 'manifest.v1.json'), JSON.stringify({
        comicId, chapterId: comicId + '-chapter', comicTitle: '同名作品', chapterTitle: '第01话',
        sourceId, pages: [],
      }))
    }
    writeLegacyLayout('0123456789abcdef', '1111111111111111', 'legacy-a', 'source-a')
    writeLegacyLayout('fedcba9876543210', '2222222222222222', 'legacy-b', 'source-b')
    fs.mkdirSync(path.join(layoutRoot, '裸名作品', '第01话', '.koma'), { recursive: true })
    fs.writeFileSync(path.join(layoutRoot, '裸名作品', '第01话', '.koma', 'manifest.v1.json'), JSON.stringify({
      comicId: 'legacy-c', chapterId: 'legacy-c-chapter', comicTitle: '裸名作品', chapterTitle: '第01话',
      sourceId: 'source-c', pages: [],
    }))
    const layout = load('DownloadLayoutMigration', {
      '@kit.CoreFileKit': { fileIo: io },
      '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception() {}, info() {} } },
      './DownloadDirectoryIndex': directoryIndex,
    })
    const sourceName = sourceId => sourceId === 'source-a' ? '书源甲' : sourceId === 'source-b' ? '书源乙' : '书源丙'
    layout.normalizeDownloadLayout(layoutRoot, sourceName)
    const legacyManifestA = path.join(layoutRoot, '同名作品 [书源甲]', '第01话', '.koma', 'manifest.json')
    const legacyManifestB = path.join(layoutRoot, '同名作品 [书源乙]', '第01话', '.koma', 'manifest.json')
    assert.equal(JSON.parse(fs.readFileSync(legacyManifestA, 'utf8')).sourceName, '书源甲')
    assert.equal(JSON.parse(fs.readFileSync(legacyManifestB, 'utf8')).sourceName, '书源乙')
    assert.equal(fs.existsSync(path.join(layoutRoot, '同名作品 [书源甲]', '第01话', '.koma', 'manifest.v1.json')), false)
    const layoutDirectories = () => fs.readdirSync(layoutRoot).filter(name => !name.startsWith('.')).sort()
    assert.deepEqual(layoutDirectories(), ['同名作品 [书源乙]', '同名作品 [书源甲]', '裸名作品 [书源丙]'])
    layout.normalizeDownloadLayout(layoutRoot, sourceName)
    assert.deepEqual(layoutDirectories(), ['同名作品 [书源乙]', '同名作品 [书源甲]', '裸名作品 [书源丙]'])

    let manifest = disk.createManifest('a', '1', 2, 'downloaded')
    // Download filenames may use .img; the exported extension must reflect received bytes.
    for (const index of [1, 0]) {
      const imagePath = disk.pageFilePath('a', '1', 'p' + index, index, 'img')
      const bytes = Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), Buffer.alloc(32, index)])
      fs.writeFileSync(imagePath, bytes)
      manifest = disk.recordPage(manifest, { pageId: 'p' + index, pageIndex: index, localPath: imagePath,
        size: bytes.length, contentHash: downloads.createOfflineDownloadFileContentHash(imagePath), updatedAt: 1 })
    }
    const overlay = { version: 1, balloons: [{ text: '对白', x: 1, y: 2, width: 30 }] }
    manifest = disk.recordPage(manifest, { ...manifest.pages[1], sourceTextOverlay: overlay })
    const derived = path.join(dir, 'derived.jpg')
    fs.writeFileSync(derived, Buffer.from('ffd8ffe000112233', 'hex'))
    let failOverlay = false
    const render = { ReaderPageRenderKind: { LOCAL_FILE_IMAGE: 'local' },
      fetchAndCacheReaderRemoteSource: async source => {
        assert.deepEqual(source.sourceTextOverlay, overlay)
        if (failOverlay) throw new Error('overlay render failure')
        return derived
      } }
    const asyncIo = { ...io, mkdtemp: p => fs.promises.mkdtemp(p), mkdir: p => fs.promises.mkdir(p),
      copyFile: (a,b) => fs.promises.copyFile(a,b), open: async (p,m) => ({ fd: fs.openSync(p,m ? 'w' : 'r') }),
      write: async (fd,value) => fs.writeSync(fd,value), close: async f => fs.closeSync(f.fd),
      rename: (a,b) => fs.promises.rename(a,b), unlink: p => fs.promises.unlink(p), rmdir: p => fs.promises.rmdir(p) }
    const zlib = { CompressLevel: { COMPRESS_LEVEL_NO_COMPRESSION: 0 }, compressFile: async (staging,target) => {
      require('node:child_process').execFileSync('zip',['-q','-0','-r',target,'.'],{cwd:staging})
    } }
    const archive = load('ChapterArchiveExport', {
      './ReaderPageSourceAdapter': render, '@kit.CoreFileKit': { fileIo: asyncIo, fileUri: { getUriFromPath:p=>'file://'+p } },
      '@kit.ArkTS': { taskpool: { execute: async (fn,...args) => fn(...args) } }, '@kit.BasicServicesKit': { zlib },
      '@kit.ShareKit': {}, '@kit.ArkData': {}, './OfflineDownloadStore': downloads, '../i18n/AppStrings': {},
      './KomaContentStorage': { ensureKomaContentStorageBase: async context => context.filesDir },
    })
    const plan = JSON.parse(archive.chapterArchivePagesWorker(dir, 'a', '1'))
    assert.deepEqual(plan.map(p => p.name), ['00001.png', '00002.jpg'])
    const result = await archive.prepareChapterArchive({filesDir:dir,cacheDir:dir},'a','1','Series','Chapter')
    const unzip = (name) => require('node:child_process').execFileSync('unzip',['-p',result.path,name])
    assert.deepEqual(unzip('00001.png'), fs.readFileSync(manifest.pages[0].localPath))
    assert.deepEqual(unzip('00002.jpg'), fs.readFileSync(derived))
    assert.deepEqual(fs.readFileSync(manifest.pages[1].localPath), Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),Buffer.alloc(32,1)]))
    failOverlay = true
    const beforeDirs = new Set(fs.readdirSync(dir))
    await assert.rejects(archive.prepareChapterArchive({filesDir:dir,cacheDir:dir},'a','1','Series','Failed'), /overlay render failure/)
    const created = fs.readdirSync(dir).filter(name => !beforeDirs.has(name))
    for (const name of created) assert.equal(fs.readdirSync(path.join(dir,name)).some(x => /\.(cbz|zip)$/.test(x)), false)
    console.log('CBZ actual archive preserves original pages, includes rendered overlay JPEG and rejects failed rendering')
    assert.equal(path.basename(plan[0].path), '001.img')
    fs.unlinkSync(plan[1].path)
    assert.throws(() => archive.chapterArchivePagesWorker(dir, 'a', '1'), /download_incomplete/)
    console.log('Production queue ordering, per-book preference isolation/rollback and complete ordered CBZ plan passed')
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
main().catch(error => { console.error(error); process.exitCode = 1 })
