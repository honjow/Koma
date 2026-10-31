const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const file = path.resolve(__dirname, '../entry/src/main/ets/readerLab/KomaReaderPreferenceBridge.ets')
const source = fs.readFileSync(file, 'utf8')
const output = ts.transpileModule(source, { compilerOptions: {
  target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS,
} }).outputText
const exportsBridge = {}
const ReadingDirection = { LEFT_TO_RIGHT: 'left_to_right', RIGHT_TO_LEFT: 'right_to_left', WEBTOON: 'webtoon' }
const normalizeReaderPreferences = value => ({ ...value })
const storeAst = ts.createSourceFile('store.ts', fs.readFileSync(path.resolve(__dirname,
  '../entry/src/main/ets/model/ReaderPreferencesStore.ets'), 'utf8'), ts.ScriptTarget.Latest, true)
const modeExports = {}
new Function('exports', 'ReadingDirection', ts.transpileModule(
  storeAst.statements.find(node => node.name?.text === 'readerModeSelection').getText(storeAst),
  { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText)(modeExports, ReadingDirection)

new Function('exports', 'require', output)(exportsBridge, name => {
  if (name === '../model/ComicModels') return { ReadingDirection }
  if (name === '../model/ReaderPreferencesStore') return { normalizeReaderPreferences, readerModeSelection: modeExports.readerModeSelection }
  if (name === '@reader-kit/core') return {}
  throw new Error(`Unexpected import: ${name}`)
})
const { KomaReaderPreferenceBridge } = exportsBridge

const base = {
  pageMode: 'single_page', readingDirection: ReadingDirection.LEFT_TO_RIGHT,
  themeMode: 'dark', backgroundMode: 'gray', showProgressControls: false,
  keepScreenAwake: false, fullscreen: false, imageFitMode: 'fit_height', imageScalingQuality: 'high',
  showPageNumber: false, pageTurnAnimation: false, autoPageSeconds: 9, preloadPages: 4, preloadWifiOnly: true,
  spreadLayoutMode: 'joined', columnMode: 'odd_left', tapZonePreset: 'kindle', tapZoneInvert: 'both',
  pageGapMode: 'wide', trimPageMarginsEnabled: false, cropStrength: 'strong', superResolutionEnabled: true, superResolutionModel: 'waifu2xPhotoNoise0_2x',
  superResolutionBackend: 'auto', superResolutionMaxHeight: 2000, wideImageMode: 'rotate_wide_pages',
  volumeKeyNavigationEnabled: true, volumeKeyBehavior: 'up_next_down_previous',
}

function policy(overrides = {}) {
  return { layout: 'single', pagingAxis: 'horizontal', direction: 'ltr', spreadLayout: 'joined',
    firstPageAlone: false, splitWidePages: false, rotateWidePages: false, ...overrides }
}

const rotated = KomaReaderPreferenceBridge.applyPolicy(base, policy({ rotateWidePages: true }))
assert.equal(rotated.wideImageMode, 'rotate_wide_pages')

const spread = KomaReaderPreferenceBridge.applyPolicy(base,
  policy({ layout: 'spread', direction: 'rtl', spreadLayout: 'split', firstPageAlone: true }))
assert.equal(spread.pageMode, 'double_page')
assert.equal(spread.readingDirection, ReadingDirection.RIGHT_TO_LEFT)
assert.equal(spread.spreadLayoutMode, 'split')
assert.equal(spread.columnMode, 'even_left')
assert.equal(spread.wideImageMode, 'keep_single')

const vertical = KomaReaderPreferenceBridge.applyPolicy(base, policy({ pagingAxis: 'vertical', splitWidePages: true }))
assert.equal(vertical.pageMode, 'vertical_page')
assert.equal(vertical.readingDirection, ReadingDirection.LEFT_TO_RIGHT)
assert.equal(vertical.wideImageMode, 'split_wide_pages')

const continuous = KomaReaderPreferenceBridge.applyPolicy(base,
  policy({ layout: 'continuous', direction: 'rtl', pagingAxis: 'vertical' }))
assert.equal(continuous.pageMode, 'continuous_scroll')
assert.equal(continuous.readingDirection, base.readingDirection)

for (const key of ['themeMode', 'backgroundMode', 'showProgressControls', 'keepScreenAwake', 'fullscreen',
  'imageFitMode', 'imageScalingQuality', 'showPageNumber', 'pageTurnAnimation', 'autoPageSeconds',
  'preloadPages', 'preloadWifiOnly', 'tapZonePreset', 'tapZoneInvert', 'pageGapMode', 'trimPageMarginsEnabled', 'cropStrength', 'superResolutionEnabled', 'superResolutionModel',
  'superResolutionBackend', 'superResolutionMaxHeight',
  'volumeKeyNavigationEnabled', 'volumeKeyBehavior']) {
  assert.equal(spread[key], base[key], key)
}

const cropped = KomaReaderPreferenceBridge.applyCrop(base, true)
assert.equal(cropped.trimPageMarginsEnabled, true)
assert.equal(cropped.cropStrength, 'strong')
assert.equal(cropped.pageMode, base.pageMode)
assert.equal(cropped.wideImageMode, base.wideImageMode)
assert.equal(base.trimPageMarginsEnabled, false)
console.log('PASS: reader preference policy and crop transformations preserve unrelated values.')
