#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


HTTP_IMPORT = "koma_host.http_request"
ALLOWED_SETTING_TYPES = {"string", "enum", "bool", "number", "int", "secret"}
ALLOWED_SECRET_PURPOSES = {"password", "token", "cookie", "apiKey", "oauthRefresh", "session"}
ALLOWED_ERROR_CODES = {
    "AUTH_REQUIRED",
    "AUTH_EXPIRED",
    "BAD_CREDENTIALS",
    "RATE_LIMITED",
    "ACCOUNT_LOCKED",
    "HOST_CREDENTIAL_UNAVAILABLE",
    "NETWORK_REQUIRED_BUT_DISABLED",
}
EXECUTABLE_KEYS = {
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
SECRET_VALUE_KEYS = {
    "authorization",
    "authHeader",
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
PATH_LEAK_RE = re.compile(
    r"(^/home/|^/Users/|^/data/|^/storage/|^/sdcard/|^/mnt/|"
    r"^[A-Za-z]:\\|file://|content://|ohos://|internal://|app-private|"
    r"\.hermes-artifacts|/cache/|/files/|/Documents/)"
)
KEY_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,63}$")


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
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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
            require(not PATH_LEAK_RE.search(item), f"{path} leaks raw local/picker/app-private path")
        if isinstance(item, dict):
            for key, child in item.items():
                if key in SECRET_VALUE_KEYS and isinstance(child, str):
                    require(False, f"{path}.{key} contains inline secret-like value")


def validate_current_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require(runtime.get("network") is False, "network must remain false for current source runtime")
    imports = runtime.get("hostImports")
    require(isinstance(imports, list), "currentRuntime.hostImports must be a list")
    require(HTTP_IMPORT not in imports, "current runtime forbids koma_host.http_request import")
    require(set(imports).issubset({"koma_host.log", "koma_host.check_cancel"}),
            "currentRuntime.hostImports contains unsupported host import")


def validate_default(field: dict[str, Any], path: str) -> None:
    field_type = field["type"]
    if "default" not in field:
        return
    default = field["default"]
    if field_type == "secret":
        require(False, f"{path}.default is forbidden for secret fields")
    if field_type == "string":
        require(isinstance(default, str), f"{path}.default must be a string")
    elif field_type == "enum":
        require(isinstance(default, str), f"{path}.default must be an enum string")
        options = option_values(field.get("options"), path)
        require(default in options, f"{path}.default must be one of options")
    elif field_type == "bool":
        require(isinstance(default, bool), f"{path}.default must be boolean")
    elif field_type == "number":
        require(isinstance(default, (int, float)) and not isinstance(default, bool),
                f"{path}.default must be numeric")
    elif field_type == "int":
        require(isinstance(default, int) and not isinstance(default, bool),
                f"{path}.default must be integer")


def option_values(options: Any, path: str) -> set[str]:
    require(isinstance(options, list) and options, f"{path}.options must be a non-empty list")
    values: set[str] = set()
    for index, item in enumerate(options):
        if isinstance(item, str):
            value = item
        else:
            require(isinstance(item, dict), f"{path}.options[{index}] must be a string or object")
            value = item.get("value")
            require(isinstance(item.get("label"), str) and item["label"], f"{path}.options[{index}].label is required")
        require(isinstance(value, str) and value, f"{path}.options[{index}].value must be a non-empty string")
        require(value not in values, f"{path}.options has duplicate values")
        values.add(value)
    return values


def validate_constraints(field: dict[str, Any], path: str) -> None:
    constraints = field.get("constraints")
    if constraints is None:
        return
    require(isinstance(constraints, dict), f"{path}.constraints must be an object")
    field_type = field["type"]
    allowed = {
        "string": {"minLength", "maxLength", "pattern"},
        "enum": set(),
        "bool": set(),
        "number": {"min", "max"},
        "int": {"min", "max"},
        "secret": set(),
    }[field_type]
    require(set(constraints.keys()).issubset(allowed), f"{path}.constraints has unsupported keys")
    if field_type == "string":
        if "minLength" in constraints:
            require(isinstance(constraints["minLength"], int) and constraints["minLength"] >= 0,
                    f"{path}.constraints.minLength must be a non-negative integer")
        if "maxLength" in constraints:
            require(isinstance(constraints["maxLength"], int) and constraints["maxLength"] >= 1,
                    f"{path}.constraints.maxLength must be a positive integer")
        if "minLength" in constraints and "maxLength" in constraints:
            require(constraints["minLength"] <= constraints["maxLength"],
                    f"{path}.constraints minLength exceeds maxLength")
        if "pattern" in constraints:
            require(isinstance(constraints["pattern"], str) and constraints["pattern"],
                    f"{path}.constraints.pattern must be a non-empty string")
            re.compile(constraints["pattern"])
    if field_type in {"number", "int"}:
        for name in ("min", "max"):
            if name in constraints:
                expected = int if field_type == "int" else (int, float)
                require(isinstance(constraints[name], expected) and not isinstance(constraints[name], bool),
                        f"{path}.constraints.{name} must match numeric type")
        if "min" in constraints and "max" in constraints:
            require(constraints["min"] <= constraints["max"], f"{path}.constraints min exceeds max")


def validate_secret_ref(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path}.secretRef must be an object")
    require(set(value.keys()).issubset({"id", "purpose", "required"}), f"{path}.secretRef has unsupported keys")
    require(isinstance(value.get("id"), str) and KEY_RE.match(value["id"]),
            f"{path}.secretRef.id must be an opaque identifier")
    require(value.get("purpose") in ALLOWED_SECRET_PURPOSES, f"{path}.secretRef.purpose is unsupported")
    if "required" in value:
        require(isinstance(value["required"], bool), f"{path}.secretRef.required must be boolean")


def validate_setting(field: Any, path: str, seen: set[str]) -> None:
    require(isinstance(field, dict), f"{path} must be an object")
    require(set(field.keys()).issubset({
        "key", "type", "label", "description", "required", "default", "constraints", "options", "secretRef"
    }), f"{path} has unsupported keys")
    key = field.get("key")
    require(isinstance(key, str) and KEY_RE.match(key), f"{path}.key must be an opaque identifier")
    require(key not in seen, f"{path}.key is duplicated")
    seen.add(key)
    field_type = field.get("type")
    require(field_type in ALLOWED_SETTING_TYPES, f"{path}.type is unsupported")
    require(isinstance(field.get("label"), str) and field["label"], f"{path}.label is required")
    if "description" in field:
        require(isinstance(field["description"], str), f"{path}.description must be a string")
    require(isinstance(field.get("required"), bool), f"{path}.required must be boolean")
    if field_type == "enum":
        option_values(field.get("options"), path)
    else:
        require("options" not in field, f"{path}.options is only valid for enum")
    if field_type == "secret":
        require("secretRef" in field, f"{path}.secretRef is required for secret fields")
        validate_secret_ref(field["secretRef"], path)
    else:
        require("secretRef" not in field, f"{path}.secretRef is only valid for secret fields")
    validate_default(field, path)
    validate_constraints(field, path)


def validate_settings(value: dict[str, Any]) -> None:
    settings = value.get("settings")
    require(isinstance(settings, list), "settings must be a list")
    seen: set[str] = set()
    for index, field in enumerate(settings):
        validate_setting(field, f"settings[{index}]", seen)


def validate_auth(value: dict[str, Any]) -> None:
    auth = value.get("auth")
    require(isinstance(auth, dict), "auth object is required")
    require(auth.get("designOnly") is True, "auth.designOnly must be true")
    require(auth.get("hostOwnedStorage") is True, "auth.hostOwnedStorage must be true")
    require(auth.get("sourceStoresCredentials") is False, "auth.sourceStoresCredentials must be false")
    operations = auth.get("operations")
    require(isinstance(operations, dict), "auth.operations must be an object")
    require(set(operations.keys()).issubset({"login", "logout", "status", "session"}),
            "auth.operations contains unsupported operation")
    for name, operation in operations.items():
        path = f"auth.operations.{name}"
        require(isinstance(operation, dict), f"{path} must be an object")
        require(operation.get("designOnly") is True, f"{path}.designOnly must be true")
        require(operation.get("runtimeEnabled") is False, f"{path}.runtimeEnabled must be false")
        require(not any(key in operation for key in EXECUTABLE_KEYS), f"{path} must not be executable")
    errors = auth.get("errors", [])
    require(isinstance(errors, list), "auth.errors must be a list")
    for index, error in enumerate(errors):
        path = f"auth.errors[{index}]"
        require(isinstance(error, dict), f"{path} must be an object")
        require(error.get("code") in ALLOWED_ERROR_CODES, f"{path}.code is unsupported")
        require(isinstance(error.get("message"), str) and error["message"], f"{path}.message is required")
        if "retryAfterSeconds" in error:
            require(isinstance(error["retryAfterSeconds"], int) and error["retryAfterSeconds"] >= 0,
                    f"{path}.retryAfterSeconds must be a non-negative integer")


def validate_credential_policy(value: dict[str, Any]) -> None:
    policy = value.get("credentialPolicy")
    require(isinstance(policy, dict), "credentialPolicy object is required")
    required_false = {"sourceStoresCredentials", "sourceOwnsCookieJar"}
    required_true = {
        "hostOwnedStorage",
        "hostOwnedSession",
        "redactLogs",
        "denyRawAuthorizationHeaders",
        "denyRawCookies",
        "denyAppPrivatePathLeaks",
    }
    for key in required_true:
        require(policy.get(key) is True, f"credentialPolicy.{key} must be true")
    for key in required_false:
        require(policy.get(key) is False, f"credentialPolicy.{key} must be false")


def validate_boundary(value: dict[str, Any]) -> None:
    require(value.get("boundaryVersion") == 1, "boundaryVersion must be 1")
    validate_no_leaks(value)
    validate_current_runtime(value)
    validate_settings(value)
    validate_auth(value)
    validate_credential_policy(value)


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
        validate_boundary(input_value)
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
    parser = argparse.ArgumentParser(description="Validate design-only source settings/auth boundary fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/settings-auth-fixtures-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "settings-auth-fixtures-report.json"
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
                validate_boundary(read_json(path))
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
        require(not failing, f"{len(failing)} settings/auth fixture case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid settings/auth fixtures accepted",
            f"{report['invalidCases']} invalid settings/auth fixtures rejected",
            "network=false and no koma_host.http_request enforced for current runtime",
            "auth operations constrained to designOnly=true and runtimeEnabled=false",
            "secret-like values and local/app-private paths rejected without echoing leaked values",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
