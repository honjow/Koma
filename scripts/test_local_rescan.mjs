import assert from 'node:assert/strict'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { performance } from 'node:perf_hooks'

const root = resolve(import.meta.dirname, '..')
const contractPath = resolve(root, 'entry/src/main/ets/model/LocalLibraryFolderContract.ets')
const servicePath = resolve(root, 'entry/src/main/ets/model/LocalLibraryRescanService.ets')
const libraryPersistencePath = resolve(root, 'entry/src/main/ets/model/LibraryPersistence.ets')
const artifactPath = resolve(root, '.hermes-artifacts/20260527-d43-local-rescan/local-rescan-fixture.json')
const serviceSource = readFileSync(servicePath, 'utf8')
const contractSource = readFileSync(contractPath, 'utf8')
const libraryPersistenceSource = readFileSync(libraryPersistencePath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(serviceSource, 'LOCAL_LIBRARY_RESCAN_CONTRACT_VERSION')
assertExport(serviceSource, 'LOCAL_LIBRARY_RESCAN_UI_MUTATION_CONTRACT')
assertExport(serviceSource, 'LOCAL_LIBRARY_RESCAN_DESTRUCTIVE_ACTION_CONTRACT')
assertExport(serviceSource, 'LocalLibraryRescanFailure')
assertExport(serviceSource, 'LocalLibraryRescanSummary')
assertExport(serviceSource, 'createLocalLibraryRescanSummary')
assertExport(serviceSource, 'LocalLibraryRescanService')
assert.match(serviceSource, /LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS/, 'rescan must inherit honest D42 runtime picker status')
assert.match(serviceSource, /MODEL_ONLY_NO_SYNC_UI_MUTATION/, 'rescan summary must be producible without synchronous UI mutation')
assert.match(serviceSource, /NO_DELETE_LIBRARY_ROWS_OR_USER_FILES/, 'rescan contract must forbid destructive cleanup')
assert.match(serviceSource, /removedCount:\s*missingCount/, 'removed-from-scan must be represented as missing, not destructive deletion')
assert.doesNotMatch(serviceSource, /unlink|rmdir|removeComputed|deleteFile|deleteComic|removeComic|upsertComic|LibraryStore|fileIo|fs\./, 'rescan service must not delete files or mutate library persistence')
assert.match(contractSource, /LOCAL_LIBRARY_FOLDER_RUNTIME_PICKER_STATUS = 'BEST_EFFORT_DOCUMENT_PICKER'/, 'D42 picker persistence must advertise the best-effort document picker path')
assert.match(
  libraryPersistenceSource,
  /mergeLocalLibraryRescanComic\(previous: Comic \| undefined, fresh: Comic\)[\s\S]*createdAt: previous\.createdAt[\s\S]*const categoryIds = normalizeCategoryIds\(previous\.categoryIds\)[\s\S]*if \(categoryIds\.length > 0\) \{[\s\S]*merged\.categoryIds = categoryIds[\s\S]*libraryStore\.upsertComic\(mergeLocalLibraryRescanComic\(libraryStore\.getComic\(comic\.id\), comic\)\)/,
  'rescan persistence must preserve existing shelf category membership and createdAt while refreshing scanned local folder metadata',
)

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

function isExplicitImageChapterFolderName(path) {
  return /^(chapter|chap|ch|episode|ep|volume|vol|book)\b/i.test(getBaseName(path))
}

function scanLocalLibraryFolderEntries(entries, rootName = 'Local Library') {
  const rejectedEntries = []
  const seen = new Set()
  const imageFolders = new Map()
  const archiveEntries = []

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

function textCompare(left, right) {
  return left.localeCompare(right)
}

function chapterSignature(chapter) {
  return [
    chapter.kind,
    chapter.relativePath,
    String(chapter.pageCount),
    chapter.pages.map((page) => page.relativePath).slice().sort(textCompare).join('|'),
  ].join('\n')
}

function sidecarMetadataSignature(series) {
  const metadata = series.sidecarMetadata
  if (metadata === undefined) {
    return ''
  }
  return [
    metadata.title ?? '',
    (metadata.authors ?? []).slice().sort(textCompare).join('|'),
    metadata.status ?? '',
    metadata.coverPath ?? '',
  ].join('\n')
}

function seriesSignature(series) {
  return [
    series.relativePath,
    sidecarMetadataSignature(series),
    String(series.chapterCount),
    String(series.pageCount),
    series.chapters.map(chapterSignature).slice().sort(textCompare).join('\n--chapter--\n'),
  ].join('\n')
}

function buildChapterOutcomes(previousChapters, currentChapters) {
  const previousById = new Map(previousChapters.map((chapter) => [chapter.id, chapter]))
  const currentById = new Map(currentChapters.map((chapter) => [chapter.id, chapter]))
  const outcomes = []
  for (const previous of previousChapters) {
    const current = currentById.get(previous.id)
    outcomes.push(current === undefined
      ? { id: previous.id, status: 'missing', previousRelativePath: previous.relativePath, previousPageCount: previous.pageCount, currentPageCount: 0 }
      : {
          id: previous.id,
          status: chapterSignature(previous) === chapterSignature(current) ? 'unchanged' : 'changed',
          previousRelativePath: previous.relativePath,
          currentRelativePath: current.relativePath,
          previousPageCount: previous.pageCount,
          currentPageCount: current.pageCount,
        })
  }
  for (const current of currentChapters) {
    if (!previousById.has(current.id)) {
      outcomes.push({ id: current.id, status: 'added', currentRelativePath: current.relativePath, previousPageCount: 0, currentPageCount: current.pageCount })
    }
  }
  return outcomes.sort((a, b) => textCompare(a.previousRelativePath ?? a.currentRelativePath ?? a.id, b.previousRelativePath ?? b.currentRelativePath ?? b.id))
}

function buildSeriesOutcome(previous, current) {
  const chapters = buildChapterOutcomes(previous?.chapters ?? [], current?.chapters ?? [])
  const metadataChanged = previous !== undefined && current !== undefined &&
    sidecarMetadataSignature(previous) !== sidecarMetadataSignature(current)
  const status = previous === undefined
    ? 'added'
    : current === undefined
      ? 'missing'
      : seriesSignature(previous) === seriesSignature(current)
        ? 'unchanged'
        : 'changed'
  return {
    id: previous?.id ?? current?.id ?? '',
    title: current?.title ?? previous?.title ?? '',
    status,
    previousRelativePath: previous?.relativePath,
    currentRelativePath: current?.relativePath,
    previousChapterCount: previous?.chapterCount ?? 0,
    currentChapterCount: current?.chapterCount ?? 0,
    previousPageCount: previous?.pageCount ?? 0,
    currentPageCount: current?.pageCount ?? 0,
    addedChapterCount: chapters.filter((chapter) => chapter.status === 'added').length,
    missingChapterCount: chapters.filter((chapter) => chapter.status === 'missing').length,
    changedChapterCount: chapters.filter((chapter) => chapter.status === 'changed').length,
    unchangedChapterCount: chapters.filter((chapter) => chapter.status === 'unchanged').length,
    metadataChanged,
    chapters,
  }
}

function createLocalLibraryRescanSummary(previousKnownSeries, freshScan, failures = []) {
  const previousById = new Map(previousKnownSeries.map((series) => [series.id, series]))
  const currentById = new Map(freshScan.series.map((series) => [series.id, series]))
  const outcomes = []
  for (const previous of previousKnownSeries) {
    outcomes.push(buildSeriesOutcome(previous, currentById.get(previous.id)))
  }
  for (const current of freshScan.series) {
    if (!previousById.has(current.id)) {
      outcomes.push(buildSeriesOutcome(undefined, current))
    }
  }
  outcomes.sort((a, b) => textCompare(a.previousRelativePath ?? a.currentRelativePath ?? a.id, b.previousRelativePath ?? b.currentRelativePath ?? b.id))
  const missingCount = outcomes.filter((outcome) => outcome.status === 'missing').length
  const missingChapterCount = outcomes.reduce((total, outcome) => total + outcome.missingChapterCount, 0)
  return {
    contractVersion: 1,
    runtimeFolderPicker: 'NOT_IMPLEMENTED_DEFERRED',
    uiMutationContract: 'MODEL_ONLY_NO_SYNC_UI_MUTATION',
    destructiveActionContract: 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES',
    previousSeriesCount: previousKnownSeries.length,
    currentSeriesCount: freshScan.series.length,
    addedCount: outcomes.filter((outcome) => outcome.status === 'added').length,
    removedCount: missingCount,
    missingCount,
    changedCount: outcomes.filter((outcome) => outcome.status === 'changed').length,
    unchangedCount: outcomes.filter((outcome) => outcome.status === 'unchanged').length,
    addedChapterCount: outcomes.reduce((total, outcome) => total + outcome.addedChapterCount, 0),
    removedChapterCount: missingChapterCount,
    missingChapterCount,
    changedChapterCount: outcomes.reduce((total, outcome) => total + outcome.changedChapterCount, 0),
    unchangedChapterCount: outcomes.reduce((total, outcome) => total + outcome.unchangedChapterCount, 0),
    metadataChangedCount: outcomes.filter((outcome) => outcome.metadataChanged).length,
    rejectedEntryCount: freshScan.rejectedEntries.length,
    partialFailureCount: failures.filter((failure) => failure.status === 'partial_failure').length,
    outcomes,
    rejectedEntries: freshScan.rejectedEntries.slice().sort((a, b) => textCompare(a.relativePath, b.relativePath)),
    failures: failures.slice().sort((a, b) => textCompare(a.reason, b.reason)),
  }
}

const previousEntries = [
  ...Array.from({ length: 120 }, (_, index) => ({ relativePath: `Large Fixture/Chapter ${String(index + 1).padStart(3, '0')}.cbz` })),
  { relativePath: 'Image Fixture/Chapter 001/001.jpg' },
  { relativePath: 'Image Fixture/Chapter 001/002.jpg' },
  { relativePath: 'Image Fixture/Chapter 002/001.jpg' },
  { relativePath: 'Image Fixture/Chapter 002/002.jpg' },
  { relativePath: 'Rename Fixture/Old Path.cbz' },
  { relativePath: 'Missing Fixture/Chapter 001.cbz' },
]
const currentEntries = [
  ...previousEntries.filter((entry) => entry.relativePath !== 'Missing Fixture/Chapter 001.cbz' && entry.relativePath !== 'Image Fixture/Chapter 001/002.jpg' && entry.relativePath !== 'Rename Fixture/Old Path.cbz'),
  { relativePath: 'Large Fixture/Chapter 121.cbz' },
  { relativePath: 'New Fixture/Chapter 001.cbz' },
  { relativePath: 'Rename Fixture/New Path.cbz' },
  { relativePath: '../unsafe.cbz' },
  { relativePath: 'Large Fixture/notes.txt' },
  { relativePath: '.hidden/Chapter 001.cbz' },
]

const previousScan = scanLocalLibraryFolderEntries(previousEntries, 'D43 Fixture Root')
const currentScan = scanLocalLibraryFolderEntries(currentEntries, 'D43 Fixture Root')
assert.equal(previousScan.series.find((series) => series.relativePath === 'Large Fixture').chapterCount, 120, 'fixture must include at least 100 chapter candidates')
previousScan.series.find((series) => series.relativePath === 'Large Fixture').sidecarMetadata = {
  title: 'Large Fixture',
  authors: ['Koma Fixture'],
  status: 'ongoing',
  coverPath: 'Large Fixture/cover-old.jpg',
}
currentScan.series.find((series) => series.relativePath === 'Large Fixture').sidecarMetadata = {
  title: 'Large Fixture Revised',
  authors: ['Koma Fixture'],
  status: 'completed',
  coverPath: 'Large Fixture/cover-new.jpg',
}

const started = performance.now()
const summary = createLocalLibraryRescanSummary(previousScan.series, currentScan, [
  { status: 'partial_failure', reason: 'scan_interrupted', message: 'Folder enumeration stopped after rejected fixture entries' },
  { status: 'deferred', reason: 'runtime_folder_handle', message: 'Persistent runtime folder handles are not implemented' },
])
const runtimeMs = performance.now() - started
const duplicateSummary = createLocalLibraryRescanSummary(previousScan.series, currentScan, [
  { status: 'partial_failure', reason: 'scan_interrupted', message: 'Folder enumeration stopped after rejected fixture entries' },
  { status: 'deferred', reason: 'runtime_folder_handle', message: 'Persistent runtime folder handles are not implemented' },
])

assert.deepEqual(duplicateSummary, summary, 'duplicate rescan summaries must be idempotent')
assert.ok(runtimeMs < 250, `100+ chapter rescan should be non-pathological, took ${runtimeMs}ms`)
assert.equal(summary.runtimeFolderPicker, 'NOT_IMPLEMENTED_DEFERRED')
assert.equal(summary.uiMutationContract, 'MODEL_ONLY_NO_SYNC_UI_MUTATION')
assert.equal(summary.destructiveActionContract, 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES')
assert.equal(summary.previousSeriesCount, 4)
assert.equal(summary.currentSeriesCount, 4)
assert.equal(summary.addedCount, 1)
assert.equal(summary.removedCount, 1)
assert.equal(summary.missingCount, 1)
assert.equal(summary.changedCount, 3)
assert.equal(summary.unchangedCount, 0)
assert.equal(summary.addedChapterCount, 3)
assert.equal(summary.missingChapterCount, 2)
assert.equal(summary.changedChapterCount, 1)
assert.equal(summary.unchangedChapterCount, 121)
assert.equal(summary.metadataChangedCount, 1)
assert.equal(summary.rejectedEntryCount, 3)
assert.equal(summary.partialFailureCount, 1)
assert.deepEqual(summary.rejectedEntries.map((entry) => `${entry.reason}:${entry.relativePath}`), [
  'unsafe_path:../unsafe.cbz',
  'hidden:.hidden/Chapter 001.cbz',
  'unsupported:Large Fixture/notes.txt',
])

const missingFixture = summary.outcomes.find((outcome) => outcome.previousRelativePath === 'Missing Fixture')
assert.equal(missingFixture.status, 'missing')
assert.equal(missingFixture.currentChapterCount, 0, 'partial failure must not erase previous known missing series detail')

const renameFixture = summary.outcomes.find((outcome) => outcome.previousRelativePath === 'Rename Fixture' || outcome.currentRelativePath === 'Rename Fixture')
assert.equal(renameFixture.status, 'changed', 'path rename without stable metadata must be honest missing chapter plus added chapter')
assert.deepEqual(renameFixture.chapters.map((chapter) => `${chapter.status}:${chapter.previousRelativePath ?? chapter.currentRelativePath}`), [
  'added:Rename Fixture/New Path.cbz',
  'missing:Rename Fixture/Old Path.cbz',
])

const imageFixture = summary.outcomes.find((outcome) => outcome.previousRelativePath === 'Image Fixture')
assert.equal(imageFixture.status, 'changed')
assert.deepEqual(imageFixture.chapters.map((chapter) => `${chapter.status}:${chapter.previousRelativePath ?? chapter.currentRelativePath}`), [
  'changed:Image Fixture/Chapter 001',
  'unchanged:Image Fixture/Chapter 002',
])

const largeFixture = summary.outcomes.find((outcome) => outcome.previousRelativePath === 'Large Fixture')
assert.equal(largeFixture.status, 'changed')
assert.equal(largeFixture.addedChapterCount, 1)
assert.equal(largeFixture.unchangedChapterCount, 120)
assert.equal(largeFixture.metadataChanged, true)

mkdirSync(dirname(artifactPath), { recursive: true })
writeFileSync(artifactPath, `${JSON.stringify({
  verdict: 'PASS',
  summary: 'D43 local rescan model fixture passed with 120 archive chapters, idempotence, missing/deleted status, rejected entries, and partial failure recovery.',
  runtimeMs,
  rescan: summary,
}, null, 2)}\n`)

console.log(`local rescan fixture written: ${artifactPath}`)
