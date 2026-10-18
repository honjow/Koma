const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const root = path.resolve(__dirname, '..')
const strings = new Map(JSON.parse(fs.readFileSync(path.join(root, 'entry/src/main/resources/zh_CN/element/string.json'))).string.map(s => [s.name, s.value]))
const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/LibraryUpdatePresentation.ets'), 'utf8')
const compiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText
const moduleInstance = { exports: {} }
new Function('require', 'exports', compiled)(name => {
  assert.equal(name, '../i18n/AppStrings')
  return { AppStrings: { get: key => { assert.ok(strings.has(key), key); return strings.get(key) } } }
}, moduleInstance.exports)
const { libraryUpdateComicTitle: title, libraryUpdateProviderTitle: providerTitle } = moduleInstance.exports
const comics = [{ id: 'comic-internal-a', title: '  海贼王  ', sourceRuntimeId: 'source-a' }, { id: 'comic-internal-b', title: '另一部漫画', sourceRuntimeId: 'source-b' }]
const labels = [{ id: 'source-a', name: 'Komiic' }, { id: 'source-b', name: 'DM5' }]
const provider = { providerKind: 'source_runtime', sourceKey: 'source:opaque-a' }
const results = [{ comicId: comics[0].id, providerKind: 'source_runtime', sourceKey: provider.sourceKey }, { comicId: comics[1].id, providerKind: 'source_runtime', sourceKey: 'source:opaque-b' }]
assert.equal(title(comics[0]), '海贼王')
assert.equal(title(undefined), strings.get('library_update_results_unavailable_comic'))
assert.equal(title({ id: 'do-not-show-id', title: ' ' }), strings.get('library_update_results_unavailable_comic'))
assert.equal(providerTitle(provider, results, comics, labels), 'Komiic')
assert.equal(providerTitle({ ...provider, sourceKey: 'source:opaque-b' }, results, comics, labels), 'DM5')
assert.equal(providerTitle(provider, results, [], labels), strings.get('library_source_package'))
assert.equal(providerTitle(provider, results, comics, []), strings.get('library_source_package'))
assert.equal(providerTitle(provider, [{ ...results[0], providerKind: 'local' }], comics, labels), strings.get('library_source_package'))
for (const [kind, key] of [['local', 'library_source_local'], ['private_library', 'library_source_private'], ['komga', 'route_komga_title'], ['kavita', 'route_kavita_title'], ['opds', 'route_opds_title'], ['webdav', 'route_webdav_title'], ['unsupported', 'library_update_results_unsupported_source']]) {
  assert.equal(providerTitle({ providerKind: kind, sourceKey: 'server:opaque' }, results, comics, labels), strings.get(key))
}
assert.equal(results[0].comicId, 'comic-internal-a', 'Display labels do not mutate navigation identities')
console.log('PASS library update presentation: manga titles, source identity joins, missing-data fallback and all provider labels')

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
