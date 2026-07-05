#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
user_id="${KOMA_SMOKE_USER_ID:-100}"
artifact_dir="${KOMA_DOWNLOAD_NOTIFICATION_ROUTE_ARTIFACT_DIR:-.hvigor/outputs/download-notification-route-smoke}"

mkdir -p "$artifact_dir"

if [ ! -x "$hdc" ]; then
  echo "download notification route smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "download notification route smoke failed: hvigorw not found or not executable: $hvigorw" >&2
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
  hdc_target shell uitest dumpLayout -p "/data/local/tmp/koma-$name-layout.json" -a || return 1
  hdc_target shell uitest screenCap -p "/data/local/tmp/koma-$name-screen.png" || return 1
  rm -f "$artifact_dir/$name-layout.json" "$artifact_dir/$name-screen.png"
  hdc_target file recv "/data/local/tmp/koma-$name-layout.json" "$artifact_dir/$name-layout.json" || return 1
  hdc_target file recv "/data/local/tmp/koma-$name-screen.png" "$artifact_dir/$name-screen.png" || return 1
  [ -s "$artifact_dir/$name-layout.json" ]
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
missing = []
for group in sys.argv[2:]:
    choices = group.split('|')
    if not any(choice in text for choice in choices):
        missing.append(group)
if missing:
    raise SystemExit(f'layout missing expected text groups: {missing}')
PY
}

wait_layout_contains_any() {
  local name="$1"
  shift
  local poll_count="${KOMA_DOWNLOAD_NOTIFICATION_ROUTE_POLL_COUNT:-8}"
  local poll_delay="${KOMA_DOWNLOAD_NOTIFICATION_ROUTE_POLL_DELAY_SECONDS:-2}"
  for ((attempt = 1; attempt <= poll_count; attempt += 1)); do
    sleep "$poll_delay"
    if capture_layout "$name" && assert_layout_contains_any "$artifact_dir/$name-layout.json" "$@"; then
      return 0
    fi
  done
  echo "download notification route smoke failed: timed out waiting for $*" >&2
  return 1
}

"$hvigorw" --no-daemon --warn --mode module \
  -p product=default \
  -p buildMode=debug \
  -p module=entry@default \
  assembleHap

rm -f "$artifact_dir"/*.json "$artifact_dir"/*.png
hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -u "$user_id" -a EntryAbility -b com.honjow.koma -m entry \
  --ps koma.launchRoute downloads

wait_layout_contains_any "download-notification-route" \
  "Downloads|下载管理" \
  "Rescan downloads|重扫下载" \
  "No downloads yet|暂无下载任务"

echo "download notification route smoke passed: $artifact_dir"
