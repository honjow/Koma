#!/usr/bin/env python3
import argparse
import copy
import json
import re
import sys
from pathlib import Path
from typing import Any


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
HTTP_IMPORT = "koma_host.http_request"
REQUIRED_ORDER = [
    "archive_safety",
    "archive_digest_size",
    "manifest_parse_schema",
    "manifest_digest_size",
    "wasm_hash_size",
    "package_identity_version_provenance",
    "trust_signature_future_gate",
    "abi_import_network_policy",
    "atomic_promote_register",
]
REQUIRED_METADATA = {
    "signerId",
    "keyId",
    "signatureBlockPath",
    "createdAt",
    "expiresAt",
    "packageProvenance",
}
REQUIRED_NON_GOALS = {
    "sourceMarket",
    "publicIndex",
    "remoteInstall",
    "builtInSources",
    "realSigningImplementation",
    "productUi",
    "network",
}
SECRET_VALUE_KEYS = {"authorization", "cookie", "password", "privateKey", "rawKey", "secret", "signature", "token"}
RAW_SECRET_RE = re.compile(
    r"(Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|Cookie\s*:|Set-Cookie\s*:|"
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----|"
    r"\b(password|token|secret|api[_-]?key)\s*[=:]\s*[^\s,;}]+|"
    r"\bsignature\s*[=:]\s*[A-Za-z0-9+/=]{24,})",
    re.IGNORECASE,
)
RAW_PATH_OR_REMOTE_RE = re.compile(
    r"(https?://|ftp://|file://|content://|ohos://|app-private|"
    r"(^|[\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|"
    r"[A-Za-z]:\\|\.hermes-artifacts|/cache/|/files/|/Documents/)",
    re.IGNORECASE,
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PACKAGE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*){2,}$")
PACKAGE_VERSION_RE = re.compile(r"^[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?$")


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


def validate_no_leaks(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, str):
            require(not RAW_SECRET_RE.search(item), f"{path} leaks raw credential, key, or signature material")
            require(not RAW_PATH_OR_REMOTE_RE.search(item), f"{path} leaks raw path, URI, or remote URL")
        elif isinstance(item, dict):
            for key, child in item.items():
                if key in SECRET_VALUE_KEYS and isinstance(child, str):
                    raise ValidationError(f"{path}.{key} contains inline secret-like value")


def validate_scope(value: dict[str, Any]) -> None:
    require(value.get("boundaryVersion") == 1, "boundaryVersion must be 1")
    require(value.get("status") == "design-tooling-only", "status must be design-tooling-only")
    require_bool(value, "designOnly", True, "$")
    require_bool(value, "implementsSigning", False, "$")
    require_bool(value, "implementsTrustStore", False, "$")
    require_bool(value, "implementsCryptoVerification", False, "$")
    require_bool(value, "productRuntime", False, "$")
    require_bool(value, "productUi", False, "$")

    scope = value.get("scope")
    require(isinstance(scope, dict), "scope object is required")
    require_bool(scope, "localPackagesOnly", True, "scope")
    for key in ("sourceMarket", "publicIndex", "remoteInstall", "builtInSources", "deviceInstall", "network"):
        require_bool(scope, key, False, "scope")


def validate_trust_modes(value: dict[str, Any]) -> None:
    modes = value.get("trustModes")
    require(isinstance(modes, dict), "trustModes object is required")
    require(modes.get("selectedProductMode") == "undecided", "trustModes.selectedProductMode must stay undecided")

    unsigned = modes.get("unsignedLocalDevOnly")
    require(isinstance(unsigned, dict), "trustModes.unsignedLocalDevOnly object is required")
    require_bool(unsigned, "allowed", True, "trustModes.unsignedLocalDevOnly")
    require_bool(unsigned, "releaseAccepted", False, "trustModes.unsignedLocalDevOnly")
    require_bool(unsigned, "requiresExplicitDeveloperMode", True, "trustModes.unsignedLocalDevOnly")

    checksum = modes.get("checksumPinnedPrivatePackages")
    require(isinstance(checksum, dict), "trustModes.checksumPinnedPrivatePackages object is required")
    for key in ("plannedOption", "pinArchiveDigest", "pinWasmDigest"):
        require_bool(checksum, key, True, "trustModes.checksumPinnedPrivatePackages")

    signature = modes.get("signaturePinnedPrivateKeys")
    require(isinstance(signature, dict), "trustModes.signaturePinnedPrivateKeys object is required")
    require_bool(signature, "plannedOption", True, "trustModes.signaturePinnedPrivateKeys")
    require_bool(signature, "realVerificationImplemented", False, "trustModes.signaturePinnedPrivateKeys")
    require_bool(signature, "requiresSignerId", True, "trustModes.signaturePinnedPrivateKeys")
    require_bool(signature, "requiresKeyId", True, "trustModes.signaturePinnedPrivateKeys")

    enterprise = modes.get("enterprisePrivateTrustStore")
    require(isinstance(enterprise, dict), "trustModes.enterprisePrivateTrustStore object is required")
    require_bool(enterprise, "plannedOption", True, "trustModes.enterprisePrivateTrustStore")
    require_bool(enterprise, "publicCatalogRequired", False, "trustModes.enterprisePrivateTrustStore")
    require_bool(enterprise, "remoteRevocationRequired", False, "trustModes.enterprisePrivateTrustStore")


def validate_metadata(value: dict[str, Any]) -> None:
    metadata = value.get("futureMetadata")
    require(isinstance(metadata, dict), "futureMetadata object is required")
    manifest_fields = metadata.get("manifestFields")
    trust_fields = metadata.get("trustFields")
    provenance_kinds = metadata.get("provenanceKinds")
    require(isinstance(manifest_fields, list) and "runtime.wasm.sha256" in manifest_fields,
            "futureMetadata.manifestFields must include runtime.wasm.sha256")
    for required in ("package.id", "package.version"):
        require(required in manifest_fields, f"futureMetadata.manifestFields must include {required}")
    require(isinstance(trust_fields, list) and REQUIRED_METADATA <= set(trust_fields),
            "futureMetadata.trustFields missing required trust metadata")
    require(metadata.get("signatureBlockLocation") == "signatures/koma-source-signature.json",
            "futureMetadata.signatureBlockLocation must be package-local signature path")
    require(isinstance(provenance_kinds, list) and len(provenance_kinds) >= 4,
            "futureMetadata.provenanceKinds must list future trust options")


def validate_digest_size_gate(gate: Any, path: str) -> None:
    require(isinstance(gate, dict), f"{path} object is required")
    sha256 = gate.get("sha256")
    size_bytes = gate.get("sizeBytes")
    require(isinstance(sha256, str) and SHA256_RE.fullmatch(sha256),
            f"{path}.sha256 must be a 64-character lowercase hex sha256")
    require(isinstance(size_bytes, int) and size_bytes > 0,
            f"{path}.sizeBytes must be a positive integer")
    require_bool(gate, "requiredBeforeTrustDecision", True, path)


def validate_package_gate(gate: Any) -> None:
    require(isinstance(gate, dict), "provenanceGates.package object is required")
    package_id = gate.get("id")
    package_version = gate.get("version")
    require(isinstance(package_id, str) and PACKAGE_ID_RE.fullmatch(package_id),
            "provenanceGates.package.id must be a normalized dotted package id")
    require(isinstance(package_version, str) and PACKAGE_VERSION_RE.fullmatch(package_version),
            "provenanceGates.package.version must be a normalized semantic version")
    require_bool(gate, "requiredBeforeTrustDecision", True, "provenanceGates.package")


def validate_provenance_gates(value: dict[str, Any]) -> None:
    gates = value.get("provenanceGates")
    require(isinstance(gates, dict), "provenanceGates object is required")
    validate_digest_size_gate(gates.get("archive"), "provenanceGates.archive")
    validate_digest_size_gate(gates.get("manifest"), "provenanceGates.manifest")
    validate_package_gate(gates.get("package"))


def validate_order(value: dict[str, Any]) -> None:
    order = value.get("verificationOrder")
    require(isinstance(order, list) and all(isinstance(item, str) for item in order),
            "verificationOrder must be a list of strings")
    for gate in REQUIRED_ORDER:
        require(gate in order, f"verificationOrder missing {gate}")
    positions = {gate: order.index(gate) for gate in REQUIRED_ORDER}
    for earlier, later in zip(REQUIRED_ORDER, REQUIRED_ORDER[1:]):
        require(positions[earlier] < positions[later],
                f"verificationOrder must run {earlier} before {later}")


def validate_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require_bool(runtime, "network", False, "currentRuntime")
    imports = runtime.get("hostImports")
    require(imports == ALLOWED_IMPORTS, "currentRuntime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in imports, "currentRuntime.hostImports must not include http_request")
    require_bool(runtime, "httpHostImport", False, "currentRuntime")


def validate_failure_update_logging(value: dict[str, Any]) -> None:
    failure = value.get("failurePolicy")
    require(isinstance(failure, dict), "failurePolicy object is required")
    for key in ("failClosed", "rejectUnknownTrustMode", "rejectMissingTrustMetadataWhenRequired",
                "rejectOnVerificationError", "noRuntimeHandoffOnFailure", "cleanupStagingOnFailure"):
        require_bool(failure, key, True, "failurePolicy")

    update = value.get("updatePolicy")
    require(isinstance(update, dict), "updatePolicy object is required")
    require_bool(update, "duplicatePackageIdDecisionRequired", True, "updatePolicy")
    require_bool(update, "duplicateVersionSilentOverwrite", False, "updatePolicy")
    require_bool(update, "downgradeAllowedSilently", False, "updatePolicy")
    require_bool(update, "downgradeRequiresExplicitTrustDecision", True, "updatePolicy")
    require_bool(update, "revocationDecisionRequired", True, "updatePolicy")
    require_bool(update, "removalCleansFilesMetadataCachesSecretsLogs", True, "updatePolicy")
    require_bool(update, "rollbackRequiresStillTrustedCompatiblePackage", True, "updatePolicy")

    logging = value.get("logging")
    require(isinstance(logging, dict), "logging object is required")
    require_bool(logging, "redactedByDefault", True, "logging")
    require_bool(logging, "developerDiagnosticModeRequiredForExpandedDetails", True, "logging")
    for key in ("rawKeys", "rawSignatures", "fullUserPaths", "credentials", "cookies", "fullManifests", "largeResponses"):
        require_bool(logging, key, False, "logging")


def validate_mapping_and_non_goals(value: dict[str, Any]) -> None:
    mapping = value.get("mapping")
    require(isinstance(mapping, dict), "mapping object is required")
    existing = mapping.get("existingValidators")
    missing = mapping.get("missingFutureTrustTests")
    require(isinstance(existing, list) and "validate-source-package.py" in existing,
            "mapping.existingValidators must include current package validators")
    require(isinstance(missing, list) and len(missing) >= 6,
            "mapping.missingFutureTrustTests must list future trust gaps")

    non_goals = value.get("nonGoals")
    require(isinstance(non_goals, dict), "nonGoals object is required")
    require(REQUIRED_NON_GOALS <= set(non_goals), "nonGoals missing required explicit non-goals")
    for key in REQUIRED_NON_GOALS:
        require_bool(non_goals, key, True, "nonGoals")


def validate_policy(value: dict[str, Any]) -> None:
    validate_no_leaks(value)
    validate_scope(value)
    validate_trust_modes(value)
    validate_metadata(value)
    validate_provenance_gates(value)
    validate_order(value)
    validate_runtime(value)
    validate_failure_update_logging(value)
    validate_mapping_and_non_goals(value)


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
            validate_policy(candidate)
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
    parser = argparse.ArgumentParser(description="Validate design/tooling-only source package trust provenance boundary fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--policy", default="tools/wasm-runtime-spike/source-package/trust-provenance-boundary.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/trust-provenance-boundary-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    policy_path = Path(args.policy).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "trust-provenance-boundary-report.json"
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
        base = read_json(policy_path)
        validate_policy(base)
        report["cases"].append({"file": str(policy_path), "expected": "accept", "status": "PASS"})

        for path in collect_json_files(fixture_dir / "valid"):
            try:
                validate_policy(read_json(path))
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
        require(not failing, f"{len(failing)} trust/provenance boundary case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid trust/provenance fixture(s) accepted",
            f"{report['invalidCases']} invalid trust/provenance fixture(s) rejected",
            "designOnly=true, no signing/trust-store/crypto implementation, productRuntime=false, and productUi=false enforced",
            "archive digest/size, manifest digest/size, package id, and package version gates enforced before trust decisions",
            "unsigned release acceptance, order drift, provenance gate drift, network/http import drift, marketplace/remote/built-in source drift, downgrade/duplicate overwrite, logging leaks, and non-fail-closed policy rejected",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
