const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const src = fs.readFileSync('entry/src/main/ets/model/MangaMigrationMatching.ets', 'utf8')
const code = ts.transpileModule(src, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const result = {}; new Function('exports', code)(result)
const { migrationSearchQueries: queries, chooseMigrationCandidate: choose, latestMigrationChapter: latest } = result
const item = title => ({ id: title, sourceId: 's', title })
test('reference query cleanup and deduplication preserve short foreign names', () => {
  assert.deepEqual(queries('Dragon Ball (Color Edition)', true), ['dragon ball', 'dragon'])
  assert.deepEqual(queries('葬送', true), ['葬送'])
  assert.deepEqual(queries('葬送のフリーレン', true), ['葬送のフリーレン'])
  assert.deepEqual(queries('这是一个中文漫画标题', true), ['这是一个中文漫画标题'])
  assert.deepEqual(queries('!!!', true), ['!!!'])
  assert.deepEqual(queries('   ', true), [])
  assert.deepEqual(queries('Dragon Ball', false), ['Dragon Ball'])
})
test('multiple results choose highest eligible similarity; single-query singleton follows reference', () => {
  assert.equal(choose('Dragon Ball', [item('Dragon B'), item('Dragon Ball'), item('Unrelated')], false).title, 'Dragon Ball')
  assert.equal(choose('Dragon Ball', [item('unrelated')], false).title, 'unrelated')
  assert.equal(choose('Dragon Ball', [item('x'), item('y')], false), undefined)
  assert.equal(choose('Dragon Ball', [item('x')], true), undefined)
  assert.equal(choose('葬送のフリーレン', [item('葬送のフリーレン'), item('別の漫画')], true).title, '葬送のフリーレン')
  assert.equal(choose('这是一个中文漫画标题', [item('其他作品'), item('这是一个中文漫画标题')], true).title, '这是一个中文漫画标题')
})
test('latest chapter considers finite numbers only and does not invent a value', () => {
  assert.equal(latest([{chapterNumber: 2.5}, {}, {chapterNumber: 12}, {chapterNumber: NaN}]), 12)
  assert.equal(latest([{}, {chapterNumber: Infinity}]), undefined)
})

test('page matching consumes similarity, source priority and the latest-chapter option', async () => {
  const page = fs.readFileSync('entry/src/main/ets/pages/MangaMigrationPage.ets', 'utf8').replace('export struct MangaMigrationPage', 'export class MangaMigrationPage')
  const ast = ts.createSourceFile('migration.ts', page, ts.ScriptTarget.Latest, true)
  const owner = ast.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'MangaMigrationPage')
  const method = owner.members.find(n => n.name?.getText(ast) === 'match').getText(ast)
  const js = ts.transpileModule('exports.Subject = class { ' + method + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText
  const requested = [], prepared = [], exports = {}
  new Function('exports', 'chooseMigrationCandidate', 'migrationSearchQueries', 'latestMigrationChapter', 'prepareMangaMigration', js)(
    exports, choose, queries, latest, async (_registry, manga) => {
      prepared.push(manga.id)
      return { chapters: [{ chapterNumber: manga.sourceId === 'a' ? 5 : 20 }] }
    })
  const subject = Object.assign(new exports.Subject(), { active: true, stage: 'matches', matchingRun: 1,
    generations: new Map(), prepared: new Map(), deepSearch: false, prioritizeChapters: false,
    selected: () => [{ sourceId: 'a' }, { sourceId: 'b' }],
    updateRow(_id, update) { Object.assign(this.row, update) }, failureText: e => e.message,
    searcher: { searchSource: async source => {
      requested.push(source.sourceId)
      return { manga: ['Something unrelated', 'Dragon Ball'].map(title => ({ id: source.sourceId + title, sourceId: source.sourceId, title })) }
    } } })
  subject.row = { comic: { id: 'old', title: 'Dragon Ball', sourceRuntimeId: 'old', remoteResourceId: 'old' } }
  await subject.match(subject.row, 1)
  assert.deepEqual(requested, ['a']); assert.deepEqual(prepared, ['aDragon Ball'])
  assert.equal(subject.row.target.sourceId, 'a')
  requested.length = 0; prepared.length = 0; subject.prioritizeChapters = true
  await subject.match(subject.row, 1)
  assert.deepEqual(requested, ['a', 'b']); assert.equal(subject.row.target.sourceId, 'b')
  requested.length = 0; subject.stage = 'search'
  await subject.match(subject.row, 1)
  assert.deepEqual(requested, ['a', 'b']); assert.equal(subject.row.state, 'ready')
})

test('retry-failed title action preserves ready, skipped and completed matches', async () => {
  const page = fs.readFileSync('entry/src/main/ets/pages/MangaMigrationPage.ets', 'utf8').replace('export struct MangaMigrationPage', 'export class MangaMigrationPage')
  const ast = ts.createSourceFile('migration.ts', page, ts.ScriptTarget.Latest, true)
  const owner = ast.statements.find(n => ts.isClassDeclaration(n) && n.name?.text === 'MangaMigrationPage')
  const methods = owner.members.filter(n => ['handleTitleCommand', 'runMatches'].includes(n.name?.getText(ast)))
    .map(n => n.getText(ast).replace(/@Monitor\([^\n]*\)\s*/, '')).join('\n')
  const js = ts.transpileModule('exports.Subject = class { ' + methods + ' }', {
    compilerOptions: { target: ts.ScriptTarget.ES2020 } }).outputText
  const exports = {}; new Function('exports', js)(exports)
  const processed = [], retained = { id: 'chosen' }
  const subject = Object.assign(new exports.Subject(), { active: true, stage: 'matches', matchingRun: 0,
    committing: false, handledCommandSeq: 0, chrome: { commandSeq: 1, command: 'retryFailed', busy: false },
    rows: ['ready', 'failed', 'skipped', 'done'].map(state => ({ comic: { id: state }, state, target: retained })),
    match: async row => { processed.push(row.comic.id) } })
  subject.handleTitleCommand(); await new Promise(setImmediate)
  assert.deepEqual(processed, ['failed'])
  assert.equal(subject.rows[0].state, 'ready'); assert.equal(subject.rows[0].target, retained)
})
