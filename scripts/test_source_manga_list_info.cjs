const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.join(__dirname, '../entry/src/main/ets/model')
function load(file, imports = {}) {
  const exports = {}
  const js = ts.transpileModule(fs.readFileSync(path.join(root, file + '.ets'), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  new Function('exports', 'require', js)(exports, name => {
    assert.ok(imports[name], `missing dependency ${name}`)
    return imports[name]
  })
  return exports
}
const normalizer = load('SourceTextNormalizer')
const info = load('SourceMangaListInfo', { './SourceTextNormalizer': normalizer })
const models = load('SourceModels', {
  './SourceTextNormalizer': normalizer,
  './SourceMangaListInfo': info,
  './MangaWebLink': load('MangaWebLink'),
  '../i18n/AppStrings': { AppStrings: { get: key => key } },
})
function cards(items) {
  return models.parseSourceMangaListJson('source', JSON.stringify({ items, page: { nextCursor: '2', hasMore: true } }))
}

test('legacy cards expose existing summary data without changing identity or pagination', () => {
  const result = cards([{ id: 'work:1', title: '作品', subtitle: '更新至第23话', authors: ['作者'],
    status: 'ongoing', tags: ['奇幻', '冒险'] }])
  assert.equal(result.manga[0].id, 'work:1')
  assert.equal(result.nextCursor, '2')
  assert.equal(result.hasNextPage, true)
  assert.deepEqual(models.sourceMangaListInfo(result.manga[0]).map(info.sourceMangaListInfoText),
    ['更新至第23话', '作者 · manga_status_ongoing', '奇幻 · 冒险'])
})

test('source-selected information retains its order and explicit empty information suppresses fallback', () => {
  const result = cards([{ id: '1', title: '作品', authors: ['旧作者'], listInfo: [
    { type: 'tags', items: ['科幻', '科幻', '日常'] },
    { type: 'text', label: '更新', text: '第9话' },
    { type: 'text', text: '原站评分 9.2' },
  ] }, { id: '2', title: '作品2', authors: ['旧作者'], listInfo: [] }])
  assert.deepEqual(models.sourceMangaListInfo(result.manga[0]).map(info.sourceMangaListInfoText),
    ['科幻 · 日常', '更新: 第9话', '原站评分 9.2'])
  assert.deepEqual(models.sourceMangaListInfo(result.manga[1]), [])
})

test('bad optional information cannot erase cards or valid adjacent information', () => {
  const result = cards([{ id: '1', title: '作品', listInfo: [null, { type: 'future', payload: {} },
    { type: 'text', text: '有效摘要', label: {} }] },
  { id: '2', title: '作品2', subtitle: '旧摘要', listInfo: { text: 'wrong shape' } }])
  assert.equal(result.manga.length, 2)
  assert.equal(result.hasNextPage, true)
  assert.deepEqual(models.sourceMangaListInfo(result.manga[0]).map(info.sourceMangaListInfoText), ['有效摘要'])
  assert.deepEqual(models.sourceMangaListInfo(result.manga[1]).map(info.sourceMangaListInfoText), ['旧摘要'])
})

test('UTF-8 budgets, unknown rows and whitespace are handled independently', () => {
  assert.equal(info.normalizeSourceMangaListInfo([{ type: 'text', text: '😀'.repeat(129) }]), undefined)
  assert.equal(info.normalizeSourceMangaListInfo([{ type: 'text', text: '\ud800' }]), undefined)
  const rows = info.normalizeSourceMangaListInfo([
    { type: 'text', text: '😀'.repeat(128) },
    { type: 'tags', items: ['a\n b', 4, '', '\u0000', ...Array.from({ length: 9 }, (_, i) => `tag${i}`)] },
    { type: 'text', text: '   ' }, { type: 'text', text: 'over the row limit' },
  ])
  assert.equal(rows.length, 2)
  assert.equal(rows[0].text, '😀'.repeat(128))
  assert.deepEqual(rows[1].items, ['a b', 'tag0', 'tag1', 'tag2', 'tag3'])
})

test('ordinary Browse parsing keeps summaries through its independent response path', () => {
  // Execute the actual Browse response functions, which also accept nested home sections.
  const source = fs.readFileSync(path.join(root, '../viewmodel/BrowseViewModel.ets'), 'utf8')
  const ast = ts.createSourceFile('BrowseViewModel.ets', source, ts.ScriptTarget.Latest, true)
  const names = ['optionalString', 'normalizeStatus', 'normalizeStringArray', 'firstDisplayText',
    'itemRecord', 'sourceItemCoverUrl', 'parseSourceMangaFromItem', 'sourceMangaIdentityKey',
    'appendUniqueSourceManga', 'parseSourceMangaListFromResponse']
  const functions = ast.statements.filter(node => ts.isFunctionDeclaration(node) && names.includes(node.name?.text))
    .map(node => node.getText(ast)).join('\n')
  const js = ts.transpileModule(functions + '\nexport { parseSourceMangaListFromResponse };', {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const actual = {}
  new Function('exports', 'normalizeSourceDisplayText', 'normalizeSourceImageUrl',
    'normalizeSourceMangaListInfo', 'sourceStaticCoverHeaders', 'AppStrings', js)(actual,
    normalizer.normalizeSourceDisplayText, normalizer.normalizeSourceImageUrl,
    info.normalizeSourceMangaListInfo, models.sourceStaticCoverHeaders, { get: key => key })
  const result = actual.parseSourceMangaListFromResponse('source', { ok: true, data: { items: [
    { items: [{ id: 'legacy', title: '作品', subtitle: '更新至23话', tags: ['冒险'] }] },
    { id: 'modern', title: '作品2', listInfo: [{ type: 'text', text: '站点自定摘要' }] },
    { id: 'provenance', title: '作品3', sourceTags: ['komiic'] },
  ], page: { nextCursor: 'next', hasMore: true } } })
  assert.equal(result.nextCursor, 'next')
  assert.equal(result.manga.length, 3)
  assert.deepEqual(models.sourceMangaListInfo(result.manga[0]).map(info.sourceMangaListInfoText), ['更新至23话', '冒险'])
  assert.deepEqual(models.sourceMangaListInfo(result.manga[1]).map(info.sourceMangaListInfoText), ['站点自定摘要'])
  // Actual older source cards use sourceTags:['komiic'] as provenance, not a genre.
  assert.deepEqual(result.manga[2].tags, ['komiic'])
  assert.deepEqual(models.sourceMangaListInfo(result.manga[2]), [])
})
