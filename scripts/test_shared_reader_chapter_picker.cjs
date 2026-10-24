const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets/readerLab')

function subject(file, owner, names, globals = {}) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.getText(tree) === owner)
  assert.ok(cls, owner)
  const members = names.map(name => {
    const member = cls.members.find(value => value.name?.getText(tree) === name)
    assert.ok(member, `${owner}.${name}`)
    return member.getText(tree).replace(/^\s*@Monitor\([^\n]+\)\s*/m, '')
  })
  const output = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: output, console: { info() {}, warn() {} }, setTimeout, ...globals })
  return output.Subject
}

function key(unit) {
  return {
    scope: 'koma-local', work: 'work', unit,
    copy() { return key(this.unit) },
    equals(other) { return other?.scope === this.scope && other?.work === this.work && other?.unit === this.unit },
  }
}

class Choice {
  constructor(value, title) { this.key = value; this.title = title }
}

test('manual picker keeps the complete host catalog and aligned titles', () => {
  class ReaderUnitKey {
    constructor(scope, work, unit) { Object.assign(this, { scope, work, unit }) }
  }
  const Adapter = subject('KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter', ['unitId', 'chapterChoices'], {
    KomaReaderLabChapterChoice: Choice, ReaderUnitKey,
  })
  const adapter = new Adapter()
  adapter.configs = new Map()
  const current = new ReaderUnitKey('koma-local', 'work', 'B')
  adapter.configs.set(JSON.stringify(['koma-local', 'work', 'B']), {
    chapterIds: ['A', 'B', 'C'], chapterTitles: ['Alpha', 'Beta', 'Gamma'], continuationChapterIds: ['B', 'C'],
  })
  assert.deepEqual(adapter.chapterChoices(current).map(value => [value.key.unit, value.title]),
    [['A', 'Alpha'], ['B', 'Beta'], ['C', 'Gamma']])
})

test('picker opens only for an exact current unit/navigation and dismisses before switching', () => {
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['syncChapterChoices', 'chapterControlLabel', 'openChapterPicker', 'selectChapterFromPicker',
      'finishChapterPickerDismissal'],
    { AppStrings: { get: () => 'Chapter' } })
  const page = new Page()
  const current = key('A')
  const choices = [new Choice(current, 'Alpha'), new Choice(key('B'), 'Beta')]
  const opened = []
  Object.assign(page, {
    adapter: { chapterChoices: () => choices }, chapterChoices: [], chapterChoiceIdentity: '',
    session: { snapshot: () => ({ phase: 'ready', navigationRevision: 4, unit: { key: current } }) },
    openChapterTarget: (...args) => opened.push(args.map(value => value?.unit ?? value)),
    syncKeepScreenOn() {}, syncVolumeKeys() {},
  })
  page.openChapterPicker(current, 3)
  assert.equal(page.chapterPickerShown, undefined)
  page.openChapterPicker(current, 4)
  assert.equal(page.chapterPickerShown, true)
  assert.equal(page.chapterControlLabel(), 'Chapter 1 / 2')
  page.selectChapterFromPicker(choices[1])
  assert.equal(page.chapterPickerShown, false)
  page.finishChapterPickerDismissal()
  assert.deepEqual(opened, [['B', 'A', 'picker']])
})

test('a newer picker target cancels preparation and is the only chapter opened', async () => {
  class ReaderCancellation {
    constructor() { this.cancelled = false }
    cancel() { this.cancelled = true }
    isCancelled() { return this.cancelled }
    check() { if (this.cancelled) throw new Error('cancelled') }
  }
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage', ['openChapterTarget'], {
    ReaderCancellation, $r: value => value, DiagnosticLogger: { info() {}, warn() {} },
  })
  const page = new Page()
  const source = key('A')
  let current = source
  let releaseB
  const pendingB = new Promise(resolve => { releaseB = resolve })
  const opened = []
  const adapter = { prepare: target => target.unit === 'B' ? pendingB : Promise.resolve() }
  const session = {
    snapshot: () => ({ phase: 'ready', unit: { key: current } }),
    open: async target => { opened.push(target.unit); current = target },
  }
  Object.assign(page, {
    session, adapter, routeActive: true, labVisibility: { foreground: true }, readerClosed: false,
    chapterRequest: null, chapterBusy: false, request: { chapterProbe: '' },
    runChapterPreparationProbe: async () => {}, syncChapterChoices() {},
    getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) }),
  })
  const first = page.openChapterTarget(key('B'), source, 'picker')
  await new Promise(setImmediate)
  const second = page.openChapterTarget(key('C'), source, 'picker')
  await second
  releaseB()
  await first
  assert.deepEqual(opened, ['C'])
  assert.equal(page.chapterBusy, false)
})

function chapterSequence() {
  const exports = {}
  const source = fs.readFileSync(path.join(root, '../model/ReaderChapterSequence.ets'), 'utf8')
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports })
  return exports
}

test('first-read ignores catalog display direction and unknown negative ordinals, preserving a real chapter zero', () => {
  const { firstReaderChapter } = chapterSequence()
  const catalog = [
    { id: 'newest', title: 'Latest', chapterNumber: 46 },
    { id: 'unknown', title: 'Extra', chapterNumber: -1 },
    { id: 'first', title: 'First', chapterNumber: 1 },
  ]
  assert.equal(firstReaderChapter(catalog).id, 'first')
  assert.equal(firstReaderChapter([...catalog].reverse()).id, 'first')
  assert.equal(catalog[0].id, 'newest')
  assert.equal(firstReaderChapter([...catalog, { id: 'zero', title: 'Prologue', chapterNumber: 0 }]).id, 'zero')
})

test('first-read uses oldest real upload date without inventing numbers from titles', () => {
  const { firstReaderChapter } = chapterSequence()
  const catalog = [
    { id: 'new', title: 'Chapter 1', dateUpload: 200 },
    { id: 'unknown-date', title: 'Chapter 0', dateUpload: 0 },
    { id: 'old', title: 'Chapter 99', dateUpload: 100 },
  ]
  assert.equal(firstReaderChapter(catalog).id, 'old')
  assert.equal(firstReaderChapter([]), undefined)
  assert.equal(firstReaderChapter([{ id: 'stable', title: 'No metadata' },
    { id: 'other', title: 'Chapter 1' }]).id, 'stable')
})


test('backward chapter continuation uses prepared final page while next and picker start at zero', async () => {
  class ReaderCancellation {
    cancel() { this.cancelled = true }
    isCancelled() { return this.cancelled === true }
  }
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage', ['openChapterTarget'], {
    ReaderCancellation, $r: value => value, DiagnosticLogger: { info() {}, warn() {} },
  })
  for (const [reason, count, expected] of [['previous', 19, 18], ['previous', 1, 0], ['next', 19, 0], ['picker', 19, 0]]) {
    const page = new Page(), source = key('A'), opened = []
    let current = source
    Object.assign(page, {
      session: {
        snapshot: () => ({ phase: 'ready', unit: { key: current } }),
        open: async (target, index) => { opened.push([target.unit, index]); current = target },
      },
      adapter: { prepare: async target => ({ key: target, pageCount: count }) },
      routeActive: true, labVisibility: { foreground: true }, readerClosed: false,
      chapterRequest: null, chapterBusy: false,
      runChapterPreparationProbe: async () => {}, syncChapterChoices() {},
      getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) }),
    })
    await page.openChapterTarget(key('B'), source, reason)
    assert.deepEqual(opened, [['B', expected]], reason)
    assert.equal(page.chapterBusy, false)
  }
})

function pickerPositionFixture() {
  const frames = [], scrolls = [], adjustments = []
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['hasChapterPickerPosition', 'chapterPickerInitialIndex', 'restoreChapterPickerPosition', 'rememberChapterPickerPosition'], {
      KomaReaderAfterLayout: class { constructor(observe) { this.observe = observe } },
      LengthMetrics: { vp: value => value }, ScrollAlign: { START: 'start' },
    })
  const page = new Page()
  Object.assign(page, { chapterPickerShown: true, chapterPickerOpening: true, readerClosed: false,
    currentChapterUnit: '73', chapterChoiceIdentity: 'catalog', chapterPickerSavedUnit: '', chapterPickerSavedCatalog: '',
    chapterPickerFirstIndex: 0, chapterPickerFirstY: 0, chapterPickerLayoutRevision: 0,
    chapterChoices: Array.from({ length: 76 }, (_, index) => ({ key: { unit: String(index) } })),
    getUIContext: () => ({ postFrameCallback: frame => frames.push(frame) }),
    chapterPickerScroller: { scrollToIndex: (...args) => scrolls.push(args), getItemRect: () => ({ y: 8, height: 48 }),
      scrollBy: (...args) => adjustments.push(args) },
  })
  return { page, frames, scrolls, adjustments, frame() { assert.ok(frames.length); frames.shift().observe() } }
}
test('first picker layout aligns the actual current chapter without animation and cannot save an interim viewport', () => {
  const f = pickerPositionFixture()
  f.page.restoreChapterPickerPosition(); f.frame(); f.frame()
  assert.deepEqual(f.scrolls[0].slice(0, 3), [73, false, 'start'])
  assert.equal(f.scrolls[0][3].extraOffset, -0)
  assert.equal(f.adjustments.length, 0)
  assert.equal(f.page.chapterPickerPositionReady, false, 'opening layout must not overwrite the retained user position')
  f.page.rememberChapterPickerPosition(62)
  assert.equal(f.page.chapterPickerSavedUnit, '')
  f.page.chapterPickerOpening = false
  f.page.restoreChapterPickerPosition(); f.frame(); f.frame()
  assert.equal(f.page.chapterPickerPositionReady, true)
  assert.equal(f.scrolls.at(-1)[0], 73)
})
test('saved manual row and measured Y take priority over the current chapter on reopen', () => {
  const f = pickerPositionFixture()
  Object.assign(f.page, { chapterPickerSavedUnit: '73', chapterPickerSavedCatalog: 'catalog',
    chapterPickerFirstIndex: 40, chapterPickerFirstY: -7, chapterPickerOpening: false })
  f.page.restoreChapterPickerPosition(); f.frame(); f.frame()
  assert.deepEqual(f.scrolls[0].slice(0, 3), [40, false, 'start'])
  assert.equal(f.scrolls[0][3].extraOffset, 7)
  assert.deepEqual(f.adjustments, [[0, 15]])
  assert.equal(f.page.chapterPickerPositionReady, true)
})
test('a newer opening layout retires its earlier callback and closed/replaced catalogs cannot scroll', () => {
  const f = pickerPositionFixture()
  f.page.restoreChapterPickerPosition(); f.page.restoreChapterPickerPosition()
  f.frame(); assert.equal(f.scrolls.length, 0)
  f.frame(); assert.equal(f.scrolls.length, 1)
  f.page.chapterChoiceIdentity = 'replacement'; f.frame()
  assert.equal(f.page.chapterPickerPositionReady, false)
  f.page.restoreChapterPickerPosition(); f.page.chapterPickerShown = false; f.frame()
  assert.equal(f.scrolls.length, 1)
})


const sharedCore = require('../../reader-kit/tests/load-core.cjs')('ReaderSession')
function preparationFixture(hostPrepare, fetchSource = async source => '/cache/' + source.imageUri) {
  const Adapter = subject('KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter',
    ['unitId', 'open', 'prepare', 'prepareShared', 'prepareUnit', 'installConfig', 'preloadNextUnit',
      'page', 'preload', 'recoverableImageFailure', 'refreshPageSources', 'sourceFile', 'load', 'close'], {
      ...sharedCore, DiagnosticLogger: { info() {} }, KomaReaderFailure: { catalogMessage: error => error.message },
      ReaderPageRenderKind: { REMOTE_URL_IMAGE: 1, URI_PLACEHOLDER: 2 },
      createReaderPageRenderSources: config => config.pageUris.map((imageUri, index) => ({ kind: 1, imageUri, sourceRuntimeId: config.sourceRuntimeId, pageId: config.pageIds?.[index] })),
      fetchAndCacheReaderRemoteSource: fetchSource,
      KomaReaderFileInformation: class {}, ReaderFileCropSource: class {},
    })
  const adapter = new Adapter()
  Object.assign(adapter, { configs: new Map(), sources: new Map(), preparedUnits: new Map(),
    preparingUnits: new Map(), sourceRequests: new Map(), refreshingSources: new Map(), automaticallyRefreshedUnits: new Set(), automaticPageRetries: new Set(), closed: false, chapterPreloadEnabled: true,
    preparationCancellation: new sharedCore.ReaderCancellation(), catalogFailureText: 'visible failure',
    catalogHost: { prepare: hostPrepare }, thumbnails: { close() {} },
  })
  return adapter
}
function unitKey(unit) { return new sharedCore.ReaderUnitKey('koma-local', 'work', unit) }
function chapterConfig(unit = 'B') {
  return { comicId: 'work', chapterId: unit, totalPages: 3, pageUris: [unit + '0', unit + '1', unit + '2'],
    chapterIds: ['A', 'B', 'C'], continuationChapterIds: ['A', 'B', 'C'] }
}
const later = () => new Promise(setImmediate)
test('concurrent chapter consumers share host preparation; cancelling one does not reject the other', async () => {
  let finish, count = 0
  const adapter = preparationFixture(() => { count++; return new Promise(resolve => { finish = resolve }) })
  const cancelled = new sharedCore.ReaderCancellation(), current = new sharedCore.ReaderCancellation()
  const first = adapter.prepare(unitKey('B'), cancelled), second = adapter.prepare(unitKey('B'), current)
  const firstFailure = assert.rejects(first, /cancel/)
  assert.equal(count, 1)
  cancelled.cancel(); finish(chapterConfig())
  await firstFailure
  const ready = await second
  assert.equal(ready.pageCount, 3)
  assert.equal((await adapter.prepare(unitKey('B'), current)).pageCount, 3)
  assert.equal(count, 1)
  assert.equal(adapter.preparingUnits.size, 0)
  adapter.close()
})
test('failed preparation is not cached and a real foreground retry can resolve it', async () => {
  let count = 0
  const adapter = preparationFixture(async () => { if (++count === 1) throw Error('unavailable'); return chapterConfig() })
  await assert.rejects(adapter.prepare(unitKey('B'), new sharedCore.ReaderCancellation()), /unavailable/)
  assert.equal(adapter.preparedUnits.size, 0)
  assert.equal((await adapter.prepare(unitKey('B'), new sharedCore.ReaderCancellation())).pageCount, 3)
  assert.equal(count, 2)
  adapter.close()
})
test('next-unit prefetch requires a verified sequence, warms only its configured prefix and never commits progress', async () => {
  let preparations = 0
  const fetched = []
  const adapter = preparationFixture(async () => { preparations++; return chapterConfig() },
    async source => { fetched.push(source.imageUri); return '/cache/' + source.imageUri })
  const unit = new sharedCore.ReaderUnit(unitKey('A'), 'current', 8)
  const id = adapter.unitId(unit.key)
  adapter.configs.set(id, { ...chapterConfig('A'), continuationChapterIds: undefined })
  await adapter.preloadNextUnit(unit, 2, new sharedCore.ReaderCancellation())
  assert.equal(preparations, 0, 'the full manual picker catalog is not automatic adjacency')
  adapter.configs.set(id, chapterConfig('A'))
  await adapter.preloadNextUnit(unit, 2, new sharedCore.ReaderCancellation())
  assert.equal(preparations, 1)
  assert.deepEqual(fetched, ['B0', 'B1'])
  assert.equal(adapter.catalogFailureText, 'visible failure', 'speculation must not replace a foreground diagnostic')
  assert.equal(unit.key.unit, 'A')
  adapter.chapterPreloadEnabled = false
  await adapter.preloadNextUnit(new sharedCore.ReaderUnit(unitKey('B'), 'next', 3), 2,
    new sharedCore.ReaderCancellation())
  assert.equal(preparations, 1, 'read-only/debug consumers do not gain network speculation')
  adapter.close()
})
test('foreground body joins a warming image before descriptor resolution; retired prefetch stops further images', async () => {
  let finishImage, preparations = 0, images = 0
  const adapter = preparationFixture(async () => { preparations++; return chapterConfig() },
    () => { images++; return new Promise(resolve => { finishImage = resolve }) })
  const current = new sharedCore.ReaderUnit(unitKey('A'), 'current', 8)
  adapter.configs.set(adapter.unitId(current.key), chapterConfig('A'))
  const warming = new sharedCore.ReaderCancellation()
  const prefetch = adapter.preloadNextUnit(current, 2, warming)
  const retired = assert.rejects(prefetch, /cancel/)
  await later(); assert.equal(images, 1)
  const foreground = new sharedCore.ReaderCancellation()
  const ready = await adapter.prepare(unitKey('B'), foreground)
  const page = await adapter.page(ready, 0, foreground)
  const body = adapter.load(page, 'original', foreground, false)
  assert.equal(images, 1)
  warming.cancel(); finishImage('/cache/B0')
  assert.equal((await body).uri, 'file:///cache/B0')
  await retired
  assert.equal(preparations, 1)
  assert.equal(images, 1)
  assert.equal(adapter.sourceRequests.size, 0)
  adapter.close()
})
test('closing retires a pending catalog before it can install late pages', async () => {
  let finish
  const adapter = preparationFixture(() => new Promise(resolve => { finish = resolve }))
  const pending = adapter.prepare(unitKey('B'), new sharedCore.ReaderCancellation())
  const rejected = assert.rejects(pending, /closed|cancel/)
  adapter.close(); finish(chapterConfig()); await rejected
  assert.equal(adapter.configs.size, 0)
  assert.equal(adapter.preparedUnits.size, 0)
})

function retryConfig(uris = ['old0', 'old1', 'old2'], ids = ['p0', 'p1', 'p2']) {
  return { ...chapterConfig(), sourceRuntimeId: 'source', pageIds: ids, pageUris: uris }
}
test('explicit image retry refreshes the chapter descriptors and bypasses the byte cache', async () => {
  const hostCalls = [], fetched = []
  const adapter = preparationFixture(async (_key, _cancel, force) => {
    hostCalls.push(force); return retryConfig(['new0', 'new1', 'new2'])
  }, async (source, _context, force) => { fetched.push([source.imageUri, force]); return '/cache/' + source.imageUri })
  const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
  const unit = adapter.installConfig(key, retryConfig(), cancel), page = await adapter.page(unit, 0, cancel)
  await adapter.load(page, 'original', cancel, false)
  assert.equal(hostCalls.length, 0, 'ordinary opening remains cache-first')
  const result = await adapter.load(page, 'original', cancel, true)
  assert.equal(hostCalls.length, 1)
  assert.equal(hostCalls[0], true)
  assert.equal(result.uri, 'file:///cache/new0')
  assert.deepEqual(fetched.at(-1), ['new0', true])
  assert.equal(adapter.configs.get(adapter.unitId(key)).pageUris[0], 'old0', 'retry must not replace the live catalog or jump position')
  adapter.close()
})
test('concurrent page retries share refresh, match stable IDs and allow retry after a refresh failure', async () => {
  let resolve, calls = 0
  const adapter = preparationFixture(async () => {
    calls++
    if (calls === 1) throw Error('temporary provider failure')
    return new Promise(done => { resolve = done })
  })
  const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
  const unit = adapter.installConfig(key, retryConfig(), cancel)
  const first = await adapter.page(unit, 0, cancel), second = await adapter.page(unit, 1, cancel)
  await assert.rejects(adapter.load(first, 'original', cancel, true), /temporary provider failure/)
  assert.equal(adapter.sources.get(adapter.unitId(key))[0].imageUri, 'old0')
  const a = adapter.load(first, 'original', cancel, true), b = adapter.load(second, 'original', cancel, true)
  await later(); assert.equal(calls, 2)
  resolve(retryConfig(['new1', 'new0', 'new2'], ['p1', 'p0', 'p2']))
  assert.equal((await a).uri, 'file:///cache/new0')
  assert.equal((await b).uri, 'file:///cache/new1')
  adapter.close()
})
test('local/offline image retry never refreshes a source catalog', async () => {
  const adapter = preparationFixture(async () => { throw Error('must not request provider') })
  const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
  const unit = adapter.installConfig(key, chapterConfig(), cancel), page = await adapter.page(unit, 0, cancel)
  adapter.sources.set(adapter.unitId(key), [{ kind: 0, imageUri: '/offline/page.jpg', pageId: 'p0' }])
  assert.equal((await adapter.load(page, 'original', cancel, true)).uri, 'file:///cache//offline/page.jpg')
  adapter.close()
})

test('a recoverable source image failure automatically refreshes and retries once', async () => {
  let refreshes = 0
  const fetched = []
  const adapter = preparationFixture(async () => { refreshes++; return retryConfig(['new0', 'new1', 'new2']) },
    async (source, _context, force) => {
      fetched.push([source.imageUri, force])
      if (source.imageUri === 'old0') throw Error('reader_remote_image_fetch_failed_2300999')
      return '/cache/' + source.imageUri
    })
  const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
  const unit = adapter.installConfig(key, retryConfig(), cancel), page = await adapter.page(unit, 0, cancel)
  assert.equal((await adapter.load(page, 'original', cancel, false)).uri, 'file:///cache/new0')
  assert.equal(refreshes, 1)
  assert.deepEqual(fetched, [['old0', false], ['new0', true]])
  adapter.close()
})
test('persistent failure has a finite automatic budget and explicit retry remains available', async () => {
  let refreshes = 0, requests = 0
  const adapter = preparationFixture(async () => { refreshes++; return retryConfig() }, async () => {
    requests++; throw Error('reader_remote_image_fetch_failed_2300999')
  })
  const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
  const unit = adapter.installConfig(key, retryConfig(), cancel), page = await adapter.page(unit, 0, cancel)
  await assert.rejects(adapter.load(page, 'original', cancel, false), /2300999/)
  assert.equal(requests, 2); assert.equal(refreshes, 1)
  await assert.rejects(adapter.load(page, 'original', cancel, false), /2300999/)
  assert.equal(requests, 3); assert.equal(refreshes, 1, 'ordinary rerender cannot create a retry loop')
  await assert.rejects(adapter.load(page, 'original', cancel, true), /2300999/)
  assert.equal(requests, 4); assert.equal(refreshes, 2, 'manual retry has its own explicit refresh')
  adapter.close()
})
test('known web challenges, authorization failures, cancellation and missing files are not auto-retried', async () => {
  for (const reason of ['reader_remote_image_http_403', 'reader_remote_image_http_401', 'source_challenge_required', 'cancelled', 'missing_file']) {
    let requests = 0
    const adapter = preparationFixture(async () => { throw Error('must not refresh') }, async () => { requests++; throw Error(reason) })
    const cancel = new sharedCore.ReaderCancellation(), key = unitKey('B')
    const unit = adapter.installConfig(key, retryConfig(), cancel), page = await adapter.page(unit, 0, cancel)
    await assert.rejects(adapter.load(page, 'original', cancel, false), e => e.message === reason)
    assert.equal(requests, 1)
    adapter.close()
  }
})
