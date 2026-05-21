#!/usr/bin/env python3
import argparse
import copy
import json
import math
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redact_value, write_redacted_json  # noqa: E402


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
HTTP_IMPORT = "koma_host.http_request"
SUPPORTED_POLICY_VERSION = 1
PACKAGE_SCHEMA_VERSION = 1
SOURCE_ABI = "koma-source-abi-v0.1"
HOST_ABI = "koma-host-v0.1"
APP_VERSION = "0.1.0"
REAL_VERIFICATION_CLAIM_REJECTED = "REAL_VERIFICATION_CLAIM_REJECTED"
PACKAGE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*){2,}$")
PACKAGE_VERSION_RE = re.compile(r"^[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
IDENTIFIER_RE = re.compile(r"^(signer|key):[A-Za-z0-9._:-]+$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REASON_CODE_RE = re.compile(r"^[A-Z0-9_]+$")
STRICT_UTC_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
FORBIDDEN_KEY_RE = re.compile(
    r"(private.?key|raw.?key|credential|cookie|authorization|auth.?header|"
    r"request.?body|response.?body|archive.?bytes|wasm.?bytes|trust.?store|"
    r"certificate|cert.?pem|raw.?signature|signature.?dump|picker.?uri|"
    r"cache.?path|user.?path|local.?path|full.?path|secret|token|password|"
    r"payload.?dump|raw.?payload|generated.?cache)",
    re.IGNORECASE,
)
FORBIDDEN_VALUE_RE = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|"
    r"Cookie\s*:|Set-Cookie\s*:|https?://|ftp://|file://|content://|ohos://|"
    r"(^|[\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|"
    r"[A-Za-z]:\\|app-private|\.hermes-artifacts|/cache/|/files/|/Documents/|"
    r"\b(password|token|secret|api[_-]?key)\s*[=:]\s*[^\s,;}]+|"
    r"\bsignature\s*[=:]\s*[A-Za-z0-9+/=]{24,})",
    re.IGNORECASE,
)


class ValidationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def no_duplicates_object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError(f"duplicate key rejected: {key}")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValidationError(f"non-finite JSON number rejected: {value}")


def read_json_object(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as fh:
            value = json.load(fh, object_pairs_hook=no_duplicates_object_pairs, parse_constant=reject_constant)
    except json.JSONDecodeError as err:
        raise ValidationError(f"strict JSON parse failed: {err.msg}") from err
    require(isinstance(value, dict), "json root must be an object")
    return value


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


def require_bool(value: dict[str, Any], key: str, expected: bool, path: str) -> None:
    require(value.get(key) is expected, f"{path}.{key} must be {str(expected).lower()}")


def require_identifier(value: Any, path: str, prefix: str | None = None) -> str:
    require(isinstance(value, str) and IDENTIFIER_RE.fullmatch(value), f"{path} must be a public identifier")
    if prefix:
        require(value.startswith(prefix), f"{path} must start with {prefix}")
    return value


def require_sha256(value: Any, path: str) -> str:
    require(isinstance(value, str) and SHA256_RE.fullmatch(value), f"{path} must be lowercase sha256")
    return value


def parse_time(value: Any, path: str) -> datetime:
    require(isinstance(value, str) and STRICT_UTC_RE.fullmatch(value), f"{path} must be strict UTC timestamp")
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def require_active_window(value: dict[str, Any], now: datetime, path: str) -> None:
    start_key = "notBefore" if "notBefore" in value else "createdAt"
    end_key = "notAfter" if "notAfter" in value else "expiresAt"
    require(start_key in value and end_key in value, f"{path} freshness window required")
    start = parse_time(value[start_key], f"{path}.{start_key}")
    end = parse_time(value[end_key], f"{path}.{end_key}")
    require(start <= end, f"{path} freshness window order invalid")
    require(now >= start, f"{path} not yet valid")
    require(now <= end, f"{path} expired")


def semver_tuple(value: str) -> tuple[int, int, int]:
    core = value.split("-", 1)[0].split("+", 1)[0]
    parts = core.split(".")
    require(len(parts) == 3 and all(part.isdigit() for part in parts), "version must be semantic")
    return int(parts[0]), int(parts[1]), int(parts[2])


def semver_in_range(value: str, minimum: str, maximum: str) -> bool:
    current = semver_tuple(value)
    return semver_tuple(minimum) <= current <= semver_tuple(maximum)


def validate_no_forbidden_material(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, float):
            require(math.isfinite(item), f"{path} must not be non-finite")
        if isinstance(item, dict):
            for key, child in item.items():
                if not isinstance(child, bool):
                    require(not FORBIDDEN_KEY_RE.search(key), f"{path}.{key} forbidden diagnostic field")
        elif isinstance(item, str):
            require(not FORBIDDEN_VALUE_RE.search(item), f"{path} forbidden diagnostic value")


def validate_scope(value: dict[str, Any]) -> None:
    require(value.get("policyVersion") == SUPPORTED_POLICY_VERSION, "policyVersion unsupported")
    require(value.get("status") == "design-tooling-only", "status must be design-tooling-only")
    for key in ("designOnly", "fixtureOnly"):
        require_bool(value, key, True, "$")
    for key in ("implementsSigning", "implementsCryptoVerification", "implementsKeyGeneration",
                "implementsTrustStore", "implementsCertificates", "networkIo", "subprocesses",
                "executesWasm", "productRuntime", "productUi"):
        require_bool(value, key, False, "$")

    scope = value.get("scope")
    require(isinstance(scope, dict), "scope object is required")
    for key in ("sourceMarket", "publicIndex", "remoteInstall", "builtInSources", "network"):
        require_bool(scope, key, False, "scope")

    drift = value.get("validatorDrift")
    require(isinstance(drift, dict), "validatorDrift object is required")
    for key in ("network", "subprocess", "executableHook", "wasmExecution", "productRuntimeHook"):
        require_bool(drift, key, False, "validatorDrift")


def validate_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require_bool(runtime, "network", False, "currentRuntime")
    require(runtime.get("hostImports") == ALLOWED_IMPORTS,
            "currentRuntime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in runtime.get("hostImports", []),
            "currentRuntime.hostImports must not include http_request")
    require_bool(runtime, "httpHostImport", False, "currentRuntime")


def validate_identity(value: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    installed = value.get("installedPackagePolicy")
    candidate = value.get("candidatePackage")
    require(isinstance(installed, dict), "installedPackagePolicy object is required")
    require(isinstance(candidate, dict), "candidatePackage object is required")

    for path, package in (("installedPackagePolicy", installed), ("candidatePackage", candidate)):
        package_id = package.get("packageId")
        package_version = package.get("packageVersion")
        require(isinstance(package_id, str) and PACKAGE_ID_RE.fullmatch(package_id),
                f"{path}.packageId must be normalized")
        require(isinstance(package_version, str) and PACKAGE_VERSION_RE.fullmatch(package_version),
                f"{path}.packageVersion must be semantic")
        require_identifier(package.get("signerId"), f"{path}.signerId", "signer:")
        require_identifier(package.get("keyId"), f"{path}.keyId", "key:")
        require_sha256(package.get("archiveSha256"), f"{path}.archiveSha256")
        require_sha256(package.get("wasmSha256"), f"{path}.wasmSha256")
        display = package.get("display")
        require(isinstance(display, dict), f"{path}.display object is required")
        for key in ("name", "author"):
            require(isinstance(display.get(key), str) and display[key], f"{path}.display.{key} required")

    binding = value.get("identityBinding")
    require(isinstance(binding, dict), "identityBinding object is required")
    require_bool(binding, "displayTextIsTrustIdentity", False, "identityBinding")
    for key in ("packageIdStableAcrossUpdates", "signerIdRequired", "keyIdRequired",
                "signerAndKeyMustMatchInstalledPolicy"):
        require_bool(binding, key, True, "identityBinding")

    require(candidate["packageId"] == installed["packageId"], "package id changed across update")
    if candidate["signerId"] != installed["signerId"]:
        validate_rotation(value, installed, candidate, signer_change=True)
    elif candidate["keyId"] != installed["keyId"]:
        validate_rotation(value, installed, candidate, signer_change=False)
    return installed, candidate


def validate_rotation(value: dict[str, Any], installed: dict[str, Any], candidate: dict[str, Any],
                      signer_change: bool) -> None:
    rotation = value.get("rotationPolicy")
    require(isinstance(rotation, dict), "rotationPolicy object is required")
    require_bool(rotation, "requiredForKeyChange", True, "rotationPolicy")
    require_bool(rotation, "allowsSignerChange", False, "rotationPolicy")
    require_bool(rotation, "mustNotBypassPackageVersionCompatibilityDigestGates", True, "rotationPolicy")
    if signer_change:
        require(rotation.get("allowsSignerChange") is True, "unapproved signer change")

    approval = rotation.get("approved")
    require(isinstance(approval, dict), "rotationPolicy.approved object is required")
    require_bool(approval, "explicit", True, "rotationPolicy.approved")
    require(approval.get("packageId") == installed["packageId"], "cross-package rotation")
    require(approval.get("signerId") == installed["signerId"], "rotation signer scope mismatch")
    require(approval.get("fromKeyId") == installed["keyId"], "rotation from key mismatch")
    require(approval.get("toKeyId") == candidate["keyId"], "unapproved key rotation")


def validate_update_policy(value: dict[str, Any], installed: dict[str, Any], candidate: dict[str, Any]) -> None:
    update = value.get("updatePolicy")
    require(isinstance(update, dict), "updatePolicy object is required")
    require_bool(update, "packageIdMustRemainStable", True, "updatePolicy")
    require_bool(update, "downgradeRejectedByDefault", True, "updatePolicy")
    require_bool(update, "downgradeRequiresExplicitTrustAuthorityApproval", True, "updatePolicy")
    require_bool(update, "startupRuntimeHandoffBlockedWhenRevoked", True, "updatePolicy")
    if semver_tuple(candidate["packageVersion"]) < semver_tuple(installed["packageVersion"]):
        approval = update.get("downgradeApproval")
        require(isinstance(approval, dict) and approval.get("explicit") is True,
                "downgrade without explicit approval")
        require(approval.get("sameTrustAuthority") is True, "downgrade without explicit approval")


def validate_time_policy(value: dict[str, Any]) -> datetime:
    time_policy = value.get("timePolicy")
    require(isinstance(time_policy, dict), "timePolicy object is required")
    require(time_policy.get("clockSource") == "fixture-evaluationTime", "timePolicy.clockSource invalid")
    now = parse_time(time_policy.get("evaluationTime"), "timePolicy.evaluationTime")
    require_bool(time_policy, "rejectAmbiguousTimestamp", True, "timePolicy")
    require_bool(time_policy, "rejectExpired", True, "timePolicy")
    require_bool(time_policy, "rejectNotYetValid", True, "timePolicy")
    return now


def validate_freshness(value: dict[str, Any], now: datetime) -> None:
    for key in ("candidatePackage", "signatureMetadata"):
        item = value.get(key)
        require(isinstance(item, dict), f"{key} object is required")
        require_active_window(item, now, key)
    signature = value["signatureMetadata"]
    candidate = value["candidatePackage"]
    require(signature.get("realVerificationPerformed") is not True,
            f"{REAL_VERIFICATION_CLAIM_REJECTED}: signatureMetadata.realVerificationPerformed must be false or absent")
    require(signature.get("signerId") == candidate.get("signerId"), "signatureMetadata.signerId mismatch")
    require(signature.get("keyId") == candidate.get("keyId"), "signatureMetadata.keyId mismatch")
    rotation = value.get("rotationPolicy")
    require(isinstance(rotation, dict), "rotationPolicy object is required")
    approved = rotation.get("approved")
    require(isinstance(approved, dict), "rotationPolicy.approved object is required")
    require_active_window(approved, now, "rotationPolicy.approved")


def validate_revocation(value: dict[str, Any], candidate: dict[str, Any]) -> None:
    revocation = value.get("revocationInputs")
    require(isinstance(revocation, dict), "revocationInputs object is required")
    require_bool(revocation, "staticFixtureOnly", True, "revocationInputs")
    require_bool(revocation, "networkFetch", False, "revocationInputs")
    require(candidate["signerId"] not in revocation.get("revokedSignerIds", []), "signer revoked")
    require(candidate["keyId"] not in revocation.get("revokedKeyIds", []), "key id revoked")
    revoked_versions = revocation.get("revokedPackageVersions", [])
    require(isinstance(revoked_versions, list), "revocationInputs.revokedPackageVersions must be a list")
    for item in revoked_versions:
        require(isinstance(item, dict), "revoked package entry must be an object")
        require(not (item.get("packageId") == candidate["packageId"]
                     and item.get("packageVersion") == candidate["packageVersion"]),
                "package id/version revoked")
    digests = set(revocation.get("revokedDigests", []))
    require(candidate["archiveSha256"] not in digests and candidate["wasmSha256"] not in digests,
            "digest revoked")


def validate_compatibility(value: dict[str, Any], candidate: dict[str, Any]) -> None:
    compat = value.get("compatibility")
    require(isinstance(compat, dict), "compatibility object is required")
    require(compat.get("policyVersion") == SUPPORTED_POLICY_VERSION, "compatibility.policyVersion unsupported")
    require(compat.get("packageSchemaVersion") == PACKAGE_SCHEMA_VERSION,
            "compatibility.packageSchemaVersion incompatible")
    require(compat.get("sourceAbi") == SOURCE_ABI, "compatibility.sourceAbi incompatible")
    require(compat.get("hostAbi") == HOST_ABI, "compatibility.hostAbi incompatible")
    app = compat.get("app")
    require(isinstance(app, dict), "compatibility.app object is required")
    require(semver_in_range(APP_VERSION, app.get("minVersion"), app.get("maxVersion")),
            "compatibility.app incompatible")

    gates = compat.get("checkedBeforeRuntimeEligibility")
    require(isinstance(gates, list), "compatibility.checkedBeforeRuntimeEligibility must be a list")
    for gate in ("packageSchema", "sourceAbi", "hostAbi", "appVersion"):
        require(gate in gates, f"compatibility gate missing {gate}")

    require(candidate.get("packageSchemaVersion") == compat["packageSchemaVersion"],
            "compatibility.packageSchemaVersion incompatible")
    require(candidate.get("sourceAbi") == compat["sourceAbi"], "compatibility.sourceAbi incompatible")
    require(candidate.get("hostAbi") == compat["hostAbi"], "compatibility.hostAbi incompatible")


def validate_diagnostics(value: dict[str, Any]) -> None:
    diagnostics = value.get("diagnostics")
    require(isinstance(diagnostics, dict), "diagnostics object is required")
    require_bool(diagnostics, "redactedByDefault", True, "diagnostics")
    require_bool(diagnostics, "minimalFieldNamesOnly", True, "diagnostics")
    for key in ("includeRawKeys", "includeRawSignatures", "includeTrustStoreDump",
                "includeCredentials", "includeCookies", "includeAuthorizationHeaders",
                "includeFullUserPaths", "includePickerUris", "includeAppPrivatePaths",
                "includeRawPayloads", "includeFullManifests", "includeRequestBodies",
                "includeResponseBodies", "includeGeneratedCachePaths", "includeRawPackageBytes"):
        require_bool(diagnostics, key, False, "diagnostics")
    fields = diagnostics.get("reportFields")
    require(isinstance(fields, list) and fields, "diagnostics.reportFields must be listed")
    for field in fields:
        require(field in {"status", "case", "reasonCode", "field"}, "diagnostics.reportFields too broad")
    codes = diagnostics.get("reasonCodes")
    require(isinstance(codes, list) and codes, "diagnostics.reasonCodes must be listed")
    for code in codes:
        require(isinstance(code, str) and REASON_CODE_RE.fullmatch(code), "diagnostics.reasonCodes invalid")


def validate_non_goals(value: dict[str, Any]) -> None:
    non_goals = value.get("nonGoals")
    require(isinstance(non_goals, dict), "nonGoals object is required")
    for key in ("realSigning", "signatureVerification", "keyGeneration", "certificates",
                "trustStore", "revocationStore", "networkRevocationFetch", "productRuntime",
                "productUi", "sourceMarket", "publicIndex", "remoteInstall", "builtInSources",
                "httpImport", "webViewJsDsl"):
        require_bool(non_goals, key, True, "nonGoals")


def validate_policy(value: Any) -> None:
    require(isinstance(value, dict), "json root must be an object")
    validate_no_forbidden_material(value)
    validate_scope(value)
    validate_runtime(value)
    now = validate_time_policy(value)
    installed, candidate = validate_identity(value)
    validate_update_policy(value, installed, candidate)
    validate_freshness(value, now)
    validate_revocation(value, candidate)
    validate_compatibility(value, candidate)
    validate_diagnostics(value)
    validate_non_goals(value)


def collect_json_files(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def validate_invalid_file(path: Path, base: dict[str, Any]) -> list[dict[str, Any]]:
    fixture = read_json_object(path)
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
        try:
            validate_policy(candidate)
        except Exception as err:
            reason = str(err)
            require(expect.lower() in reason.lower(),
                    f"rejection reason did not contain expected text: {expect}")
            results.append({"file": str(path), "case": name, "expected": "reject", "status": "PASS",
                            "reasonCode": "EXPECTED_REJECT", "field": expect})
            continue
        results.append({"file": str(path), "case": name, "expected": "reject", "status": "FAIL",
                        "reasonCode": "INVALID_ACCEPTED", "field": expect})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate static signer rotation/revocation/freshness fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--policy", default="tools/wasm-runtime-spike/source-package/signer-rotation-revocation.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/signer-rotation-revocation-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    policy_path = Path(args.policy).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "signer-rotation-revocation-report.json"
    report: dict[str, Any] = {
        "status": "FAIL",
        "policy": str(policy_path),
        "fixtureDir": str(fixture_dir),
        "artifactDir": str(artifact_dir),
        "validCases": 0,
        "invalidCases": 0,
        "cases": [],
        "evidence": [],
    }

    try:
        base = read_json_object(policy_path)
        validate_policy(base)
        report["cases"].append({"file": str(policy_path), "expected": "accept", "status": "PASS"})

        for path in collect_json_files(fixture_dir / "valid"):
            try:
                validate_policy(read_json_object(path))
                case = {"file": str(path), "expected": "accept", "status": "PASS"}
                report["validCases"] += 1
            except Exception as err:
                case = {"file": str(path), "expected": "accept", "status": "FAIL",
                        "reasonCode": "VALID_REJECTED", "field": str(err)}
            report["cases"].append(case)

        for path in collect_json_files(fixture_dir / "invalid"):
            for case in validate_invalid_file(path, base):
                if case["status"] == "PASS":
                    report["invalidCases"] += 1
                report["cases"].append(case)

        failing = [case for case in report["cases"] if case["status"] != "PASS"]
        require(not failing, f"{len(failing)} signer rotation/revocation case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid signer rotation fixture(s) accepted",
            f"{report['invalidCases']} invalid signer rotation fixture(s) rejected",
            "identity, rotation, revocation, freshness, compatibility, runtime-closed, and diagnostics gates enforced from static fixture metadata",
            "validator performs local JSON checks only and keeps signing, verification, stores, network, subprocesses, WASM execution, product runtime, and product UI out of scope",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
