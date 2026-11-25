const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture() {
  const modules = new Map()
  const states = new Map()
  const values = new Map()
  let failFlush = false
  const preference = {
    has: async key => values.has(key),
    get: async (key, fallback) => values.has(key) ? values.get(key) : fallback,
    put: async (key, value) => { values.set(key, value) },
    delete: async key => { values.delete(key) },
    flush: async () => {
      if (failFlush) {
        failFlush = false
        throw new Error('disk full')
      }
    },
  }
  function load(file) {
    if (modules.has(file)) return modules.get(file)
    const exports = {}
    modules.set(file, exports)
    const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets', file + '.ets'), 'utf8')
    const js = ts.transpileModule(source, {
      compilerOptions: {
        target: ts.ScriptTarget.ES2020,
        module: ts.ModuleKind.CommonJS,
        experimentalDecorators: true,
      },
    }).outputText
    new Function('require', 'exports', 'ObservedV2', 'Trace', js)(name => {
      if (name === '@kit.ArkUI') {
        return {
          AppStorageV2: {
            connect(_type, key, factory) {
              if (!states.has(key)) states.set(key, factory())
              return states.get(key)
            },
          },
        }
      }
      if (name === '@kit.ArkData') return { preferences: { getPreferences: async () => preference } }
      if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key } }
      if (name.startsWith('.')) {
        return load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name)))
      }
      throw new Error('Unexpected import ' + name)
    }, exports, () => {}, () => {})
    return exports
  }
  const state = load('state/ContinuationState').connectContinuationState()
  const Store = load('model/ContinuationPreferencesStore').ContinuationPreferencesStore
  const payloadMod = load('continuation/ReaderContinuationPayload')
  return {
    state,
    Store,
    values,
    payloadMod,
    context: { filesDir: '/continuation-test' },
    failNextFlush() { failFlush = true },
  }
}

test('continuation preferences default to enabled and silent auto-install', async () => {
  const f = fixture()
  const store = new f.Store(f.context)
  assert.equal(f.state.enabled, true)
  assert.equal(f.state.autoInstallMissingSource, true)

  await store.load()
  assert.equal(f.state.enabled, true)
  assert.equal(f.state.autoInstallMissingSource, true)

  await store.saveAutoInstallMissingSource(false)
  assert.equal(f.values.get('continuation.autoInstallMissingSource'), false)
  assert.equal(f.state.autoInstallMissingSource, false)

  await store.saveEnabled(false)
  assert.equal(f.values.get('continuation.enabled'), false)
  assert.equal(f.state.enabled, false)

  f.state.enabled = true
  f.state.autoInstallMissingSource = true
  await new f.Store(f.context).load()
  assert.equal(f.state.enabled, false)
  assert.equal(f.state.autoInstallMissingSource, false)
})

test('failed continuation preference flush rolls back stored and published state', async () => {
  const f = fixture()
  const store = new f.Store(f.context)
  await store.saveEnabled(true)
  f.failNextFlush()
  await assert.rejects(store.saveEnabled(false), /disk full/)
  assert.equal(f.values.get('continuation.enabled'), true)
  assert.equal(f.state.enabled, true)
})

test('source continuation eligibility blocks incognito, locked privacy, non-source works, and continuedAway', () => {
  const { canContinueSourceSession } = fixture().payloadMod
  const base = {
    continuationEnabled: true,
    readerOpen: true,
    readerClosing: false,
    readerRouteVisible: true,
    readerSessionLoading: false,
    continuedAway: false,
    incognitoEnabled: false,
    sourceIncognitoEnabled: false,
    privacyLocked: false,
    sourceKind: 'private_library',
    sourceId: 'zh.dmzj',
    mangaId: '12345',
    chapterId: 'ch-1',
  }
  assert.equal(canContinueSourceSession(base), true)
  assert.equal(canContinueSourceSession({ ...base, continuationEnabled: false }), false)
  assert.equal(canContinueSourceSession({ ...base, readerRouteVisible: false }), false)
  assert.equal(canContinueSourceSession({ ...base, continuedAway: true }), false)
  assert.equal(canContinueSourceSession({ ...base, incognitoEnabled: true }), false)
  assert.equal(canContinueSourceSession({ ...base, sourceIncognitoEnabled: true }), false)
  assert.equal(canContinueSourceSession({ ...base, privacyLocked: true }), false)
  assert.equal(canContinueSourceSession({ ...base, sourceKind: 'local_archive' }), false)
  assert.equal(canContinueSourceSession({ ...base, sourceId: 'mihon:abc' }), false)
  assert.equal(canContinueSourceSession({ ...base, mangaId: '' }), false)
})

test('payload roundtrip, version check, page clamping, and source request builder', () => {
  const {
    CONTINUATION_SCHEMA_VERSION,
    encodeReaderContinuationPayload,
    decodeReaderContinuationPayload,
    isContinuationTargetVersionCompatible,
    resolveContinuationPageIndex,
    buildSourceRequestFromContinuation,
  } = fixture().payloadMod

  const raw = encodeReaderContinuationPayload({
    schemaVersion: CONTINUATION_SCHEMA_VERSION,
    sourceId: 'zh.test',
    sourceName: 'TestSource',
    mangaId: 'm1',
    mangaUrl: 'https://example.com/m/1',
    comicId: 'zh.test:m1',
    title: 'Sample Manga',
    chapterId: 'c5',
    chapterTitle: 'Chapter 5',
    pageIndex: 17,
    totalPages: 24,
    requiresPrivacyAuth: true,
    privateCategoryId: 'priv-1',
    timestamp: 123456,
  })
  const decoded = decodeReaderContinuationPayload(raw)
  assert.ok(decoded)
  assert.equal(decoded.sourceId, 'zh.test')
  assert.equal(decoded.pageIndex, 17)
  assert.equal(decoded.requiresPrivacyAuth, true)
  assert.equal(decoded.privateCategoryId, 'priv-1')

  const req = buildSourceRequestFromContinuation(decoded)
  assert.equal(req.comicId, 'zh.test:m1')
  assert.deepEqual(req.chapterIds, ['c5'])
  assert.equal(req.chaptersResolved, false)

  assert.equal(resolveContinuationPageIndex(17, 24), 17)
  assert.equal(resolveContinuationPageIndex(17, 10), 9)
  assert.equal(resolveContinuationPageIndex(-3, 10), 0)
  assert.equal(resolveContinuationPageIndex(17, 0), 17)

  assert.equal(isContinuationTargetVersionCompatible(27, 28), false)
  assert.equal(isContinuationTargetVersionCompatible(28, 28), true)
  assert.equal(isContinuationTargetVersionCompatible(undefined, 28), true)
  assert.equal(decodeReaderContinuationPayload('{"schemaVersion":99}'), undefined)
})
