#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACT_DIR="${KOMA_WASM_SPIKE_ARTIFACT_DIR:-$REPO_ROOT/.hermes-artifacts/wasm-runtime-spike-rust}"
WAMR_TAG="${WAMR_TAG:-WAMR-2.3.0}"
WAMR_COMMIT="${WAMR_COMMIT:-c7b2db18329f849b81568b94e72ddd0b20f431a5}"
WAMR_ROOT_DIR="${WAMR_ROOT_DIR:-$ARTIFACT_DIR/cache/wasm-micro-runtime}"
BUILD_DIR="$ARTIFACT_DIR/build"
LOG_DIR="$ARTIFACT_DIR/logs"
WASM_OUT="$BUILD_DIR/rust_source_fixture.wasm"
HOST_BUILD_DIR="$BUILD_DIR/host"
RUN_LOG="$LOG_DIR/run-rust-fixture.log"
JSON_OUT="$ARTIFACT_DIR/rust-search-result.json"

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

require_tool cmake
require_tool git

if [[ -n "${RUSTC:-}" ]]; then
  RUSTC_CMD=("$RUSTC")
elif command -v rustup >/dev/null 2>&1 && rustup run stable rustc --version >/dev/null 2>&1; then
  RUSTC_CMD=(rustup run stable rustc)
else
  require_tool rustc
  RUSTC_CMD=(rustc)
fi

run_logged "${RUSTC_CMD[@]}" --version
if ! "${RUSTC_CMD[@]}" --target wasm32-unknown-unknown --print cfg >/dev/null 2>&1; then
  log "selected rustc cannot compile wasm32-unknown-unknown; install the target with: rustup target add wasm32-unknown-unknown"
  exit 30
fi

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

run_logged "${RUSTC_CMD[@]}" --target wasm32-unknown-unknown \
  --crate-type cdylib \
  -C opt-level=z \
  -C panic=abort \
  -C link-arg=--no-entry \
  -C link-arg=--export=add \
  -C link-arg=--export=koma_source_init \
  -C link-arg=--export=koma_source_search \
  -C link-arg=--export=koma_source_free \
  -C link-arg=--export-memory \
  -C link-arg=-z \
  -C link-arg=stack-size=32768 \
  -C link-arg=--initial-memory=131072 \
  -C link-arg=--max-memory=131072 \
  -o "$WASM_OUT" \
  "$SCRIPT_DIR/rust-fixture/src/lib.rs"

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

if ! grep -q 'HOST_LOG level=1 .*rust fixture init reached host imports' "$RUN_LOG"; then
  log "missing Rust host log import evidence"
  exit 23
fi

if ! grep -q 'HOST_CHECK_CANCEL result=0' "$RUN_LOG"; then
  log "missing host check_cancel import evidence"
  exit 24
fi

if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$search_json" > "$JSON_OUT"
  run_logged python3 -m json.tool "$JSON_OUT"
  run_logged python3 - "$JSON_OUT" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    payload = json.load(fh)

assert payload["ok"] is True
assert payload["data"]["requestEcho"] == "fixture"
assert payload["data"]["items"][0]["title"] == "Fixture Series"
assert payload["hostHints"]["network"] is False
PY
else
  log "python3 not found; host runner still validated result envelope shape"
fi

log "Rust fixture artifacts:"
log "  wasm: $WASM_OUT"
log "  log: $RUN_LOG"
log "  json: $JSON_OUT"
