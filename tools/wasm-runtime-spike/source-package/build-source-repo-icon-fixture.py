#!/usr/bin/env python3
"""Regenerate Koma's checked-in test-only source-repo archive with icon.png.

The fixture proves the optional package-owned icon path. Its one-pixel indexed
PNG is not product branding and is never used as a real source identity asset.
"""

import argparse
import binascii
import hashlib
import json
import os
import struct
import zipfile
import zlib
from pathlib import Path


SOURCE_REPO_MANIFEST = "manifest.json"
SOURCE_REPO_WASM = "source.wasm"
SOURCE_REPO_ICON = "icon.png"
FIXED_ZIP_DATE_TIME = (2024, 1, 1, 0, 0, 0)

def png_chunk(kind: bytes, payload: bytes) -> bytes:
    crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def test_only_indexed_icon_png() -> bytes:
    """Build a valid 1x1 8-bit indexed PNG without adding a brand asset."""
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 3, 0, 0, 0)
    palette = b"\x58\x62\xa9"
    image_data = zlib.compress(b"\x00\x00")
    return signature + png_chunk(b"IHDR", ihdr) + png_chunk(b"PLTE", palette) + png_chunk(b"IDAT", image_data) + png_chunk(b"IEND", b"")


TEST_ONLY_ICON_PNG = test_only_indexed_icon_png()


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, FIXED_ZIP_DATE_TIME)
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o644 << 16
    return info


def main() -> int:
    parser = argparse.ArgumentParser(description="Regenerate the source-repo icon smoke fixture.")
    parser.add_argument(
        "--archive",
        default="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma",
        help="Checked-in fixture to update in place.",
    )
    parser.add_argument("--report", required=True)
    args = parser.parse_args()

    root = repo_root()
    archive_path = Path(args.archive)
    report_path = Path(args.report)
    if not archive_path.is_absolute():
        archive_path = root / archive_path
    if not report_path.is_absolute():
        report_path = root / report_path

    with zipfile.ZipFile(archive_path, "r") as archive:
        names = archive.namelist()
        if names not in (
            [SOURCE_REPO_MANIFEST, SOURCE_REPO_WASM],
            [SOURCE_REPO_MANIFEST, SOURCE_REPO_WASM, SOURCE_REPO_ICON],
        ):
            raise ValueError(f"unexpected source-repo fixture entries: {names}")
        manifest = archive.read(SOURCE_REPO_MANIFEST)
        wasm = archive.read(SOURCE_REPO_WASM)

    temporary_path = archive_path.with_name(archive_path.name + ".tmp")
    with zipfile.ZipFile(temporary_path, "w") as archive:
        archive.writestr(zip_info(SOURCE_REPO_MANIFEST), manifest)
        archive.writestr(zip_info(SOURCE_REPO_WASM), wasm)
        archive.writestr(zip_info(SOURCE_REPO_ICON), TEST_ONLY_ICON_PNG)
    os.replace(temporary_path, archive_path)

    report = {
        "status": "PASS",
        "archive": str(archive_path),
        "entries": [SOURCE_REPO_MANIFEST, SOURCE_REPO_WASM, SOURCE_REPO_ICON],
        "iconByteCount": len(TEST_ONLY_ICON_PNG),
        "iconSha256": sha256_bytes(TEST_ONLY_ICON_PNG),
        "note": "test-only source-repo package asset; not a production source logo",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
