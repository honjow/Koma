const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = resolve(__dirname, '..')

// Execute the production methods, not a duplicate of either route/title algorithm.
function method(page, name) {
  const source = readFileSync(resolve(root, `entry/src/main/ets/pages/${page}.ets`), 'utf8')
  const file = ts.createSourceFile(`${page}.ts`, source.replace(/\bstruct (\w+)/g, 'class $1'),
    ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
  const owner = file.statements.find((node) => ts.isClassDeclaration(node) && node.name?.text === page)
  const member = owner?.members.find((node) => node.name?.text === name)
  assert.ok(member, `Missing production ${page}.${name}`)
  return member.getText(file)
}

const code = ts.transpileModule(`
  export class Downloads {
    libraryStore; blocked = []; toasts = [];
    blockUnavailableEntry(entry) { this.blocked.push(entry) }
    showToast(text) { this.toasts.push(text) }
    ${method('DownloadsPage', 'openDownloadEntry')}
  }
  export class Index {
    libraryStore;
    ${method('Index', 'mangaDetailTitle')}
  }
`, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
const strings = new Map(JSON.parse(readFileSync(resolve(root,
  'entry/src/main/resources/zh_CN/element/string.json'), 'utf8')).string.map((item) => [item.name, item.value]))
const s = (key) => { assert.ok(strings.has(key), `Missing localized key ${key}`); return strings.get(key) }
const routes = []
const compiled = { exports: {} }
new Function('module', 'exports', 'RouterHelper', 'AppStrings', 's', code)(
  compiled, compiled.exports, { pushMangaDetail: (param) => routes.push(param) }, { get: s }, s)
const index = new compiled.exports.Index()
const downloads = new compiled.exports.Downloads()
const comics = [
  { id: 'library-a', title: ' Source A title ', sourceRuntimeId: 'source-a', remoteResourceId: 'remote-1' },
  { id: 'library-b', title: 'Source B title', sourceRuntimeId: 'source-b', remoteResourceId: 'remote-1' },
  // A local primary key deliberately collides with both sources' remote ID.
  { id: 'remote-1', title: 'Unrelated local title' },
  { id: 'local-result', title: 'Local result title' },
  { id: 'blank-title', title: '   ' },
]
const libraryStore = { getComic: (id) => comics.find((comic) => comic.id === id), listComics: () => comics }
index.libraryStore = libraryStore
downloads.libraryStore = libraryStore

for (const [comicId, sourceId, title] of [
  ['library-a', 'source-a', 'Source A title'],
  ['library-b', 'source-b', 'Source B title'],
]) {
  downloads.openDownloadEntry({ comicId })
  const route = routes.at(-1)
  const comic = comics.find((item) => item.id === comicId)
  assert.deepEqual(route, { mangaId: 'remote-1', sourceId, initialManga: {
    id: 'remote-1', sourceId, title: comic.title, coverUrl: comic.coverUri, url: comic.sourcePath,
  } }, 'Download navigation must retain accepted source identity and initial work URL context')
  assert.equal(index.mangaDetailTitle(route), title,
    'Resolve the source identity, not a coincident local primary key or another source')
}
assert.equal(index.mangaDetailTitle({ mangaId: ' remote-1 ', sourceId: ' source-a ' }), 'Source A title')
assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1', sourceId: 'missing-source' }),
  '', 'Missing source must not fall back to a colliding local ID')

downloads.openDownloadEntry({ comicId: 'local-result' })
assert.deepEqual(routes.at(-1), { mangaId: 'local-result' })
assert.equal(index.mangaDetailTitle(routes.at(-1)), 'Local result title')
assert.equal(index.mangaDetailTitle({ mangaId: 'library-a' }), 'Source A title',
  'Update-result/library-ID navigation remains supported')
assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1' }), 'Unrelated local title',
  'Without a source identity the route remains a local primary-key lookup')
assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1', sourceId: 'source-a',
  initialManga: { title: ' Preview title ' } }), 'Preview title')
assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1', sourceId: 'source-a',
  initialManga: { title: '  ' } }), 'Source A title')
for (const route of [{ mangaId: 'missing' }, { mangaId: 'blank-title' },
  { mangaId: 'missing', sourceId: 'source-a' }]) {
  assert.equal(index.mangaDetailTitle(route), '')
}

assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1', sourceId: 'source-a',
  initialManga: { title: 'Search preview' }, chrome: { resolvedTitle: 'Loaded actual title' } }),
  'Loaded actual title', 'A detail response publishes only its route-local loaded title')
assert.equal(index.mangaDetailTitle({ mangaId: 'missing', chrome: { resolvedTitle: '  ' } }), '',
  'Unknown titles keep the bar empty instead of showing an untitled placeholder')

const count = routes.length
downloads.openDownloadEntry({ comicId: 'missing' })
assert.equal(routes.length, count, 'Unavailable downloads must not navigate')
assert.deepEqual(downloads.blocked, [{ comicId: 'missing' }])
assert.deepEqual(downloads.toasts, [s('downloads_toast_entry_unavailable')])
assert.equal(index.mangaDetailTitle({ mangaId: 'remote-1', sourceId: 'source-a' }), 'Source A title',
  'Resolving another route must not retain its title')
console.log('PASS manga detail title: production download routes and title resolution; source/local ID collisions, preview and missing states')
