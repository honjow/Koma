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
    adapter: { chapterChoices: () => choices, chapterCatalogPending: () => false,
      chapterReadingPosition: () => ({ index: 0, total: 2 }) }, chapterChoices: [], chapterChoiceIdentity: '',
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
  const adapter = { prepare: target => target.unit === 'B' ? pendingB : Promise.resolve(),
    chapterPrepared: () => false, chapterTitle: () => '' }
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
  return loadHostModel('ReaderChapterSequence', { './ChapterSortOrder': loadHostModel('ChapterSortOrder') })
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
      adapter: { prepare: async target => ({ key: target, pageCount: count }),
        chapterPrepared: () => false, chapterTitle: () => '' },
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

test('a prepared boundary skips the loading toast and announces only the opened chapter', async () => {
  class ReaderCancellation {
    cancel() { this.cancelled = true }
    isCancelled() { return this.cancelled === true }
  }
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage', ['openChapterTarget'], {
    ReaderCancellation, $r: value => value, DiagnosticLogger: { info() {}, warn() {} },
  })
  for (const [prepared, reason, expected] of [
    [true, 'next', ['Beta']],
    [false, 'next', ['app.string.manga_detail_loading_source', 'Beta']],
    [true, 'picker', []],
  ]) {
    const page = new Page(), source = key('A'), toasts = []
    let current = source
    Object.assign(page, {
      session: { snapshot: () => ({ phase: 'ready', unit: { key: current } }),
        open: async target => { current = target } },
      adapter: { chapterPrepared: () => prepared, chapterTitle: () => 'Beta',
        prepare: async target => ({ key: target, pageCount: 1 }) },
      routeActive: true, labVisibility: { foreground: true }, readerClosed: false,
      chapterRequest: null, chapterBusy: false,
      runChapterPreparationProbe: async () => {}, syncChapterChoices() {},
      getUIContext: () => ({ getPromptAction: () => ({ showToast: value => toasts.push(value.message) }) }),
    })
    await page.openChapterTarget(key('B'), source, reason)
    assert.deepEqual(toasts, expected)
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


const sharedCore = require('../third_party/reader-kit/tests/load-core.cjs')('ReaderSession')
const sharedProcessing = require('../third_party/reader-kit/tests/load-core.cjs')('ReaderProcessingCoordinator')
function loadHostModel(name, dependencies = {}) {
  const source = fs.readFileSync(path.join(root, '../model', `${name}.ets`), 'utf8')
  const exports = {}
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports, require: id => dependencies[id] ?? {} })
  return exports
}
const { RemoteImageFileRequest } = loadHostModel('RemoteImageCacheStore')
function preparationFixture(hostPrepare, fetchSource = async source => '/cache/' + source.imageUri,
  readSize = async () => '0,0') {
  const Adapter = subject('KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter',
    ['unitId', 'open', 'prepare', 'prepareShared', 'prepareUnit', 'prepareArchiveBookmarks', 'authenticationSource',
      'installConfig', 'prepareSequence', 'chapterCatalogPending', 'retryChapterCatalog', 'readingChapterIds',
      'chapterReadingPosition', 'adjacent', 'preloadNextUnit',
      'page', 'preload', 'prepareImageSize', 'publishPreparedSize', 'recoverableImageFailure', 'refreshPageSources', 'sourceFile', 'load', 'close'], {
      ...sharedCore, ...sharedProcessing, DiagnosticLogger: { info() {}, warn() {} }, KomaReaderFailure: { catalogMessage: error => error.message },
      SourceRuntimeError: class extends Error {}, RemoteImageFileRequest,
      ComicSourceKind: { LOCAL_FOLDER: 'local_folder', LOCAL_ARCHIVE: 'local_archive' },
      ReaderPageRenderKind: { REMOTE_URL_IMAGE: 1, URI_PLACEHOLDER: 2, LOCAL_FILE_IMAGE: 3 },
      createReaderPageRenderSources: config => config.pageUris.map((imageUri, index) => ({ kind: 1, imageUri, sourceRuntimeId: config.sourceRuntimeId, pageId: config.pageIds?.[index] })),
      fetchAndCacheReaderRemoteSource: fetchSource,
      KomaReaderFileInformation: class {}, KomaReaderCropSource: class {},
      KomaReaderPreloadedSize: class { constructor(source, width, height) { Object.assign(this, { source, width, height }) } },
      readPreloadedImageSize() {}, taskpool: { execute: (_worker, path) => readSize(path) },
    })
  const adapter = new Adapter()
  Object.assign(adapter, { configs: new Map(), sources: new Map(), preparedUnits: new Map(), archiveBookmarks: new Map(),
    preparingUnits: new Map(), preparingSequences: new Set(), resolvedSequences: new Map(), onSequenceReady() {},
    sourceRequests: new Map(), refreshingSources: new Map(), automaticallyRefreshedUnits: new Set(), automaticPageRetries: new Set(), closed: false, chapterPreloadEnabled: true,
    preloadedSizes: new Map(), preloadedSizeVersions: new Map(),
    preparationCancellation: new sharedCore.ReaderCancellation(), catalogFailureText: 'visible failure',
    remotePreloadAllowed: () => true, bannerPolicy: () => 'off', automaticPaging: () => false,
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
test('network restrictions stop online page, chapter and processing prefetch while foreground loading remains usable', async () => {
  const prepared = [], fetched = []
  const adapter = preparationFixture(async key => { prepared.push(key.unit); return chapterConfig(key.unit) },
    async source => { fetched.push(source.imageUri); return '/cache/' + source.imageUri })
  const current = await adapter.prepare(unitKey('A'), new sharedCore.ReaderCancellation())
  let allowed = false
  adapter.remotePreloadAllowed = () => allowed
  await adapter.preloadNextUnit(current, 2, new sharedCore.ReaderCancellation())
  assert.deepEqual(prepared, ['A'])
  const page = await adapter.page(current, 0, new sharedCore.ReaderCancellation())
  await adapter.preload(page, new sharedCore.ReaderCancellation())
  assert.equal(fetched.length, 0)
  const processing = new sharedProcessing.ReaderProcessingCancellation('prefetch')
  await assert.rejects(adapter.load(page, 'original', processing, false), /cancel/)
  assert.equal(processing.isCancelled(), true)
  const displayed = await adapter.load(page, 'original', new sharedCore.ReaderCancellation(), false)
  assert.equal(fetched.length, 1, 'explicit foreground read must work off Wi-Fi')
  displayed.release()
  allowed = true
  await adapter.preloadNextUnit(current, 2, new sharedCore.ReaderCancellation())
  assert.deepEqual(prepared, ['A', 'B'])
  assert.ok(fetched.includes('B0'))
  adapter.close()
})
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
test('source next-unit prefetch requires a verified sequence, warms only its configured prefix and never commits progress', async () => {
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
  const catalog = []
  await adapter.preloadNextUnit(unit, 0, new sharedCore.ReaderCancellation(),
    (next, indexes) => catalog.push([next.key.unit, Array.from(indexes)]))
  assert.deepEqual(catalog, [['B', []]])
  assert.equal(preparations, 1)
  assert.deepEqual(fetched, [])
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

test('online adjacent chapters and lookahead consume the same sequence instead of reverse catalog order', async () => {
  const opened = [], fetched = []
  const adapter = preparationFixture(async target => {
    opened.push(target.unit)
    return { ...chapterConfig(target.unit), sourceRuntimeId: 'source',
      chapterIds: ['C', 'B', 'A'], continuationChapterIds: ['A', 'B', 'C'] }
  }, async source => { fetched.push(source.imageUri); return '/cache/' + source.imageUri })
  const current = new sharedCore.ReaderUnit(unitKey('B'), 'middle', 3)
  adapter.configs.set(adapter.unitId(current.key), { ...chapterConfig('B'), sourceRuntimeId: 'source',
    chapterIds: ['C', 'B', 'A'], continuationChapterIds: ['A', 'B', 'C'] })
  assert.equal(adapter.adjacent(current, 'previous').unit, 'A')
  assert.equal(adapter.adjacent(current, 'next').unit, 'C')
  await adapter.preloadNextUnit(current, 1, new sharedCore.ReaderCancellation())
  assert.deepEqual(opened, ['C'])
  assert.deepEqual(fetched, ['C0'])
  adapter.configs.set(adapter.unitId(current.key), { ...chapterConfig('B'), sourceRuntimeId: 'source',
    continuationChapterIds: undefined })
  assert.equal(adapter.adjacent(current, 'next'), null, 'unknown chronology must not reverse the reading relation')
  adapter.close()
})

test('reader chapter counter follows reading chronology while the 341-item picker can remain reversed', () => {
  const adapter = preparationFixture(async () => { throw Error('must not fetch chapter pages') })
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['syncChapterChoices', 'chapterControlLabel'], { AppStrings: { get: () => 'Chapter' } })
  const sequence = Array.from({ length: 341 }, (_, i) => `chapter:${i}`)
  const page = new Page(), unit = unitKey(sequence[1])
  const config = { ...chapterConfig(unit.unit), sourceRuntimeId: 'source',
    chapterIds: sequence.slice().reverse(), continuationChapterIds: sequence }
  adapter.configs.set(adapter.unitId(unit), config)
  Object.assign(page, { adapter, chapterChoices: [], chapterChoiceIdentity: '' })
  adapter.chapterChoices = current => config.chapterIds.map(id => new Choice(unitKey(id), id))
  page.syncChapterChoices(unit)
  assert.equal(page.chapterControlLabel(), 'Chapter 2 / 341')
  assert.equal(page.chapterChoices[0].key.unit, sequence[340], 'manual picker retains descending display')
  assert.equal(adapter.adjacent({ key: unit }, 'previous').unit, sequence[0])
  assert.equal(adapter.adjacent({ key: unit }, 'next').unit, sequence[2])
  config.chapterIds.reverse()
  page.syncChapterChoices(unit)
  assert.equal(page.chapterControlLabel(), 'Chapter 2 / 341', 'picker reversal cannot reverse the counter')
  adapter.configs.set(adapter.unitId(unitKey(sequence[2])), config)
  page.syncChapterChoices(unitKey(sequence[2]))
  assert.equal(page.chapterControlLabel(), 'Chapter 3 / 341')
  config.sourceChapterChronologyPending = true
  page.syncChapterChoices(unit)
  assert.equal(page.chapterControlLabel(), 'Chapter', 'pending metadata has no false chapter position')
  adapter.close()
})

test('a known chapter opens while the catalog is pending, then gains picker choices and verified lookahead', async () => {
  const adapter = preparationFixture(async target => ({ ...chapterConfig(target.unit), sourceRuntimeId: 'source',
    chapterIds: [target.unit], chapterTitles: ['Current'], continuationChapterIds: undefined }))
  let finish, publications = 0
  adapter.catalogHost.sequence = () => new Promise(resolve => { finish = resolve })
  adapter.onSequenceReady = () => { publications++ }
  const unit = await adapter.prepare(unitKey('B'), new sharedCore.ReaderCancellation())
  assert.equal(unit.pageCount, 3, 'cached current pages do not wait for chapter metadata')
  assert.equal(adapter.adjacent(unit, 'next'), null)
  assert.equal(adapter.chapterReadingPosition(unit.key), undefined)
  finish({ continuation: ['A', 'B', 'C'], chapterIds: ['C', 'B', 'A', 'alternate'],
    chapterTitles: ['Gamma', 'Beta', 'Alpha', 'Alternate'] })
  await later()
  assert.equal(adapter.adjacent(unit, 'next').unit, 'C')
  assert.deepEqual(JSON.parse(JSON.stringify(adapter.chapterReadingPosition(unit.key))), { index: 1, total: 3 })
  assert.equal(adapter.configs.get(adapter.unitId(unit.key)).chapterTitles[3], 'Alternate')
  assert.equal(adapter.configs.get(adapter.unitId(unit.key)).chapterTitle, 'Beta')
  assert.equal(publications, 1)
  const laterChapter = await adapter.prepare(unitKey('C'), new sharedCore.ReaderCancellation())
  assert.equal(adapter.adjacent(laterChapter, 'previous').unit, 'B')
  adapter.close()
})

test('local folder page budget warms its existing adjacency without source edition metadata', async () => {
  const prepared = [], fetched = []
  const config = unit => ({ ...chapterConfig(unit), sourceKind: 'local_folder', continuationChapterIds: undefined })
  const adapter = preparationFixture(async key => { prepared.push(key.unit); return config(key.unit) },
    async source => { fetched.push(source.imageUri); return '/cache/' + source.imageUri })
  const unit = new sharedCore.ReaderUnit(unitKey('A'), 'current', 8)
  adapter.configs.set(adapter.unitId(unit.key), config('A'))
  await adapter.preloadNextUnit(unit, 2, new sharedCore.ReaderCancellation())
  assert.deepEqual(prepared, ['B'])
  assert.deepEqual(fetched, ['B0', 'B1'])
  assert.equal(unit.key.unit, 'A')
  assert.equal(adapter.configs.get(adapter.unitId(unit.key)).continuationChapterIds, undefined,
    'local preparation does not rewrite Legacy automatic-navigation permission')
  adapter.close()
})

test('a warmed chapter exposes cached image dimensions and rejects a stale force-reload result', async () => {
  let finish
  const adapter = preparationFixture(async () => chapterConfig(), undefined,
    async () => new Promise(resolve => { finish = resolve }))
  const current = new sharedCore.ReaderCancellation()
  const unit = await adapter.prepare(unitKey('B'), current)
  const page = await adapter.page(unit, 0, current)
  const first = adapter.preload(page, current)
  await later()
  finish('640,960'); await first
  const warmed = await adapter.page(unit, 0, current)
  assert.deepEqual([warmed.width, warmed.height], [640, 960])

  const second = adapter.preload(page, current)
  await later()
  await adapter.sourceFile(unit.key, 0, true)
  finish('100,200'); await second
  const refreshed = await adapter.page(unit, 0, current)
  assert.deepEqual([refreshed.width, refreshed.height], [0, 0])
  adapter.close()
})

test('five-page lookahead crosses five verified single-page chapters without changing the active chapter', async () => {
  const sequence = ['A','B','C','D','E','F','G'], prepared = [], fetched = [], processing = []
  const config = chapter => ({ comicId:'work',chapterId:chapter,totalPages:1,pageUris:[chapter+'0'],
    chapterIds:sequence,continuationChapterIds:sequence })
  const adapter = preparationFixture(async key => { prepared.push(key.unit); return config(key.unit) },
    async source => { fetched.push(source.imageUri); return '/cache/'+source.imageUri })
  const unit = new sharedCore.ReaderUnit(unitKey('A'),'current',1)
  adapter.configs.set(adapter.unitId(unit.key),config('A'))
  await adapter.preloadNextUnit(unit,5,new sharedCore.ReaderCancellation(),
    (future, indexes, preceding) => processing.push([future.key.unit, Array.from(indexes), preceding]))
  assert.deepEqual(prepared,['B','C','D','E','F'])
  assert.deepEqual(fetched,['B0','C0','D0','E0','F0'])
  assert.deepEqual(processing, [['B',[0],0],['C',[0],1],['D',[0],2],['E',[0],3],['F',[0],4]])
  assert.equal(unit.key.unit,'A')
  assert.equal((await adapter.prepare(unitKey('B'),new sharedCore.ReaderCancellation())).key.unit,'B')
  assert.deepEqual(prepared,['B','C','D','E','F'])
  adapter.close()
})

test('automatic next-chapter translation does not inherit the current chapter page controls', () => {
  class Config {
    constructor(enabled, projectId) { Object.assign(this, { enabled, projectId }) }
    identity() { return this.enabled && this.projectId ? 'configured' : '' }
  }
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['translationConfiguration', 'translationPreference'], {
      KomaReaderTranslationConfiguration: Config, ReaderVariantPreference: sharedCore.ReaderVariantPreference,
    })
  const page = new Page(), current = unitKey('A'), future = unitKey('B')
  Object.assign(page, { request: { preferencesReadWrite: true },
    translationSettings: { configured: () => true, revision: 3, targetLanguage: 'zh', sourceLanguage: 'ja' },
    translationState: { revision: 3 }, translationUnit: current, translationProjectId: 'project-A',
    translationProjectForUnit: unit => `project-${unit.unit}`, translationAutoEnabled: true,
    translationRequestedPages: [0], translationHiddenPages: [0], translationAutoFailedPages: [0],
    enhancementPreference: () => new sharedCore.ReaderVariantPreference('enhanced', 'model') })
  const futurePage = new sharedCore.ReaderPage(future, 'B-0', 0)
  assert.equal(page.translationPreference(futurePage, true).variant, 'translated')
  assert.equal(page.translationConfiguration(futurePage).projectId, 'project-B')
  assert.equal(page.translationPreference(futurePage, false).variant, 'enhanced')
  page.translationAutoEnabled = false
  assert.equal(page.translationPreference(futurePage, true).variant, 'enhanced')
})

test('a speculative translation failure is associated with the chapter only after it is observed', () => {
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['observeTranslationPosition', 'refreshTranslationPresentation'])
  const page = new Page(), target = unitKey('B')
  Object.assign(page, { translationUnit: unitKey('A'), translationProjectId: 'project-A',
    translationProjectForUnit: unit => `project-${unit.unit}`, translationRequestedPages: [0],
    translationHiddenPages: [0], translationAutoFailedPages: [0], translationAutoEnabled: true,
    translationBusyPage: -1, translationErrorPage: -1, translationRevision: 0,
    session: { snapshot: () => ({ processingStates: [{ sourceIndex: 0,
      preference: { variant: 'translated' }, phase: 'unavailable' }] }) },
    translationFrame: () => ({ asset: { variant: 'default' } }),
  })
  page.observeTranslationPosition({ anchor: { unit: target, sourceIndexHint: 0 } })
  assert.equal(page.translationUnit.unit, 'B')
  assert.equal(page.translationProjectId, 'project-B')
  assert.deepEqual(Array.from(page.translationAutoFailedPages), [0])
  assert.equal(page.translationBusyPage, -1)
  assert.equal(page.translationErrorPage, 0)
})

test('single-page chapter lookahead overlaps image warming instead of waiting for each download', async () => {
  const sequence=['A','B','C','D','E','F'], pending=[]
  const config=chapter=>({comicId:'work',chapterId:chapter,totalPages:1,pageUris:[chapter+'0'],
    chapterIds:sequence,continuationChapterIds:sequence})
  const adapter=preparationFixture(async key=>config(key.unit),source=>new Promise(resolve=>pending.push([source.imageUri,resolve])))
  const unit=new sharedCore.ReaderUnit(unitKey('A'),'current',1)
  adapter.configs.set(adapter.unitId(unit.key),config('A'))
  const warming=adapter.preloadNextUnit(unit,5,new sharedCore.ReaderCancellation())
  await later()
  assert.deepEqual(pending.map(item=>item[0]),['B0','C0','D0','E0','F0'])
  pending.forEach(([uri,resolve])=>resolve('/cache/'+uri))
  await warming
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


test('declared source chronology picks earliest unread without sorting tied or unknown chapter numbers',()=>{
 const {firstReaderChapter}=chapterSequence()
 const catalog=[{id:'notice',title:'中奖公告'},
  {id:'two-down',title:'第2话下 蟒雀吞龙',chapterNumber:2},
  {id:'two-up',title:'第2话 蟒雀吞龙（上）',chapterNumber:2},
  {id:'228919',title:'第1话 周家圣龙（下）',chapterNumber:1},
  {id:'228928',title:'第1话 周家圣龙（上）',chapterNumber:1}]
 const before=JSON.stringify(catalog),read=new Set()
 const choose=()=>firstReaderChapter(catalog,'newest_first',id=>read.has(id))
 assert.equal(choose().id,'228928');read.add('228928');assert.equal(choose().id,'228919')
 catalog.forEach(c=>read.add(c.id));assert.equal(choose(),undefined)
 assert.equal(firstReaderChapter([...catalog].reverse(),'oldest_first',()=>false).id,'228928')
 assert.equal(JSON.stringify(catalog),before)
 assert.equal(firstReaderChapter([{id:'latest',title:'第519回',chapterNumber:519},
  {id:'numbered',title:'第131回',chapterNumber:131},{id:'196437',title:'01'}],'newest_first').id,'196437')
})


test('ordinary first-read owners keep explicit chapter and resume before earliest-unread policy',()=>{
 const {firstReaderChapter}=chapterSequence()
 const globals={firstReaderChapter,sourceChapterOrderFor:()=> 'newest_first',
  ChapterBatchDownloadMode:{NOT_DOWNLOADED:'not_downloaded',FAILED_ONLY:'failed_only'}}
 const comic={id:'work',sourceRuntimeId:'declared',chapters:[
  {id:'down',title:'第1话下',chapterNumber:1},{id:'up',title:'第1话上',chapterNumber:1}]}
 let progress,read=new Set()
 const store={getProgress:()=>progress,getComicProgress:()=>progress,isChapterRead:(_work,id)=>read.has(id)}
 const Index=subject('../pages/Index.ets','Index',['readerChapterIdForOpen'],globals)
 const index=new Index();index.readerSessionStore=store
 assert.equal(index.readerChapterIdForOpen(comic),'up')
 assert.equal(index.readerChapterIdForOpen(comic,'down'),'down')
 progress={chapterId:'down'};assert.equal(index.readerChapterIdForOpen(comic),'down')
 progress=undefined;read.add('up');assert.equal(index.readerChapterIdForOpen(comic),'down')
 const Library=subject('../pages/LibraryPage.ets','LibraryPage',['readerChapterIdForComic'],globals)
 const library=new Library();library.readerSessionStore=store
 assert.equal(library.readerChapterIdForComic(comic),'down')
 const Detail=subject('../pages/MangaDetailPage.ets','MangaDetailPage',
  ['downloadUnreadChapterIds','batchDownloadChapterIds','firstUnreadChapterId','primaryReadChapterId'],globals)
 const detail=new Detail();Object.assign(detail,{readerSessionStore:store,manga:{sourceId:'declared'},chapters:comic.chapters,currentComicId:()=>comic.id,progressChapterId:()=>undefined})
 assert.equal(detail.primaryReadChapterId(),'down');read.clear();assert.equal(detail.primaryReadChapterId(),'up')
 assert.deepEqual([...detail.downloadUnreadChapterIds(5)],['up','down'])
 detail.chapters=[comic.chapters[0],{...comic.chapters[1],isDownloaded:true}]
 assert.deepEqual([...detail.downloadUnreadChapterIds(1)],['down'],'download the next unread chapter without duplicating local files')
})

test('first reading uses a named source sequence after the catalogue has been reordered', () => {
  const { firstReaderChapter, continuationChapterIds } = chapterSequence()
  const rows = [
    { id: 'latest', title: '第二十六章', readingGroup: 'baozi-main', readingOrder: 2, continuationEligible: true },
    { id: 'notice', title: '公告', continuationEligible: false },
    { id: 'second', title: '第二十五章', readingGroup: 'baozi-main', readingOrder: 1, continuationEligible: true },
    { id: 'first', title: '第二十四章', readingGroup: 'baozi-main', readingOrder: 0, continuationEligible: true },
  ]
  assert.equal(firstReaderChapter(rows, 'oldest_first').id, 'first')
  assert.equal(firstReaderChapter(rows, 'oldest_first', id => id === 'first').id, 'second')
  assert.equal(firstReaderChapter(rows, 'oldest_first', id => id !== 'notice'), undefined)
  rows[0].dateUpload = 1
  rows[2].dateUpload = 2
  rows[3].dateUpload = 3
  const sort = { basis: 'upload_date' }
  assert.equal(firstReaderChapter(rows, 'oldest_first', undefined, sort).id, 'latest')
  assert.deepEqual(Array.from(continuationChapterIds(rows, 'second', true, sort)), ['latest', 'second', 'first'])
  assert.deepEqual(Array.from(continuationChapterIds(rows, 'notice', true, sort)), ['notice'])
})


test('downloaded single-page lookahead prepares geometry without waiting for foreground decode', async () => {
  const seen = []
  const adapter = preparationFixture(async () => chapterConfig(), async source => source.imageUri,
    async path => { seen.push(path); return '900,1400' })
  const cancel = new sharedCore.ReaderCancellation(), unit = await adapter.prepare(unitKey('B'), cancel)
  const source = adapter.sources.get(adapter.unitId(unit.key))[0]
  source.kind = 3; source.imageUri = 'file:///downloaded/B0.png'
  await adapter.preload(await adapter.page(unit, 0, cancel), cancel)
  const page = await adapter.page(unit, 0, cancel)
  assert.deepEqual(seen, ['file:///downloaded/B0.png'])
  assert.deepEqual([page.width, page.height], [900, 1400])
  adapter.close()
})

test('verified source reading order preserves duplicate numbers and unnumbered extras through continuation', () => {
  const output = chapterSequence()
  const chapters = [
    { id: 'end', chapterNumber: 3, readingOrder: 4 },
    { id: 'one-b', chapterNumber: 1, readingOrder: 1 },
    { id: 'extra', readingOrder: 2 },
    { id: 'two', chapterNumber: 2, readingOrder: 3 },
    { id: 'one-a', chapterNumber: 1, readingOrder: 0 },
  ].map(chapter => ({ ...chapter, title: chapter.id, readingGroup: 'site-reader', continuationEligible: true }))
  const alternate = { id: 'volume', title: 'volume', volumeNumber: '1', readingGroup: 'volume', continuationEligible: true }
  assert.deepEqual(Array.from(output.continuationChapterIds([...chapters, alternate], 'extra')),
    ['one-a', 'one-b', 'extra', 'two', 'end'])
  assert.equal(output.continuationChapterIds([{ id: 'legacy', title: 'legacy', chapterNumber: 1 }], 'legacy'), undefined)
  const legacy = chapters.filter(chapter => chapter.chapterNumber !== undefined)
    .map(({ readingOrder, ...chapter }) => chapter)
  // The old expectation used array order to break equal chapter numbers.
  // That conflicts with the user's absolute chapter relation requirement:
  // reversing a displayed/merged list must never pick a different neighbour.
  assert.deepEqual(Array.from(output.continuationChapterIds(legacy, 'one-a')), ['one-a'])
  assert.deepEqual(Array.from(output.continuationChapterIds(legacy.slice().reverse(), 'one-a')), ['one-a'])
  const repeatedOrdinal = chapters.map(chapter => ({ ...chapter, readingOrder: 1 }))
  assert.deepEqual(Array.from(output.continuationChapterIds(repeatedOrdinal, 'extra')), ['extra'])
  const volumes = [
    { id: 'v2c1', volumeNumber: '2', chapterNumber: 1 },
    { id: 'v1c3', volumeNumber: '1', chapterNumber: 3 },
    { id: 'v1c2', volumeNumber: '1', chapterNumber: 2 },
    { id: 'v1c1', volumeNumber: '1', chapterNumber: 1 },
  ].map(chapter => ({ ...chapter, title: chapter.id, readingGroup: 'edition', continuationEligible: true }))
  assert.deepEqual(Array.from(output.continuationChapterIds(volumes, 'v1c2')),
    ['v1c1', 'v1c2', 'v1c3', 'v2c1'])
})

test('reader prefers the current scanlator only among source-declared variants', () => {
  const { continuationChapterIds } = chapterSequence()
  const row = (id, order, variant, scanlator) => ({ id, title: id, readingOrder: order,
    readingGroup: 'edition', readingVariantGroup: variant, scanlator, continuationEligible: true })
  const current = row('start', 1, 'one', 'Blue')
  const chapters = [row('red', 2, 'two', 'Red'), current, row('blue', 2, 'two', 'Blue'), row('final', 3, 'three', 'Red')]
  assert.deepEqual(Array.from(continuationChapterIds(chapters, 'start', true)), ['start', 'blue', 'final'])
  assert.deepEqual(Array.from(continuationChapterIds(chapters, 'red', true)), ['start', 'red', 'final'])
  assert.deepEqual(Array.from(continuationChapterIds(chapters, 'start')), ['start'])
  assert.deepEqual(Array.from(continuationChapterIds(chapters.map(chapter => ({ ...chapter,
    readingVariantGroup: undefined })), 'start', true)), ['start'])
  const editions = chapters.map(chapter => ({ ...chapter, scanlator: 'Same display name',
    readingGroup: chapter.scanlator, readingVariantSequence: 'en' }))
  assert.deepEqual(Array.from(continuationChapterIds(editions, 'start', true)), ['start', 'blue', 'final'])
  assert.deepEqual(Array.from(continuationChapterIds(editions, 'start')), ['start', 'blue'])
})

test('declared source chronology supplies the same chapter relation without edition metadata', () => {
  const output = chapterSequence()
  const chronology = {}
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, '../model/SourceChapterChronology.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: chronology })
  // Source order is newest first; unnumbered extras must not disappear or be
  // sorted by their title. Display reversal works on a copy and is irrelevant.
  const chapters = ['last', 'extra', 'first'].map(id => ({ id, title: id }))
  const shown = chapters.slice().reverse()
  assert.deepEqual(shown.map(chapter => chapter.id), ['first', 'extra', 'last'])
  const persisted = chronology.sourceCatalogChronology(chapters, 'newest_first')
  assert.deepEqual(Array.from(output.continuationChapterIds(persisted, 'extra')),
    ['first', 'extra', 'last'])
  assert.deepEqual(Array.from(output.continuationChapterIds([persisted[1], persisted[2], persisted[0]], 'extra')),
    ['first', 'extra', 'last'], 'library merges do not change the saved source relation')
  assert.equal(output.firstReaderChapter([persisted[1], persisted[2], persisted[0]], 'newest_first').id, 'first')
  assert.equal(output.firstReaderChapter(persisted, 'newest_first', id => id === 'first').id, 'extra')
  assert.deepEqual(chapters.map(chapter => chapter.id), ['last', 'extra', 'first'])
  assert.deepEqual(Array.from(output.continuationChapterIds(chronology.sourceCatalogChronology(shown, 'oldest_first'), 'extra')),
    ['first', 'extra', 'last'])
  const grouped = chapters.map(chapter => ({ ...chapter, readingGroup: 'edition', continuationEligible: false }))
  assert.deepEqual(Array.from(output.continuationChapterIds(chronology.sourceCatalogChronology(grouped, 'newest_first'), 'extra')), ['extra'],
    'catalog chronology cannot override a source edition restriction')
})

test('complete source catalogs supply automatic neighbors through missing and repeated numbers', () => {
  const { continuationChapterIds, needsSourceCatalogChronology } = chapterSequence()
  const chronology = loadHostModel('SourceChapterChronology')
  const { parseSourceChapterRow } = loadHostModel('SourceChapterRow', {
    './SourceTextNormalizer': loadHostModel('SourceTextNormalizer'),
  })
  const catalog = [
    { id: 'latest', chapterNumber: 13 }, { id: 'extra' },
    { id: '12-part-two', chapterNumber: 12 }, { id: '12-part-one', chapterNumber: 12 },
    { id: 'first', chapterNumber: 11 },
  ].map(chapter => parseSourceChapterRow({ ...chapter, title: chapter.id,
    readingGroup: 'main', continuationEligible: true }, 'Untitled', 'Chapter %s'))
  const notice = { id: 'notice', title: 'notice', readingGroup: 'main', continuationEligible: false }
  const volume = { id: 'volume', title: 'volume', readingGroup: 'volumes', continuationEligible: true }
  assert.equal(needsSourceCatalogChronology(catalog[1]), true)
  assert.equal(needsSourceCatalogChronology(notice), false)
  assert.equal(needsSourceCatalogChronology(notice, true), true)
  const resolved = chronology.sourceCatalogChronology([volume, notice, ...catalog], undefined)
  assert.deepEqual(Array.from(continuationChapterIds(resolved, 'extra')),
    ['first', '12-part-one', '12-part-two', 'extra', 'latest'])
  assert.deepEqual(Array.from(continuationChapterIds(resolved, 'notice')), ['notice'])
  assert.deepEqual(Array.from(continuationChapterIds(resolved, 'volume')), ['volume'])
  assert.equal(needsSourceCatalogChronology(resolved.find(chapter => chapter.id === 'extra')), false)

  const plainCatalog = [{ id: 'opening', title: 'Opening' }, { id: 'appendix', title: 'Appendix' }]
  assert.deepEqual(Array.from(continuationChapterIds(chronology.sourceCatalogChronology(plainCatalog, undefined), 'opening')),
    ['opening', 'appendix'])
  const explicit = catalog.map(chapter => ({ ...chapter, readingOrder: 1 }))
  assert.equal(chronology.sourceCatalogChronology(explicit, 'newest_first')[1], explicit[1])
  assert.deepEqual(Array.from(continuationChapterIds(explicit, 'extra')), ['extra'])
})


test('a complete source catalog retires missing chapter adjacency without losing saved pages or progress', () => {
  const output = {}
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root, '../model/SourceChapterMetadata.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: output })
  for (const readingGroup of ['source-catalog', 'source-edition']) {
    const missing = { id: 'missing', index: 0, readingGroup, readingOrder: 0, continuationEligible: true,
      pages: [{ uri: 'saved-original' }], isRead: true, lastReadPage: 4 }
    const present = { id: 'present', index: 1, readingGroup, readingOrder: 1, continuationEligible: true,
      scanlator: '旧分组', language: 'zh' }
    const comic = { chapters: [missing, present] }
    const confirmed = { ...present, scanlator: undefined, language: undefined }
    assert.equal(output.enrichSourceChapterMetadata(comic, [confirmed]), true)
    assert.equal(missing.continuationEligible, false)
    assert.deepEqual(missing.pages, [{ uri: 'saved-original' }])
    assert.deepEqual([missing.isRead, missing.lastReadPage, missing.readingOrder], [true, 4, 0])
    assert.equal(present.continuationEligible, true)
    assert.equal(present.scanlator, undefined)
    assert.equal(present.language, undefined)
    assert.equal(output.enrichSourceChapterMetadata(comic, [confirmed]), false)
  }
})

test('failed history catalog remains retryable without replacing its readable chapter', async () => {
  const adapter = preparationFixture(async target => ({ ...chapterConfig(target.unit), sourceRuntimeId: 'source',
    chapterIds: [target.unit], chapterTitles: ['Current'], continuationChapterIds: undefined }))
  let attempts = 0
  adapter.catalogHost.sequence = async () => {
    if (++attempts === 1) throw new Error('challenge_required')
    return { continuation: ['A', 'B', 'C'], chapterIds: ['A', 'B', 'C'], chapterTitles: ['Alpha', 'Beta', 'Gamma'] }
  }
  const unit = await adapter.prepare(unitKey('B'), new sharedCore.ReaderCancellation())
  await later()
  const config = adapter.configs.get(adapter.unitId(unit.key))
  const pages = config.pageUris
  assert.equal(adapter.chapterCatalogPending(unit.key), true)
  assert.equal(adapter.adjacent(unit, 'next'), null)
  assert.equal(adapter.preparingSequences.size, 0)
  await adapter.retryChapterCatalog(unit.key)
  assert.equal(attempts, 2)
  assert.equal(adapter.chapterCatalogPending(unit.key), false)
  assert.equal(config.pageUris, pages)
  assert.equal(adapter.adjacent(unit, 'previous').unit, 'A')
  assert.equal(adapter.adjacent(unit, 'next').unit, 'C')
  assert.equal(config.chapterIds.length, 3)
  adapter.close()
})

test('saved edition filters constrain source and shelf reading without changing the complete catalog or downloads', async () => {
  const sequence = chapterSequence()
  const rows = ['v2', 's2', 'v1', 's1'].map((id, index) => ({
    id, title: id, index, sortKey: id, pages: [{ id: id + '-p', uri: id + '.jpg' }], pageCount: 1,
    scanlator: id.startsWith('s') ? ' 连载 ' : '单行本', language: 'zh',
    readingOrder: 3 - index, readingGroup: 'source-catalog', continuationEligible: true,
  }))
  const records = new Map([['work', JSON.stringify({ groupFilter: '连载' })]])
  const preferences = loadHostModel('ChapterListPreferencesStore', {
    './ReaderChapterSequence': sequence,
    './MangaDetailModels': { ChapterSortBasis: { SOURCE_ORDER: 'source_order', CHAPTER_NUMBER: 'chapter_number',
      UPLOAD_DATE: 'upload_date', NAME: 'name' }, ChapterSortDirection: { FORWARD: 'forward', REVERSE: 'reverse' } },
    './MigratedPreferenceRecords': { chapterListRecords: { prepared: () => records,
      prepare: async () => ({ put: (id, value) => records.set(id, value) }) } },
    './BackupRestoreActivity': { BackupRestoreActivity: { runWrite: run => run() } },
    '../state/LanguageState': { connectLanguageState: () => ({ effectiveLocale: 'zh-CN' }) },
  })
  const globals = { ...sequence, ...preferences, sourceChapterOrderFor: () => 'newest_first' }
  const comicModels = loadHostModel('ComicModels')
  const { createReaderSessionConfigFromComic } = loadHostModel('ReaderSessionStore', {
    './ReaderChapterSequence': sequence, './ChapterListPreferencesStore': preferences,
    './ComicModels': comicModels, '../sourceRuntime/SourceRuntimeAppRegistry': globals,
    '../i18n/AppStrings': { AppStrings: { get: () => 'Chapter %s' } },
  })
  const comic = { id: 'work', title: 'Editions', sourceRuntimeId: 'source', chapters: rows }
  const original = JSON.stringify(comic)
  const Index = subject('../pages/Index.ets', 'Index', ['createSourceReaderSessionConfig'], globals)
  const index = new Index()
  const request = { comicId: 'work', sourceId: 'source', chapterId: 's1', chapters: rows,
    chapterIds: rows.map(row => row.id), chapterTitles: rows.map(row => row.title), chaptersResolved: true }
  const verify = (config, ids) => {
    assert.deepEqual(Array.from(config.chapterIds), ids)
    assert.deepEqual(Array.from(config.continuationChapterIds), ids)
  }
  verify(createReaderSessionConfigFromComic(comic), ['s1', 's2'])
  verify(index.createSourceReaderSessionConfig(request, []), ['s1', 's2'])
  const oldComic = { ...comic, chapters: rows.map(row => ({ ...row, scanlator: undefined })) }
  const oldConfig = createReaderSessionConfigFromComic(oldComic, 's1')
  assert.equal(oldConfig.sourceChapterChronologyPending, true)
  assert.deepEqual(Array.from(oldConfig.chapterIds), ['s1'])
  const Detail = subject('../pages/MangaDetailPage.ets', 'MangaDetailPage',
    ['readingChaptersValue', 'progressChapterValue', 'progressChapterId', 'firstUnreadChapterValue', 'firstUnreadChapterId',
      'primaryReadChapterValue'], { ...globals, Computed: () => {} })
  const detail = new Detail()
  Object.assign(detail, { chapters: rows, manga: { sourceId: 'source' }, chapterPresentation: { groupFilter: '连载' },
    currentComicId: () => 'work', currentReadingProgress: () => ({ chapterId: 'v2' }),
    readerSessionStore: { isChapterRead: () => false } })
  assert.equal(detail.primaryReadChapterValue, 's1', 'detail continue cannot reopen a hidden edition')

  const store = new preferences.ChapterListPreferencesStore({ filesDir: '/test' })
  const save = store.save('work', { ...store.load('work'), groupFilter: '单行本', readFilter: 'unread' })
  verify(createReaderSessionConfigFromComic(comic), ['v1', 'v2'])
  await save
  verify(index.createSourceReaderSessionConfig({ ...request, chapterId: 'v1' }, []), ['v1', 'v2'])
  verify(createReaderSessionConfigFromComic(comic, 's2'), ['s2'])
  const download = createReaderSessionConfigFromComic(comic, 's2', undefined, false)
  assert.equal(download.chapterId, 's2')
  assert.equal(download.pageUris[0], 's2.jpg')
  assert.equal(download.continuationChapterIds, undefined)
  const clone = sequence.cloneReaderChapterDescriptor(rows[0])
  assert.equal(clone.language, 'zh')
  assert.deepEqual(Array.from(sequence.filterChapterMetadata([clone], { languageFilter: 'en', groupFilter: '' })), [])
  await store.save('work', { ...store.load('work'), groupFilter: '', languageFilter: '' })
  verify(createReaderSessionConfigFromComic(comic), ['s1', 'v1', 's2', 'v2'])
  assert.equal(JSON.stringify(comic), original)
})
