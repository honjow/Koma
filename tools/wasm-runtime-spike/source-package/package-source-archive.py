#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redacted_command, redact_text, redact_value, write_redacted_json  # noqa: E402


HOST_ABI = "koma-host-v0.1"
HOST_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
CONTENT_POLICY_KEYS = ("publicIndex", "marketplace", "builtInSource", "remoteInstall")
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_WASM_BYTES = 2 * 1024 * 1024
MAX_ICON_BYTES = 1024 * 1024
MAX_ARCHIVE_BYTES = 5 * 1024 * 1024
EXPECTED_REQUIRED = {"manifest.generated.json", "wasm/rust_source_fixture.wasm"}
EXPECTED_OPTIONAL = {"icon.placeholder.txt"}


class BoundaryError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise BoundaryError(message)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def is_under(path: Path, base: Path) -> bool:
    path = path.resolve()
    base = base.resolve()
    return path == base or base in path.parents


def run_command(cmd: list[str], *, cwd: Path, env: dict[str, str], log_path: Path) -> dict:
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(redact_text(proc.stdout), encoding="utf-8")
    return {
        "cmd": redacted_command(cmd),
        "exitCode": proc.returncode,
        "log": str(log_path),
    }


def resolve_manifest_asset(manifest_path: Path, value: str) -> Path:
    require(isinstance(value, str) and value, "asset path must be a non-empty string")
    require("://" not in value, f"remote asset path is not allowed: {value}")
    p = Path(value)
    if not p.is_absolute():
        p = manifest_path.parent / p
    resolved = p.resolve()
    root = repo_root().resolve()
    artifact_env = os.environ.get("KOMA_SOURCE_PACKAGE_ARTIFACT_DIR")
    allowed_roots = [root]
    if artifact_env:
        allowed_roots.append(Path(artifact_env).resolve())
    require(any(is_under(resolved, base) for base in allowed_roots), f"asset path escapes allowed roots: {resolved}")
    return resolved


def archive_name_is_safe(name: str) -> bool:
    if not name or name.endswith("/"):
        return False
    pure = PurePosixPath(name)
    parts = pure.parts
    return (
        not pure.is_absolute()
        and ".." not in parts
        and all(part and not part.startswith(".") for part in parts)
        and not any(part in {"build", "target", "__MACOSX"} for part in parts)
        and "\\" not in name
    )


def zipinfo_is_symlink(info: zipfile.ZipInfo) -> bool:
    mode = (info.external_attr >> 16) & 0o777777
    return stat.S_ISLNK(mode)


def build_generated_package(artifact_dir: Path, env: dict[str, str], report: dict) -> Path:
    build_dir = artifact_dir / "package-build-for-archive"
    build_script = repo_root() / "tools/wasm-runtime-spike/source-package/build-rust-sdk-source-package.py"
    result = run_command(
        ["python3", str(build_script), "--artifact-dir", str(build_dir)],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "build-rust-sdk-source-package-for-archive.log",
    )
    report["commands"].append(result)
    require(result["exitCode"] == 0, "SDK-backed package build failed")
    package_dir = build_dir / "generated-package"
    require((package_dir / "manifest.generated.json").is_file(), f"generated manifest missing: {package_dir}")
    return package_dir


def create_archive(package_dir: Path, archive_path: Path, staging_dir: Path) -> dict:
    manifest_path = package_dir / "manifest.generated.json"
    require(manifest_path.is_file(), f"manifest.generated.json missing in {package_dir}")
    manifest = read_json(manifest_path)
    wasm_path = resolve_manifest_asset(manifest_path, manifest.get("runtime", {}).get("wasm", {}).get("path"))
    require(wasm_path.is_file(), f"manifest wasm missing: {wasm_path}")

    wasm_sha = sha256_file(wasm_path)
    wasm_size = wasm_path.stat().st_size
    require(wasm_size <= MAX_WASM_BYTES, f"wasm exceeds archive max size: {wasm_size}")
    require(manifest["runtime"]["wasm"].get("sha256") == wasm_sha, "generated manifest wasm sha256 mismatch")

    staged_manifest = json.loads(json.dumps(manifest))
    staged_manifest["runtime"]["wasm"]["path"] = "wasm/rust_source_fixture.wasm"
    staged_manifest["runtime"]["wasm"]["sha256"] = wasm_sha

    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    (staging_dir / "wasm").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(wasm_path, staging_dir / "wasm/rust_source_fixture.wasm")
    write_json(staging_dir / "manifest.generated.json", staged_manifest)

    entries = ["manifest.generated.json", "wasm/rust_source_fixture.wasm"]
    icon_value = manifest.get("package", {}).get("icon")
    if icon_value:
        icon_path = resolve_manifest_asset(manifest_path, icon_value)
        require(icon_path.is_file(), f"manifest icon missing: {icon_path}")
        require(icon_path.stat().st_size <= MAX_ICON_BYTES, f"icon exceeds archive max size: {icon_path.stat().st_size}")
        icon_name = Path(icon_value).name
        require(icon_name == icon_value, "icon path must be package-root filename for archive boundary")
        shutil.copyfile(icon_path, staging_dir / icon_name)
        entries.append(icon_name)

    require((staging_dir / "manifest.generated.json").stat().st_size <= MAX_MANIFEST_BYTES,
            "manifest exceeds archive max size")
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in entries:
            require(archive_name_is_safe(name), f"unsafe archive entry generated: {name}")
            source = staging_dir / name
            require(source.is_file() and not source.is_symlink(), f"archive source is not a regular file: {source}")
            zf.write(source, name)

    require(archive_path.stat().st_size <= MAX_ARCHIVE_BYTES, f"archive exceeds max size: {archive_path.stat().st_size}")
    return {
        "archive": str(archive_path),
        "sourceManifest": str(manifest_path),
        "stagedManifest": str(staging_dir / "manifest.generated.json"),
        "entries": entries,
        "wasm": {
            "path": str(wasm_path),
            "sha256": wasm_sha,
            "sizeBytes": wasm_size,
        },
    }


def validate_archive_safety(archive_path: Path) -> dict:
    require(archive_path.is_file(), f"archive missing: {archive_path}")
    require(archive_path.suffixes[-2:] == [".source", ".zip"] or archive_path.name.endswith(".koma-source.zip"),
            "archive must use a local source zip suffix")
    seen: set[str] = set()
    entries: list[dict] = []
    with zipfile.ZipFile(archive_path, "r") as zf:
        bad = zf.testzip()
        require(bad is None, f"zip CRC check failed for {bad}")
        infos = zf.infolist()
        require(infos, "archive is empty")
        for info in infos:
            name = info.filename
            require(name not in seen, f"duplicate archive entry: {name}")
            seen.add(name)
            require(archive_name_is_safe(name), f"unsafe archive entry: {name}")
            require(not zipinfo_is_symlink(info), f"archive entry is a symlink: {name}")
            require(info.file_size >= 0, f"negative file size for {name}")
            if name == "manifest.generated.json":
                require(info.file_size <= MAX_MANIFEST_BYTES, "manifest entry exceeds max size")
            elif name.endswith(".wasm"):
                require(info.file_size <= MAX_WASM_BYTES, "wasm entry exceeds max size")
            elif name == "icon.placeholder.txt":
                require(info.file_size <= MAX_ICON_BYTES, "icon entry exceeds max size")
            else:
                raise BoundaryError(f"unexpected archive entry: {name}")
            entries.append({"name": name, "sizeBytes": info.file_size})
    names = {entry["name"] for entry in entries}
    require(EXPECTED_REQUIRED.issubset(names), "archive missing required entries")
    require(names.issubset(EXPECTED_REQUIRED | EXPECTED_OPTIONAL), "archive contains unexpected entries")
    return {
        "status": "PASS",
        "entries": entries,
        "gates": {
            "noAbsolutePaths": True,
            "noPathTraversal": True,
            "noSymlinks": True,
            "noDuplicateNames": True,
            "noHiddenOrGeneratedBuildDirs": True,
            "expectedEntriesOnly": True,
            "oversizedFilesRejected": True,
        },
    }


def extract_archive(archive_path: Path, extract_dir: Path) -> None:
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)
    base = extract_dir.resolve()
    with zipfile.ZipFile(archive_path, "r") as zf:
        for info in zf.infolist():
            target = (base / info.filename).resolve()
            require(is_under(target, base), f"archive extraction would escape staging dir: {info.filename}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info, "r") as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)


def manifest_gates(manifest: dict, wasm_sha: str, wasm_size: int) -> list[dict]:
    runtime = manifest.get("runtime", {})
    permissions = manifest.get("permissions", {})
    content_policy = manifest.get("contentPolicy", {})
    imports = [
        f"{item.get('module')}.{item.get('name')}"
        for item in runtime.get("requiredHostImports", [])
        if isinstance(item, dict)
    ]
    gates = [
        {"name": "network", "status": "PASS" if permissions.get("network") is False else "FAIL",
         "value": permissions.get("network")},
        {"name": "hostAbi", "status": "PASS" if runtime.get("hostAbi") == HOST_ABI else "FAIL",
         "value": runtime.get("hostAbi")},
        {"name": "hostImports", "status": "PASS" if imports == HOST_IMPORTS else "FAIL", "value": imports},
        {"name": "permissionsHostImports", "status": "PASS" if permissions.get("hostImports") == HOST_IMPORTS else "FAIL",
         "value": permissions.get("hostImports")},
        {"name": "wasmSha256", "status": "PASS" if runtime.get("wasm", {}).get("sha256") == wasm_sha else "FAIL",
         "value": runtime.get("wasm", {}).get("sha256"), "actual": wasm_sha},
        {"name": "wasmSize", "status": "PASS" if wasm_size <= runtime.get("limits", {}).get("maxWasmBytes", 0) else "FAIL",
         "value": wasm_size, "limit": runtime.get("limits", {}).get("maxWasmBytes")},
    ]
    for key in CONTENT_POLICY_KEYS:
        gates.append({"name": key, "status": "PASS" if content_policy.get(key) is False else "FAIL",
                      "value": content_policy.get(key)})
    return gates


def validate_staged_manifest(extract_dir: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> dict:
    manifest_path = extract_dir / "manifest.generated.json"
    manifest = read_json(manifest_path)
    wasm_path = extract_dir / manifest["runtime"]["wasm"]["path"]
    require(wasm_path.is_file(), f"staged wasm missing: {wasm_path}")
    wasm_sha = sha256_file(wasm_path)
    wasm_size = wasm_path.stat().st_size
    gates = manifest_gates(manifest, wasm_sha, wasm_size)
    require(all(gate["status"] == "PASS" for gate in gates), "manifest archive gates failed")

    validate_script = repo_root() / "tools/wasm-runtime-spike/source-package/validate-source-package.py"
    result = run_command(
        ["python3", str(validate_script), "--manifest", str(manifest_path), "--artifact-dir", str(artifact_dir)],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "validate-source-package-archive.log",
    )
    report["commands"].append(result)
    require(result["exitCode"] == 0, "archive staged manifest validation failed")
    return {
        "gates": gates,
        "validationReport": str(artifact_dir / "source-package-validation.json"),
        "wasm": {
            "path": str(wasm_path),
            "sha256": wasm_sha,
            "sizeBytes": wasm_size,
        },
    }


def validate_existing_archive(archive_path: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> dict:
    extract_dir = artifact_dir / "archive-extracted"
    safety = validate_archive_safety(archive_path)
    extract_archive(archive_path, extract_dir)
    staged = validate_staged_manifest(extract_dir, artifact_dir, env, report)
    return {
        "extractDir": str(extract_dir),
        "safety": safety,
        "manifestGates": staged["gates"],
        "wasm": staged["wasm"],
        "validationReport": staged["validationReport"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create and validate a tooling-only local Koma WASM source package archive."
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--package-dir", help="Existing generated-package directory to archive.")
    parser.add_argument("--validate-archive", help="Validate an existing local source archive without building one.")
    parser.add_argument("--report", help="Report path. Defaults to <artifact-dir>/source-package-archive-report.json.")
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    default_report = "source-package-archive-validation-report.json" if args.validate_archive else "source-package-archive-report.json"
    report_path = Path(args.report).resolve() if args.report else artifact_dir / default_report
    archive_path = Path(args.validate_archive).resolve() if args.validate_archive else artifact_dir / "archive" / "local.test.koma.fixture.koma-source.zip"
    staging_dir = artifact_dir / "archive-staging"
    report = {
        "status": "FAIL",
        "artifactDir": str(artifact_dir),
        "archive": str(archive_path),
        "commands": [],
        "safety": {},
        "manifestGates": [],
        "evidence": [],
    }

    try:
        artifact_dir.mkdir(parents=True, exist_ok=True)
        require(is_under(artifact_dir, artifact_dir), "artifact dir must resolve")
        os.environ["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
        env = os.environ.copy()
        if args.validate_archive:
            validated = validate_existing_archive(archive_path, artifact_dir, env, report)
            report.update({
                "status": "PASS",
                **validated,
            })
            report["evidence"].extend([
                f"archive validated at {archive_path}",
                f"wasm sha256 {validated['wasm']['sha256']} size {validated['wasm']['sizeBytes']} bytes",
                "existing archive safety and staged manifest checks passed",
            ])
        else:
            package_dir = Path(args.package_dir).resolve() if args.package_dir else build_generated_package(artifact_dir, env, report)
            require(is_under(package_dir, artifact_dir), "package dir must live under artifact dir")

            archive_info = create_archive(package_dir, archive_path, staging_dir)
            validated = validate_existing_archive(archive_path, artifact_dir, env, report)

            report.update({
                "status": "PASS",
                "packageDir": str(package_dir),
                "stagingDir": str(staging_dir),
                "extractDir": validated["extractDir"],
                "entries": archive_info["entries"],
                "safety": validated["safety"],
                "manifestGates": validated["manifestGates"],
                "wasm": validated["wasm"],
                "validationReport": validated["validationReport"],
            })
            report["evidence"].extend([
                f"archive created at {archive_path}",
                f"entries: {', '.join(archive_info['entries'])}",
                f"wasm sha256 {validated['wasm']['sha256']} size {validated['wasm']['sizeBytes']} bytes",
                "staged archive manifest passed validate-source-package.py",
                "network=false, hostAbi=koma-host-v0.1, host imports log/check_cancel, and content policy flags closed",
            ])
    except Exception as err:
        report["error"] = str(err)

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
