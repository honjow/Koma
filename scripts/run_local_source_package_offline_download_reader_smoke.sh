#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

export KOMA_SOURCE_READER_PHASE="${KOMA_SOURCE_READER_PHASE:-local-source-package-visible-offline-download-reader}"
export KOMA_SOURCE_READER_REQUIRES_INDEX="${KOMA_SOURCE_READER_REQUIRES_INDEX:-false}"
export KOMA_SOURCE_READER_CAPTURE_UI="${KOMA_SOURCE_READER_CAPTURE_UI:-true}"
export KOMA_SOURCE_PACKAGE_PATH="${KOMA_SOURCE_PACKAGE_PATH:-$repo/../koma-sources/dist/sources/mangadex/mangadex-0.1.0.koma}"
export KOMA_SOURCE_READER_ARTIFACT_DIR="${KOMA_SOURCE_READER_ARTIFACT_DIR:-.hvigor/outputs/local-source-package-offline-download-reader-smoke}"
exec scripts/run_source_reader_smoke.sh
