#!/usr/bin/env bash
set -euo pipefail

deveco_home="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
hvigorw="${HVIGORW:-$deveco_home/tools/hvigor/bin/hvigorw}"
node_home="${KOMA_NODE_HOME:-$deveco_home/tools/node}"

if [ ! -x "$hvigorw" ]; then
  echo "hvigorw 不存在或不可执行: $hvigorw" >&2
  exit 1
fi
if [ ! -x "$node_home/bin/node" ]; then
  echo "DevEco Node 不存在或不可执行: $node_home/bin/node" >&2
  exit 1
fi

export NODE_HOME="$node_home"
export PATH="$node_home/bin:$PATH"
exec "$hvigorw" "$@"
