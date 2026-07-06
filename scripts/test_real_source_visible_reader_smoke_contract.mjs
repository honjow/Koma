import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const smoke = readFileSync(resolve(root, 'entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets'), 'utf8')
const script = readFileSync(resolve(root, 'scripts/run_source_reader_smoke.sh'), 'utf8')
const localReaderScript = readFileSync(resolve(root, 'scripts/run_local_source_package_reader_smoke.sh'), 'utf8')
const localOfflineScript = readFileSync(resolve(root, 'scripts/run_local_source_package_offline_download_reader_smoke.sh'), 'utf8')

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
  /SMOKE_PHASE_LOCAL_SOURCE_PACKAGE_VISIBLE_OFFLINE_DOWNLOAD_READER: string = 'local-source-package-visible-offline-download-reader'/,
  'device smoke must expose a local source package offline download reader phase',
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
  /SMOKE_PHASE_LOCAL_SOURCE_PACKAGE_VISIBLE_OFFLINE_DOWNLOAD_READER[\s\S]*downloadChapter\(comic, chapterId[\s\S]*ReaderPageRenderKind\.LOCAL_FILE_IMAGE/,
  'local source package offline reader smoke must download a real package chapter and prove the reader resolves a local image',
)
assert.match(
  smoke,
  /fetchAndCacheReaderRemoteSource[\s\S]*sourceIndexReaderRemoteFetchOk[\s\S]*sourceIndexReaderRemoteFetchOk === true/,
  'real source visible reader smoke must prove the reader can fetch/cache the first remote page image',
)
assert.match(
  smoke,
  /operation":"get_pages","mangaId":"\$\{mangaId\}","chapterId":"\$\{chapterId\}"[\s\S]*sourceRuntimeRequest\([\s\S]*'get_pages'[\s\S]*`\{"mangaId":"\$\{mangaId\}","chapterId":"\$\{chapterId\}"\}`/,
  'real and installed source reader smokes must pass mangaId into get_pages so validation matches app page hydration',
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
  /local_source_package_offline_download_visible_phase="local-source-package-visible-offline-download-reader"[\s\S]*requires_index="false"/,
  'local package offline download reader smoke must not require a source index server',
)
assert.match(
  script,
  /local_source_package_visible_phase="local-source-package-visible-reader"[\s\S]*local_source_package_offline_download_visible_phase="local-source-package-visible-offline-download-reader"[\s\S]*KOMA_SOURCE_PACKAGE_PATH[\s\S]*basename "\$source_package_path"/,
  'source reader smoke script must accept a local .koma package path for visible and offline local package phases',
)
assert.match(
  script,
  /source_repo="\$\{KOMA_SOURCES_REPO:-\$repo\/\.\.\/koma-sources\}"[\s\S]*source_build_name="\$\{KOMA_SOURCE_READER_BUILD_SOURCE:-mangadex\}"[\s\S]*build_source_first="\$\{KOMA_SOURCE_READER_BUILD_SOURCE_FIRST:-false\}"[\s\S]*\.\/build\.sh --source "\$source_build_name"/,
  'source reader smoke script must optionally build the local source project before package/index validation',
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
  /aa_start_args=\([\s\S]*--ps koma\.sourceRuntimeSmoke\.packageFile "\$source_package_file"[\s\S]*--ps koma\.sourceRuntimeSmoke\.packageRawfile "\$source_package_rawfile"[\s\S]*hdc_target "\$\{aa_start_args\[@\]\}"/,
  'source reader smoke script must pass package metadata and rawfile path to the app smoke',
)
assert.match(
  script,
  /if \[ -n "\$index_url" \]; then[\s\S]*aa_start_args\+=\(--ps koma\.sourceRuntimeSmoke\.indexUrl "\$index_url"\)[\s\S]*if \[ -n "\$source_package_base64" \]; then[\s\S]*aa_start_args\+=\(--ps koma\.sourceRuntimeSmoke\.packageBase64 "\$source_package_base64"\)/,
  'source reader smoke script must not pass empty aa --ps values for local source package phases',
)
assert.match(
  script,
  /phase in \('local-source-package-visible-reader', 'local-source-package-visible-offline-download-reader'\)[\s\S]*sourceIndexReaderPackageBytes/,
  'source reader smoke script must verify that both local package phases read real package bytes',
)
assert.match(
  script,
  /phase in \('source-index-visible-offline-download-reader', 'local-source-package-visible-offline-download-reader'\)[\s\S]*local_file_image/,
  'source reader smoke script must require local-file reader output for both offline visible phases',
)
assert.match(
  script,
  /python3 - "\$smoke_result" "\$reader_layout" "\$reader_screen"[\s\S]*screen_path\.stat\(\)\.st_size < 500000/,
  'source reader smoke script must accept screenshot evidence when uitest layout omits an Image node',
)
assert.match(
  script,
  /if \[ "\$requires_index" = "true" \] && \[ -z "\$\{KOMA_SOURCE_INDEX_URL:-\}" \]; then[\s\S]*http\.server/,
  'source reader smoke must only start the local index server when the phase needs it',
)
assert.match(
  script,
  /KOMA_HDC_COMMAND_TIMEOUT_SECONDS[\s\S]*subprocess\.run\(cmd, timeout=timeout\)[\s\S]*"\$hdc" kill[\s\S]*"\$hdc" start/,
  'source reader smoke hdc wrapper must timeout hung device commands and restart hdc before retrying',
)
assert.match(
  script,
  /KOMA_HVIGOR_TIMEOUT_SECONDS[\s\S]*source reader smoke failed: hvigor build timed out/,
  'source reader smoke script must bound hung hvigor builds',
)
assert.match(
  localReaderScript,
  /KOMA_SOURCE_READER_PHASE="\$\{KOMA_SOURCE_READER_PHASE:-local-source-package-visible-reader\}"[\s\S]*KOMA_SOURCE_READER_REQUIRES_INDEX="\$\{KOMA_SOURCE_READER_REQUIRES_INDEX:-false\}"/,
  'local source package reader smoke wrapper must default to the no-index local package visible reader phase',
)
assert.match(
  localReaderScript,
  /KOMA_SOURCE_PACKAGE_PATH="\$\{KOMA_SOURCE_PACKAGE_PATH:-\$repo\/\.\.\/koma-sources\/dist\/sources\/mangadex\/mangadex-0\.1\.0\.koma\}"/,
  'local source package reader smoke wrapper must default to the source-project MangaDex package',
)
assert.match(
  localOfflineScript,
  /KOMA_SOURCE_READER_PHASE="\$\{KOMA_SOURCE_READER_PHASE:-local-source-package-visible-offline-download-reader\}"[\s\S]*KOMA_SOURCE_READER_REQUIRES_INDEX="\$\{KOMA_SOURCE_READER_REQUIRES_INDEX:-false\}"/,
  'local source package offline smoke wrapper must default to the no-index local package offline phase',
)
assert.match(
  localOfflineScript,
  /KOMA_SOURCE_PACKAGE_PATH="\$\{KOMA_SOURCE_PACKAGE_PATH:-\$repo\/\.\.\/koma-sources\/dist\/sources\/mangadex\/mangadex-0\.1\.0\.koma\}"/,
  'local source package offline smoke wrapper must default to the source-project MangaDex package',
)

console.log('real source visible reader smoke contract PASS')
