#!/usr/bin/env bash
set -euo pipefail

export KOMA_SOURCE_BROWSE_DOWNLOAD_FIRST="${KOMA_SOURCE_BROWSE_DOWNLOAD_FIRST:-true}"
export KOMA_SOURCE_BROWSE_READER_ARTIFACT_DIR="${KOMA_SOURCE_BROWSE_READER_ARTIFACT_DIR:-.hvigor/outputs/source-browse-detail-download-reader-smoke}"
exec "$(dirname "$0")/run_source_browse_detail_reader_smoke.sh"
