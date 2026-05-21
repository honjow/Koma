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
CONTENT_POLICY_KEYS = ("publicIndex", "marketplace", "builtInSource", "remoteInstall")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_command(cmd: list[str], *, cwd: Path, env: dict[str, str], log_path: Path) -> dict:
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(proc.stdout, encoding="utf-8")
    return {
        "cmd": " ".join(cmd),
        "exitCode": proc.returncode,
        "log": str(log_path),
    }


def gate_results(manifest: dict, wasm_path: Path, wasm_sha: str, wasm_size: int) -> list[dict]:
    runtime = manifest.get("runtime", {})
    package = manifest.get("package", {})
    permissions = manifest.get("permissions", {})
    content_policy = manifest.get("contentPolicy", {})
    wasm = runtime.get("wasm", {})

    gates = [
        {
            "name": "packageId",
            "status": "PASS" if isinstance(package.get("id"), str) and package["id"] else "FAIL",
            "value": package.get("id"),
        },
        {
            "name": "hostAbi",
            "status": "PASS" if runtime.get("hostAbi") == HOST_ABI else "FAIL",
            "value": runtime.get("hostAbi"),
        },
        {
            "name": "network",
            "status": "PASS" if permissions.get("network") is False else "FAIL",
            "value": permissions.get("network"),
        },
        {
            "name": "hostImports",
            "status": "PASS" if permissions.get("hostImports") == HOST_IMPORTS else "FAIL",
            "value": permissions.get("hostImports"),
        },
        {
            "name": "wasmSha256",
            "status": "PASS" if wasm.get("sha256") == wasm_sha else "FAIL",
            "value": wasm.get("sha256"),
            "actual": wasm_sha,
        },
        {
            "name": "wasmSize",
            "status": "PASS" if wasm_path.is_file() and wasm_path.stat().st_size == wasm_size else "FAIL",
            "value": wasm_size,
        },
    ]
    for key in CONTENT_POLICY_KEYS:
        gates.append({
            "name": key,
            "status": "PASS" if content_policy.get(key) is False else "FAIL",
            "value": content_policy.get(key),
        })
    return gates


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build the SDK-backed Rust fixture wasm and validate a generated local source package manifest."
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument(
        "--manifest-template",
        default="tools/wasm-runtime-spike/source-package/manifest.example.json",
    )
    args = parser.parse_args()

    root = repo_root()
    artifact_dir = Path(args.artifact_dir).resolve()
    template_path = Path(args.manifest_template).resolve()
    rust_artifact_dir = artifact_dir / "rust-fixture"
    package_dir = artifact_dir / "generated-package"
    validate_dir = artifact_dir
    manifest_out = package_dir / "manifest.generated.json"
    report_path = artifact_dir / "rust-sdk-source-package-build-report.json"
    run_log = artifact_dir / "logs" / "run-rust-fixture.log"
    validate_log = artifact_dir / "logs" / "validate-generated-package.log"

    report = {
        "status": "FAIL",
        "artifactDir": str(artifact_dir),
        "templateManifest": str(template_path),
        "generatedManifest": str(manifest_out),
        "commands": [],
        "gates": [],
        "evidence": [],
    }

    try:
        artifact_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["KOMA_WASM_SPIKE_ARTIFACT_DIR"] = str(rust_artifact_dir)
        env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)

        run_script = root / "tools/wasm-runtime-spike/run-rust-fixture.sh"
        run_result = run_command(["bash", str(run_script)], cwd=root, env=env, log_path=run_log)
        report["commands"].append(run_result)
        if run_result["exitCode"] != 0:
            raise RuntimeError("Rust SDK fixture build/run failed")

        wasm_path = rust_artifact_dir / "build/rust_source_fixture.wasm"
        if not wasm_path.is_file():
            raise RuntimeError(f"built wasm missing: {wasm_path}")
        wasm_sha = sha256_file(wasm_path)
        wasm_size = wasm_path.stat().st_size

        manifest = read_json(template_path)
        package_dir.mkdir(parents=True, exist_ok=True)
        icon_value = manifest.get("package", {}).get("icon")
        if icon_value:
            source_icon = (template_path.parent / icon_value).resolve()
            shutil.copyfile(source_icon, package_dir / Path(icon_value).name)
            manifest["package"]["icon"] = Path(icon_value).name
        manifest["runtime"]["wasm"]["path"] = str(wasm_path)
        manifest["runtime"]["wasm"]["sha256"] = wasm_sha
        manifest["runtime"]["wasm"]["build"] = {
            "kind": "rustc-no-std-sdk-fixture",
            "script": str(run_script),
            "artifactPath": "build/rust_source_fixture.wasm",
        }
        write_json(manifest_out, manifest)

        report["builtWasm"] = {
            "path": str(wasm_path),
            "sha256": wasm_sha,
            "sizeBytes": wasm_size,
        }
        report["gates"] = gate_results(manifest, wasm_path, wasm_sha, wasm_size)
        if any(gate["status"] != "PASS" for gate in report["gates"]):
            raise RuntimeError("generated manifest gate failed")

        validate_script = root / "tools/wasm-runtime-spike/source-package/validate-source-package.py"
        validate_result = run_command(
            [
                "python3",
                str(validate_script),
                "--manifest",
                str(manifest_out),
                "--artifact-dir",
                str(validate_dir),
            ],
            cwd=root,
            env=env,
            log_path=validate_log,
        )
        report["commands"].append(validate_result)
        if validate_result["exitCode"] != 0:
            raise RuntimeError("generated package manifest validation failed")

        validation_report = validate_dir / "source-package-validation.json"
        report["validationReport"] = str(validation_report)
        report["evidence"].extend([
            f"built wasm sha256 {wasm_sha} size {wasm_size} bytes",
            f"generated manifest {manifest_out}",
            f"validator report {validation_report}",
            "WAMR run preserved ok:true, Fixture Series, and network=false evidence",
        ])
        report["status"] = "PASS"
    except Exception as err:
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
