#!/usr/bin/env python3
"""Validate the optional fixed-root icon.png contract for source-repo packages.

This is a host-side fixture contract only.  It never executes WASM, contacts a
source index, installs an app, or writes a product package.  The generated
archives stay below the caller-provided artifact directory.
"""

import argparse
import base64
import binascii
import hashlib
import json
import re
import shutil
import stat
import struct
import zipfile
import zlib
from pathlib import Path


SOURCE_REPO_MANIFEST = "manifest.json"
SOURCE_REPO_WASM = "source.wasm"
SOURCE_REPO_ICON = "icon.png"
LEGACY_MANIFEST = "manifest.generated.json"
LEGACY_WASM = "rust_source_runtime_fixture.wasm"
MAX_ICON_BYTES = 1024 * 1024
MAX_ICON_DIMENSION = 1024
FIXED_ZIP_DATE_TIME = (2024, 1, 1, 0, 0, 0)

# A checked, test-only 1x1 PNG.  It is deliberately not a product/source
# identity asset; source packages carry their own real icon.png files.
VALID_ICON_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOot8/4DwAEjQImF5xSzQAAAABJRU5ErkJggg=="
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ValidationError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, FIXED_ZIP_DATE_TIME)
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o644 << 16
    return info


def write_archive(path: Path, entries: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w") as archive:
        for name, payload in entries:
            archive.writestr(zip_info(name), payload)


def write_icon_symlink_archive(path: Path, entries: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w") as archive:
        for name, payload in entries:
            archive.writestr(zip_info(name), payload)
        info = zipfile.ZipInfo(SOURCE_REPO_ICON, FIXED_ZIP_DATE_TIME)
        info.create_system = 3
        info.compress_type = zipfile.ZIP_STORED
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(info, b"other.png")


def archive_entries(path: Path) -> list[tuple[zipfile.ZipInfo, bytes]]:
    with zipfile.ZipFile(path, "r") as archive:
        return [(info, archive.read(info)) for info in archive.infolist()]


def zip_entry_is_symlink(info: zipfile.ZipInfo) -> bool:
    return stat.S_ISLNK((info.external_attr >> 16) & 0o777777)


def is_safe_archive_entry_name(name: str) -> bool:
    if not name or name.endswith("/") or name.startswith("/") or "\\" in name:
        return False
    parts = name.split("/")
    return all(part and part != ".." and not part.startswith(".") for part in parts)


def png_crc32(value: bytes) -> int:
    return binascii.crc32(value) & 0xFFFFFFFF


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", png_crc32(kind + payload))


def indexed_palette_icon_png() -> bytes:
    """A valid 1x1 8-bit indexed PNG, assembled without a product logo asset."""
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 3, 0, 0, 0)
    plte = b"\x58\x62\xa9"
    image_data = zlib.compress(b"\x00\x00")
    return PNG_SIGNATURE + png_chunk(b"IHDR", ihdr) + png_chunk(b"PLTE", plte) + png_chunk(b"IDAT", image_data) + png_chunk(b"IEND", b"")


VALID_INDEXED_ICON_PNG = indexed_palette_icon_png()


def is_valid_icon_bytes(value: bytes) -> bool:
    if len(value) < 57 or len(value) > MAX_ICON_BYTES:
        return False
    if value[:8] != PNG_SIGNATURE:
        return False
    if value[8:12] != b"\x00\x00\x00\r" or value[12:16] != b"IHDR":
        return False
    width, height = struct.unpack(">II", value[16:24])
    if not (0 < width <= MAX_ICON_DIMENSION and 0 < height <= MAX_ICON_DIMENSION):
        return False
    bit_depth, color_type, compression, filter_method, interlace = value[24:29]
    direct_color_type = color_type in (0, 2, 4, 6)
    indexed_color_type = color_type == 3
    if (
        (not direct_color_type and not indexed_color_type)
        or (direct_color_type and bit_depth not in (8, 16))
        or (indexed_color_type and bit_depth != 8)
    ):
        return False
    if compression != 0 or filter_method != 0 or interlace != 0:
        return False
    offset = 8
    image_data = bytearray()
    while offset + 12 <= len(value):
        length = struct.unpack(">I", value[offset : offset + 4])[0]
        kind = value[offset + 4 : offset + 8]
        payload = value[offset + 8 : offset + 8 + length]
        crc = struct.unpack(">I", value[offset + 8 + length : offset + 12 + length])[0] if offset + 12 + length <= len(value) else -1
        next_offset = offset + 12 + length
        if next_offset > len(value):
            return False
        if png_crc32(kind + payload) != crc:
            return False
        if offset == 8 and (kind != b"IHDR" or length != 13):
            return False
        if kind == b"IDAT" and length > 0:
            image_data.extend(payload)
        if kind == b"IEND":
            if length != 0 or not image_data or next_offset != len(value):
                return False
            try:
                zlib.decompress(bytes(image_data))
                return True
            except zlib.error:
                return False
        offset = next_offset
    return False


def source_archive_reason(path: Path) -> str | None:
    """Mirror only the archive/icon admission boundary used by the ArkTS host."""
    entries = archive_entries(path)
    names = [info.filename for info, _payload in entries]
    seen: set[str] = set()
    has_legacy_manifest = False
    has_source_repo_manifest = False
    root_icon: tuple[zipfile.ZipInfo, bytes] | None = None

    for info, payload in entries:
        name = info.filename
        if name in seen or not is_safe_archive_entry_name(name) or zip_entry_is_symlink(info):
            return "unsafe_archive_entry"
        seen.add(name)
        if name == LEGACY_MANIFEST:
            has_legacy_manifest = True
        elif name == SOURCE_REPO_MANIFEST:
            has_source_repo_manifest = True
        elif name == SOURCE_REPO_ICON:
            root_icon = (info, payload)

    if has_legacy_manifest and has_source_repo_manifest:
        return "unsafe_archive_entry"
    if not has_legacy_manifest and not has_source_repo_manifest:
        return "missing_manifest"

    expected_manifest = LEGACY_MANIFEST if has_legacy_manifest else SOURCE_REPO_MANIFEST
    expected_wasm = LEGACY_WASM if has_legacy_manifest else SOURCE_REPO_WASM
    expected_icon = SOURCE_REPO_ICON if has_source_repo_manifest else ""
    if any(name not in {expected_manifest, expected_wasm, expected_icon} for name in names):
        return "unsafe_archive_entry"

    if root_icon is not None:
        info, payload = root_icon
        if info.file_size <= 0 or info.file_size > MAX_ICON_BYTES:
            return "invalid_icon"
        if not is_valid_icon_bytes(payload):
            return "invalid_icon"
    return None


def read_fixture_base(
    path: Path,
    expected_names: list[str],
    allow_optional_source_repo_icon: bool = False,
) -> list[tuple[str, bytes]]:
    entries = archive_entries(path)
    names = [info.filename for info, _payload in entries]
    allowed_names = [expected_names]
    if allow_optional_source_repo_icon:
        allowed_names.append(expected_names + [SOURCE_REPO_ICON])
    require(names in allowed_names, f"fixture entries drifted for {path}: {names}")
    for info, _payload in entries:
        require(not info.is_dir(), f"fixture contains a directory entry: {info.filename}")
        require(info.compress_type == zipfile.ZIP_STORED, f"fixture entry is not stored: {info.filename}")
        require(info.date_time == FIXED_ZIP_DATE_TIME, f"fixture timestamp drifted: {info.filename}")
    return [(info.filename, payload) for info, payload in entries]


def assert_importer_binding(importer_path: Path) -> None:
    source = importer_path.read_text(encoding="utf-8")
    required_patterns = (
        r"export const SOURCE_REPO_PACKAGE_ICON_FILE:\s*string\s*=\s*'icon\.png'",
        r"export const SOURCE_REPO_PACKAGE_ICON_MAX_BYTES:\s*number\s*=\s*1024\s*\*\s*1024",
        r"export const SOURCE_REPO_PACKAGE_ICON_MAX_DIMENSION:\s*number\s*=\s*1024",
        r"const expectedIcon = hasSourceRepoManifest \? SOURCE_REPO_PACKAGE_ICON_FILE : ''",
        r"export function validateSourcePackageIconBytes\(iconBytes: Uint8Array\): boolean",
        r"iconBytes\[12\].*0x49.*iconBytes\[13\].*0x48.*iconBytes\[14\].*0x44.*iconBytes\[15\].*0x52",
        r"width > SOURCE_REPO_PACKAGE_ICON_MAX_DIMENSION",
        r"height > SOURCE_REPO_PACKAGE_ICON_MAX_DIMENSION",
        r"let sawImageData = false",
        r"const indexedColorType = colorType === 3",
        r"isIdat && chunkLength > 0",
        r"pngCrc32\(iconBytes, typeOffset, 4 \+ chunkLength\)",
        r"isIend.*sawImageData.*nextOffset === iconBytes\.byteLength",
        r"export async function validateSourcePackageIconFile\(iconPath: string\): Promise<boolean>",
        r"image\.createImageSource\(iconPath\)",
        r"await imageSource\.createPixelMap",
        r"await pixelMap\.release\(\)",
        r"await imageSource\.release\(\)",
        r"iconPath\?: string",
        r"externalAttributes: readUInt32Le\(archiveBytes, offset \+ 38\)",
        r"archiveEntryIsSymlink\(entry\)",
    )
    for pattern in required_patterns:
        require(re.search(pattern, source, re.DOTALL) is not None, f"importer icon contract drifted: {pattern}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate and validate source-repo optional icon.png contract archives."
    )
    parser.add_argument(
        "--archive",
        default="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma",
        help="Checked-in source-repo fixture used as manifest/source.wasm baseline.",
    )
    parser.add_argument(
        "--legacy-archive",
        default="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma-source",
        help="Checked-in legacy fixture used to prove icon.png stays source-repo-only.",
    )
    parser.add_argument(
        "--importer",
        default="entry/src/main/ets/sourceRuntime/SourcePackageImporter.ets",
        help="ArkTS importer whose fixed icon contract is asserted.",
    )
    parser.add_argument("--artifact-dir", required=True)
    args = parser.parse_args()

    root = repo_root()
    archive_path = Path(args.archive)
    legacy_archive_path = Path(args.legacy_archive)
    importer_path = Path(args.importer)
    artifact_dir = Path(args.artifact_dir)
    if not archive_path.is_absolute():
        archive_path = root / archive_path
    if not legacy_archive_path.is_absolute():
        legacy_archive_path = root / legacy_archive_path
    if not importer_path.is_absolute():
        importer_path = root / importer_path
    if not artifact_dir.is_absolute():
        artifact_dir = root / artifact_dir
    fixture_dir = artifact_dir / "source-repo-icon-archives"
    report_path = artifact_dir / "source-repo-icon-fixtures-report.json"

    report: dict = {
        "status": "FAIL",
        "fixture": str(archive_path),
        "legacyFixture": str(legacy_archive_path),
        "importer": str(importer_path),
        "maxIconBytes": MAX_ICON_BYTES,
        "maxIconDimension": MAX_ICON_DIMENSION,
        "cases": [],
    }

    try:
        assert_importer_binding(importer_path)
        source_repo_fixture_entries = read_fixture_base(
            archive_path,
            [SOURCE_REPO_MANIFEST, SOURCE_REPO_WASM],
            allow_optional_source_repo_icon=True,
        )
        fixture_icon_entries = [payload for name, payload in source_repo_fixture_entries if name == SOURCE_REPO_ICON]
        require(len(fixture_icon_entries) <= 1, "source-repo fixture contains more than one icon.png")
        if fixture_icon_entries:
            require(is_valid_icon_bytes(fixture_icon_entries[0]), "checked-in source-repo fixture icon.png is invalid")
        source_repo_entries = [
            (name, payload) for name, payload in source_repo_fixture_entries if name != SOURCE_REPO_ICON
        ]
        legacy_entries = read_fixture_base(legacy_archive_path, [LEGACY_MANIFEST, LEGACY_WASM])
        require(is_valid_icon_bytes(VALID_ICON_PNG), "test icon must be a valid bounded PNG")
        require(is_valid_icon_bytes(VALID_INDEXED_ICON_PNG), "indexed palette test icon must be valid")

        if fixture_dir.exists():
            shutil.rmtree(fixture_dir)
        fixture_dir.mkdir(parents=True, exist_ok=True)

        oversized_icon = b"\x00" * (MAX_ICON_BYTES + 1)
        oversized_dimension_icon = (
            PNG_SIGNATURE + b"\x00\x00\x00\rIHDR" + struct.pack(">II", MAX_ICON_DIMENSION + 1, 1)
        )
        truncated_icon = PNG_SIGNATURE + b"\x00\x00\x00\rIHDR" + struct.pack(">II", 1, 1)
        corrupted_crc_icon = bytearray(VALID_ICON_PNG)
        corrupted_crc_icon[-1] ^= 0x01
        cases: list[tuple[str, str | None, list[tuple[str, bytes]]]] = [
            ("source_repo_icon_optional_absent", None, source_repo_entries),
            ("source_repo_valid_root_icon", None, source_repo_entries + [(SOURCE_REPO_ICON, VALID_ICON_PNG)]),
            ("source_repo_valid_indexed_root_icon", None, source_repo_entries + [(SOURCE_REPO_ICON, VALID_INDEXED_ICON_PNG)]),
            ("source_repo_nested_icon_rejected", "unsafe_archive_entry", source_repo_entries + [("assets/icon.png", VALID_ICON_PNG)]),
            ("legacy_root_icon_rejected", "unsafe_archive_entry", legacy_entries + [(SOURCE_REPO_ICON, VALID_ICON_PNG)]),
            ("source_repo_non_png_icon_rejected", "invalid_icon", source_repo_entries + [(SOURCE_REPO_ICON, b"not-a-png")]),
            ("source_repo_oversized_icon_rejected", "invalid_icon", source_repo_entries + [(SOURCE_REPO_ICON, oversized_icon)]),
            ("source_repo_oversized_dimension_icon_rejected", "invalid_icon", source_repo_entries + [(SOURCE_REPO_ICON, oversized_dimension_icon)]),
            ("source_repo_truncated_icon_rejected", "invalid_icon", source_repo_entries + [(SOURCE_REPO_ICON, truncated_icon)]),
            ("source_repo_bad_crc_icon_rejected", "invalid_icon", source_repo_entries + [(SOURCE_REPO_ICON, bytes(corrupted_crc_icon))]),
        ]

        for case_id, expected_reason, entries in cases:
            archive = fixture_dir / f"{case_id}.koma"
            write_archive(archive, entries)
            actual_reason = source_archive_reason(archive)
            status = "PASS" if actual_reason == expected_reason else "FAIL"
            report["cases"].append({
                "id": case_id,
                "status": status,
                "expectedReason": expected_reason,
                "actualReason": actual_reason,
                "archiveSha256": sha256_bytes(archive.read_bytes()),
                "entries": [info.filename for info, _payload in archive_entries(archive)],
            })
            require(status == "PASS", f"{case_id}: expected {expected_reason}, got {actual_reason}")

        symlink_archive = fixture_dir / "source_repo_icon_symlink_rejected.koma"
        write_icon_symlink_archive(symlink_archive, source_repo_entries)
        symlink_reason = source_archive_reason(symlink_archive)
        symlink_status = "PASS" if symlink_reason == "unsafe_archive_entry" else "FAIL"
        report["cases"].append({
            "id": "source_repo_icon_symlink_rejected",
            "status": symlink_status,
            "expectedReason": "unsafe_archive_entry",
            "actualReason": symlink_reason,
            "archiveSha256": sha256_bytes(symlink_archive.read_bytes()),
            "entries": [info.filename for info, _payload in archive_entries(symlink_archive)],
        })
        require(symlink_status == "PASS", f"source_repo_icon_symlink_rejected: expected unsafe_archive_entry, got {symlink_reason}")

        report["status"] = "PASS"
        report["evidence"] = [
            "source-repo packages accept no icon or exactly one bounded fixed-root icon.png",
            "legacy/internal package layout still rejects root icon.png",
            "nested, symlink, non-PNG, oversized-byte, and oversized-dimension icon cases fail closed",
            "the ArkTS importer declares the same fixed-root PNG boundary",
        ]
    except Exception as err:  # keep a machine-readable failure artifact
        report["error"] = str(err)

    artifact_dir.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
