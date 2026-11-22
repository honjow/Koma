const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

test('the hosted reader resolves the selected work even when a full library read would fail', () => {
  const work = { id: 'shelf-book', title: 'Test book', chapters: [{ id: 'chapter', title: 'Test chapter' }] }
  const core = require('../third_party/reader-kit/tests/load-core.cjs')('ReaderSession')
  const modules = {
    '@reader-kit/core': core,
    '../model/LibraryStore': { InMemoryLibraryStore: class {} },
    '../model/LibraryPersistence': {
      AppFilesLibraryStorePersistenceAdapter: class {
        load() { throw new Error('unavailable compatibility snapshot') }
      },
    },
    '../model/ReaderPageSourceAdapter': {
      configureReaderOfflineDownloads() {},
      configureReaderRemoteImageCache() {},
    },
    './KomaReaderLabThumbnailProvider': { KomaReaderLabThumbnailProvider: class {} },
  }
  const exported = {}
  const source = fs.readFileSync(path.resolve(__dirname,
    '../entry/src/main/ets/readerLab/KomaReaderLabAdapter.ets'), 'utf8')
  const code = ts.transpileModule(source, { compilerOptions: {
    target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
  } }).outputText
  new Function('exports', 'require', code)(exported, name => modules[name] ?? {})
  const Adapter = exported.KomaReaderLabAdapter
  const adapter = new Adapter('/files', '/cache', 100, {
    initial: () => null,
    work: id => id === work.id ? work : undefined,
  })
  const key = adapter.initialKey(work.id, 'chapter')
  assert.equal(adapter.workTitle(key), work.title)
  assert.equal(adapter.chapterTitle(key), work.chapters[0].title)
  assert.throws(() => new Adapter('/files', '/cache', 100), /unavailable compatibility snapshot/)
})
