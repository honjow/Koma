#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redacted_command, redact_text, redact_value, write_redacted_json  # noqa: E402


EXPECTED_OPERATIONS = (
    "search",
    "get_manga",
    "get_chapters",
    "get_pages",
    "get_listings",
    "get_manga_list",
    "get_home",
    "get_filters",
    "get_settings",
    "get_image_request",
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def run_step(cmd: list[str], *, cwd: Path, env: dict[str, str],
             log_path: Path, summary: str, report: dict) -> dict:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.write_text(redact_text(proc.stdout), encoding="utf-8")
    entry = {
        "cmd": redacted_command(cmd),
        "summary": summary,
        "exitCode": proc.returncode,
        "log": redact_text(str(log_path)),
    }
    report["commands"].append(entry)
    return entry


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Run the source-runtime evidence chain "
            "(direct Rust/WAMR fixture, archive smoke, operation-surface parity, "
            "source API v0.2 JSON fixture validator) and emit a concise suite report."
        ),
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument(
        "--report",
        help="Defaults to <artifact-dir>/source-runtime-evidence-suite-report.json.",
    )
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    report_path = (Path(args.report).resolve() if args.report
                   else artifact_dir / "source-runtime-evidence-suite-report.json")

    direct_dir = artifact_dir / "rust-wamr"
    archive_dir = artifact_dir / "archive-smoke"
    parity_dir = artifact_dir / "parity"
    source_api_dir = artifact_dir / "source-api-fixtures"
    logs_dir = artifact_dir / "logs"

    direct_report_path = direct_dir / "source-operation-surface-report.json"
    archive_report_path = archive_dir / "source-archive-wamr-smoke-report.json"
    parity_report_path = parity_dir / "operation-surface-parity-report.json"
    source_api_report_path = source_api_dir / "source-api-fixtures-report.json"

    env = os.environ.copy()
    shared_wamr = artifact_dir / "cache" / "wasm-micro-runtime"
    env.setdefault("WAMR_ROOT_DIR", str(shared_wamr))
    env["KOMA_WASM_SPIKE_ARTIFACT_DIR"] = str(artifact_dir)
    env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
    os.environ["KOMA_WASM_SPIKE_ARTIFACT_DIR"] = str(artifact_dir)
    os.environ["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)

    report: dict = {
        "status": "FAIL",
        "artifactDir": redact_text(str(artifact_dir)),
        "commands": [],
        "reports": {
            "directReport": redact_text(str(direct_report_path)),
            "archiveReport": redact_text(str(archive_report_path)),
            "parityReport": redact_text(str(parity_report_path)),
            "sourceApiReport": redact_text(str(source_api_report_path)),
            "suiteReport": redact_text(str(report_path)),
        },
        "expectedReportsPresent": {
            "direct": False,
            "archive": False,
            "parity": False,
            "sourceApi": False,
        },
        "operationsCovered": [],
        "evidence": [],
        "findings": [],
    }

    root = repo_root()
    steps = [
        {
            "cmd": [
                "tools/wasm-runtime-spike/run-rust-fixture.sh",
                "--artifact-dir", str(direct_dir),
            ],
            "summary": "Direct Rust/WAMR fixture (source operation surface evidence)",
            "log": logs_dir / "01-rust-wamr-fixture.log",
            "expected_report": direct_report_path,
        },
        {
            "cmd": [
                "python3",
                "tools/wasm-runtime-spike/source-package/run-source-archive-smoke.py",
                "--artifact-dir", str(archive_dir),
            ],
            "summary": "Archive smoke (extracted wasm operation surface)",
            "log": logs_dir / "02-archive-smoke.log",
            "expected_report": archive_report_path,
        },
        {
            "cmd": [
                "python3",
                "tools/wasm-runtime-spike/source-package/validate-operation-surface-parity.py",
                "--direct-report", str(direct_report_path),
                "--archive-report", str(archive_report_path),
                "--artifact-dir", str(parity_dir),
            ],
            "summary": "Operation surface parity validator (direct vs archive)",
            "log": logs_dir / "03-parity.log",
            "expected_report": parity_report_path,
        },
        {
            "cmd": [
                "python3",
                "tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py",
                "--artifact-dir", str(source_api_dir),
            ],
            "summary": "Source API v0.2 JSON fixture validator",
            "log": logs_dir / "04-source-api-fixtures.log",
            "expected_report": source_api_report_path,
        },
    ]

    findings: list[str] = []
    for step in steps:
        entry = run_step(step["cmd"], cwd=root, env=env,
                         log_path=step["log"], summary=step["summary"], report=report)
        if entry["exitCode"] != 0:
            findings.append(f"step exit {entry['exitCode']}: {step['summary']}")
        if not step["expected_report"].is_file():
            findings.append(
                f"missing expected report for step '{step['summary']}': "
                f"{redact_text(str(step['expected_report']))}"
            )

    report["expectedReportsPresent"] = {
        "direct": direct_report_path.is_file(),
        "archive": archive_report_path.is_file(),
        "parity": parity_report_path.is_file(),
        "sourceApi": source_api_report_path.is_file(),
    }

    operations_covered: list[str] = []
    parity_status: str | None = None
    if parity_report_path.is_file():
        try:
            parity_report = read_json(parity_report_path)
            parity_status = parity_report.get("status")
            ops = parity_report.get("operations")
            if isinstance(ops, list):
                operations_covered = [str(op) for op in ops]
            if parity_status != "PASS":
                findings.append(f"parity report status is {parity_status!r}, expected PASS")
            if sorted(operations_covered) != sorted(EXPECTED_OPERATIONS):
                findings.append(
                    "parity operations do not match expected v0.2 set: "
                    f"{sorted(operations_covered)} != {sorted(EXPECTED_OPERATIONS)}"
                )
        except Exception as err:
            findings.append(f"parity report read failed: {err}")

    if direct_report_path.is_file():
        try:
            direct_report = read_json(direct_report_path)
            if direct_report.get("operationCount") != 10:
                findings.append(
                    "direct report operationCount is "
                    f"{direct_report.get('operationCount')!r}, expected 10"
                )
        except Exception as err:
            findings.append(f"direct report read failed: {err}")

    if archive_report_path.is_file():
        try:
            archive_report = read_json(archive_report_path)
            if archive_report.get("status") != "PASS":
                findings.append(
                    f"archive report status is {archive_report.get('status')!r}, expected PASS"
                )
        except Exception as err:
            findings.append(f"archive report read failed: {err}")

    if source_api_report_path.is_file():
        try:
            source_api_report = read_json(source_api_report_path)
            if source_api_report.get("status") != "PASS":
                findings.append(
                    "source API fixture report status is "
                    f"{source_api_report.get('status')!r}, expected PASS"
                )
        except Exception as err:
            findings.append(f"source API fixture report read failed: {err}")

    status = "PASS" if not findings else "FAIL"

    evidence: list[str] = []
    if status == "PASS":
        evidence = [
            f"direct Rust/WAMR surface report at {redact_text(str(direct_report_path))}",
            f"archive smoke report at {redact_text(str(archive_report_path))}",
            f"operation surface parity report at {redact_text(str(parity_report_path))}",
            f"source API v0.2 fixture report at {redact_text(str(source_api_report_path))}",
            "direct report operationCount=10, archive report status=PASS, "
            "parity report status=PASS, source API fixture report status=PASS",
            f"parity covered {len(operations_covered)} v0.2 operations: "
            f"{', '.join(operations_covered)}",
        ]

    report.update({
        "status": status,
        "parityStatus": parity_status,
        "operationsCovered": operations_covered,
        "evidence": evidence,
        "findings": findings,
    })

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
