#!/usr/bin/env bash
set -euo pipefail
SRC_DIR="${1:-/home/gamer/git/V2Next/scripts}"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in xiaobai.p12 xiaobai.csr koma-debug.cer koma-debug.p7b; do
  if [ -f "$SRC_DIR/$f" ]; then
    install -m 600 "$SRC_DIR/$f" "$DST_DIR/$f"
  fi
done
# Accept V2Next existing debug materials as seed only when Koma-specific names are absent.
[ -f "$DST_DIR/koma-debug.cer" ] || [ ! -f "$SRC_DIR/next2v-debug.cer" ] || install -m 600 "$SRC_DIR/next2v-debug.cer" "$DST_DIR/koma-debug.cer"
[ -f "$DST_DIR/koma-debug.p7b" ] || [ ! -f "$SRC_DIR/next2v-debug.p7b" ] || install -m 600 "$SRC_DIR/next2v-debug.p7b" "$DST_DIR/koma-debug.p7b"
