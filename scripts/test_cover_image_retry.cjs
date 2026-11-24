// Executes the production cover retry policy; no device or network.
const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/model/CoverImageRetryPolicy.ets'), 'utf8')
const policyExports = {}
const output = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
new Function('exports', output)(policyExports)

test('a transient cover failure receives exactly one delayed retry', () => {
  const failure = new Error('reader_remote_image_fetch_failed_2300028')
  assert.equal(policyExports.coverImageFailureRetryable(failure), true)
  assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 0), 1200)
  assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 1), -1)
})

test('a failed decode may retry once after its cached image is invalidated', () => {
  const failure = new Error('image_source_decode_failed')
  assert.equal(policyExports.coverImageFailureRetryable(failure), false)
  assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 0), -1)
  assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 0, true), 1200)
  assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 1, true), -1)
})

test('authentication, quota, missing content and client errors stay terminal', () => {
  for (const failure of [
    new Error('reader_remote_image_http_401'),
    new Error('reader_remote_image_http_402'),
    new Error('reader_remote_image_http_403'),
    new Error('reader_remote_image_http_404'),
    new Error('reader_remote_image_http_410'),
    new Error('cover_image_http_403'),
    Object.assign(new Error('quota'), { diagnostic: { kind: 'image_quota_exhausted', status: 402 } }),
  ]) {
    assert.equal(policyExports.coverImageFailureRetryable(failure), false, failure.message)
    assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 0), -1, failure.message)
  }
})

test('rate limits, server failures and neutral transport codes remain retryable once', () => {
  for (const failure of [
    new Error('reader_remote_image_http_408'),
    new Error('reader_remote_image_http_429'),
    new Error('reader_remote_image_http_503'),
    new Error('cover_image_http_503'),
    new Error('cover_image_fetch_failed_2300028'),
    Object.assign(new Error('rate limited'), { diagnostic: { kind: 'rate_limit', status: 429 } }),
    Object.assign(new Error('transport'), { code: 2300028 }),
  ]) {
    assert.equal(policyExports.coverImageFailureRetryable(failure), true, failure.message)
    assert.equal(policyExports.coverImageAutomaticRetryDelayMs(failure, 0), 1200, failure.message)
  }
})

function mountedCover() {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/components/CachedCoverImage.ets'), 'utf8')
  const tree = ts.createSourceFile('cover.ts', source.replace(/\bstruct\b/g, 'class'), ts.ScriptTarget.Latest, true)
  const component = tree.statements.find(node => ts.isClassDeclaration(node) && node.name.text === 'CachedCoverImage')
  const names = ['coverVisibilityChanged', 'createSourceSignature', 'handleSourceChanged', 'onSourceChanged', 'cancelAutomaticRetry']
  const body = names.map(name => component.members.find(node => node.name?.text === name).getText(tree)).join('\n')
  const key = tree.statements.find(node => ts.isFunctionDeclaration(node) && node.name?.text === 'cachedCoverFailureKey').getText(tree)
  const compiled = ts.transpileModule(key + '\nclass Cover {' + body + '}\nexports.Cover = Cover', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS, experimentalDecorators: true },
  }).outputText
  const api = {}
  new Function('exports', 'Monitor', compiled)(api, () => () => {})
  const cover = new api.Cover()
  const requests = []
  Object.assign(cover, { uri: 'https://fixture.invalid/cover.jpg', sourceRuntimeId: 'source', sourceImageId: 'work',
    sourceKind: 'private_library', remoteServerId: '', sourceMangaUrl: 'https://fixture.invalid/work',
    downloadedComicId: '', decodeMaxEdge: 320, coverOwnerId: 'work', requestedOwnerId: 'work',
    decodeGeneration: 1, completedAutomaticRetries: 1, automaticRetryTimer: -1, coverVisible: true,
    disposed: false, loading: false, displayedSignature: '', decodeImage: async (...args) => { requests.push(args) } })
  cover.sourceSignature = cover.createSourceSignature(cover.uri, cover.sourceRuntimeId, cover.sourceImageId,
    cover.sourceKind, cover.remoteServerId, cover.sourceMangaUrl)
  cover.failedSignature = cover.sourceSignature
  return { cover, requests }
}

test('a retained failed cover reloads the same URI once when the page becomes visible again', async () => {
  const { cover, requests } = mountedCover()
  cover.coverVisibilityChanged(false)
  cover.coverVisibilityChanged(true)
  await Promise.resolve()
  assert.equal(requests.length, 1)
  assert.equal(requests[0][0], cover.uri)
  assert.equal(cover.failedSignature, '')
  assert.equal(cover.completedAutomaticRetries, 0)
  cover.coverVisibilityChanged(true)
  await Promise.resolve()
  assert.equal(requests.length, 1, 'remaining visible does not create a retry loop')
})

test('successful and destroyed covers do not reload when visibility changes', async () => {
  for (const state of [{ failedSignature: '' }, { disposed: true }]) {
    const { cover, requests } = mountedCover()
    Object.assign(cover, state)
    cover.coverVisibilityChanged(false); cover.coverVisibilityChanged(true)
    await Promise.resolve()
    assert.equal(requests.length, 0)
  }
})
