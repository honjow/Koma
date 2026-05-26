import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const readerPreferencesStorePath = resolve(root, 'entry/src/main/ets/model/ReaderPreferencesStore.ets')
const readerPagePath = resolve(root, 'entry/src/main/ets/pages/ReaderPage.ets')
const settingsPagePath = resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')

const readerPreferencesStoreSource = readFileSync(readerPreferencesStorePath, 'utf8')
const readerPageSource = readFileSync(readerPagePath, 'utf8')
const settingsPageSource = readFileSync(settingsPagePath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')

assert.match(
  readerPreferencesStoreSource,
  /export type ReaderImageFitMode = 'contain' \| 'fit_width'/,
  'reader preferences must model persisted image fit choices',
)
assert.match(
  readerPreferencesStoreSource,
  /export type ReaderPageGapMode = 'compact' \| 'normal' \| 'wide'/,
  'reader preferences must model persisted page gap choices',
)
assert.match(
  readerPreferencesStoreSource,
  /IMAGE_FIT_MODE_KEY:\s*string = 'reader\.imageFitMode'/,
  'image fit mode must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /TAP_NAVIGATION_ENABLED_KEY:\s*string = 'reader\.tapNavigationEnabled'/,
  'tap navigation setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /PAGE_GAP_MODE_KEY:\s*string = 'reader\.pageGapMode'/,
  'page gap setting must have a stable persistence key',
)
assert.match(
  readerPreferencesStoreSource,
  /DEFAULT_READER_PREFERENCES:[\s\S]*imageFitMode:\s*'contain'[\s\S]*tapNavigationEnabled:\s*true[\s\S]*pageGapMode:\s*'normal'/,
  'new reader settings must default to current contain fit, enabled tap navigation, and normal spacing',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderImageFitMode\(value: string\)[\s\S]*value === 'fit_width'[\s\S]*return 'contain'/,
  'image fit loading must be backward-compatible with missing or invalid saved values',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderTapNavigationEnabled\(value: boolean \| string \| number\)[\s\S]*value === false[\s\S]*return false[\s\S]*return true/,
  'tap navigation loading must default to enabled for older preference stores',
)
assert.match(
  readerPreferencesStoreSource,
  /normalizeReaderPageGapMode\(value: string\)[\s\S]*value === 'compact' \|\| value === 'wide'[\s\S]*return 'normal'/,
  'page gap loading must be backward-compatible with missing or invalid saved values',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(IMAGE_FIT_MODE_KEY, DEFAULT_READER_PREFERENCES\.imageFitMode\)/,
  'reader preferences load must read persisted image fit mode',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(TAP_NAVIGATION_ENABLED_KEY, DEFAULT_READER_PREFERENCES\.tapNavigationEnabled\)/,
  'reader preferences load must read persisted tap navigation setting',
)
assert.match(
  readerPreferencesStoreSource,
  /store\.get\(PAGE_GAP_MODE_KEY, DEFAULT_READER_PREFERENCES\.pageGapMode\)/,
  'reader preferences load must read persisted page gap setting',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveImageFitMode\(imageFitMode: ReaderImageFitMode\)/,
  'reader preferences store must persist image fit mode independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async saveTapNavigationEnabled\(tapNavigationEnabled: boolean\)/,
  'reader preferences store must persist tap navigation independently',
)
assert.match(
  readerPreferencesStoreSource,
  /async savePageGapMode\(pageGapMode: ReaderPageGapMode\)/,
  'reader preferences store must persist page gap independently',
)

assert.match(settingsPageSource, /key: 'reader-image-fit', title: '图片适配'/, 'Settings must expose an image fit row')
assert.match(settingsPageSource, /key: 'reader-tap-navigation', title: '点击翻页'/, 'Settings must expose a tap navigation row')
assert.match(settingsPageSource, /key: 'reader-page-gap', title: '页面间距'/, 'Settings must expose a page gap row')
assert.match(settingsPageSource, /showReaderImageFitSheet\(\)[\s\S]*title: '适合屏幕'[\s\S]*title: '适合宽度'/, 'image fit sheet must expose contain and fit-width choices')
assert.match(settingsPageSource, /showReaderTapNavigationSheet\(\)[\s\S]*title: '开启'[\s\S]*title: '关闭'/, 'tap navigation sheet must expose on/off choices')
assert.match(settingsPageSource, /showReaderPageGapSheet\(\)[\s\S]*title: '紧凑'[\s\S]*title: '标准'[\s\S]*title: '宽松'/, 'page gap sheet must expose compact, normal, and wide choices')

assert.match(
  readerPageSource,
  /imageFitMode = preferences\.imageFitMode[\s\S]*tapNavigationEnabled = preferences\.tapNavigationEnabled[\s\S]*pageGapMode = preferences\.pageGapMode/,
  'ReaderPage must apply persisted advanced settings after load',
)
assert.match(
  readerPageSource,
  /objectFit\(this\.imageFit\)[\s\S]*imageFit: this\.imageObjectFit\(\)/,
  'ReaderPage image rendering must use the persisted fit mode',
)
assert.match(
  readerPageSource,
  /private imageObjectFit\(\): ImageFit\s*\{[\s\S]*return ImageFit\.Contain[\s\S]*\}/,
  'ReaderPage image fit must use non-cropping contain semantics',
)
assert.doesNotMatch(
  readerPageSource,
  /imageObjectFit\(\): ImageFit[\s\S]*ImageFit\.Cover/,
  'fit-width must not map to crop-prone ImageFit.Cover',
)
assert.match(
  readerPageSource,
  /private singlePageWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '96%'[\s\S]*return '82%'/,
  'single-page fit-width must visibly use more reader width than the default contain width',
)
assert.match(
  readerPageSource,
  /private singlePageMaxWidth\(\): number[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return 720[\s\S]*return 430/,
  'single-page fit-width must raise the max card width without changing object-fit to cover',
)
assert.match(
  readerPageSource,
  /private dualPageSlotWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '96%'[\s\S]*return '88%'/,
  'dual-page slots must widen for fit-width',
)
assert.match(
  readerPageSource,
  /private webtoonPageWidth\(\): string[\s\S]*this\.imageFitMode === 'fit_width'[\s\S]*return '94%'[\s\S]*return '76%'/,
  'webtoon page width must depend on imageFitMode instead of staying fixed at 76%',
)
assert.match(
  readerPageSource,
  /\.width\(this\.singlePageWidth\(\)\)[\s\S]*\.constraintSize\(\{ maxWidth: this\.singlePageMaxWidth\(\) \}\)/,
  'single-page reader must apply the setting-dependent page card width functions',
)
assert.match(
  readerPageSource,
  /\.width\(this\.webtoonPageWidth\(\)\)[\s\S]*\.constraintSize\(\{ maxWidth: this\.webtoonPageMaxWidth\(\) \}\)/,
  'webtoon reader must apply the setting-dependent page width functions',
)
assert.match(
  readerPageSource,
  /private pageGapSpace\(\): number[\s\S]*this\.pageGapMode === 'compact'[\s\S]*this\.pageGapMode === 'wide'[\s\S]*return 18/,
  'ReaderPage must map page gap setting to visible spacing',
)
assert.match(
  readerPageSource,
  /List\(\{ space: this\.pageGapSpace\(\), initialIndex: this\.pageIndex, scroller: this\.webtoonScroller \}\)/,
  'webtoon reader must visibly apply the page gap setting',
)
assert.match(
  readerPageSource,
  /Row\(\{ space: this\.pageGapSpace\(\) \}\)/,
  'dual-page reader must visibly apply the page gap setting',
)
assert.match(
  readerPageSource,
  /private tapLeftZone\(\): void \{[\s\S]*if \(!this\.tapNavigationEnabled\) \{[\s\S]*this\.toggleChrome\(\)[\s\S]*return[\s\S]*this\.previousPage\(\)/,
  'left tap zone must respect the tap navigation setting without breaking chrome toggling',
)
assert.match(
  readerPageSource,
  /private tapRightZone\(\): void \{[\s\S]*if \(!this\.tapNavigationEnabled\) \{[\s\S]*this\.toggleChrome\(\)[\s\S]*return[\s\S]*this\.nextPage\(\)/,
  'right tap zone must respect the tap navigation setting without breaking chrome toggling',
)
assert.match(
  readerPageSource,
  /private tapEdgeZoneWidth\(\): string[\s\S]*this\.tapNavigationEnabled[\s\S]*return '18%'[\s\S]*return '0%'/,
  'tap navigation must use narrower explicit edge zones when enabled and ordinary full-surface chrome toggling when disabled',
)
assert.match(
  readerPageSource,
  /private TapNavigationOverlay\(\)[\s\S]*\.width\(this\.tapEdgeZoneWidth\(\)\)[\s\S]*\.layoutWeight\(1\)[\s\S]*\.width\(this\.tapEdgeZoneWidth\(\)\)/,
  'tap overlay must size only the center with layout weight and keep left/right as explicit edge zones',
)
assert.doesNotMatch(
  readerPageSource,
  /Row\(\) \{\s*Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?Column\(\)[\s\S]*?\.layoutWeight\(1\)[\s\S]*?this\.tapRightZone\(\)/,
  'tap overlay must not use three equal full-height layoutWeight(1) columns for left/center/right',
)

assert.match(
  backupServiceSource,
  /imageFitMode:\s*settings\.imageFitMode \?\? DEFAULT_READER_PREFERENCES\.imageFitMode[\s\S]*tapNavigationEnabled:\s*settings\.tapNavigationEnabled \?\? DEFAULT_READER_PREFERENCES\.tapNavigationEnabled[\s\S]*pageGapMode:\s*settings\.pageGapMode \?\? DEFAULT_READER_PREFERENCES\.pageGapMode/,
  'backup import must preserve backward compatibility while restoring advanced reader settings',
)

console.log('reader settings static tests passed')
