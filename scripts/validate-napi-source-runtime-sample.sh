#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cpp_file="entry/src/main/cpp/source_runtime_sample.cpp"
cmake_file="entry/src/main/cpp/CMakeLists.txt"
adapter_cpp="entry/src/main/cpp/wasm_runtime_adapter.cpp"
adapter_h="entry/src/main/cpp/wasm_runtime_adapter.h"
wrapper_file="entry/src/main/ets/sourceRuntime/NativeSourceRuntime.ets"
smoke_file="entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets"
entry_ability_file="entry/src/main/ets/entryability/EntryAbility.ets"
build_profile="entry/build-profile.json5"
rawfile_fixture="entry/src/main/resources/rawfile/test/source_runtime_fixture.wasm"
rust_rawfile_fixture="entry/src/main/resources/rawfile/test/rust_source_runtime_fixture.wasm"
archive_fixture="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma-source"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
}

require_text() {
  local path="$1"
  local pattern="$2"
  if ! rg -q -- "$pattern" "$path"; then
    echo "missing pattern '$pattern' in $path" >&2
    exit 1
  fi
}

require_file "$cpp_file"
require_file "$cmake_file"
require_file "$adapter_cpp"
require_file "$adapter_h"
require_file "$wrapper_file"
require_file "$smoke_file"
require_file "$entry_ability_file"
require_file "$rawfile_fixture"
require_file "$rust_rawfile_fixture"
require_file "$archive_fixture"

require_text "$cpp_file" '#include <napi/native_api.h>'
require_text "$cpp_file" 'napi_module_register'
require_text "$cpp_file" '"hello"'
require_text "$cpp_file" '"add"'
require_text "$cpp_file" '"runJsonCall"'
require_text "$cpp_file" '"runJsonCallFromBytes"'
require_text "$cpp_file" 'RunBundledWasmJsonCall'
require_text "$cpp_file" 'RunWasmJsonCallFromBytes'
require_text "$cpp_file" 'napi_get_typedarray_info'

require_text "$adapter_cpp" 'KOMA_ENABLE_WAMR'
require_text "$adapter_cpp" 'wasm_runtime_full_init'
require_text "$adapter_cpp" 'native_module_name = "koma_host"'
require_text "$adapter_cpp" 'NativeSymbol g_komaHostSymbols'
require_text "$adapter_cpp" '"log".*HostLog'
require_text "$adapter_cpp" '"check_cancel".*HostCheckCancel'
require_text "$adapter_cpp" 'wasm_runtime_load'
require_text "$adapter_cpp" 'wasm_runtime_module_dup_data'
require_text "$adapter_cpp" 'LoadWasmBytesFromBundledFixture'
require_text "$adapter_cpp" 'LoadWasmBytesFromExternalBytes'
require_text "$adapter_cpp" 'koma_source_search'
require_text "$adapter_cpp" 'koma_source_free'
require_text "$adapter_cpp" 'kKomaMagic'
require_text "$adapter_cpp" 'WAMR_NOT_BUILT'
require_text "$adapter_cpp" 'koma-host-v0.1'
require_text "$adapter_cpp" 'maxPayloadBytes'

if rg -q 'runtime\\":\\"napi-sample' "$cpp_file" "$adapter_cpp"; then
  echo "runJsonCall still contains the old hardcoded napi-sample response" >&2
  exit 1
fi

require_text "$cmake_file" 'wasm-runtime-spike/wasm/source_fixture.c'
require_text "$cmake_file" 'KOMA_ENABLE_WAMR'
require_text "$cmake_file" 'WAMR_ROOT_DIR'
require_text "$cmake_file" '--allow-undefined'
require_text "$cmake_file" 'WAMR_BUILD_INTERP 1'
require_text "$cmake_file" 'WAMR_BUILD_AOT 0'
require_text "$cmake_file" 'WAMR_BUILD_JIT 0'
require_text "$cmake_file" 'add_library\(koma_source_runtime SHARED'
require_text "$cmake_file" 'libace_napi.z.so'
require_text "$build_profile" '"externalNativeOptions"'
require_text "$build_profile" '"./src/main/cpp/CMakeLists.txt"'

require_text "$wrapper_file" "import nativeRuntime from 'libkoma_source_runtime.so'"
require_text "$wrapper_file" 'class NativeSourceRuntime'
require_text "$wrapper_file" 'JSON.parse'
require_text "$wrapper_file" 'runJsonCallFromBytes'

require_text "$smoke_file" 'maybeRunSourceRuntimeDeviceSmoke'
require_text "$smoke_file" 'NativeSourceRuntime.runJsonCall'
require_text "$smoke_file" 'NativeSourceRuntime.runJsonCallFromBytes'
require_text "$smoke_file" 'getRawFileContentSync'
require_text "$smoke_file" 'test/source_runtime_fixture.wasm'
require_text "$smoke_file" 'test/rust_source_runtime_fixture.wasm'
require_text "$smoke_file" '"query":"fixture"'
require_text "$smoke_file" '"operation":"search"'
require_text "$smoke_file" 'koma-smoke'
require_text "$smoke_file" 'koma-rust-smoke'
require_text "$smoke_file" 'Fixture Series'
require_text "$smoke_file" 'rustSourceResponse'
require_text "$smoke_file" 'rustRawfileBytes'
require_text "$smoke_file" 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT'
require_text "$smoke_file" 'entryability-want-test-only'
require_text "$smoke_file" 'local_source_runtime_fixture.koma-source'
require_text "$smoke_file" 'app-local-source-archive-import-test-only'
require_text "$smoke_file" 'zlib.decompressFile'
require_text "$smoke_file" 'archiveImportOk'
require_text "$smoke_file" 'archiveResponseOk'
require_text "$smoke_file" 'archiveImportedWasmPath'
require_text "$entry_ability_file" 'maybeRunSourceRuntimeDeviceSmoke'
require_text "$entry_ability_file" 'onCreate'
require_text "$entry_ability_file" 'onNewWant'

rawfile_magic="$(od -An -tx1 -N8 "$rawfile_fixture" | tr -d ' \n')"
if [[ "$rawfile_magic" != "0061736d01000000" ]]; then
  echo "rawfile wasm fixture does not start with wasm magic/version: $rawfile_magic" >&2
  exit 1
fi
rawfile_size="$(wc -c < "$rawfile_fixture" | tr -d ' ')"
if (( rawfile_size <= 0 || rawfile_size > 4096 )); then
  echo "rawfile wasm fixture must stay a small test-only fixture, got ${rawfile_size} bytes" >&2
  exit 1
fi
if ! strings "$rawfile_fixture" | rg -q 'Fixture Series|fixture init reached host imports'; then
  echo "rawfile wasm fixture does not contain expected test fixture evidence" >&2
  exit 1
fi

rust_rawfile_magic="$(od -An -tx1 -N8 "$rust_rawfile_fixture" | tr -d ' \n')"
if [[ "$rust_rawfile_magic" != "0061736d01000000" ]]; then
  echo "rust rawfile wasm fixture does not start with wasm magic/version: $rust_rawfile_magic" >&2
  exit 1
fi
rust_rawfile_size="$(wc -c < "$rust_rawfile_fixture" | tr -d ' ')"
if (( rust_rawfile_size <= 0 || rust_rawfile_size > 131072 )); then
  echo "rust rawfile wasm fixture must stay inside the source-package maxWasmBytes test boundary, got ${rust_rawfile_size} bytes" >&2
  exit 1
fi
if ! strings "$rust_rawfile_fixture" | rg -q 'Rust WAMR runtime smoke|rust fixture init reached host imports'; then
  echo "rust rawfile wasm fixture does not contain expected Rust fixture evidence" >&2
  exit 1
fi
if ! strings "$rust_rawfile_fixture" | rg -q '"requestEcho":"fixture"'; then
  echo "rust rawfile wasm fixture does not contain requestEcho fixture evidence" >&2
  exit 1
fi

python3 tools/wasm-runtime-spike/source-package/validate-local-source-archive-fixture.py \
  --archive "$archive_fixture" \
  --artifact-dir "${KOMA_NAPI_SOURCE_RUNTIME_ARTIFACT_DIR:-.hermes-artifacts/napi-source-runtime-static/source-archive-fixture}" >/dev/null

if rg -q 'NativeSourceRuntime\\.(hello|add)' "$smoke_file"; then
  echo "device smoke route must prove runJsonCall, not hello/add sample methods" >&2
  exit 1
fi

if rg -q 'napi-sample|Koma native source runtime sample' "$smoke_file"; then
  echo "device smoke route still references old hardcoded napi sample proof" >&2
  exit 1
fi

changed_ui_files="$(git diff --name-only -- entry/src/main/ets/pages entry/src/main/ets/components entry/src/main/ets/model entry/src/main/ets/import entry/src/main/ets/remote entry/src/main/module.json5)"
if [[ -n "$changed_ui_files" ]]; then
  echo "unexpected product/UI changes:" >&2
  echo "$changed_ui_files" >&2
  exit 1
fi

unexpected_entryability_changes="$(git diff --name-only -- entry/src/main/ets/entryability | rg -v '^entry/src/main/ets/entryability/EntryAbility\.ets$' || true)"
if [[ -n "$unexpected_entryability_changes" ]]; then
  echo "unexpected entryability changes:" >&2
  echo "$unexpected_entryability_changes" >&2
  exit 1
fi

if git diff --name-only | rg -q '(^|/)(Aidoku|AidokuRunner|aidoku-rs|source-market|marketplace|plugin-market)'; then
  echo "unexpected source marketplace/plugin/Aidoku-shaped path changed" >&2
  exit 1
fi

require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_module\("koma_host"\)'
require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_name\("log"\)'
require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_name\("check_cancel"\)'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'native_module_name = "koma_host"'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'HOST_LOG'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'HOST_CHECK_CANCEL'

if git diff --name-only | rg -q '(^|/)(source|sources|market|marketplace|plugin).*(Page|View|Store|Service|Client)\.(ets|ts|cpp)$'; then
  echo "unexpected source management or marketplace-shaped product changes" >&2
  git diff --name-only | rg '(^|/)(source|sources|market|marketplace|plugin).*(Page|View|Store|Service|Client)\.(ets|ts|cpp)$' >&2
  exit 1
fi

echo "NAPI source runtime sample static contract OK"
