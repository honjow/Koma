#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
user_id="${KOMA_SMOKE_USER_ID:-100}"
artifact_dir="${KOMA_DOWNLOAD_NOTIFICATION_ARTIFACT_DIR:-.hvigor/outputs/download-notification-ui-smoke}"

mkdir -p "$artifact_dir"

if [ ! -x "$hdc" ]; then
  echo "download notification UI smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "download notification UI smoke failed: hvigorw not found or not executable: $hvigorw" >&2
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
    box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
    if box is None:
        continue
    if any(value == needle for value in values for needle in needles):
        exact_matches.append((box, text))
    elif any(needle in text for needle in needles):
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

click_after_scrolls() {
  local base="$1"
  local output="$2"
  shift 2
  for index in 0 1 2 3 4 5; do
    capture_layout "$base-$index"
    if click_from_layout "$artifact_dir/$base-$index-layout.json" "$output" "$@"; then
      return 0
    fi
    hdc_target shell uitest uiInput swipe 660 1700 660 700 600
    sleep 1
  done
  echo "download notification UI smoke failed: missing clickable text: $*" >&2
  return 1
}

"$hvigorw" --no-daemon --warn --mode module \
  -p product=default \
  -p buildMode=debug \
  -p module=entry@default \
  assembleHap

rm -f "$artifact_dir"/*.json "$artifact_dir"/*.png "$artifact_dir"/*.txt
hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell hilog -r
hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -u "$user_id" -a EntryAbility -b com.honjow.koma -m entry
sleep "${KOMA_DOWNLOAD_NOTIFICATION_START_WAIT_SECONDS:-4}"

capture_layout "download-notification-home"
click_from_layout "$artifact_dir/download-notification-home-layout.json" "$artifact_dir/click-settings.txt" Settings 设置
sleep "${KOMA_DOWNLOAD_NOTIFICATION_SETTINGS_WAIT_SECONDS:-2}"

click_after_scrolls "download-notification-root-settings" "$artifact_dir/click-download-settings.txt" Downloads 下载
sleep "${KOMA_DOWNLOAD_NOTIFICATION_PANE_WAIT_SECONDS:-2}"

click_after_scrolls "download-notification-settings" "$artifact_dir/click-test-notification.txt" \
  "Send test notification" "发送测试通知"
sleep "${KOMA_DOWNLOAD_NOTIFICATION_RESULT_WAIT_SECONDS:-3}"
capture_layout "download-notification-result"

hdc_target shell hilog -x -e "download_notification_test" > "$artifact_dir/download-notification-hilog.txt" || true
python3 - "$artifact_dir/download-notification-hilog.txt" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8', errors='ignore')
match = re.search(r'step=download_notification_test code=(delivered|disabled|publish_failed)', text)
if match is None:
    raise SystemExit('download notification UI smoke failed: missing notification dispatch result')
if match.group(1) == 'publish_failed':
    raise SystemExit('download notification UI smoke failed: notification publish failed')
PY

echo "download notification UI smoke passed: $artifact_dir"
