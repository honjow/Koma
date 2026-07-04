import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/remote/KavitaModels.ets')
const clientPath = resolve(root, 'entry/src/main/ets/remote/KavitaClient.ets')
const storePath = resolve(root, 'entry/src/main/ets/model/RemoteServerStore.ets')
const comicModelsPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const readerSourceAdapterPath = resolve(root, 'entry/src/main/ets/model/ReaderPageSourceAdapter.ets')
const libraryUpdateServicePath = resolve(root, 'entry/src/main/ets/model/LibraryUpdateService.ets')
const browsePath = resolve(root, 'entry/src/main/ets/pages/BrowsePage.ets')
const kavitaBrowsePath = resolve(root, 'entry/src/main/ets/pages/KavitaBrowsePage.ets')
const settingsPath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const clientSource = readFileSync(clientPath, 'utf8')
const storeSource = readFileSync(storePath, 'utf8')
const comicModelsSource = readFileSync(comicModelsPath, 'utf8')
const readerSourceAdapterSource = readFileSync(readerSourceAdapterPath, 'utf8')
const libraryUpdateServiceSource = readFileSync(libraryUpdateServicePath, 'utf8')
const browseSource = readFileSync(browsePath, 'utf8')
const kavitaBrowseSource = readFileSync(kavitaBrowsePath, 'utf8')
const settingsSource = readFileSync(settingsPath, 'utf8')
const indexSource = readFileSync(indexPath, 'utf8')

function normalizeKavitaBaseUrl(baseUrl) {
  return baseUrl.trim().replace(/\/+$/, '')
}

function buildKavitaUrl(baseUrl, path) {
  const normalized = normalizeKavitaBaseUrl(baseUrl)
  return path.startsWith('/') ? `${normalized}${path}` : `${normalized}/${path}`
}

assert.match(modelSource, /export interface KavitaServerConfig[\s\S]*baseUrl: string[\s\S]*credentialRef: KavitaCredentialRef/, 'Kavita server config must carry a base URL and credential ref')
assert.match(modelSource, /export interface KavitaResolvedCredential[\s\S]*apiKey: string/, 'Kavita credentials must model the Auth Key only')
assert.match(clientSource, /static libraries\(\): string \{\s*return '\/api\/Library\/libraries'\s*\}/, 'Kavita client must use the documented libraries endpoint for connection tests')
assert.match(clientSource, /static librarySeries\(pageNumber: number = 1, pageSize: number = 50\): string \{[\s\S]*\/api\/Series\/all-v2\?PageNumber=\$\{pageNumber\}&PageSize=\$\{pageSize\}/, 'Kavita client must use the documented all-v2 series endpoint')
assert.match(clientSource, /static seriesVolumes\(seriesId: number\): string \{[\s\S]*\/api\/Series\/volumes\?seriesId=\$\{seriesId\}/, 'Kavita client must use the documented volumes endpoint')
assert.match(clientSource, /static chapterInfo\(chapterId: number[\s\S]*\/api\/Reader\/chapter-info\?chapterId=\$\{chapterId\}&extractPdf=\$\{extractPdf\}&includeDimensions=\$\{includeDimensions\}/, 'Kavita client must use the documented reader chapter-info endpoint')
assert.match(clientSource, /static readerImage\(chapterId: number, page: number[\s\S]*\/api\/Reader\/image\?chapterId=\$\{chapterId\}&page=\$\{page\}&extractPdf=\$\{extractPdf\}/, 'Kavita client must use the documented reader image endpoint')
assert.match(clientSource, /static readerProgress\(chapterId: number\): string \{[\s\S]*\/api\/Reader\/get-progress\?chapterId=\$\{chapterId\}/, 'Kavita client must use the documented reader progress endpoint')
assert.match(clientSource, /static saveReaderProgress\(\): string \{[\s\S]*return '\/api\/Reader\/progress'/, 'Kavita client must use the documented reader progress save endpoint')
assert.match(clientSource, /headers\.xApiKey[\s\S]*"x-api-key"/, 'Kavita client must send Auth Key as x-api-key header')
assert.match(clientSource, /http\.request\(\{[\s\S]*method,[\s\S]*url: this\.buildUrl\(path\)[\s\S]*headers: this\.buildHeaders\(headers\)[\s\S]*body,/, 'Kavita client must delegate requests through the injected adapter')
assert.match(clientSource, /listSeries\(libraryId: number[\s\S]*field: 19[\s\S]*value: `\$\{libraryId\}`[\s\S]*sortField: 1[\s\S]*this\.request\('POST', KavitaPaths\.librarySeries/, 'Kavita series listing must filter by library id and sort by name')
assert.match(clientSource, /listVolumes\(seriesId: number\)[\s\S]*this\.request\('GET', KavitaPaths\.seriesVolumes\(seriesId\)/, 'Kavita volume listing must fetch volumes by series id')
assert.match(clientSource, /getChapterInfo\(chapterId: number\)[\s\S]*this\.request\('GET', KavitaPaths\.chapterInfo\(chapterId\)/, 'Kavita client must fetch reader chapter metadata before opening Reader')
assert.match(clientSource, /getReadProgress\(chapterId: number\)[\s\S]*this\.request\('GET', KavitaPaths\.readerProgress\(chapterId\)/, 'Kavita client must fetch chapter read progress before applying remote progress')
assert.match(clientSource, /saveReadProgress\(progress: KavitaProgressDto\)[\s\S]*this\.request\('POST', KavitaPaths\.saveReaderProgress\(\)[\s\S]*JSON\.stringify\(progress\)/, 'Kavita client must post official ProgressDto payloads to save reader progress')
assert.match(clientSource, /buildReaderImageUrl\(chapterId: number, page: number\)[\s\S]*this\.buildUrl\(KavitaPaths\.readerImage\(chapterId, page\)\)/, 'Kavita client must generate reader image URLs without leaking the Auth Key in the URL')
assert.doesNotMatch(clientSource, /\bfetch\s*\(/, 'Kavita client must not call fetch directly')

assert.equal(normalizeKavitaBaseUrl(' https://reader.example/kavita/// '), 'https://reader.example/kavita')
assert.equal(buildKavitaUrl('https://reader.example/kavita/', '/api/Library/libraries'), 'https://reader.example/kavita/api/Library/libraries')

assert.match(storeSource, /KAVITA_CREDENTIAL_KEY[\s\S]*DEFAULT_KAVITA_CREDENTIAL_REF[\s\S]*RemoteServerCredentialKind = 'komga' \| 'kavita' \| 'webdav' \| 'opds'/, 'RemoteServerStore must register Kavita as a secure credential kind')
assert.match(storeSource, /saveKavita[\s\S]*saveSecureCredential\(store, KAVITA_CREDENTIAL_KEY, 'kavita'[\s\S]*createKavitaClient/, 'RemoteServerStore must save Kavita Auth Key through AssetStore and expose a client factory')
assert.match(storeSource, /getKavitaImageHeaders\(record: KavitaServerRecord\)[\s\S]*buildHeaders\(\{ accept: 'image\/\*' \} as KavitaHeaders\)[\s\S]*xApiKey: kavitaHeaders\.xApiKey/, 'RemoteServerStore must expose Kavita image headers for Reader without plain Preferences secrets')
assert.doesNotMatch(storeSource, /store\.put\(KAVITA_CREDENTIAL_KEY,\s*JSON\.stringify/, 'Kavita Auth Key must not be written to plain Preferences')
assert.match(comicModelsSource, /KAVITA_REMOTE = 'kavita_remote'/, 'Comic model must distinguish Kavita remote comics from generic private-library rows')
assert.match(readerSourceAdapterSource, /ComicSourceKind\.KAVITA_REMOTE[\s\S]*store\.loadKavita\(\)[\s\S]*getKavitaImageHeaders\(record\)/, 'Reader remote header installer must install Kavita x-api-key headers for image loading')
assert.match(libraryUpdateServiceSource, /LibraryUpdateProviderKind = [\s\S]*'kavita'[\s\S]*if \(comic\.sourceKind === ComicSourceKind\.KAVITA_REMOTE\) \{[\s\S]*return 'kavita'/, 'Library update summaries must report Kavita as its own provider kind')
assert.match(libraryUpdateServiceSource, /checkKavitaComic\(comic: Comic, previousChapterCount: number\)[\s\S]*remoteServerStore\.loadKavita\(\)[\s\S]*client\.listVolumes\(seriesId\)[\s\S]*createKavitaChapterId\(record\.server\.id, chapterDto\.id\)/, 'Library update service must refresh Kavita chapters from the documented volumes endpoint')
assert.match(libraryUpdateServiceSource, /existing !== undefined && existing\.pages\.length > 0[\s\S]*mapKavitaChapterToChapter\(record\.server\.id, chapterDto, comic\.id, existing\.pages/, 'Kavita library updates must preserve already hydrated reader pages')
assert.match(libraryUpdateServiceSource, /client\.buildReaderImageUrl\(chapterDto\.id, pageIndex\)[\s\S]*mapKavitaChapterToChapter\(record\.server\.id, chapterDto, comic\.id, pages/, 'Kavita library updates must generate reader image URLs for newly discovered chapters')
assert.match(modelSource, /export interface KavitaProgressDto[\s\S]*volumeId: KavitaVolumeId[\s\S]*chapterId: KavitaChapterId[\s\S]*pageNum: number[\s\S]*seriesId: KavitaSeriesId[\s\S]*libraryId: KavitaLibraryId/, 'Kavita progress model must match the official ProgressDto required fields')

assert.match(settingsSource, /settings_row_kavita_title[\s\S]*rowsByKeys\(\['komga', 'kavita', 'opds', 'webdav'\]\)[\s\S]*onOpenKavitaSettings/, 'Settings must expose Kavita in private library services')
assert.match(indexSource, /KavitaServerPage[\s\S]*RouteName\.KAVITA_SERVER[\s\S]*route_kavita_title/, 'Index route stack must include Kavita settings page')
assert.match(browseSource, /KavitaBrowsePage[\s\S]*kavitaConfigured[\s\S]*browse_kavita_detail/, 'Browse must render configured Kavita library entries')
assert.match(browseSource, /this\.kavitaConfigured = await store\.loadKavita\(\) !== undefined/, 'Browse availability must check saved Kavita configuration')
assert.match(browseSource, /KavitaBrowsePage\(\{[\s\S]*libraryStore: this\.libraryStore[\s\S]*onOpenReader: \(comicId: string, chapterId\?: string\)/, 'Browse must pass shelf and reader callbacks into Kavita browsing')
assert.match(kavitaBrowseSource, /openLibrary\(item: KavitaLibraryDto\)[\s\S]*listSeries\(item\.id\)[\s\S]*SeriesRow\(item: KavitaSeriesDto\)/, 'Kavita browse page must drill from libraries into series list without faking reader support')
assert.match(kavitaBrowseSource, /openSeries\(item: KavitaSeriesDto\)[\s\S]*listVolumes\(item\.id\)[\s\S]*VolumeRow\(item: KavitaVolumeDto\)/, 'Kavita browse page must drill from series into volume and chapter metadata without faking reader support')
assert.match(kavitaBrowseSource, /openChapter\(chapter: KavitaChapterDto\)[\s\S]*getChapterInfo\(chapter\.id\)[\s\S]*upsertComicAndPersistLibraryStore[\s\S]*this\.onOpenReader\(comic\.id, createKavitaChapterId/, 'Kavita browse page must open real reader sessions from chapter-info and persisted remote comics')
assert.match(kavitaBrowseSource, /buildChapterPages\(record: KavitaServerRecord[\s\S]*mapKavitaPageToPage\([\s\S]*client\.buildReaderImageUrl\(chapter\.id, index\)/, 'Kavita browse page must build Reader pages from Kavita reader image URLs')
