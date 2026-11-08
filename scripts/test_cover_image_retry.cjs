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
