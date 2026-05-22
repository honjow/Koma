#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import zipfile
import warnings
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redacted_command, redact_text, redact_value, write_redacted_json  # noqa: E402


PACKAGE_SCRIPT = "tools/wasm-runtime-spike/source-package/package-source-archive.py"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    write_redacted_json(path, payload)


def run_command(cmd: list[str], *, cwd: Path, env: dict[str, str], log_path: Path) -> dict:
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(redact_text(proc.stdout), encoding="utf-8")
    return {
        "cmd": redacted_command(cmd),
        "exitCode": proc.returncode,
        "log": str(log_path),
        "output": proc.stdout,
    }


def read_baseline_entries(archive_path: Path) -> dict[str, bytes]:
    with zipfile.ZipFile(archive_path, "r") as zf:
        return {info.filename: zf.read(info.filename) for info in zf.infolist()}


def write_zip(path: Path, entries: list[tuple[str, bytes]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, data in entries:
            zf.writestr(name, data)


def write_symlink_zip(path: Path, entries: dict[str, bytes]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        link_info = zipfile.ZipInfo("manifest.generated.json")
        link_info.create_system = 3
        link_info.external_attr = (stat.S_IFLNK | 0o777) << 16
        zf.writestr(link_info, b"wasm/rust_source_fixture.wasm")
        for name, data in entries.items():
            if name != "manifest.generated.json":
                zf.writestr(name, data)


def manifest_bytes(entries: dict[str, bytes]) -> dict:
    return json.loads(entries["manifest.generated.json"].decode("utf-8"))


def encode_manifest(manifest: dict) -> bytes:
    return (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")


def case_entries(entries: dict[str, bytes], *, manifest: dict | None = None,
                 wasm: bytes | None = None, omit: set[str] | None = None,
                 extra: list[tuple[str, bytes]] | None = None) -> list[tuple[str, bytes]]:
    omit = omit or set()
    out: list[tuple[str, bytes]] = []
    for name, data in entries.items():
        if name in omit:
            continue
        if name == "manifest.generated.json" and manifest is not None:
            data = encode_manifest(manifest)
        elif name == "wasm/rust_source_fixture.wasm" and wasm is not None:
            data = wasm
        out.append((name, data))
    out.extend(extra or [])
    return out


def parse_validation_reason(output: str) -> str:
    try:
        payload = json.loads(output)
    except json.JSONDecodeError:
        lines = [line for line in output.splitlines() if line.strip()]
        return lines[-1] if lines else "validator produced no output"
    return payload.get("error") or payload.get("status") or "no validator reason"


def build_fixtures(entries: dict[str, bytes], fixture_dir: Path) -> list[dict]:
    manifest = manifest_bytes(entries)
    wasm = entries["wasm/rust_source_fixture.wasm"]
    fixtures: list[dict] = []

    def add(name: str, archive_name: str, zip_entries: list[tuple[str, bytes]]) -> None:
        archive = fixture_dir / archive_name
        write_zip(archive, zip_entries)
        fixtures.append({"id": name, "name": name, "archive": archive})

    add("path_traversal_entry", "path-traversal.koma-source.zip",
        case_entries(entries, extra=[("../evil", b"evil")]))
    add("absolute_path_entry", "absolute-path.koma-source.zip",
        case_entries(entries, extra=[("/abs", b"abs")]))

    duplicate_archive = fixture_dir / "duplicate-entry.koma-source.zip"
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        write_zip(duplicate_archive, list(entries.items()) + [("manifest.generated.json", entries["manifest.generated.json"])])
    fixtures.append({"id": "duplicate_entry_name", "name": "duplicate_entry_name", "archive": duplicate_archive})

    symlink_archive = fixture_dir / "symlink-entry.koma-source.zip"
    write_symlink_zip(symlink_archive, entries)
    fixtures.append({"id": "symlink_entry", "name": "symlink_entry", "archive": symlink_archive})

    add("unexpected_entry_name", "unexpected-entry.koma-source.zip",
        case_entries(entries, extra=[("unexpected.txt", b"unexpected")]))

    network_manifest = json.loads(json.dumps(manifest))
    network_manifest["permissions"]["network"] = True
    add("manifest_network_true", "manifest-network-true.koma-source.zip",
        case_entries(entries, manifest=network_manifest))

    host_import_drift_manifest = json.loads(json.dumps(manifest))
    host_import_drift_manifest["runtime"]["requiredHostImports"].append({"module": "koma_host", "name": "raw_socket"})
    host_import_drift_manifest["permissions"]["hostImports"].append("koma_host.raw_socket")
    add("host_import_policy_drift", "host-import-policy-drift.koma-source.zip",
        case_entries(entries, manifest=host_import_drift_manifest))

    tampered_wasm = wasm + b"\0tampered"
    add("wasm_sha256_mismatch", "wasm-sha256-mismatch.koma-source.zip",
        case_entries(entries, wasm=tampered_wasm))

    add("missing_manifest", "missing-manifest.koma-source.zip",
        case_entries(entries, omit={"manifest.generated.json"}))
    add("missing_wasm", "missing-wasm.koma-source.zip",
        case_entries(entries, omit={"wasm/rust_source_fixture.wasm"}))

    return fixtures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate adversarial local source archive fixtures and assert package-source-archive.py rejects them."
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Report path. Defaults to <artifact-dir>/archive-negative-fixtures-report.json.")
    args = parser.parse_args()

    root = repo_root()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "archive-negative-fixtures-report.json"
    baseline_dir = artifact_dir / "baseline"
    fixture_dir = artifact_dir / "fixtures"
    validation_dir = artifact_dir / "validations"
    logs_dir = artifact_dir / "logs"

    report = {
        "status": "FAIL",
        "artifactDir": str(artifact_dir),
        "baselineArchive": str(baseline_dir / "archive" / "local.test.koma.fixture.koma-source.zip"),
        "cases": [],
        "commands": [],
        "evidence": [],
    }

    try:
        if fixture_dir.exists():
            shutil.rmtree(fixture_dir)
        if validation_dir.exists():
            shutil.rmtree(validation_dir)
        artifact_dir.mkdir(parents=True, exist_ok=True)

        env = os.environ.copy()
        env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
        package_script = root / PACKAGE_SCRIPT
        baseline_cmd = [
            "python3",
            str(package_script),
            "--artifact-dir",
            str(baseline_dir),
        ]
        baseline_result = run_command(
            baseline_cmd,
            cwd=root,
            env=env,
            log_path=logs_dir / "baseline-package-source-archive.log",
        )
        report["commands"].append({k: v for k, v in baseline_result.items() if k != "output"})
        if baseline_result["exitCode"] != 0:
            raise RuntimeError("baseline archive packaging failed")

        baseline_archive = baseline_dir / "archive" / "local.test.koma.fixture.koma-source.zip"
        entries = read_baseline_entries(baseline_archive)
        fixtures = build_fixtures(entries, fixture_dir)

        for fixture in fixtures:
            case_id = fixture["id"]
            case_name = fixture["name"]
            case_validation_dir = validation_dir / case_name
            case_log = logs_dir / f"validate-{case_name}.log"
            cmd = [
                "python3",
                str(package_script),
                "--artifact-dir",
                str(case_validation_dir),
                "--validate-archive",
                str(fixture["archive"]),
            ]
            result = run_command(cmd, cwd=root, env=env, log_path=case_log)
            rejected = result["exitCode"] != 0
            reason = parse_validation_reason(result["output"])
            report["commands"].append({k: v for k, v in result.items() if k != "output"})
            report["cases"].append({
                "id": case_id,
                "name": case_name,
                "archive": str(fixture["archive"]),
                "expectedRejection": True,
                "actualRejection": rejected,
                "status": "PASS" if rejected else "FAIL",
                "reason": reason,
                "log": str(case_log),
            })

        if any(case["status"] != "PASS" for case in report["cases"]):
            raise RuntimeError("one or more negative archive fixtures were accepted")

        report["status"] = "PASS"
        report["evidence"].extend([
            f"baseline archive {baseline_archive}",
            f"generated {len(fixtures)} adversarial archives under {fixture_dir}",
            "all adversarial archives were rejected by package-source-archive.py --validate-archive",
        ])
    except Exception as err:
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
