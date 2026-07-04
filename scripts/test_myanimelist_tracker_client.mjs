import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = readFileSync(resolve(root, 'entry/src/main/ets/model/MyAnimeListTrackerClient.ets'), 'utf8')
const trackerModels = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerModels.ets'), 'utf8')

assert.match(source, /export class MyAnimeListTrackerClient/, 'MyAnimeList tracker client must exist')
assert.match(source, /export interface MyAnimeListTrackerHttpAdapter[\s\S]*request\(request: MyAnimeListTrackerHttpRequest\): Promise<MyAnimeListTrackerHttpResponse>/, 'MyAnimeList tracker client must use an injectable HTTP adapter')
assert.match(source, /import \{ http \} from '@kit\.NetworkKit'/, 'MyAnimeList tracker client must provide a Harmony NetworkKit adapter')
assert.match(
  source,
  /export function myAnimeListTrackerHeadersToHttpHeaderObject\(headers: MyAnimeListTrackerHeaders\)[\s\S]*"Authorization"[\s\S]*"Accept"[\s\S]*"Content-Type"/,
  'MyAnimeList HTTP adapter must convert typed headers to Harmony request headers',
)
assert.match(
  source,
  /export class HarmonyMyAnimeListTrackerHttpAdapter implements MyAnimeListTrackerHttpAdapter[\s\S]*http\.createHttp\(\)[\s\S]*method: request\.method === 'GET' \? http\.RequestMethod\.GET : http\.RequestMethod\.PUT[\s\S]*expectDataType: http\.HttpDataType\.STRING[\s\S]*header: myAnimeListTrackerHeadersToHttpHeaderObject\(request\.headers\)[\s\S]*httpRequest\.destroy\(\)/,
  'MyAnimeList Harmony adapter must dispatch GET/PUT requests and always destroy the request handle',
)
assert.match(source, /const MYANIMELIST_API_BASE: string = 'https:\/\/api\.myanimelist\.net\/v2'/, 'MyAnimeList client must target the official API v2 base')
assert.match(source, /MYANIMELIST_PROVIDER_ID: TrackerProviderId = 'myanimelist'/, 'MyAnimeList client must identify the tracker provider id')
assert.match(source, /fetchProfile\(accessToken: string\)[\s\S]*'\/users\/@me'[\s\S]*fields: 'id,name'/, 'MyAnimeList client must support profile fetch')
assert.match(source, /searchManga\(accessToken: string, query: string[\s\S]*'\/manga'[\s\S]*q: normalizedQuery[\s\S]*fields: 'id,title,main_picture,media_type,status,alternative_titles'/, 'MyAnimeList client must support manga search mapping')
assert.match(source, /fetchProgress\(accessToken: string, providerTitleId: string\)[\s\S]*`\/manga\/\$\{mangaId\}`[\s\S]*fields: 'id,title,status,media_type,my_list_status,num_chapters'/, 'MyAnimeList client must support progress pull')
assert.match(source, /pushProgress\(accessToken: string, providerTitleId: string, progress: number, completed: boolean\)[\s\S]*`\/manga\/\$\{mangaId\}\/my_list_status`[\s\S]*status=\$\{completed \? 'completed' : 'reading'\}[\s\S]*num_chapters_read=\$\{normalizedProgress\}/, 'MyAnimeList client must support progress push')

assert.match(
  source,
  /buildApiRequest\([\s\S]*accessToken: string,[\s\S]*method: MyAnimeListTrackerHttpMethod[\s\S]*authorization: `Bearer \$\{token\}`[\s\S]*body,/,
  'MyAnimeList requests must keep bearer tokens in headers and serialize only safe query/body fields',
)
const buildRequestBlock = source.match(/buildApiRequest\([\s\S]*?\n  \}/)?.[0] ?? ''
const bodyAssignment = buildRequestBlock.match(/body,[\s\S]*?\n    \}/)?.[0] ?? ''
assert.doesNotMatch(
  bodyAssignment,
  /accessToken|authorization|Bearer/,
  'MyAnimeList request body must not serialize access token material',
)
assert.match(
  source,
  /redactMyAnimeListTrackerRequest[\s\S]*headers\.authorization = '<redacted>'[\s\S]*body: request\.body/,
  'MyAnimeList request redaction must hide Authorization while preserving safe request body diagnostics',
)
assert.doesNotMatch(
  source,
  /console\.(log|info|warn|error)\([^)]*(token|authorization|Bearer|accessToken)/i,
  'MyAnimeList client must not log token-bearing material',
)

assert.match(
  source,
  /export type MyAnimeListTrackerErrorCode =[\s\S]*'unauthorized'[\s\S]*'rate_limited'[\s\S]*'network_error'[\s\S]*'malformed_response'/,
  'MyAnimeList client must expose safe provider error buckets',
)
assert.match(
  source,
  /myAnimeListTrackerErrorCode\(response[\s\S]*response\.status === 401 \|\| response\.status === 403[\s\S]*'unauthorized'[\s\S]*response\.status === 429[\s\S]*'rate_limited'/,
  'HTTP response errors must map auth and rate-limit failures to safe buckets',
)
assert.match(
  source,
  /catch \(_error\) \{[\s\S]*errorCode: 'network_error'[\s\S]*JSON\.parse\(response\.body\)[\s\S]*catch \(_error\) \{[\s\S]*errorCode: 'malformed_response'/,
  'MyAnimeList client must fail closed for transport and malformed JSON errors',
)

assert.match(
  source,
  /normalizeMyAnimeListTrackerSearchQuery\(query: string\): string[\s\S]*query\.trim\(\)\.slice\(0, 120\)/,
  'MyAnimeList search query must be bounded before transport',
)
assert.match(
  source,
  /limit: `\$\{Math\.max\(1, Math\.min\(20, Math\.floor\(limit\)\)\)\}`/,
  'MyAnimeList search page size must be bounded',
)
assert.match(
  source,
  /function normalizeMyAnimeListMangaId\(value: string\): number[\s\S]*\/\^\[0-9\]\{1,12\}\$\/\.test\(trimmed\)/,
  'MyAnimeList manga ids must be numeric and bounded before progress sync',
)
assert.match(
  source,
  /normalizeMyAnimeListProgress\(progress[\s\S]*completed: status === 'completed'/,
  'MyAnimeList progress normalization must derive completed state from provider status',
)
assert.match(
  trackerModels,
  /providerId: 'myanimelist'[\s\S]*supportStatus: 'available'/,
  'Tracker provider registry must keep MyAnimeList available for this client',
)

console.log('MyAnimeList tracker client checks PASS')
