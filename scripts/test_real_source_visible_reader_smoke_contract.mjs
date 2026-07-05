import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const smoke = readFileSync(resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets'), 'utf8')
const script = readFileSync(resolve(root, 'scripts/run_source_reader_smoke.sh'), 'utf8')

assert.match(
  smoke,
  /SMOKE_PHASE_REAL_SOURCE_VISIBLE_READER: string = 'real-source-visible-reader'/,
  'device smoke must expose a real source visible reader phase',
)
assert.match(
  smoke,
  /SMOKE_PACKAGE_FILE_PARAM: string = 'koma\.sourceRuntimeSmoke\.packageFile'/,
  'device smoke must accept a package file name for local source package reader verification',
)
assert.match(
  smoke,
  /SMOKE_PACKAGE_BASE64_PARAM: string = 'koma\.sourceRuntimeSmoke\.packageBase64'/,
  'device smoke must accept package bytes for local source package reader verification',
)
assert.match(
  smoke,
  /SMOKE_PACKAGE_RAWFILE_PARAM: string = 'koma\.sourceRuntimeSmoke\.packageRawfile'/,
  'device smoke must accept a rawfile package path for source-project smoke packages built into the HAP',
)
assert.match(
  smoke,
  /SMOKE_PHASE_LOCAL_SOURCE_PACKAGE_VISIBLE_READER: string = 'local-source-package-visible-reader'/,
  'device smoke must expose a local source package visible reader phase',
)
assert.match(
  smoke,
  /function decodeSmokeBase64Bytes[\s\S]*buffer\.from\(payload, 'base64'\)[\s\S]*return bytes/,
  'local source package reader smoke must decode package bytes from base64 smoke input',
)
assert.match(
  smoke,
  /SMOKE_PHASE_LOCAL_SOURCE_PACKAGE_VISIBLE_READER[\s\S]*SMOKE_PACKAGE_BASE64_PARAM[\s\S]*SMOKE_PACKAGE_RAWFILE_PARAM[\s\S]*installFromBytes[\s\S]*appSourceRuntimeRegistry\.lookup/,
  'local source package reader smoke must install package bytes and read from the registered source entry',
)
assert.match(
  smoke,
  /fetchAndCacheReaderRemoteSource[\s\S]*sourceIndexReaderRemoteFetchOk[\s\S]*sourceIndexReaderRemoteFetchOk === true/,
  'real source visible reader smoke must prove the reader can fetch/cache the first remote page image',
)
assert.match(
  smoke,
  /registerRealSourceSmokeWasm[\s\S]*name: 'MangaDex'[\s\S]*appSourceRuntimeRegistry\.register/,
  'real source visible reader smoke must register MangaDex bytes for reader image resolution',
)
assert.match(
  smoke,
  /SMOKE_PHASE_REAL_SOURCE_VISIBLE_READER[\s\S]*MANGADEX_RAWFILE_PATH[\s\S]*operation': 'search'|SMOKE_PHASE_REAL_SOURCE_VISIBLE_READER[\s\S]*MANGADEX_RAWFILE_PATH[\s\S]*operation: 'search'/,
  'real source visible reader smoke must search the bundled real source',
)
assert.match(
  smoke,
  /SMOKE_PHASE_REAL_SOURCE_VISIBLE_READER[\s\S]*verifySourceIndexVisibleLibraryReaderSmoke[\s\S]*writeSourceRuntimeSmokeResultFile/,
  'real source visible reader smoke must persist a visible library comic and write result evidence',
)
assert.match(
  script,
  /if \[ "\$phase" = "real-source-visible-reader" \] \|\| \[ "\$phase" = "\$local_source_package_visible_phase" \]; then[\s\S]*requires_index="false"/,
  'real and local package visible reader smokes must not require a source index server',
)
assert.match(
  script,
  /local_source_package_visible_phase="local-source-package-visible-reader"[\s\S]*KOMA_SOURCE_PACKAGE_PATH[\s\S]*basename "\$source_package_path"/,
  'source reader smoke script must accept a local .koma package path',
)
assert.match(
  script,
  /source_package_rawfile="\$\{KOMA_SOURCE_PACKAGE_RAWFILE:-test\/source-smoke-package\.koma\}"/,
  'source reader smoke script must define a temporary rawfile package path',
)
assert.match(
  script,
  /cp "\$source_package_path" "\$source_package_rawfile_path"[\s\S]*temp_source_package_rawfile="\$source_package_rawfile_path"/,
  'source reader smoke script must stage the local .koma package into rawfile before build',
)
assert.match(
  script,
  /rm -f "\$temp_source_package_rawfile"/,
  'source reader smoke script must clean the temporary rawfile package',
)
assert.match(
  script,
  /--ps koma\.sourceRuntimeSmoke\.packageFile "\$source_package_file"[\s\S]*--ps koma\.sourceRuntimeSmoke\.packageRawfile "\$source_package_rawfile"/,
  'source reader smoke script must pass package metadata and rawfile path to the app smoke',
)
assert.match(
  script,
  /if \[ "\$requires_index" = "true" \] && \[ -z "\$\{KOMA_SOURCE_INDEX_URL:-\}" \]; then[\s\S]*http\.server/,
  'source reader smoke must only start the local index server when the phase needs it',
)

console.log('real source visible reader smoke contract PASS')
