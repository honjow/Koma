#!/usr/bin/env bash
set -euo pipefail

# Pin both upstream decoders. The app packs their pixels with the public ImageKit API.
sdk="${1:?Pass the OpenHarmony native SDK directory}"
cache_root="${2:?Pass an ignored dependency cache directory}"
arch="${3:?Pass the OHOS ABI or host for the local decoder test}"
cmake="$sdk/build-tools/cmake/bin/cmake"
toolchain="$sdk/build/cmake/ohos.toolchain.cmake"
mkdir -p "$cache_root/downloads"
cache_root="$(cd "$cache_root" && pwd)"
key="$(shasum -a 256 "$0" "$sdk/oh-uni-package.json" "$toolchain" "$sdk/llvm/bin/clang" | shasum -a 256 | cut -c1-16)"
cache="$cache_root/$arch-$key"
target="$cache/target"
if [ -s "$target/lib/libavif.a" ] && [ -s "$target/lib/libaom.a" ] && [ -f "$cache/.complete" ]; then
  printf '%s\n' "$target"
  exit 0
fi

fetch() {
  local name="$1" expected="$2" url="$3" file="$cache_root/downloads/$1"
  if [ ! -f "$file" ]; then
    local temp="$file.$$"
    curl -fL --max-time 120 "$url" -o "$temp" >&2
    mv "$temp" "$file"
  fi
  if [ "$(shasum -a 256 "$file" | awk '{print $1}')" != "$expected" ]; then
    echo "$name checksum mismatch" >&2
    exit 1
  fi
}
fetch libavif-1.4.2.tar.gz 2b645287340ba5a631d268b551dc2d72bd73ac33335962dd36dcdb6d8366921d \
  https://codeload.github.com/AOMediaCodec/libavif/tar.gz/refs/tags/v1.4.2
fetch libaom-3.14.1.tar.gz 44bf90dbd23e734d50e70a8c41c285193922938bd0d3bc2ee56764d181d55ef5 \
  https://storage.googleapis.com/aom-releases/libaom-3.14.1.tar.gz

mkdir -p "$cache/source/libavif" "$cache/source/aom" "$target/lib" "$target/include"
tar -xzf "$cache_root/downloads/libavif-1.4.2.tar.gz" -C "$cache/source/libavif" --strip-components=1
tar -xzf "$cache_root/downloads/libaom-3.14.1.tar.gz" -C "$cache/source/aom" --strip-components=1
common=(-G Ninja -DCMAKE_MAKE_PROGRAM="$sdk/build-tools/cmake/bin/ninja"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF)
case "$arch" in
  host) ;;
  arm64-v8a|x86_64) common+=(-DCMAKE_TOOLCHAIN_FILE="$toolchain" -DOHOS_ARCH="$arch" -DOHOS_PLATFORM=OHOS) ;;
  *) echo "Unsupported reader AVIF ABI: $arch" >&2; exit 1 ;;
esac
"$cmake" -S "$cache/source/libavif" -B "$cache/build" "${common[@]}" \
  -DAVIF_CODEC_AOM=LOCAL -DAVIF_CODEC_AOM_ENCODE=OFF -DAVIF_CODEC_AOM_DECODE=ON \
  -DAVIF_LIBYUV=OFF -DAVIF_BUILD_APPS=OFF -DAVIF_BUILD_TESTS=OFF -DAVIF_BUILD_EXAMPLES=OFF \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON -DFETCHCONTENT_SOURCE_DIR_LIBAOM="$cache/source/aom" \
  -DAOM_TARGET_CPU=generic >&2
"$cmake" --build "$cache/build" --target avif --parallel "${KOMA_BUILD_JOBS:-4}" >&2
cp "$cache/build/libavif_internal.a" "$target/lib/libavif.a"
cp "$cache/build/_deps/libaom-build/libaom.a" "$target/lib/"
cp -R "$cache/source/libavif/include/avif" "$target/include/"
touch "$cache/.complete"
printf '%s\n' "$target"
