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
PACKAGE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:[.][a-z0-9][a-z0-9-]*){2,}$")
SEMVER_RE = re.compile(r"^(0|[1-9][0-9]*)[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)(?:[-+][0-9A-Za-z.-]+)?$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
IDENTIFIER_RE = re.compile(r"^(signer|key|prov):[A-Za-z0-9._:-]+$")
STRICT_UTC_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
REASON_CODE_RE = re.compile(r"^[A-Z0-9_]+$")
FORBIDDEN_KEY_RE = re.compile(
    r"(raw.?path|full.?path|cache.?path|local.?path|user.?path|credential|password|"
    r"secret|token|cookie|authorization|auth.?header|trust.?store|raw.?package|"
    r"archive.?bytes|wasm.?bytes|payload.?bytes|raw.?payload|private.?key|raw.?key|"
    r"signature.?dump|delete.?path|install.?path)",
    re.IGNORECASE,
)
FORBIDDEN_VALUE_RE = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|"
    r"Cookie\s*:|Set-Cookie\s*:|https?://|ftp://|file://|content://|ohos://|"
    r"(^|[\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|[A-Za-z]:\\|"
    r"\.hermes-artifacts|/cache/|/files/|/Documents/|"
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
        if isinstance(current, list) and part.isdigit():
            index = int(part)
            require(0 <= index < len(current), f"mutation path missing: {path}")
            current = current[index]
        else:
            require(isinstance(current, dict) and part in current, f"mutation path missing: {path}")
            current = current[part]
    last = parts[-1]
    if isinstance(current, list) and last.isdigit():
        index = int(last)
        require(0 <= index < len(current), f"mutation path missing: {path}")
        current[index] = replacement
    else:
        require(isinstance(current, dict), f"mutation parent is not an object: {path}")
        current[last] = replacement


def remove_path(value: dict[str, Any], path: str) -> None:
    parts = path.split(".")
    current: Any = value
    for part in parts[:-1]:
        if isinstance(current, list) and part.isdigit():
            index = int(part)
            require(0 <= index < len(current), f"mutation path missing: {path}")
            current = current[index]
        else:
            require(isinstance(current, dict) and part in current, f"mutation path missing: {path}")
            current = current[part]
    last = parts[-1]
    if isinstance(current, list) and last.isdigit():
        index = int(last)
        require(0 <= index < len(current), f"mutation path missing: {path}")
        current.pop(index)
    else:
        require(isinstance(current, dict), f"mutation parent is not an object: {path}")
        current.pop(last, None)


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


def parse_time(value: Any, path: str) -> datetime:
    require(isinstance(value, str) and STRICT_UTC_RE.fullmatch(value), f"{path} must be strict UTC timestamp")
    return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def require_active_window(value: dict[str, Any], now: datetime, path: str) -> None:
    start = parse_time(value.get("createdAt"), f"{path}.createdAt")
    end = parse_time(value.get("expiresAt"), f"{path}.expiresAt")
    require(start <= end, f"{path} freshness window order invalid")
    require(now >= start, f"{path} not yet valid")
    require(now <= end, f"{path} expired")


def semver_tuple(value: Any, path: str) -> tuple[int, int, int]:
    require(isinstance(value, str) and SEMVER_RE.fullmatch(value), f"{path} version ordering ambiguous or malformed")
    core = value.split("-", 1)[0].split("+", 1)[0]
    major, minor, patch = core.split(".")
    return int(major), int(minor), int(patch)


def semver_in_range(value: str, minimum: str, maximum: str) -> bool:
    return semver_tuple(minimum, "compatibility.app.minVersion") <= semver_tuple(value, "appVersion") <= semver_tuple(maximum, "compatibility.app.maxVersion")


def normalize_package_id(value: Any, path: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{path} package id required")
    normalized = value.strip().lower().replace("_", "-")
    normalized = re.sub(r"-+", "-", normalized)
    normalized = re.sub(r"[.]+", ".", normalized)
    require(PACKAGE_ID_RE.fullmatch(normalized), f"{path} package id canonicalization missing or ambiguous")
    return normalized


def require_canonical_id(value: Any, path: str) -> str:
    normalized = normalize_package_id(value, path)
    require(value == normalized, f"{path} package id canonicalization missing or ambiguous")
    return normalized


def require_sha256(value: Any, path: str) -> str:
    require(isinstance(value, str) and SHA256_RE.fullmatch(value), f"{path} digest must be lowercase sha256")
    return value


def require_identifier(value: Any, path: str, prefix: str | None = None) -> str:
    require(isinstance(value, str) and IDENTIFIER_RE.fullmatch(value), f"{path} must be a public identifier")
    if prefix:
        require(value.startswith(prefix), f"{path} must start with {prefix}")
    return value


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
    require(value.get("policyVersion") == SUPPORTED_POLICY_VERSION, "unknown lifecycle policy version")
    require(value.get("status") == "design-tooling-only", "status must be design-tooling-only")
    for key in ("designOnly", "fixtureOnly"):
        require_bool(value, key, True, "$")
    for key in ("networkIo", "subprocesses", "executesWasm", "implementsInstallStateMutation",
                "implementsDeletion", "implementsRollback", "implementsRegistry", "implementsSigning",
                "implementsCryptoVerification", "implementsTrustStore", "implementsRevocationStore",
                "productRuntime", "productUi"):
        require_bool(value, key, False, "$")

    scope = value.get("scope")
    require(isinstance(scope, dict), "scope object is required")
    for key in ("sourceMarket", "publicIndex", "remoteInstall", "builtInSources", "network", "webViewJsDsl"):
        require_bool(scope, key, False, "scope")

    drift = value.get("validatorDrift")
    require(isinstance(drift, dict), "validatorDrift object is required")
    for key in ("network", "subprocess", "executableHook", "installMutation", "deletionMutation", "registryMutation"):
        require_bool(drift, key, False, "validatorDrift")

    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require_bool(runtime, "network", False, "currentRuntime")
    require(runtime.get("hostImports") == ALLOWED_IMPORTS, "HTTP host import drift")
    require(HTTP_IMPORT not in runtime.get("hostImports", []), "HTTP host import drift")
    require_bool(runtime, "httpHostImport", False, "currentRuntime")


def validate_normalization_policy(value: dict[str, Any]) -> None:
    policy = value.get("identityNormalization")
    require(isinstance(policy, dict), "identityNormalization object is required")
    require(policy.get("algorithm") == "trim-lowercase-dot-segments-hyphen-only-v1",
            "package id canonicalization missing or ambiguous")
    require_bool(policy, "explicitCanonicalPackageIds", True, "identityNormalization")
    require_bool(policy, "rejectAmbiguousCanonicalization", True, "identityNormalization")
    require(policy.get("allowedPattern") == PACKAGE_ID_RE.pattern,
            "package id canonicalization missing or ambiguous")


def artifact_key(package: dict[str, Any]) -> tuple[str, str]:
    return package["packageId"], package["packageVersion"]


def digest_tuple(package: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        package["archiveSha256"],
        package["manifestSha256"],
        package["wasmSha256"],
        package["payloadSha256"],
    )


def validate_package(package: Any, path: str, require_canonical: bool = True) -> dict[str, Any]:
    require(isinstance(package, dict), f"{path} object is required")
    package_id = require_canonical_id(package.get("packageId"), f"{path}.packageId") if require_canonical else normalize_package_id(package.get("packageId"), f"{path}.packageId")
    normalized = package.get("normalizedPackageId")
    require(isinstance(normalized, str) and normalized == normalize_package_id(package.get("packageId"), f"{path}.packageId"),
            f"{path}.normalizedPackageId package id canonicalization missing or ambiguous")
    require(package_id == normalized or not require_canonical, f"{path}.packageId normalized collision")
    package["packageId"] = package.get("packageId")
    package["normalizedPackageId"] = normalized
    require(SEMVER_RE.fullmatch(str(package.get("packageVersion", ""))), f"{path}.packageVersion version ordering ambiguous or malformed")
    require(package.get("packageSchemaVersion") == PACKAGE_SCHEMA_VERSION, f"{path}.packageSchemaVersion incompatible")
    require(package.get("sourceAbi") == SOURCE_ABI, f"{path}.sourceAbi incompatible")
    require(package.get("hostAbi") == HOST_ABI, f"{path}.hostAbi incompatible")
    require_identifier(package.get("signerId"), f"{path}.signerId", "signer:")
    require_identifier(package.get("keyId"), f"{path}.keyId", "key:")
    require_identifier(package.get("provenanceId"), f"{path}.provenanceId", "prov:")
    for key in ("archiveSha256", "manifestSha256", "wasmSha256", "payloadSha256"):
        require_sha256(package.get(key), f"{path}.{key}")
    display = package.get("display")
    require(isinstance(display, dict), f"{path}.display object is required")
    require(isinstance(display.get("name"), str) and display["name"], f"{path}.display.name required")
    require(isinstance(display.get("author"), str) and display["author"], f"{path}.display.author required")
    require_active_window(package, validate_time_policy.CURRENT, path)  # type: ignore[attr-defined]
    return package


def validate_time_policy(value: dict[str, Any]) -> datetime:
    time_policy = value.get("timePolicy")
    require(isinstance(time_policy, dict), "timePolicy object is required")
    require(time_policy.get("clockSource") == "fixture-evaluationTime", "timePolicy.clockSource invalid")
    now = parse_time(time_policy.get("evaluationTime"), "timePolicy.evaluationTime")
    require_bool(time_policy, "rejectAmbiguousTimestamp", True, "timePolicy")
    require_bool(time_policy, "rejectExpired", True, "timePolicy")
    return now


def validate_installed(value: dict[str, Any]) -> dict[tuple[str, str], dict[str, Any]]:
    installed = value.get("installedArtifacts")
    require(isinstance(installed, list) and installed, "installedArtifacts required")
    index: dict[tuple[str, str], dict[str, Any]] = {}
    normalized_ids: dict[str, str] = {}
    for idx, raw in enumerate(installed):
        package = validate_package(raw, f"installedArtifacts[{idx}]")
        require(package.get("accepted") is True, f"installedArtifacts[{idx}] must be previously accepted")
        key = artifact_key(package)
        require(key not in index, f"installedArtifacts[{idx}] duplicate id/version")
        if package["normalizedPackageId"] in normalized_ids:
            require(normalized_ids[package["normalizedPackageId"]] == package["packageId"], "duplicate normalized id collision")
        normalized_ids[package["normalizedPackageId"]] = package["packageId"]
        index[key] = package
    return index


def validate_decision(case: dict[str, Any], expected: str, path: str) -> None:
    decision = case.get("decision")
    require(isinstance(decision, dict), f"{path}.decision object is required")
    require(decision.get("outcome") == expected, f"{path} must {expected}")
    require(isinstance(decision.get("reasonCode"), str) and REASON_CODE_RE.fullmatch(decision["reasonCode"]),
            f"{path}.decision.reasonCode invalid")
    require(decision.get("minimalFieldNamesOnly") is True, f"{path}.decision must use minimal field names")


def require_same_identity(base: dict[str, Any], candidate: dict[str, Any], path: str) -> None:
    for key in ("display", "signerId", "keyId", "provenanceId"):
        require(candidate.get(key) == base.get(key), f"{path} signer/key/provenance drift accepted")


def validate_duplicate_cases(cases: dict[str, Any], installed: dict[tuple[str, str], dict[str, Any]]) -> None:
    policy = cases.get("duplicatePolicy")
    require(isinstance(policy, dict), "lifecycleCases.duplicatePolicy object is required")
    require_bool(policy, "exactDuplicateNoopRequiresExplicitPolicy", True, "lifecycleCases.duplicatePolicy")
    require_bool(policy, "sameVersionDigestMismatchRejects", True, "lifecycleCases.duplicatePolicy")
    require_bool(policy, "sameVersionSignerKeyProvenanceDriftRejects", True, "lifecycleCases.duplicatePolicy")
    require_bool(policy, "normalizedCollisionRejects", True, "lifecycleCases.duplicatePolicy")

    exact = cases.get("exactDuplicate")
    require(isinstance(exact, dict), "lifecycleCases.exactDuplicate object is required")
    package = validate_package(exact.get("candidate"), "lifecycleCases.exactDuplicate.candidate")
    base = installed.get(artifact_key(package))
    require(base is not None, "exact duplicate package missing installed base")
    require(digest_tuple(package) == digest_tuple(base), "exact duplicate digest mismatch")
    require_same_identity(base, package, "exact duplicate")
    require(exact.get("explicitIdempotentPolicy") is True, "exact duplicate accepted without explicit idempotent policy")
    validate_decision(exact, "noop", "lifecycleCases.exactDuplicate")

    collision = cases.get("normalizedCollision")
    require(isinstance(collision, dict), "lifecycleCases.normalizedCollision object is required")
    colliding = validate_package(collision.get("candidate"), "lifecycleCases.normalizedCollision.candidate", require_canonical=False)
    require(colliding["packageId"] != colliding["normalizedPackageId"], "normalized collision fixture must use non-canonical id")
    require(any(item["normalizedPackageId"] == colliding["normalizedPackageId"] for item in installed.values()),
            "normalized collision fixture must collide with installed artifact")
    validate_decision(collision, "reject", "lifecycleCases.normalizedCollision")

    digest_mismatch = cases.get("duplicateVersionDigestMismatch")
    require(isinstance(digest_mismatch, dict), "lifecycleCases.duplicateVersionDigestMismatch object is required")
    package = validate_package(digest_mismatch.get("candidate"), "lifecycleCases.duplicateVersionDigestMismatch.candidate")
    base = installed.get(artifact_key(package))
    require(base is not None, "duplicate version missing installed base")
    require(digest_tuple(package) != digest_tuple(base), "duplicate id/version with digest mismatch not represented")
    validate_decision(digest_mismatch, "reject", "lifecycleCases.duplicateVersionDigestMismatch")

    drift = cases.get("duplicateVersionIdentityDrift")
    require(isinstance(drift, dict), "lifecycleCases.duplicateVersionIdentityDrift object is required")
    package = validate_package(drift.get("candidate"), "lifecycleCases.duplicateVersionIdentityDrift.candidate")
    base = installed.get(artifact_key(package))
    require(base is not None, "duplicate version identity drift missing installed base")
    require(
        package.get("signerId") != base.get("signerId")
        or package.get("keyId") != base.get("keyId")
        or package.get("provenanceId") != base.get("provenanceId")
        or package.get("display") != base.get("display"),
        "duplicate id/version signer/key/provenance drift accepted",
    )
    validate_decision(drift, "reject", "lifecycleCases.duplicateVersionIdentityDrift")


def validate_gates(value: dict[str, Any], path: str) -> None:
    gates = value.get("gates")
    require(isinstance(gates, dict), f"{path}.gates object is required")
    for key in ("digest", "abi", "imports", "network", "trust", "compatibility"):
        require_bool(gates, key, True, f"{path}.gates")


def validate_update_case(cases: dict[str, Any], installed: dict[tuple[str, str], dict[str, Any]]) -> None:
    update = cases.get("update")
    require(isinstance(update, dict), "lifecycleCases.update object is required")
    policy = update.get("policy")
    require(isinstance(policy, dict), "lifecycleCases.update.policy object is required")
    require(policy.get("versionOrdering") == "semver-core-ascending", "version ordering ambiguous or malformed")
    require_bool(policy, "packageIdMustRemainStable", True, "lifecycleCases.update.policy")
    require_bool(policy, "signerKeyTrustAuthorityContinuityRequired", True, "lifecycleCases.update.policy")
    from_artifact = installed.get((update.get("fromPackageId"), update.get("fromVersion")))
    require(from_artifact is not None, "update from artifact unknown")
    candidate = validate_package(update.get("candidate"), "lifecycleCases.update.candidate")
    require(candidate["packageId"] == from_artifact["packageId"], "package id changed across update")
    require(semver_tuple(candidate["packageVersion"], "lifecycleCases.update.candidate.packageVersion") > semver_tuple(from_artifact["packageVersion"], "lifecycleCases.update.fromVersion"),
            "version ordering ambiguous or malformed")
    require(candidate["signerId"] == from_artifact["signerId"], "update signer/key/trust authority continuity mismatch")
    require(candidate["keyId"] == from_artifact["keyId"], "update signer/key/trust authority continuity mismatch")
    validate_gates(update, "lifecycleCases.update")
    validate_decision(update, "accept", "lifecycleCases.update")


def validate_downgrade_cases(cases: dict[str, Any], installed: dict[tuple[str, str], dict[str, Any]]) -> None:
    policy = cases.get("downgradePolicy")
    require(isinstance(policy, dict), "lifecycleCases.downgradePolicy object is required")
    require_bool(policy, "rejectByDefault", True, "lifecycleCases.downgradePolicy")
    require_bool(policy, "requiresExplicitTrustAuthorityApproval", True, "lifecycleCases.downgradePolicy")

    unapproved = cases.get("downgradeWithoutApproval")
    require(isinstance(unapproved, dict), "lifecycleCases.downgradeWithoutApproval object is required")
    validate_decision(unapproved, "reject", "lifecycleCases.downgradeWithoutApproval")

    approved = cases.get("approvedDowngrade")
    require(isinstance(approved, dict), "lifecycleCases.approvedDowngrade object is required")
    current = installed.get((approved.get("fromPackageId"), approved.get("fromVersion")))
    require(current is not None, "downgrade from artifact unknown")
    candidate = validate_package(approved.get("candidate"), "lifecycleCases.approvedDowngrade.candidate")
    require(candidate["packageId"] == current["packageId"], "downgrade approval package mismatch")
    require(semver_tuple(candidate["packageVersion"], "lifecycleCases.approvedDowngrade.candidate.packageVersion") < semver_tuple(current["packageVersion"], "lifecycleCases.approvedDowngrade.fromVersion"),
            "downgrade accepted without explicit approval")
    approval = approved.get("approval")
    require(isinstance(approval, dict), "downgrade accepted without explicit approval")
    require(approval.get("explicit") is True, "downgrade accepted without explicit approval")
    require_active_window(approval, validate_time_policy.CURRENT, "lifecycleCases.approvedDowngrade.approval")  # type: ignore[attr-defined]
    require(approval.get("packageId") == current["packageId"], "downgrade approval package mismatch")
    require(approval.get("fromVersion") == current["packageVersion"], "downgrade approval from mismatch")
    require(approval.get("toVersion") == candidate["packageVersion"], "downgrade approval to mismatch")
    require(approval.get("signerId") == candidate["signerId"] == current["signerId"], "downgrade approval signer/key mismatch")
    require(approval.get("keyId") == candidate["keyId"] == current["keyId"], "downgrade approval signer/key mismatch")
    require(approval.get("fromArchiveSha256") == current["archiveSha256"], "downgrade approval digest mismatch")
    require(approval.get("toArchiveSha256") == candidate["archiveSha256"], "downgrade approval digest mismatch")
    validate_gates(approved, "lifecycleCases.approvedDowngrade")
    validate_decision(approved, "accept", "lifecycleCases.approvedDowngrade")


def validate_revocation(value: dict[str, Any], package: dict[str, Any], path: str) -> None:
    revocation = value.get("revocationInputs")
    require(isinstance(revocation, dict), "revocationInputs object is required")
    require_bool(revocation, "staticFixtureOnly", True, "revocationInputs")
    require_bool(revocation, "networkFetch", False, "revocationInputs")
    require(package["signerId"] not in revocation.get("revokedSignerIds", []), f"{path} rollback to revoked package/key/signer/digest")
    require(package["keyId"] not in revocation.get("revokedKeyIds", []), f"{path} rollback to revoked package/key/signer/digest")
    require(not any(item.get("packageId") == package["packageId"] and item.get("packageVersion") == package["packageVersion"]
                    for item in revocation.get("revokedPackageVersions", [])), f"{path} rollback to revoked package/key/signer/digest")
    revoked_digests = set(revocation.get("revokedDigests", []))
    require(not (revoked_digests & set(digest_tuple(package))), f"{path} rollback to revoked package/key/signer/digest")


def validate_compatibility(package: dict[str, Any], compat: dict[str, Any], path: str) -> None:
    require(isinstance(compat, dict), f"{path}.compatibility object is required")
    require(compat.get("policyVersion") == SUPPORTED_POLICY_VERSION, f"{path} rollback incompatible ABI/app/host policy")
    require(compat.get("packageSchemaVersion") == package["packageSchemaVersion"], f"{path} rollback incompatible ABI/app/host policy")
    require(compat.get("sourceAbi") == package["sourceAbi"], f"{path} rollback incompatible ABI/app/host policy")
    require(compat.get("hostAbi") == package["hostAbi"], f"{path} rollback incompatible ABI/app/host policy")
    app = compat.get("app")
    require(isinstance(app, dict) and semver_in_range(APP_VERSION, app.get("minVersion"), app.get("maxVersion")),
            f"{path} rollback incompatible ABI/app/host policy")


def validate_rollback_case(value: dict[str, Any], cases: dict[str, Any], installed: dict[tuple[str, str], dict[str, Any]]) -> None:
    rollback = cases.get("rollback")
    require(isinstance(rollback, dict), "lifecycleCases.rollback object is required")
    policy = rollback.get("policy")
    require(isinstance(policy, dict), "lifecycleCases.rollback.policy object is required")
    for key in ("requiresPreviouslyAcceptedArtifact", "mustStillBeTrusted", "mustStillBeCompatible",
                "mustNotBypassTrustAbiImportNetworkCompatibilityGates"):
        require_bool(policy, key, True, "lifecycleCases.rollback.policy")
    candidate = validate_package(rollback.get("target"), "lifecycleCases.rollback.target")
    require(artifact_key(candidate) in installed and installed[artifact_key(candidate)]["archiveSha256"] == candidate["archiveSha256"],
            "rollback to unknown/not-previously-accepted artifact")
    validate_revocation(value, candidate, "lifecycleCases.rollback")
    validate_compatibility(candidate, rollback.get("compatibility"), "lifecycleCases.rollback")
    validate_gates(rollback, "lifecycleCases.rollback")
    validate_decision(rollback, "accept", "lifecycleCases.rollback")


def validate_removal_case(cases: dict[str, Any]) -> None:
    removal = cases.get("removalPlan")
    require(isinstance(removal, dict), "lifecycleCases.removalPlan object is required")
    require_bool(removal, "designOnly", True, "lifecycleCases.removalPlan")
    require_bool(removal, "atomic", True, "lifecycleCases.removalPlan")
    require_bool(removal, "idempotent", True, "lifecycleCases.removalPlan")
    require_bool(removal, "leavesRuntimeEligibleStaleHandles", False, "lifecycleCases.removalPlan")
    require_bool(removal, "dumpsCredentials", False, "lifecycleCases.removalPlan")
    require_bool(removal, "dumpsTrustData", False, "lifecycleCases.removalPlan")
    require_bool(removal, "dumpsRawPackageBytes", False, "lifecycleCases.removalPlan")
    categories = removal.get("cleanupCategories")
    require(isinstance(categories, list), "lifecycleCases.removalPlan.cleanupCategories required")
    required = {
        "app-private-package-files",
        "package-metadata",
        "derived-caches",
        "active-sessions",
        "source-settings",
        "credential-references",
        "diagnostic-reports",
        "runtime-handles",
    }
    require(required <= set(categories), "removal plan omits required cleanup categories")
    allowed = required | {"temporary-staging-records"}
    for category in categories:
        require(category in allowed, "removal plan includes raw paths, credentials, trust data, raw package bytes, or runtime-eligible stale handle")


def validate_diagnostics(value: dict[str, Any]) -> None:
    diagnostics = value.get("diagnostics")
    require(isinstance(diagnostics, dict), "diagnostics object is required")
    require_bool(diagnostics, "redactedByDefault", True, "diagnostics")
    require_bool(diagnostics, "minimalFieldNamesOnly", True, "diagnostics")
    for key in ("includeRawPaths", "includeCachePaths", "includeCredentials", "includeHeaders",
                "includeCookies", "includeTrustStoreData", "includeRawPackageBytes",
                "includeRawPayloads", "includeCommandLines"):
        require_bool(diagnostics, key, False, "diagnostics")
    fields = diagnostics.get("reportFields")
    require(isinstance(fields, list) and fields, "diagnostics.reportFields must be listed")
    for field in fields:
        require(field in {"status", "case", "reasonCode", "field"}, "diagnostics.reportFields too broad")


def validate_non_goals(value: dict[str, Any]) -> None:
    non_goals = value.get("nonGoals")
    require(isinstance(non_goals, dict), "nonGoals object is required")
    for key in ("productInstallState", "productDeletion", "realRollback", "registryDatabase",
                "realSigning", "signatureVerification", "trustStore", "revocationStore",
                "network", "httpImport", "webViewJsDsl", "productRuntime", "productUi",
                "sourceMarket", "publicIndex", "remoteInstall", "builtInSources"):
        require_bool(non_goals, key, True, "nonGoals")


def validate_policy(value: Any) -> None:
    require(isinstance(value, dict), "json root must be an object")
    validate_no_forbidden_material(value)
    validate_scope(value)
    validate_normalization_policy(value)
    now = validate_time_policy(value)
    validate_time_policy.CURRENT = now  # type: ignore[attr-defined]
    installed = validate_installed(value)
    cases = value.get("lifecycleCases")
    require(isinstance(cases, dict), "lifecycleCases object is required")
    validate_duplicate_cases(cases, installed)
    validate_update_case(cases, installed)
    validate_downgrade_cases(cases, installed)
    validate_rollback_case(value, cases, installed)
    validate_removal_case(cases)
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
    parser = argparse.ArgumentParser(description="Validate static lifecycle update/downgrade/rollback/removal fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--policy", default="tools/wasm-runtime-spike/source-package/lifecycle-update-rollback.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/lifecycle-update-rollback-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    policy_path = Path(args.policy).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "lifecycle-update-rollback-report.json"
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
        require(not failing, f"{len(failing)} lifecycle update/rollback case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid lifecycle fixture(s) accepted",
            f"{report['invalidCases']} invalid lifecycle drift case(s) rejected",
            "duplicate id, normalized collision, duplicate version, update, downgrade, rollback, and removal decisions are static fixture metadata only",
            "validator performs local JSON checks only and keeps install state mutation, deletion, rollback execution, registry stores, network, subprocesses, WASM execution, signing, verification, product runtime, and product UI out of scope",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
