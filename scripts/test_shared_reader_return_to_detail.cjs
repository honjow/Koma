const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets')

function subject(file, owner, names, globals = {}) {
  const source = fs.readFileSync(path.join(root, file), 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.getText(tree) === owner)
  assert.ok(cls, owner)
  const members = names.map(name => {
    const member = cls.members.find(value => value.name?.getText(tree) === name)
    assert.ok(member, `${owner}.${name}`)
    return member.getText(tree)
  })
  const output = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject { ${members.join('\n')} }`, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText, { exports: output, ...globals })
  return output.Subject
}

function key(unit) {
  return {
    scope: 'koma-local', work: 'work', unit,
    copy() { return key(this.unit) },
    equals(other) { return other?.scope === this.scope && other?.work === this.work && other?.unit === this.unit },
  }
}

test('shared reader exposes the legacy manga-detail action through a Koma-owned callback', () => {
  class ReaderHostAction {
    constructor(id, label) { Object.assign(this, { id, label }) }
  }
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['readerHostActions', 'openMangaDetail'], {
      AppStrings: { get: value => value }, ReaderHostAction,
    })
  const page = new Page()
  const current = key('A')
  const opened = []
  Object.assign(page, {
    session: { snapshot: () => ({
      phase: 'ready', unit: { key: current }, navigationRevision: 5, anchor: { sourceIndexHint: 2 },
    }) },
    onOpenMangaDetail: work => opened.push(work),
  })

  assert.equal(JSON.stringify(page.readerHostActions().map(action => [action.id, action.label])),
    JSON.stringify([['manga-detail', 'reader_action_return_to_detail']]))
  page.openMangaDetail('manga-detail', current, 4, 2)
  page.openMangaDetail('manga-detail', current, 5, 1)
  assert.deepEqual(opened, [])
  page.openMangaDetail('manga-detail', current, 5, 2)
  assert.deepEqual(opened, ['work'])
})

test('Koma owns detail routing while reader-kit remains host-neutral', () => {
  const page = fs.readFileSync(path.join(root, 'readerLab/KomaReaderLabPage.ets'), 'utf8')
  const index = fs.readFileSync(path.join(root, 'pages/Index.ets'), 'utf8')
  assert.match(page, /hostActions: new ReaderHostActions\(this\.readerHostActions\(\)/)
  assert.match(page, /this\.openMangaDetail\(id, source, navigation, sourceIndex\)/)
  assert.match(index, /onOpenMangaDetail: \(work: string\): void => \{\s*this\.openLibraryMangaDetail\(work\)/)
  assert.doesNotMatch(page, /RouterHelper|MangaDetailRouteParam|RouteName\.MANGA_DETAIL/)
})
