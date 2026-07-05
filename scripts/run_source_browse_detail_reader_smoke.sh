#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
user_id="${KOMA_SMOKE_USER_ID:-100}"
source_id="${KOMA_SOURCE_READER_SOURCE_ID:-org.mangadex.koma}"
source_display="${KOMA_SOURCE_BROWSE_DISPLAY_NAME:-MangaDex}"
artifact_dir="${KOMA_SOURCE_BROWSE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-browse-detail-reader-smoke}"

mkdir -p "$artifact_dir"

if [ ! -x "$hdc" ]; then
  echo "source browse detail reader smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi

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

capture_layout() {
  local name="$1"
  hdc_target shell uitest dumpLayout -p "/data/local/tmp/koma-$name-layout.json" -a
  hdc_target shell uitest screenCap -p "/data/local/tmp/koma-$name-screen.png"
  rm -f "$artifact_dir/$name-layout.json" "$artifact_dir/$name-screen.png"
  hdc_target file recv "/data/local/tmp/koma-$name-layout.json" "$artifact_dir/$name-layout.json"
  hdc_target file recv "/data/local/tmp/koma-$name-screen.png" "$artifact_dir/$name-screen.png"
}

click_from_layout() {
  local layout="$1"
  local output="$2"
  shift 2
  python3 - "$layout" "$output" "$@" <<'PY'
import json
import pathlib
import re
import sys

layout_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
needles = sys.argv[3:]
layout = json.loads(layout_path.read_text(encoding='utf-8'))

def attrs(node):
    if not isinstance(node, dict):
        return {}
    value = node.get('attributes')
    return value if isinstance(value, dict) else node

def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)

def bounds(value):
    if isinstance(value, list) and len(value) >= 4:
        return [int(float(v)) for v in value[:4]]
    if isinstance(value, dict):
        keys = ('left', 'top', 'right', 'bottom')
        if all(k in value for k in keys):
            return [int(float(value[k])) for k in keys]
    if isinstance(value, str):
        nums = [int(float(v)) for v in re.findall(r'-?\d+(?:\.\d+)?', value)]
        if len(nums) >= 4:
            return nums[:4]
    return None

matches = []
for node in walk(layout):
    item = attrs(node)
    node_text = ' '.join(str(item.get(key, '')) for key in ('text', 'originalText', 'description'))
    if any(needle in node_text for needle in needles):
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            matches.append((box, node_text))

if not matches:
    raise SystemExit(f'missing clickable text: {needles}')

box, _text = sorted(matches, key=lambda row: (row[0][1], row[0][0]))[0]
output_path.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n', encoding='utf-8')
PY
  read -r click_x click_y < "$output"
  hdc_target shell uitest uiInput click "$click_x" "$click_y"
}

click_first_source_manga() {
  local layout="$1"
  local output="$2"
  python3 - "$layout" "$output" "$source_display" <<'PY'
import json
import pathlib
import re
import sys

layout_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
source_display = sys.argv[3]
layout = json.loads(layout_path.read_text(encoding='utf-8'))

excluded = {
    source_display, f'v', 'Browse', '浏览', 'Search', '搜索', 'Open list', '打开列表',
    'No manga found', '没有找到漫画', 'Load more', '加载更多', 'books', '本',
}

def attrs(node):
    if not isinstance(node, dict):
        return {}
    value = node.get('attributes')
    return value if isinstance(value, dict) else node

def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)

def bounds(value):
    if isinstance(value, list) and len(value) >= 4:
        return [int(float(v)) for v in value[:4]]
    if isinstance(value, dict):
        keys = ('left', 'top', 'right', 'bottom')
        if all(k in value for k in keys):
            return [int(float(value[k])) for k in keys]
    if isinstance(value, str):
        nums = [int(float(v)) for v in re.findall(r'-?\d+(?:\.\d+)?', value)]
        if len(nums) >= 4:
            return nums[:4]
    return None

def candidate_text(item):
    values = []
    for key in ('text', 'originalText', 'description'):
        value = str(item.get(key, '')).strip()
        if value:
            values.append(value)
    return ' '.join(values).strip()

candidates = []
for node in walk(layout):
    item = attrs(node)
    text = candidate_text(item)
    if len(text) < 2 or text in excluded or text.startswith('v'):
        continue
    if re.fullmatch(r'\d+\s*/?\s*\d*', text):
        continue
    box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
    if box is None:
        continue
    left, top, right, bottom = box
    if top < 1100 or bottom <= top or right <= left:
        continue
    if bottom - top > 220:
        continue
    candidates.append((top, left, box, text))

if not candidates:
    raise SystemExit('missing source manga grid item in browse layout')

_top, _left, box, title = sorted(candidates)[0]
output_path.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n{title}\n', encoding='utf-8')
PY
  read -r click_x click_y < "$output"
  hdc_target shell uitest uiInput click "$click_x" "$click_y"
}

assert_layout_contains() {
  local layout="$1"
  shift
  python3 - "$layout" "$@" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
missing = [needle for needle in sys.argv[2:] if needle not in text]
if missing:
    raise SystemExit(f'layout missing expected text: {missing}')
PY
}

assert_layout_contains_any() {
  local layout="$1"
  shift
  python3 - "$layout" "$@" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
if not any(needle in text for needle in sys.argv[2:]):
    raise SystemExit(f'layout missing any expected text: {sys.argv[2:]}')
PY
}

rm -f "$artifact_dir"/*.json "$artifact_dir"/*.png "$artifact_dir"/*.txt

KOMA_SOURCE_READER_PHASE=source-index-browse \
KOMA_SOURCE_READER_CAPTURE_UI=false \
KOMA_SOURCE_READER_ARTIFACT_DIR="$artifact_dir/source-seed" \
KOMA_SOURCE_READER_SOURCE_ID="$source_id" \
  scripts/run_source_reader_smoke.sh

hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -u "$user_id" -a EntryAbility -b com.honjow.koma -m entry
sleep "${KOMA_SOURCE_BROWSE_START_WAIT_SECONDS:-4}"

capture_layout "source-browse-home"
click_from_layout "$artifact_dir/source-browse-home-layout.json" "$artifact_dir/click-browse-tab.txt" Browse 浏览
sleep "${KOMA_SOURCE_BROWSE_TAB_WAIT_SECONDS:-2}"

capture_layout "source-browse-list"
click_from_layout "$artifact_dir/source-browse-list-layout.json" "$artifact_dir/click-source.txt" "$source_display"
sleep "${KOMA_SOURCE_BROWSE_SOURCE_WAIT_SECONDS:-8}"

capture_layout "source-browse-source"
assert_layout_contains "$artifact_dir/source-browse-source-layout.json" "$source_display"
click_first_source_manga "$artifact_dir/source-browse-source-layout.json" "$artifact_dir/click-source-manga.txt"
sleep "${KOMA_SOURCE_BROWSE_DETAIL_WAIT_SECONDS:-8}"

capture_layout "source-browse-detail"
assert_layout_contains_any "$artifact_dir/source-browse-detail-layout.json" "Start reading" "开始阅读"
click_from_layout "$artifact_dir/source-browse-detail-layout.json" "$artifact_dir/click-start-reading.txt" "Start reading" "开始阅读"
sleep "${KOMA_SOURCE_BROWSE_READER_WAIT_SECONDS:-10}"

capture_layout "source-browse-reader"
python3 - "$artifact_dir/source-browse-reader-layout.json" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
if ' / ' not in text:
    raise SystemExit('source browse detail reader smoke failed: reader layout missing page counter')
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit('source browse detail reader smoke failed: reader layout missing image node')
PY

echo "source browse detail reader smoke passed: $artifact_dir"
