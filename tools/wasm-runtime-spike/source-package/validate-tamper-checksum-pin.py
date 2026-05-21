#!/usr/bin/env python3
import argparse
import copy
import hashlib
import json
import math
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redact_value, write_redacted_json  # noqa: E402


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
HTTP_IMPORT = "koma_host.http_request"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PACKAGE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*){2,}$")
PACKAGE_VERSION_RE = re.compile(r"^[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
PACKAGE_PATH_RE = re.compile(r"^[A-Za-z0-9._/-]+$")
IDENTIFIER_RE = re.compile(r"^(signer|key):[A-Za-z0-9._:-]+$")
REASON_CODE_RE = re.compile(r"^[A-Z0-9_]+$")
FORBIDDEN_KEY_RE = re.compile(
    r"(private.?key|raw.?key|credential|cookie|authorization|auth.?header|"
    r"request.?body|response.?body|archive.?bytes|wasm.?bytes|trust.?store|"
    r"certificate|cert.?pem|raw.?signature|signature.?dump|picker.?uri|"
    r"cache.?path|user.?path|local.?path|full.?path|secret|token|password)",
    re.IGNORECASE,
)
FORBIDDEN_VALUE_RE = re.compile(
    r"(-----BEGIN [A-Z ]*PRIVATE KEY-----|Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|"
    r"Cookie\s*:|Set-Cookie\s*:|https?://|ftp://|file://|content://|ohos://|"
    r"(^|[\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp)/|"
    r"[A-Za-z]:\\|app-private|\.hermes-artifacts|/cache/|/files/|/Documents/|"
    r"\b(password|token|secret|api[_-]?key)\s*[=:]\s*[^\s,;}]+)",
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


def read_json_value(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh, object_pairs_hook=no_duplicates_object_pairs, parse_constant=reject_constant)
    except json.JSONDecodeError as err:
        raise ValidationError(f"strict JSON parse failed: {err.msg}") from err


def read_json_object(path: Path) -> dict[str, Any]:
    value = read_json_value(path)
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


def canonical_bytes(value: Any) -> bytes:
    require(isinstance(value, dict), "canonical input must be a normalized JSON object")
    validate_json_model(value)
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode("utf-8")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def digest_prefix(value: str) -> str:
    return value[:12]


def mismatch(field: str, expected: Any, observed: Any) -> None:
    if isinstance(expected, str) and isinstance(observed, str) and SHA256_RE.fullmatch(expected) and SHA256_RE.fullmatch(observed):
        raise ValidationError(
            f"{field} mismatch expected={digest_prefix(expected)} observed={digest_prefix(observed)}"
        )
    raise ValidationError(f"{field} mismatch")


def validate_json_model(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, float):
            require(math.isfinite(item), f"{path} must not be NaN or Infinity")
            raise ValidationError(f"{path} floats are not allowed in canonical payload v1")
        if isinstance(item, str):
            require(item == unicodedata.normalize("NFC", item), f"{path} string must be NFC-normalized")
        if isinstance(item, dict):
            for key in item:
                require(key == unicodedata.normalize("NFC", key), f"{path} key must be NFC-normalized")


def validate_no_forbidden_material(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, dict):
            for key, child in item.items():
                if not isinstance(child, bool):
                    require(not FORBIDDEN_KEY_RE.search(key), f"{path}.{key} forbidden sensitive field")
        elif isinstance(item, str):
            require(not FORBIDDEN_VALUE_RE.search(item), f"{path} forbidden sensitive value")


def require_bool(value: dict[str, Any], key: str, expected: bool, path: str) -> None:
    require(value.get(key) is expected, f"{path}.{key} must be {str(expected).lower()}")


def require_sha_size(value: Any, path: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{path} object is required")
    require(isinstance(value.get("sha256"), str) and SHA256_RE.fullmatch(value["sha256"]),
            f"{path}.sha256 must be lowercase sha256")
    require(isinstance(value.get("sizeBytes"), int) and value["sizeBytes"] > 0,
            f"{path}.sizeBytes must be a positive integer")
    return value


def require_package_path(value: Any, path: str) -> str:
    require(isinstance(value, str) and value.endswith(".wasm") and PACKAGE_PATH_RE.fullmatch(value)
            and not value.startswith("/") and ".." not in value.split("/"),
            f"{path} must be a package-local wasm path")
    return value


def validate_scope(value: dict[str, Any]) -> None:
    require(value.get("boundaryVersion") == 1, "boundaryVersion must be 1")
    require(value.get("status") == "design-tooling-only", "status must be design-tooling-only")
    for key in ("designOnly", "fixtureOnly"):
        require_bool(value, key, True, "$")
    for key in ("implementsSigning", "implementsCryptoVerification", "implementsKeyGeneration",
                "implementsTrustStore", "executesWasm", "networkIo", "subprocesses",
                "productRuntime", "productUi"):
        require_bool(value, key, False, "$")

    scope = value.get("scope")
    require(isinstance(scope, dict), "scope object is required")
    for key in ("sourceMarket", "publicIndex", "remoteInstall", "builtInSources", "network"):
        require_bool(scope, key, False, "scope")

    drift = value.get("validatorDrift")
    require(isinstance(drift, dict), "validatorDrift object is required")
    for key in ("network", "subprocess", "executableHook", "wasmExecution", "productRuntimeHook"):
        require_bool(drift, key, False, "validatorDrift")


def validate_manifest_model(manifest: Any) -> bytes:
    require(isinstance(manifest, dict), "manifestModel must be a normalized JSON object")
    validate_json_model(manifest)
    package = manifest.get("package")
    runtime = manifest.get("runtime")
    content = manifest.get("contentPolicy")
    require(isinstance(package, dict), "manifestModel.package object is required")
    require(isinstance(package.get("id"), str) and PACKAGE_ID_RE.fullmatch(package["id"]),
            "manifestModel.package.id must be a normalized package id")
    require(isinstance(package.get("version"), str) and PACKAGE_VERSION_RE.fullmatch(package["version"]),
            "manifestModel.package.version must be a normalized package version")
    require(isinstance(runtime, dict), "manifestModel.runtime object is required")
    wasm = runtime.get("wasm")
    require_sha_size(wasm, "manifestModel.runtime.wasm")
    require_package_path(wasm.get("path"), "manifestModel.runtime.wasm.path")
    require_bool(runtime, "network", False, "manifestModel.runtime")
    require(runtime.get("hostImports") == ALLOWED_IMPORTS,
            "manifestModel.runtime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in runtime.get("hostImports", []),
            "manifestModel.runtime.hostImports must not include http_request")
    require(isinstance(content, dict), "manifestModel.contentPolicy object is required")
    for key in ("sourceMarket", "publicIndex", "remoteInstall", "builtInSources"):
        require_bool(content, key, False, "manifestModel.contentPolicy")
    return canonical_bytes(manifest)


def validate_observed(value: dict[str, Any], manifest_bytes: bytes) -> dict[str, Any]:
    observed = value.get("observedPackage")
    require(isinstance(observed, dict), "observedPackage object is required")
    archive = require_sha_size(observed.get("archive"), "observedPackage.archive")
    manifest = require_sha_size(observed.get("manifest"), "observedPackage.manifest")
    require(manifest.get("input") == "normalized-json-object",
            "observedPackage.manifest.input must be normalized-json-object")
    wasm = require_sha_size(observed.get("wasm"), "observedPackage.wasm")
    require_package_path(wasm.get("path"), "observedPackage.wasm.path")
    payload = observed.get("canonicalSignedPayload")
    require(isinstance(payload, dict), "observedPackage.canonicalSignedPayload object is required")
    require_bool(payload, "present", True, "observedPackage.canonicalSignedPayload")
    require_sha_size(payload, "observedPackage.canonicalSignedPayload")

    identity = observed.get("identity")
    require(isinstance(identity, dict), "observedPackage.identity object is required")
    require(isinstance(identity.get("packageId"), str) and PACKAGE_ID_RE.fullmatch(identity["packageId"]),
            "observedPackage.identity.packageId must be a normalized package id")
    require(isinstance(identity.get("packageVersion"), str) and PACKAGE_VERSION_RE.fullmatch(identity["packageVersion"]),
            "observedPackage.identity.packageVersion must be a normalized package version")
    require(isinstance(identity.get("signerId"), str) and IDENTIFIER_RE.fullmatch(identity["signerId"]),
            "observedPackage.identity.signerId must be a public identifier")
    require(isinstance(identity.get("keyId"), str) and IDENTIFIER_RE.fullmatch(identity["keyId"]),
            "observedPackage.identity.keyId must be a public identifier")

    if manifest["sha256"] != sha256_hex(manifest_bytes):
        mismatch("manifest digest", sha256_hex(manifest_bytes), manifest["sha256"])
    if manifest["sizeBytes"] != len(manifest_bytes):
        mismatch("manifest size", len(manifest_bytes), manifest["sizeBytes"])
    return observed


def validate_signed_payload(value: dict[str, Any], observed: dict[str, Any]) -> bytes:
    payload = value.get("canonicalSignedPayloadModel")
    require(isinstance(payload, dict), "canonicalSignedPayloadModel must be a normalized JSON object")
    validate_json_model(payload)

    package = payload.get("package")
    runtime = payload.get("runtime")
    trust = payload.get("trust")
    require(isinstance(package, dict), "canonicalSignedPayloadModel.package object is required")
    if package.get("id") != observed["identity"]["packageId"]:
        mismatch("package id", observed["identity"]["packageId"], package.get("id"))
    if package.get("version") != observed["identity"]["packageVersion"]:
        mismatch("package version", observed["identity"]["packageVersion"], package.get("version"))

    for name in ("archive", "manifest", "wasm"):
        require_sha_size(payload.get(name), f"canonicalSignedPayloadModel.{name}")
    require_package_path(payload["wasm"].get("path"), "canonicalSignedPayloadModel.wasm.path")
    for field in ("sha256", "sizeBytes"):
        if payload["archive"][field] != observed["archive"][field]:
            mismatch(f"archive {'digest' if field == 'sha256' else 'size'}", observed["archive"][field], payload["archive"][field])
        if payload["manifest"][field] != observed["manifest"][field]:
            mismatch(f"manifest {'digest' if field == 'sha256' else 'size'}", observed["manifest"][field], payload["manifest"][field])
        if payload["wasm"][field] != observed["wasm"][field]:
            mismatch(f"wasm {'digest' if field == 'sha256' else 'size'}", observed["wasm"][field], payload["wasm"][field])
    if payload["wasm"]["path"] != observed["wasm"]["path"]:
        mismatch("wasm path", observed["wasm"]["path"], payload["wasm"]["path"])

    require(isinstance(runtime, dict), "canonicalSignedPayloadModel.runtime object is required")
    require_bool(runtime, "network", False, "canonicalSignedPayloadModel.runtime")
    require(runtime.get("hostImports") == ALLOWED_IMPORTS,
            "canonicalSignedPayloadModel.runtime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in runtime.get("hostImports", []),
            "canonicalSignedPayloadModel.runtime.hostImports must not include http_request")

    require(isinstance(trust, dict), "canonicalSignedPayloadModel.trust object is required")
    if trust.get("signerId") != observed["identity"]["signerId"]:
        mismatch("signer id", observed["identity"]["signerId"], trust.get("signerId"))
    if trust.get("keyId") != observed["identity"]["keyId"]:
        mismatch("key id", observed["identity"]["keyId"], trust.get("keyId"))
    return canonical_bytes(payload)


def validate_expected_trust(value: dict[str, Any], observed: dict[str, Any], payload_bytes: bytes) -> None:
    expected = value.get("expectedTrust")
    require(isinstance(expected, dict), "expectedTrust object is required")
    require(expected.get("mode") in {"private-checksum-pin", "private-signature-pin"},
            "expectedTrust.mode must be a future private pin mode")
    release = value.get("releasePolicy")
    require(isinstance(release, dict), "releasePolicy object is required")
    if expected.get("mode") == "private-signature-pin":
        require_bool(release, "allowUnsignedRelease", False, "releasePolicy")
    require_bool(release, "signaturePinnedModeRequiresSignatureBlock", True, "releasePolicy")

    pins = expected.get("checksumPins")
    require(isinstance(pins, dict), "expectedTrust.checksumPins object is required")
    if expected.get("mode") == "private-checksum-pin":
        require("archiveSha256" in pins or "wasmSha256" in pins,
                "checksum-pinned mode missing expected checksum")
    if "archiveSha256" in pins and pins["archiveSha256"] != observed["archive"]["sha256"]:
        mismatch("archive digest", pins["archiveSha256"], observed["archive"]["sha256"])
    if "archiveSizeBytes" in pins and pins["archiveSizeBytes"] != observed["archive"]["sizeBytes"]:
        mismatch("archive size", pins["archiveSizeBytes"], observed["archive"]["sizeBytes"])
    if "wasmSha256" in pins and pins["wasmSha256"] != observed["wasm"]["sha256"]:
        mismatch("wasm digest", pins["wasmSha256"], observed["wasm"]["sha256"])
    if "wasmSizeBytes" in pins and pins["wasmSizeBytes"] != observed["wasm"]["sizeBytes"]:
        mismatch("wasm size", pins["wasmSizeBytes"], observed["wasm"]["sizeBytes"])

    package = expected.get("package")
    require(isinstance(package, dict), "expectedTrust.package object is required")
    if package.get("id") != observed["identity"]["packageId"]:
        mismatch("package id", package.get("id"), observed["identity"]["packageId"])
    if package.get("version") != observed["identity"]["packageVersion"]:
        mismatch("package version", package.get("version"), observed["identity"]["packageVersion"])

    signer = expected.get("signer")
    require(isinstance(signer, dict), "expectedTrust.signer object is required")
    if expected.get("mode") == "private-signature-pin":
        if signer.get("signerId") != observed["identity"]["signerId"]:
            mismatch("signer id", signer.get("signerId"), observed["identity"]["signerId"])
        if signer.get("keyId") != observed["identity"]["keyId"]:
            mismatch("key id", signer.get("keyId"), observed["identity"]["keyId"])
        if observed["canonicalSignedPayload"]["sha256"] != sha256_hex(payload_bytes):
            mismatch("canonical payload digest", sha256_hex(payload_bytes), observed["canonicalSignedPayload"]["sha256"])
        if observed["canonicalSignedPayload"]["sizeBytes"] != len(payload_bytes):
            mismatch("canonical payload size", len(payload_bytes), observed["canonicalSignedPayload"]["sizeBytes"])
        if expected.get("canonicalPayloadSha256") != observed["canonicalSignedPayload"]["sha256"]:
            mismatch("canonical payload digest", expected.get("canonicalPayloadSha256"), observed["canonicalSignedPayload"]["sha256"])


def validate_signature_block(value: dict[str, Any]) -> None:
    expected = value["expectedTrust"]
    block = value.get("signatureBlock")
    require(isinstance(block, dict), "signature block object is required")
    if expected.get("mode") == "private-signature-pin":
        require_bool(block, "present", True, "signatureBlock")
        require_bool(block, "unsigned", False, "signatureBlock")
        require_bool(block, "malformed", False, "signatureBlock")
        require_bool(block, "tampered", False, "signatureBlock")
        require(block.get("state") == "well-formed-placeholder",
                "signature block must be well-formed placeholder")
    require_bool(block, "realVerificationPerformed", False, "signatureBlock")
    require_bool(block, "rawSignatureIncluded", False, "signatureBlock")


def validate_diagnostics(value: dict[str, Any]) -> None:
    diagnostics = value.get("diagnostics")
    require(isinstance(diagnostics, dict), "diagnostics object is required")
    require_bool(diagnostics, "redactedByDefault", True, "diagnostics")
    require_bool(diagnostics, "includeRawSignatures", False, "diagnostics")
    require_bool(diagnostics, "includeRawArchiveBytes", False, "diagnostics")
    require_bool(diagnostics, "includeRawWasmBytes", False, "diagnostics")
    require_bool(diagnostics, "includeFullManifestDump", False, "diagnostics")
    fields = diagnostics.get("reportFields")
    require(isinstance(fields, list) and fields, "diagnostics.reportFields must list minimal fields")
    for field in fields:
        require(field in {"status", "case", "reasonCode", "field", "expectedPrefix", "observedPrefix"},
                "diagnostics.reportFields must be minimal field names only")
    reasons = diagnostics.get("reasonCodes")
    require(isinstance(reasons, list) and reasons, "diagnostics.reasonCodes must be listed")
    for code in reasons:
        require(isinstance(code, str) and REASON_CODE_RE.fullmatch(code),
                "diagnostics.reasonCodes must be stable reason codes")


def validate_non_goals(value: dict[str, Any]) -> None:
    non_goals = value.get("nonGoals")
    require(isinstance(non_goals, dict), "nonGoals object is required")
    for key in ("realSigning", "signatureVerification", "keyGeneration", "certificates",
                "keyStore", "trustStore", "productIngestion", "runtimeLoading",
                "productRuntime", "productUi", "network", "http", "webViewJsDsl",
                "sourceMarket", "publicIndex", "remoteInstall", "builtInSources",
                "rawArchiveBytes", "rawWasmBytes", "rawSignatures", "credentials",
                "headers", "fullLocalPaths", "executableHooks"):
        require_bool(non_goals, key, True, "nonGoals")


def validate_policy(value: Any) -> None:
    require(isinstance(value, dict), "json root must be an object")
    validate_no_forbidden_material(value)
    validate_scope(value)
    manifest_bytes = validate_manifest_model(value.get("manifestModel"))
    observed = validate_observed(value, manifest_bytes)
    payload_bytes = validate_signed_payload(value, observed)
    validate_expected_trust(value, observed, payload_bytes)
    validate_signature_block(value)
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
    parser = argparse.ArgumentParser(description="Validate static tamper/checksum-pin boundary fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--policy", default="tools/wasm-runtime-spike/source-package/tamper-checksum-pin.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/tamper-checksum-pin-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    policy_path = Path(args.policy).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "tamper-checksum-pin-report.json"
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
        require(not failing, f"{len(failing)} tamper/checksum-pin case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid tamper/checksum-pin fixture(s) accepted",
            f"{report['invalidCases']} invalid tamper/checksum-pin fixture(s) rejected",
            "archive, manifest, WASM, package id/version, signer id/key id, and canonical payload pin mismatches fail closed",
            "signature block missing/malformed/tampered/unsigned release cases are rejected in signature-pinned mode without real verification",
            "network=true, http_request import, source market/remote/built-in drift, product runtime/UI, raw bytes, secret/path/header leaks, and validator executable/network/subprocess drift are rejected",
            "reports include reason codes and minimal fields only; digest evidence is prefix-only",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
