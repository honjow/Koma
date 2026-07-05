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
download_first="${KOMA_SOURCE_BROWSE_DOWNLOAD_FIRST:-false}"
entry_mode="${KOMA_SOURCE_BROWSE_ENTRY:-browse}"
source_search_query="${KOMA_SOURCE_BROWSE_SEARCH_QUERY:-1}"
seed_mode="${KOMA_SOURCE_BROWSE_SEED_MODE:-local-package}"
source_repo="${KOMA_SOURCES_REPO:-$repo/../koma-sources}"
source_build_name="${KOMA_SOURCE_BROWSE_BUILD_SOURCE:-mangadex}"
build_source_first="${KOMA_SOURCE_BROWSE_BUILD_SOURCE_FIRST:-false}"
source_package_path="${KOMA_SOURCE_PACKAGE_PATH:-$source_repo/dist/sources/mangadex/mangadex-0.1.0.koma}"

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
  if ! python3 - "$layout" "$output" "$@" <<'PY'
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
exact_matches = []
for node in walk(layout):
    item = attrs(node)
    values = [str(item.get(key, '')).strip() for key in ('text', 'originalText', 'description')]
    node_text = ' '.join(values)
    if any(value == needle for value in values for needle in needles):
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            exact_matches.append((box, node_text))
    elif any(needle in node_text for needle in needles):
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            matches.append((box, node_text))

if exact_matches:
    matches = exact_matches

if not matches:
    raise SystemExit(f'missing clickable text: {needles}')

box, _text = sorted(matches, key=lambda row: (row[0][1], row[0][0]))[0]
output_path.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n', encoding='utf-8')
PY
  then
    return 1
  fi
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

click_source_search_field() {
  local layout="$1"
  local output="$2"
  python3 - "$layout" "$output" <<'PY'
import json
import pathlib
import re
import sys

layout_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
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

candidates = []
for node in walk(layout):
    item = attrs(node)
    values = [str(item.get(key, '')).strip() for key in ('type', 'text', 'originalText', 'description')]
    text = ' '.join(values)
    if 'Search' not in text and '搜索漫画' not in text:
        continue
    box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
    if box is not None:
        candidates.append((box[1], box[0], box))

if not candidates:
    raise SystemExit('source browse detail reader smoke failed: missing source search field')

_top, _left, box = sorted(candidates)[0]
output_path.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n', encoding='utf-8')
PY
  read -r click_x click_y < "$output"
  hdc_target shell uitest uiInput click "$click_x" "$click_y"
}

type_source_search_query() {
  local query="$1"
  local layout="$2"
  if [[ ! "$query" =~ ^[0-9]+$ ]]; then
    echo "source browse detail reader smoke failed: UI search smoke query must be numeric for soft-keyboard automation: $query" >&2
    exit 1
  fi
  python3 - "$query" "$layout" "$artifact_dir/source-search-key-clicks.txt" <<'PY'
import json
import pathlib
import re
import sys

query = sys.argv[1].strip()
layout = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
output = pathlib.Path(sys.argv[3])

def walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from walk(item)

def bounds(value):
    if isinstance(value, str):
        nums = [int(float(v)) for v in re.findall(r'-?\d+(?:\.\d+)?', value)]
        if len(nums) >= 4:
            return nums[:4]
    if isinstance(value, list) and len(value) >= 4:
        return [int(float(v)) for v in value[:4]]
    return None

right = 1320
bottom = 2120
for node in walk(layout):
    item = node.get('attributes') if isinstance(node, dict) and isinstance(node.get('attributes'), dict) else node
    if not isinstance(item, dict):
        continue
    box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
    if box is not None:
        right = max(right, box[2])
        bottom = max(bottom, box[3])

digits = {
    '1': (0.300, 0.641), '2': (0.472, 0.641), '3': (0.660, 0.641),
    '4': (0.300, 0.714), '5': (0.472, 0.714), '6': (0.660, 0.714),
    '7': (0.300, 0.790), '8': (0.472, 0.790), '9': (0.660, 0.790),
    '0': (0.472, 0.870),
}
points = [(0.772, 0.889)]
points.extend(digits[char] for char in query)
output.write_text('\n'.join(f'{int(right * x)} {int(bottom * y)}' for x, y in points) + '\n', encoding='utf-8')
PY
  while read -r key_x key_y; do
    hdc_target shell uitest uiInput click "$key_x" "$key_y"
    sleep 0.1
  done < "$artifact_dir/source-search-key-clicks.txt"
}

click_first_search_manga() {
  local layout="$1"
  local output="$2"
  python3 - "$layout" "$output" "$source_display" "$source_search_query" <<'PY'
import json
import pathlib
import re
import sys

layout_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
source_display = sys.argv[3]
query = sys.argv[4]
layout = json.loads(layout_path.read_text(encoding='utf-8'))

excluded = {
    source_display, query, 'Search', '搜索', 'Search manga', '搜索漫画',
    'No manga found', '没有找到漫画', 'Load more', '加载更多',
    'Reset', '重置', 'Status', 'Content Rating', 'Demographic', 'Order By',
    '输入关键词搜索',
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
    if top < 1000 or bottom <= top or right <= left:
        continue
    if bottom - top > 260:
        continue
    candidates.append((top, left, box, text))

if not candidates:
    raise SystemExit('source browse detail reader smoke failed: missing source search result manga')

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

extract_source_detail_title() {
  local layout="$1"
  local output="$2"
  python3 - "$layout" "$output" "$source_display" <<'PY'
import json
import pathlib
import re
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
output = pathlib.Path(sys.argv[2])
source_display = sys.argv[3]
blocked = {
    source_display, 'Unknown author', '作者未知', 'Ongoing', '连载中',
    'Add to library', '加入书架', 'In library', '已在书架',
    'Start reading', '开始阅读', 'Download chapter', '下载章节',
    'Download again', '重新下载', 'Description', '简介', 'Tags', '标签',
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

seen = []
for node in walk(layout):
    item = attrs(node)
    values = []
    for key in ('text', 'originalText', 'description'):
        value = re.sub(r'\s+', ' ', str(item.get(key, '')).strip())
        if value and value not in values:
            values.append(value)
    text = ' '.join(values).strip()
    if not text or text in seen:
        continue
    seen.append(text)

for text in seen:
    if len(text) < 4 or text in blocked:
        continue
    if text.endswith('章') or text.startswith('v') or re.fullmatch(r'\d+(\.\d+)?', text):
        continue
    output.write_text(text + '\n', encoding='utf-8')
    raise SystemExit(0)

raise SystemExit('missing source detail title')
PY
}

layout_contains_all() {
  local layout="$1"
  shift
  python3 - "$layout" "$@" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
if not all(needle in text for needle in sys.argv[2:]):
    raise SystemExit(1)
PY
}

wait_layout_contains_any() {
  local name="$1"
  shift
  local poll_count="${KOMA_SOURCE_BROWSE_DOWNLOAD_POLL_COUNT:-18}"
  local poll_delay="${KOMA_SOURCE_BROWSE_DOWNLOAD_POLL_DELAY_SECONDS:-5}"
  for ((attempt = 1; attempt <= poll_count; attempt += 1)); do
    sleep "$poll_delay"
    capture_layout "$name"
    if python3 - "$artifact_dir/$name-layout.json" "$@" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
if not any(needle in text for needle in sys.argv[2:]):
    raise SystemExit(1)
PY
    then
      return 0
    fi
  done
  echo "source browse detail reader smoke failed: timed out waiting for $*" >&2
  return 1
}

rm -f "$artifact_dir"/*.json "$artifact_dir"/*.png "$artifact_dir"/*.txt

if [ "$build_source_first" = "true" ]; then
  if [ ! -x "$source_repo/build.sh" ]; then
    echo "source browse detail reader smoke failed: source build script not found: $source_repo/build.sh" >&2
    exit 1
  fi
  (cd "$source_repo" && ./build.sh --source "$source_build_name")
fi

if [ "$seed_mode" = "index" ]; then
  KOMA_SOURCE_READER_PHASE=source-index-browse \
  KOMA_SOURCE_READER_CAPTURE_UI=false \
  KOMA_SOURCE_READER_ARTIFACT_DIR="$artifact_dir/source-seed" \
  KOMA_SOURCE_READER_SOURCE_ID="$source_id" \
    scripts/run_source_reader_smoke.sh
else
  if [ ! -f "$source_package_path" ]; then
    echo "source browse detail reader smoke failed: source package not found: $source_package_path" >&2
    exit 1
  fi
  KOMA_SOURCE_READER_PHASE=local-source-package-visible-reader \
  KOMA_SOURCE_READER_REQUIRES_INDEX=false \
  KOMA_SOURCE_READER_CAPTURE_UI=false \
  KOMA_SOURCE_READER_ARTIFACT_DIR="$artifact_dir/source-seed" \
  KOMA_SOURCE_READER_SOURCE_ID="$source_id" \
  KOMA_SOURCE_PACKAGE_PATH="$source_package_path" \
    scripts/run_source_reader_smoke.sh
fi

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
if [ "$entry_mode" = "search" ]; then
  click_from_layout "$artifact_dir/source-browse-source-layout.json" "$artifact_dir/click-source-search.txt" Search 搜索
  sleep "${KOMA_SOURCE_BROWSE_SEARCH_PAGE_WAIT_SECONDS:-2}"
  capture_layout "source-browse-search"
  click_source_search_field "$artifact_dir/source-browse-search-layout.json" "$artifact_dir/click-source-search-field.txt"
  sleep "${KOMA_SOURCE_BROWSE_KEYBOARD_WAIT_SECONDS:-1}"
  capture_layout "source-browse-search-focused"
  type_source_search_query "$source_search_query" "$artifact_dir/source-browse-search-focused-layout.json"
  sleep "${KOMA_SOURCE_BROWSE_QUERY_SETTLE_SECONDS:-1}"
  capture_layout "source-browse-search-typed"
  assert_layout_contains "$artifact_dir/source-browse-search-typed-layout.json" "$source_search_query"
  hdc_target shell uitest uiInput keyEvent Back || true
  sleep "${KOMA_SOURCE_BROWSE_SEARCH_RESULT_WAIT_SECONDS:-10}"
  capture_layout "source-browse-search-results"
  assert_layout_contains "$artifact_dir/source-browse-search-results-layout.json" "$source_search_query"
  click_first_search_manga "$artifact_dir/source-browse-search-results-layout.json" "$artifact_dir/click-source-search-manga.txt"
else
  click_first_source_manga "$artifact_dir/source-browse-source-layout.json" "$artifact_dir/click-source-manga.txt"
fi
sleep "${KOMA_SOURCE_BROWSE_DETAIL_WAIT_SECONDS:-8}"

capture_layout "source-browse-detail"
extract_source_detail_title "$artifact_dir/source-browse-detail-layout.json" "$artifact_dir/source-manga-title.txt"
source_manga_title="$(sed -n '1p' "$artifact_dir/source-manga-title.txt")"
assert_layout_contains_any "$artifact_dir/source-browse-detail-layout.json" "Start reading" "开始阅读"
detail_action_layout="$artifact_dir/source-browse-detail-layout.json"
if [ "$download_first" = "true" ]; then
  click_from_layout "$artifact_dir/source-browse-detail-layout.json" "$artifact_dir/click-download-chapter.txt" "Download chapter" "下载章节" "Download again" "重新下载"
  wait_layout_contains_any "source-browse-download" "Download again" "重新下载" "Downloaded" "已下载"
  detail_action_layout="$artifact_dir/source-browse-download-layout.json"
fi
assert_layout_contains_any "$detail_action_layout" "Add to library" "加入书架" "In library" "已在书架"
click_from_layout "$detail_action_layout" "$artifact_dir/click-add-to-library.txt" "Add to library" "加入书架" "In library" "已在书架"
sleep "${KOMA_SOURCE_BROWSE_ADD_WAIT_SECONDS:-4}"
capture_layout "source-browse-library-after-add"
if ! layout_contains_all "$artifact_dir/source-browse-library-after-add-layout.json" "$source_manga_title" "浏览"; then
  hdc_target shell uitest uiInput keyEvent Back || true
  sleep "${KOMA_SOURCE_BROWSE_BACK_WAIT_SECONDS:-2}"
  capture_layout "source-browse-after-add-back"
  click_from_layout "$artifact_dir/source-browse-after-add-back-layout.json" "$artifact_dir/click-library-tab.txt" Library 书架
  sleep "${KOMA_SOURCE_BROWSE_LIBRARY_WAIT_SECONDS:-3}"
  capture_layout "source-browse-library-after-add"
fi
assert_layout_contains "$artifact_dir/source-browse-library-after-add-layout.json" "$source_manga_title"
click_from_layout "$artifact_dir/source-browse-library-after-add-layout.json" "$artifact_dir/click-library-source-manga.txt" "$source_manga_title"
sleep "${KOMA_SOURCE_BROWSE_READER_WAIT_SECONDS:-10}"

capture_layout "source-browse-reader"
python3 - "$artifact_dir/source-browse-reader-layout.json" "$artifact_dir/click-reader-center.txt" <<'PY'
import json
import pathlib
import re
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
click_path = pathlib.Path(sys.argv[2])
text = json.dumps(layout, ensure_ascii=False)
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit('source browse detail reader smoke failed: reader layout missing image node')

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

boxes = []
for node in walk(layout):
    item = attrs(node)
    box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
    if box is not None:
        boxes.append(box)
if not boxes:
    raise SystemExit('source browse detail reader smoke failed: reader layout missing bounds')
left = min(box[0] for box in boxes)
top = min(box[1] for box in boxes)
right = max(box[2] for box in boxes)
bottom = max(box[3] for box in boxes)
click_path.write_text(f'{(left + right) // 2} {(top + bottom) // 2}\n', encoding='utf-8')
PY
read -r reader_x reader_y < "$artifact_dir/click-reader-center.txt"
hdc_target shell uitest uiInput click "$reader_x" "$reader_y"
sleep "${KOMA_SOURCE_BROWSE_CHROME_WAIT_SECONDS:-1}"
capture_layout "source-browse-reader-chrome"
python3 - "$artifact_dir/source-browse-reader-chrome-layout.json" <<'PY'
import json
import pathlib
import sys

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
if ' / ' not in text:
    raise SystemExit('source browse detail reader smoke failed: reader chrome layout missing page counter')
PY

echo "source browse detail reader smoke passed: $artifact_dir"
