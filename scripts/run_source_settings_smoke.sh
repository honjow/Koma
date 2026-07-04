#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

KOMA_SOURCE_READER_PHASE="${KOMA_SOURCE_READER_PHASE:-source-index-settings}" \
KOMA_SOURCE_READER_CAPTURE_UI="${KOMA_SOURCE_READER_CAPTURE_UI:-false}" \
KOMA_SOURCE_READER_ARTIFACT_DIR="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-settings-smoke}" \
  scripts/run_source_reader_smoke.sh
