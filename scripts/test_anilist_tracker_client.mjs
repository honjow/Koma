import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const source = readFileSync(resolve(root, 'entry/src/main/ets/model/AniListTrackerClient.ets'), 'utf8')
const trackerModels = readFileSync(resolve(root, 'entry/src/main/ets/model/TrackerModels.ets'), 'utf8')

assert.match(source, /export class AniListTrackerClient/, 'AniList tracker client must exist')
assert.match(source, /export interface AniListTrackerHttpAdapter[\s\S]*request\(request: AniListTrackerHttpRequest\): Promise<AniListTrackerHttpResponse>/, 'AniList tracker client must use an injectable HTTP adapter')
assert.match(source, /const ANILIST_GRAPHQL_ENDPOINT: string = 'https:\/\/graphql\.anilist\.co'/, 'AniList client must target the official GraphQL endpoint')
assert.match(source, /ANILIST_VIEWER_QUERY[\s\S]*Viewer \{ id name \}/, 'AniList client must support profile fetch')
assert.match(source, /ANILIST_SEARCH_QUERY[\s\S]*media\(type: MANGA, search: \$search\)/, 'AniList client must support manga search mapping')
assert.match(source, /ANILIST_PROGRESS_QUERY[\s\S]*MediaList\(mediaId: \$mediaId, type: MANGA\)/, 'AniList client must support progress pull')
assert.match(source, /ANILIST_SAVE_PROGRESS_MUTATION[\s\S]*SaveMediaListEntry\(mediaId: \$mediaId, progress: \$progress, status: \$status\)/, 'AniList client must support progress push')

assert.match(
  source,
  /buildGraphqlRequest\(accessToken: string[\s\S]*authorization: `Bearer \$\{token\}`[\s\S]*body: JSON\.stringify\(\{[\s\S]*query,[\s\S]*variables,/,
  'AniList requests must keep bearer tokens in headers and serialize only query variables in the body',
)
const buildRequestBlock = source.match(/buildGraphqlRequest\([\s\S]*?\n  \}/)?.[0] ?? ''
const requestBodyBlock = buildRequestBlock.match(/body: JSON\.stringify\(\{[\s\S]*?\}\),/)?.[0] ?? ''
assert.doesNotMatch(
  requestBodyBlock,
  /accessToken|token|authorization|Bearer/,
  'AniList request body must not serialize access token material',
)
assert.match(
  source,
  /redactAniListTrackerRequest[\s\S]*headers\.authorization = '<redacted>'[\s\S]*body: request\.body/,
  'AniList request redaction must hide Authorization while preserving safe request body diagnostics',
)
assert.doesNotMatch(
  source,
  /console\.(log|info|warn|error)\([^)]*(token|authorization|Bearer|accessToken)/i,
  'AniList client must not log token-bearing material',
)

assert.match(
  source,
  /export type AniListTrackerErrorCode =[\s\S]*'unauthorized'[\s\S]*'rate_limited'[\s\S]*'network_error'[\s\S]*'malformed_response'/,
  'AniList client must expose safe provider error buckets',
)
assert.match(
  source,
  /aniListTrackerErrorCode\(response[\s\S]*response\.status === 401 \|\| response\.status === 403[\s\S]*'unauthorized'[\s\S]*response\.status === 429[\s\S]*'rate_limited'/,
  'HTTP response errors must map auth and rate-limit failures to safe buckets',
)
assert.match(
  source,
  /private graphqlErrorCode\(errors: AniListGraphqlError\[\]\)[\s\S]*message\.indexOf\('auth'\)[\s\S]*'unauthorized'[\s\S]*message\.indexOf\('rate'\)[\s\S]*'rate_limited'/,
  'GraphQL errors must be bucketed without surfacing raw provider messages',
)
assert.match(
  source,
  /catch \(_error\) \{[\s\S]*errorCode: 'network_error'[\s\S]*JSON\.parse\(response\.body\)[\s\S]*catch \(_error\) \{[\s\S]*errorCode: 'malformed_response'/,
  'AniList client must fail closed for transport and malformed JSON errors',
)

assert.match(
  source,
  /normalizeAniListTrackerSearchQuery\(query: string\): string[\s\S]*query\.trim\(\)\.slice\(0, 120\)/,
  'AniList search query must be bounded before transport',
)
assert.match(
  source,
  /perPage: Math\.max\(1, Math\.min\(20, Math\.floor\(perPage\)\)\)/,
  'AniList search page size must be bounded',
)
assert.match(
  source,
  /function normalizeAniListMediaId\(value: string\): number[\s\S]*\/\^\[0-9\]\{1,12\}\$\/\.test\(trimmed\)/,
  'AniList media ids must be numeric and bounded before progress sync',
)
assert.match(
  source,
  /normalizeAniListProgress\(progress[\s\S]*completed: progress\.status === 'COMPLETED'/,
  'AniList progress normalization must derive completed state from provider status',
)
assert.match(
  trackerModels,
  /providerId: 'anilist'[\s\S]*supportStatus: 'available'/,
  'Tracker provider registry must keep AniList available for this client',
)

console.log('AniList tracker client checks PASS')
