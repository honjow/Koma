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
CANONICAL_ALGORITHM = "koma.canonical-json.v1"
HTTP_IMPORT = "koma_host.http_request"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PACKAGE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*){2,}$")
PACKAGE_VERSION_RE = re.compile(r"^[0-9]+[.][0-9]+[.][0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
PACKAGE_PATH_RE = re.compile(r"^[A-Za-z0-9._/-]+$")
TIMESTAMP_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
FORBIDDEN_KEY_RE = re.compile(
    r"(private.?key|raw.?key|credential|cookie|authorization|auth.?header|"
    r"request.?body|response.?body|archive.?bytes|wasm.?bytes|trust.?store|"
    r"certificate|cert.?pem|signature.?dump|picker.?uri|cache.?path|user.?path)",
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
REASON_CODE_RE = re.compile(r"^[A-Z0-9_]+$")


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


def parse_strict_json_text(raw: str) -> Any:
    try:
        return json.loads(raw, object_pairs_hook=no_duplicates_object_pairs, parse_constant=reject_constant)
    except json.JSONDecodeError as err:
        raise ValidationError(f"strict JSON parse failed: {err.msg}") from err


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


def mutated(base: dict[str, Any], case: dict[str, Any]) -> Any:
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
    require(isinstance(value, dict), "canonical payload input must be a normalized JSON object")
    validate_json_model(value)
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode("utf-8")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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


def require_sha_size(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} object is required")
    require(isinstance(value.get("sha256"), str) and SHA256_RE.fullmatch(value["sha256"]),
            f"{path}.sha256 must be lowercase sha256")
    require(isinstance(value.get("sizeBytes"), int) and value["sizeBytes"] > 0,
            f"{path}.sizeBytes must be a positive integer")


def validate_boundary_scope(value: dict[str, Any]) -> None:
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


def validate_canonicalization(value: dict[str, Any]) -> None:
    rules = value.get("canonicalization")
    require(isinstance(rules, dict), "canonicalization object is required")
    require(rules.get("algorithm") == CANONICAL_ALGORITHM,
            "canonicalization.algorithm unknown canonicalization algorithm/version")
    require(rules.get("input") == "normalized-json-object",
            "canonicalization.input must be normalized-json-object")
    require_bool(rules, "utf8", True, "canonicalization")
    require_bool(rules, "sortedKeys", True, "canonicalization")
    require_bool(rules, "insignificantWhitespace", False, "canonicalization")
    require_bool(rules, "duplicateKeysAccepted", False, "canonicalization")
    require_bool(rules, "nanInfinityAccepted", False, "canonicalization")
    require_bool(rules, "commentsAccepted", False, "canonicalization")
    require_bool(rules, "trailingCommasAccepted", False, "canonicalization")
    primitives = rules.get("primitiveFormatting")
    require(isinstance(primitives, dict), "canonicalization.primitiveFormatting object is required")
    require_bool(primitives, "floatsAllowed", False, "canonicalization.primitiveFormatting")
    require_bool(primitives, "integersDecimalNoPlus", True, "canonicalization.primitiveFormatting")
    require(primitives.get("unicodeNormalization") == "NFC",
            "canonicalization.primitiveFormatting.unicodeNormalization must be NFC")


def validate_manifest_binding(value: dict[str, Any], payload: dict[str, Any]) -> None:
    manifest_model = value.get("manifestModel")
    require(isinstance(manifest_model, dict), "manifestModel must be a normalized JSON object")
    require("rawManifestText" not in value, "raw manifest text must not be used as signed input")
    manifest_bytes = canonical_bytes(manifest_model)
    manifest = payload.get("manifest")
    require_sha_size(manifest, "payload.manifest")
    require(manifest["sha256"] == sha256_hex(manifest_bytes), "manifest digest mismatch")
    require(manifest["sizeBytes"] == len(manifest_bytes), "payload.manifest.sizeBytes mismatch")
    require(manifest.get("input") == "normalized-json-object",
            "payload.manifest.input must be normalized-json-object")


def validate_payload_model(value: dict[str, Any]) -> dict[str, Any]:
    payload = value.get("payload")
    require(isinstance(payload, dict), "payload must be a normalized JSON object")
    validate_json_model(payload)

    require(payload.get("schemaVersion") == 1, "payload.schemaVersion must be 1")
    package = payload.get("package")
    require(isinstance(package, dict), "payload.package object is required")
    require(isinstance(package.get("id"), str) and PACKAGE_ID_RE.fullmatch(package["id"]),
            "payload.package.id must be a normalized package id")
    require(isinstance(package.get("version"), str) and PACKAGE_VERSION_RE.fullmatch(package["version"]),
            "payload.package.version must be a normalized package version")

    abi = payload.get("abi")
    require(isinstance(abi, dict), "payload.abi object is required")
    require(abi.get("sourceAbi") == "koma-source-abi-v0.1", "payload.abi.sourceAbi must be bound")
    require(abi.get("hostAbi") == "koma-host-v0.1", "payload.abi.hostAbi must be bound")
    require(abi.get("schemaVersion") == 1, "payload.abi.schemaVersion must be bound")

    require_sha_size(payload.get("archive"), "payload.archive")
    require_sha_size(payload.get("wasm"), "payload.wasm")
    wasm = payload["wasm"]
    require(isinstance(wasm.get("path"), str) and wasm["path"].endswith(".wasm")
            and PACKAGE_PATH_RE.fullmatch(wasm["path"]) and not wasm["path"].startswith("/"),
            "payload.wasm.path must be a package-relative wasm path")

    runtime = payload.get("runtime")
    require(isinstance(runtime, dict), "payload.runtime object is required")
    require_bool(runtime, "network", False, "payload.runtime")
    require(runtime.get("hostImports") == ALLOWED_IMPORTS,
            "payload.runtime.hostImports must be exactly log/check_cancel")
    require(HTTP_IMPORT not in runtime.get("hostImports", []),
            "payload.runtime.hostImports must not include http_request")

    trust = payload.get("trust")
    require(isinstance(trust, dict), "payload.trust object is required")
    require(trust.get("mode") in {"local-dev", "private-checksum-pin", "private-signature-pin", "enterprise-private-trust-store"},
            "payload.trust.mode must be public provenance metadata")
    require(isinstance(trust.get("provenance"), str) and trust["provenance"],
            "payload.trust.provenance public metadata is required")
    require(isinstance(trust.get("signerId"), str) and trust["signerId"].startswith("signer:"),
            "payload.trust.signerId must be an identifier only")
    require(isinstance(trust.get("keyId"), str) and trust["keyId"].startswith("key:"),
            "payload.trust.keyId must be an identifier only")
    for key in ("createdAt", "expiresAt"):
        require(isinstance(trust.get(key), str) and TIMESTAMP_RE.fullmatch(trust[key]),
                f"payload.trust.{key} must be an RFC3339 UTC freshness field")
    require(trust["createdAt"] < trust["expiresAt"], "payload.trust.createdAt must be before expiresAt")
    return payload


def validate_diagnostics(value: dict[str, Any]) -> None:
    diagnostics = value.get("diagnostics")
    require(isinstance(diagnostics, dict), "diagnostics object is required")
    require_bool(diagnostics, "redactedByDefault", True, "diagnostics")
    require_bool(diagnostics, "dumpRawPayloadByDefault", False, "diagnostics")
    require_bool(diagnostics, "dumpSecretsPathsHeadersSignatures", False, "diagnostics")
    fields = diagnostics.get("reportFields")
    require(isinstance(fields, list) and fields, "diagnostics.reportFields must list minimal fields")
    for field in fields:
        require(field in {"status", "case", "reasonCode", "field", "expected", "actualKind"},
                "diagnostics.reportFields must be minimal field names only")
    reasons = diagnostics.get("reasonCodes")
    require(isinstance(reasons, list) and reasons, "diagnostics.reasonCodes must be listed")
    for code in reasons:
        require(isinstance(code, str) and REASON_CODE_RE.fullmatch(code),
                "diagnostics.reasonCodes must be stable reason codes")


def validate_non_goals(value: dict[str, Any]) -> None:
    non_goals = value.get("nonGoals")
    require(isinstance(non_goals, dict), "nonGoals object is required")
    for key in ("rawPrivateKeys", "rawAppSigningCerts", "credentials", "cookies", "authorizationHeaders",
                "fullUserPaths", "pickerUris", "appPrivateAbsolutePaths", "rawArchiveBytes",
                "rawWasmBytes", "fullRequestResponseBodies", "generatedCachePaths",
                "trustStoreDumps", "sourceMarket", "remoteInstall", "builtInSources",
                "productRuntime", "productUi", "network", "webViewJsDsl", "executableHooks"):
        require_bool(non_goals, key, True, "nonGoals")


def validate_policy(value: Any) -> None:
    require(isinstance(value, dict), "json root must be an object")
    validate_no_forbidden_material(value)
    validate_boundary_scope(value)
    validate_canonicalization(value)
    payload = validate_payload_model(value)
    validate_manifest_binding(value, payload)
    validate_diagnostics(value)
    validate_non_goals(value)

    payload_bytes = canonical_bytes(payload)
    digest = value.get("payloadSha256")
    require(isinstance(digest, str) and SHA256_RE.fullmatch(digest),
            "payloadSha256 must be lowercase sha256")
    require(digest == sha256_hex(payload_bytes), "payload digest mismatch")
    require(isinstance(value.get("payloadSizeBytes"), int) and value["payloadSizeBytes"] == len(payload_bytes),
            "payloadSizeBytes mismatch")


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
        try:
            if "rawJson" in case:
                candidate = parse_strict_json_text(case["rawJson"])
            elif "input" in case:
                candidate = case["input"]
            else:
                candidate = mutated(base, case)
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
    parser = argparse.ArgumentParser(description="Validate static canonical signature payload boundary fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--policy", default="tools/wasm-runtime-spike/source-package/canonical-signature-payload.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/canonical-signature-payload-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    policy_path = Path(args.policy).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "canonical-signature-payload-report.json"
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
        require(not failing, f"{len(failing)} canonical signature payload case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid canonical payload fixture(s) accepted",
            f"{report['invalidCases']} invalid canonical payload fixture(s) rejected",
            "canonical bytes use UTF-8 JSON with sorted keys and no insignificant whitespace",
            "payload digest and manifest digest/size bindings are checked using stdlib hashlib only",
            "network=true, http_request import, product runtime/UI, source market/remote/built-in drift, executable validator drift, raw byte material, paths, headers, secrets, and signature dumps are rejected",
            "default reports include reason codes and minimal field names, not raw payload dumps",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
