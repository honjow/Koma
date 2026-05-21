#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


HOST_ABI = "koma-host-v0.1"
HOST_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
WAMR_TAG = "WAMR-2.3.0"
WAMR_COMMIT = "c7b2db18329f849b81568b94e72ddd0b20f431a5"
CONTENT_POLICY_KEYS = ("publicIndex", "marketplace", "builtInSource", "remoteInstall")


class SmokeError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeError(message)


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


def command_text(cmd: list[str], env_prefix: dict[str, str] | None = None) -> str:
    prefix = ""
    if env_prefix:
        prefix = " ".join(f"{key}={value}" for key, value in sorted(env_prefix.items())) + " "
    return prefix + " ".join(cmd)


def run_command(cmd: list[str], *, cwd: Path, env: dict[str, str], log_path: Path,
                report: dict, summary: str, env_prefix: dict[str, str] | None = None) -> dict:
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(proc.stdout, encoding="utf-8")
    result = {
        "cmd": command_text(cmd, env_prefix),
        "exitCode": proc.returncode,
        "log": str(log_path),
        "summary": summary,
    }
    report["commands"].append(result)
    return result


def extract_operation_json(output: str) -> dict[str, dict]:
    payloads: dict[str, dict] = {}
    for line in output.splitlines():
        if line.startswith("SOURCE_API_JSON "):
            name, raw = line[len("SOURCE_API_JSON "):].split("=", 1)
            payloads[name] = json.loads(raw)
    require(payloads, "host runner did not print SOURCE_API_JSON evidence")
    return payloads


def build_or_accept_archive(args: argparse.Namespace, artifact_dir: Path, env: dict[str, str], report: dict) -> Path:
    if args.archive:
        archive_path = Path(args.archive).resolve()
        require(archive_path.is_file(), f"archive does not exist: {archive_path}")
        return archive_path

    package_artifact_dir = artifact_dir / "archive-package"
    package_script = repo_root() / "tools/wasm-runtime-spike/source-package/package-source-archive.py"
    result = run_command(
        [
            "python3",
            str(package_script),
            "--artifact-dir",
            str(package_artifact_dir),
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "package-source-archive.log",
        report=report,
        summary="Build SDK-backed local .koma-source.zip archive",
    )
    require(result["exitCode"] == 0, "package-source-archive.py failed")
    archive_path = package_artifact_dir / "archive" / "local.test.koma.fixture.koma-source.zip"
    require(archive_path.is_file(), f"generated archive missing: {archive_path}")
    return archive_path


def validate_and_extract_archive(archive_path: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> tuple[Path, Path, dict]:
    validation_dir = artifact_dir / "archive-validation"
    validation_report_path = validation_dir / "source-package-archive-validation-report.json"
    package_script = repo_root() / "tools/wasm-runtime-spike/source-package/package-source-archive.py"
    result = run_command(
        [
            "python3",
            str(package_script),
            "--artifact-dir",
            str(validation_dir),
            "--validate-archive",
            str(archive_path),
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "validate-source-archive.log",
        report=report,
        summary="Validate and extract local source archive",
    )
    require(result["exitCode"] == 0, "archive validate-only path failed")
    validation_report = read_json(validation_report_path)
    require(validation_report.get("status") == "PASS", "archive validation report did not pass")

    extract_dir = Path(validation_report["extractDir"]).resolve()
    manifest_path = extract_dir / "manifest.generated.json"
    require(manifest_path.is_file(), f"extracted manifest missing: {manifest_path}")
    manifest = read_json(manifest_path)
    wasm_path = (manifest_path.parent / manifest["runtime"]["wasm"]["path"]).resolve()
    require(wasm_path.is_file(), f"extracted wasm missing: {wasm_path}")
    return manifest_path, wasm_path, validation_report


def manifest_gates(manifest_path: Path, wasm_path: Path) -> list[dict]:
    manifest = read_json(manifest_path)
    runtime = manifest.get("runtime", {})
    permissions = manifest.get("permissions", {})
    content_policy = manifest.get("contentPolicy", {})
    wasm = runtime.get("wasm", {})
    wasm_sha = sha256_file(wasm_path)
    wasm_size = wasm_path.stat().st_size
    required_imports = [
        f"{item.get('module')}.{item.get('name')}"
        for item in runtime.get("requiredHostImports", [])
        if isinstance(item, dict)
    ]
    gates = [
        {"name": "network", "status": "PASS" if permissions.get("network") is False else "FAIL",
         "value": permissions.get("network")},
        {"name": "hostAbi", "status": "PASS" if runtime.get("hostAbi") == HOST_ABI else "FAIL",
         "value": runtime.get("hostAbi")},
        {"name": "requiredHostImports", "status": "PASS" if required_imports == HOST_IMPORTS else "FAIL",
         "value": required_imports},
        {"name": "permissionsHostImports", "status": "PASS" if permissions.get("hostImports") == HOST_IMPORTS else "FAIL",
         "value": permissions.get("hostImports")},
        {"name": "wasmSha256", "status": "PASS" if wasm.get("sha256") == wasm_sha else "FAIL",
         "value": wasm.get("sha256"), "actual": wasm_sha},
        {"name": "wasmSize", "status": "PASS" if wasm_size <= runtime.get("limits", {}).get("maxWasmBytes", 0) else "FAIL",
         "value": wasm_size, "limit": runtime.get("limits", {}).get("maxWasmBytes")},
    ]
    for key in CONTENT_POLICY_KEYS:
        gates.append({
            "name": key,
            "status": "PASS" if content_policy.get(key) is False else "FAIL",
            "value": content_policy.get(key),
        })
    return gates


def ensure_wamr_checkout(wamr_root: Path, env: dict[str, str], report: dict, artifact_dir: Path) -> None:
    require(shutil.which("git") is not None, "missing required tool: git")
    if not (wamr_root / ".git").is_dir():
        result = run_command(
            ["git", "clone", "--depth", "1", "--branch", WAMR_TAG,
             "https://github.com/bytecodealliance/wasm-micro-runtime.git", str(wamr_root)],
            cwd=repo_root(),
            env=env,
            log_path=artifact_dir / "logs" / "wamr-clone.log",
            report=report,
            summary=f"Fetch ignored WAMR {WAMR_TAG} cache",
        )
        require(result["exitCode"] == 0, "WAMR clone failed")
    result = run_command(
        ["git", "-C", str(wamr_root), "rev-parse", "HEAD"],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "wamr-rev-parse.log",
        report=report,
        summary="Verify WAMR cache commit",
    )
    require(result["exitCode"] == 0, "WAMR rev-parse failed")
    actual_commit = Path(result["log"]).read_text(encoding="utf-8").strip()
    require(actual_commit == WAMR_COMMIT, f"WAMR commit mismatch: expected {WAMR_COMMIT} got {actual_commit}")


def run_extracted_wasm(wasm_path: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> dict:
    require(shutil.which("cmake") is not None, "missing required tool: cmake")
    host_artifact_dir = artifact_dir / "host-runner"
    host_build_dir = host_artifact_dir / "build" / "host"
    wamr_root = Path(env.get("WAMR_ROOT_DIR", host_artifact_dir / "cache" / "wasm-micro-runtime")).resolve()
    ensure_wamr_checkout(wamr_root, env, report, artifact_dir)

    cmake_configure = run_command(
        [
            "cmake",
            "-S",
            str(repo_root() / "tools/wasm-runtime-spike/host"),
            "-B",
            str(host_build_dir),
            f"-DWAMR_ROOT_DIR={wamr_root}",
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-cmake-configure.log",
        report=report,
        summary="Configure existing WAMR host runner",
    )
    require(cmake_configure["exitCode"] == 0, "host runner CMake configure failed")

    cmake_build = run_command(
        ["cmake", "--build", str(host_build_dir), "--target", "koma_wamr_spike", "--parallel"],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-cmake-build.log",
        report=report,
        summary="Build existing WAMR host runner",
    )
    require(cmake_build["exitCode"] == 0, "host runner CMake build failed")

    host_binary = host_build_dir / "koma_wamr_spike"
    require(host_binary.is_file(), f"host runner binary missing: {host_binary}")
    run_result = run_command(
        [str(host_binary), str(wasm_path)],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-run-extracted-wasm.log",
        report=report,
        summary="Run extracted archive wasm through WAMR host runner",
    )
    require(run_result["exitCode"] == 0, "extracted wasm host run failed")
    output = Path(run_result["log"]).read_text(encoding="utf-8")
    operation_payloads = extract_operation_json(output)
    expected_operations = ["search", "get_manga", "get_chapters", "get_pages"]
    require("WAMR_SPIKE_PASS" in output, "missing WAMR_SPIKE_PASS")
    require("SOURCE_API_RUNTIME_SMOKE_PASS" in output, "missing SOURCE_API_RUNTIME_SMOKE_PASS")
    for operation in expected_operations:
        require(f"SOURCE_API_OPERATION {operation} ok:true" in output,
                f"missing SOURCE_API_OPERATION {operation} ok:true")
        payload = operation_payloads.get(operation)
        require(isinstance(payload, dict), f"missing {operation} JSON payload")
        require(payload.get("version") == 1, f"{operation} JSON version was not 1")
        require(payload.get("ok") is True, f"{operation} JSON ok was not true")
        require(payload.get("operation") == operation, f"{operation} JSON operation mismatch")
        require(isinstance(payload.get("data"), dict), f"{operation} JSON missing data")
        require(payload.get("hostHints", {}).get("network") is False,
                f"{operation} JSON hostHints.network was not false")
    items = operation_payloads["search"].get("data", {}).get("items", [])
    require(items and items[0].get("title") == "Fixture Series", "missing Fixture Series search evidence")
    require("HOST_LOG level=1" in output and "rust fixture init reached host imports" in output,
            "missing HOST_LOG import evidence")
    require("HOST_CHECK_CANCEL result=0" in output, "missing HOST_CHECK_CANCEL import evidence")
    require("hostHints.network=false" in output, "missing hostHints.network=false evidence")

    operation_json_path = artifact_dir / "extracted-wasm-operation-results.json"
    write_json(operation_json_path, operation_payloads)
    return {
        "hostBinary": str(host_binary),
        "runLog": run_result["log"],
        "operationJson": str(operation_json_path),
        "evidence": [
            "WAMR_SPIKE_PASS",
            "SOURCE_API_RUNTIME_SMOKE_PASS",
            "SOURCE_API_OPERATION search ok:true",
            "SOURCE_API_OPERATION get_manga ok:true",
            "SOURCE_API_OPERATION get_chapters ok:true",
            "SOURCE_API_OPERATION get_pages ok:true",
            "Fixture Series",
            "HOST_LOG rust fixture init reached host imports",
            "HOST_CHECK_CANCEL result=0",
            "hostHints.network=false",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate/extract a local .koma-source.zip and run its wasm through the Linux WAMR host runner."
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--archive", help="Existing local .koma-source.zip to validate/extract and run.")
    parser.add_argument("--report", help="Report path. Defaults to <artifact-dir>/source-archive-wamr-smoke-report.json.")
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "source-archive-wamr-smoke-report.json"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
    env.setdefault("WAMR_ROOT_DIR", str(artifact_dir / "cache" / "wasm-micro-runtime"))

    report = {
        "status": "FAIL",
        "artifactDir": str(artifact_dir),
        "archive": "",
        "extractedManifest": "",
        "extractedWasm": "",
        "commands": [],
        "manifestGates": [],
        "archiveValidationReport": "",
        "wamr": {},
        "evidence": [],
    }

    try:
        archive_path = build_or_accept_archive(args, artifact_dir, env, report)
        manifest_path, wasm_path, archive_validation = validate_and_extract_archive(archive_path, artifact_dir, env, report)
        gates = manifest_gates(manifest_path, wasm_path)
        require(all(gate["status"] == "PASS" for gate in gates), "extracted manifest gates failed")
        wamr = run_extracted_wasm(wasm_path, artifact_dir, env, report)
        report.update({
            "status": "PASS",
            "archive": str(archive_path),
            "extractedManifest": str(manifest_path),
            "extractedWasm": str(wasm_path),
            "manifestGates": gates,
            "archiveValidationReport": str(artifact_dir / "archive-validation" / "source-package-archive-validation-report.json"),
            "wamr": wamr,
        })
        report["evidence"].extend([
            f"archive validated at {archive_path}",
            f"extracted manifest {manifest_path}",
            f"extracted wasm {wasm_path}",
            "manifest gates passed for network=false, hostAbi, host imports, wasm sha/size, and closed content policy",
            *wamr["evidence"],
        ])
        if archive_validation.get("safety", {}).get("status") == "PASS":
            report["evidence"].append("archive safety gates passed before WAMR execution")
    except Exception as err:
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
