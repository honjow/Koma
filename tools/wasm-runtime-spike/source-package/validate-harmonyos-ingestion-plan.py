#!/usr/bin/env python3
import argparse
import copy
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redact_value, write_redacted_json  # noqa: E402


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
HTTP_IMPORT = "koma_host.http_request"
REQUIRED_GATES = [
    "copy_to_app_private_staging",
    "archive_safety",
    "manifest_parse_schema",
    "wasm_hash_size",
    "trust_provenance",
    "abi_import_network_policy",
    "settings_auth_policy",
    "resource_limits_policy",
    "image_page_policy",
    "atomic_promote_register",
]
REQUIRED_STOP_CONDITIONS = {
    "product_decision",
    "internal_dev_ux",
    "signing_trust",
    "storage_quota",
    "app_logging",
    "network_permission",
}
FORBIDDEN_TRUE_KEYS = {
    "builtInSources",
    "deviceCommands",
    "executeOrTrustSharedPickerUri",
    "fullManifestByDefault",
    "includePickerUri",
    "includeRawSharedPath",
    "includeUnvalidatedBytes",
    "largeResponsesByDefault",
    "productRuntime",
    "productUi",
    "publicIndex",
    "rawPickerUris",
    "rawUserPaths",
    "remoteInstall",
    "remoteUrlsAccepted",
    "runtimeImplementation",
    "secrets",
    "sourceMarket",
    "sourceRepositorySync",
    "webViewDsl",
}
FORBIDDEN_KEYS = {
    "command",
    "endpoint",
    "httpRequest",
    "installScreen",
    "marketplaceUrl",
    "pickerImplementation",
    "registryImplementation",
    "remoteInstallUrl",
    "script",
    "url",
    "wasmLoaderImplementation",
}
SECRET_VALUE_KEYS = {"authorization", "cookie", "password", "secret", "setCookie", "token"}
RAW_SECRET_RE = re.compile(
    r"(Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|Cookie\s*:|Set-Cookie\s*:|"
    r"\b(password|token|secret|api[_-]?key)\s*[=:]\s*[^\s,;}]+|"
    r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})",
    re.IGNORECASE,
)
RAW_PATH_OR_REMOTE_RE = re.compile(
    r"(https?://|ftp://|file://|content://|ohos://|app-private|"
    r"(^|[\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|"
    r"[A-Za-z]:\\|\.hermes-artifacts|/cache/|/files/|/Documents/)",
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
    require(isinstance(value, dict), "json root must be an object")
    return value


def write_json(path: Path, payload: dict[str, Any]) -> None:
    write_redacted_json(path, payload)


def walk(value: Any, path: str = "$") -> list[tuple[str, Any]]:
    hits = [(path, value)]
    if isinstance(value, dict):
        for key, child in value.items():
            hits.extend(walk(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            hits.extend(walk(child, f"{path}[{index}]"))
    return hits


def set_path(value: dict[str, Any], path: str, replacement: Any) -> None:
    parts = path.split(".")
    current: Any = value
    for part in parts[:-1]:
        require(isinstance(current, dict) and part in current, f"mutation path missing: {path}")
        current = current[part]
    require(isinstance(current, dict), f"mutation parent is not an object: {path}")
    current[parts[-1]] = replacement


def remove_path(value: dict[str, Any], path: str) -> None:
    parts = path.split(".")
    current: Any = value
    for part in parts[:-1]:
        require(isinstance(current, dict) and part in current, f"mutation path missing: {path}")
        current = current[part]
    require(isinstance(current, dict), f"mutation parent is not an object: {path}")
    current.pop(parts[-1], None)


def mutated(base: dict[str, Any], case: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(base)
    for mutation in case.get("mutations", []):
        require(isinstance(mutation, dict), "mutation must be an object")
        path = mutation.get("path")
        require(isinstance(path, str) and path, "mutation.path must be a non-empty string")
        action = mutation.get("action", "set")
        if action == "set":
            require("value" in mutation, "set mutation requires value")
            set_path(value, path, mutation["value"])
        elif action == "remove":
            remove_path(value, path)
        else:
            raise ValidationError(f"unsupported mutation action: {action}")
    return value


def validate_no_leaks_or_executable_shape(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, str):
            require(not RAW_SECRET_RE.search(item), f"{path} leaks raw credential material")
            require(not RAW_PATH_OR_REMOTE_RE.search(item), f"{path} leaks raw path, picker URI, or remote URL")
        if isinstance(item, dict):
            for key, child in item.items():
                require(key not in FORBIDDEN_KEYS, f"{path}.{key} is outside design-only planning scope")
                if key in FORBIDDEN_TRUE_KEYS:
                    require(child is False, f"{path}.{key} must be false")
                if key in SECRET_VALUE_KEYS and isinstance(child, str):
                    require(False, f"{path}.{key} contains inline secret-like value")


def require_bool(value: dict[str, Any], key: str, expected: bool, path: str) -> None:
    require(value.get(key) is expected, f"{path}.{key} must be {str(expected).lower()}")


def validate_scope(value: dict[str, Any]) -> None:
    require_bool(value, "designOnly", True, "$")
    require_bool(value, "productRuntime", False, "$")
    scope = value.get("scope")
    require(isinstance(scope, dict), "scope object is required")
    require_bool(scope, "internalDevOnly", True, "scope")
    for key in ("productUi", "runtimeImplementation", "deviceCommands", "sourceMarket",
                "publicIndex", "remoteInstall", "builtInSources", "webViewDsl"):
        require_bool(scope, key, False, "scope")


def validate_input_and_storage(value: dict[str, Any]) -> None:
    input_boundary = value.get("inputBoundary")
    require(isinstance(input_boundary, dict), "inputBoundary object is required")
    require(input_boundary.get("archiveKind") == "koma-source-zip", "inputBoundary.archiveKind must be koma-source-zip")
    require_bool(input_boundary, "localDeveloperProvidedArchiveOnly", True, "inputBoundary")
    require_bool(input_boundary, "remoteUrlsAccepted", False, "inputBoundary")
    require_bool(input_boundary, "sourceRepositorySync", False, "inputBoundary")
    require_bool(input_boundary, "copyPickerUriToAppPrivateStagingBeforeValidation", True, "inputBoundary")
    require_bool(input_boundary, "executeOrTrustSharedPickerUri", False, "inputBoundary")

    storage = value.get("storage")
    require(isinstance(storage, dict), "storage object is required")
    for key in ("appPrivateStagingRequired", "deriveLayoutFromManifest", "atomicPromoteBeforeRegister",
                "cleanupOnValidationFailure", "cleanupOnPartialExtract", "cleanupOnCrashOrInterruption",
                "quotaDecisionRequiredBeforeImplementation"):
        require_bool(storage, key, True, "storage")
    layout = storage.get("deterministicLayout")
    require(layout == ["normalizedPackageId", "normalizedVersion"],
            "storage.deterministicLayout must be packageId/version")


def validate_order(value: dict[str, Any]) -> None:
    order = value.get("validationOrder")
    require(isinstance(order, list) and all(isinstance(item, str) for item in order),
            "validationOrder must be a list of strings")
    for gate in REQUIRED_GATES:
        require(gate in order, f"validationOrder missing {gate}")
    positions = {gate: order.index(gate) for gate in REQUIRED_GATES}
    for earlier, later in zip(REQUIRED_GATES, REQUIRED_GATES[1:]):
        require(positions[earlier] < positions[later],
                f"validationOrder must run {earlier} before {later}")


def validate_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require_bool(runtime, "network", False, "currentRuntime")
    imports = runtime.get("hostImports")
    require(imports == ALLOWED_IMPORTS, "currentRuntime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in imports, "currentRuntime.hostImports must not include http_request")
    require_bool(runtime, "httpHostImport", False, "currentRuntime")

    handoff = value.get("runtimeHandoff")
    require(isinstance(handoff, dict), "runtimeHandoff object is required")
    require_bool(handoff, "validatedExtractedWasmOnly", True, "runtimeHandoff")
    require_bool(handoff, "parsedManifestOnly", True, "runtimeHandoff")
    for key in ("includePickerUri", "includeRawSharedPath", "includeUnvalidatedBytes"):
        require_bool(handoff, key, False, "runtimeHandoff")


def validate_diagnostics_and_future(value: dict[str, Any]) -> None:
    diagnostics = value.get("diagnostics")
    require(isinstance(diagnostics, dict), "diagnostics object is required")
    require_bool(diagnostics, "redactedLogs", True, "diagnostics")
    for key in ("rawUserPaths", "rawPickerUris", "secrets", "fullManifestByDefault", "largeResponsesByDefault"):
        require_bool(diagnostics, key, False, "diagnostics")

    rollback = value.get("rollbackRemovalUpdate")
    require(isinstance(rollback, dict), "rollbackRemovalUpdate object is required")
    for key in ("duplicatePackageVersionDecisionRequired", "downgradeDecisionRequired",
                "compatibilityGateRequired", "revocationTrustFuture", "quotaCleanupRequired",
                "removeFilesMetadataCachesSecretsLogs"):
        require_bool(rollback, key, True, "rollbackRemovalUpdate")

    api_notes = value.get("harmonyosApiNotes")
    require(isinstance(api_notes, dict), "harmonyosApiNotes object is required")
    for key in ("specificApisToBeConfirmed", "doNotAssumeBroadFilePermissions",
                "pickerUriCopyToSandboxToBeConfirmed", "atomicPromoteToBeConfirmed",
                "zipEnumerationToBeConfirmed"):
        require_bool(api_notes, key, True, "harmonyosApiNotes")

    stops = value.get("stopConditions")
    require(isinstance(stops, list), "stopConditions must be a list")
    require(set(stops) >= REQUIRED_STOP_CONDITIONS, "stopConditions missing required blocker")

    test_plan = value.get("testPlan")
    require(isinstance(test_plan, dict), "testPlan object is required")
    require_bool(test_plan, "mapsExistingCliValidators", True, "testPlan")
    require_bool(test_plan, "futureAppSideSmokeOnly", True, "testPlan")
    require_bool(test_plan, "deviceImplementationRequiredNow", False, "testPlan")
    require(isinstance(test_plan.get("unimplemented"), list) and test_plan["unimplemented"],
            "testPlan.unimplemented must list remaining implementation work")


def validate_plan(value: dict[str, Any]) -> None:
    require(value.get("planVersion") == 1, "planVersion must be 1")
    validate_no_leaks_or_executable_shape(value)
    validate_scope(value)
    validate_input_and_storage(value)
    validate_order(value)
    validate_runtime(value)
    validate_diagnostics_and_future(value)


def collect_json_files(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def validate_invalid_file(path: Path, base: dict[str, Any]) -> list[dict[str, Any]]:
    fixture = read_json(path)
    raw_cases = fixture.get("cases", [fixture])
    require(isinstance(raw_cases, list), "invalid fixture cases must be a list")
    results = []
    for case in raw_cases:
        require(isinstance(case, dict), "invalid fixture case must be an object")
        name = case.get("case")
        expect = case.get("expectRejectContains")
        require(isinstance(name, str) and name, "case must be a non-empty string")
        require(isinstance(expect, str) and expect, "expectRejectContains must be a non-empty string")
        candidate = case.get("input")
        if candidate is None:
            candidate = mutated(base, case)
        require(isinstance(candidate, dict), "invalid fixture input must be an object")
        try:
            validate_plan(candidate)
        except Exception as err:
            reason = str(err)
            require(expect.lower() in reason.lower(),
                    f"rejection reason did not contain expected text: {expect}")
            results.append({"file": str(path), "case": name, "expected": "reject", "status": "PASS", "reason": reason})
            continue
        results.append({"file": str(path), "case": name, "expected": "reject", "status": "FAIL",
                        "reason": "invalid fixture was accepted"})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate design-only HarmonyOS internal-dev ingestion plan fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--plan", default="tools/wasm-runtime-spike/source-package/harmonyos-ingestion-plan.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/harmonyos-ingestion-plan-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    plan_path = Path(args.plan).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "harmonyos-ingestion-plan-report.json"
    report: dict[str, Any] = {
        "status": "FAIL",
        "plan": str(plan_path),
        "fixtureDir": str(fixture_dir),
        "artifactDir": str(artifact_dir),
        "validCases": 0,
        "invalidCases": 0,
        "cases": [],
        "evidence": [],
    }

    try:
        base = read_json(plan_path)
        validate_plan(base)
        report["cases"].append({"file": str(plan_path), "expected": "accept", "status": "PASS"})

        for path in collect_json_files(fixture_dir / "valid"):
            try:
                validate_plan(read_json(path))
                case = {"file": str(path), "expected": "accept", "status": "PASS"}
                report["validCases"] += 1
            except Exception as err:
                case = {"file": str(path), "expected": "accept", "status": "FAIL", "reason": str(err)}
            report["cases"].append(case)

        for path in collect_json_files(fixture_dir / "invalid"):
            for case in validate_invalid_file(path, base):
                if case["status"] == "PASS":
                    report["invalidCases"] += 1
                report["cases"].append(case)

        failing = [case for case in report["cases"] if case["status"] != "PASS"]
        require(not failing, f"{len(failing)} HarmonyOS ingestion plan case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid HarmonyOS ingestion plan fixture(s) accepted",
            f"{report['invalidCases']} invalid HarmonyOS ingestion plan fixture(s) rejected",
            "designOnly=true and productRuntime=false enforced",
            "local-only input, app-private staging copy, validation order, network=false, and closed imports enforced",
            "source market, public index, remote install, built-in sources, direct picker execution, raw diagnostics, and product runtime drift rejected",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
