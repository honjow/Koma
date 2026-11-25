const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function fixture() {
  const modules = new Map()
  const states = new Map()
  const values = new Map()
  const dataObjects = []
  const deleted = []
  let beforeSave = async () => {}
  let uptime = 0
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
          window: {},
        }
      }
      if (name === '@kit.ArkData') return {
        preferences: { getPreferences: async () => preference },
        distributedDataObject: {
          genSessionId: () => 'generated-session',
          create(context, data) {
            const object = Object.assign(data, {
              on(_event, listener) { this.listener = listener },
              off() { this.listener = undefined },
              async setSessionId(id) { this.sessionId = id },
              async save() { await beforeSave() },
              deliver(payloadJson, sourcePackage) {
                this.payloadJson = payloadJson
                this.sourcePackage = sourcePackage
                this.listener?.(this.sessionId, 'device', 'restored')
              },
            })
            dataObjects.push(object)
            return object
          },
        },
      }
      if (name === '@kit.AbilityKit') return {
        AbilityConstant: {
          ContinueState: { ACTIVE: 1, INACTIVE: 0 },
          OnContinueResult: { AGREE: 0, REJECT: 1, MISMATCH: 2 },
        },
        wantConstant: { Params: { SUPPORT_CONTINUE_PAGE_STACK_KEY: 'stack', SUPPORT_CONTINUE_SOURCE_EXIT_KEY: 'exit' } },
      }
      if (name === '@kit.ArkTS') return {}
      if (name === '@kit.BasicServicesKit') return {
        commonEventManager: {
          Support: {},
          async createSubscriber() { return {} },
          async subscribeToEvent() {},
          unsubscribe() {},
        },
        systemDateTime: { TimeType: {}, getUptime: () => uptime },
      }
      if (name === '@kit.UserAuthenticationKit' || name === '@kit.CryptoArchitectureKit') return {}
      if (name === '@kit.CoreFileKit') return {
        fileIo: { unlinkSync: path => deleted.push(path) },
        fileUri: { getUriFromPath: path => 'file://koma' + path },
      }
      if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { info() {}, warn() {}, exception() {} } }
      if (name === '../theme/KomaPopupOptions') return {}
      if (name === '../sourceRuntime/SourcePackageShare') return { canShareInstalledSourcePackage: () => false }
      if (name === '../sourceRuntime/SourceRuntimeAppRegistry') return { getInstalledSourcePackage: () => undefined }
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
    context: {
      filesDir: '/continuation-test',
      distributedFilesDir: '/continuation-test/distributed',
      setMissionContinueState(_state, callback) { callback() },
    },
    service: () => load('continuation/ReaderContinuationService').appReaderContinuation,
    privacy: () => new (load('state/LibraryPrivacyState').LibraryPrivacyState)(),
    dataObjects,
    deleted,
    beforeSave(callback) { beforeSave = callback },
    advanceTime(ms) { uptime += ms },
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
  assert.equal(decodeReaderContinuationPayload(raw.replace('zh.test:m1', 'other:m1')), undefined)
})

const outgoing = {
  sourceId: 'zh.test', sourceName: 'Source', comicId: 'zh.test:work', mangaId: 'work', title: 'Work',
  chapterId: 'chapter', pageIndex: 8, totalPages: 20, requiresPrivacyAuth: false,
}

test('closing or locking the reader during system save rejects an outdated transfer', async () => {
  const f = fixture()
  const service = f.service()
  service.publishActiveReading(outgoing)
  f.beforeSave(async () => service.publishActiveReading(undefined))
  const want = { version: 28, targetDevice: 'target' }
  assert.equal(await service.handleOnContinue(f.context, want), 1)
  assert.equal(want['koma.continuation.sessionId'], undefined)
  assert.equal(f.dataObjects[0].sessionId, '')

  service.publishActiveReading(outgoing)
  f.beforeSave(async () => {})
  assert.equal(await service.handleOnContinue(f.context, want), 0)
  assert.equal(want['koma.continuation.sessionId'], 'generated-session')
  assert.equal(JSON.parse(f.dataObjects[1].payloadJson).pageIndex, 8)
})

test('the receiver waits for its window, discards superseded tasks and ignores old callbacks', () => {
  const f = fixture()
  const service = f.service()
  const raw = JSON.stringify({ ...outgoing, schemaVersion: 1 })
  const firstFile = '/continuation-test/distributed/koma-continue-1234.koma'
  service.setRestoreGateOpen(false)
  service.beginTargetRestore(f.context, { parameters: { 'koma.continuation.sessionId': 'first' } })
  const oldListener = f.dataObjects[0].listener
  assert.equal(f.dataObjects[0].sourcePackage, undefined)
  f.dataObjects[0].deliver(raw, { uri: 'file://koma' + firstFile, path: firstFile })
  assert.equal(service.consumePendingRestore(), undefined)
  service.beginTargetRestore(f.context, { parameters: { 'koma.continuation.sessionId': 'second' } })
  assert.deepEqual(f.deleted, [firstFile])
  oldListener('first', 'device', 'restored')
  service.setRestoreGateOpen(true)
  assert.equal(service.consumePendingRestore(), undefined)
  f.dataObjects[1].deliver(raw, undefined)
  const transferred = service.consumePendingRestore()
  assert.equal(transferred.payload.pageIndex, 8)
  assert.equal(service.isCurrentRestore(transferred.id), true)
  service.beginTargetRestore(f.context, { parameters: {} })
  assert.equal(service.isCurrentRestore(transferred.id), false)
  service.cleanupDistributedTempFile('/continuation-test/distributed/../private.db')
  assert.deepEqual(f.deleted, [firstFile])
})

test('a transferred private work stays protected after the device locks or its local grant expires', async () => {
  const f = fixture()
  const privacy = f.privacy()
  const protections = []
  await privacy.attach({
    async setWindowPrivacyMode(value) { protections.push(value) },
  }, { on() {}, off() {} })
  privacy.verify = async () => 0

  assert.equal(await privacy.activateContinuationPrivacy(f.context, 'private-a', () => true), 0)
  assert.equal(privacy.privateContinuation('private-a'), true)
  assert.equal(privacy.visibleContinuation('private-a'), true)
  privacy.onBackground()
  f.advanceTime(31_000)
  privacy.onForeground()
  assert.equal(privacy.privateContinuation('private-a'), true)
  assert.equal(privacy.visibleContinuation('private-a'), false)
  assert.equal(protections.at(-1), true)

  assert.equal(await privacy.activateContinuationPrivacy(f.context, 'private-b', () => true), 0)
  assert.equal(privacy.visibleContinuation('private-b'), true)
  assert.equal(privacy.visibleContinuation('private-a'), false)
  privacy.releaseContinuationPrivacy('private-b')
  assert.equal(privacy.privateContinuation('private-b'), false)
  assert.equal(protections.at(-1), true)
  privacy.releaseContinuationPrivacy('private-a')
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(protections.at(-1), false)
})
