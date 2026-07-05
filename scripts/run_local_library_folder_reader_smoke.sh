#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

export KOMA_SOURCE_READER_PHASE="${KOMA_SOURCE_READER_PHASE:-local-library-folder-visible-reader}"
export KOMA_SOURCE_READER_REQUIRES_INDEX="${KOMA_SOURCE_READER_REQUIRES_INDEX:-false}"
export KOMA_SOURCE_READER_CAPTURE_UI="${KOMA_SOURCE_READER_CAPTURE_UI:-true}"
export KOMA_SOURCE_READER_ARTIFACT_DIR="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/local-library-folder-reader-smoke}"
exec scripts/run_source_reader_smoke.sh
