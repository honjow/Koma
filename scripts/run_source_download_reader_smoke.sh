#!/usr/bin/env bash
set -euo pipefail

export KOMA_SOURCE_READER_PHASE="${KOMA_SOURCE_READER_PHASE:-source-index-visible-download-reader}"
export KOMA_SOURCE_READER_ARTIFACT_DIR="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-download-reader-smoke}"
exec "$(dirname "$0")/run_source_reader_smoke.sh"
