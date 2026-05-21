#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
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


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, FIXED_ZIP_DATE_TIME)
    info.compress_type = zipfile.ZIP_STORED
    info.external_attr = 0o644 << 16
    return info


def build_manifest(wasm_bytes: bytes, *, network: bool = False) -> dict:
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
            "network": network,
            "hostImports": ["koma_host.log", "koma_host.check_cancel"],
        },
        "contentPolicy": {
            "publicIndex": False,
            "marketplace": False,
            "builtInSource": False,
            "remoteInstall": False,
        },
    }


def encode_manifest(manifest: dict) -> bytes:
    return json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode("utf-8")


def write_archive(path: Path, entries: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w") as archive:
        for name, payload in entries:
            archive.writestr(zip_info(name), payload)


def read_entries(path: Path) -> set[str]:
    with zipfile.ZipFile(path, "r") as archive:
        return {info.filename for info in archive.infolist()}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build deterministic rawfile negative .koma-source fixtures for device archive smoke."
    )
    parser.add_argument(
        "--wasm",
        default="entry/src/main/resources/rawfile/test/rust_source_runtime_fixture.wasm",
    )
    parser.add_argument(
        "--output-dir",
        default="entry/src/main/resources/rawfile/test/archive-negative",
    )
    parser.add_argument("--report", help="Optional JSON report path.")
    args = parser.parse_args()

    root = repo_root()
    wasm_path = Path(args.wasm)
    if not wasm_path.is_absolute():
        wasm_path = root / wasm_path
    output_dir = Path(args.output_dir)
    if not output_dir.is_absolute():
        output_dir = root / output_dir

    wasm_bytes = wasm_path.read_bytes()
    if not wasm_bytes.startswith(b"\0asm\x01\0\0\0"):
        raise SystemExit(f"wasm fixture magic/version mismatch: {wasm_path}")
    if len(wasm_bytes) <= 0 or len(wasm_bytes) > WASM_MAX_BYTES:
        raise SystemExit(f"wasm fixture size outside test boundary: {len(wasm_bytes)}")

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    baseline_manifest = build_manifest(wasm_bytes)
    baseline_manifest_bytes = encode_manifest(baseline_manifest)
    tampered_wasm = bytearray(wasm_bytes)
    tampered_wasm[-1] = (tampered_wasm[-1] + 1) % 256

    fixtures = [
        {
            "id": "checksum_mismatch",
            "expectedReason": "checksum_mismatch",
            "entries": [(MANIFEST_NAME, baseline_manifest_bytes), (WASM_NAME, bytes(tampered_wasm))],
        },
        {
            "id": "network_not_allowed",
            "expectedReason": "network_not_allowed",
            "entries": [(MANIFEST_NAME, encode_manifest(build_manifest(wasm_bytes, network=True))), (WASM_NAME, wasm_bytes)],
        },
        {
            "id": "unsafe_archive_entry",
            "expectedReason": "unsafe_archive_entry",
            "entries": [(MANIFEST_NAME, baseline_manifest_bytes), (WASM_NAME, wasm_bytes), ("../escape.txt", b"blocked")],
        },
        {
            "id": "missing_manifest",
            "expectedReason": "missing_manifest",
            "entries": [(WASM_NAME, wasm_bytes)],
        },
        {
            "id": "missing_wasm",
            "expectedReason": "missing_wasm",
            "entries": [(MANIFEST_NAME, baseline_manifest_bytes)],
        },
    ]

    cases = []
    for fixture in fixtures:
        path = output_dir / f"{fixture['id']}.koma-source"
        write_archive(path, fixture["entries"])
        entries = sorted(read_entries(path))
        cases.append({
            "id": fixture["id"],
            "path": str(path.relative_to(root)),
            "expectedReason": fixture["expectedReason"],
            "archiveSha256": sha256_bytes(path.read_bytes()),
            "archiveSizeBytes": path.stat().st_size,
            "entries": entries,
        })

    report = {
        "status": "PASS",
        "fixtureDir": str(output_dir),
        "caseCount": len(cases),
        "cases": cases,
        "notes": [
            "device smoke uses these rawfiles through the same archive import validation helper as the happy archive",
            "fixtures are minimal ZIP_STORED archives generated from the checked-in Rust wasm fixture",
        ],
    }
    if args.report:
        report_path = Path(args.report)
        if not report_path.is_absolute():
            report_path = root / report_path
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
