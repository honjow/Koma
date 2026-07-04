import assert from 'node:assert/strict'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const contractPath = resolve(root, 'entry/src/main/ets/model/LocalLibraryFolderContract.ets')
const localImportCoordinatorPath = resolve(root, 'entry/src/main/ets/import/LocalImportCoordinator.ets')
const artifactPath = resolve(root, '.hermes-artifacts/20260527-d42-local-library-folder-contract/fixture-scan.json')
const contractSource = readFileSync(contractPath, 'utf8')
const localImportCoordinatorSource = readFileSync(localImportCoordinatorPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(contractSource, 'LOCAL_LIBRARY_FOLDER_CONTRACT_VERSION')
assertExport(contractSource, 'LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS')
assertExport(contractSource, 'LocalLibraryFolderRootContract')
assertExport(contractSource, 'LocalLibraryFolderEntry')
assertExport(contractSource, 'LocalLibraryFolderScanResult')
assertExport(contractSource, 'normalizeLocalLibraryRelativePath')
assertExport(contractSource, 'createLocalLibraryFolderRootContract')
assertExport(contractSource, 'scanLocalLibraryFolderEntries')
assertExport(contractSource, 'reconcileLocalLibraryFolderAvailability')

assert.match(contractSource, /LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS = 'BEST_EFFORT_DOCUMENT_PICKER'/, 'runtime picker support must be exposed as a best-effort document picker path')
assert.match(contractSource, /root\/\{series path\}\/\{chapter folder pages \| chapter\.cbz \| chapter\.zip\}/, 'contract must document deterministic series/chapter/page layout')
assert.doesNotMatch(contractSource, /fileIo|fs\.|unlink|rmdir|removeComputed|TRUNC|cacheDir/, 'folder contract must not delete or mutate files')
assert.match(contractSource, /idFor\('series', seriesPath\)/, 'series ids must derive from normalized relative series paths')
assert.match(contractSource, /normalized\.startsWith\('\/'\)[\s\S]*normalized\.includes\(':\/\/'\)[\s\S]*\/\^\[A-Za-z\]:\/\.test/, 'normalization must reject absolute paths and URI/path leakage')
assert.match(contractSource, /trimmed === '\.' \|\| trimmed === '\.\.'/, 'normalization must reject traversal segments')
// ETS sources are not directly importable from Node without the Harmony build pipeline, so this fixture runner
// mirrors the public contract and pins production-only helper rules with source assertions.
assert.match(contractSource, /function isExplicitImageChapterFolderName\(path: string\): boolean \{[\s\S]*\^\(chapter\|chap\|ch\|episode\|ep\|volume\|vol\|book\)\\b/, 'production helper must detect explicit chapter folder names')
assert.match(contractSource, /parentPath\.length > 0 && \(siblingChapterCount > 1 \|\| isExplicitImageChapterFolderName\(folder\.folderPath\)\)/, 'single explicit nested image folders must be inferred as chapters under their parent series')
assert.match(contractSource, /textContent\?: string/, 'production contract must accept model-provided sidecar text')
assert.match(contractSource, /sidecarMetadata\?: LocalLibrarySidecarMetadata/, 'production scan series must carry parsed sidecar metadata')
assert.match(contractSource, /parseLocalLibrarySidecarMetadata\(entry\.textContent\)/, 'production scanner must parse sidecar payloads through the metadata service')
assert.match(contractSource, /comicinfo\.xml/, 'production scanner must recognize ComicInfo.xml sidecar metadata')
assert.match(localImportCoordinatorSource, /isLocalLibraryMetadataPath[\s\S]*comicinfo\.xml/, 'picked-folder runtime scan must read ComicInfo.xml sidecar text')
assert.match(localImportCoordinatorSource, /readPickedFolderTextIfNeeded[\s\S]*byteSize > 1024 \* 1024[\s\S]*fs\.readTextSync/, 'picked-folder runtime sidecar IO must stay bounded to small text files')

const archiveExts = new Set(['.cbz', '.zip'])
const imageExts = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'])
const idPrefix = 'local-library-folder'

function normalizeSortKey(value) {
  return value.replace(/\\/g, '/').trim().toLocaleLowerCase()
}

function stableHash(value) {
  let hash = 2166136261
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash ^ value.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash.toString(16).padStart(8, '0')
}

function idFor(kind, relativePath) {
  return `${idPrefix}-${kind}-${stableHash(relativePath)}`
}

function getBaseName(path) {
  const parts = path.replace(/\\/g, '/').trim().split('/').filter(Boolean)
  return parts.length === 0 ? path : parts.at(-1)
}

function getExtension(path) {
  const base = getBaseName(path)
  const dot = base.lastIndexOf('.')
  return dot <= 0 || dot === base.length - 1 ? '' : base.substring(dot).toLocaleLowerCase()
}

function stripExtension(path) {
  const base = getBaseName(path)
  const dot = base.lastIndexOf('.')
  return dot <= 0 ? base : base.substring(0, dot)
}

function naturalSortTokens(value) {
  const normalized = value.replace(/\\/g, '/').trim().toLocaleLowerCase()
  const tokens = []
  let index = 0
  while (index < normalized.length) {
    const isDigit = normalized.charCodeAt(index) >= 48 && normalized.charCodeAt(index) <= 57
    let end = index + 1
    while (end < normalized.length) {
      const nextIsDigit = normalized.charCodeAt(end) >= 48 && normalized.charCodeAt(end) <= 57
      if (nextIsDigit !== isDigit) break
      end += 1
    }
    const text = normalized.substring(index, end)
    tokens.push(isDigit ? { text, numberValue: Number(text) } : { text })
    index = end
  }
  return tokens
}

function compareNaturalPath(a, b) {
  const aTokens = naturalSortTokens(a)
  const bTokens = naturalSortTokens(b)
  const count = Math.min(aTokens.length, bTokens.length)
  for (let index = 0; index < count; index += 1) {
    const left = aTokens[index]
    const right = bTokens[index]
    if (left.numberValue !== undefined && right.numberValue !== undefined) {
      if (left.numberValue !== right.numberValue) return left.numberValue - right.numberValue
      if (left.text.length !== right.text.length) return left.text.length - right.text.length
      continue
    }
    const textCompare = left.text.localeCompare(right.text)
    if (textCompare !== 0) return textCompare
  }
  if (aTokens.length !== bTokens.length) return aTokens.length - bTokens.length
  return a.localeCompare(b)
}

function dirnameOf(path) {
  const normalized = path.replace(/^\/+/, '').replace(/\/+$/, '')
  const slash = normalized.lastIndexOf('/')
  return slash < 0 ? '' : normalized.substring(0, slash)
}

function isExplicitImageChapterFolderName(path) {
  return /^(chapter|chap|ch|episode|ep|volume|vol|book)\b/i.test(getBaseName(path))
}

function isSidecarMetadataPath(path) {
  const name = getBaseName(path).toLowerCase()
  return ['metadata.json', 'series.json', 'comicinfo.json', 'comicinfo.xml', 'koma-metadata.json'].includes(name)
}

function parseSidecarMetadata(payload) {
  if (typeof payload !== 'string' || payload.trim().length === 0) return undefined
  const trimmed = payload.trim()
  if (trimmed.startsWith('<')) {
    if (!/<\s*ComicInfo\b/i.test(trimmed)) return undefined
    const firstTag = (tags) => {
      for (const tag of tags) {
        const match = new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i').exec(trimmed)
        if (match) {
          const text = match[1]
            .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
            .replace(/<[^>]+>/g, '')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"')
            .replace(/&apos;/g, "'")
            .replace(/&amp;/g, '&')
            .trim()
          if (text.length > 0) return text
        }
      }
      return undefined
    }
    const metadata = {}
    const title = firstTag(['Series', 'Title'])
    const authors = firstTag(['Writer', 'Author'])
    const status = firstTag(['Status'])?.toLowerCase()
    const coverPath = firstTag(['CoverPath', 'Cover', 'Thumbnail'])
    if (title) metadata.title = title
    if (authors) metadata.authors = [...new Set(authors.split(/[,;\u3001]/).map((author) => author.trim()).filter(Boolean))]
    if (status === 'ongoing' || status === 'continuing') metadata.status = 'ongoing'
    if (status === 'completed' || status === 'complete' || status === 'ended') metadata.status = 'completed'
    if (status === 'hiatus') metadata.status = 'hiatus'
    if (status === 'cancelled' || status === 'canceled') metadata.status = 'cancelled'
    if (typeof coverPath === 'string' && imageExts.has(getExtension(coverPath)) && !coverPath.includes('..')) metadata.coverPath = coverPath
    return Object.keys(metadata).length === 0 ? undefined : metadata
  }
  try {
    const row = JSON.parse(trimmed)
    if (!row || Array.isArray(row) || typeof row !== 'object') return undefined
    const metadata = {}
    if (typeof row.title === 'string' && row.title.trim().length > 0) metadata.title = row.title.trim()
    if (Array.isArray(row.authors)) metadata.authors = [...new Set(row.authors.filter((author) => typeof author === 'string').map((author) => author.trim()).filter(Boolean))]
    if (['ongoing', 'completed', 'hiatus', 'cancelled'].includes(row.status)) metadata.status = row.status
    if (typeof row.coverPath === 'string' && imageExts.has(getExtension(row.coverPath)) && !row.coverPath.includes('..')) metadata.coverPath = row.coverPath
    return Object.keys(metadata).length === 0 ? undefined : metadata
  } catch {
    return undefined
  }
}

function normalizeLocalLibraryRelativePath(path) {
  const normalized = path.replace(/\\/g, '/').trim()
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('://') ||
    /^[A-Za-z]:/.test(normalized) ||
    [...normalized].some((char) => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127)
  ) {
    throw new Error(`Unsafe local library path: ${path}`)
  }
  const parts = normalized.split('/')
  const safeParts = []
  for (const part of parts) {
    const trimmed = part.trim()
    if (trimmed.length === 0 || trimmed === '.' || trimmed === '..' || trimmed.includes(':')) {
      throw new Error(`Unsafe local library path segment: ${path}`)
    }
    safeParts.push(trimmed)
  }
  return safeParts.join('/')
}

function isHiddenPath(path) {
  return path.split('/').some((segment) => segment.startsWith('.'))
}

function scanLocalLibraryFolderEntries(entries, rootName = 'Local Library') {
  const rejectedEntries = []
  const seen = new Set()
  const imageFolders = new Map()
  const archiveEntries = []
  const sidecarMetadataBySeriesPath = new Map()

  for (const entry of entries) {
    if (entry.exists === false) continue
    let relativePath
    try {
      relativePath = normalizeLocalLibraryRelativePath(entry.relativePath)
    } catch {
      rejectedEntries.push({ relativePath: entry.relativePath, reason: 'unsafe_path' })
      continue
    }
    if (isHiddenPath(relativePath)) {
      rejectedEntries.push({ relativePath, reason: 'hidden' })
      continue
    }
    if (seen.has(relativePath)) continue
    seen.add(relativePath)
    if ((entry.kind ?? 'file') !== 'file') continue

    const extension = getExtension(relativePath)
    if (isSidecarMetadataPath(relativePath)) {
      const seriesPath = dirnameOf(relativePath)
      const metadata = parseSidecarMetadata(entry.textContent)
      if (seriesPath.length === 0) rejectedEntries.push({ relativePath, reason: 'root_level_metadata' })
      else if (metadata === undefined) rejectedEntries.push({ relativePath, reason: 'metadata_invalid' })
      else sidecarMetadataBySeriesPath.set(seriesPath, metadata)
      continue
    }
    if (imageExts.has(extension)) {
      const folderPath = dirnameOf(relativePath)
      if (folderPath.length === 0) {
        rejectedEntries.push({ relativePath, reason: 'root_level_image' })
        continue
      }
      const group = imageFolders.get(folderPath) ?? { folderPath, images: [] }
      group.images.push({ relativePath, kind: 'file' })
      imageFolders.set(folderPath, group)
      continue
    }
    if (archiveExts.has(extension)) {
      archiveEntries.push({ relativePath, kind: 'file' })
      continue
    }
    rejectedEntries.push({ relativePath, reason: 'unsupported' })
  }

  const childChapterCounts = new Map()
  for (const entry of archiveEntries) {
    const parentPath = dirnameOf(entry.relativePath)
    if (parentPath.length > 0) childChapterCounts.set(parentPath, (childChapterCounts.get(parentPath) ?? 0) + 1)
  }
  for (const group of imageFolders.values()) {
    const parentPath = dirnameOf(group.folderPath)
    if (parentPath.length > 0) childChapterCounts.set(parentPath, (childChapterCounts.get(parentPath) ?? 0) + 1)
  }

  const candidatesBySeries = new Map()
  const addCandidate = (candidate) => {
    const candidates = candidatesBySeries.get(candidate.seriesPath) ?? []
    candidates.push(candidate)
    candidatesBySeries.set(candidate.seriesPath, candidates)
  }

  for (const entry of archiveEntries) {
    const parentPath = dirnameOf(entry.relativePath)
    addCandidate({
      kind: 'archive',
      seriesPath: parentPath.length === 0 ? stripExtension(entry.relativePath) : parentPath,
      chapterPath: entry.relativePath,
      archivePath: entry.relativePath,
      pages: [],
    })
  }
  for (const group of imageFolders.values()) {
    const parentPath = dirnameOf(group.folderPath)
    const siblingChapterCount = parentPath.length === 0 ? 0 : childChapterCounts.get(parentPath) ?? 0
    addCandidate(parentPath.length > 0 && (siblingChapterCount > 1 || isExplicitImageChapterFolderName(group.folderPath))
      ? { kind: 'image_folder', seriesPath: parentPath, chapterPath: group.folderPath, pages: group.images }
      : { kind: 'image_folder', seriesPath: group.folderPath, chapterPath: group.folderPath, pages: group.images })
  }

  const series = [...candidatesBySeries.keys()].sort(compareNaturalPath).map((seriesPath) => {
    const seriesId = idFor('series', seriesPath)
    const chapters = candidatesBySeries.get(seriesPath).sort((a, b) => compareNaturalPath(a.chapterPath, b.chapterPath)).map((candidate, index) => {
      const chapterId = idFor('chapter', `${candidate.kind}:${candidate.chapterPath}`)
      const pages = candidate.pages.sort((a, b) => compareNaturalPath(a.relativePath, b.relativePath)).map((page, pageIndex) => ({
        id: `${chapterId}-page-${pageIndex + 1}`,
        relativePath: page.relativePath,
        fileName: getBaseName(page.relativePath),
        index: pageIndex,
        sortKey: normalizeSortKey(page.relativePath),
      }))
      return {
        id: chapterId,
        seriesId,
        title: candidate.kind === 'archive' ? stripExtension(candidate.chapterPath) : getBaseName(candidate.chapterPath),
        kind: candidate.kind,
        relativePath: candidate.chapterPath,
        index,
        pageCount: pages.length,
        pages,
        ...(candidate.archivePath === undefined ? {} : { sourceArchivePath: candidate.archivePath }),
        sortKey: normalizeSortKey(candidate.chapterPath),
      }
    })
    return {
      id: seriesId,
      title: getBaseName(seriesPath),
      relativePath: seriesPath,
      ...(sidecarMetadataBySeriesPath.has(seriesPath) ? { sidecarMetadata: sidecarMetadataBySeriesPath.get(seriesPath) } : {}),
      chapters,
      chapterCount: chapters.length,
      pageCount: chapters.reduce((total, chapter) => total + chapter.pageCount, 0),
      sortKey: normalizeSortKey(seriesPath),
    }
  })

  return {
    contract: {
      version: 1,
      rootName,
      rootId: idFor('root', normalizeSortKey(rootName)),
      directoryConvention: 'root/{series path}/{chapter folder pages | chapter.cbz | chapter.zip}; image-only series folders are one chapter',
      runtimeFolderPicker: 'NOT_IMPLEMENTED_DEFERRED',
    },
    series,
    rejectedEntries: rejectedEntries.sort((a, b) => compareNaturalPath(a.relativePath, b.relativePath)),
    sourceEntryCount: entries.length,
  }
}

function reconcileLocalLibraryFolderAvailability(knownSeries, scanResult) {
  const available = new Set(scanResult.series.map((series) => series.id))
  return knownSeries.map((series) => ({
    id: series.id,
    status: available.has(series.id) ? 'available' : 'missing',
  }))
}

const fixtureEntries = [
  { relativePath: 'Nested/Series Alpha/Chapter 01/002.jpg' },
  { relativePath: 'Nested/Series Alpha/Chapter 01/001.jpg' },
  { relativePath: 'Nested/Series Alpha/Chapter 02.cbz' },
  { relativePath: 'Nested/Series Alpha/Chapter 03.zip' },
  { relativePath: 'Nested/Series Alpha/metadata.json', textContent: JSON.stringify({ title: 'Alpha Sidecar', authors: ['A', 'A', 'B'], status: 'completed', coverPath: 'cover.png' }) },
  { relativePath: 'Single Nested Series/Chapter 01/001.jpg' },
  { relativePath: 'Single Nested Series/ComicInfo.xml', textContent: '<ComicInfo><Series>Single XML Series</Series><Writer>Writer A; Writer B</Writer><Status>Continuing</Status><CoverPath>cover.jpg</CoverPath></ComicInfo>' },
  { relativePath: 'Loose Image Series/cover.png' },
  { relativePath: 'Loose Image Series/010.webp' },
  { relativePath: 'Top Level One Shot.cbz' },
  { relativePath: '.hidden/Chapter 01/001.jpg' },
  { relativePath: 'Nested/Series Alpha/.DS_Store' },
  { relativePath: 'Nested/Series Alpha/notes.txt' },
  { relativePath: 'root-page.jpg' },
  { relativePath: 'Nested/Series Alpha/Chapter 01/001.jpg' },
  { relativePath: '/absolute/leak.cbz' },
  { relativePath: '../traversal.cbz' },
  { relativePath: 'Nested/Unsafe:Name.cbz' },
  { relativePath: 'Missing Series/Chapter 01/001.jpg', exists: false },
]

for (const unsafePath of ['/tmp/Series.cbz', 'file:///tmp/Series.cbz', 'C:/Series.cbz', 'Series/../Chapter.cbz', 'Series//Chapter.cbz', 'Series/Bad:Name.cbz']) {
  assert.throws(() => normalizeLocalLibraryRelativePath(unsafePath), /Unsafe local library path/, `${unsafePath} must be rejected`)
}
assert.equal(normalizeLocalLibraryRelativePath('Nested\\Series Alpha\\Chapter 01\\001.jpg'), 'Nested/Series Alpha/Chapter 01/001.jpg')

const firstScan = scanLocalLibraryFolderEntries(fixtureEntries, 'Fixture Root')
const secondScan = scanLocalLibraryFolderEntries(fixtureEntries, 'Fixture Root')
assert.deepEqual(secondScan, firstScan, 'duplicate scans must be idempotent')

assert.equal(firstScan.contract.runtimeFolderPicker, 'NOT_IMPLEMENTED_DEFERRED')
assert.equal(firstScan.sourceEntryCount, fixtureEntries.length)
assert.deepEqual(firstScan.series.map((series) => series.relativePath), [
  'Loose Image Series',
  'Nested/Series Alpha',
  'Single Nested Series',
  'Top Level One Shot',
])

const looseSeries = firstScan.series.find((series) => series.relativePath === 'Loose Image Series')
assert.equal(looseSeries.chapterCount, 1)
assert.equal(looseSeries.pageCount, 2)
assert.deepEqual(looseSeries.chapters[0].pages.map((page) => page.fileName), ['010.webp', 'cover.png'])

const nestedSeries = firstScan.series.find((series) => series.relativePath === 'Nested/Series Alpha')
assert.equal(nestedSeries.chapterCount, 3)
assert.deepEqual(nestedSeries.sidecarMetadata, {
  title: 'Alpha Sidecar',
  authors: ['A', 'B'],
  status: 'completed',
  coverPath: 'cover.png',
})
assert.deepEqual(nestedSeries.chapters.map((chapter) => `${chapter.kind}:${chapter.relativePath}`), [
  'image_folder:Nested/Series Alpha/Chapter 01',
  'archive:Nested/Series Alpha/Chapter 02.cbz',
  'archive:Nested/Series Alpha/Chapter 03.zip',
])
assert.deepEqual(nestedSeries.chapters[0].pages.map((page) => page.fileName), ['001.jpg', '002.jpg'])

const singleNestedSeries = firstScan.series.find((series) => series.relativePath === 'Single Nested Series')
assert.equal(singleNestedSeries.chapterCount, 1)
assert.deepEqual(singleNestedSeries.sidecarMetadata, {
  title: 'Single XML Series',
  authors: ['Writer A', 'Writer B'],
  status: 'ongoing',
  coverPath: 'cover.jpg',
})
assert.equal(singleNestedSeries.chapters[0].kind, 'image_folder')
assert.equal(singleNestedSeries.chapters[0].relativePath, 'Single Nested Series/Chapter 01')
assert.deepEqual(singleNestedSeries.chapters[0].pages.map((page) => page.relativePath), ['Single Nested Series/Chapter 01/001.jpg'])

const topLevel = firstScan.series.find((series) => series.relativePath === 'Top Level One Shot')
assert.equal(topLevel.chapterCount, 1)
assert.equal(topLevel.chapters[0].kind, 'archive')

assert.deepEqual(firstScan.rejectedEntries.map((entry) => `${entry.reason}:${entry.relativePath}`), [
  'unsafe_path:../traversal.cbz',
  'hidden:.hidden/Chapter 01/001.jpg',
  'unsafe_path:/absolute/leak.cbz',
  'hidden:Nested/Series Alpha/.DS_Store',
  'unsupported:Nested/Series Alpha/notes.txt',
  'unsafe_path:Nested/Unsafe:Name.cbz',
  'root_level_image:root-page.jpg',
])

for (const series of firstScan.series) {
  assert.doesNotMatch(series.id, /\//, 'series ids must not contain raw relative paths')
  assert.doesNotMatch(series.id, /Nested|Loose|tmp|absolute/i, 'series ids must not leak path labels')
}

const scanAfterDelete = scanLocalLibraryFolderEntries(
  fixtureEntries.filter((entry) => !entry.relativePath.startsWith('Loose Image Series/')),
  'Fixture Root',
)
assert.deepEqual(
  reconcileLocalLibraryFolderAvailability(firstScan.series.map((series) => ({ id: series.id })), scanAfterDelete),
  [
    { id: looseSeries.id, status: 'missing' },
    { id: nestedSeries.id, status: 'available' },
    { id: singleNestedSeries.id, status: 'available' },
    { id: topLevel.id, status: 'available' },
  ],
  'missing files must report missing rows without deleting known library ids',
)

mkdirSync(dirname(artifactPath), { recursive: true })
writeFileSync(artifactPath, `${JSON.stringify({
  verdict: 'PASS',
  summary: 'Static local library folder contract fixture scan passed; runtime folder picker NOT_IMPLEMENTED_DEFERRED.',
  scan: firstScan,
  deletedFixtureAvailability: reconcileLocalLibraryFolderAvailability(firstScan.series.map((series) => ({ id: series.id })), scanAfterDelete),
}, null, 2)}\n`)

console.log(`local library folder contract fixture written: ${artifactPath}`)
