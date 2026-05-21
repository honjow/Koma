#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ARTIFACT_DIR="${KOMA_WASM_SPIKE_ARTIFACT_DIR:-$REPO_ROOT/.hermes-artifacts/wasm-runtime-spike-rust}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

WAMR_TAG="${WAMR_TAG:-WAMR-2.3.0}"
WAMR_COMMIT="${WAMR_COMMIT:-c7b2db18329f849b81568b94e72ddd0b20f431a5}"
WAMR_ROOT_DIR="${WAMR_ROOT_DIR:-$ARTIFACT_DIR/cache/wasm-micro-runtime}"
BUILD_DIR="$ARTIFACT_DIR/build"
LOG_DIR="$ARTIFACT_DIR/logs"
WASM_OUT="$BUILD_DIR/rust_source_fixture.wasm"
SDK_RLIB="$BUILD_DIR/libkoma_source_sdk.rlib"
HOST_BUILD_DIR="$BUILD_DIR/host"
RUN_LOG="$LOG_DIR/run-rust-fixture.log"
JSON_OUT="$ARTIFACT_DIR/rust-source-operation-results.json"

mkdir -p "$BUILD_DIR" "$LOG_DIR" "$(dirname "$WAMR_ROOT_DIR")"
: > "$RUN_LOG"

redact_stream() {
  sed \
    -e "s#$WAMR_ROOT_DIR#<cache>#g" \
    -e "s#$ARTIFACT_DIR#<artifact>#g" \
    -e "s#$REPO_ROOT#<repo>#g" \
    -e "s#/home/gamer#<home>#g" \
    -e "s#cache/wasm-micro-runtime#<cache>#g" \
    -e 's#Authorization:[^[:space:],;}]*#Authorization: <redacted>#Ig' \
    -e 's#-----BEGIN [A-Z ]*PRIVATE KEY-----#<private-key>#Ig'
}

log() {
  printf '%s\n' "$*" | redact_stream | tee -a "$RUN_LOG"
}

run_logged() {
  log "+ $*"
  "$@" 2>&1 | redact_stream | tee -a "$RUN_LOG"
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
  --edition=2021 \
  --crate-name koma_source_sdk \
  --crate-type rlib \
  -C target-cpu=mvp \
  -C target-feature=-reference-types \
  -C opt-level=z \
  -C panic=abort \
  -o "$SDK_RLIB" \
  "$SCRIPT_DIR/rust-sdk/src/lib.rs"

run_logged "${RUSTC_CMD[@]}" --target wasm32-unknown-unknown \
  --edition=2021 \
  --crate-type cdylib \
  -C target-cpu=mvp \
  -C target-feature=-reference-types \
  -C opt-level=z \
  -C panic=abort \
  --extern "koma_source_sdk=$SDK_RLIB" \
  -C link-arg=--no-entry \
  -C link-arg=--export=add \
  -C link-arg=--export=koma_source_init \
  -C link-arg=--export=koma_source_search \
  -C link-arg=--export=koma_source_get_manga \
  -C link-arg=--export=koma_source_get_chapters \
  -C link-arg=--export=koma_source_get_pages \
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
"$HOST_BUILD_DIR/koma_wamr_spike" "$WASM_OUT" 2>&1 | redact_stream | tee -a "$RUN_LOG"

for operation in search get_manga get_chapters get_pages; do
  if ! grep -q "SOURCE_API_OPERATION $operation ok:true" "$RUN_LOG"; then
    log "missing SOURCE_API_OPERATION $operation ok:true evidence"
    exit 22
  fi
done

if ! grep -q 'SOURCE_API_RUNTIME_SMOKE_PASS' "$RUN_LOG"; then
  log "missing SOURCE_API_RUNTIME_SMOKE_PASS evidence"
  exit 22
fi

if ! grep -q 'hostHints.network=false' "$RUN_LOG"; then
  log "missing hostHints.network=false evidence"
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
  run_logged python3 - "$RUN_LOG" "$JSON_OUT" <<'PY'
import json
import sys

run_log = sys.argv[1]
json_out = sys.argv[2]
payloads = {}
with open(run_log, "r", encoding="utf-8") as fh:
    for line in fh:
        if not line.startswith("SOURCE_API_JSON "):
            continue
        name, raw = line[len("SOURCE_API_JSON "):].split("=", 1)
        payloads[name] = json.loads(raw)

expected = ["search", "get_manga", "get_chapters", "get_pages"]
assert sorted(payloads) == sorted(expected), payloads.keys()
for name in expected:
    payload = payloads[name]
    assert payload["version"] == 1
    assert payload["ok"] is True
    assert payload["operation"] == name
    assert "data" in payload
    assert payload["hostHints"]["network"] is False
assert payloads["search"]["data"]["items"][0]["title"] == "Fixture Series"
assert payloads["search"]["data"]["requestEcho"] == "fixture"
with open(json_out, "w", encoding="utf-8") as out:
    json.dump(payloads, out, indent=2, sort_keys=True)
    out.write("\n")
PY
  run_logged python3 -m json.tool "$JSON_OUT"
else
  log "python3 not found; host runner still validated result envelope shape"
fi

log "Rust fixture artifacts:"
log "  sdk: $SDK_RLIB"
log "  wasm: $WASM_OUT"
log "  log: $RUN_LOG"
log "  json: $JSON_OUT"
