#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
REQUIRED_OPERATIONS = {"search", "get_manga", "get_chapters", "get_pages"}
REQUIRED_ERRORS = {"TIMEOUT", "CANCELLED", "RESOURCE_LIMIT_EXCEEDED"}
HTTP_IMPORT = "koma_host.http_request"
RESULT_CEILINGS = {
    "maxResultJsonBytes": 1048576,
    "maxResultBufferBytes": 1114112,
    "maxSearchItems": 200,
    "maxChapterItems": 1000,
    "maxPageItems": 500,
    "maxPageCountPerChapter": 500,
}
WASM_CEILINGS = {
    "maxWasmBytes": 262144,
    "maxMemoryPages": 4,
    "maxHeapBytes": 262144,
    "maxStackBytes": 65536,
    "maxCallDepth": 128,
}
MAX_TIMEOUT_MS = 10000
EXECUTABLE_KEYS = {
    "command",
    "endpoint",
    "export",
    "function",
    "handler",
    "httpRequest",
    "request",
    "script",
    "url",
    "wasmExport",
}
FORBIDDEN_SCOPE_KEYS = {
    "market",
    "marketplaceUrl",
    "plugin",
    "productRuntimeEnabled",
    "remoteInstallUrl",
    "repository",
    "updateUrl",
    "webView",
}
SECRET_VALUE_KEYS = {
    "authorization",
    "cookie",
    "password",
    "secret",
    "setCookie",
    "token",
}
RAW_SECRET_RE = re.compile(
    r"(Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|Cookie\s*:|Set-Cookie\s*:|"
    r"\b(password|token|secret|api[_-]?key)\s*[=:]\s*[^\\s,;}]+|"
    r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})",
    re.IGNORECASE,
)
PATH_OR_REMOTE_RE = re.compile(
    r"(https?://|ftp://|file://|content://|ohos://|internal://|app-private|"
    r"(^|[\\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|"
    r"[A-Za-z]:\\\\|\\.hermes-artifacts|/cache/|/files/|/Documents/)",
    re.IGNORECASE,
)


class ValidationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    require(isinstance(value, dict), "fixture root must be an object")
    return value


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def walk(value: Any, path: str = "$") -> list[tuple[str, Any]]:
    hits = [(path, value)]
    if isinstance(value, dict):
        for key, child in value.items():
            hits.extend(walk(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            hits.extend(walk(child, f"{path}[{index}]"))
    return hits


def validate_no_leaks(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, str):
            require(not RAW_SECRET_RE.search(item), f"{path} leaks raw credential material")
            require(not PATH_OR_REMOTE_RE.search(item), f"{path} leaks remote URL or local/app-private path")
        if isinstance(item, dict):
            for key, child in item.items():
                if key in SECRET_VALUE_KEYS and isinstance(child, str):
                    require(False, f"{path}.{key} contains inline secret-like value")


def validate_no_executable_or_scope_flags(value: Any) -> None:
    for path, item in walk(value):
        if not isinstance(item, dict):
            continue
        for key, child in item.items():
            require(key not in EXECUTABLE_KEYS, f"{path}.{key} must not be executable")
            require(key not in FORBIDDEN_SCOPE_KEYS, f"{path}.{key} is outside tooling-only scope")
            if key in {"enabled", "networkEnabled", "remoteInstall", "sourceMarket", "marketplace", "builtInSource"}:
                require(child is False, f"{path}.{key} must be false")
            if key in {"runtimeEnabled", "designOnly"}:
                expected = key == "designOnly"
                require(child is expected, f"{path}.{key} must be {str(expected).lower()}")


def positive_int(value: Any, path: str, maximum: int) -> int:
    require(isinstance(value, int) and not isinstance(value, bool), f"{path} must be an integer")
    require(1 <= value <= maximum, f"{path} must be between 1 and {maximum}")
    return value


def validate_current_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require(runtime.get("network") is False, "network must remain false")
    imports = runtime.get("hostImports")
    require(isinstance(imports, list), "currentRuntime.hostImports must be a list")
    require(imports == ALLOWED_IMPORTS, "hostImports must be exactly koma_host.log/check_cancel")
    require(HTTP_IMPORT not in imports, "current runtime forbids koma_host.http_request import")


def validate_results(value: Any) -> None:
    require(isinstance(value, dict), "resourceLimits.results object is required")
    for key, maximum in RESULT_CEILINGS.items():
        positive_int(value.get(key), f"resourceLimits.results.{key}", maximum)
    require(value["maxResultJsonBytes"] <= value["maxResultBufferBytes"],
            "maxResultJsonBytes must fit within maxResultBufferBytes")
    require(value.get("truncation") == "error", "resourceLimits.results.truncation must be error")


def validate_wasm(value: Any) -> None:
    require(isinstance(value, dict), "resourceLimits.wasm object is required")
    for key, maximum in WASM_CEILINGS.items():
        positive_int(value.get(key), f"resourceLimits.wasm.{key}", maximum)
    budget = value.get("operationBudget")
    require(isinstance(budget, dict), "resourceLimits.wasm.operationBudget object is required")
    require(budget.get("kind") in {"hostDefined", "instruction"}, "operationBudget.kind is unsupported")
    positive_int(budget.get("maxUnits"), "resourceLimits.wasm.operationBudget.maxUnits", 10000000)
    require(isinstance(budget.get("enforced"), bool), "operationBudget.enforced must be boolean")


def validate_timeouts(value: Any) -> None:
    require(isinstance(value, dict), "resourceLimits.timeouts object is required")
    per_operation = value.get("perOperationMs")
    require(isinstance(per_operation, dict), "resourceLimits.timeouts.perOperationMs object is required")
    require(set(per_operation.keys()) == REQUIRED_OPERATIONS,
            "timeouts must declare search/get_manga/get_chapters/get_pages")
    for operation in sorted(REQUIRED_OPERATIONS):
        positive_int(per_operation.get(operation), f"resourceLimits.timeouts.perOperationMs.{operation}", MAX_TIMEOUT_MS)
    require(value.get("hostOwnedWallClock") is True, "resourceLimits.timeouts.hostOwnedWallClock must be true")


def validate_cancellation(value: Any) -> None:
    require(isinstance(value, dict), "resourceLimits.cancellation object is required")
    require(value.get("required") is True, "cancellation.required must be true")
    require(value.get("hostImport") == "koma_host.check_cancel", "cancellation.hostImport must be koma_host.check_cancel")
    require(value.get("sourceSdkKeepsImport") is True, "cancellation.sourceSdkKeepsImport must be true")
    polling = value.get("polling")
    require(isinstance(polling, dict), "cancellation.polling object is required")
    require(polling.get("beforeOperation") is True, "cancellation polling beforeOperation must be true")
    require(polling.get("duringResultLoops") is True, "cancellation polling duringResultLoops must be true")
    positive_int(polling.get("maxItemsBetweenPolls"), "cancellation.polling.maxItemsBetweenPolls", 64)


def validate_logging(value: Any) -> None:
    require(isinstance(value, dict), "resourceLimits.logging object is required")
    for key in ("redactBodies", "redactHeaders", "redactPaths", "includeRequestId"):
        require(value.get(key) is True, f"resourceLimits.logging.{key} must be true")
    require("sampleBody" not in value and "body" not in value, "resourceLimits.logging must not include body samples")


def validate_policy(value: dict[str, Any]) -> None:
    require(value.get("boundaryVersion") == 1, "boundaryVersion must be 1")
    require(value.get("designOnly") is True, "designOnly must be true")
    require(value.get("runtimeEnabled") is False, "runtimeEnabled must be false")
    validate_no_leaks(value)
    validate_no_executable_or_scope_flags(value)
    validate_current_runtime(value)
    limits = value.get("resourceLimits")
    require(isinstance(limits, dict), "resourceLimits object is required")
    validate_results(limits.get("results"))
    validate_wasm(limits.get("wasm"))
    validate_timeouts(limits.get("timeouts"))
    validate_cancellation(limits.get("cancellation"))
    errors = limits.get("errors")
    require(isinstance(errors, list), "resourceLimits.errors must be a list")
    require(set(errors) == REQUIRED_ERRORS, "resourceLimits.errors must contain TIMEOUT/CANCELLED/RESOURCE_LIMIT_EXCEEDED")
    validate_logging(limits.get("logging"))
    product = value.get("productRuntime")
    require(isinstance(product, dict), "productRuntime object is required")
    for key in ("enabled", "networkEnabled", "remoteInstall", "sourceMarket"):
        require(product.get(key) is False, f"productRuntime.{key} must be false")


def collect_json_files(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def validate_invalid_fixture(path: Path) -> dict[str, Any]:
    fixture = read_json(path)
    case_name = fixture.get("case")
    expect = fixture.get("expectRejectContains")
    input_value = fixture.get("input")
    require(isinstance(case_name, str) and case_name, "case must be a non-empty string")
    require(isinstance(expect, str) and expect, "expectRejectContains must be a non-empty string")
    require(isinstance(input_value, dict), "input must be an object")
    try:
        validate_policy(input_value)
    except Exception as err:
        reason = str(err)
        require(expect.lower() in reason.lower(),
                f"rejection reason did not contain expected text: {expect}")
        return {
            "file": str(path),
            "case": case_name,
            "expected": "reject",
            "status": "PASS",
            "reason": reason,
        }
    return {
        "file": str(path),
        "case": case_name,
        "expected": "reject",
        "status": "FAIL",
        "reason": "invalid fixture was accepted",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate design-only resource limit/cancellation/timeout fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/resource-limit-fixtures-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "resource-limit-fixtures-report.json"
    report: dict[str, Any] = {
        "status": "FAIL",
        "fixtureDir": str(fixture_dir),
        "artifactDir": str(artifact_dir),
        "validCases": 0,
        "invalidCases": 0,
        "cases": [],
        "evidence": [],
    }

    try:
        for path in collect_json_files(fixture_dir / "valid"):
            try:
                validate_policy(read_json(path))
                case = {"file": str(path), "expected": "accept", "status": "PASS"}
                report["validCases"] += 1
            except Exception as err:
                case = {"file": str(path), "expected": "accept", "status": "FAIL", "reason": str(err)}
            report["cases"].append(case)

        for path in collect_json_files(fixture_dir / "invalid"):
            case = validate_invalid_fixture(path)
            if case["status"] == "PASS":
                report["invalidCases"] += 1
            report["cases"].append(case)

        failing = [case for case in report["cases"] if case["status"] != "PASS"]
        require(not failing, f"{len(failing)} resource limit fixture case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid resource boundary fixture(s) accepted",
            f"{report['invalidCases']} invalid resource boundary fixture(s) rejected",
            "network=false and exact log/check_cancel host imports enforced",
            "timeout, cancellation, result, wasm, logging, and product-runtime gates enforced",
            "remote URL, path, and credential-shaped values rejected without echoing leaked values",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
