import assert from 'node:assert/strict'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { relative, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const artifactDir = resolve(root, '.hermes-artifacts/20260527-d41-reader-qa-matrix')
const resultPath = resolve(artifactDir, 'result.json')
const notesPath = resolve(artifactDir, 'notes.md')
const changedFilesPath = resolve(artifactDir, 'changed-files.txt')
const matrixPath = resolve(artifactDir, 'reader-qa-matrix.json')

const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const readerSettingsTestPath = resolve(root, 'scripts/test_reader_settings.mjs')
const readerProgressTestPath = resolve(root, 'scripts/test_reader_progress.mjs')

const runtimeEvidenceCandidates = [
  {
    id: 'source-reader',
    result: '.hvigor/outputs/source-reader-smoke/source-runtime-smoke-result.json',
    screenshot: '.hvigor/outputs/source-reader-smoke/reader-screen.png',
    layout: '.hvigor/outputs/source-reader-smoke/reader-layout.json',
  },
  {
    id: 'source-download-reader',
    result: '.hvigor/outputs/source-download-reader-smoke/source-runtime-smoke-result.json',
    screenshot: '.hvigor/outputs/source-download-reader-smoke/reader-screen.png',
    layout: '.hvigor/outputs/source-download-reader-smoke/reader-layout.json',
  },
  {
    id: 'source-corrupt-download-reader',
    result: '.hvigor/outputs/source-corrupt-download-reader-smoke/source-runtime-smoke-result.json',
    screenshot: '',
    layout: '',
  },
]

const ReaderMode = Object.freeze({
  SINGLE_PAGE: 'single_page',
  DUAL_PAGE: 'dual_page',
  CONTINUOUS_SCROLL: 'continuous_scroll',
})

const ReadingDirection = Object.freeze({
  LEFT_TO_RIGHT: 'left_to_right',
  RIGHT_TO_LEFT: 'right_to_left',
  WEBTOON: 'webtoon',
})

const ReaderWideImageMode = Object.freeze({
  KEEP_SINGLE: 'keep_single',
  ROTATE_WIDE_PAGES: 'rotate_wide_pages',
  SPLIT_WIDE_PAGES: 'split_wide_pages',
})

const WIDE_ASPECT_RATIO_THRESHOLD = 1.2
const SCRIPT_COMMAND = 'node scripts/test_reader_qa_matrix.mjs'
const MATRIX_GENERATED_AT = '2026-05-27T00:00:00.000Z'

const fixtures = [
  {
    id: 'portrait-page',
    label: 'Portrait page',
    width: 1080,
    height: 1600,
    expectedAspectRatio: 0.675,
    metadataKind: 'image_dimensions',
    uriKind: 'local_image',
  },
  {
    id: 'landscape-wide-page',
    label: 'Landscape wide page',
    width: 1920,
    height: 1080,
    expectedAspectRatio: 1.7778,
    metadataKind: 'image_dimensions',
    uriKind: 'local_image',
  },
  {
    id: 'ultra-wide-panorama',
    label: 'Ultra-wide panorama',
    width: 4096,
    height: 1024,
    expectedAspectRatio: 4,
    metadataKind: 'image_dimensions',
    uriKind: 'local_image',
  },
  {
    id: 'tall-webtoon-strip',
    label: 'Tall webtoon strip',
    width: 1080,
    height: 6000,
    expectedAspectRatio: 0.18,
    metadataKind: 'image_dimensions',
    uriKind: 'local_image',
  },
  {
    id: 'tiny-placeholder',
    label: 'Tiny placeholder',
    width: 1,
    height: 1,
    expectedAspectRatio: 1,
    metadataKind: 'image_dimensions',
    uriKind: 'placeholder_image',
  },
  {
    id: 'empty-metadata-placeholder',
    label: 'Empty placeholder metadata',
    metadataKind: 'missing_dimensions',
    uriKind: 'empty_uri',
  },
  {
    id: 'zero-dimension-error-placeholder',
    label: 'Error placeholder metadata',
    width: 0,
    height: 1080,
    metadataKind: 'invalid_dimensions',
    uriKind: 'error_placeholder',
  },
]

const scenarios = [
  {
    id: 'single-ltr-split',
    readerMode: ReaderMode.SINGLE_PAGE,
    readingDirection: ReadingDirection.LEFT_TO_RIGHT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'single-rtl-split',
    readerMode: ReaderMode.SINGLE_PAGE,
    readingDirection: ReadingDirection.RIGHT_TO_LEFT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'webtoon-ltr-split',
    readerMode: ReaderMode.CONTINUOUS_SCROLL,
    readingDirection: ReadingDirection.LEFT_TO_RIGHT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'webtoon-rtl-split',
    readerMode: ReaderMode.CONTINUOUS_SCROLL,
    readingDirection: ReadingDirection.RIGHT_TO_LEFT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'dual-ltr-no-split',
    readerMode: ReaderMode.DUAL_PAGE,
    readingDirection: ReadingDirection.LEFT_TO_RIGHT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'dual-rtl-no-split',
    readerMode: ReaderMode.DUAL_PAGE,
    readingDirection: ReadingDirection.RIGHT_TO_LEFT,
    wideImageMode: ReaderWideImageMode.SPLIT_WIDE_PAGES,
  },
  {
    id: 'single-ltr-rotate',
    readerMode: ReaderMode.SINGLE_PAGE,
    readingDirection: ReadingDirection.LEFT_TO_RIGHT,
    wideImageMode: ReaderWideImageMode.ROTATE_WIDE_PAGES,
  },
  {
    id: 'webtoon-direction-forces-scroll',
    readerMode: ReaderMode.CONTINUOUS_SCROLL,
    readingDirection: ReadingDirection.WEBTOON,
    wideImageMode: ReaderWideImageMode.KEEP_SINGLE,
  },
]

function hasDimensions(fixture) {
  return fixture.width !== undefined && fixture.height !== undefined && fixture.width > 0 && fixture.height > 0
}

function isWideLandscape(fixture) {
  return hasDimensions(fixture) && fixture.width / fixture.height >= WIDE_ASPECT_RATIO_THRESHOLD
}

function splitSidesForDirection(direction) {
  if (direction === ReadingDirection.RIGHT_TO_LEFT) {
    return ['right', 'left']
  }
  return ['left', 'right']
}

function shouldSplitWideImage({ wideImageMode, readerMode }, fixture) {
  return wideImageMode === ReaderWideImageMode.SPLIT_WIDE_PAGES &&
    readerMode !== ReaderMode.DUAL_PAGE &&
    isWideLandscape(fixture)
}

function shouldRotateWideImage({ wideImageMode }, fixture) {
  return wideImageMode === ReaderWideImageMode.ROTATE_WIDE_PAGES && isWideLandscape(fixture)
}

function renderDecision(fixture) {
  if (fixture.uriKind === 'empty_uri' || fixture.uriKind === 'error_placeholder') {
    return 'error_placeholder'
  }
  return 'image_surface'
}

function createDisplayEntries(scenario, fixture) {
  if (!shouldSplitWideImage(scenario, fixture)) {
    return [{ fixtureId: fixture.id, splitSide: 'none' }]
  }
  return splitSidesForDirection(scenario.readingDirection).map((splitSide) => ({
    fixtureId: fixture.id,
    splitSide,
  }))
}

function createCase(scenario, fixture) {
  const displayEntries = createDisplayEntries(scenario, fixture)
  return {
    id: `${scenario.id}/${fixture.id}`,
    fixtureId: fixture.id,
    readerMode: scenario.readerMode,
    readingDirection: scenario.readingDirection,
    wideImageMode: scenario.wideImageMode,
    expected: {
      hasDimensions: hasDimensions(fixture),
      isWideLandscape: isWideLandscape(fixture),
      renderDecision: renderDecision(fixture),
      shouldSplit: shouldSplitWideImage(scenario, fixture),
      shouldRotate: shouldRotateWideImage(scenario, fixture),
      displayEntryCount: displayEntries.length,
      displayEntries,
      navigationBasis: scenario.readerMode === ReaderMode.SINGLE_PAGE && scenario.wideImageMode === ReaderWideImageMode.SPLIT_WIDE_PAGES
        ? 'display_entries'
        : 'physical_pages',
    },
  }
}

function createMatrix() {
  const cases = scenarios.flatMap((scenario) => fixtures.map((fixture) => createCase(scenario, fixture)))
  const runtimeEvidence = runtimeEvidenceCandidates
    .map((candidate) => ({
      id: candidate.id,
      result: candidate.result,
      screenshot: candidate.screenshot,
      layout: candidate.layout,
      available: existsSync(resolve(root, candidate.result)) &&
        (candidate.screenshot.length === 0 || existsSync(resolve(root, candidate.screenshot))) &&
        (candidate.layout.length === 0 || existsSync(resolve(root, candidate.layout))),
    }))
  return {
    schemaVersion: 1,
    generatedAt: MATRIX_GENERATED_AT,
    source: {
      lane: 'D41 Reader QA matrix',
      threshold: WIDE_ASPECT_RATIO_THRESHOLD,
      productionContract: 'entry/src/main/ets/pages/ReaderPage.ets',
    },
    screenshotCapture: {
      status: runtimeEvidence.some((item) => item.available) ? 'PARTIAL' : 'BLOCKED',
      reason: runtimeEvidence.some((item) => item.available)
        ? 'Existing Pura X reader/source smoke artifacts are linked; wide-split fixture screenshots still require a dedicated capture run.'
        : 'No device screenshot artifacts are available from this static matrix script.',
      fakeScreenshots: false,
      runtimeEvidence,
    },
    staticMatrix: {
      status: 'PASS',
      fixtures,
      scenarios,
      cases,
    },
  }
}

function assertRequiredCoverage(matrix) {
  const fixtureIds = new Set(matrix.staticMatrix.fixtures.map((fixture) => fixture.id))
  const scenarioIds = new Set(matrix.staticMatrix.scenarios.map((scenario) => scenario.id))

  ;[
    'portrait-page',
    'landscape-wide-page',
    'ultra-wide-panorama',
    'tall-webtoon-strip',
    'tiny-placeholder',
    'empty-metadata-placeholder',
    'zero-dimension-error-placeholder',
  ].forEach((id) => assert.equal(fixtureIds.has(id), true, `fixture coverage missing ${id}`))

  ;[
    'single-ltr-split',
    'single-rtl-split',
    'webtoon-ltr-split',
    'webtoon-rtl-split',
    'dual-ltr-no-split',
    'dual-rtl-no-split',
    'single-ltr-rotate',
    'webtoon-direction-forces-scroll',
  ].forEach((id) => assert.equal(scenarioIds.has(id), true, `scenario coverage missing ${id}`))
}

function caseById(matrix, id) {
  const found = matrix.staticMatrix.cases.find((item) => item.id === id)
  assert.notEqual(found, undefined, `matrix case missing ${id}`)
  return found
}

function assertWideSplitContract(matrix) {
  const ltr = caseById(matrix, 'single-ltr-split/landscape-wide-page')
  assert.deepEqual(ltr.expected.displayEntries.map((entry) => entry.splitSide), ['left', 'right'], 'LTR split order must be left/right')
  assert.equal(ltr.expected.navigationBasis, 'display_entries', 'single-page split navigation must use display entries')

  const rtl = caseById(matrix, 'single-rtl-split/landscape-wide-page')
  assert.deepEqual(rtl.expected.displayEntries.map((entry) => entry.splitSide), ['right', 'left'], 'RTL split order must be right/left')
  assert.equal(rtl.expected.navigationBasis, 'display_entries', 'single-page RTL split navigation must use display entries')

  const panorama = caseById(matrix, 'single-ltr-split/ultra-wide-panorama')
  assert.equal(panorama.expected.shouldSplit, true, 'ultra-wide panorama must be eligible for split in single-page mode')
  assert.equal(panorama.expected.displayEntryCount, 2, 'ultra-wide split must duplicate into two display entries')

  const webtoon = caseById(matrix, 'webtoon-ltr-split/landscape-wide-page')
  assert.deepEqual(webtoon.expected.displayEntries.map((entry) => entry.splitSide), ['left', 'right'], 'webtoon matrix must pin split order')

  const dual = caseById(matrix, 'dual-ltr-no-split/landscape-wide-page')
  assert.equal(dual.expected.shouldSplit, false, 'dual-page mode must not split wide pages')
  assert.equal(dual.expected.displayEntryCount, 1, 'dual-page wide page stays one physical page')
  assert.equal(dual.expected.navigationBasis, 'physical_pages', 'dual-page navigation must remain physical-page based')

  const dualRtl = caseById(matrix, 'dual-rtl-no-split/ultra-wide-panorama')
  assert.equal(dualRtl.expected.shouldSplit, false, 'dual-page RTL must not split wide pages')
  assert.deepEqual(dualRtl.expected.displayEntries.map((entry) => entry.splitSide), ['none'], 'dual-page RTL has no split half ordering')
}

function assertFixtureDecisions(matrix) {
  assert.equal(caseById(matrix, 'single-ltr-split/portrait-page').expected.shouldSplit, false, 'portrait pages must not split')
  assert.equal(caseById(matrix, 'single-ltr-split/tall-webtoon-strip').expected.shouldSplit, false, 'tall strips must not split as wide landscape pages')
  assert.equal(caseById(matrix, 'single-ltr-split/tiny-placeholder').expected.shouldSplit, false, 'tiny placeholders must not split')
  assert.equal(caseById(matrix, 'single-ltr-split/empty-metadata-placeholder').expected.hasDimensions, false, 'missing metadata must be explicit')
  assert.equal(caseById(matrix, 'single-ltr-split/empty-metadata-placeholder').expected.renderDecision, 'error_placeholder', 'empty URI uses error placeholder evidence')
  assert.equal(caseById(matrix, 'single-ltr-split/zero-dimension-error-placeholder').expected.hasDimensions, false, 'zero dimensions must fail the metadata gate')
  assert.equal(caseById(matrix, 'single-ltr-rotate/landscape-wide-page').expected.shouldRotate, true, 'rotate mode must remain separate from split mode')
  assert.equal(caseById(matrix, 'single-ltr-split/landscape-wide-page').expected.shouldRotate, false, 'split mode must not also rotate')
}

function assertProductionStaticContracts() {
  const readerPageSource = readFileSync(readerPagePath, 'utf8')
  const readerSettingsTestSource = readFileSync(readerSettingsTestPath, 'utf8')
  const readerProgressTestSource = readFileSync(readerProgressTestPath, 'utf8')

  assert.match(
    readerPageSource,
    /export const READER_WIDE_IMAGE_ASPECT_RATIO_THRESHOLD:\s*number = 1\.2/,
    'production wide threshold must stay pinned to the matrix threshold',
  )
  assert.match(
    readerPageSource,
    /shouldSplitReaderWideImagePage\(mode: ReaderWideImageMode, readerMode: ReaderMode, width: number \| undefined, height: number \| undefined\): boolean \{[\s\S]*mode === 'split_wide_pages' && readerMode !== ReaderMode\.DUAL_PAGE && isReaderWideLandscapePage\(width, height\)/,
    'production split helper must require split mode, non-dual mode, and wide metadata',
  )
  assert.match(
    readerPageSource,
    /readerWidePageSplitSidesForDirection\(direction: ReadingDirection\): ReaderWidePageSplitSide\[\][\s\S]*ReadingDirection\.RIGHT_TO_LEFT[\s\S]*return \['right', 'left'\][\s\S]*return \['left', 'right'\]/,
    'production split helper must preserve LTR and RTL ordering',
  )
  assert.match(
    readerSettingsTestSource,
    /reader-tap-zone-preset[\s\S]*reader_tap_zone_edge[\s\S]*reader_tap_zone_wide[\s\S]*tap zone preset menu/,
    'D40 tap-zone setting UI coverage must remain in reader settings tests',
  )
  assert.match(
    readerSettingsTestSource,
    /tapEdgeZoneWidth[\s\S]*wide_edges[\s\S]*32%[\s\S]*18%/,
    'D40 tap-zone hit-test width coverage must remain in reader settings tests',
  )
  assert.match(
    readerProgressTestSource,
    /splitAwareCanGoPrevious[\s\S]*splitAwareCanGoNext/,
    'reader progress tests must continue covering split-aware navigation',
  )
}

function writeArtifacts(matrix) {
  mkdirSync(artifactDir, { recursive: true })
  writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`)
  writeFileSync(changedFilesPath, 'scripts/test_reader_qa_matrix.mjs\n')
  writeFileSync(notesPath, [
    '# D41 Reader QA Matrix',
    '',
    'Verdict: PASS for generated static matrix.',
    '',
    `Device screenshot capture: ${matrix.screenshotCapture.status}. ${matrix.screenshotCapture.reason}`,
    '',
    `Static matrix cases: ${matrix.staticMatrix.cases.length}.`,
    `Fixtures: ${matrix.staticMatrix.fixtures.map((fixture) => fixture.id).join(', ')}.`,
    '',
    'Evidence:',
    `- ${relative(root, matrixPath)}`,
    ...matrix.screenshotCapture.runtimeEvidence
      .filter((item) => item.available)
      .flatMap((item) => [
        `- ${item.result}`,
        ...(item.screenshot.length > 0 ? [`- ${item.screenshot}`] : []),
        ...(item.layout.length > 0 ? [`- ${item.layout}`] : []),
      ]),
    '- Production split helper/static tests were checked from source.',
    '- Existing D40 tap-zone coverage remains in scripts/test_reader_settings.mjs.',
    '',
  ].join('\n'))

  const result = {
    verdict: 'PASS',
    summary: `Generated deterministic reader QA matrix; device screenshot capture status is ${matrix.screenshotCapture.status}.`,
    changed_files: ['scripts/test_reader_qa_matrix.mjs'],
    commands: [
      {
        command: SCRIPT_COMMAND,
        status: 'pass',
        log: relative(root, notesPath),
      },
    ],
    evidence: [
      relative(root, matrixPath),
      relative(root, notesPath),
      'Static matrix status: PASS',
      `Screenshot capture status: ${matrix.screenshotCapture.status}; no fake screenshots emitted`,
      ...matrix.screenshotCapture.runtimeEvidence
        .filter((item) => item.available)
        .map((item) => item.result),
    ],
    risks: [
      'Dedicated wide-split fixture screenshot capture still needs a device run.',
    ],
    commit: '',
  }
  writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`)
}

const matrix = createMatrix()
assertRequiredCoverage(matrix)
assertWideSplitContract(matrix)
assertFixtureDecisions(matrix)
assertProductionStaticContracts()
writeArtifacts(matrix)

console.log(`reader QA matrix static tests passed: ${relative(root, resultPath)}`)
