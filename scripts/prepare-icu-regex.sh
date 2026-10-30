#!/usr/bin/env bash
set -euo pipefail
# Official ICU source and an explicit Unicode-data filter are both part of the
# build recipe. CMake selects a fresh ignored cache when either or the SDK changes.
root_dir="$(cd "$(dirname "$0")/.." && pwd)"
native_sdk="${1:?Pass the OpenHarmony native SDK directory}"
cache_dir="${2:?Pass the recipe-specific cache directory}"
archive="$cache_dir/icu-release-74-2.tar.gz"
expected=27b8650a94df6f945cb3b686be3be320c2a32edf3ece2981672bf98bb3baa9e1
filter="$root_dir/scripts/icu-regex-data-filter.json"
mkdir -p "$cache_dir"
if [ ! -f "$archive" ]; then
  curl -fL --retry 2 https://github.com/unicode-org/icu/archive/refs/tags/release-74-2.tar.gz -o "$archive.tmp"
  mv "$archive.tmp" "$archive"
fi
actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
[ "$actual" = "$expected" ] || { echo 'ICU archive checksum mismatch' >&2; exit 1; }
if [ ! -f "$cache_dir/icu4c/source/configure" ]; then
  tar -xzf "$archive" -C "$cache_dir" --strip-components=1 icu-release-74-2/icu4c
fi
mkdir -p "$cache_dir/host" "$cache_dir/target"
case "$(uname -s)" in Darwin) platform=MacOSX;; Linux) platform=Linux;; *) echo 'Unsupported build host' >&2; exit 1;; esac
if [ ! -f "$cache_dir/host/.complete" ]; then
  (cd "$cache_dir/host" && ICU_DATA_FILTER_FILE="$filter" "$cache_dir/icu4c/source/runConfigureICU" "$platform" --disable-tests --disable-samples --disable-shared --enable-static && make -j"${KOMA_BUILD_JOBS:-8}" && touch .complete)
fi
if [ ! -f "$cache_dir/target/.complete" ]; then
  (cd "$cache_dir/target" && \
    ICU_DATA_FILTER_FILE="$filter" \
    CC="$native_sdk/llvm/bin/aarch64-unknown-linux-ohos-clang" \
    CXX="$native_sdk/llvm/bin/aarch64-unknown-linux-ohos-clang++" \
    AR="$native_sdk/llvm/bin/llvm-ar" RANLIB="$native_sdk/llvm/bin/llvm-ranlib" \
    CFLAGS='-O2 -fPIC -fvisibility=hidden' CXXFLAGS='-O2 -fPIC -fvisibility=hidden' \
    "$cache_dir/icu4c/source/configure" --host=aarch64-unknown-linux-gnu --with-cross-build="$cache_dir/host" \
      --disable-tests --disable-samples --disable-shared --enable-static && make -j"${KOMA_BUILD_JOBS:-8}" && touch .complete)
fi
