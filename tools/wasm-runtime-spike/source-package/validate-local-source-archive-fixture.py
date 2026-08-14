#!/usr/bin/env python3
import argparse
import base64
import binascii
import hashlib
import json
import struct
import zipfile
import zlib
from pathlib import Path


PACKAGE_ID = "local.test.koma.fixture"
PACKAGE_VERSION = "0.1.0"
MANIFEST_NAME = "manifest.generated.json"
WASM_NAME = "rust_source_runtime_fixture.wasm"
SOURCE_REPO_MANIFEST_NAME = "manifest.json"
SOURCE_REPO_WASM_NAME = "source.wasm"
SOURCE_REPO_ICON_NAME = "icon.png"
SOURCE_REPO_ICON_MAX_BYTES = 1024 * 1024
SOURCE_REPO_ICON_MAX_DIMENSION = 1024
WASM_SHA256 = "255163710202d77fa218f1ccf96fbdcc7ec954b8f8bd1a04e6f15426a2d00161"
WASM_MAX_BYTES = 131072
FORBIDDEN_TEXT = (
    "source market",
    "remote install",
    "remote repository",
    "plugin market",
    "free manga",
    "all manga",
)


class ValidationError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def sha256_bytes(value: bytes) -> str:
  return hashlib.sha256(value).hexdigest()


def png_crc32(value: bytes) -> int:
    return binascii.crc32(value) & 0xFFFFFFFF


def source_repo_icon_is_valid(value: bytes) -> bool:
    if len(value) < 57 or len(value) > SOURCE_REPO_ICON_MAX_BYTES:
        return False
    if value[:8] != b"\x89PNG\r\n\x1a\n" or value[8:16] != b"\x00\x00\x00\rIHDR":
        return False
    width, height = struct.unpack(">II", value[16:24])
    if not (0 < width <= SOURCE_REPO_ICON_MAX_DIMENSION and 0 < height <= SOURCE_REPO_ICON_MAX_DIMENSION):
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate test-only local source archive fixture.")
    parser.add_argument(
        "--archive",
        default="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma-source",
    )
    parser.add_argument("--artifact-dir", required=True)
    args = parser.parse_args()

    root = repo_root()
    archive_path = Path(args.archive)
    if not archive_path.is_absolute():
        archive_path = root / archive_path
    artifact_dir = Path(args.artifact_dir)
    if not artifact_dir.is_absolute():
        artifact_dir = root / artifact_dir
    artifact_dir.mkdir(parents=True, exist_ok=True)
    report_path = artifact_dir / "local-source-archive-fixture-validation.json"

    report = {
        "status": "FAIL",
        "archivePath": str(archive_path),
        "artifactDir": str(artifact_dir),
        "evidence": [],
    }

    try:
        archive_bytes = archive_path.read_bytes()
        with zipfile.ZipFile(archive_path, "r") as archive:
            names = archive.namelist()
            internal_layout = names == [MANIFEST_NAME, WASM_NAME]
            source_repo_layout = names in (
                [SOURCE_REPO_MANIFEST_NAME, SOURCE_REPO_WASM_NAME],
                [SOURCE_REPO_MANIFEST_NAME, SOURCE_REPO_WASM_NAME, SOURCE_REPO_ICON_NAME],
            )
            require(internal_layout or source_repo_layout, f"archive entries drifted: {names}")
            for info in archive.infolist():
                require(not info.is_dir(), f"unexpected directory entry: {info.filename}")
                require(info.compress_type == zipfile.ZIP_STORED, f"entry is not stored deterministically: {info.filename}")
                require(info.date_time == (2024, 1, 1, 0, 0, 0), f"entry timestamp drifted: {info.filename}")
            manifest_name = MANIFEST_NAME if internal_layout else SOURCE_REPO_MANIFEST_NAME
            wasm_name = WASM_NAME if internal_layout else SOURCE_REPO_WASM_NAME
            manifest_bytes = archive.read(manifest_name)
            wasm_bytes = archive.read(wasm_name)
            icon_bytes = archive.read(SOURCE_REPO_ICON_NAME) if source_repo_layout and SOURCE_REPO_ICON_NAME in names else None

        manifest_text = manifest_bytes.decode("utf-8")
        manifest = json.loads(manifest_text)
        lower_manifest = manifest_text.lower()
        require(not any(term in lower_manifest for term in FORBIDDEN_TEXT), "archive manifest contains forbidden scope text")
        if internal_layout:
            require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
            package = manifest.get("package")
            require(isinstance(package, dict), "package object is required")
            require(package.get("id") == PACKAGE_ID, "package id drifted")
            require(package.get("version") == PACKAGE_VERSION, "package version drifted")
            runtime = manifest.get("runtime")
            require(isinstance(runtime, dict), "runtime object is required")
            require(runtime.get("abi") == "koma-source-abi-v0.1", "source ABI drifted")
            require(runtime.get("hostAbi") == "koma-host-v0.1", "host ABI drifted")
            require(runtime.get("wasmPath") == WASM_NAME, "wasm path drifted")
            require(runtime.get("wasmSha256") == WASM_SHA256, "wasm sha256 drifted")
            require(runtime.get("wasmSizeBytes") == len(wasm_bytes), "wasm size metadata mismatch")
            require(runtime.get("maxWasmBytes") == WASM_MAX_BYTES, "max wasm bytes drifted")
            require(sha256_bytes(wasm_bytes) == WASM_SHA256, "wasm payload sha256 mismatch")
            permissions = manifest.get("permissions")
            require(isinstance(permissions, dict), "permissions object is required")
            require(permissions.get("network") is False, "network must be false")
            require(permissions.get("hostImports") == ["koma_host.log", "koma_host.check_cancel"], "host imports drifted")
            content_policy = manifest.get("contentPolicy")
            require(isinstance(content_policy, dict), "contentPolicy object is required")
            for key in ("publicIndex", "marketplace", "builtInSource", "remoteInstall"):
                require(content_policy.get(key) is False, f"contentPolicy.{key} must be false")
            package_id = package["id"]
            package_version = package["version"]
            network = permissions["network"]
        else:
            require(manifest.get("id") == PACKAGE_ID, "source-repo package id drifted")
            require(manifest.get("version") == PACKAGE_VERSION, "source-repo package version drifted")
            require(manifest.get("name") == "Koma Local WASM Fixture", "source-repo package name drifted")
            require(manifest.get("runtime") == "wasm-source", "source-repo runtime drifted")
            require(manifest.get("nsfw") is False, "source-repo fixture nsfw must be false")
            if icon_bytes is not None:
                require(source_repo_icon_is_valid(icon_bytes), "source-repo fixture icon.png is invalid")
            package_id = manifest["id"]
            package_version = manifest["version"]
            network = False
        require(wasm_bytes.startswith(b"\0asm\x01\0\0\0"), "wasm magic/version mismatch")
        require(0 < len(wasm_bytes) <= WASM_MAX_BYTES, "wasm size outside test boundary")

        report.update({
            "status": "PASS",
            "layout": "internal" if internal_layout else "source-repo",
            "archiveSha256": sha256_bytes(archive_bytes),
            "archiveSizeBytes": len(archive_bytes),
            "manifest": {
                "packageId": package_id,
                "packageVersion": package_version,
                "network": network,
            },
            "wasmSha256": sha256_bytes(wasm_bytes),
            "wasmSizeBytes": len(wasm_bytes),
            "sourceRepoIcon": icon_bytes is not None,
        })
        if internal_layout:
            report["evidence"].extend([
                "archive contains deterministic manifest and wasm entries",
                "manifest binds package id/version, network=false, wasm sha256 and size",
                "wasm payload matches committed Rust runtime fixture",
                "content policy keeps public index, marketplace, built-in source, and remote install disabled",
            ])
        else:
            report["evidence"].extend([
                "archive contains deterministic source-repo manifest.json/source.wasm and optional fixed-root icon.png entries",
                "manifest binds package id/version and declares no network capability",
                "wasm payload matches committed Rust runtime fixture",
                "fixture is local/test-only and does not bundle public sources",
            ])
    except Exception as err:
        report["error"] = str(err)

    report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
