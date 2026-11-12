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
const indexIo = { reads: 0, writes: 0 }
const io = {
  accessSync: fs.existsSync, mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
  OpenMode: { READ_ONLY: 0, WRITE_ONLY: 1, CREATE: 2, TRUNC: 4 },
  openSync: (p, mode) => ({ fd: fs.openSync(p, mode ? 'w' : 'r') }), closeSync: f => fs.closeSync(f.fd),
  readTextSync: p => {
    if (path.basename(p) === '.koma-download-index.v1.json') indexIo.reads++
    return fs.readFileSync(p, 'utf8')
  },
  writeSync: fs.writeSync, fsyncSync: fs.fsyncSync,
  renameSync: (from, to) => {
    fs.renameSync(from, to)
    if (path.basename(to) === '.koma-download-index.v1.json') indexIo.writes++
  },
  unlinkSync: fs.unlinkSync, statSync: fs.statSync,
  rmdirSync: fs.rmdirSync,
  listFileSync: p => fs.readdirSync(p),
  access: async p => fs.existsSync(p),
  listFile: (p, options) => fs.promises.readdir(p, { recursive: options.recursion }),
  stat: p => fs.promises.stat(p),
  unlink: p => fs.promises.unlink(p),
  rmdir: p => fs.promises.rmdir(p),
  readSync: (fd, data) => fs.readSync(fd, Buffer.from(data), 0, data.byteLength, null),
}
const logger = { exception() {}, info() {} }
const persistence = load('AppFileTextPersistence', { '@kit.CoreFileKit': { fileIo: io }, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger } })
const directoryIndex = load('DownloadDirectoryIndex', { '@kit.CoreFileKit': { fileIo: io }, './AppFileTextPersistence': persistence })
const activity = load('BackupRestoreActivity')
const overlays = load('SourceTextOverlay')
const comicModels = load('ComicModels', {
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
})
const downloads = load('OfflineDownloadStore', { './SourceTextOverlay': overlays, './AppFileTextPersistence': persistence,
  '@kit.CoreFileKit': { fileIo: io }, './DownloadDirectoryIndex': directoryIndex, './ComicModels': comicModels })
const runtime = load('OfflineDownloadRuntime', { './BackupRestoreActivity': activity })
const queues = load('OfflineDownloadQueueStore', {
  './BackupRestoreActivity': activity, './AppFileTextPersistence': persistence,
  '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger },
  '@kit.CoreFileKit': { fileIo: io }, './OfflineDownloadRuntime': runtime,
  './OfflineDownloadStore': downloads,
})
async function main() {
  const dir = fs.mkdtempSync('/private/tmp/koma-chapter-management-')
  try {
    const queue = new queues.OfflineDownloadQueueStore(dir)
    const entry = (comicId, chapterId) => ({ comicId, chapterId, status: 'queued', pageCount: 1, downloadedPageCount: 0, updatedAt: 1 })
    const publicRoot = path.join(dir, 'public-download')
    const appRoot = path.join(dir, 'app-files')
    const oldQueue = new queues.OfflineDownloadQueueStore(publicRoot)
    oldQueue.addNewEntries([entry('a', '1'), entry('a', '2')])
    oldQueue.move('a', '2', true)
    oldQueue.setTasksPaused([entry('a', '2')], true)
    oldQueue.pauseAllQueuedWork()
    oldQueue.setWifiOnly(true)
    oldQueue.upsert({ ...entry('b', 'done'), status: 'downloaded' })
    const oldSnapshot = oldQueue.loadSnapshot()
    const oldPath = queues.offlineDownloadQueuePath(publicRoot, publicRoot)
    const privatePath = queues.offlineDownloadQueuePath(publicRoot, appRoot)
    assert.equal(queues.readableOfflineDownloadQueuePath(publicRoot, appRoot), oldPath,
      'A background backup before the first app launch still sees the old queue')
    const relocated = new queues.OfflineDownloadQueueStore(publicRoot, appRoot)
    // Block the atomic write. The complete old queue must remain available for retry.
    fs.mkdirSync(path.dirname(privatePath), { recursive: true })
    fs.mkdirSync(privatePath + '.tmp')
    assert.throws(() => relocated.loadSnapshot())
    assert.deepEqual(oldQueue.loadSnapshot(), oldSnapshot)
    assert.equal(fs.existsSync(privatePath), false)
    fs.rmdirSync(privatePath + '.tmp')
    assert.deepEqual(relocated.loadSnapshot(), oldSnapshot)
    assert.equal(fs.existsSync(oldPath), false)
    assert.equal(queues.readableOfflineDownloadQueuePath(publicRoot, appRoot), privatePath)
    // A stale copy retained after an interrupted cleanup cannot undo newer private changes.
    const oldPayload = fs.readFileSync(privatePath, 'utf8')
    relocated.setWifiOnly(false)
    fs.writeFileSync(oldPath, oldPayload)
    const reopened = new queues.OfflineDownloadQueueStore(publicRoot, appRoot)
    reopened.migratePublicQueue()
    assert.equal(reopened.loadPreferences().wifiOnly, false)
    assert.deepEqual(reopened.load(), oldSnapshot.entries)
    assert.equal(fs.existsSync(oldPath), false)

    queue.addNewEntries([entry('a', '1'), entry('a', '2'), entry('b', '3')])
    queue.move('a', '1', true)
    const ordered = () => queue.load().map(e => e.chapterId)
    assert.deepEqual(ordered(), ['1', '2', '3'], 'New chapters append in the request order')
    queue.upsert({ ...entry('b', '3'), status: 'downloading' })
    assert.deepEqual(ordered(), ['1', '2', '3'], 'Progress cannot undo queue order')
    queue.move('a', '1', false, true)
    assert.deepEqual(ordered(), ['3', '1', '2'], 'Whole-series move retains the series internal order')
    assert.deepEqual(new queues.OfflineDownloadQueueStore(dir).load().map(e => e.chapterId), ordered())
    const execution = load('OfflineDownloadQueueExecution', {
      './OfflineDownloadQueueStore': queues, './OfflineDownloadStore': downloads,
    })
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
      'Only pending chapters moved. The completed row stayed between the preceding work and moved rows.')

    const controlRoot = path.join(dir, 'scoped-controls')
    const scoped = new queues.OfflineDownloadQueueStore(controlRoot)
    const a1 = { ...entry('a', '1'), automatic: true }
    const a2 = { ...entry('a', '2'), automatic: true }
    const b1 = { ...entry('b', '1'), automatic: true }
    scoped.addNewEntries([a1, a2, b1])
    scoped.upsert({ ...entry('a', 'done'), status: 'downloaded' })
    scoped.setTasksPaused([a1, a2], true)
    scoped.pauseAllQueuedWork()
    scoped.resumeAllQueuedWork()
    const afterResume = new queues.OfflineDownloadQueueStore(controlRoot)
    assert.deepEqual(afterResume.load().filter(item => item.pausedByUser).map(queues.offlineDownloadTaskKey),
      [a1, a2].map(queues.offlineDownloadTaskKey), 'Global resume preserves independent pauses across a new store')
    const dispatched = []
    await execution.runOrderedDownloadQueueBatch(afterResume, afterResume.load(),
      async item => { dispatched.push(queues.offlineDownloadTaskKey(item)) }, () => true)
    assert.deepEqual(dispatched, [queues.offlineDownloadTaskKey(b1)])

    scoped.setTasksPaused([a1, a2], false)
    let finishTransfer
    const transfer = new Promise(resolve => { finishTransfer = resolve })
    const runningTransfer = runtime.OfflineDownloadRuntime.run(controlRoot, a1.comicId, a1.chapterId, () => transfer)
    const targets = scoped.load().filter(item => item.comicId === 'a')
    const cancel = scoped.cancelTasks(targets)
    const committed = new queues.OfflineDownloadQueueStore(controlRoot).load()
    assert.deepEqual(committed.filter(item => item.canceling).map(queues.offlineDownloadTaskKey),
      [a1, a2].map(queues.offlineDownloadTaskKey), 'The complete cancel scope is committed before the first transfer stops')
    assert.equal(runtime.OfflineDownloadRuntime.isPauseRequested(
      runtime.OfflineDownloadRuntime.key(controlRoot, a1.comicId, a1.chapterId)), true)
    finishTransfer({})
    await runningTransfer
    assert.equal(await cancel, 2)
    assert.deepEqual(scoped.load().map(queues.offlineDownloadTaskKey),
      [b1, entry('a', 'done')].map(queues.offlineDownloadTaskKey), 'Cancellation preserves other works and complete files')

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

    const storageDir = path.join(dir, 'public-content')
    const appFilesDir = path.join(dir, 'app-files')
    const disk = new downloads.OfflineDownloadStore(storageDir, appFilesDir)
    const otherWriter = new downloads.OfflineDownloadStore(storageDir, appFilesDir)
    const sameNameA = disk.createManifest('same-name-a', 'chapter', 1, 'queued',
      { sourceKind: comicModels.ComicSourceKind.PRIVATE_LIBRARY, sourceId: 'source-a', seriesId: 'same-name-a' },
      { comicTitle: '同名作品', chapterTitle: '第01话', sourceName: '书源甲' })
    const sameNameB = otherWriter.createManifest('same-name-b', 'chapter', 1, 'queued',
      { sourceKind: comicModels.ComicSourceKind.PRIVATE_LIBRARY, sourceId: 'source-b', seriesId: 'same-name-b' },
      { comicTitle: '同名作品', chapterTitle: '第01话', sourceName: '书源乙' })
    assert.equal(path.basename(disk.comicDir(sameNameA.comicId)), '同名作品 [书源甲]')
    assert.equal(path.basename(otherWriter.comicDir(sameNameB.comicId)), '同名作品 [书源乙]')
    assert.equal(disk.loadManifest(sameNameA.comicId, 'chapter').sourceName, '书源甲')
    assert.equal(otherWriter.loadManifest(sameNameB.comicId, 'chapter').sourceName, '书源乙')
    assert.equal(otherWriter.loadManifest(sameNameA.comicId, 'chapter').sourceName, '书源甲',
      'A second store opening a directory preserves existing mappings')

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
    const layoutIndexDir = path.join(appFilesDir, 'legacy-layout')
    layout.normalizeDownloadLayout(layoutRoot, layoutIndexDir, sourceName)
    const legacyManifestA = path.join(layoutRoot, '同名作品 [书源甲]', '第01话', '.koma', 'manifest.json')
    const legacyManifestB = path.join(layoutRoot, '同名作品 [书源乙]', '第01话', '.koma', 'manifest.json')
    assert.equal(JSON.parse(fs.readFileSync(legacyManifestA, 'utf8')).sourceName, '书源甲')
    assert.equal(JSON.parse(fs.readFileSync(legacyManifestB, 'utf8')).sourceName, '书源乙')
    assert.equal(fs.existsSync(path.join(layoutRoot, '同名作品 [书源甲]', '第01话', '.koma', 'manifest.v1.json')), false)
    const layoutDirectories = () => fs.readdirSync(layoutRoot).filter(name => !name.startsWith('.')).sort()
    assert.deepEqual(layoutDirectories(), ['同名作品 [书源乙]', '同名作品 [书源甲]', '裸名作品 [书源丙]'])
    layout.normalizeDownloadLayout(layoutRoot, layoutIndexDir, sourceName)
    assert.deepEqual(layoutDirectories(), ['同名作品 [书源乙]', '同名作品 [书源甲]', '裸名作品 [书源丙]'])

    let manifest = disk.createManifest('a', '1', 2, 'downloaded')
    const beforeProgress = { ...indexIo }
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
    assert.deepEqual(indexIo, beforeProgress, 'Page checkpoints never read or rewrite the root index')
    const downloadRoot = path.join(storageDir, downloads.OFFLINE_DOWNLOAD_ROOT_DIR_NAME)
    const publicIndex = directoryIndex.downloadIndexPath(downloadRoot)
    const privateIndex = directoryIndex.downloadIndexPath(downloads.offlineDownloadIndexDirectory(storageDir, appFilesDir))
    assert.equal(fs.existsSync(publicIndex), false)
    // Recreate the layout of the previous app version, then upgrade.
    fs.renameSync(privateIndex, publicIndex)
    fs.writeFileSync(publicIndex + '.tmp', '{')
    fs.mkdirSync(privateIndex + '.tmp')
    assert.throws(() => new downloads.OfflineDownloadStore(storageDir, appFilesDir), /EISDIR/)
    assert.ok(fs.existsSync(publicIndex), 'A failed private write preserves the old index for retry')
    fs.rmdirSync(privateIndex + '.tmp')
    const upgradedDisk = new downloads.OfflineDownloadStore(storageDir, appFilesDir)
    assert.equal(upgradedDisk.resolveDownloadedPage('a', '1', 'p0', 0), manifest.pages[0].localPath)
    assert.ok(fs.existsSync(privateIndex))
    assert.equal(fs.existsSync(publicIndex), false)
    assert.equal(fs.existsSync(publicIndex + '.tmp'), false)
    fs.unlinkSync(privateIndex)
    const recoveredDisk = new downloads.OfflineDownloadStore(storageDir, appFilesDir)
    assert.equal(recoveredDisk.resolveDownloadedPage('a', '1', 'p0', 0), manifest.pages[0].localPath)
    assert.equal(recoveredDisk.loadManifest(sameNameA.comicId, 'chapter').sourceName, '书源甲')
    assert.equal(recoveredDisk.loadManifest(sameNameB.comicId, 'chapter').sourceName, '书源乙')
    const removing = recoveredDisk.deleteChapterDownload(sameNameA.comicId, 'chapter')
    otherWriter.createManifest('same-name-b', 'other-chapter', 0, 'queued')
    await removing
    const afterRemoval = new downloads.OfflineDownloadStore(storageDir, appFilesDir)
    assert.equal(afterRemoval.loadManifest(sameNameA.comicId, 'chapter'), undefined)
    assert.ok(afterRemoval.loadManifest(sameNameB.comicId, 'other-chapter'),
      'Finishing a deletion preserves newly allocated directories from another store')
    assert.equal(fs.existsSync(publicIndex), false, 'Recovery and later mutations never recreate the public index')
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
      '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { warn: () => {} } },
      './KomaContentStorage': { ensureKomaContentStorageBase: async () => storageDir },
    })
    const plan = JSON.parse(archive.chapterArchivePagesWorker(storageDir, appFilesDir, 'a', '1'))
    assert.deepEqual(plan.map(p => p.name), ['00001.png', '00002.jpg'])
    const result = await archive.prepareChapterArchive({filesDir:appFilesDir,cacheDir:dir},'a','1','Series','Chapter')
    const unzip = (name) => require('node:child_process').execFileSync('unzip',['-p',result.path,name])
    assert.deepEqual(unzip('00001.png'), fs.readFileSync(manifest.pages[0].localPath))
    assert.deepEqual(unzip('00002.jpg'), fs.readFileSync(derived))
    assert.deepEqual(fs.readFileSync(manifest.pages[1].localPath), Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),Buffer.alloc(32,1)]))
    let other = disk.createManifest('a', '2', 1, 'downloaded')
    const otherPath = disk.pageFilePath('a', '2', 'p0', 0, 'img')
    const otherBytes = Buffer.from('89504e470d0a1a0a1011', 'hex')
    fs.writeFileSync(otherPath, otherBytes)
    other = disk.recordPage(other, { pageId: 'p0', pageIndex: 0, localPath: otherPath, size: otherBytes.length,
      contentHash: downloads.createOfflineDownloadFileContentHash(otherPath), updatedAt: 1 })
    const chapterOrder = [{ id: '2', title: 'Chapter 2 & "special"' }, { id: '1', title: 'Chapter 1' }]
    const progress = []
    const combined = await archive.prepareWorkArchive({ filesDir: appFilesDir, cacheDir: dir }, 'a', 'Series',
      chapterOrder, { isCanceled: () => false, onChapterPrepared: count => progress.push(count) })
    const readCombined = name => require('node:child_process').execFileSync('unzip', ['-p', combined.path, name])
    assert.equal(combined.fileName, 'Series.cbz')
    assert.deepEqual(progress, [1, 2])
    assert.deepEqual(readCombined('00000001.png'), otherBytes)
    assert.deepEqual(readCombined('00000002.png'), fs.readFileSync(manifest.pages[0].localPath))
    assert.deepEqual(readCombined('00000003.jpg'), fs.readFileSync(derived))
    const xmlPages = require('node:child_process').execFileSync('python3', ['-c',
      'import json,sys,xml.etree.ElementTree as E; r=E.fromstring(sys.stdin.buffer.read()); print(json.dumps([p.attrib for p in r.findall("./Pages/Page")]))'],
      { input: readCombined('ComicInfo.xml') })
    const nodes = JSON.parse(xmlPages).map(attributes => ({ _name: 'Page', _attributes: attributes }))
    const bookmarkParser = load('../import/ComicArchiveBookmarkParser')
    assert.deepEqual(bookmarkParser.comicArchiveBookmarks({ _elements: nodes }, 3), [
      { title: 'Chapter 2 & "special"', pageIndex: 0 }, { title: 'Chapter 1', pageIndex: 1 },
    ], 'The exported chapter bookmarks round-trip through the import parser at the selected page boundaries')
    const beforeCancel = fs.readdirSync(dir)
    let cancelExport = false
    await assert.rejects(archive.prepareWorkArchive({ filesDir: appFilesDir, cacheDir: dir }, 'a', 'Series',
      chapterOrder, { isCanceled: () => cancelExport, onChapterPrepared: () => { cancelExport = true } }),
    /chapter_archive_canceled/)
    assert.deepEqual(fs.readdirSync(dir), beforeCancel, 'Cancel discards the staging directory and partial archive')
    failOverlay = true
    const beforeDirs = new Set(fs.readdirSync(dir))
    await assert.rejects(archive.prepareChapterArchive({filesDir:appFilesDir,cacheDir:dir},'a','1','Series','Failed'), /overlay render failure/)
    const created = fs.readdirSync(dir).filter(name => !beforeDirs.has(name))
    for (const name of created) assert.equal(fs.readdirSync(path.join(dir,name)).some(x => /\.(cbz|zip)$/.test(x)), false)
    console.log('CBZ actual archive preserves original pages, includes rendered overlay JPEG and rejects failed rendering')
    assert.equal(path.basename(plan[0].path), '001.img')
    fs.unlinkSync(plan[1].path)
    assert.throws(() => archive.chapterArchivePagesWorker(storageDir, appFilesDir, 'a', '1'), /download_incomplete/)
    console.log('Production queue ordering, per-book preference isolation/rollback and complete ordered CBZ plan passed')
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
main().catch(error => { console.error(error); process.exitCode = 1 })
