#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
port="${KOMA_READER_WIDE_SPLIT_PORT:-8771}"
host_ip="${KOMA_READER_WIDE_SPLIT_HOST:-}"
artifact_dir="${KOMA_READER_WIDE_SPLIT_ARTIFACT_DIR:-.hvigor/outputs/reader-wide-split-smoke}"
remote_smoke_result="${KOMA_READER_WIDE_SPLIT_REMOTE_RESULT:-/data/app/el2/100/base/com.honjow.koma/haps/entry/files/source-runtime-smoke-result.json}"

if [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ -z "$host_ip" ]; then
  echo "reader wide split smoke failed: set KOMA_READER_WIDE_SPLIT_HOST to the host IP reachable from the emulator" >&2
  exit 1
fi
if [ ! -x "$hdc" ]; then
  echo "reader wide split smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "reader wide split smoke failed: hvigorw not found or not executable: $hvigorw" >&2
  exit 1
fi

mkdir -p "$artifact_dir"
python3 - "$artifact_dir/wide-split-fixture.png" <<'PY'
import pathlib
import struct
import sys
import zlib

path = pathlib.Path(sys.argv[1])
width, height = 1920, 1080

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

rows = []
for _y in range(height):
    row = bytearray([0])
    for x in range(width):
        row.extend((24, 126, 192) if x < width // 2 else (238, 108, 44))
    rows.append(bytes(row))

path.write_bytes(
    b"\x89PNG\r\n\x1a\n" +
    chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
    chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) +
    chunk(b"IEND", b"")
)
PY

server_pid=""
python3 -m http.server "$port" --bind 0.0.0.0 --directory "$artifact_dir" > "$artifact_dir/http.log" 2>&1 &
server_pid="$!"

cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

hdc_target() {
  local attempt=1
  local max_attempts="${KOMA_HDC_RETRY_COUNT:-3}"
  while true; do
    if "$hdc" -t "$target" "$@"; then
      return 0
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
}

"$hvigorw" --no-daemon --warn --mode module \
  -p product=default \
  -p buildMode=debug \
  -p module=entry@default \
  assembleHap

image_url="http://$host_ip:$port/wide-split-fixture.png"
hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell hilog -r
hdc_target shell rm -f "$remote_smoke_result"
hdc_target shell aa start -a EntryAbility -b com.honjow.koma \
  --ps koma.sourceRuntimeSmoke run \
  --ps koma.sourceRuntimeSmoke.phase reader-wide-split-fixture \
  --ps koma.sourceRuntimeSmoke.wideImageUrl "$image_url"

smoke_result="$artifact_dir/source-runtime-smoke-result.json"
poll_count="${KOMA_READER_WIDE_SPLIT_RESULT_POLL_COUNT:-18}"
poll_delay="${KOMA_READER_WIDE_SPLIT_RESULT_POLL_DELAY_SECONDS:-3}"
for ((attempt = 1; attempt <= poll_count; attempt += 1)); do
  if hdc_target file recv "$remote_smoke_result" "$smoke_result" >/dev/null 2>&1; then
    if [ -s "$smoke_result" ] && python3 - "$smoke_result" <<'PY'
import json
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if result.get("ok") is not True:
    raise SystemExit("reader wide split smoke failed: result ok=false")
if result.get("smokePhase") != "reader-wide-split-fixture":
    raise SystemExit("reader wide split smoke failed: phase mismatch")
for key in ("readerWideSplitFixtureImageUrlProvided", "readerWideSplitFixturePersistOk", "readerWideSplitFixturePreferenceOk"):
    if result.get(key) is not True:
        raise SystemExit(f"reader wide split smoke failed: {key}=false")
if result.get("readerWideSplitFixtureExpectedSplitCount") != 2:
    raise SystemExit("reader wide split smoke failed: expected split count mismatch")
PY
    then
      break
    fi
  fi
  if [ "$attempt" -eq "$poll_count" ]; then
    echo "reader wide split smoke failed: missing successful result file at $remote_smoke_result" >&2
    exit 1
  fi
  sleep "$poll_delay"
done

hdc_target shell uitest dumpLayout -p /data/local/tmp/koma-reader-wide-split-library-layout.json -a
hdc_target shell uitest screenCap -p /data/local/tmp/koma-reader-wide-split-library-screen.png
hdc_target file recv /data/local/tmp/koma-reader-wide-split-library-layout.json "$artifact_dir/library-layout.json"
hdc_target file recv /data/local/tmp/koma-reader-wide-split-library-screen.png "$artifact_dir/library-screen.png"
python3 - "$artifact_dir/library-layout.json" "$artifact_dir/fixture-click.txt" <<'PY'
import json
import pathlib
import re
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
out = pathlib.Path(sys.argv[2])
title = "Reader Wide Split Fixture"

def bounds(value):
    if isinstance(value, list) and len(value) >= 4:
        return [int(float(v)) for v in value[:4]]
    if isinstance(value, dict):
        keys = ("left", "top", "right", "bottom")
        if all(k in value for k in keys):
            return [int(float(value[k])) for k in keys]
    if isinstance(value, str):
        nums = [int(float(v)) for v in re.findall(r"-?\d+(?:\.\d+)?", value)]
        if len(nums) >= 4:
            return nums[:4]
    return None

def walk(node):
    if isinstance(node, dict):
        text = " ".join(str(node.get(k, "")) for k in ("text", "content", "description", "name", "value"))
        if title in text:
            for key in ("bounds", "origBounds", "rect"):
                found = bounds(node.get(key))
                if found:
                    return found
        for value in node.values():
            found = walk(value)
            if found:
                return found
    if isinstance(node, list):
        for item in node:
            found = walk(item)
            if found:
                return found
    return None

box = walk(layout)
if box is None:
    raise SystemExit("reader wide split smoke failed: library layout missing fixture title bounds")
x = (box[0] + box[2]) // 2
y = (box[1] + box[3]) // 2
out.write_text(f"{x} {y}\n", encoding="utf-8")
PY
read -r click_x click_y < "$artifact_dir/fixture-click.txt"
hdc_target shell uitest uiInput click "$click_x" "$click_y"
sleep "${KOMA_READER_WIDE_SPLIT_OPEN_WAIT_SECONDS:-5}"
hdc_target shell uitest dumpLayout -p /data/local/tmp/koma-reader-wide-split-reader-layout.json -a
hdc_target shell uitest screenCap -p /data/local/tmp/koma-reader-wide-split-reader-screen.png
hdc_target file recv /data/local/tmp/koma-reader-wide-split-reader-layout.json "$artifact_dir/reader-layout.json"
hdc_target file recv /data/local/tmp/koma-reader-wide-split-reader-screen.png "$artifact_dir/reader-screen.png"
python3 - "$artifact_dir/reader-layout.json" <<'PY'
import json
import pathlib
import sys

text = json.dumps(json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")), ensure_ascii=False)
for needle in ("Reader Wide Split Fixture", "Wide landscape page"):
    if needle not in text:
        raise SystemExit(f"reader wide split smoke failed: reader layout missing {needle}")
if "1 / 2" not in text and "2 / 2" not in text:
    raise SystemExit("reader wide split smoke failed: reader layout missing split page counter")
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit("reader wide split smoke failed: reader layout missing image node")
PY

echo "reader wide split smoke passed: $artifact_dir"
