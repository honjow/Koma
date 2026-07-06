import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { request as httpRequest } from 'node:http'
import { request as httpsRequest } from 'node:https'
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
    sourceId: 'com.mangabz.koma',
    label: 'Mangabz',
    query: '海贼王',
    expectedMangaId: 'manga:139bz',
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

function runSourceOperation(wasmPath, op, request, label, options = {}) {
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
  if (response.ok !== true && options.allowFailure === true) {
    return response
  }
  assert.equal(response.ok, true, `${label} ${op} must return ok=true: ${response.reasonCode ?? response.error ?? 'no reason'}`)
  const operationAliases = options.operationAliases ?? []
  assert.ok(response.operation === op || operationAliases.includes(response.operation), `${label} ${op} must echo the operation`)
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
  return pages
}

function stringField(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined
}

function imageRecord(page) {
  const image = page.image
  if (image === undefined || image === null || Array.isArray(image) || typeof image !== 'object') {
    return undefined
  }
  return image
}

function directImageUrl(page) {
  const image = imageRecord(page)
  return stringField(page.url) ??
    stringField(page.uri) ??
    stringField(page.imageUrl) ??
    stringField(page.image_url) ??
    stringField(image?.url) ??
    stringField(image?.uri)
}

function imageRequestPayload(response, label) {
  const data = response.data
  assert.ok(data !== undefined && data !== null && typeof data === 'object', `${label} get_image_request must return data`)
  const nested = data.imageRequest
  if (nested !== undefined && nested !== null && !Array.isArray(nested) && typeof nested === 'object') {
    return nested
  }
  return data
}

function resolveFirstPageImage(wasmPath, page, label) {
  const directUrl = directImageUrl(page)
  const image = imageRecord(page)
  assert.ok(directUrl !== undefined || image?.kind === 'request', `${label} first page must expose a URL or request descriptor`)
  const request = { pageId: page.id }
  const pageUri = stringField(page.uri) ?? stringField(image?.uri)
  if (pageUri !== undefined) {
    request.pageUri = pageUri
  }
  if (directUrl !== undefined) {
    request.url = directUrl
    request.pageUri = pageUri ?? directUrl
  }
  const response = runSourceOperation(wasmPath, 'get_image_request', request, label, {
    allowFailure: true,
    operationAliases: ['image_request', 'modify_image_request'],
  })
  if (response.ok === true) {
    const payload = imageRequestPayload(response, label)
    const url = stringField(payload.url)
    if (url !== undefined) {
      return {
        url,
        headers: payload.headers !== undefined && typeof payload.headers === 'object' && !Array.isArray(payload.headers) ? payload.headers : undefined,
        via: 'request',
      }
    }
  }
  assert.ok(directUrl !== undefined, `${label} get_image_request failed and first page has no direct image URL`)
  return { url: directUrl, headers: undefined, via: 'url-fallback' }
}

function normalizeHttpHeaders(headers) {
  const normalized = {
    'User-Agent': 'KomaSourceMatrixSmoke/1.0',
  }
  if (headers === undefined) {
    return normalized
  }
  Object.entries(headers).forEach(([key, value]) => {
    if (typeof value === 'string' && value.trim().length > 0) {
      normalized[key] = value
    }
  })
  return normalized
}

function assertReadableImageUrl(url, headers, label, redirectCount = 0) {
  assert.ok(/^https?:\/\//.test(url), `${label} first page image URL must be http(s)`)
  assert.ok(redirectCount <= 4, `${label} first page image URL redirected too many times`)
  const parsedUrl = new URL(url)
  const transport = parsedUrl.protocol === 'http:' ? httpRequest : httpsRequest
  return new Promise((resolvePromise, rejectPromise) => {
    const req = transport(parsedUrl, {
      method: 'GET',
      headers: normalizeHttpHeaders(headers),
    }, (res) => {
      const statusCode = res.statusCode ?? 0
      const location = res.headers.location
      if (statusCode >= 300 && statusCode < 400 && typeof location === 'string') {
        res.resume()
        const redirectedUrl = new URL(location, parsedUrl).toString()
        assertReadableImageUrl(redirectedUrl, headers, label, redirectCount + 1).then(resolvePromise, rejectPromise)
        return
      }
      if (statusCode < 200 || statusCode >= 300) {
        res.resume()
        rejectPromise(new Error(`${label} first page image returned HTTP ${statusCode}`))
        return
      }
      let receivedBytes = 0
      res.on('data', (chunk) => {
        receivedBytes += chunk.length
        req.destroy()
        resolvePromise()
      })
      res.on('end', () => {
        if (receivedBytes > 0) {
          resolvePromise()
        } else {
          rejectPromise(new Error(`${label} first page image returned no bytes`))
        }
      })
    })
    req.setTimeout(15_000, () => {
      req.destroy(new Error(`${label} first page image timed out`))
    })
    req.on('error', (error) => {
      if (error.code === 'ERR_STREAM_PREMATURE_CLOSE') {
        resolvePromise()
        return
      }
      rejectPromise(error)
    })
    req.end()
  })
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
    const pageRows = assertPages(pages, chapter.id, matrixCase.label)
    const firstImage = resolveFirstPageImage(wasmPath, pageRows[0], matrixCase.label)
    await assertReadableImageUrl(firstImage.url, firstImage.headers, matrixCase.label)
    summaries.push({
      sourceId: matrixCase.sourceId,
      label: matrixCase.label,
      mangaId: manga.id,
      chapterId: chapter.id,
      pageCount: pageRows.length,
      firstImageVia: firstImage.via,
    })
  } finally {
    rmSync(tempDir, { recursive: true, force: true })
  }
}

console.log(`source CLI matrix smoke PASS: ${summaries.length} sources`)
summaries.forEach((summary) => {
  console.log(`- ${summary.label} (${summary.sourceId}): ${summary.mangaId} -> ${summary.chapterId}, pages=${summary.pageCount}, firstImage=${summary.firstImageVia}`)
})
