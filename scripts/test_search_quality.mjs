import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const crossSearchSource = readFileSync(resolve(root, 'entry/src/main/ets/model/CrossSearchService.ets'), 'utf8')
const searchPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SearchPage.ets'), 'utf8')
const historyStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/SearchHistoryStore.ets'), 'utf8')
const baseStrings = readFileSync(resolve(root, 'entry/src/main/resources/base/element/string.json'), 'utf8')
const enStrings = readFileSync(resolve(root, 'entry/src/main/resources/en_US/element/string.json'), 'utf8')
const zhStrings = readFileSync(resolve(root, 'entry/src/main/resources/zh_CN/element/string.json'), 'utf8')

assert.match(
  crossSearchSource,
  /export type CrossSearchMatchQuality = 'title_exact' \| 'title_prefix' \| 'title_contains' \| 'metadata_prefix' \| 'metadata_contains' \| 'weak'/,
  'cross-source search must expose a bounded match-quality enum',
)
assert.match(
  crossSearchSource,
  /matchQuality\?: CrossSearchMatchQuality[\s\S]*matchScore\?: number/,
  'search result items must carry optional match quality and score for UI/debug presentation',
)
assert.match(
  crossSearchSource,
  /sortSearchResultItems\(query: string, items: CrossSearchResultItem\[\]\)[\s\S]*searchResultWithMatchQuality\(item, normalizedQuery, compactQuery\)[\s\S]*const scoreDiff = \(left\.matchScore \?\? 9\) - \(right\.matchScore \?\? 9\)/,
  'cross-source search sorting must enrich every visible result with stable match quality before ordering',
)
assert.match(
  crossSearchSource,
  /searchResultMatchQuality\(item: CrossSearchResultItem[\s\S]*return 'title_exact'[\s\S]*return 'title_prefix'[\s\S]*return 'title_contains'[\s\S]*return 'metadata_prefix'[\s\S]*return 'metadata_contains'[\s\S]*return 'weak'/,
  'search quality scoring must distinguish title exact, title prefix, title contains, metadata prefix, metadata contains, and weak matches',
)
assert.match(
  crossSearchSource,
  /searchResultScoreForQuality\(matchQuality: CrossSearchMatchQuality\)[\s\S]*title_exact[\s\S]*return 0[\s\S]*title_prefix[\s\S]*return 1[\s\S]*title_contains[\s\S]*return 2[\s\S]*metadata_prefix[\s\S]*return 3[\s\S]*metadata_contains[\s\S]*return 4[\s\S]*return 9/,
  'search quality scores must keep title matches ahead of metadata matches and weak matches last',
)
assert.match(
  searchPageSource,
  /CrossSearchMatchQuality[\s\S]*matchQualityLabel\(matchQuality: CrossSearchMatchQuality \| undefined\)[\s\S]*search_match_title_exact[\s\S]*search_match_metadata_contains[\s\S]*search_match_weak/,
  'SearchPage must render a localized match-quality label instead of hiding result scoring',
)
assert.match(
  searchPageSource,
  /Text\(this\.matchQualityLabel\(item\.matchQuality\)\)[\s\S]*FONT_SIZE_CAPTION[\s\S]*TEXT_SECONDARY/,
  'SearchPage result rows must display match quality as secondary metadata',
)
assert.match(
  searchPageSource,
  /SourceFilterMenu\(\)[\s\S]*setSourceFilter\('all'\)[\s\S]*setSourceFilter\('local'\)[\s\S]*setSourceFilter\('private'\)[\s\S]*setSourceFilter\('source'\)/,
  'SearchPage must keep source/private/local filters available',
)
assert.match(
  searchPageSource,
  /removeHistoryEntry\(query: string\)[\s\S]*store\.remove\(query\)/,
  'SearchPage must support deleting individual search history entries',
)
assert.match(
  searchPageSource,
  /clearHistory\(\): void[\s\S]*store\.clear\(\)/,
  'SearchPage must support clearing search history',
)
assert.match(
  historyStoreSource,
  /removeSearchHistoryEntry\(entries: SearchHistoryEntry\[\], query: string\)[\s\S]*entry\.query\.toLocaleLowerCase\(\) !== normalizedQuery\.toLocaleLowerCase\(\)/,
  'SearchHistoryStore must delete history entries case-insensitively',
)
assert.match(
  crossSearchSource,
  /state: items\.length === 0 \? 'empty' : 'ready'/,
  'empty search sections must remain distinct from failed or timeout sections',
)
assert.match(
  crossSearchSource,
  /timeoutSection\(id: string, title: string, kind: CrossSearchSourceKind\)[\s\S]*state: 'timeout'[\s\S]*diagnosticCode: 'timeout'/,
  'timeout search sections must remain explicit',
)
assert.match(
  crossSearchSource,
  /errorSection\(id: string, title: string, kind: CrossSearchSourceKind, diagnostic: SearchDiagnostic\)[\s\S]*state: 'failed'[\s\S]*diagnosticCode: diagnostic\.code/,
  'failed search sections must remain explicit and diagnostic-code based',
)

for (const [name, source] of [['base', baseStrings], ['en_US', enStrings], ['zh_CN', zhStrings]]) {
  for (const key of [
    'search_match_title_exact',
    'search_match_title_prefix',
    'search_match_title_contains',
    'search_match_metadata_prefix',
    'search_match_metadata_contains',
    'search_match_weak',
  ]) {
    assert.match(source, new RegExp(`"name": "${key}"`), `${name} strings must include ${key}`)
  }
}

function normalizeText(value) {
  const lower = value.trim().toLocaleLowerCase()
  let normalized = ''
  let previousWasSpace = true
  for (let index = 0; index < lower.length; index += 1) {
    const ch = lower.charAt(index)
    const code = lower.charCodeAt(index)
    const isAsciiLetter = ch >= 'a' && ch <= 'z'
    const isDigit = ch >= '0' && ch <= '9'
    const isNonAsciiText = code > 127
    if (isAsciiLetter || isDigit || isNonAsciiText) {
      normalized += ch
      previousWasSpace = false
    } else if (!previousWasSpace) {
      normalized += ' '
      previousWasSpace = true
    }
  }
  return previousWasSpace && normalized.length > 0 ? normalized.substring(0, normalized.length - 1) : normalized
}

function compactText(value) {
  return normalizeText(value).replace(/ /g, '')
}

function matchQuality(item, query) {
  const normalizedQuery = normalizeText(query)
  const compactQuery = compactText(query)
  const title = normalizeText(item.title)
  const titleCompact = compactText(item.title)
  const subtitle = normalizeText(item.subtitle)
  const subtitleCompact = compactText(item.subtitle)
  if (title === normalizedQuery || titleCompact === compactQuery) return 'title_exact'
  if (title.startsWith(normalizedQuery) || titleCompact.startsWith(compactQuery)) return 'title_prefix'
  if (title.includes(normalizedQuery) || titleCompact.includes(compactQuery)) return 'title_contains'
  if (subtitle.startsWith(normalizedQuery) || subtitleCompact.startsWith(compactQuery)) return 'metadata_prefix'
  if (subtitle.includes(normalizedQuery) || subtitleCompact.includes(compactQuery)) return 'metadata_contains'
  return 'weak'
}

const examples = [
  { title: 'A Different Book', subtitle: 'Manga One Author' },
  { title: 'One', subtitle: 'Other' },
  { title: 'One Piece', subtitle: 'Other' },
  { title: 'The One Within', subtitle: 'Other' },
  { title: 'Other', subtitle: 'One Author' },
  { title: 'Other', subtitle: 'The One Tag' },
]
assert.deepEqual(
  examples.map((item) => matchQuality(item, 'One')),
  ['metadata_contains', 'title_exact', 'title_prefix', 'title_contains', 'metadata_prefix', 'metadata_contains'],
  'search quality fixture must classify title matches ahead of metadata matches',
)

console.log('search quality checks PASS')
