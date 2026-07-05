#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hdc="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
target="${KOMA_SMOKE_TARGET:-127.0.0.1:5557}"
user_id="${KOMA_SMOKE_USER_ID:-100}"
source_id="${KOMA_SOURCE_READER_SOURCE_ID:-org.mangadex.koma}"
query="${KOMA_SOURCE_READER_QUERY:-Salt Friend}"
phase="${KOMA_SOURCE_READER_PHASE:-source-index-visible-reader}"
capture_ui="${KOMA_SOURCE_READER_CAPTURE_UI:-true}"
dist_dir="${KOMA_SOURCES_DIST:-$repo/../koma-sources/dist}"
port="${KOMA_SOURCE_INDEX_PORT:-8765}"
index_url="${KOMA_SOURCE_INDEX_URL:-}"
host_ip="${KOMA_SOURCE_INDEX_HOST:-}"
artifact_dir="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-reader-smoke}"
remote_smoke_result="${KOMA_SOURCE_READER_REMOTE_RESULT:-/data/app/el2/100/base/com.honjow.koma/haps/entry/files/source-runtime-smoke-result.json}"

if [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  echo "source reader smoke failed: set KOMA_SOURCE_INDEX_HOST to the host IP reachable from the emulator" >&2
  exit 1
fi

if [ -z "$index_url" ]; then
  index_url="http://$host_ip:$port/index.json"
fi

if [ ! -x "$hdc" ]; then
  echo "source reader smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "source reader smoke failed: hvigorw not found or not executable: $hvigorw" >&2
  exit 1
fi
if [ ! -f "$dist_dir/index.json" ]; then
  echo "source reader smoke failed: missing source index at $dist_dir/index.json" >&2
  exit 1
fi

mkdir -p "$artifact_dir"
smoke_result="$artifact_dir/source-runtime-smoke-result.json"
library_layout="$artifact_dir/library-layout.json"
library_screen="$artifact_dir/library-screen.png"
reader_layout="$artifact_dir/reader-layout.json"
reader_screen="$artifact_dir/reader-screen.png"
reader_click="$artifact_dir/source-reader-click.txt"
rm -f "$smoke_result" "$library_layout" "$library_screen" "$reader_layout" "$reader_screen" "$reader_click"

server_pid=""
if [ -z "${KOMA_SOURCE_INDEX_URL:-}" ]; then
  python3 -m http.server "$port" --bind 0.0.0.0 --directory "$dist_dir" > "$artifact_dir/source-index-http.log" 2>&1 &
  server_pid="$!"
fi

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

hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell hilog -r
hdc_target shell rm -f "$remote_smoke_result"
hdc_target shell aa start -a EntryAbility -b com.honjow.koma \
  -m entry \
  --ps koma.sourceRuntimeSmoke run \
  --ps koma.sourceRuntimeSmoke.phase "$phase" \
  --ps koma.sourceRuntimeSmoke.indexUrl "$index_url" \
  --ps koma.sourceRuntimeSmoke.sourceId "$source_id" \
  --ps koma.sourceRuntimeSmoke.query "$query"

poll_count="${KOMA_SOURCE_READER_RESULT_POLL_COUNT:-18}"
poll_delay="${KOMA_SOURCE_READER_RESULT_POLL_DELAY_SECONDS:-5}"
for ((attempt = 1; attempt <= poll_count; attempt += 1)); do
  rm -f "$smoke_result"
  if hdc_target file recv "$remote_smoke_result" "$smoke_result" >/dev/null 2>&1; then
    if [ -s "$smoke_result" ] && python3 - "$smoke_result" "$source_id" "$query" "$phase" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source_id = sys.argv[2]
query = sys.argv[3]
phase = sys.argv[4]
result = json.loads(path.read_text(encoding='utf-8'))
if result.get('ok') is not True:
    raise SystemExit('source reader smoke failed: result ok=false')
if result.get('smokePhase') != phase:
    raise SystemExit('source reader smoke failed: phase mismatch')
if result.get('sourceIndexReaderSelectedSourceId') != source_id:
    raise SystemExit('source reader smoke failed: source id mismatch')
if phase != 'source-index-settings' and result.get('sourceIndexReaderSearchQuery') != query:
    raise SystemExit('source reader smoke failed: query mismatch')
if phase == 'source-index-settings':
    if result.get('sourceIndexSettingsDescriptorCount', 0) <= 0:
        raise SystemExit('source settings smoke failed: no descriptors')
    if result.get('sourceIndexSettingsEditableCount', 0) <= 0:
        raise SystemExit('source settings smoke failed: no editable descriptors')
    if result.get('sourceIndexSettingsSelectCount', 0) <= 0:
        raise SystemExit('source settings smoke failed: no select descriptor')
    if result.get('sourceIndexSettingsBooleanCount', 0) <= 0:
        raise SystemExit('source settings smoke failed: no boolean descriptor')
    if result.get('sourceIndexSettingsPersistOk') is not True:
        raise SystemExit('source settings smoke failed: settings did not persist')
elif 'undownloaded-offline-reader' in phase:
    if result.get('sourceIndexUndownloadedOfflineReaderKind') != 'uri_placeholder':
        raise SystemExit('source reader smoke failed: undownloaded offline reader did not use placeholder')
    if result.get('sourceIndexUndownloadedOfflineReaderOk') is not True:
        raise SystemExit('source reader smoke failed: undownloaded offline reader check failed')
elif 'download-corrupt-reader' in phase:
    if result.get('sourceIndexDownloadStatus') != 'downloaded':
        raise SystemExit('source reader smoke failed: corrupt download status mismatch')
    if result.get('sourceIndexDownloadOfflineReaderKind') != 'uri_placeholder':
        raise SystemExit('source reader smoke failed: corrupt offline reader did not use placeholder')
    if result.get('sourceIndexDownloadCorruptReaderOk') is not True:
        raise SystemExit('source reader smoke failed: corrupt offline reader check failed')
elif 'download-reader' in phase:
    if result.get('sourceIndexDownloadStatus') != 'downloaded':
        raise SystemExit('source reader smoke failed: download status mismatch')
    if result.get('sourceIndexDownloadDownloadedPageCount') != result.get('sourceIndexReaderPageCount'):
        raise SystemExit('source reader smoke failed: downloaded page count mismatch')
    if result.get('sourceIndexDownloadOfflineReaderKind') != 'local_file_image':
        raise SystemExit('source reader smoke failed: offline reader did not use local file')
PY
    then
      break
    fi
  fi
  if [ "$attempt" -eq "$poll_count" ]; then
    echo "source reader smoke failed: missing successful result file at $remote_smoke_result" >&2
    exit 1
  fi
  sleep "$poll_delay"
done

hdc_target shell hilog -x -e KOMA_SOURCE_RUNTIME_SMOKE_RESULT > "$artifact_dir/source-runtime-smoke-hilog.txt" || true

if [ "$capture_ui" != "true" ]; then
  echo "source reader smoke passed: $artifact_dir"
  exit 0
fi

hdc_target shell aa force-stop com.honjow.koma
hdc_target shell aa start -u "$user_id" -a EntryAbility -b com.honjow.koma -m entry
library_poll_count="${KOMA_SOURCE_READER_FOREGROUND_POLL_COUNT:-8}"
library_poll_delay="${KOMA_SOURCE_READER_FOREGROUND_WAIT_SECONDS:-3}"
for ((attempt = 1; attempt <= library_poll_count; attempt += 1)); do
  sleep "$library_poll_delay"
  hdc_target shell uitest dumpLayout -p /data/local/tmp/koma-source-reader-library-layout.json -a
  hdc_target shell uitest screenCap -p /data/local/tmp/koma-source-reader-library-screen.png
  rm -f "$library_layout" "$library_screen" "$reader_click"
  hdc_target file recv /data/local/tmp/koma-source-reader-library-layout.json "$library_layout"
  hdc_target file recv /data/local/tmp/koma-source-reader-library-screen.png "$library_screen"
  if python3 - "$smoke_result" "$library_layout" "$reader_click" <<'PY'
import json
import pathlib
import re
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
layout = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
click_path = pathlib.Path(sys.argv[3])
text = json.dumps(layout, ensure_ascii=False)

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

def is_koma_root(node):
    item = attrs(node)
    return item.get('bundleName') == 'com.honjow.koma' and item.get('pagePath') == 'pages/Index'

if not any(is_koma_root(node) for node in walk(layout)):
    raise SystemExit('source reader smoke failed: Koma is not foreground in library layout')
title = result.get('sourceIndexVisibleLibraryTitle')
chapter = result.get('sourceIndexReaderChapterTitle')
if not title or title not in text:
    raise SystemExit('source reader smoke failed: library layout missing visible manga title')
if not chapter or chapter not in text:
    raise SystemExit('source reader smoke failed: library layout missing visible chapter title')
for node in walk(layout):
    item = attrs(node)
    node_text = ' '.join(str(item.get(key, '')) for key in ('text', 'originalText', 'description'))
    if title in node_text:
        box = bounds(item.get('bounds')) or bounds(item.get('origBounds')) or bounds(item.get('rect'))
        if box is not None:
            click_path.write_text(f'{(box[0] + box[2]) // 2} {(box[1] + box[3]) // 2}\n', encoding='utf-8')
            raise SystemExit(0)
raise SystemExit('source reader smoke failed: library layout missing visible manga title bounds')
PY
  then
    break
  fi
  if [ "$attempt" -eq "$library_poll_count" ]; then
    echo "source reader smoke failed: Koma library UI did not become ready" >&2
    exit 1
  fi
done

read -r click_x click_y < "$reader_click"
hdc_target shell uitest uiInput click "$click_x" "$click_y"
sleep "${KOMA_SOURCE_READER_OPEN_WAIT_SECONDS:-5}"
hdc_target shell uitest dumpLayout -p /data/local/tmp/koma-source-reader-reader-layout.json -a
hdc_target shell uitest screenCap -p /data/local/tmp/koma-source-reader-reader-screen.png
rm -f "$reader_layout" "$reader_screen"
hdc_target file recv /data/local/tmp/koma-source-reader-reader-layout.json "$reader_layout"
hdc_target file recv /data/local/tmp/koma-source-reader-reader-screen.png "$reader_screen"
python3 - "$smoke_result" "$reader_layout" <<'PY'
import json
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
layout = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
text = json.dumps(layout, ensure_ascii=False)
phase = result.get('smokePhase')
title = result.get('sourceIndexReaderMangaTitle')
chapter = result.get('sourceIndexReaderChapterTitle')
page_count = result.get('sourceIndexReaderPageCount')
if not title or title not in text:
    raise SystemExit('source reader smoke failed: reader layout missing visible manga title')
if not chapter or chapter not in text:
    raise SystemExit('source reader smoke failed: reader layout missing visible chapter title')
if not isinstance(page_count, int) or f' / {page_count}' not in text:
    raise SystemExit('source reader smoke failed: reader layout missing visible page counter')
if phase == 'source-index-download-corrupt-reader':
    if result.get('sourceIndexDownloadOfflineReaderKind') != 'uri_placeholder':
        raise SystemExit('source reader smoke failed: corrupt reader did not report offline placeholder')
    if '"type": "Image"' in text or '"type":"Image"' in text:
        raise SystemExit('source reader smoke failed: corrupt reader unexpectedly rendered an image node')
    raise SystemExit(0)
if '"type": "Image"' not in text and '"type":"Image"' not in text:
    raise SystemExit('source reader smoke failed: reader layout missing visible image node')
PY

echo "source reader smoke passed: $artifact_dir"
