const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')

function subject(file, owner, names, globals = {}, extra = '') {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.getText(tree) === owner)
  const members = names.map(name => {
    const member = cls.members.find(value => value.name?.getText(tree) === name)
    assert.ok(member, `${owner}.${name}`)
    return member.getText(tree).replace(/^\s*@Monitor\([^\n]+\)\s*/m, '')
  })
  const output = {}
  vm.runInNewContext(ts.transpileModule(`${extra}\nexport class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: output, console: { warn() {} }, ...globals })
  return output.Subject
}

class Cancellation {
  cancelled = false
  cancel() { this.cancelled = true }
  isCancelled() { return this.cancelled }
}
const backend = { LEGACY: 'legacy', SHARED: 'shared' }
const config = chapterId => ({ comicId: 'book', chapterId, chapterIds: ['A', 'B'], totalPages: 2,
  pageUris: [`${chapterId}1`, `${chapterId}2`] })
const common = { KomaReaderBackend: backend, ReaderCancellation: Cancellation, ReaderTrialWindow: class {} }

// Lifecycle registration guard, not UI acceptance: ArkUI overwrites identical Monitor path lists.
test('embedded reader lifecycle has no duplicate Monitor registrations', () => {
  const file = 'readerLab/KomaReaderLabPage.ets'
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.text === 'KomaReaderLabPage')
  const registrations = new Map()
  for (const member of cls.members) {
    for (const decorator of ts.getDecorators(member) || []) {
      const expression = decorator.expression
      if (!ts.isCallExpression(expression) || expression.expression.getText(tree) !== 'Monitor') continue
      const key = expression.arguments.map(argument => argument.text).join(' ')
      const name = member.name.getText(tree)
      assert.equal(registrations.has(key), false, `${name} would replace ${registrations.get(key)} for ${key}`)
      registrations.set(key, name)
    }
  }
  assert.equal(registrations.get('routeActive labVisibility.foreground'), 'onChapterActivityChanged')
})

test('backend is captured on new routes; preparation publishes one immutable external-open identity', () => {
  let selected = 'shared'
  const source = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8')
  const tree = ts.createSourceFile('Index', source, ts.ScriptTarget.Latest, true)
  const entry = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.text === 'KomaSharedReaderEntry')
  const Host = subject('pages/Index.ets', 'Index',
    ['beginSharedReaderOpen', 'readerPreparationCurrent', 'publishSharedReaderEntry', 'sharedReaderEntryCurrent'], {
      ...common, connectKomaReaderBackendSelection: () => ({ current: debug => debug ? selected : 'legacy' }),
      ReaderLabRequest: class { constructor(work, unit, pageIndex) { Object.assign(this, { work, unit, pageIndex }) } },
    }, entry.getText(tree))
  const host = new Host()
  Object.assign(host, { readerBackend: 'legacy', readerForeground: { active: true },
    readerOpen: true, readerClosing: false, readerOpenEpoch: 1, readerSessionConfig: config('A'),
    readerPageIndex: 1, readerSessionLoading: true, readerCloseRequestId: 4,
    getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug: true } }) }),
  })
  host.beginSharedReaderOpen(true)
  host.publishSharedReaderEntry(1)
  assert.equal(host.sharedReaderEntries.length, 0, 'pending config cannot mount a reader')
  host.readerSessionLoading = false
  host.publishSharedReaderEntry(1)
  const opened = host.sharedReaderEntries[0]
  assert.equal(opened.request.unit, 'A')
  assert.equal(opened.initialCloseRequestId, 4)
  assert.equal(opened.request.progressReadWrite, true)
  assert.equal(opened.request.preferencesReadWrite, true)
  assert.equal(opened.request.pageIndexProvided, true)
  host.readerSessionConfig = config('B') // A committed internal chapter is not an external open.
  assert.equal(host.sharedReaderEntries[0], opened)
  selected = 'legacy'
  host.readerOpenEpoch = 2
  const routeWindow = host.sharedReaderWindow
  host.beginSharedReaderOpen(false)
  assert.equal(host.sharedReaderWindow, routeWindow, 'external chapter replacement retains the route window')
  assert.equal(host.readerBackend, 'shared', 'detail-to-chapter retains route backend')
  host.publishSharedReaderEntry(1)
  assert.equal(host.sharedReaderEntries.length, 0, 'late external open cannot publish')
  host.publishSharedReaderEntry(2)
  assert.equal(host.sharedReaderEntries[0].request.unit, 'B')
  host.readerClosing = true
  assert.equal(host.sharedReaderEntryCurrent(2), false, 'late onShown cannot activate a closing shared route')
  host.readerClosing = false
  host.beginSharedReaderOpen(true)
  assert.equal(host.readerBackend, 'legacy')
})

test('old source resolution cannot replace a newer chapter or publish history', async () => {
  let resolvePages
  const Host = subject('pages/Index.ets', 'Index', ['readerPreparationCurrent', 'prepareSourceReaderSession'], {
    ...common, cloneSourceReaderSessionRequest: value => ({ ...value }),
    resolveSourceChapterPages: () => new Promise(resolve => { resolvePages = resolve }),
  })
  const host = new Host()
  const old = { comicId: 'book', chapterId: 'A', sourceId: 'source', mangaId: 'book', chaptersResolved: true }
  Object.assign(host, { readerOpenEpoch: 1, readerOpen: true, readerClosing: false, readerBackend: 'shared',
    sharedReaderPreparation: new Cancellation(), activeSourceReaderRequest: old,
    readerSessionConfig: config('A'), readerSessionLoading: true,
    publishSharedReaderEntry: () => assert.fail('stale entry published'),
    readerSessionStore: { saveSourceHistory: () => assert.fail('stale history saved') },
  })
  const pending = host.prepareSourceReaderSession(old, 1)
  host.readerOpenEpoch = 2
  host.activeSourceReaderRequest = { ...old, chapterId: 'B' }
  host.readerSessionConfig = config('B')
  resolvePages({ pages: [{ id: 'old', uri: 'old' }] })
  await pending
  assert.equal(host.readerSessionConfig.chapterId, 'B')
  assert.equal(host.readerSessionLoading, true)
})

test('chapter chosen above Reader reuses its route, retires the old entry and prepares the selected chapter', async () => {
  const paths = ['Reader', 'MangaDetail']
  const actions = []
  const Host = subject('pages/Index.ets', 'Index', ['openSourceReader', 'beginSharedReaderOpen',
    'isReaderDetailRouteVisible'], {
    ...common, RouteName: { READER: 'Reader', MANGA_DETAIL: 'MangaDetail' },
    cloneSourceReaderSessionRequest: value => ({ ...value }),
    connectKomaReaderBackendSelection: () => assert.fail('same route must not select a new backend'),
  })
  const host = new Host()
  const oldPreparation = new Cancellation()
  Object.assign(host, { readerOpen: true, readerClosing: false, readerBackend: 'shared', readerOpenEpoch: 3,
    readerForeground: { active: true }, sharedReaderEntries: [{ epoch: 3 }],
    sharedReaderPreparation: oldPreparation, sharedReaderClosing: null,
    appPathStack: { getAllPathName: () => paths, pop: () => { paths.pop(); actions.push('pop-detail') },
      pushPath: () => assert.fail('second Reader route') },
    createSourceReaderSessionConfig: request => ({ ...config(request.chapterId), totalPages: 0, pageUris: [] }),
    readerSessionStore: { openPageIndex: () => 0 },
    prepareCurrentSharedReader: epoch => actions.push(['prepare', epoch, host.activeSourceReaderRequest.chapterId]),
  })
  await host.openSourceReader({ comicId: 'book', mangaId: 'manga', sourceId: 'source',
    chapterId: 'B', chapterIds: ['A', 'B'] })
  assert.deepEqual(paths, ['Reader'])
  assert.equal(host.readerSessionLoading, true)
  assert.equal(host.readerSessionConfig.chapterId, 'B')
  assert.equal(host.sharedReaderEntries.length, 0)
  assert.equal(oldPreparation.isCancelled(), true)
  assert.deepEqual(actions, ['pop-detail', ['prepare', 4, 'B']])
})

test('background cancels pending preparation; foreground starts only that pending request once', () => {
  const Host = subject('pages/Index.ets', 'Index', ['onSharedReaderForegroundChanged'], common)
  const host = new Host()
  const epochs = []
  const pending = new Cancellation()
  Object.assign(host, { readerBackend: 'shared', readerOpen: true, readerClosing: false,
    readerForeground: { active: false }, sharedReaderPreparation: pending, readerOpenEpoch: 9,
    prepareCurrentSharedReader: epoch => epochs.push(epoch) })
  host.onSharedReaderForegroundChanged()
  assert.equal(pending.isCancelled(), true)
  host.readerForeground.active = true
  host.onSharedReaderForegroundChanged()
  host.onSharedReaderForegroundChanged()
  assert.deepEqual(epochs, [10])
  host.sharedReaderPreparation = null // A ready session survives a background/foreground pair.
  host.readerForeground.active = false
  host.onSharedReaderForegroundChanged()
  host.readerForeground.active = true
  host.onSharedReaderForegroundChanged()
  assert.deepEqual(epochs, [10])
})

test('preparation rejection closes the pending route with feedback, but stale rejection is ignored', async () => {
  const Host = subject('pages/Index.ets', 'Index', ['prepareCurrentSharedReader', 'readerPreparationCurrent'], {
    ...common, AppStrings: { get: value => value },
  })
  const host = new Host()
  const events = []
  Object.assign(host, { readerBackend: 'shared', readerOpen: true, readerClosing: false, readerOpenEpoch: 1,
    sharedReaderPreparation: new Cancellation(), readerSessionConfig: config('A'),
    prepareReaderSession: async () => { throw new Error('provider failed') },
    showToast: value => events.push(value), closeReader: () => events.push('close'),
  })
  await host.prepareCurrentSharedReader(1)
  assert.deepEqual(events, ['manga_detail_chapter_pages_load_failed', 'close'])
  events.length = 0
  await host.prepareCurrentSharedReader(0)
  assert.deepEqual(events, [])
})

function closingHost() {
  const events = []
  const paths = ['Reader']
  let restore
  const ownedWindow = { close: () => {
    events.push('restore-start')
    return new Promise(resolve => { restore = resolve })
  } }
  const Host = subject('pages/Index.ets', 'Index', ['closeReader', 'closeSharedReaderEntry',
    'sharedReaderEntryCurrent', 'closeSharedReaderRoute', 'restoreSharedReaderRoute',
    'isReaderDetailRouteVisible', 'isReaderRouteVisible', 'popReaderRouteAfterSystemBarRestore',
    'finishReaderRouteClose'], { ...common, RouteName: { READER: 'Reader', MANGA_DETAIL: 'MangaDetail' } })
  const host = new Host()
  Object.assign(host, { readerBackend: 'shared', readerOpen: true, readerClosing: false,
    readerRouteVisible: true, readerOpenEpoch: 2, readerCloseRequestId: 4, readerProgressRevision: 0,
    sharedReaderEntries: [{ epoch: 2 }], sharedReaderPreparation: null,
    sharedReaderWindow: ownedWindow, sharedReaderClosing: null,
    readerSessionStore: { flush: () => events.push('flush') },
    appPathStack: { getAllPathName: () => paths, pop: () => events.push(`pop-${paths.pop()}`) },
  })
  return { host, events, paths, ownedWindow, restore: () => restore() }
}

test('shown Reader -> detail -> return transition close waits for its route window before pop', async () => {
  const state = closingHost()
  const { host, events, paths } = state
  paths.push('MangaDetail')
  host.readerRouteVisible = false // onWillHide; Reader still owns its acquired window.
  host.closeReader()
  assert.deepEqual(events, ['pop-MangaDetail'])
  host.closeReader() // Back again before Reader onShown.
  const pending = host.sharedReaderClosing
  assert.deepEqual(events, ['pop-MangaDetail', 'restore-start'])
  assert.deepEqual(paths, ['Reader'])
  host.closeReader()
  assert.equal(host.sharedReaderClosing, pending)
  state.restore()
  await pending
  assert.deepEqual(events, ['pop-MangaDetail', 'restore-start', 'flush', 'pop-Reader'])
})

test('retiring an embedded chapter keeps the route window; pending next chapter close restores it', async () => {
  const state = closingHost()
  const { host, events, ownedWindow } = state
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage', ['aboutToDisappear'])
  const page = new Page()
  Object.assign(page, { embedded: true, request: { readingChrome: true }, trialWindow: ownedWindow,
    initialization: null, pendingSession: null, volumeKeys: { close() {} }, cancelChapterRequest() {},
    adapter: null, keepScreenOn: null, clearStatusBarHideTimer() {} })
  page.aboutToDisappear()
  assert.deepEqual(events, [], 'chapter body must not return a window still owned by its route')
  host.sharedReaderEntries = []
  host.sharedReaderPreparation = new Cancellation()
  const preparing = host.sharedReaderPreparation
  host.readerSessionLoading = true
  host.readerRouteVisible = false
  host.closeReader()
  const pending = host.sharedReaderClosing
  assert.equal(preparing.isCancelled(), true)
  assert.deepEqual(events, ['restore-start'])
  state.restore()
  await pending
  assert.deepEqual(events, ['restore-start', 'flush', 'pop-Reader'])
})

test('stale child callback and old window close/disappear cannot change a newer route', async () => {
  const state = closingHost()
  const { host, events, ownedWindow } = state
  host.closeSharedReaderEntry(1)
  assert.deepEqual(events, [])
  host.closeSharedReaderEntry(2)
  const pending = host.sharedReaderClosing
  const nextClosing = Promise.resolve()
  host.sharedReaderWindow = { close: () => assert.fail('new window closed by old callback') }
  host.sharedReaderClosing = nextClosing
  host.readerOpenEpoch = 4
  host.readerClosing = false
  host.sharedReaderEntries = [{ epoch: 4 }]
  state.restore()
  await pending
  host.finishReaderRouteClose(ownedWindow)
  assert.deepEqual(events, ['restore-start'])
  assert.equal(host.readerOpen, true)
  assert.equal(host.readerClosing, false)
  assert.equal(host.sharedReaderClosing, nextClosing)
  assert.equal(host.sharedReaderEntries[0].epoch, 4)
})

test('initial preferences canceled in background cannot mount over the resumed initialization', async () => {
  const loads = []
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['syncInitializationActivity', 'initializeSession'], {
      ReaderCancellation: Cancellation,
      ReaderPreferencesStore: class { load() { return new Promise(resolve => loads.push(resolve)) } },
      KomaReaderInitialPolicy: { resolve: preferences => preferences },
    })
  const page = new Page()
  const session = { setPolicy(value) { this.policy = value } }
  Object.assign(page, { embedded: true, readerClosed: false, request: { readingChrome: true, progressReadWrite: false },
    routeActive: true, labVisibility: { foreground: true }, session: null,
    pendingSession: session, initialization: null, unitKey: { work: 'book', unit: 'A' },
    getUIContext: () => ({ getHostContext: () => ({}) }), readInitialColumn: () => 'odd_left',
    acquireReadingWindow() {},
    syncKeepScreenOn() {}, syncVolumeKeys() {}, closeReader: () => assert.fail('canceled load must not close reader') })
  page.syncInitializationActivity()
  page.labVisibility.foreground = false
  page.syncInitializationActivity()
  page.labVisibility.foreground = true
  page.syncInitializationActivity()
  assert.equal(loads.length, 2)
  loads[0]({ preset: 'old' })
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(page.session, null)
  loads[1]({ preset: 'current' })
  await new Promise(resolve => setImmediate(resolve))
  assert.equal(page.session, session)
  assert.equal(session.policy.preset, 'current')
})

test('embedded enter does not acquire a window before destination activation; standalone Lab still does', () => {
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['aboutToAppear', 'onHostCloseRequested', 'syncInitializationActivity', 'acquireReadingWindow',
      'syncHostRouteActivity', 'onChapterActivityChanged'], {
      KomaReaderLabAdapter: class { initialKey() { return { work: 'book', unit: 'A' } } },
      ReaderMediaActions: class {}, KomaReaderLabImageShareHost: class {}, ReaderSystemImageSaveHost: class {},
      ReaderPagedSession: class {}, ReaderKeepScreenOn: class {},
    })
  function page(embedded) {
    const value = new Page()
    const events = []
    Object.assign(value, { embedded, request: { readingChrome: true, work: 'book', unit: 'A', pageIndex: 0 },
      closeRequestId: 4, initialCloseRequestId: 4, hostRouteActive: false, routeActive: false,
      labVisibility: { foreground: true }, initialization: null, readerClosed: false,
      readingWindowAcquired: false, trialWindow: { open: () => events.push('window-open') },
      getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug: true } }) }),
      initializeSession() { events.push('initialize'); this.initialization = {} },
      closeReader: () => assert.fail('no new close request'),
      cancelChapterRequest: () => events.push('cancel-chapter'),
    })
    value.hostWindow = value.trialWindow
    return { value, events }
  }
  const embedded = page(true)
  embedded.value.aboutToAppear()
  assert.deepEqual(embedded.events, [], 'Index may cancel an unshown destination without a window to restore')
  embedded.value.hostRouteActive = true
  embedded.value.syncHostRouteActivity()
  embedded.value.onChapterActivityChanged()
  embedded.value.onChapterActivityChanged()
  assert.deepEqual(embedded.events, ['window-open', 'initialize'])
  embedded.value.hostRouteActive = false
  embedded.value.initialization = new Cancellation()
  const pending = embedded.value.initialization
  embedded.value.syncHostRouteActivity()
  embedded.value.onChapterActivityChanged()
  assert.equal(pending.isCancelled(), true, 'same activity callback also cancels pending initialization')
  assert.deepEqual(embedded.events, ['window-open', 'initialize', 'cancel-chapter'])
  const standalone = page(false)
  standalone.value.aboutToAppear()
  assert.deepEqual(standalone.events, ['window-open', 'initialize'])
})

test('a close arriving after entry publication but before component mount is handled before window acquisition', () => {
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['aboutToAppear', 'onHostCloseRequested'], {
      KomaReaderLabAdapter: class { constructor() { assert.fail('closed entry must not initialize') } },
    })
  const page = new Page()
  const events = []
  Object.assign(page, { embedded: true, initialCloseRequestId: 7, closeRequestId: 8,
    pageMounted: false, observedCloseRequestId: 0, hostRouteActive: true,
    request: { readingChrome: true }, initialization: null, readerClosed: false,
    getUIContext: () => ({ getHostContext: () => ({ applicationInfo: { debug: true } }) }),
    closeReader() { this.readerClosed = true; events.push('close') },
  })
  page.onHostCloseRequested()
  assert.deepEqual(events, [], 'pre-mount monitor must not consume the close')
  page.aboutToAppear()
  assert.deepEqual(events, ['close'])
  assert.equal(page.observedCloseRequestId, 8)
})
