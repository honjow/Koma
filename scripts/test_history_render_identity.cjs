const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const ts = require(process.env.KOMA_TYPESCRIPT ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const file = path.join(__dirname, '../entry/src/main/ets/pages/HistoryPage.ets')

function methods(names) {
  const source = fs.readFileSync(file, 'utf8').replace(/\bstruct /g, 'class ')
  const tree = ts.createSourceFile('HistoryPage.ets', source, ts.ScriptTarget.Latest, true)
  const cls = tree.statements.find(value => ts.isClassDeclaration(value) && value.name?.getText(tree) === 'HistoryPage')
  assert.ok(cls)
  return names.map(name => {
    const member = cls.members.find(value => value.name?.getText(tree) === name)
    assert.ok(member, name)
    return member.getText(tree)
  })
}

test('history render identity changes with chapter, page and time group state', () => {
  const output = {}
  vm.runInNewContext(ts.transpileModule(`export class Subject {
    ${methods(['historyItemRenderIdentity', 'historySectionRenderIdentity']).join('\n')}
  }`, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText,
  { exports: output })
  const subject = new output.Subject()
  const first = { id: 'source-history:work', title: 'Work', lastReadAt: 1,
    progress: { chapterId: 'A', pageIndex: 0, totalPages: 39 },
    sourceHistory: { chapterId: 'A', chapterTitle: 'Chapter 1' } }
  const second = { ...first, lastReadAt: 2,
    progress: { chapterId: 'B', pageIndex: 1, totalPages: 19 },
    sourceHistory: { chapterId: 'B', chapterTitle: 'Chapter 2' } }
  assert.notEqual(subject.historyItemRenderIdentity(first), subject.historyItemRenderIdentity(second))
  assert.notEqual(subject.historySectionRenderIdentity({ key: 'last_7_days', items: [first] }),
    subject.historySectionRenderIdentity({ key: 'last_7_days', items: [second] }))
  assert.notEqual(subject.historySectionRenderIdentity({ key: 'last_7_days', items: [second] }),
    subject.historySectionRenderIdentity({ key: 'today', items: [second] }))
})

test('History ForEach uses content identities instead of comic-only keys', () => {
  const source = fs.readFileSync(file, 'utf8')
  assert.match(source, /\(item: HistoryItem\) => this\.historyItemRenderIdentity\(item\)/)
  assert.match(source, /\(section: HistorySection\) => this\.historySectionRenderIdentity\(section\)/)
  assert.doesNotMatch(source, /\(item: HistoryItem\) => item\.comicId\)/)
})
