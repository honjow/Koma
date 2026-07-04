import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/remote/KavitaModels.ets')
const clientPath = resolve(root, 'entry/src/main/ets/remote/KavitaClient.ets')
const storePath = resolve(root, 'entry/src/main/ets/model/RemoteServerStore.ets')
const browsePath = resolve(root, 'entry/src/main/ets/pages/BrowsePage.ets')
const kavitaBrowsePath = resolve(root, 'entry/src/main/ets/pages/KavitaBrowsePage.ets')
const settingsPath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const indexPath = resolve(root, 'entry/src/main/ets/pages/Index.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const clientSource = readFileSync(clientPath, 'utf8')
const storeSource = readFileSync(storePath, 'utf8')
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
assert.match(clientSource, /headers\.xApiKey[\s\S]*"x-api-key"/, 'Kavita client must send Auth Key as x-api-key header')
assert.match(clientSource, /http\.request\(\{[\s\S]*method,[\s\S]*url: this\.buildUrl\(path\)[\s\S]*headers: this\.buildHeaders\(headers\)[\s\S]*body,/, 'Kavita client must delegate requests through the injected adapter')
assert.match(clientSource, /listSeries\(libraryId: number[\s\S]*field: 19[\s\S]*value: `\$\{libraryId\}`[\s\S]*sortField: 1[\s\S]*this\.request\('POST', KavitaPaths\.librarySeries/, 'Kavita series listing must filter by library id and sort by name')
assert.doesNotMatch(clientSource, /\bfetch\s*\(/, 'Kavita client must not call fetch directly')

assert.equal(normalizeKavitaBaseUrl(' https://reader.example/kavita/// '), 'https://reader.example/kavita')
assert.equal(buildKavitaUrl('https://reader.example/kavita/', '/api/Library/libraries'), 'https://reader.example/kavita/api/Library/libraries')

assert.match(storeSource, /KAVITA_CREDENTIAL_KEY[\s\S]*DEFAULT_KAVITA_CREDENTIAL_REF[\s\S]*RemoteServerCredentialKind = 'komga' \| 'kavita' \| 'webdav' \| 'opds'/, 'RemoteServerStore must register Kavita as a secure credential kind')
assert.match(storeSource, /saveKavita[\s\S]*saveSecureCredential\(store, KAVITA_CREDENTIAL_KEY, 'kavita'[\s\S]*createKavitaClient/, 'RemoteServerStore must save Kavita Auth Key through AssetStore and expose a client factory')
assert.doesNotMatch(storeSource, /store\.put\(KAVITA_CREDENTIAL_KEY,\s*JSON\.stringify/, 'Kavita Auth Key must not be written to plain Preferences')

assert.match(settingsSource, /settings_row_kavita_title[\s\S]*rowsByKeys\(\['komga', 'kavita', 'opds', 'webdav'\]\)[\s\S]*onOpenKavitaSettings/, 'Settings must expose Kavita in private library services')
assert.match(indexSource, /KavitaServerPage[\s\S]*RouteName\.KAVITA_SERVER[\s\S]*route_kavita_title/, 'Index route stack must include Kavita settings page')
assert.match(browseSource, /KavitaBrowsePage[\s\S]*kavitaConfigured[\s\S]*browse_kavita_detail/, 'Browse must render configured Kavita library entries')
assert.match(browseSource, /this\.kavitaConfigured = await store\.loadKavita\(\) !== undefined/, 'Browse availability must check saved Kavita configuration')
assert.match(kavitaBrowseSource, /openLibrary\(item: KavitaLibraryDto\)[\s\S]*listSeries\(item\.id\)[\s\S]*SeriesRow\(item: KavitaSeriesDto\)/, 'Kavita browse page must drill from libraries into series list without faking reader support')
