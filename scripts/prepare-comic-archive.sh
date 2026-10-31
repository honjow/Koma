#!/usr/bin/env bash
set -euo pipefail
# Only archive codecs are built; no external archiver executable or system-private library.
sdk="${1:?Pass the OpenHarmony native SDK directory}"
cache_root="${2:?Pass the ignored codec cache}"
arch="${3:-arm64-v8a}"
case "$arch" in
  arm64-v8a) triple=aarch64-linux-ohos ;;
  x86_64) triple=x86_64-linux-ohos ;;
  *) echo "Unsupported archive codec architecture: $arch" >&2; exit 1 ;;
esac
mkdir -p "$cache_root"
cache_root="$(cd "$cache_root" && pwd)"
cmake="$sdk/build-tools/cmake/bin/cmake"
toolchain="$sdk/build/cmake/ohos.toolchain.cmake"
recipe_hash="$(shasum -a 256 "$0" | awk '{print $1}')"
sdk_hash="$(shasum -a 256 "$sdk/oh-uni-package.json" "$toolchain" "$sdk/llvm/bin/clang" | shasum -a 256 | awk '{print $1}')"
key="$(printf '%s\n%s\n%s\n' "$recipe_hash" "$sdk_hash" "$arch" | shasum -a 256 | cut -c1-16)"
cache="$cache_root/$key"
target="$cache/target"
mkdir -p "$cache_root/downloads" "$cache/source" "$target/lib" "$target/include"
fetch() {
  local name="$1" expected="$2" url="$3" file="$cache_root/downloads/$1"
  if [ ! -f "$file" ]; then
    curl -fL --max-time 120 "$url" -o "$file.tmp" >&2
    mv "$file.tmp" "$file"
  fi
  [ "$(shasum -a 256 "$file" | awk '{print $1}')" = "$expected" ] || { echo "$name checksum mismatch" >&2; exit 1; }
}
fetch libarchive-3.8.11.tar.xz a3dc0872b1b39da34dc18ef1b944f0f11ffd37425d70ae04be679279f1cf43d2 https://github.com/libarchive/libarchive/releases/download/v3.8.11/libarchive-3.8.11.tar.xz
fetch xz-5.8.4.tar.xz 4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.xz
fetch bzip2-1.0.8.tar.gz ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269 https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
if [ ! -f "$cache/.complete" ] || [ ! -s "$target/lib/libarchive.a" ] || [ ! -s "$target/lib/liblzma.a" ] || [ ! -s "$target/lib/libbz2.a" ]; then
  for dep in libarchive xz bzip2; do mkdir -p "$cache/source/$dep"; done
  tar -xJf "$cache_root/downloads/libarchive-3.8.11.tar.xz" -C "$cache/source/libarchive" --strip-components=1
  tar -xJf "$cache_root/downloads/xz-5.8.4.tar.xz" -C "$cache/source/xz" --strip-components=1
  tar -xzf "$cache_root/downloads/bzip2-1.0.8.tar.gz" -C "$cache/source/bzip2" --strip-components=1
  common=(-G Ninja -DCMAKE_MAKE_PROGRAM="$sdk/build-tools/cmake/bin/ninja"
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DOHOS_ARCH="$arch" -DOHOS_PLATFORM=OHOS
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_INSTALL_PREFIX="$target")
  "$cmake" -S "$cache/source/xz" -B "$cache/xz-build" "${common[@]}" \
    -DBUILD_TESTING=OFF -DXZ_TOOL_XZ=OFF -DXZ_TOOL_XZDEC=OFF -DXZ_TOOL_LZMADEC=OFF \
    -DXZ_TOOL_LZMAINFO=OFF -DXZ_TOOL_SCRIPTS=OFF -DXZ_DOC=OFF -DXZ_NLS=OFF >&2
  "$cmake" --build "$cache/xz-build" --parallel "${KOMA_BUILD_JOBS:-4}" >&2
  "$cmake" --install "$cache/xz-build" >&2
  # bzip2's upstream Makefile does not provide a cross CMake project.
  mkdir -p "$cache/bzip2-build"
  for unit in blocksort huffman crctable randtable compress decompress bzlib; do
    "$sdk/llvm/bin/clang" --target="$triple" --sysroot="$sdk/sysroot" -fPIC -O2 \
      -I"$cache/source/bzip2" -c "$cache/source/bzip2/$unit.c" -o "$cache/bzip2-build/$unit.o"
  done
  "$sdk/llvm/bin/llvm-ar" rcs "$target/lib/libbz2.a" "$cache/bzip2-build/"*.o
  cp "$cache/source/bzip2/bzlib.h" "$target/include/"
  "$cmake" -S "$cache/source/libarchive" -B "$cache/archive-build" "${common[@]}" \
    -DENABLE_TEST=OFF -DENABLE_TAR=OFF -DENABLE_CPIO=OFF -DENABLE_CAT=OFF -DENABLE_UNZIP=OFF \
    -DENABLE_OPENSSL=OFF -DENABLE_MBEDTLS=OFF -DENABLE_NETTLE=OFF -DENABLE_LIBB2=OFF -DENABLE_MD=OFF \
    -DENABLE_LZ4=OFF -DENABLE_LZO=OFF -DENABLE_ZSTD=OFF -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
    -DENABLE_PCREPOSIX=OFF -DENABLE_PCRE2POSIX=OFF -DENABLE_ACL=OFF -DENABLE_XATTR=OFF \
    -DLIBLZMA_INCLUDE_DIR="$target/include" -DLIBLZMA_LIBRARY="$target/lib/liblzma.a" \
    -DBZIP2_INCLUDE_DIR="$target/include" -DBZIP2_LIBRARIES="$target/lib/libbz2.a" >&2
  "$cmake" --build "$cache/archive-build" --target archive_static --parallel "${KOMA_BUILD_JOBS:-4}" >&2
  for feature in HAVE_LZMA_H HAVE_BZLIB_H HAVE_ZLIB_H; do
    grep -q "^#define $feature 1$" "$cache/archive-build/config.h" || { echo "Missing archive codec: $feature" >&2; exit 1; }
  done
  cp "$cache/archive-build/libarchive/libarchive.a" "$target/lib/"
  cp "$cache/source/libarchive/libarchive/"archive*.h "$target/include/"
  touch "$cache/.complete"
fi
printf '%s\n' "$target"
