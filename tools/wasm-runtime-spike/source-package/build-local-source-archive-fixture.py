#!/usr/bin/env python3
import argparse
import hashlib
import json
import zipfile
from pathlib import Path


PACKAGE_ID = "local.test.koma.fixture"
PACKAGE_VERSION = "0.1.0"
MANIFEST_NAME = "manifest.generated.json"
WASM_NAME = "rust_source_runtime_fixture.wasm"
WASM_MAX_BYTES = 131072
FIXED_ZIP_DATE_TIME = (2024, 1, 1, 0, 0, 0)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def build_manifest(wasm_bytes: bytes) -> dict:
    return {
        "schemaVersion": 1,
        "package": {
            "id": PACKAGE_ID,
            "name": "Koma Local WASM Fixture",
            "version": PACKAGE_VERSION,
            "language": "en",
            "type": "wasm-source-fixture",
            "nsfw": False,
        },
        "runtime": {
            "abi": "koma-source-abi-v0.1",
            "hostAbi": "koma-host-v0.1",
            "wasmPath": WASM_NAME,
            "wasmSha256": sha256_bytes(wasm_bytes),
            "wasmSizeBytes": len(wasm_bytes),
            "maxWasmBytes": WASM_MAX_BYTES,
        },
        "permissions": {
            "network": False,
            "hostImports": ["koma_host.log", "koma_host.check_cancel"],
        },
        "contentPolicy": {
            "publicIndex": False,
            "marketplace": False,
            "builtInSource": False,
            "remoteInstall": False,
        },
    }


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, FIXED_ZIP_DATE_TIME)
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o644 << 16
    return info


def main() -> int:
    parser = argparse.ArgumentParser(description="Build deterministic test-only local source archive fixture.")
    parser.add_argument(
        "--wasm",
        default="entry/src/main/resources/rawfile/test/rust_source_runtime_fixture.wasm",
        help="Rust source runtime fixture wasm path, relative to repo root by default.",
    )
    parser.add_argument(
        "--output",
        default="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma-source",
        help="Archive fixture output path, relative to repo root by default.",
    )
    parser.add_argument("--report", help="Optional JSON report path.")
    args = parser.parse_args()

    root = repo_root()
    wasm_path = Path(args.wasm)
    if not wasm_path.is_absolute():
        wasm_path = root / wasm_path
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = root / output_path

    wasm_bytes = wasm_path.read_bytes()
    if not wasm_bytes.startswith(b"\0asm\x01\0\0\0"):
        raise SystemExit(f"wasm fixture magic/version mismatch: {wasm_path}")
    if len(wasm_bytes) <= 0 or len(wasm_bytes) > WASM_MAX_BYTES:
        raise SystemExit(f"wasm fixture size outside test boundary: {len(wasm_bytes)}")

    manifest = build_manifest(wasm_bytes)
    manifest_bytes = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode("utf-8")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_path, "w") as archive:
        archive.writestr(zip_info(MANIFEST_NAME), manifest_bytes)
        archive.writestr(zip_info(WASM_NAME), wasm_bytes)

    archive_bytes = output_path.read_bytes()
    report = {
        "status": "PASS",
        "archivePath": str(output_path),
        "archiveSha256": sha256_bytes(archive_bytes),
        "archiveSizeBytes": len(archive_bytes),
        "manifestPath": MANIFEST_NAME,
        "wasmPath": WASM_NAME,
        "wasmSha256": manifest["runtime"]["wasmSha256"],
        "wasmSizeBytes": manifest["runtime"]["wasmSizeBytes"],
        "packageId": PACKAGE_ID,
        "packageVersion": PACKAGE_VERSION,
        "network": False,
        "entries": [MANIFEST_NAME, WASM_NAME],
    }
    if args.report:
        report_path = Path(args.report)
        if not report_path.is_absolute():
            report_path = root / report_path
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
