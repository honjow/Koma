#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redact_text, redact_value, write_redacted_json  # noqa: E402


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
FORBIDDEN_TOKENS = (
    "/home/",
    "/tmp/",
    ".p12",
    ".cer",
    ".p7b",
    "secret",
    "token",
    "credential",
    "cookie",
    "authorization",
    "http://",
    "https://",
    "begin private key",
)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def is_scalar(value) -> bool:
    return value is None or isinstance(value, (str, int, bool))


def check_entry(label: str, entry: dict, findings: list[str]) -> None:
    if entry.get("ok") is not True:
        findings.append(f"{label}: ok is not True (got {entry.get('ok')!r})")
    if entry.get("version") != 1:
        findings.append(f"{label}: version != 1 (got {entry.get('version')!r})")
    if entry.get("hostHintsNetwork") is not False:
        findings.append(f"{label}: hostHintsNetwork is not False (got {entry.get('hostHintsNetwork')!r})")
    surface = entry.get("surface")
    if not isinstance(surface, dict) or not surface:
        findings.append(f"{label}: surface is not a non-empty dict")


def scan_forbidden(label: str, payload: dict, findings: list[str]) -> None:
    raw = json.dumps(payload, sort_keys=True).lower()
    leaked = [token for token in FORBIDDEN_TOKENS if token in raw]
    if leaked:
        findings.append(f"{label}: forbidden tokens present: {sorted(leaked)}")


def compare_surfaces(operation: str, direct: dict, archive: dict,
                     mismatches: list[dict], path: str = "") -> None:
    shared = set(direct.keys()) & set(archive.keys())
    for key in sorted(shared):
        d_val = direct[key]
        a_val = archive[key]
        sub_path = f"{path}.{key}" if path else key
        if isinstance(d_val, dict) and isinstance(a_val, dict):
            compare_surfaces(operation, d_val, a_val, mismatches, sub_path)
            continue
        if is_scalar(d_val) and is_scalar(a_val):
            if d_val != a_val:
                mismatches.append({
                    "operation": operation,
                    "path": sub_path,
                    "direct": d_val,
                    "archive": a_val,
                })


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate parity between direct rust fixture and archive smoke runtime operation surfaces."
    )
    parser.add_argument("--direct-report", required=True,
                        help="Path to source-operation-surface-report.json from run-rust-fixture.sh")
    parser.add_argument("--archive-report", required=True,
                        help="Path to source-archive-wamr-smoke-report.json from run-source-archive-smoke.py")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report",
                        help="Report path. Defaults to <artifact-dir>/operation-surface-parity-report.json.")
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    direct_path = Path(args.direct_report).resolve()
    archive_path = Path(args.archive_report).resolve()
    report_path = (Path(args.report).resolve() if args.report
                   else artifact_dir / "operation-surface-parity-report.json")

    findings: list[str] = []
    mismatches: list[dict] = []
    evidence: list[str] = []
    expected = list(EXPECTED_OPERATIONS)
    expected_sorted = sorted(expected)

    direct_report: dict = {}
    archive_report: dict = {}
    try:
        direct_report = read_json(direct_path)
    except Exception as err:
        findings.append(f"direct report read failed: {err}")
    try:
        archive_report = read_json(archive_path)
    except Exception as err:
        findings.append(f"archive report read failed: {err}")

    if not isinstance(direct_report, dict):
        findings.append("direct report root is not a dict")
        direct_report = {}
    if not isinstance(archive_report, dict):
        findings.append("archive report root is not a dict")
        archive_report = {}

    if direct_report.get("operationCount") != 10:
        findings.append(
            f"direct report operationCount is {direct_report.get('operationCount')!r}, expected 10"
        )
    direct_ops = direct_report.get("operations")
    if not isinstance(direct_ops, list):
        findings.append("direct report operations is not a list")
        direct_ops = []

    if archive_report.get("status") != "PASS":
        findings.append(
            f"archive report status is {archive_report.get('status')!r}, expected PASS"
        )
    archive_surface = archive_report.get("operationSurface")
    if not isinstance(archive_surface, dict):
        findings.append("archive report operationSurface is not a dict")
        archive_surface = {}
    if archive_surface.get("operationCount") != 10:
        findings.append(
            f"archive operationSurface.operationCount is "
            f"{archive_surface.get('operationCount')!r}, expected 10"
        )
    archive_ops = archive_surface.get("operations")
    if not isinstance(archive_ops, list):
        findings.append("archive operationSurface.operations is not a list")
        archive_ops = []

    direct_by_op = {
        entry.get("operation"): entry
        for entry in direct_ops if isinstance(entry, dict)
    }
    archive_by_op = {
        entry.get("operation"): entry
        for entry in archive_ops if isinstance(entry, dict)
    }

    if sorted(direct_by_op.keys()) != expected_sorted:
        findings.append(
            f"direct report operations mismatch: "
            f"{sorted(k for k in direct_by_op.keys() if k is not None)} != {expected_sorted}"
        )
    if sorted(archive_by_op.keys()) != expected_sorted:
        findings.append(
            f"archive operationSurface.operations mismatch: "
            f"{sorted(k for k in archive_by_op.keys() if k is not None)} != {expected_sorted}"
        )

    for op in expected:
        direct_entry = direct_by_op.get(op)
        archive_entry = archive_by_op.get(op)
        if not isinstance(direct_entry, dict):
            findings.append(f"direct report missing operation entry: {op}")
            continue
        if not isinstance(archive_entry, dict):
            findings.append(f"archive report missing operation entry: {op}")
            continue
        check_entry(f"direct[{op}]", direct_entry, findings)
        check_entry(f"archive[{op}]", archive_entry, findings)
        direct_surface = direct_entry.get("surface") if isinstance(direct_entry.get("surface"), dict) else {}
        archive_surface_op = archive_entry.get("surface") if isinstance(archive_entry.get("surface"), dict) else {}
        scan_forbidden(f"direct[{op}].surface", direct_surface, findings)
        scan_forbidden(f"archive[{op}].surface", archive_surface_op, findings)
        compare_surfaces(op, direct_surface, archive_surface_op, mismatches)

    status = "PASS" if not findings and not mismatches else "FAIL"

    if status == "PASS":
        evidence.extend([
            f"expected 10 v0.2 operations confirmed: {', '.join(expected)}",
            "direct report operationCount=10 with top-level operations array",
            "archive report status=PASS with operationSurface.operationCount=10 and operations array",
            "every direct/archive entry has ok=true, version=1, hostHintsNetwork=false, non-empty surface",
            "no forbidden tokens present in serialized direct/archive surfaces",
            "shared scalar leaves between direct/archive surfaces matched on parity check",
        ])

    report = {
        "status": status,
        "operations": expected,
        "directReport": redact_text(str(direct_path)),
        "archiveReport": redact_text(str(archive_path)),
        "mismatches": mismatches,
        "findings": findings,
        "evidence": evidence,
    }
    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
