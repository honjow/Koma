#!/usr/bin/env python3
"""Tooling-only negative/contract validator for the S16 source-runtime evidence suite.

Asserts the suite fails closed when an internal step exits nonzero and its
expected per-step report is missing. Copies the real wrapper (and the redaction
helper it imports) under the artifact directory, patches the copy so that the
first step is replaced with a local stub that exits nonzero without writing
its expected report, runs the patched copy, and checks the resulting suite
report. No repository source is mutated; all generated material lives under
the provided ``--artifact-dir``.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import (  # noqa: E402
    redact_text,
    redact_value,
    redacted_command,
    write_redacted_json,
)


WRAPPER_NAME = "run-source-runtime-evidence-suite.py"
REDACTION_NAME = "redaction.py"
SUITE_REPORT_NAME = "source-runtime-evidence-suite-report.json"
STUB_STEP_SUMMARY = "Direct Rust/WAMR fixture (source operation surface evidence)"
STUB_STEP_KEY = "direct"
STUB_EXIT_CODE = 7

REPO_ROOT_MARKER = (
    "def repo_root() -> Path:\n"
    "    return Path(__file__).resolve().parents[3]"
)
FIRST_STEP_MARKER = (
    '            "cmd": [\n'
    '                "tools/wasm-runtime-spike/run-rust-fixture.sh",\n'
    '                "--artifact-dir", str(direct_dir),\n'
    '            ],'
)


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def patch_wrapper(source_text: str, repo: Path) -> str:
    if REPO_ROOT_MARKER not in source_text:
        raise RuntimeError("wrapper repo_root marker not found; suite layout drifted")
    if FIRST_STEP_MARKER not in source_text:
        raise RuntimeError("wrapper first-step cmd marker not found; suite layout drifted")
    patched = source_text.replace(
        REPO_ROOT_MARKER,
        "def repo_root() -> Path:\n"
        f"    return Path({str(repo)!r})",
        1,
    )
    stub_cmd_block = (
        '            "cmd": [\n'
        '                "python3", "-c",\n'
        '                "import sys; '
        "sys.stderr.write('negative-contract stub: forced step failure\\\\n'); "
        f"sys.exit({STUB_EXIT_CODE})\",\n"
        '            ],'
    )
    patched = patched.replace(FIRST_STEP_MARKER, stub_cmd_block, 1)
    return patched


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Negative-contract validator for the source-runtime evidence suite. "
            "Patches a copy of the suite wrapper to force one step to exit nonzero "
            "and asserts the suite reports FAIL closed."
        ),
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument(
        "--report",
        help=(
            "Defaults to "
            "<artifact-dir>/evidence-suite-negative-contract-report.json."
        ),
    )
    parser.add_argument(
        "--shared-wamr-root",
        help=(
            "Optional existing WAMR_ROOT_DIR to reuse for the unstubbed steps. "
            "Default: a private cache under the artifact directory."
        ),
    )
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    report_path = (
        Path(args.report).resolve()
        if args.report
        else artifact_dir / "evidence-suite-negative-contract-report.json"
    )

    repo = repo_root()
    src_wrapper = repo / "tools" / "wasm-runtime-spike" / "source-package" / WRAPPER_NAME
    src_redaction = repo / "tools" / "wasm-runtime-spike" / REDACTION_NAME

    findings: list[str] = []

    if not src_wrapper.is_file():
        findings.append(f"missing source wrapper: {redact_text(str(src_wrapper))}")
    if not src_redaction.is_file():
        findings.append(f"missing redaction helper: {redact_text(str(src_redaction))}")

    copy_root = artifact_dir / "wrapper-copy"
    copy_root.mkdir(parents=True, exist_ok=True)
    redaction_copy_path = artifact_dir / REDACTION_NAME
    wrapper_copy_path = copy_root / WRAPPER_NAME

    if not findings:
        shutil.copy2(src_redaction, redaction_copy_path)
        wrapper_text = src_wrapper.read_text(encoding="utf-8")
        try:
            patched_text = patch_wrapper(wrapper_text, repo)
        except RuntimeError as err:
            findings.append(str(err))
            patched_text = None
        else:
            wrapper_copy_path.write_text(patched_text, encoding="utf-8")

    suite_artifact_dir = artifact_dir / "negative-suite"
    log_path = artifact_dir / "logs" / "negative-suite.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    suite_report_path = suite_artifact_dir / SUITE_REPORT_NAME

    proc_returncode: int | None = None
    cmd: list[str] = []
    suite_report: dict | None = None

    if not findings:
        suite_artifact_dir.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.pop("KOMA_WASM_SPIKE_ARTIFACT_DIR", None)
        env.pop("KOMA_SOURCE_PACKAGE_ARTIFACT_DIR", None)
        if args.shared_wamr_root:
            env["WAMR_ROOT_DIR"] = str(Path(args.shared_wamr_root).resolve())
        cmd = [
            sys.executable,
            str(wrapper_copy_path),
            "--artifact-dir", str(suite_artifact_dir),
        ]
        proc = subprocess.run(
            cmd,
            cwd=str(repo),
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        proc_returncode = proc.returncode
        log_path.write_text(redact_text(proc.stdout), encoding="utf-8")

        if proc_returncode == 0:
            findings.append(
                f"expected nonzero exit from patched suite, got {proc_returncode}"
            )

        if not suite_report_path.is_file():
            findings.append(
                "patched suite did not write expected report at "
                f"{redact_text(str(suite_report_path))}"
            )
        else:
            try:
                suite_report = json.loads(
                    suite_report_path.read_text(encoding="utf-8")
                )
            except Exception as err:
                findings.append(f"suite report read failed: {err}")

    suite_status: str | None = None
    suite_findings: list[str] = []
    expected_present: dict = {}
    if suite_report is not None:
        suite_status = suite_report.get("status")
        if suite_status != "FAIL":
            findings.append(
                f"expected suite report status 'FAIL', got {suite_status!r}"
            )
        raw_findings = suite_report.get("findings") or []
        if isinstance(raw_findings, list):
            suite_findings = [str(item) for item in raw_findings]
        else:
            findings.append(
                f"suite report findings is not a list: {type(raw_findings).__name__}"
            )
        raw_present = suite_report.get("expectedReportsPresent") or {}
        if isinstance(raw_present, dict):
            expected_present = dict(raw_present)
        else:
            findings.append(
                "suite report expectedReportsPresent is not an object: "
                f"{type(raw_present).__name__}"
            )

        step_exit_match = any(
            STUB_STEP_SUMMARY in entry and entry.startswith("step exit ")
            for entry in suite_findings
        )
        if not step_exit_match:
            findings.append(
                "suite findings do not flag stubbed step "
                f"'{STUB_STEP_SUMMARY}' as exiting nonzero"
            )

        missing_report_match = any(
            "missing expected report" in entry and STUB_STEP_SUMMARY in entry
            for entry in suite_findings
        )
        if not missing_report_match:
            findings.append(
                "suite findings do not flag missing expected report for stubbed step "
                f"'{STUB_STEP_SUMMARY}'"
            )

        if STUB_STEP_KEY not in expected_present:
            findings.append(
                "suite report expectedReportsPresent missing key "
                f"{STUB_STEP_KEY!r}"
            )
        elif expected_present.get(STUB_STEP_KEY) is not False:
            findings.append(
                f"suite report expectedReportsPresent[{STUB_STEP_KEY!r}] is "
                f"{expected_present.get(STUB_STEP_KEY)!r}, expected False"
            )

    status = "PASS" if not findings else "FAIL"

    evidence: list[str] = []
    if status == "PASS":
        evidence = [
            f"patched suite wrapper copy at {redact_text(str(wrapper_copy_path))}",
            f"redaction helper copy at {redact_text(str(redaction_copy_path))}",
            "patched first step replaced with local stub exiting "
            f"{STUB_EXIT_CODE} without writing its expected report",
            f"patched suite exited {proc_returncode} (nonzero)",
            f"suite report at {redact_text(str(suite_report_path))} status=FAIL",
            f"suite findings flagged stubbed step '{STUB_STEP_SUMMARY}' "
            "exit and missing expected report",
            f"suite report expectedReportsPresent[{STUB_STEP_KEY!r}] = false",
        ]

    report = {
        "status": status,
        "artifactDir": redact_text(str(artifact_dir)),
        "wrapperSource": redact_text(str(src_wrapper)),
        "redactionSource": redact_text(str(src_redaction)),
        "wrapperCopy": redact_text(str(wrapper_copy_path)),
        "redactionCopy": redact_text(str(redaction_copy_path)),
        "suiteArtifactDir": redact_text(str(suite_artifact_dir)),
        "suiteReportPath": redact_text(str(suite_report_path)),
        "stubbedStepSummary": STUB_STEP_SUMMARY,
        "stubbedStepKey": STUB_STEP_KEY,
        "stubbedExitCode": STUB_EXIT_CODE,
        "command": redacted_command(cmd) if cmd else "",
        "log": redact_text(str(log_path)),
        "negativeSuiteExitCode": proc_returncode,
        "suiteReportStatus": suite_status,
        "suiteFindings": [redact_text(item) for item in suite_findings],
        "expectedReportsPresent": expected_present,
        "evidence": evidence,
        "findings": findings,
    }

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
