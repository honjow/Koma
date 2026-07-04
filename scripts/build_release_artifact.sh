#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

hvigorw="${HVIGORW:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
product="${KOMA_RELEASE_PRODUCT:-release}"
build_mode="${KOMA_RELEASE_BUILD_MODE:-release}"
module="${KOMA_RELEASE_MODULE:-entry@default}"
target_bundle="${KOMA_BUNDLE_NAME:-com.honjow.koma}"
artifact_root="${KOMA_RELEASE_ARTIFACT_ROOT:-.hermes-artifacts/release}"

if [ ! -x "$hvigorw" ]; then
  echo "release build failed: hvigorw not found or not executable: $hvigorw" >&2
  exit 1
fi

scripts/check-public-build-profile.sh --head

"$hvigorw" --no-daemon --warn --mode module \
  -p "product=$product" \
  -p "buildMode=$build_mode" \
  -p "module=$module" \
  assembleHap

hap_dir="entry/build/$product/outputs/default"
signed_hap="$hap_dir/entry-default-signed.hap"
unsigned_hap="$hap_dir/entry-default-unsigned.hap"
pack_info="$hap_dir/pack.info"

if [ ! -f "$signed_hap" ]; then
  echo "release build failed: missing signed HAP at $signed_hap" >&2
  exit 1
fi
if [ ! -f "$unsigned_hap" ]; then
  echo "release build failed: missing unsigned HAP at $unsigned_hap" >&2
  exit 1
fi

metadata_json="$(mktemp)"
trap 'rm -f "$metadata_json"' EXIT
unzip -p "$signed_hap" module.json > "$metadata_json"

read -r bundle_name version_name version_code hap_build_mode hap_debug <<EOF
$(python3 - "$metadata_json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding='utf-8'))
app = data.get('app', {})
print(
    app.get('bundleName', ''),
    app.get('versionName', ''),
    app.get('versionCode', ''),
    app.get('buildMode', ''),
    str(app.get('debug', '')).lower(),
)
PY
)
EOF

if [ "$bundle_name" != "$target_bundle" ]; then
  echo "release build failed: expected bundle $target_bundle, got $bundle_name" >&2
  exit 1
fi
if [ "$hap_build_mode" != "release" ] || [ "$hap_debug" != "false" ]; then
  echo "release build failed: HAP is not a non-debug release build (buildMode=$hap_build_mode debug=$hap_debug)" >&2
  exit 1
fi

short_sha="$(git rev-parse --short HEAD)"
artifact_dir="$artifact_root/${version_name}-${version_code}-${short_sha}"
mkdir -p "$artifact_dir"

signed_name="Koma-${version_name}-${version_code}-${short_sha}-${product}-${build_mode}-signed.hap"
unsigned_name="Koma-${version_name}-${version_code}-${short_sha}-${product}-${build_mode}-unsigned.hap"
pack_name="Koma-${version_name}-${version_code}-${short_sha}-${product}-${build_mode}-pack.info"

cp "$signed_hap" "$artifact_dir/$signed_name"
cp "$unsigned_hap" "$artifact_dir/$unsigned_name"
cp "$pack_info" "$artifact_dir/$pack_name"
cp "$metadata_json" "$artifact_dir/module.json"

python3 - "$artifact_dir" "$signed_name" "$unsigned_name" "$pack_name" "$bundle_name" "$version_name" "$version_code" "$short_sha" "$product" "$build_mode" <<'PY'
import hashlib
import json
import pathlib
import sys

artifact_dir = pathlib.Path(sys.argv[1])
signed_name, unsigned_name, pack_name = sys.argv[2:5]
bundle_name, version_name, version_code, short_sha, product, build_mode = sys.argv[5:11]

def file_info(name: str) -> dict:
    path = artifact_dir / name
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {'file': name, 'bytes': path.stat().st_size, 'sha256': digest}

manifest = {
    'bundleName': bundle_name,
    'versionName': version_name,
    'versionCode': int(version_code),
    'gitCommit': short_sha,
    'product': product,
    'buildMode': build_mode,
    'debug': False,
    'artifacts': [
        file_info(signed_name),
        file_info(unsigned_name),
        file_info(pack_name),
        file_info('module.json'),
    ],
}
(artifact_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
PY

echo "release artifact: $artifact_dir"
