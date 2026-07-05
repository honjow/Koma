#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
user_id="${KOMA_SMOKE_USER_ID:-100}"
source_id="${KOMA_SOURCE_READER_SOURCE_ID:-org.mangadex.koma}"
source_display="${KOMA_SOURCE_BROWSE_DISPLAY_NAME:-MangaDex}"
artifact_dir="${KOMA_SOURCE_SETTINGS_UI_ARTIFACT_DIR:-.hvigor/outputs/source-settings-ui-smoke}"

mkdir -p "$artifact_dir"

if [ ! -x "$hdc" ]; then
  echo "source settings UI smoke failed: hdc not found or not executable: $hdc" >&2
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

layout = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
output = pathlib.Path(sys.argv[2])
needles = sys.argv[3:]

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
    text = ' '.join(values)
    if any(value == needle for value in values for needle in needles):
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            exact_matches.append((box, text))
    elif any(needle in text for needle in needles):
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            matches.append((box, text))

if exact_matches:
    matches = exact_matches

if not matches:
    raise SystemExit(f'missing clickable text: {needles}')

box, _text = sorted(matches, key=lambda row: (row[0][1], row[0][0]))[0]
output.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n', encoding='utf-8')
PY
  then
    return 1
  fi
  read -r click_x click_y < "$output"
  hdc_target shell uitest uiInput click "$click_x" "$click_y"
}

click_from_layout_or_after_scroll() {
  local name="$1"
  local output="$2"
  shift 2
  if click_from_layout "$artifact_dir/$name-layout.json" "$output" "$@"; then
    return 0
  fi
  hdc_target shell uitest uiInput swipe 660 1700 660 700 600
  sleep "${KOMA_SOURCE_SETTINGS_UI_SCROLL_WAIT_SECONDS:-1}"
  capture_layout "$name-scrolled"
  click_from_layout "$artifact_dir/$name-scrolled-layout.json" "$output" "$@"
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

wait_layout_contains_any() {
  local name="$1"
  shift
  local poll_count="${KOMA_SOURCE_SETTINGS_UI_POLL_COUNT:-10}"
  local poll_delay="${KOMA_SOURCE_SETTINGS_UI_POLL_DELAY_SECONDS:-2}"
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
  echo "source settings UI smoke failed: timed out waiting for $*" >&2
  return 1
}

rm -f "$artifact_dir"/*.json "$artifact_dir"/*.png "$artifact_dir"/*.txt

KOMA_SOURCE_READER_PHASE=source-index-settings \
KOMA_SOURCE_READER_CAPTURE_UI=false \
KOMA_SOURCE_READER_ARTIFACT_DIR="$artifact_dir/source-seed" \
KOMA_SOURCE_READER_SOURCE_ID="$source_id" \
  scripts/run_source_reader_smoke.sh

hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -u "$user_id" -a EntryAbility -b com.honjow.koma -m entry \
  --ps koma.launchRoute source_package_manager
sleep "${KOMA_SOURCE_SETTINGS_UI_START_WAIT_SECONDS:-5}"

capture_layout "source-settings-manager"
assert_layout_contains_any "$artifact_dir/source-settings-manager-layout.json" "$source_display"
click_from_layout_or_after_scroll "source-settings-manager" "$artifact_dir/click-settings.txt" "Settings" "设置"
sleep "${KOMA_SOURCE_SETTINGS_UI_PANEL_WAIT_SECONDS:-2}"

capture_layout "source-settings-panel"
assert_layout_contains_any "$artifact_dir/source-settings-panel-layout.json" "Source settings" "源设置"
assert_layout_contains_any "$artifact_dir/source-settings-panel-layout.json" "Save settings" "保存设置"
click_from_layout "$artifact_dir/source-settings-panel-layout.json" "$artifact_dir/click-save-settings.txt" "Save settings" "保存设置"
sleep "${KOMA_SOURCE_SETTINGS_UI_SAVE_WAIT_SECONDS:-2}"

capture_layout "source-settings-saved"
click_from_layout "$artifact_dir/source-settings-saved-layout.json" "$artifact_dir/click-validate-settings.txt" "Validate settings" "验证设置"
wait_layout_contains_any "source-settings-validation" "Settings validation: PASS" "设置验证：PASS"

echo "source settings UI smoke passed: $artifact_dir"
