import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const releaseScript = readFileSync(resolve(root, 'scripts/build_release_artifact.sh'), 'utf8')
const publicBuildProfile = readFileSync(resolve(root, 'build-profile.github.json5'), 'utf8')
const appProfile = readFileSync(resolve(root, 'AppScope/app.json5'), 'utf8')

assert.match(
  releaseScript,
  /-p "product=\$product"[\s\S]*-p "buildMode=\$build_mode"[\s\S]*-p "module=\$module"[\s\S]*assembleHap/,
  'release artifact script must pass product, buildMode, and module explicitly to hvigor',
)
assert.match(
  releaseScript,
  /scripts\/check-public-build-profile\.sh --head/,
  'release artifact script must verify the tracked public build profile before building',
)
assert.match(
  releaseScript,
  /python3 scripts\/check_i18n_duplicates\.py[\s\S]*python3 scripts\/check_ui_i18n_literals\.py[\s\S]*"\$hvigorw"/,
  'release artifact script must run i18n resource and UI literal gates before building',
)
assert.match(
  releaseScript,
  /target_bundle="\$\{KOMA_BUNDLE_NAME:-com\.honjow\.koma\}"/,
  'release artifact script must default to the unified Koma bundle name',
)
assert.match(
  releaseScript,
  /if \[ "\$bundle_name" != "\$target_bundle" \][\s\S]*expected bundle/,
  'release artifact script must fail when the built HAP bundle name drifts',
)
assert.match(
  releaseScript,
  /if \[ "\$hap_build_mode" != "release" \] \|\| \[ "\$hap_debug" != "false" \]/,
  'release artifact script must reject debug-mode HAPs even when the product directory is release',
)
assert.match(
  releaseScript,
  /Koma-\$\{version_name\}-\$\{version_code\}-\$\{short_sha\}-\$\{product\}-\$\{build_mode\}-signed\.hap/,
  'release artifact names must include app, version, commit, product, build mode, and signing state',
)
assert.match(
  releaseScript,
  /sha256[\s\S]*manifest\.json/,
  'release artifact script must write a manifest with SHA-256 checksums',
)
assert.doesNotMatch(
  publicBuildProfile,
  /signingConfigs|storePassword|keyPassword|\/Users\/|\.p12|\.p7b/,
  'public build profile must not contain local signing material',
)
assert.match(
  appProfile,
  /"bundleName":\s*"com\.honjow\.koma"/,
  'AppScope bundleName must stay unified across debug and release lanes',
)

console.log('release build lane checks PASS')
