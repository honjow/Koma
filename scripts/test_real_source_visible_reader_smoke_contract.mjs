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
  /if \[ "\$phase" = "real-source-visible-reader" \]; then[\s\S]*requires_index="false"/,
  'real source visible reader smoke must not require a source index server',
)
assert.match(
  script,
  /if \[ "\$requires_index" = "true" \] && \[ -z "\$\{KOMA_SOURCE_INDEX_URL:-\}" \]; then[\s\S]*http\.server/,
  'source reader smoke must only start the local index server when the phase needs it',
)

console.log('real source visible reader smoke contract PASS')
