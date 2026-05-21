#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ALLOWED_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
HTTP_IMPORT = "koma_host.http_request"
ALLOWED_DESCRIPTOR_TYPES = {"placeholder", "testImage"}
ALLOWED_OWNERSHIP = {"host_loaded"}
REQUIRED_ERRORS = {
    "network_disabled",
    "permission_denied",
    "not_found",
    "cancelled",
    "timeout",
    "resource_limit_exceeded",
    "cache_miss",
    "stale_cache",
    "decode_error",
    "source_error",
}
OPAQUE_ID_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]{2,63}$")
RAW_SECRET_RE = re.compile(
    r"(Authorization\s*:|Bearer\s+[A-Za-z0-9._~+/=-]+|Cookie\s*:|Set-Cookie\s*:|"
    r"\b(password|token|secret|api[_-]?key|session)\s*[=:]\s*[^\\s,;}]+|"
    r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})",
    re.IGNORECASE,
)
PATH_OR_REMOTE_RE = re.compile(
    r"(https?://|ftp://|file://|content://|ohos://|internal://|app-private|"
    r"(^|[\\s\"'])/(home|Users|data|storage|sdcard|mnt|tmp|var)/|"
    r"[A-Za-z]:\\\\|\\.hermes-artifacts|/cache/|/files/|/Documents/)",
    re.IGNORECASE,
)
FORBIDDEN_RAW_HEADER_NAMES = {
    "authorization",
    "cookie",
    "referer",
    "referrer",
    "set-cookie",
    "user-agent",
    "host",
    "proxy-authorization",
}
SECRET_VALUE_KEYS = {
    "authorization",
    "authHeader",
    "cookie",
    "password",
    "secret",
    "session",
    "setCookie",
    "token",
}
EXECUTABLE_KEYS = {
    "body",
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
    "builtInSource",
    "imageLoaderEnabled",
    "market",
    "marketplace",
    "marketplaceUrl",
    "plugin",
    "productRuntimeEnabled",
    "remoteInstallUrl",
    "repository",
    "sourceMarket",
    "updateUrl",
    "webView",
}


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


def is_future_disabled_path(path: str) -> bool:
    return ".futureImageRequestDescriptor" in path or ".sourceResolvedImages" in path


def validate_no_leaks(value: Any) -> None:
    for path, item in walk(value):
        if isinstance(item, str):
            require(not RAW_SECRET_RE.search(item), f"{path} leaks raw credential material")
            require(not PATH_OR_REMOTE_RE.search(item), f"{path} leaks remote URL or local/app-private path")
            if path.lower().endswith(".cachekey"):
                require(False, f"{path} must not contain prebuilt cache key material")
        if isinstance(item, dict):
            for key, child in item.items():
                lower_key = key.lower()
                if lower_key in FORBIDDEN_RAW_HEADER_NAMES and isinstance(child, str):
                    require(False, f"{path}.{key} contains raw forbidden header value")
                if key in SECRET_VALUE_KEYS and isinstance(child, str):
                    require(False, f"{path}.{key} contains inline secret-like value")
                if lower_key in {"headers", "requestheaders", "responseheaders"} and isinstance(child, dict):
                    require(is_future_disabled_path(f"{path}.{key}"),
                            f"{path}.{key} raw headers are forbidden in current source responses")


def validate_no_executable_or_scope_flags(value: Any) -> None:
    for path, item in walk(value):
        if not isinstance(item, dict):
            continue
        for key, child in item.items():
            child_path = f"{path}.{key}"
            if key in EXECUTABLE_KEYS:
                require(is_future_disabled_path(child_path), f"{child_path} must not be executable")
            if key in FORBIDDEN_SCOPE_KEYS:
                require(child is False, f"{child_path} is outside tooling-only scope and must be false")
            if key in {"enabled", "networkEnabled", "remoteInstall", "remoteImagesEnabled"}:
                require(child is False, f"{child_path} must be false")
            if key == "runtimeEnabled":
                require(child is False, f"{child_path} must be false")


def require_opaque_id(value: Any, path: str) -> None:
    require(isinstance(value, str) and OPAQUE_ID_RE.match(value) is not None,
            f"{path} must be an opaque identifier")


def positive_int(value: Any, path: str, maximum: int) -> None:
    require(isinstance(value, int) and not isinstance(value, bool), f"{path} must be an integer")
    require(1 <= value <= maximum, f"{path} must be between 1 and {maximum}")


def validate_current_runtime(value: dict[str, Any]) -> None:
    runtime = value.get("currentRuntime")
    require(isinstance(runtime, dict), "currentRuntime object is required")
    require(runtime.get("network") is False, "network must remain false")
    imports = runtime.get("hostImports")
    require(isinstance(imports, list), "currentRuntime.hostImports must be a list")
    require(imports == ALLOWED_IMPORTS, "hostImports must be exactly koma_host.log/check_cancel")
    require(HTTP_IMPORT not in imports, "current runtime forbids koma_host.http_request import")
    if "httpImportEnabled" in runtime:
        require(runtime["httpImportEnabled"] is False, "currentRuntime.httpImportEnabled must be false")


def validate_cache_identity(value: Any, path: str, descriptor: dict[str, Any]) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    require(set(value.keys()).issubset({
        "namespace", "version", "sourceOpaqueId", "sourceId", "mangaId", "chapterId", "pageId"
    }), f"{path} has unsupported keys")
    for key in ("namespace", "sourceOpaqueId", "sourceId", "mangaId", "chapterId", "pageId"):
        require_opaque_id(value.get(key), f"{path}.{key}")
    positive_int(value.get("version"), f"{path}.version", 1000000)
    for key in ("sourceId", "mangaId", "chapterId", "pageId"):
        require(value[key] == descriptor[key], f"{path}.{key} must match descriptor.{key}")
    require(value["sourceOpaqueId"] == descriptor["pageId"],
            f"{path}.sourceOpaqueId must match descriptor.pageId")


def validate_descriptor(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    require(set(value.keys()).issubset({
        "descriptorType", "ownership", "sourceId", "mangaId", "chapterId", "pageId",
        "ordinal", "display", "cacheIdentity", "errors"
    }), f"{path} has unsupported keys")
    require(value.get("descriptorType") in ALLOWED_DESCRIPTOR_TYPES,
            f"{path}.descriptorType must be placeholder/testImage")
    require(value.get("ownership") in ALLOWED_OWNERSHIP, f"{path}.ownership must be host_loaded")
    for key in ("sourceId", "mangaId", "chapterId", "pageId"):
        require_opaque_id(value.get(key), f"{path}.{key}")
    positive_int(value.get("ordinal"), f"{path}.ordinal", 500)
    display = value.get("display")
    require(isinstance(display, dict), f"{path}.display must be an object")
    require(display.get("kind") in {"placeholder", "testImage"}, f"{path}.display.kind is unsupported")
    positive_int(display.get("width"), f"{path}.display.width", 10000)
    positive_int(display.get("height"), f"{path}.display.height", 20000)
    validate_cache_identity(value.get("cacheIdentity"), f"{path}.cacheIdentity", value)
    if "errors" in value:
        validate_errors(value["errors"], f"{path}.errors")


def validate_page_loading(value: dict[str, Any]) -> None:
    page_loading = value.get("pageLoading")
    require(isinstance(page_loading, dict), "pageLoading object is required")
    require(page_loading.get("defaultOwnership") == "host_loaded",
            "pageLoading.defaultOwnership must be host_loaded")
    accepted = page_loading.get("currentAcceptedDescriptorTypes")
    require(isinstance(accepted, list) and set(accepted) == ALLOWED_DESCRIPTOR_TYPES,
            "pageLoading.currentAcceptedDescriptorTypes must be placeholder/testImage")
    source_resolved = page_loading.get("sourceResolvedImages")
    require(isinstance(source_resolved, dict), "pageLoading.sourceResolvedImages object is required")
    require(source_resolved.get("designOnly") is True, "sourceResolvedImages.designOnly must be true")
    require(source_resolved.get("futureDisabled") is True, "sourceResolvedImages.futureDisabled must be true")
    require(source_resolved.get("requiresNetwork") is True, "sourceResolvedImages.requiresNetwork must be true")
    require(source_resolved.get("requiresHttpImport") is True, "sourceResolvedImages.requiresHttpImport must be true")
    require(source_resolved.get("acceptedInCurrentRuntime") is False,
            "sourceResolvedImages.acceptedInCurrentRuntime must be false")
    descriptors = page_loading.get("descriptors")
    require(isinstance(descriptors, list) and descriptors, "pageLoading.descriptors must be a non-empty list")
    seen: set[tuple[str, str, str, str]] = set()
    for index, descriptor in enumerate(descriptors):
        validate_descriptor(descriptor, f"pageLoading.descriptors[{index}]")
        key = (descriptor["sourceId"], descriptor["mangaId"], descriptor["chapterId"], descriptor["pageId"])
        require(key not in seen, f"pageLoading.descriptors[{index}] duplicates page identity")
        seen.add(key)


def validate_cache_policy(value: dict[str, Any]) -> None:
    policy = value.get("cachePolicy")
    require(isinstance(policy, dict), "cachePolicy object is required")
    for key in ("hostBuildsFinalKey", "forbidRawUrls", "forbidHeaders", "forbidCredentials", "forbidLocalPaths"):
        require(policy.get(key) is True, f"cachePolicy.{key} must be true")
    positive_int(policy.get("deterministicVersion"), "cachePolicy.deterministicVersion", 1000000)
    stale = policy.get("staleBehavior")
    require(isinstance(stale, dict), "cachePolicy.staleBehavior object is required")
    require(stale.get("hostOwned") is True, "cachePolicy.staleBehavior.hostOwned must be true")
    require(set(stale.get("allowedStates", [])) == {"fresh", "stale", "missing", "evicted"},
            "cachePolicy.staleBehavior.allowedStates must contain fresh/stale/missing/evicted")


def validate_header_policy(value: dict[str, Any]) -> None:
    policy = value.get("headerPolicy")
    require(isinstance(policy, dict), "headerPolicy object is required")
    require(policy.get("hostOwned") is True, "headerPolicy.hostOwned must be true")
    require(policy.get("redacted") is True, "headerPolicy.redacted must be true")
    require(policy.get("sourceMayReturnRawHeaders") is False,
            "headerPolicy.sourceMayReturnRawHeaders must be false")
    allowlist = policy.get("allowlist")
    require(isinstance(allowlist, list), "headerPolicy.allowlist must be a list")
    for name in allowlist:
        require(isinstance(name, str) and name in {"Accept", "Accept-Language"},
                "headerPolicy.allowlist contains unsupported header")
    forbidden = policy.get("forbiddenRaw")
    require(isinstance(forbidden, list), "headerPolicy.forbiddenRaw must be a list")
    require(FORBIDDEN_RAW_HEADER_NAMES.issubset({str(name).lower() for name in forbidden}),
            "headerPolicy.forbiddenRaw must include sensitive request headers")


def validate_future_image_request(value: dict[str, Any]) -> None:
    descriptor = value.get("futureImageRequestDescriptor")
    require(isinstance(descriptor, dict), "futureImageRequestDescriptor object is required")
    require(descriptor.get("designOnly") is True, "futureImageRequestDescriptor.designOnly must be true")
    require(descriptor.get("futureDisabled") is True, "futureImageRequestDescriptor.futureDisabled must be true")
    require(descriptor.get("runtimeEnabled") is False, "futureImageRequestDescriptor.runtimeEnabled must be false")
    require(set(descriptor.get("methodPolicy", [])) == {"GET", "HEAD"},
            "futureImageRequestDescriptor.methodPolicy must be GET/HEAD")
    require(set(descriptor.get("schemePolicy", [])) == {"https"},
            "futureImageRequestDescriptor.schemePolicy must be https")
    headers = descriptor.get("headers")
    require(isinstance(headers, dict), "futureImageRequestDescriptor.headers must be an object")
    require(headers.get("hostOwned") is True, "futureImageRequestDescriptor.headers.hostOwned must be true")
    require(headers.get("redacted") is True, "futureImageRequestDescriptor.headers.redacted must be true")
    require(headers.get("sourceProvidesValues") is False,
            "futureImageRequestDescriptor.headers.sourceProvidesValues must be false")
    cookies = descriptor.get("cookies")
    require(isinstance(cookies, dict), "futureImageRequestDescriptor.cookies must be an object")
    require(cookies.get("hostOwned") is True, "futureImageRequestDescriptor.cookies.hostOwned must be true")
    require(cookies.get("sourceOwnsCookieJar") is False,
            "futureImageRequestDescriptor.cookies.sourceOwnsCookieJar must be false")
    timeout = descriptor.get("timeoutPolicy")
    require(isinstance(timeout, dict), "futureImageRequestDescriptor.timeoutPolicy must be an object")
    require(timeout.get("hostOwnedWallClock") is True,
            "futureImageRequestDescriptor.timeoutPolicy.hostOwnedWallClock must be true")
    positive_int(timeout.get("maxMs"), "futureImageRequestDescriptor.timeoutPolicy.maxMs", 10000)
    size = descriptor.get("sizePolicy")
    require(isinstance(size, dict), "futureImageRequestDescriptor.sizePolicy must be an object")
    positive_int(size.get("maxBytes"), "futureImageRequestDescriptor.sizePolicy.maxBytes", 10485760)


def validate_network_gates(value: dict[str, Any]) -> None:
    gates = value.get("networkGates")
    require(isinstance(gates, dict), "networkGates object is required")
    for key in ("network", "httpImport", "remoteUrlsAcceptedInCurrentRuntime", "imageRequestsAcceptedInCurrentRuntime"):
        require(gates.get(key) is False, f"networkGates.{key} must be false")


def validate_errors(value: Any, path: str = "errors") -> None:
    require(isinstance(value, list), f"{path} must be a list")
    for index, item in enumerate(value):
        if isinstance(item, str):
            require(item in REQUIRED_ERRORS, f"{path}[{index}] is unsupported")
        else:
            require(isinstance(item, dict), f"{path}[{index}] must be a string or object")
            require(item.get("code") in REQUIRED_ERRORS, f"{path}[{index}].code is unsupported")
            require(isinstance(item.get("message"), str) and item["message"],
                    f"{path}[{index}].message is required")
            if "retryable" in item:
                require(isinstance(item["retryable"], bool), f"{path}[{index}].retryable must be boolean")


def validate_product_runtime(value: dict[str, Any]) -> None:
    product = value.get("productRuntime")
    require(isinstance(product, dict), "productRuntime object is required")
    for key in ("enabled", "networkEnabled", "remoteInstall", "sourceMarket", "imageLoaderEnabled"):
        require(product.get(key) is False, f"productRuntime.{key} must be false")


def validate_boundary(value: dict[str, Any]) -> None:
    require(value.get("boundaryVersion") == 1, "boundaryVersion must be 1")
    require(value.get("designOnly") is True, "designOnly must be true")
    require(value.get("runtimeEnabled") is False, "runtimeEnabled must be false")
    validate_no_leaks(value)
    validate_no_executable_or_scope_flags(value)
    validate_current_runtime(value)
    validate_page_loading(value)
    validate_cache_policy(value)
    validate_header_policy(value)
    validate_future_image_request(value)
    validate_network_gates(value)
    validate_errors(value.get("errors"))
    validate_product_runtime(value)


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
    parser = argparse.ArgumentParser(description="Validate design-only image/page loading boundary fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/image-page-fixtures-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "image-page-fixtures-report.json"
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
        require(not failing, f"{len(failing)} image/page fixture case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid image/page boundary fixture(s) accepted",
            f"{report['invalidCases']} invalid image/page boundary fixture(s) rejected",
            "network=false and exact log/check_cancel host imports enforced",
            "current descriptors limited to host-loaded placeholder/test images",
            "remote URLs, raw paths, raw headers, credential leaks, executable keys, and unsafe cache keys rejected",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
