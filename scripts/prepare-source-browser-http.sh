#!/usr/bin/env bash
set -euo pipefail
# Browser-profile HTTP is a bounded source-runtime candidate. Keep the exact
# upstream revision and SDK/recipe/architecture cache identity together; do not
# substitute it for the normal HTTP transport without the existing acceptance.
sdk="${1:?Pass the OpenHarmony native SDK directory}"
cache_root="${2:?Pass an ignored cache root}"
arch="${3:-arm64-v8a}"
[ "$arch" = arm64-v8a ] || { echo 'Unsupported source-browser-http architecture' >&2; exit 1; }
cmake="$sdk/build-tools/cmake/bin/cmake"
ninja="$sdk/build-tools/cmake/bin/ninja"
toolchain="$sdk/build/cmake/ohos.toolchain.cmake"
compiler="$sdk/llvm/bin/clang"
[ -x "$cmake" ] && [ -x "$ninja" ] && [ -x "$compiler" ] || { echo 'Missing SDK build tools' >&2; exit 1; }
recipe_hash="$(shasum -a 256 "$0" | awk '{print $1}')"
sdk_hash="$(shasum -a 256 "$sdk/oh-uni-package.json" "$toolchain" "$compiler" | shasum -a 256 | awk '{print $1}')"
key="$(printf '%s\n%s\n%s\n' "$recipe_hash" "$sdk_hash" "$arch" | shasum -a 256 | cut -c1-16)"
cache="$cache_root/$key"
archive="$cache/curl-impersonate-v2.3.2.tar.gz"
expected='ce8ef1faef42992ef2ef1985f44a802250a25f325b6f1391599d417027cb129a'
mkdir -p "$cache"
if [ ! -f "$archive" ]; then
  curl -fL --max-time 120 'https://api.github.com/repos/lexiforest/curl-impersonate/tarball/v2.3.2' -o "$archive.tmp"
  mv "$archive.tmp" "$archive"
fi
[ "$(shasum -a 256 "$archive" | awk '{print $1}')" = "$expected" ] || { echo 'Source archive checksum mismatch' >&2; exit 1; }
required_libs="libcurl-impersonate.a libssl.a libcrypto.a libnghttp2.a libcares.a libbrotlidec.a libbrotlicommon.a libzstd.a libz.a"
complete=1
[ -f "$cache/.complete" ] && [ -s "$cache/target/include/curl/curl.h" ] && [ -s "$cache/target/include/curl/easy.h" ] || complete=0
for lib in $required_libs; do [ -s "$cache/target/lib/$lib" ] || complete=0; done
if [ "$complete" != 1 ]; then
  mkdir -p "$cache/source"
  tar -xzf "$archive" -C "$cache/source" --strip-components=1
  # The upstream superbuild pins every dependency URL and hash. Propagate the
  # target toolchain into its CMake children. HTTP/3 uses unavailable recvmmsg
  # on this SDK; BoringSSL assembly is disabled until OHOS target selection is verified.
  python3 - "$cache/source/CMakeLists.txt" <<'PY'
import sys
p=sys.argv[1];s=open(p,encoding='utf8').read()
a='set(_common_cmake_args\n';b='      -DUSE_NGTCP2=ON\n      -DUSE_PROXY_HTTP3=ON'
assert s.count(a)==1 and s.count(b)==1
s=s.replace(a,'''if(CMAKE_SYSTEM_NAME STREQUAL "OHOS")
  list(APPEND _toolchain_cmake_args "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"
    "-DOHOS_ARCH=${OHOS_ARCH}" "-DOHOS_PLATFORM=${OHOS_PLATFORM}")
endif()

'''+a).replace(b,'      -DUSE_NGTCP2=OFF\n      -DUSE_PROXY_HTTP3=OFF')
open(p,'w',encoding='utf8').write(s)
PY
  export PATH="$sdk/build-tools/cmake/bin:$PATH"
  "$cmake" -S "$cache/source" -B "$cache/build" -G 'Unix Makefiles' \
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DOHOS_ARCH="$arch" -DOHOS_PLATFORM=OHOS \
    -DUSE_LIBIDN2=OFF -DDISABLE_BORINGSSL_ASM=ON \
    -DCMAKE_CXX_FLAGS='-Wno-error=unused-command-line-argument' \
    -DSUBJOBS="${KOMA_BUILD_JOBS:-4}" -DCURL_IMPERSONATE_VERSION=2.3.2 >&2
  "$cmake" --build "$cache/build" --parallel "${KOMA_BUILD_JOBS:-4}" >&2
  mkdir -p "$cache/target/lib" "$cache/target/include"
  cp "$cache/build/deps/build/curl/lib/libcurl-impersonate.so.4.8.0" "$cache/target/lib/"
  cp "$cache/build/deps/build/curl/lib/libcurl-impersonate.a" "$cache/target/lib/"
  for lib in libssl.a libcrypto.a libnghttp2.a libcares.a libbrotlidec.a libbrotlicommon.a libzstd.a libz.a; do
    cp "$cache/build/deps/install/lib/$lib" "$cache/target/lib/"
  done
  cp -R "$cache/build/deps/src/curl/include/curl" "$cache/target/include/"
  for lib in $required_libs; do [ -s "$cache/target/lib/$lib" ] || { echo "Missing built library: $lib" >&2; exit 1; }; done
  [ -s "$cache/target/include/curl/curl.h" ] && [ -s "$cache/target/include/curl/easy.h" ] || exit 1
  touch "$cache/.complete"
fi
printf '%s\n' "$cache/target"
