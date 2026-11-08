const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require((process.env.DEVECO_HOME || '/Applications/DevEco-Studio.app/Contents') +
  '/tools/hvigor/hvigor/node_modules/typescript')

const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/pages/MangaDetailPage.ets'), 'utf8')
  .replace(/\bstruct (\w+)/g, 'class $1')
const tree = ts.createSourceFile('detail.ts', source, ts.ScriptTarget.Latest, true)
const owner = tree.statements.find(node => ts.isClassDeclaration(node) && node.name?.text === 'MangaDetailPage')
const method = owner.members.find(node => node.name?.text === 'loadSourceMangaDetail').getText(tree)
const code = ts.transpileModule('export class Page { ' + method + ' }', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText

async function exercise({ ids = ['a', 'b'], rows = ['a', 'b'], fingerprint = 'same',
  cached = false, force = false, hasDetail = true } = {}) {
  let calls = 0
  const out = {}
  new Function('exports', 'SourceDetailContentState', 'appSourceSettingsStore', 'sourceRuntimeEntryEnabled',
    'sourceSettingsFingerprint', 'sourceMangaDetailSnapshotCache', 's', code)(
    out, { LOADING: 'loading', READY: 'ready' }, { loadForSource: () => ({}) }, () => true,
    () => 'same', { read: () => cached ? { chaptersResolved: true } : undefined }, key => key)
  const page = new out.Page()
  Object.assign(page, {
    manga: hasDetail ? { title: 'book' } : undefined, chapters: rows.map(id => ({ id })),
    sourceDetailDataResolved: hasDetail, sourceChaptersResolved: cached,
    sourceDetailContentState: 'ready', sourceRegistry: { lookup: () => ({ ok: true, entry: {} }) },
    closeDetailWebChallenge() {}, clearDetailWebChallenge() {}, isDetailPending: () => false,
    beginSourceDetailRequest() { this.sourceChaptersResolved = false; return 1 },
    sourceMangaRouteUrl: () => '', sourceComicId: () => 'book',
    findSourceRuntimeComic: () => ({ chapters: rows.map(id => ({ id })),
      sourceMetadata: { sharedChapterIds: ids, settingsFingerprint: fingerprint } }),
    async runSourceMangaOperation() { calls++; throw Error('request observed') },
    isCurrentSourceDetailRequest: () => false,
  })
  await page.loadSourceMangaDetail('source', 'book', force)
  return { calls, resolved: page.sourceChaptersResolved }
}

test('only complete matching catalogs skip source requests on entry', async () => {
  assert.deepEqual(await exercise({}), { calls: 0, resolved: true })
  assert.deepEqual(await exercise({ cached: true, ids: undefined, rows: ['a'] }), { calls: 0, resolved: true })
  assert.equal((await exercise({ rows: ['a'] })).calls, 1)
  assert.equal((await exercise({ fingerprint: 'changed' })).calls, 1)
  assert.equal((await exercise({ ids: [] })).calls, 1)
  assert.equal((await exercise({ force: true })).calls, 1)
  assert.equal((await exercise({ hasDetail: false, ids: [], rows: [] })).calls, 1)
})
