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
            require(names == [MANIFEST_NAME, WASM_NAME], f"archive entries drifted: {names}")
            for info in archive.infolist():
                require(not info.is_dir(), f"unexpected directory entry: {info.filename}")
                require(info.compress_type == zipfile.ZIP_STORED, f"entry is not stored deterministically: {info.filename}")
                require(info.date_time == (2024, 1, 1, 0, 0, 0), f"entry timestamp drifted: {info.filename}")
            manifest_bytes = archive.read(MANIFEST_NAME)
            wasm_bytes = archive.read(WASM_NAME)

        manifest_text = manifest_bytes.decode("utf-8")
        manifest = json.loads(manifest_text)
        lower_manifest = manifest_text.lower()
        require(not any(term in lower_manifest for term in FORBIDDEN_TEXT), "archive manifest contains forbidden scope text")
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
        require(wasm_bytes.startswith(b"\0asm\x01\0\0\0"), "wasm magic/version mismatch")
        require(0 < len(wasm_bytes) <= WASM_MAX_BYTES, "wasm size outside test boundary")
        permissions = manifest.get("permissions")
        require(isinstance(permissions, dict), "permissions object is required")
        require(permissions.get("network") is False, "network must be false")
        require(permissions.get("hostImports") == ["koma_host.log", "koma_host.check_cancel"], "host imports drifted")
        content_policy = manifest.get("contentPolicy")
        require(isinstance(content_policy, dict), "contentPolicy object is required")
        for key in ("publicIndex", "marketplace", "builtInSource", "remoteInstall"):
            require(content_policy.get(key) is False, f"contentPolicy.{key} must be false")

        report.update({
            "status": "PASS",
            "archiveSha256": sha256_bytes(archive_bytes),
            "archiveSizeBytes": len(archive_bytes),
            "manifest": {
                "packageId": package["id"],
                "packageVersion": package["version"],
                "network": permissions["network"],
            },
            "wasmSha256": sha256_bytes(wasm_bytes),
            "wasmSizeBytes": len(wasm_bytes),
        })
        report["evidence"].extend([
            "archive contains deterministic manifest and wasm entries",
            "manifest binds package id/version, network=false, wasm sha256 and size",
            "wasm payload matches committed Rust runtime fixture",
            "content policy keeps public index, marketplace, built-in source, and remote install disabled",
        ])
    except Exception as err:
        report["error"] = str(err)

    report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
