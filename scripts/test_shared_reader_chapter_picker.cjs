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

test('adapter keeps the full manual catalog while adjacent navigation uses only the continuation sequence', () => {
  class ReaderUnitKey {
    constructor(scope, work, unit) { Object.assign(this, { scope, work, unit }) }
  }
  const Adapter = subject('KomaReaderLabAdapter.ets', 'KomaReaderLabAdapter', ['unitId', 'adjacent', 'chapterChoices'], {
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
  assert.equal(adapter.adjacent({ key: current }, 'previous'), null)
  assert.equal(adapter.adjacent({ key: current }, 'next').unit, 'C')
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

test('a newer picker target cancels preparation and restores only the opened chapter position', async () => {
  class ReaderCancellation {
    constructor() { this.cancelled = false }
    cancel() { this.cancelled = true }
    isCancelled() { return this.cancelled }
    check() { if (this.cancelled) throw new Error('cancelled') }
  }
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['chapterInitialPage', 'openChapterTarget', 'syncChapterChoices', 'onObservedPosition'], {
    ReaderCancellation, $r: value => value,
  })
  const page = new Page()
  const source = key('A')
  let current = source
  let releaseB
  const pendingB = new Promise(resolve => { releaseB = resolve })
  const opened = []
  const committed = []
  const restored = []
  const adapter = {
    prepare: target => target.unit === 'B' ? pendingB : Promise.resolve(),
    sessionConfig: target => ({ comicId: target.work, chapterId: target.unit,
      chapterIds: [target.unit], totalPages: 1, pageUris: [`uri:${target.unit}`] }),
    chapterChoices: () => [],
  }
  const session = {
    snapshot: () => ({ phase: 'ready', unit: { key: current }, policy: { firstPageAlone: false } }),
    open: async (target, index) => { opened.push([target.unit, index]); current = target },
  }
  Object.assign(page, {
    session, adapter, routeActive: true, labVisibility: { foreground: true }, readerClosed: false,
    chapterRequest: null, chapterBusy: false, request: { chapterProbe: '', progressReadWrite: true },
    readInitialPage: (work, unit) => { restored.push([work, unit]); return unit === 'C' ? 7 : 3 },
    runChapterPreparationProbe: async () => {}, chapterChoices: [], chapterChoiceIdentity: '',
    catalogHost: { commit: target => committed.push(target.unit) },
    persistObserved() {},
    getUIContext: () => ({ getPromptAction: () => ({ showToast() {} }) }),
  })
  const first = page.openChapterTarget(key('B'), source, 'picker')
  await new Promise(setImmediate)
  const second = page.openChapterTarget(key('C'), source, 'picker')
  await second
  releaseB()
  await first
  assert.deepEqual(opened, [['C', 7]])
  assert.deepEqual(committed, [])
  page.onObservedPosition({ anchor: { unit: current, sourceIndexHint: 0 }, pageCount: 1 })
  assert.deepEqual(committed, ['C'])
  assert.deepEqual(restored, [['work', 'C']])
  assert.equal(page.chapterBusy, false)
})

test('chapter switch starts at zero when host progress is disabled', () => {
  const Page = subject('KomaReaderLabPage.ets', 'KomaReaderLabPage', ['chapterInitialPage'])
  const page = new Page()
  Object.assign(page, {
    request: { progressReadWrite: false },
    readInitialPage: () => { throw new Error('must not read disabled progress') },
  })
  assert.equal(page.chapterInitialPage(key('B')), 0)
})

test('shared page keeps chapter data and sheet ownership outside reader-kit', () => {
  const page = fs.readFileSync(path.join(root, 'KomaReaderLabPage.ets'), 'utf8')
  const adapter = fs.readFileSync(path.join(root, 'KomaReaderLabAdapter.ets'), 'utf8')
  assert.match(page, /hostCenterActionLabel: this\.chapterControlLabel\(\)/)
  assert.match(page, /chapterNavigation: new ReaderChapterNavigation\(this\.chapterBusy/)
  assert.doesNotMatch(page, /chapterNavigationAvailable:/)
  assert.doesNotMatch(page, /chapterNavigationBusy:/)
  assert.doesNotMatch(page, /onChapter:/)
  assert.match(page, /ReaderHostChapterPickerSheet/)
  assert.match(page, /!this\.chapterPickerShown/)
  assert.match(adapter, /chapterChoices\(unit: ReaderUnitKey\)/)
  assert.doesNotMatch(page, /@reader-kit\/.*ChapterPicker/)
})
