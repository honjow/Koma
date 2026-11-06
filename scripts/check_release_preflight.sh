#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

bash scripts/check-public-build-profile.sh --head
python3 scripts/check_release_notes.py
python3 scripts/check_i18n_duplicates.py

if [[ -z "${KOMA_TYPESCRIPT_PATH:-}" && -n "${COMMANDLINE_TOOLS_HOME:-}" ]]; then
  compiler_package="$(find "$COMMANDLINE_TOOLS_HOME" -path '*/node_modules/typescript/package.json' -print -quit)"
  if [[ -z "$compiler_package" ]]; then
    echo 'release preflight: TypeScript was not found in COMMANDLINE_TOOLS_HOME' >&2
    exit 1
  fi
  export KOMA_TYPESCRIPT_PATH="$(dirname "$compiler_package")"
fi

node scripts/check_backup_settings.cjs
node scripts/test_backup_task_state.cjs
node --test scripts/test_device_sync.cjs scripts/test_device_sync_journal.cjs
