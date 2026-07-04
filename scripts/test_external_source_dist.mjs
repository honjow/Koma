import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const distDir = resolve(process.env.KOMA_SOURCES_DIST ?? resolve(root, '../koma-sources/dist'))
const indexPath = resolve(distDir, 'index.json')
const devRunnerPath = resolve(process.env.KOMA_SOURCE_DEV ?? resolve(distDir, '../target/release/koma-source-dev'))

function fail(message) {
  throw new Error(message)
}

function isSafePkgPath(value) {
  return typeof value === 'string' &&
    value.length > 0 &&
    !value.startsWith('/') &&
    !value.includes('\\') &&
    !value.split('/').includes('..') &&
    value.endsWith('.koma')
}

function normalizedSha256(value) {
  if (typeof value !== 'string') return ''
  const normalized = value.trim().toLowerCase()
  return /^[0-9a-f]{64}$/.test(normalized) ? normalized : ''
}

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex')
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    fail(`${label} is not valid JSON: ${error.message}`)
  }
}

function unzipText(zipPath, entryName) {
  try {
    return execFileSync('unzip', ['-p', zipPath, entryName], { encoding: 'utf8' })
  } catch (_error) {
    fail(`${zipPath} is missing ${entryName} or unzip is unavailable`)
  }
}

function unzipBytes(zipPath, entryName) {
  try {
    return execFileSync('unzip', ['-p', zipPath, entryName])
  } catch (_error) {
    fail(`${zipPath} is missing ${entryName} or unzip is unavailable`)
  }
}

function runSourceInfo(zipPath) {
  const tempDir = mkdtempSync(resolve(tmpdir(), 'koma-source-dist-'))
  const wasmPath = resolve(tempDir, 'source.wasm')
  try {
    writeFileSync(wasmPath, unzipBytes(zipPath, 'source.wasm'))
    return readJsonFromText(execFileSync(devRunnerPath, ['info', wasmPath], { encoding: 'utf8' }), `${zipPath} source info`)
  } catch (error) {
    fail(`${zipPath} source.wasm failed source info smoke: ${error.message}`)
  } finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
}

function zipListing(zipPath) {
  try {
    return execFileSync('unzip', ['-Z1', zipPath], { encoding: 'utf8' })
      .split('\n')
      .map((line) => line.trim())
      .filter(Boolean)
  } catch (_error) {
    fail(`${zipPath} is not a readable .koma zip`)
  }
}

assert.ok(existsSync(indexPath), `missing source index: ${indexPath}`)
assert.ok(existsSync(devRunnerPath), `missing source dev runner: ${devRunnerPath}`)

const sourceIndex = readJson(indexPath, 'source index')
const sources = Array.isArray(sourceIndex) ? sourceIndex : sourceIndex.sources
assert.ok(Array.isArray(sources), 'source index must be an array or { sources: [] }')
assert.ok(sources.length > 0, 'source index must contain at least one source')

const seenIds = new Set()

sources.forEach((source, index) => {
  assert.equal(typeof source.id, 'string', `source[${index}].id must be a string`)
  assert.equal(typeof source.name, 'string', `source[${index}].name must be a string`)
  assert.equal(typeof source.version, 'string', `source[${index}].version must be a string`)
  assert.ok(isSafePkgPath(source.pkg), `source[${index}].pkg must be a safe relative .koma path`)
  assert.ok(!seenIds.has(source.id), `duplicate source id: ${source.id}`)
  seenIds.add(source.id)

  const pkgPath = resolve(distDir, source.pkg)
  assert.ok(pkgPath.startsWith(distDir), `pkg escapes dist dir: ${source.pkg}`)
  assert.ok(existsSync(pkgPath), `missing source package: ${source.pkg}`)
  const pinnedHash = normalizedSha256(source.sha256)
  if (pinnedHash.length > 0) {
    assert.equal(sha256File(pkgPath), pinnedHash, `${source.pkg} sha256 must match index pin`)
  }

  const entries = zipListing(pkgPath)
  assert.ok(entries.includes('manifest.json'), `${source.pkg} must contain manifest.json`)
  assert.ok(entries.includes('source.wasm'), `${source.pkg} must contain source.wasm`)
  assert.deepEqual(
    entries.filter((entry) => entry.includes('..') || entry.startsWith('/')),
    [],
    `${source.pkg} must not contain unsafe zip entries`,
  )

  const manifest = readJsonFromText(unzipText(pkgPath, 'manifest.json'), `${source.pkg} manifest`)
  assert.equal(manifest.id, source.id, `${source.pkg} manifest id must match index id`)
  assert.equal(manifest.version, source.version, `${source.pkg} manifest version must match index version`)
  assert.equal(manifest.name, source.name, `${source.pkg} manifest name must match index name`)

  const info = runSourceInfo(pkgPath)
  assert.equal(info?.ok, true, `${source.pkg} source info smoke must succeed`)
  assert.equal(info?.data?.sourceInfo?.id, source.id, `${source.pkg} source info id must match index id`)
  assert.equal(info?.data?.sourceInfo?.version, source.version, `${source.pkg} source info version must match index version`)
  assert.equal(info?.data?.sourceInfo?.name, source.name, `${source.pkg} source info name must match index name`)
})

function readJsonFromText(text, label) {
  try {
    return JSON.parse(text)
  } catch (error) {
    fail(`${label} is not valid JSON: ${error.message}`)
  }
}

console.log(`external source dist checks PASS: ${sources.length} packages in ${distDir}`)
