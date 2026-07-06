import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const distDir = resolve(process.env.KOMA_SOURCES_DIST ?? resolve(root, '../koma-sources/dist'))
const indexPath = resolve(distDir, 'index.json')
const devRunnerPath = resolve(process.env.KOMA_SOURCE_DEV ?? resolve(distDir, '../target/release/koma-source-dev'))

const DEFAULT_CASES = [
  {
    sourceId: 'org.mangadex.koma',
    label: 'MangaDex',
    query: 'one piece',
    expectedMangaId: 'mdx:a1c7c817-4e59-43b7-9365-09675a149a6f',
  },
  {
    sourceId: 'com.dm5.koma',
    label: 'DM5',
    query: '坂本',
    expectedMangaId: 'manga:manhua-banben-days',
  },
]

function fail(message) {
  throw new Error(message)
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    fail(`${label} is not valid JSON: ${error.message}`)
  }
}

function responseJsonFromOutput(output, label) {
  const lines = output.split(/\r?\n/)
  const jsonStart = lines.findIndex((line) => line.trim() === '{')
  if (jsonStart < 0) {
    fail(`${label} did not print a JSON response`)
  }
  try {
    return JSON.parse(lines.slice(jsonStart).join('\n'))
  } catch (error) {
    fail(`${label} response JSON could not be parsed: ${error.message}`)
  }
}

function readMatrixCases() {
  const raw = process.env.KOMA_SOURCE_CLI_MATRIX
  if (raw === undefined || raw.trim().length === 0) {
    return DEFAULT_CASES
  }
  const parsed = JSON.parse(raw)
  assert.ok(Array.isArray(parsed), 'KOMA_SOURCE_CLI_MATRIX must be a JSON array')
  return parsed.map((item, index) => {
    assert.equal(typeof item.sourceId, 'string', `matrix[${index}].sourceId must be a string`)
    assert.equal(typeof item.query, 'string', `matrix[${index}].query must be a string`)
    return {
      sourceId: item.sourceId,
      label: typeof item.label === 'string' ? item.label : item.sourceId,
      query: item.query,
      expectedMangaId: typeof item.expectedMangaId === 'string' ? item.expectedMangaId : '',
    }
  })
}

function packagePathForSource(sourceIndex, sourceId) {
  const sources = Array.isArray(sourceIndex) ? sourceIndex : sourceIndex.sources
  assert.ok(Array.isArray(sources), 'source index must be an array or { sources: [] }')
  const entry = sources.find((source) => source.id === sourceId)
  assert.ok(entry !== undefined, `source ${sourceId} must exist in dist index`)
  assert.equal(typeof entry.pkg, 'string', `source ${sourceId} must declare pkg`)
  assert.ok(!entry.pkg.startsWith('/') && !entry.pkg.split('/').includes('..'), `source ${sourceId} pkg must stay inside dist`)
  return resolve(distDir, entry.pkg)
}

function extractWasm(packagePath) {
  const tempDir = mkdtempSync(resolve(tmpdir(), 'koma-source-cli-matrix-'))
  const wasmPath = resolve(tempDir, 'source.wasm')
  try {
    writeFileSync(wasmPath, execFileSync('unzip', ['-p', packagePath, 'source.wasm']))
    return { tempDir, wasmPath }
  } catch (error) {
    rmSync(tempDir, { recursive: true, force: true })
    fail(`${packagePath} is missing source.wasm: ${error.message}`)
  }
}

function runSourceOperation(wasmPath, op, request, label) {
  let output = ''
  try {
    output = execFileSync(devRunnerPath, [
      'run',
      '--op',
      op,
      '--request',
      JSON.stringify(request),
      wasmPath,
    ], {
      encoding: 'utf8',
      maxBuffer: 12 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'pipe'],
    })
  } catch (error) {
    const stdout = typeof error.stdout === 'string' ? error.stdout : ''
    const stderr = typeof error.stderr === 'string' ? error.stderr : ''
    fail(`${label} ${op} command failed\n${stdout}\n${stderr}`.trim())
  }
  const response = responseJsonFromOutput(output, `${label} ${op}`)
  assert.equal(response.ok, true, `${label} ${op} must return ok=true`)
  assert.equal(response.operation, op, `${label} ${op} must echo the operation`)
  return response
}

function pickManga(searchResponse, expectedMangaId, label) {
  const items = searchResponse.data?.items
  assert.ok(Array.isArray(items), `${label} search must return data.items`)
  assert.ok(items.length > 0, `${label} search must return at least one manga`)
  if (expectedMangaId.length > 0) {
    const expected = items.find((item) => item.id === expectedMangaId)
    assert.ok(expected !== undefined, `${label} search must include expected manga ${expectedMangaId}`)
    return expected
  }
  return items[0]
}

function pickChapter(chapterResponse, mangaId, label) {
  const items = chapterResponse.data?.items
  assert.ok(Array.isArray(items), `${label} get_chapters must return data.items`)
  const chapter = items.find((item) => item.mangaId === mangaId && typeof item.id === 'string' && item.id.length > 0 && (item.pageCount ?? 0) > 0)
  assert.ok(chapter !== undefined, `${label} get_chapters must return at least one readable chapter for ${mangaId}`)
  return chapter
}

function assertPages(pageResponse, chapterId, label) {
  assert.equal(pageResponse.data?.chapterId, chapterId, `${label} get_pages must echo the chapter id`)
  const pages = pageResponse.data?.pages
  assert.ok(Array.isArray(pages), `${label} get_pages must return data.pages`)
  assert.ok(pages.length > 0, `${label} get_pages must return at least one page`)
  const firstPage = pages[0]
  assert.equal(typeof firstPage.id, 'string', `${label} first page must have id`)
  assert.ok(firstPage.image?.kind === 'url' || firstPage.image?.kind === 'request', `${label} first page must carry a readable image reference`)
  return pages.length
}

const sourceIndex = readJson(indexPath, 'source index')
const cases = readMatrixCases()
const summaries = []

for (const matrixCase of cases) {
  const packagePath = packagePathForSource(sourceIndex, matrixCase.sourceId)
  const { tempDir, wasmPath } = extractWasm(packagePath)
  try {
    const search = runSourceOperation(wasmPath, 'search', {
      query: matrixCase.query,
      page: 1,
      limit: 20,
    }, matrixCase.label)
    const manga = pickManga(search, matrixCase.expectedMangaId ?? '', matrixCase.label)
    const detail = runSourceOperation(wasmPath, 'get_manga', {
      mangaId: manga.id,
    }, matrixCase.label)
    assert.equal(detail.data?.manga?.id, manga.id, `${matrixCase.label} get_manga must return the selected manga`)
    const chapters = runSourceOperation(wasmPath, 'get_chapters', {
      mangaId: manga.id,
    }, matrixCase.label)
    const chapter = pickChapter(chapters, manga.id, matrixCase.label)
    const pages = runSourceOperation(wasmPath, 'get_pages', {
      mangaId: manga.id,
      chapterId: chapter.id,
    }, matrixCase.label)
    const pageCount = assertPages(pages, chapter.id, matrixCase.label)
    summaries.push({
      sourceId: matrixCase.sourceId,
      label: matrixCase.label,
      mangaId: manga.id,
      chapterId: chapter.id,
      pageCount,
    })
  } finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
}

console.log(`source CLI matrix smoke PASS: ${summaries.length} sources`)
summaries.forEach((summary) => {
  console.log(`- ${summary.label} (${summary.sourceId}): ${summary.mangaId} -> ${summary.chapterId}, pages=${summary.pageCount}`)
})
