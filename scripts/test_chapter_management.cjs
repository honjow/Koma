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
  readSync: (fd, data) => fs.readSync(fd, Buffer.from(data), 0, data.byteLength, null),
}
const logger = { exception() {} }
const persistence = load('AppFileTextPersistence', { '@kit.CoreFileKit': { fileIo: io }, '../diagnostics/DiagnosticLogger': { DiagnosticLogger: logger } })
const activity = load('BackupRestoreActivity')
const downloads = load('OfflineDownloadStore', { './AppFileTextPersistence': persistence,
  '@kit.CoreFileKit': { fileIo: io }, './ComicModels': load('ComicModels', {
    '../i18n/AppStrings': { AppStrings: { get: key => key } },
  }) })
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
    let manifest = disk.createManifest('a', '1', 2, 'downloaded')
    // Download filenames may use .img; the exported extension must reflect received bytes.
    for (const index of [1, 0]) {
      const imagePath = disk.pageFilePath('a', '1', 'p' + index, index, 'img')
      const bytes = Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), Buffer.alloc(32, index)])
      fs.writeFileSync(imagePath, bytes)
      manifest = disk.recordPage(manifest, { pageId: 'p' + index, pageIndex: index, localPath: imagePath,
        size: bytes.length, contentHash: downloads.createOfflineDownloadFileContentHash(imagePath), updatedAt: 1 })
    }
    const archive = load('ChapterArchiveExport', {
      '@kit.CoreFileKit': { fileIo: io }, '@kit.ArkTS': {}, '@kit.BasicServicesKit': {},
      '@kit.ShareKit': {}, '@kit.ArkData': {}, './OfflineDownloadStore': downloads, '../i18n/AppStrings': {},
    })
    const plan = JSON.parse(archive.chapterArchivePagesWorker(dir, 'a', '1'))
    assert.deepEqual(plan.map(p => p.name), ['00001.png', '00002.png'])
    assert.ok(plan[0].path.includes('00001-'))
    fs.unlinkSync(plan[1].path)
    assert.throws(() => archive.chapterArchivePagesWorker(dir, 'a', '1'), /download_incomplete/)
    console.log('Production queue ordering, per-book preference isolation/rollback and complete ordered CBZ plan passed')
  } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
main().catch(error => { console.error(error); process.exitCode = 1 })
