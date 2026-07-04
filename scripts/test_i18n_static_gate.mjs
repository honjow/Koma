import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const gateSource = readFileSync(resolve(root, 'scripts/check_ui_i18n_literals.py'), 'utf8')

assert.match(
  gateSource,
  /SCAN_ROOTS = \[[\s\S]*"pages"[\s\S]*"components"[\s\S]*\]/,
  'UI i18n literal gate must scan ArkUI pages and components',
)
assert.match(
  gateSource,
  /CHINESE_LITERAL_RE[\s\S]*\\u4e00-\\u9fff/,
  'UI i18n literal gate must reject Chinese literals in UI sources',
)
assert.match(
  gateSource,
  /DIRECT_UI_LITERAL_RE[\s\S]*Text[\s\S]*Button[\s\S]*MenuItem[\s\S]*label[\s\S]*placeholder/,
  'UI i18n literal gate must reject direct user-facing UI string literals',
)
assert.match(
  gateSource,
  /ALLOWED_DIRECT_VALUES[\s\S]*"Koma"[\s\S]*"Komga"[\s\S]*"OPDS"[\s\S]*"WebDAV"[\s\S]*"NSFW"/,
  'UI i18n literal gate must keep a narrow allowlist for brands, badges, and symbols',
)
assert.match(
  gateSource,
  /if "\$\{" in stripped:[\s\S]*return True/,
  'UI i18n literal gate must allow dynamic counters and version labels while checking static copy',
)

console.log('i18n static gate checks PASS')
