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

// Use the pinned kit's real capability bundle, so the callback is exercised through
// the same public dispatcher as ReaderSurface instead of calling the host method directly.
const kitDirectory = path.join(__dirname, '../../reader-kit/reader-ui/src/main/ets')
const kitSource = ['ReaderHostAction.ets', 'ReaderHostActions.ets']
  .map(file => fs.readFileSync(path.join(kitDirectory, file), 'utf8').replace(/^import .*$/gm, ''))
  .join('\n')
const kit = {}
vm.runInNewContext(ts.transpileModule(kitSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText, { exports: kit })

function fixture() {
  const Page = subject('readerLab/KomaReaderLabPage.ets', 'KomaReaderLabPage',
    ['hostActionDispatch', 'openMangaDetail'], {
      AppStrings: { get: value => value }, ...kit,
    })
  const page = new Page(), current = key('A'), opened = []
  const snapshot = { phase: 'ready', unit: { key: current }, navigationRevision: 5,
    anchor: { sourceIndexHint: 2 } }
  Object.assign(page, {
    session: { snapshot: () => snapshot },
    onOpenMangaDetail: work => opened.push(work),
  })
  return { page, current, opened, snapshot }
}

test('the current shared-reader dispatcher opens detail only for the observed position', () => {
  const { page, current, opened } = fixture()
  assert.deepEqual(Array.from(page.hostActionDispatch.items(), action => [action.id, action.label]),
    [['manga-detail', 'reader_action_return_to_detail']])
  page.hostActionDispatch.request('manga-detail', current, 5, 2)
  assert.deepEqual(opened, ['work'])
})

test('stale or unrelated menu requests cannot navigate to detail', () => {
  const { page, current, opened } = fixture()
  page.hostActionDispatch.request('other-action', current, 5, 2)
  page.hostActionDispatch.request('manga-detail', key('B'), 5, 2)
  page.hostActionDispatch.request('manga-detail', current, 4, 2)
  page.hostActionDispatch.request('manga-detail', current, 5, 1)
  assert.deepEqual(opened, [])
})

test('loading, retired and missing sessions cannot navigate to detail', () => {
  const { page, current, opened, snapshot } = fixture()
  snapshot.phase = 'loading'
  page.hostActionDispatch.request('manga-detail', current, 5, 2)
  snapshot.phase = 'ready'
  snapshot.unit = null
  page.hostActionDispatch.request('manga-detail', current, 5, 2)
  page.session = null
  page.hostActionDispatch.request('manga-detail', current, 5, 2)
  assert.deepEqual(opened, [])
})
