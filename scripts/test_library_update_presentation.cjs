const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '..')
const strings = new Map(JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/zh_CN/element/string.json'))).string.map(s => [s.name, s.value]))
function loadModel(name, dependencies = {}) {
  const source = fs.readFileSync(path.join(root, `entry/src/main/ets/model/${name}.ets`), 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  const moduleInstance = { exports: {} }
  new Function('require', 'exports', compiled)(dependency => {
    assert.ok(Object.hasOwn(dependencies, dependency), dependency)
    return dependencies[dependency]
  }, moduleInstance.exports)
  return moduleInstance.exports
}
const comicModels = loadModel('ComicModels')
const installedSources = new Map([['source-a', '瓜子漫画'], ['source-b', '包子漫画']])
const { libraryUpdateComicTitle: title, libraryUpdateFailureText: failureText, libraryUpdateRowSubtitle: subtitle } =
  loadModel('LibraryUpdatePresentation', {
    '../i18n/AppStrings': { AppStrings: { get: key => { assert.ok(strings.has(key), key); return strings.get(key) } } },
    '../sourceRuntime/SourceRuntimeAppRegistry': { sourceDisplayName: (id, fallback) => installedSources.get(id) ?? fallback },
    './ComicModels': comicModels,
  })
const comics = [{ id: 'comic-internal-a', title: '  海贼王  ', sourceRuntimeId: 'source-a' }, { id: 'comic-internal-b', title: '另一部漫画', sourceRuntimeId: 'source-b' }]
assert.equal(title(comics[0]), '海贼王')
assert.equal(title(undefined), strings.get('library_update_results_unavailable_comic'))
assert.equal(title({ id: 'do-not-show-id', title: ' ' }), strings.get('library_update_results_unavailable_comic'))
assert.equal(failureText('network_error'), '网络请求失败')
assert.equal(failureText('timeout'), '请求超时')
assert.equal(failureText('auth_error'), '登录失效或访问被拒绝')
assert.equal(failureText('unknown'), '未能确定失败原因')
const sameName = { ...comics[1], title: comics[0].title }
assert.equal(subtitle(comics[0], '第 10 话'), '瓜子漫画 · 第 10 话')
assert.equal(subtitle(comics[0], failureText('timeout')), '瓜子漫画 · 请求超时')
assert.equal(subtitle(sameName, failureText('timeout')), '包子漫画 · 请求超时')
const removedSourceComic = { ...sameName, sourceRuntimeId: 'removed-source', sourceMetadata: { sourceName: ' 旧书源 ' } }
assert.equal(subtitle(removedSourceComic, failureText('auth_error')), '旧书源 · 登录失效或访问被拒绝')
assert.equal(subtitle({ ...removedSourceComic, sourceMetadata: { sourceName: 'removed-source' } }, '第 10 话'),
  '书源 · 第 10 话')
assert.equal(subtitle({ sourceKind: comicModels.ComicSourceKind.OPDS_REMOTE }, '第 10 话'),
  strings.get('route_opds_title') + ' · 第 10 话')
assert.equal(subtitle(undefined, failureText('unknown')), '未能确定失败原因')
console.log('PASS library update presentation: same-title works, source names and localized failure reasons')

const detailSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/MangaDetailPage.ets'), 'utf8')
const detailStart = detailSource.indexOf('function mangaDetailFromComic(')
const detailEnd = detailSource.indexOf('\nfunction chapterPagesAreLocalOffline', detailStart)
assert.ok(detailStart > 0 && detailEnd > detailStart)
const detailFunction = ts.transpileModule(detailSource.slice(detailStart, detailEnd), {
  compilerOptions: { target: ts.ScriptTarget.ES2020 },
}).outputText
const detail = new Function('MangaStatus', 's', detailFunction + '\nreturn mangaDetailFromComic')(
  { UNKNOWN: 'unknown' }, key => strings.get(key))
const registry = { list: () => [{ sourceId: 'source-a', manifestName: ' Komiic ', enabled: false }] }
assert.equal(detail(comics[0], registry).sourceName, 'Komiic', 'Disabled installed source retains its readable name')
assert.equal(detail(comics[1], registry).sourceName, strings.get('library_source_package'))
assert.equal(detail({ ...comics[0], sourceRuntimeId: undefined }, registry).sourceName, '')
assert.equal(detail(comics[0], registry).sourceId, 'source-a', 'Source routing identity is unchanged')
console.log('PASS manga detail source label: installed/disabled, missing source and local fallback')
