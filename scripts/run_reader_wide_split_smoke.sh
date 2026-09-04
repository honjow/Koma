#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
artifact_dir="${KOMA_READER_WIDE_SPLIT_ARTIFACT_DIR:-.hvigor/outputs/reader-wide-split-smoke}"
remote_smoke_result="${KOMA_READER_WIDE_SPLIT_REMOTE_RESULT:-/data/app/el2/100/base/com.honjow.koma/haps/entry/files/source-runtime-smoke-result.json}"
wide_image_rawfile="${KOMA_READER_WIDE_SPLIT_RAWFILE:-test/wide-split-fixture.png}"
wide_image_rawfile_path="entry/src/main/resources/rawfile/$wide_image_rawfile"

if [ ! -x "$hdc" ]; then
  echo "reader wide split smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "reader wide split smoke failed: hvigorw not found or not executable: $hvigorw" >&2
  exit 1
fi

mkdir -p "$artifact_dir"
smoke_result="$artifact_dir/source-runtime-smoke-result.json"
library_layout="$artifact_dir/library-layout.json"
library_screen="$artifact_dir/library-screen.png"
sort_menu_layout="$artifact_dir/sort-menu-layout.json"
first_layout="$artifact_dir/reader-first-layout.json"
first_screen="$artifact_dir/reader-first-screen.png"
second_layout="$artifact_dir/reader-second-layout.json"
second_screen="$artifact_dir/reader-second-screen.png"
fixture_click="$artifact_dir/fixture-click.txt"
sort_click="$artifact_dir/sort-click.txt"
sort_added_click="$artifact_dir/sort-added-click.txt"
swipe_coordinates="$artifact_dir/swipe-coordinates.txt"
rm -f \
  "$smoke_result" \
  "$library_layout" \
  "$library_screen" \
  "$sort_menu_layout" \
  "$first_layout" \
  "$first_screen" \
  "$second_layout" \
  "$second_screen" \
  "$fixture_click" \
  "$sort_click" \
  "$sort_added_click" \
  "$swipe_coordinates"
mkdir -p "$(dirname "$wide_image_rawfile_path")"
python3 - "$wide_image_rawfile_path" <<'PY'
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

cleanup() {
  rm -f "$wide_image_rawfile_path"
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

extract_click() {
  python3 - "$1" "$2" "$3" <<'PY'
import json
import pathlib
import re
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
out = pathlib.Path(sys.argv[2])
mode = sys.argv[3]

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

def matches(text):
    normalized = text.strip()
    if mode == "fixture":
        return "Reader Wide Split Fixture" in normalized
    if mode == "sort-chip":
        return normalized.startswith("排序 ") or normalized.startswith("Sort ")
    if mode == "sort-added":
        return normalized in ("最近加入", "Recently added")
    return False

def walk(node):
    if isinstance(node, dict):
        text = " ".join(str(node.get(k, "")) for k in ("text", "content", "description", "name", "value"))
        if matches(text):
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
    raise SystemExit(f"reader wide split smoke failed: layout missing click bounds for {mode}")
out.write_text(f"{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n", encoding="utf-8")
PY
}

capture_layout() {
  local remote_path="$1"
  local local_path="$2"
  hdc_target shell uitest dumpLayout -p "$remote_path" -a
  rm -f "$local_path"
  hdc_target file recv "$remote_path" "$local_path"
}

capture_screen() {
  local remote_path="$1"
  local local_path="$2"
  hdc_target shell uitest screenCap -p "$remote_path"
  rm -f "$local_path"
  hdc_target file recv "$remote_path" "$local_path"
}

"$hvigorw" --no-daemon --warn --mode module \
  -p product=default \
  -p buildMode=debug \
  -p module=entry@default \
  assembleHap

hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell hilog -r
hdc_target shell rm -f "$remote_smoke_result"
hdc_target shell aa start -a EntryAbility -b com.honjow.koma \
  -m entry \
  --ps koma.sourceRuntimeSmoke run \
  --ps koma.sourceRuntimeSmoke.phase reader-wide-split-fixture \
  --ps koma.sourceRuntimeSmoke.wideImageRawfile "$wide_image_rawfile"

poll_count="${KOMA_READER_WIDE_SPLIT_RESULT_POLL_COUNT:-18}"
poll_delay="${KOMA_READER_WIDE_SPLIT_RESULT_POLL_DELAY_SECONDS:-3}"
for ((attempt = 1; attempt <= poll_count; attempt += 1)); do
  rm -f "$smoke_result"
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

hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -a EntryAbility -b com.honjow.koma -m entry
sleep "${KOMA_READER_WIDE_SPLIT_RELOAD_WAIT_SECONDS:-5}"
capture_layout /data/local/tmp/koma-reader-wide-split-library-layout.json "$library_layout"
capture_screen /data/local/tmp/koma-reader-wide-split-library-screen.png "$library_screen"

if ! extract_click "$library_layout" "$fixture_click" fixture; then
  extract_click "$library_layout" "$sort_click" sort-chip
  read -r sort_x sort_y < "$sort_click"
  hdc_target shell uitest uiInput click "$sort_x" "$sort_y"
  sleep 1
  capture_layout /data/local/tmp/koma-reader-wide-split-sort-menu-layout.json "$sort_menu_layout"
  extract_click "$sort_menu_layout" "$sort_added_click" sort-added
  read -r sort_added_x sort_added_y < "$sort_added_click"
  hdc_target shell uitest uiInput click "$sort_added_x" "$sort_added_y"
  sleep 1
  capture_layout /data/local/tmp/koma-reader-wide-split-library-layout.json "$library_layout"
  capture_screen /data/local/tmp/koma-reader-wide-split-library-screen.png "$library_screen"
  extract_click "$library_layout" "$fixture_click" fixture
fi

read -r click_x click_y < "$fixture_click"
hdc_target shell uitest uiInput click "$click_x" "$click_y"
sleep "${KOMA_READER_WIDE_SPLIT_OPEN_WAIT_SECONDS:-5}"
capture_layout /data/local/tmp/koma-reader-wide-split-first-layout.json "$first_layout"
capture_screen /data/local/tmp/koma-reader-wide-split-first-screen.png "$first_screen"

python3 - "$first_layout" <<'PY'
import json
import pathlib
import sys

text = json.dumps(json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")), ensure_ascii=False)
for needle in ("无法加载页面", "离线或网络不可用", "Unable to load page", "reader_page_unavailable"):
    if needle in text:
        raise SystemExit(f"reader wide split smoke failed: first split half shows load error: {needle}")
if "1 / 1" not in text:
    raise SystemExit("reader wide split smoke failed: first split half lost source-page counter")
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit("reader wide split smoke failed: first split half missing image node")
PY

python3 - "$first_screen" "$swipe_coordinates" <<'PY'
import pathlib
import struct
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
if data[:8] != b"\x89PNG\r\n\x1a\n":
    raise SystemExit("reader wide split smoke failed: first screenshot is not PNG")
width, height = struct.unpack(">II", data[16:24])
pathlib.Path(sys.argv[2]).write_text(
    f"{width * 5 // 6} {height // 2} {width // 6} {height // 2}\n",
    encoding="utf-8",
)
PY
read -r swipe_from_x swipe_from_y swipe_to_x swipe_to_y < "$swipe_coordinates"
hdc_target shell uitest uiInput swipe "$swipe_from_x" "$swipe_from_y" "$swipe_to_x" "$swipe_to_y" 650
sleep "${KOMA_READER_WIDE_SPLIT_SWIPE_WAIT_SECONDS:-2}"
capture_layout /data/local/tmp/koma-reader-wide-split-second-layout.json "$second_layout"
capture_screen /data/local/tmp/koma-reader-wide-split-second-screen.png "$second_screen"

python3 - "$second_layout" <<'PY'
import json
import pathlib
import sys

text = json.dumps(json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")), ensure_ascii=False)
for needle in ("无法加载页面", "离线或网络不可用", "Unable to load page", "reader_page_unavailable"):
    if needle in text:
        raise SystemExit(f"reader wide split smoke failed: second split half shows load error: {needle}")
if "1 / 1" not in text:
    raise SystemExit("reader wide split smoke failed: second split half lost source-page counter")
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit("reader wide split smoke failed: second split half missing image node")
PY

python3 - "$first_screen" "$second_screen" <<'PY'
import pathlib
import struct
import sys
import zlib

def paeth(left, above, upper_left):
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left

def center_rgb(path):
    data = pathlib.Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"reader wide split smoke failed: {path} is not PNG")
    offset = 8
    compressed = bytearray()
    width = height = bit_depth = color_type = interlace = None
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise SystemExit(f"reader wide split smoke failed: unsupported screenshot PNG format for {path}")
    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    previous = bytearray(stride)
    cursor = 0
    center = None
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        scanline = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        reconstructed = bytearray(stride)
        for index, value in enumerate(scanline):
            left = reconstructed[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                raise SystemExit(f"reader wide split smoke failed: unsupported PNG filter {filter_type}")
            reconstructed[index] = (value + predictor) & 0xFF
        if y == height // 2:
            pixel = (width // 2) * channels
            center = tuple(reconstructed[pixel:pixel + 3])
        previous = reconstructed
    return center

def assert_near(actual, expected, label):
    if actual is None or any(abs(actual[i] - expected[i]) > 18 for i in range(3)):
        raise SystemExit(
            f"reader wide split smoke failed: {label} center color {actual} does not match {expected}"
        )

first = center_rgb(sys.argv[1])
second = center_rgb(sys.argv[2])
assert_near(first, (24, 126, 192), "first LTR split half")
assert_near(second, (238, 108, 44), "second LTR split half")
print(f"reader wide split colors verified: first={first} second={second}")
PY

echo "reader wide split smoke passed: $artifact_dir"
