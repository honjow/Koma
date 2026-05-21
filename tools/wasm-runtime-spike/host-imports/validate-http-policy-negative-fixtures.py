#!/usr/bin/env python3
import argparse
import base64
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redact_value, write_redacted_json  # noqa: E402
from urllib.parse import urlparse


HTTP_IMPORT = "koma_host.http_request"
ALLOWED_METHODS = {"GET", "HEAD", "POST"}
ALLOWED_SCHEMES = {"https"}
DENIED_HEADERS = {
    "authorization",
    "cookie",
    "host",
    "proxy-authorization",
    "referer",
    "set-cookie",
}
SECRET_RE = re.compile(r"(authorization|bearer|cookie|password|secret|set-cookie|token)", re.IGNORECASE)
PATH_LEAK_RE = re.compile(
    r"(^/home/|^/Users/|^/data/|^/storage/|^/sdcard/|^/mnt/|"
    r"^[A-Za-z]:\\|file://|content://|ohos://|internal://|app-private|"
    r"\.hermes-artifacts|/cache/|/files/|/Documents/)"
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


def write_json(path: Path, value: dict[str, Any]) -> None:
    write_redacted_json(path, value)


def walk_strings(value: Any, path: str = "$") -> list[tuple[str, str]]:
    if isinstance(value, str):
        return [(path, value)]
    if isinstance(value, dict):
        hits: list[tuple[str, str]] = []
        for key, child in value.items():
            hits.extend(walk_strings(child, f"{path}.{key}"))
        return hits
    if isinstance(value, list):
        hits = []
        for index, child in enumerate(value):
            hits.extend(walk_strings(child, f"{path}[{index}]"))
        return hits
    return []


def required_imports(value: dict[str, Any]) -> set[str]:
    imports = value.get("requiredHostImports", [])
    require(isinstance(imports, list), "manifest requiredHostImports must be a list")
    names: set[str] = set()
    for item in imports:
        if isinstance(item, str):
            names.add(item)
        elif isinstance(item, dict):
            names.add(f"{item.get('module')}.{item.get('name')}")
    return names


def permission_imports(value: dict[str, Any]) -> set[str]:
    imports = value.get("hostImports", [])
    require(isinstance(imports, list), "manifest hostImports must be a list")
    return {item for item in imports if isinstance(item, str)}


def validate_manifest_closed(value: dict[str, Any]) -> None:
    permissions = value.get("permissions")
    require(isinstance(permissions, dict), "manifest permissions object is required")
    runtime = value.get("runtime", {})
    require(isinstance(runtime, dict), "manifest runtime object is required")
    require(permissions.get("network") is False, "network must remain false for current source runtime")
    require(HTTP_IMPORT not in permission_imports(permissions), "current runtime forbids koma_host.http_request permission")
    require(HTTP_IMPORT not in required_imports(runtime), "current runtime forbids koma_host.http_request import")


def validate_permission_gate(value: dict[str, Any]) -> None:
    manifest = value.get("manifest")
    request = value.get("request")
    require(isinstance(manifest, dict), "permission fixture manifest object is required")
    require(isinstance(request, dict), "permission fixture request object is required")
    permissions = manifest.get("permissions")
    runtime = manifest.get("runtime", {})
    require(isinstance(permissions, dict), "manifest permissions object is required")
    require(isinstance(runtime, dict), "manifest runtime object is required")
    has_permission = HTTP_IMPORT in permission_imports(permissions)
    has_import = HTTP_IMPORT in required_imports(runtime)
    network = permissions.get("network") is True
    require(network and has_permission and has_import,
            "missing permission/import: HTTP request shape cannot run without network and koma_host.http_request")
    validate_http_request_schema(request)


def validate_source_response_closed(value: dict[str, Any]) -> None:
    host_hints = value.get("hostHints")
    require(isinstance(host_hints, dict), "hostHints object is required")
    network = host_hints.get("network")
    require(network is False, "hostHints.network must be false for current runtime fixtures")
    for path, string in walk_strings(value):
        require(not PATH_LEAK_RE.search(string), f"{path} leaks raw local/app-private path")
    for path, item in walk_image_descriptors(value):
        kind = item.get("kind")
        require(kind in {"none", "placeholder"}, f"{path}.kind={kind} is gated while network=false")


def walk_image_descriptors(value: Any, path: str = "$") -> list[tuple[str, dict[str, Any]]]:
    hits: list[tuple[str, dict[str, Any]]] = []
    if isinstance(value, dict):
        if "kind" in value and ("url" in value or "request" in value or value.get("kind") in {"remoteUrl", "imageRequest"}):
            hits.append((path, value))
        for key, child in value.items():
            hits.extend(walk_image_descriptors(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            hits.extend(walk_image_descriptors(child, f"{path}[{index}]"))
    return hits


def validate_http_request_schema(value: dict[str, Any]) -> None:
    method = value.get("method")
    require(method in ALLOWED_METHODS, f"method denied: {method}")
    parsed = urlparse(value.get("url", ""))
    require(parsed.scheme in ALLOWED_SCHEMES, f"scheme denied: {parsed.scheme or '<missing>'}")
    require(not parsed.username and not parsed.password, "raw credentials in URL are denied")
    headers = value.get("headers", {})
    require(isinstance(headers, dict), "headers must be an object")
    for name, header_value in headers.items():
        lower = name.lower()
        require(lower not in DENIED_HEADERS, f"denied header: {name}")
        require(not SECRET_RE.search(name), f"secret-shaped header denied: {name}")
        require(not (isinstance(header_value, str) and SECRET_RE.search(header_value)),
                f"raw credential header value denied: {name}")
    body = value.get("bodyBase64")
    if body is not None:
        require(method == "POST", "request body is only allowed for POST")
        require(isinstance(body, str), "bodyBase64 must be a string")
        try:
            decoded = base64.b64decode(body, validate=True)
        except Exception as err:
            raise ValidationError("bodyBase64 must be valid base64") from err
        max_request_bytes = value.get("maxRequestBytes", 65536)
        require(isinstance(max_request_bytes, int), "maxRequestBytes must be an integer")
        require(len(decoded) <= max_request_bytes, "request exceeds max body size")
    max_response_bytes = value.get("maxResponseBytes", 1048576)
    require(isinstance(max_response_bytes, int), "maxResponseBytes must be an integer")
    require(0 < max_response_bytes <= 1048576, "response max bytes exceeds policy")


def validate_redirect(value: dict[str, Any]) -> None:
    from_url = urlparse(value.get("from", ""))
    to_url = urlparse(value.get("to", ""))
    require(from_url.scheme == "https", "redirect source must be https for downgrade check")
    require(to_url.scheme == "https", "redirect downgrade https -> http is denied")


def validate_log_redaction(value: dict[str, Any]) -> None:
    for path, string in walk_strings(value):
        require(not SECRET_RE.search(string), f"{path} leaks cookie or credential/token")


def validate_path_leak(value: dict[str, Any]) -> None:
    for path, string in walk_strings(value):
        require(not PATH_LEAK_RE.search(string), f"{path} leaks raw local/app-private path")


def validate_input(category: str, value: dict[str, Any]) -> None:
    validators = {
        "manifest": validate_manifest_closed,
        "permission_gate": validate_permission_gate,
        "request_schema": validate_http_request_schema,
        "source_response": validate_source_response_closed,
        "redirect": validate_redirect,
        "log_redaction": validate_log_redaction,
        "path_leak": validate_path_leak,
    }
    validator = validators.get(category)
    require(validator is not None, f"unknown category: {category}")
    validator(value)


def validate_fixture(path: Path) -> dict[str, Any]:
    fixture = read_json(path)
    case_name = fixture.get("case")
    category = fixture.get("category")
    expect = fixture.get("expectRejectContains")
    require(isinstance(case_name, str) and case_name, "case must be a non-empty string")
    require(isinstance(category, str) and category, "category must be a non-empty string")
    require(isinstance(expect, str) and expect, "expectRejectContains must be a non-empty string")
    try:
        input_value = fixture.get("input")
        require(isinstance(input_value, dict), "input must be an object")
        validate_input(category, input_value)
    except Exception as err:
        reason = str(err)
        expected = expect.lower()
        require(expected in reason.lower(), f"rejection reason did not contain expected text: {expect}; actual: {reason}")
        return {
            "case": case_name,
            "category": category,
            "expectedRejection": expect,
            "actualStatus": "REJECTED",
            "reason": reason,
            "status": "PASS",
            "file": str(path),
        }
    return {
        "case": case_name,
        "category": category,
        "expectedRejection": expect,
        "actualStatus": "ACCEPTED",
        "reason": "fixture was accepted",
        "status": "FAIL",
        "file": str(path),
    }


def collect_fixtures(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate static negative fixtures for the design-only HTTP policy boundary.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/http-policy-negative-fixtures-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "http-policy-negative-fixtures-report.json"
    report: dict[str, Any] = {
        "status": "FAIL",
        "fixtureDir": str(fixture_dir),
        "artifactDir": str(artifact_dir),
        "caseCount": 0,
        "categories": [],
        "cases": [],
        "evidence": [],
    }
    try:
        for path in collect_fixtures(fixture_dir):
            case = validate_fixture(path)
            report["cases"].append(case)
        failing = [case for case in report["cases"] if case["status"] != "PASS"]
        require(not failing, f"{len(failing)} negative fixture(s) failed")
        categories = sorted({case["category"] for case in report["cases"]})
        report.update({
            "status": "PASS",
            "caseCount": len(report["cases"]),
            "categories": categories,
            "evidence": [
                f"{len(report['cases'])} static HTTP/network policy negative fixtures rejected",
                "validator performs no network I/O and does not execute WAMR",
                "current runtime policy remains closed with network=false",
            ],
        })
    except Exception as err:
        report["error"] = str(err)
        report["status"] = "FAIL"

    write_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
