#!/usr/bin/env bash
set -euo pipefail
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="/home/gamer/devtool/ohos/command-line-tools/bin:$PATH"
HDC=/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc
DEBUG_BUNDLE=com.honjow.koma.dev
RELEASE_BUNDLE=com.honjow.koma
DEFAULT_DEVICE=192.168.50.103:12345

set_app_bundle_name() {
  python3 - "$PROJ/AppScope/app.json5" "$1" <<'PY'
from pathlib import Path
import sys
path=Path(sys.argv[1]); bundle=sys.argv[2]
text=path.read_text(encoding='utf-8')
import re
text=re.sub(r'"bundleName"\s*:\s*"[^"]+"', f'"bundleName": "{bundle}"', text, count=1)
path.write_text(text, encoding='utf-8')
PY
}

current_app_bundle_name() {
  python3 - "$PROJ/AppScope/app.json5" <<'PY'
import json, sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text()).get('app',{}).get('bundleName',''))
PY
}

hap_bundle_name() {
  python3 - "$1" <<'PY'
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as zf:
    print(json.loads(zf.read('module.json').decode()).get('app',{}).get('bundleName',''))
PY
}

ensure_ohpm_dependencies() {
  command -v ohpm >/dev/null 2>&1 || { echo '错误: 未找到 ohpm'; exit 1; }
  for d in . entry; do
    [ -f "$PROJ/$d/oh-package.json5" ] && (cd "$PROJ/$d" && ohpm install)
  done
}

build_debug() {
  ensure_ohpm_dependencies
  APP_SCOPE_BACKUP="$(mktemp)"
  cp "$PROJ/AppScope/app.json5" "$APP_SCOPE_BACKUP"
  cleanup_debug_bundle() {
    if [ -n "${APP_SCOPE_BACKUP:-}" ] && [ -f "$APP_SCOPE_BACKUP" ]; then
      cp "$APP_SCOPE_BACKUP" "$PROJ/AppScope/app.json5"
      rm -f "$APP_SCOPE_BACKUP"
    fi
  }
  trap cleanup_debug_bundle EXIT
  set_app_bundle_name "$DEBUG_BUNDLE"
  echo "==> Debug bundleName: $(current_app_bundle_name)"
  cd "$PROJ"
  hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
  local hap="$PROJ/entry/build/default/outputs/default/entry-default-unsigned.hap"
  local actual; actual="$(hap_bundle_name "$hap")"
  echo "==> unsigned HAP bundleName: $actual"
  [ "$actual" = "$DEBUG_BUNDLE" ] || { echo "错误: HAP 包名不符"; exit 1; }
  cleanup_debug_bundle
  trap - EXIT
}


usage() {
  cat <<EOF
Koma dev script
  bash dev.sh --build-only            build debug + sign only
  bash dev.sh -d ${DEFAULT_DEVICE}    build debug + sign + install
  bash dev.sh --no-build -d <device>  sign/install existing HAP
  bash dev.sh --launch [-d device]    launch app
  bash dev.sh --log [-d device]       hilog grep koma
EOF
}

case "${1:-}" in
  -h|--help) usage ;;
  --launch)
    shift || true; dev="$DEFAULT_DEVICE"; [ "${1:-}" = "-d" ] && dev="${2:-$DEFAULT_DEVICE}"
    "$HDC" -t "$dev" shell aa start -a EntryAbility -b "$DEBUG_BUNDLE" ;;
  --log)
    shift || true; dev="$DEFAULT_DEVICE"; [ "${1:-}" = "-d" ] && dev="${2:-$DEFAULT_DEVICE}"
    "$HDC" -t "$dev" shell "hilog | grep -i koma" ;;
  --build-only)
    shift; build_debug; python3 "$PROJ/scripts/sign.py" --no-install "$@" ;;
  --no-build)
    shift; python3 "$PROJ/scripts/sign.py" "$@" ;;
  *)
    build_debug
    if [ "${1:-}" = "-d" ]; then shift; python3 "$PROJ/scripts/sign.py" -d "${1:-$DEFAULT_DEVICE}"
    else python3 "$PROJ/scripts/sign.py" -d "$DEFAULT_DEVICE"
    fi ;;
esac
