const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = fs.readFileSync('entry/src/main/ets/model/OfflineDownloadBatch.ets', 'utf8')
const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
let rows = [], runnable = true, published = [], pauseAfter = false, downloaded = []
const statuses = { DOWNLOADED: 'downloaded', QUEUED: 'queued', DOWNLOADING: 'downloading', BLOCKED: 'blocked', FAILED: 'failed' }
const pending = e => e.status === 'queued' || e.status === 'downloading'
class Queue {
 loadPreferences() { return {} }
 load() { return rows.map(e => ({ ...e })) }
 upsert(entry) { const i = rows.findIndex(e => e.comicId === entry.comicId && e.chapterId === entry.chapterId); rows[i] = { ...entry } }
}
class Service {
 static async ensureQueueInitialized() {}
 async downloadChapter(comic, chapter) {
  downloaded.push({ comic, chapter })
  const row = rows.find(e => e.chapterId === chapter)
  row.status = chapter === 'bad' ? 'failed' : 'downloaded'
  if (pauseAfter) runnable = false
  return { status: row.status }
 }
}
const deps = {
 './ComicModels': { sameComicIdentity: () => true },
 './OfflineDownloadQueueStore': { OfflineDownloadQueueStore: Queue, isOfflineDownloadTaskPending: pending,
   hasOfflineDownloadSourceIdentity: entry => Boolean(entry.sourceId && entry.sourceMangaId) },
 './OfflineDownloadService': { OfflineDownloadService: Service, canRunOfflineDownloadQueueNow: () => runnable,
   publicSourceWorkUri: (_source, value) => value },
 './OfflineDownloadStore': { OfflineDownloadStore: class {}, OfflineDownloadStatus: statuses },
 './BackgroundDownloadOwner': { BackgroundDownloadOwner: { run: async (_c, op) => op() } },
 './OfflineDownloadNotificationStore': { publishOfflineDownloadSummary: async (_c, ok, failed) => { published.push([ok, failed]) } },
 './OfflineDownloadQueueExecution': { runOrderedDownloadQueueBatch: async (_q, targets, execute, canRun) => {
  for (const item of targets) { if (!canRun()) break; await execute(item) }
 } },
 './OfflineDownloadRuntime': { OfflineDownloadRuntime: { isRemovingChapter: () => false } },
 '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception() {} } },
 './KomaContentStorage': { ensureKomaContentStorageBase: async () => '/tmp', komaRuntimeStorageKey: () => '/tmp' },
 './SourceChapterPageHydrator': { SourceChapterPageHydrator: class {}, resolveSourceChapterPages: async (_registry, request) => {
  assert.equal(request.mangaId, 'remote-book')
  assert.equal(request.chapterId, 'offline-only')
  assert.equal(request.mangaUrl, 'https://test.invalid/works/remote-book')
  return { pages: [{ index: 0 }] }
 } },
 './SourceLibraryComic': { comicFromSourceManga: (manga, chapters, id) => ({
  id, title: manga.title, sourcePath: manga.url, chapters
 }) },
 './SourceMangaDetailRequest': { fetchSourceMangaDetail: async (_source, mangaId) => ({
  detail: { url: 'https://test.invalid/works/' + mangaId },
 }) },
 './SourceMangaDetailSnapshotCache': { sourceMangaDetailSnapshotCache: { read: () => undefined } },
 '../sourceRuntime/SourceSettingsStore': { appSourceSettingsStore: { loadForSource: () => ({}) } },
 '../sourceRuntime/SourceSettingsIdentity': { sourceSettingsFingerprint: () => '' },
}
const mod = {}
new Function('exports', 'require', code)(mod, name => { if (!(name in deps)) throw Error(name); return deps[name] })
const make = chapterId => ({ comicId: 'book', chapterId, requestId: chapterId, automatic: true, status: 'queued' })
const request = { context: { filesDir: '/test' }, library: { getComic: () => ({ id: 'book', title: 'Book', chapters: [] }) }, registry: {} }
test('completed and failed chapters publish one queue summary', async () => {
 rows = [make('one'), make('two'), make('bad')]; published = []; runnable = true; pauseAfter = false
 await mod.resumeAutomaticDownloads(request)
 assert.deepEqual(published, [[2, 1]])
})
test('pausing a queue with chapters remaining does not announce completion', async () => {
 rows = [make('one'), make('two')]; published = []; runnable = true; pauseAfter = true
 await mod.resumeAutomaticDownloads(request)
 assert.deepEqual(published, [])
 assert.equal(rows[1].status, 'queued')
})

test('a cold download queue resolves the work and chapter without a shelf record', async () => {
 rows = [{ ...make('offline-only'), sourceId: 'test-source', sourceMangaId: 'remote-book' }]
 published = []; downloaded = []; runnable = true; pauseAfter = false
 const requestWithoutShelf = {
  ...request,
  library: { getComic: () => undefined },
  registry: { lookup: () => ({ entry: { enabled: true } }) },
 }
 await mod.resumeAutomaticDownloads(requestWithoutShelf)
 assert.equal(rows[0].status, 'downloaded')
 assert.equal(downloaded[0].comic.sourcePath, 'https://test.invalid/works/remote-book')
 assert.equal(downloaded[0].comic.chapters[0].pages.length, 1)
 assert.deepEqual(published, [[1, 0]])
})
