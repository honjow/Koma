#!/usr/bin/env bash
set -euo pipefail
SRC_DIR="${1:-/home/gamer/git/V2Next/scripts}"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in xiaobai.p12 xiaobai.csr next2v-debug.cer next2v-debug.p7b; do
  if [ -f "$SRC_DIR/$f" ]; then
    install -m 600 "$SRC_DIR/$f" "$DST_DIR/$f"
  fi
done
