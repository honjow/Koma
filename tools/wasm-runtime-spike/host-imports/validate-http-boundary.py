#!/usr/bin/env python3
import argparse
import copy
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


HTTP_IMPORT = "koma_host.http_request"
BASE_IMPORTS = ["koma_host.log", "koma_host.check_cancel"]
DESIGN_HOST_ABI = "koma-host-v0.2-design-http"
ALLOWED_METHODS = {"GET", "HEAD", "POST"}
ALLOWED_SCHEMES = {"https", "http"}
SECRET_WORDS = ("password", "token", "secret", "apikey", "apiKey", "cookie", "authorization")
FORBIDDEN_SCOPE_KEYS = {
    "repository",
    "repositories",
    "market",
    "marketplaceUrl",
    "sourceMarket",
    "remoteInstallUrl",
    "installUrl",
    "updateUrl",
    "catalogUrl",
    "indexUrl",
    "webView",
    "quickjs",
    "apk",
    "plugin",
}


class ValidationError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def walk_forbidden_keys(value, path="$") -> list[str]:
    hits: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in FORBIDDEN_SCOPE_KEYS:
                hits.append(f"{path}.{key}")
            hits.extend(walk_forbidden_keys(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            hits.extend(walk_forbidden_keys(child, f"{path}[{index}]"))
    return hits


def has_secret_literal(value) -> bool:
    if isinstance(value, str):
        lower = value.lower()
        return any(word.lower() in lower for word in SECRET_WORDS)
    if isinstance(value, dict):
        return any(has_secret_literal(k) or has_secret_literal(v) for k, v in value.items())
    if isinstance(value, list):
        return any(has_secret_literal(item) for item in value)
    return False


def validate_package_identity(manifest: dict) -> str:
    package = manifest.get("package")
    require(isinstance(package, dict), "package object is required")
    package_id = package.get("id")
    require(isinstance(package_id, str), "package.id is required")
    require(re.fullmatch(r"[a-z][a-z0-9]*(\.[a-z0-9][a-z0-9-]*){2,}", package_id),
            "package.id must be reverse-DNS-like ASCII with at least three labels")
    require(package.get("nsfw") is False, "design fixture must declare nsfw=false")
    return package_id


def validate_network_policy(policy: dict) -> dict:
    require(isinstance(policy, dict), "permissions.networkPolicy object is required")
    schemes = policy.get("allowedSchemes")
    hosts = policy.get("allowedHosts")
    methods = policy.get("allowedMethods")
    require(isinstance(schemes, list) and schemes, "allowedSchemes must be a non-empty list")
    require(set(schemes).issubset(ALLOWED_SCHEMES), "allowedSchemes may only contain https/http")
    require("https" in schemes, "https must be allowed")
    require(isinstance(hosts, list) and hosts, "allowedHosts must be a non-empty list")
    for host in hosts:
        require(isinstance(host, str) and host == host.lower(), f"allowed host must be lowercase: {host}")
        require(re.fullmatch(r"[a-z0-9.-]+", host), f"allowed host contains invalid characters: {host}")
        require(not host.endswith(".local") and host not in {"localhost", "127.0.0.1"},
                f"design sample must not target local/private hosts: {host}")
    require(isinstance(methods, list) and methods, "allowedMethods must be a non-empty list")
    require(set(methods).issubset(ALLOWED_METHODS), "allowedMethods may only contain GET/HEAD/POST")
    require(isinstance(policy.get("maxRequestBytes"), int), "maxRequestBytes must be an integer")
    require(0 < policy["maxRequestBytes"] <= 65536, "maxRequestBytes must be 1..65536")
    require(isinstance(policy.get("maxResponseBytes"), int), "maxResponseBytes must be an integer")
    require(0 < policy["maxResponseBytes"] <= 1048576, "maxResponseBytes must be 1..1048576")
    require(isinstance(policy.get("timeoutMs"), int), "timeoutMs must be an integer")
    require(1000 <= policy["timeoutMs"] <= 10000, "timeoutMs must be 1000..10000")

    redirects = policy.get("redirects")
    require(isinstance(redirects, dict), "redirects object is required")
    require(redirects.get("mode") in {"none", "follow"}, "redirects.mode must be none/follow")
    require(isinstance(redirects.get("maxCount"), int), "redirects.maxCount must be an integer")
    require(0 <= redirects["maxCount"] <= 5, "redirects.maxCount must be 0..5")

    headers = policy.get("headers")
    require(isinstance(headers, dict), "headers object is required")
    allowlist = headers.get("requestAllowlist")
    require(isinstance(allowlist, list) and allowlist, "headers.requestAllowlist must be a non-empty list")
    lower_headers = {h.lower() for h in allowlist if isinstance(h, str)}
    denied_headers = {"authorization", "cookie", "proxy-authorization", "set-cookie"}
    require(lower_headers.isdisjoint(denied_headers), "raw credential headers must not be allowlisted")
    require(headers.get("denyRawSecrets") is True, "headers.denyRawSecrets must be true")

    credentials = policy.get("credentials")
    require(isinstance(credentials, dict), "credentials object is required")
    require(credentials.get("allowCredentialsRef") is True, "credentialsRef must be explicitly allowed")
    require(credentials.get("allowRawSecrets") is False, "raw secrets must be forbidden")
    require(credentials.get("cookiePolicy") == "host-managed-session",
            "cookiePolicy must be host-managed-session")

    return {
        "schemes": schemes,
        "hosts": hosts,
        "methods": methods,
        "maxResponseBytes": policy["maxResponseBytes"],
        "timeoutMs": policy["timeoutMs"],
    }


def validate_request_sample(boundary: dict, policy: dict) -> None:
    request = boundary.get("requestEnvelope")
    response = boundary.get("responseEnvelope")
    require(isinstance(request, dict), "httpBoundary.requestEnvelope object is required")
    require(isinstance(response, dict), "httpBoundary.responseEnvelope object is required")
    require(request.get("version") == 1, "requestEnvelope.version must be 1")
    method = request.get("method")
    require(method in policy["methods"], "requestEnvelope.method is not allowed by policy")
    require(method in ALLOWED_METHODS, "requestEnvelope.method is outside ABI method set")
    parsed = urlparse(request.get("url", ""))
    require(parsed.scheme in policy["schemes"], "request URL scheme is not allowed by policy")
    require((parsed.hostname or "").lower() in policy["hosts"], "request URL host is not allowed by policy")
    require(request.get("redirect") in {"none", "follow"}, "request redirect must be none/follow")
    require(isinstance(request.get("timeoutMs"), int), "request timeoutMs must be an integer")
    require(request["timeoutMs"] <= policy["timeoutMs"], "request timeoutMs exceeds policy")
    require(request.get("credentialsRef") is None or isinstance(request.get("credentialsRef"), str),
            "credentialsRef must be null or string")
    require(request.get("bodyBase64") is None or method == "POST", "bodyBase64 is only allowed for POST")

    headers = request.get("headers")
    require(isinstance(headers, dict), "request headers must be an object")
    header_policy = policy["raw"].get("headers", {}).get("requestAllowlist", [])
    allowed_header_names = {h.lower() for h in header_policy}
    for name in headers:
        lower = name.lower()
        require(lower in allowed_header_names, f"request header not allowlisted: {name}")
        require(lower not in {"authorization", "cookie", "proxy-authorization"}, f"raw secret header denied: {name}")

    require(response.get("ok") is True, "responseEnvelope.ok must be true in positive sample")
    require(isinstance(response.get("status"), int), "responseEnvelope.status must be an integer")
    response_url = urlparse(response.get("url", ""))
    require(response_url.scheme in policy["schemes"], "response URL scheme is not allowed by policy")
    require((response_url.hostname or "").lower() in policy["hosts"], "response URL host is not allowed by policy")
    require(isinstance(response.get("bodyBase64"), str), "responseEnvelope.bodyBase64 must be a string")


def validate_design_manifest(path: Path) -> dict:
    manifest = read_json(path)
    forbidden = walk_forbidden_keys(manifest)
    require(not forbidden, "forbidden source-market/plugin keys: " + ", ".join(forbidden))
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(manifest.get("designOnly") is True, "designOnly must be true")
    require(manifest.get("runtimeEnabled") is False, "runtimeEnabled must be false")
    require(manifest.get("networkPerformed") is False, "networkPerformed must be false")
    require(not has_secret_literal(manifest.get("settingsSchema", {})),
            "settingsSchema must not contain credential-shaped literals")
    package_id = validate_package_identity(manifest)

    runtime = manifest.get("runtime")
    require(isinstance(runtime, dict), "runtime object is required")
    require(runtime.get("hostAbi") == DESIGN_HOST_ABI, f"runtime.hostAbi must be {DESIGN_HOST_ABI}")
    imports = runtime.get("requiredHostImports")
    require(isinstance(imports, list), "runtime.requiredHostImports must be a list")
    import_names = [f"{item.get('module')}.{item.get('name')}" for item in imports if isinstance(item, dict)]
    require(import_names == BASE_IMPORTS + [HTTP_IMPORT],
            "requiredHostImports must be log/check_cancel/http_request in order")

    permissions = manifest.get("permissions")
    require(isinstance(permissions, dict), "permissions object is required")
    require(permissions.get("network") is True, "HTTP design manifest must declare permissions.network=true")
    require(permissions.get("hostImports") == BASE_IMPORTS + [HTTP_IMPORT],
            "permissions.hostImports must match HTTP boundary imports")
    policy = validate_network_policy(permissions.get("networkPolicy"))
    policy["raw"] = permissions["networkPolicy"]

    boundary = manifest.get("httpBoundary")
    require(isinstance(boundary, dict), "httpBoundary object is required")
    import_spec = boundary.get("import")
    require(isinstance(import_spec, dict), "httpBoundary.import object is required")
    require(import_spec.get("module") == "koma_host", "httpBoundary.import.module must be koma_host")
    require(import_spec.get("name") == "http_request", "httpBoundary.import.name must be http_request")
    validate_request_sample(boundary, policy)
    require(isinstance(boundary.get("errorCodes"), list), "httpBoundary.errorCodes must be a list")
    require("cancelled" in boundary["errorCodes"], "httpBoundary.errorCodes must include cancelled")
    require("network_unavailable" in boundary["errorCodes"], "httpBoundary.errorCodes must include network_unavailable")

    content_policy = manifest.get("contentPolicy")
    require(isinstance(content_policy, dict), "contentPolicy object is required")
    for key in ("publicIndex", "marketplace", "builtInSource", "remoteInstall"):
        require(content_policy.get(key) is False, f"contentPolicy.{key} must be false")

    return {
        "packageId": package_id,
        "designOnly": True,
        "runtimeEnabled": False,
        "networkPerformed": False,
        "hostAbi": runtime["hostAbi"],
        "hostImports": import_names,
        "networkPolicy": {key: policy[key] for key in ("schemes", "hosts", "methods", "maxResponseBytes", "timeoutMs")},
    }


def validate_network_false_rejects_http(current_manifest_path: Path) -> dict:
    manifest = read_json(current_manifest_path)
    mutated = copy.deepcopy(manifest)
    mutated.setdefault("runtime", {}).setdefault("requiredHostImports", []).append({
        "module": "koma_host",
        "name": "http_request",
    })
    mutated.setdefault("permissions", {}).setdefault("hostImports", []).append(HTTP_IMPORT)
    mutated["permissions"]["network"] = False
    try:
        permissions = mutated["permissions"]
        require(permissions.get("network") is True or HTTP_IMPORT not in permissions.get("hostImports", []),
                "network=false forbids koma_host.http_request")
    except ValidationError as err:
        return {"status": "PASS", "reason": str(err)}
    return {"status": "FAIL", "reason": "mutated network=false manifest unexpectedly allowed HTTP import"}


def run_runtime_validator_rejection(design_manifest: Path, artifact_dir: Path) -> dict:
    validator = repo_root() / "tools/wasm-runtime-spike/source-package/validate-source-package.py"
    log_path = artifact_dir / "current-runtime-validator-rejects-http-design.log"
    cmd = [
        sys.executable,
        str(validator),
        "--manifest",
        str(design_manifest),
        "--artifact-dir",
        str(artifact_dir / "runtime-validator-rejection"),
    ]
    proc = subprocess.run(cmd, cwd=str(repo_root()), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.write_text(proc.stdout, encoding="utf-8")
    return {
        "status": "PASS" if proc.returncode != 0 else "FAIL",
        "exitCode": proc.returncode,
        "cmd": " ".join(cmd),
        "log": str(log_path),
        "summary": "current runtime package validator rejected HTTP design manifest"
        if proc.returncode != 0 else
        "current runtime package validator unexpectedly accepted HTTP design manifest",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Koma design-only HTTP host import boundary.")
    parser.add_argument("--manifest", default="tools/wasm-runtime-spike/host-imports/http-boundary.example.json")
    parser.add_argument("--current-manifest", default="tools/wasm-runtime-spike/source-package/manifest.example.json")
    parser.add_argument("--artifact-dir", required=True)
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    current_manifest_path = Path(args.current_manifest).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    report_path = artifact_dir / "http-boundary-validation.json"

    report = {
        "status": "FAIL",
        "manifestPath": str(manifest_path),
        "artifactDir": str(artifact_dir),
        "designOnly": None,
        "runtimeEnabled": None,
        "networkPerformed": False,
        "evidence": [],
    }
    try:
        evidence = validate_design_manifest(manifest_path)
        report.update({
            "status": "PASS",
            "designOnly": evidence["designOnly"],
            "runtimeEnabled": evidence["runtimeEnabled"],
            "networkPerformed": evidence["networkPerformed"],
            "manifest": evidence,
        })
        network_false = validate_network_false_rejects_http(current_manifest_path)
        report["networkFalseHttpImportGate"] = network_false
        require(network_false["status"] == "PASS", "network=false HTTP import gate failed")
        runtime_rejection = run_runtime_validator_rejection(manifest_path, artifact_dir)
        report["currentRuntimeValidatorGate"] = runtime_rejection
        require(runtime_rejection["status"] == "PASS", "current runtime validator did not reject HTTP design")
        report["evidence"].extend([
            "design-only HTTP boundary manifest accepted by design validator",
            "report flags designOnly=true runtimeEnabled=false networkPerformed=false",
            "network=false manifest mutation with koma_host.http_request rejected",
            "current source-package validator rejected network=true/http_request design manifest",
            "validator performed no network I/O",
        ])
    except Exception as err:
        report["error"] = str(err)
        report["status"] = "FAIL"

    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
