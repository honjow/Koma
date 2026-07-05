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
offline_download_visible_phase="source-index-visible-offline-download-reader"
local_source_package_visible_phase="local-source-package-visible-reader"
local_source_package_offline_download_visible_phase="local-source-package-visible-offline-download-reader"
local_library_folder_reader_phase="local-library-folder-reader"
local_library_folder_visible_reader_phase="local-library-folder-visible-reader"
requires_index="${KOMA_SOURCE_READER_REQUIRES_INDEX:-true}"
if [ "$phase" = "real-source-visible-reader" ] ||
  [ "$phase" = "$local_source_package_visible_phase" ] ||
  [ "$phase" = "$local_source_package_offline_download_visible_phase" ] ||
  [ "$phase" = "$local_library_folder_reader_phase" ] ||
  [ "$phase" = "$local_library_folder_visible_reader_phase" ]; then
  requires_index="false"
fi
source_repo="${KOMA_SOURCES_REPO:-$repo/../koma-sources}"
source_build_name="${KOMA_SOURCE_READER_BUILD_SOURCE:-mangadex}"
build_source_first="${KOMA_SOURCE_READER_BUILD_SOURCE_FIRST:-false}"
dist_dir="${KOMA_SOURCES_DIST:-$source_repo/dist}"
port="${KOMA_SOURCE_INDEX_PORT:-8765}"
index_url="${KOMA_SOURCE_INDEX_URL:-}"
host_ip="${KOMA_SOURCE_INDEX_HOST:-}"
source_package_path="${KOMA_SOURCE_PACKAGE_PATH:-}"
source_package_file="${KOMA_SOURCE_PACKAGE_FILE:-}"
source_package_base64="${KOMA_SOURCE_PACKAGE_BASE64:-}"
source_package_rawfile="${KOMA_SOURCE_PACKAGE_RAWFILE:-test/source-smoke-package.koma}"
source_package_rawfile_path=""
temp_source_package_rawfile=""
artifact_dir="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-reader-smoke}"
remote_smoke_result="${KOMA_SOURCE_READER_REMOTE_RESULT:-/data/app/el2/100/base/com.honjow.koma/haps/entry/files/source-runtime-smoke-result.json}"

if [ "$requires_index" = "true" ] && [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [ "$requires_index" = "true" ] && [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  host_ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ "$requires_index" = "true" ] && [ -z "$index_url" ] && [ -z "$host_ip" ]; then
  echo "source reader smoke failed: set KOMA_SOURCE_INDEX_HOST to the host IP reachable from the emulator" >&2
  exit 1
fi

if [ "$requires_index" = "true" ] && [ -z "$index_url" ]; then
  index_url="http://$host_ip:$port/index.json"
fi

if [ "$build_source_first" = "true" ]; then
  if [ ! -x "$source_repo/build.sh" ]; then
    echo "source reader smoke failed: source build script not found: $source_repo/build.sh" >&2
    exit 1
  fi
  (cd "$source_repo" && ./build.sh --source "$source_build_name")
fi

if [ ! -x "$hdc" ]; then
  echo "source reader smoke failed: hdc not found or not executable: $hdc" >&2
  exit 1
fi
if [ ! -x "$hvigorw" ]; then
  echo "source reader smoke failed: hvigorw not found or not executable: $hvigorw" >&2
  exit 1
fi
if [ "$requires_index" = "true" ] && [ ! -f "$dist_dir/index.json" ]; then
  echo "source reader smoke failed: missing source index at $dist_dir/index.json" >&2
  exit 1
fi
if [ "$phase" = "$local_source_package_visible_phase" ] ||
  [ "$phase" = "$local_source_package_offline_download_visible_phase" ]; then
  if [ -z "$source_package_path" ]; then
    echo "source reader smoke failed: set KOMA_SOURCE_PACKAGE_PATH for $phase" >&2
    exit 1
  fi
  if [ ! -f "$source_package_path" ]; then
    echo "source reader smoke failed: source package not found: $source_package_path" >&2
    exit 1
  fi
  if [ -z "$source_package_file" ]; then
    source_package_file="$(basename "$source_package_path")"
  fi
  if [ -z "$source_package_base64" ]; then
    source_package_rawfile_path="entry/src/main/resources/rawfile/$source_package_rawfile"
  fi
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
if [ "$requires_index" = "true" ] && [ -z "${KOMA_SOURCE_INDEX_URL:-}" ]; then
  python3 -m http.server "$port" --bind 0.0.0.0 --directory "$dist_dir" > "$artifact_dir/source-index-http.log" 2>&1 &
  server_pid="$!"
  sleep 1
  if ! kill -0 "$server_pid" 2>/dev/null; then
    echo "source reader smoke failed: source index server did not start" >&2
    sed -n '1,80p' "$artifact_dir/source-index-http.log" >&2 || true
    exit 1
  fi
fi

cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
  fi
  if [ -n "$temp_source_package_rawfile" ]; then
    rm -f "$temp_source_package_rawfile" 2>/dev/null || true
  fi
}
trap cleanup EXIT

hdc_target() {
  local attempt=1
  local max_attempts="${KOMA_HDC_RETRY_COUNT:-3}"
  while true; do
    if python3 - "$hdc" "$target" "$@" <<'PY'
import os
import subprocess
import sys

timeout = int(os.environ.get('KOMA_HDC_COMMAND_TIMEOUT_SECONDS', '45'))
cmd = [sys.argv[1], '-t', sys.argv[2], *sys.argv[3:]]
try:
    raise SystemExit(subprocess.run(cmd, timeout=timeout).returncode)
except subprocess.TimeoutExpired:
    print(f"source reader smoke failed: hdc command timed out after {timeout}s: {' '.join(cmd[:5])}", file=sys.stderr)
    raise SystemExit(124)
PY
    then
      return 0
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      return 1
    fi
    "$hdc" kill >/dev/null 2>&1 || true
    "$hdc" start >/dev/null 2>&1 || true
    attempt=$((attempt + 1))
    sleep 2
  done
}

if { [ "$phase" = "$local_source_package_visible_phase" ] ||
  [ "$phase" = "$local_source_package_offline_download_visible_phase" ]; } &&
  [ -n "$source_package_rawfile_path" ]; then
  mkdir -p "$(dirname "$source_package_rawfile_path")"
  cp "$source_package_path" "$source_package_rawfile_path"
  temp_source_package_rawfile="$source_package_rawfile_path"
fi

hvigor_args=(
  "$hvigorw" --no-daemon --warn --mode module
  -p product=default
  -p buildMode=debug
  -p module=entry@default
  assembleHap
)
python3 - "${hvigor_args[@]}" <<'PY'
import os
import subprocess
import sys

timeout = int(os.environ.get('KOMA_HVIGOR_TIMEOUT_SECONDS', '240'))
try:
    raise SystemExit(subprocess.run(sys.argv[1:], timeout=timeout).returncode)
except subprocess.TimeoutExpired:
    print(f"source reader smoke failed: hvigor build timed out after {timeout}s", file=sys.stderr)
    raise SystemExit(124)
PY

hdc_target install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc_target shell hilog -r
hdc_target shell rm -f "$remote_smoke_result"
aa_start_args=(
  shell aa start -a EntryAbility -b com.honjow.koma
  -m entry
  --ps koma.sourceRuntimeSmoke run
  --ps koma.sourceRuntimeSmoke.phase "$phase"
  --ps koma.sourceRuntimeSmoke.packageFile "$source_package_file"
  --ps koma.sourceRuntimeSmoke.packageRawfile "$source_package_rawfile"
  --ps koma.sourceRuntimeSmoke.sourceId "$source_id"
  --ps koma.sourceRuntimeSmoke.query "$query"
)
if [ -n "$index_url" ]; then
  aa_start_args+=(--ps koma.sourceRuntimeSmoke.indexUrl "$index_url")
fi
if [ -n "$source_package_base64" ]; then
  aa_start_args+=(--ps koma.sourceRuntimeSmoke.packageBase64 "$source_package_base64")
fi
hdc_target "${aa_start_args[@]}"

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
if phase in ('local-library-folder-reader', 'local-library-folder-visible-reader'):
    if result.get('localLibraryFolderScanOk') is not True:
        raise SystemExit('local library folder reader smoke failed: scan check failed')
    if result.get('localLibraryFolderImageFilesOk') is not True:
        raise SystemExit('local library folder reader smoke failed: image fixture files were not written')
    if result.get('localLibraryFolderPersistOk') is not True:
        raise SystemExit('local library folder reader smoke failed: persist check failed')
    if result.get('localLibraryFolderReloadOk') is not True:
        raise SystemExit('local library folder reader smoke failed: reload check failed')
    if result.get('localLibraryFolderReaderKind') != 'local_file_image':
        raise SystemExit('local library folder reader smoke failed: reader did not use local file')
    if result.get('localLibraryFolderReaderOk') is not True:
        raise SystemExit('local library folder reader smoke failed: reader check failed')
    if phase == 'local-library-folder-visible-reader':
        if result.get('localLibraryFolderVisiblePersistOk') is not True:
            raise SystemExit('local library folder visible reader smoke failed: visible persist check failed')
        if result.get('localLibraryFolderVisibleReloadOk') is not True:
            raise SystemExit('local library folder visible reader smoke failed: visible reload check failed')
        if result.get('localLibraryFolderVisibleReaderKind') != 'local_file_image':
            raise SystemExit('local library folder visible reader smoke failed: visible reader did not use local file')
        if result.get('localLibraryFolderVisibleReaderOk') is not True:
            raise SystemExit('local library folder visible reader smoke failed: visible reader check failed')
    raise SystemExit(0)
if result.get('sourceIndexReaderSelectedSourceId') != source_id:
    raise SystemExit('source reader smoke failed: source id mismatch')
if phase in ('local-source-package-visible-reader', 'local-source-package-visible-offline-download-reader'):
    if result.get('sourceIndexReaderPackageBytes', 0) <= 0:
        raise SystemExit('source reader smoke failed: local source package was not read')
if phase not in ('source-index-settings', 'source-index-browse') and result.get('sourceIndexReaderSearchQuery') != query:
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

if [ "$phase" = "$offline_download_visible_phase" ] && [ -n "$server_pid" ]; then
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  server_pid=""
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
  if python3 - "$smoke_result" "$library_layout" "$reader_click" "$phase" <<'PY'
import json
import pathlib
import re
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
layout = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
click_path = pathlib.Path(sys.argv[3])
phase = sys.argv[4]
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
if phase != 'local-library-folder-visible-reader' and (not chapter or chapter not in text):
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
python3 - "$smoke_result" "$reader_layout" "$reader_screen" <<'PY'
import json
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
layout = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding='utf-8'))
screen_path = pathlib.Path(sys.argv[3])
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
    if 'Unable to load page' not in text and '无法加载页面' not in text:
        raise SystemExit('source reader smoke failed: corrupt reader missing visible error')
    raise SystemExit(0)
if phase in ('source-index-visible-offline-download-reader', 'local-source-package-visible-offline-download-reader'):
    if result.get('sourceIndexDownloadOfflineReaderKind') != 'local_file_image':
        raise SystemExit('source reader smoke failed: visible offline reader did not use local file')
if phase == 'local-library-folder-visible-reader':
    if result.get('localLibraryFolderVisibleReaderKind') != 'local_file_image':
        raise SystemExit('source reader smoke failed: visible local folder reader did not use local file')
if '"type": "Image"' not in text and '"type":"Image"' not in text and screen_path.stat().st_size < 500000:
    raise SystemExit('source reader smoke failed: reader evidence missing visible image node or detailed screenshot')
PY

echo "source reader smoke passed: $artifact_dir"
