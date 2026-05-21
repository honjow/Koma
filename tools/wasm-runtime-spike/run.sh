#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACT_DIR="${KOMA_WASM_SPIKE_ARTIFACT_DIR:-$REPO_ROOT/.hermes-artifacts/wasm-runtime-spike}"
WAMR_TAG="${WAMR_TAG:-WAMR-2.3.0}"
WAMR_COMMIT="${WAMR_COMMIT:-c7b2db18329f849b81568b94e72ddd0b20f431a5}"
WAMR_ROOT_DIR="${WAMR_ROOT_DIR:-$ARTIFACT_DIR/cache/wasm-micro-runtime}"
BUILD_DIR="$ARTIFACT_DIR/build"
LOG_DIR="$ARTIFACT_DIR/logs"
WASM_OUT="$BUILD_DIR/source_fixture.wasm"
HOST_BUILD_DIR="$BUILD_DIR/host"
RUN_LOG="$LOG_DIR/run.log"
JSON_OUT="$ARTIFACT_DIR/search-result.json"

mkdir -p "$BUILD_DIR" "$LOG_DIR" "$(dirname "$WAMR_ROOT_DIR")"
: > "$RUN_LOG"

log() {
  printf '%s\n' "$*" | tee -a "$RUN_LOG"
}

run_logged() {
  log "+ $*"
  "$@" 2>&1 | tee -a "$RUN_LOG"
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "missing required tool: $1"
    exit 20
  fi
}

require_tool clang
require_tool wasm-ld
require_tool cmake
require_tool git

if [[ ! -d "$WAMR_ROOT_DIR/.git" ]]; then
  log "Fetching WAMR $WAMR_TAG into ignored artifact cache: $WAMR_ROOT_DIR"
  run_logged git clone --depth 1 --branch "$WAMR_TAG" \
    https://github.com/bytecodealliance/wasm-micro-runtime.git "$WAMR_ROOT_DIR"
fi

actual_commit="$(git -C "$WAMR_ROOT_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$WAMR_COMMIT" ]]; then
  log "WAMR commit mismatch: expected $WAMR_COMMIT got $actual_commit"
  log "Set WAMR_ROOT_DIR to a clean $WAMR_TAG checkout or remove the cache directory."
  exit 21
fi
log "Using WAMR $WAMR_TAG at $actual_commit"

run_logged clang --target=wasm32 -O2 -nostdlib \
  -Wl,--no-entry \
  -Wl,--export=add \
  -Wl,--export=koma_source_init \
  -Wl,--export=koma_source_search \
  -Wl,--export=koma_source_free \
  -Wl,--export-memory \
  -Wl,--initial-memory=131072 \
  -Wl,--max-memory=131072 \
  -o "$WASM_OUT" "$SCRIPT_DIR/wasm/source_fixture.c"

run_logged cmake -S "$SCRIPT_DIR/host" -B "$HOST_BUILD_DIR" \
  -DWAMR_ROOT_DIR="$WAMR_ROOT_DIR" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
run_logged cmake --build "$HOST_BUILD_DIR" --target koma_wamr_spike --parallel

log "+ $HOST_BUILD_DIR/koma_wamr_spike $WASM_OUT"
"$HOST_BUILD_DIR/koma_wamr_spike" "$WASM_OUT" 2>&1 | tee -a "$RUN_LOG"

search_json="$(sed -n 's/^SEARCH_JSON=//p' "$RUN_LOG" | tail -n 1)"
if [[ -z "$search_json" ]]; then
  log "missing SEARCH_JSON evidence"
  exit 22
fi

if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$search_json" > "$JSON_OUT"
  run_logged python3 -m json.tool "$JSON_OUT"
else
  log "python3 not found; host runner still validated result envelope shape"
fi

log "Spike artifacts:"
log "  wasm: $WASM_OUT"
log "  log: $RUN_LOG"
log "  json: $JSON_OUT"
