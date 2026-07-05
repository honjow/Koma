#!/usr/bin/env bash
set -euo pipefail

export KOMA_SOURCE_READER_PHASE="${KOMA_SOURCE_READER_PHASE:-source-index-download-corrupt-reader}"
export KOMA_SOURCE_READER_CAPTURE_UI="${KOMA_SOURCE_READER_CAPTURE_UI:-true}"
export KOMA_SOURCE_READER_ARTIFACT_DIR="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-corrupt-download-reader-smoke}"
exec "$(dirname "$0")/run_source_reader_smoke.sh"
