import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const appearanceStoreSource = readFileSync(resolve(root, 'entry/src/main/ets/model/AppearancePreferencesStore.ets'), 'utf8')
const settingsPageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/SettingsPage.ets'), 'utf8')
const baseStrings = readFileSync(resolve(root, 'entry/src/main/resources/base/element/string.json'), 'utf8')
const zhStrings = readFileSync(resolve(root, 'entry/src/main/resources/zh_CN/element/string.json'), 'utf8')
const enStrings = readFileSync(resolve(root, 'entry/src/main/resources/en_US/element/string.json'), 'utf8')

assert.match(
  appearanceStoreSource,
  /export type AppearanceAccentColor = 'emerald' \| 'ocean' \| 'rose' \| 'amber' \| 'mono'/,
  'appearance preferences must model bounded accent color choices',
)
assert.match(
  appearanceStoreSource,
  /APPEARANCE_PREFERENCES_STORE_NAME: string = 'koma_appearance_preferences_v1'[\s\S]*ACCENT_COLOR_KEY: string = 'appearance\.accentColor'/,
  'appearance accent choice must have stable preferences storage keys',
)
assert.match(
  appearanceStoreSource,
  /normalizeAppearanceAccentColor\(value: string\): AppearanceAccentColor[\s\S]*value === 'ocean'[\s\S]*return 'emerald'/,
  'appearance accent loading must normalize unsupported values back to emerald',
)
assert.match(
  appearanceStoreSource,
  /saveAccentColor\(accentColor: AppearanceAccentColor\): Promise<AppearancePreferences>[\s\S]*store\.put\(ACCENT_COLOR_KEY, normalized\)[\s\S]*store\.flush\(\)/,
  'appearance accent changes must persist and flush',
)
assert.doesNotMatch(
  settingsPageSource,
  /key: 'theme-color'[^}]*placeholder:\s*true/,
  'Settings theme-color row must not remain a placeholder',
)
assert.match(
  settingsPageSource,
  /AppearancePreferencesStore[\s\S]*appearanceAccentColor: AppearanceAccentColor = DEFAULT_APPEARANCE_PREFERENCES\.accentColor[\s\S]*loadAppearancePreferences\(\)[\s\S]*this\.appearanceAccentColor = preferences\.accentColor/,
  'Settings must load the persisted appearance accent choice',
)
assert.match(
  settingsPageSource,
  /isSelectionRow\(row: SettingsRow\)[\s\S]*row\.key === 'theme-color'/,
  'Settings theme-color must be a real selection row',
)
assert.match(
  settingsPageSource,
  /row\.key === 'theme-color'[\s\S]*appearance_accent_emerald[\s\S]*saveAppearanceAccentColor\('emerald'\)[\s\S]*appearance_accent_ocean[\s\S]*saveAppearanceAccentColor\('ocean'\)[\s\S]*appearance_accent_rose[\s\S]*saveAppearanceAccentColor\('rose'\)[\s\S]*appearance_accent_amber[\s\S]*saveAppearanceAccentColor\('amber'\)[\s\S]*appearance_accent_mono[\s\S]*saveAppearanceAccentColor\('mono'\)/,
  'Settings theme-color menu must expose every bounded accent choice',
)
assert.match(
  settingsPageSource,
  /AccentColorSuffix\(\)[\s\S]*backgroundColor\(getAppearanceAccentColorValue\(this\.appearanceAccentColor\)\)[\s\S]*arrowtriangle_down_fill/,
  'Settings theme-color row must render a swatch suffix instead of plain placeholder text',
)

for (const key of [
  'appearance_accent_emerald',
  'appearance_accent_ocean',
  'appearance_accent_rose',
  'appearance_accent_amber',
  'appearance_accent_mono',
  'settings_theme_color_save_failed',
]) {
  assert.match(baseStrings, new RegExp(`"name": "${key}"`), `base strings must include ${key}`)
  assert.match(zhStrings, new RegExp(`"name": "${key}"`), `zh strings must include ${key}`)
  assert.match(enStrings, new RegExp(`"name": "${key}"`), `en strings must include ${key}`)
}

console.log('appearance preferences static checks passed')
