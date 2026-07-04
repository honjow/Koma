import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const distDir = resolve(process.env.KOMA_SOURCES_DIST ?? resolve(root, '../koma-sources/dist'))
const indexPath = resolve(distDir, 'index.json')

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
})

function readJsonFromText(text, label) {
  try {
    return JSON.parse(text)
  } catch (error) {
    fail(`${label} is not valid JSON: ${error.message}`)
  }
}

console.log(`external source dist checks PASS: ${sources.length} packages in ${distDir}`)
