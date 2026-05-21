#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cpp_file="entry/src/main/cpp/source_runtime_sample.cpp"
cmake_file="entry/src/main/cpp/CMakeLists.txt"
wrapper_file="entry/src/main/ets/sourceRuntime/NativeSourceRuntime.ets"
build_profile="entry/build-profile.json5"

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
  if ! rg -q "$pattern" "$path"; then
    echo "missing pattern '$pattern' in $path" >&2
    exit 1
  fi
}

require_file "$cpp_file"
require_file "$cmake_file"
require_file "$wrapper_file"

require_text "$cpp_file" '#include <napi/native_api.h>'
require_text "$cpp_file" 'napi_module_register'
require_text "$cpp_file" '"hello"'
require_text "$cpp_file" '"add"'
require_text "$cpp_file" '"runJsonCall"'
require_text "$cpp_file" 'napi-sample'

require_text "$cmake_file" 'add_library\(koma_source_runtime SHARED source_runtime_sample.cpp\)'
require_text "$cmake_file" 'libace_napi.z.so'
require_text "$build_profile" '"externalNativeOptions"'
require_text "$build_profile" '"./src/main/cpp/CMakeLists.txt"'

require_text "$wrapper_file" "import nativeRuntime from 'libkoma_source_runtime.so'"
require_text "$wrapper_file" 'class NativeSourceRuntime'
require_text "$wrapper_file" 'JSON.parse'

changed_ui_files="$(git diff --name-only -- entry/src/main/ets/pages entry/src/main/ets/components entry/src/main/ets/model entry/src/main/ets/import entry/src/main/ets/remote entry/src/main/ets/entryability entry/src/main/module.json5)"
if [[ -n "$changed_ui_files" ]]; then
  echo "unexpected product/UI changes:" >&2
  echo "$changed_ui_files" >&2
  exit 1
fi

if git diff --name-only | rg -q '(^|/)(Aidoku|AidokuRunner|aidoku-rs|source-market|marketplace|plugin-market)'; then
  echo "unexpected source marketplace/plugin/Aidoku-shaped path changed" >&2
  exit 1
fi

echo "NAPI source runtime sample static contract OK"
