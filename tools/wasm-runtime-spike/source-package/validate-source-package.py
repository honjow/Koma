#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redacted_command, redact_text, redact_value, write_redacted_json  # noqa: E402


SOURCE_ABI = "koma-source-abi-v0.1"
HOST_ABI = "koma-host-v0.1"
FIXTURE_HTTP_HOST_ABI = "koma-host-v0.1-fixture-http"
FIXTURE_HTTP_HTML_HOST_ABI = "koma-host-v0.1-fixture-http-html"
ALLOWED_IMPORTS = {("koma_host", "log"), ("koma_host", "check_cancel")}
FIXTURE_HTTP_IMPORTS = ALLOWED_IMPORTS | {("koma_host", "http_request")}
FIXTURE_HTML_IMPORTS = {
    ("koma_host", "html_parse"),
    ("koma_host", "html_select"),
    ("koma_host", "html_attr"),
    ("koma_host", "html_text"),
    ("koma_host", "html_close"),
}
FIXTURE_HTTP_HTML_IMPORTS = FIXTURE_HTTP_IMPORTS | FIXTURE_HTML_IMPORTS
REQUIRED_EXPORTS = {
    "add",
    "koma_source_init",
    "koma_source_search",
    "koma_source_get_manga",
    "koma_source_get_chapters",
    "koma_source_get_pages",
    "koma_source_free",
}
OPTIONAL_EXPORTS = {"koma_source_info"}
OPTIONAL_BROWSE_EXPORTS = {
    "koma_source_get_listings",
    "koma_source_get_manga_list",
    "koma_source_get_home",
    "koma_source_get_filters",
}
CAPABILITY_KEYS = {"search", "detail", "chapterList", "pageList", "imageUrl"}
SCOPE_FORBIDDEN_KEYS = {
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
SECRET_WORDS = ("password", "token", "secret", "apikey", "apiKey", "cookie", "authorization")
FORBIDDEN_RUNTIME_STRINGS = (
    '"network": true',
    '"network":true',
    "http_request",
    "https://",
    "http://",
    "file://",
    "content://",
    "ohos://",
    "internal://",
    "app-private",
    "/home/",
    "/Users/",
    "/data/",
    "/storage/",
    "/sdcard/",
    ".hermes-artifacts",
    "password",
    "token",
    "secret",
    "apiKey",
    "cookie",
    "Authorization",
)


class ValidationError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def fail(message: str) -> None:
    raise ValidationError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve_package_path(manifest_path: Path, value: str) -> Path:
    require(isinstance(value, str) and value, "path must be a non-empty string")
    require("://" not in value, f"remote paths are not allowed: {value}")
    p = Path(value)
    if not p.is_absolute():
        p = manifest_path.parent / p
    resolved = p.resolve()
    root = repo_root().resolve()
    artifact_env = os.environ.get("KOMA_SOURCE_PACKAGE_ARTIFACT_DIR")
    allowed_roots = [root]
    if artifact_env:
        allowed_roots.append(Path(artifact_env).resolve())
    require(any(resolved == base or base in resolved.parents for base in allowed_roots),
            f"path escapes repo/artifact roots: {resolved}")
    return resolved


def read_u32_leb(data: bytes, offset: int) -> tuple[int, int]:
    result = 0
    shift = 0
    pos = offset
    while True:
        require(pos < len(data), "truncated leb128")
        b = data[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if (b & 0x80) == 0:
            return result, pos
        shift += 7
        require(shift <= 35, "leb128 value too large")


def read_name(data: bytes, offset: int) -> tuple[str, int]:
    length, pos = read_u32_leb(data, offset)
    require(pos + length <= len(data), "truncated wasm name")
    return data[pos:pos + length].decode("utf-8"), pos + length


def parse_wasm_imports_exports(path: Path) -> tuple[list[tuple[str, str]], list[str]]:
    data = path.read_bytes()
    require(data.startswith(b"\0asm\x01\0\0\0"), "wasm magic/version mismatch")
    imports: list[tuple[str, str]] = []
    exports: list[str] = []
    pos = 8
    while pos < len(data):
        section_id = data[pos]
        pos += 1
        size, pos = read_u32_leb(data, pos)
        end = pos + size
        require(end <= len(data), "truncated wasm section")
        section = data[pos:end]
        if section_id == 2:
            count, inner = read_u32_leb(section, 0)
            for _ in range(count):
                module, inner = read_name(section, inner)
                name, inner = read_name(section, inner)
                require(inner < len(section), "truncated wasm import descriptor")
                kind = section[inner]
                inner += 1
                if kind == 0:
                    _, inner = read_u32_leb(section, inner)
                elif kind == 1:
                    _, inner = read_u32_leb(section, inner)
                    limits_flag, inner = read_u32_leb(section, inner)
                    _, inner = read_u32_leb(section, inner)
                    if limits_flag & 1:
                        _, inner = read_u32_leb(section, inner)
                elif kind == 2:
                    limits_flag, inner = read_u32_leb(section, inner)
                    _, inner = read_u32_leb(section, inner)
                    if limits_flag & 1:
                        _, inner = read_u32_leb(section, inner)
                elif kind == 3:
                    _, inner = read_u32_leb(section, inner)
                    require(inner < len(section), "truncated global mutability")
                    inner += 1
                else:
                    fail(f"unknown wasm import kind {kind}")
                imports.append((module, name))
        elif section_id == 7:
            count, inner = read_u32_leb(section, 0)
            for _ in range(count):
                name, inner = read_name(section, inner)
                require(inner < len(section), "truncated wasm export descriptor")
                inner += 1
                _, inner = read_u32_leb(section, inner)
                exports.append(name)
        pos = end
    return imports, exports


def walk_forbidden_keys(value, path="$") -> list[str]:
    hits: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in SCOPE_FORBIDDEN_KEYS:
                hits.append(f"{path}.{key}")
            hits.extend(walk_forbidden_keys(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for i, child in enumerate(value):
            hits.extend(walk_forbidden_keys(child, f"{path}[{i}]"))
    return hits


def validate_settings_schema(schema: dict) -> None:
    require(isinstance(schema, dict), "settingsSchema must be an object")
    require(schema.get("type") == "object", "settingsSchema.type must be object")
    props = schema.get("properties", {})
    require(isinstance(props, dict), "settingsSchema.properties must be an object")
    for name, prop in props.items():
        lower = name.lower()
        require(not any(word.lower() in lower for word in SECRET_WORDS),
                f"credential-shaped setting is not allowed in fixture: {name}")
        if isinstance(prop, dict) and "default" in prop:
            default = prop["default"]
            require(not isinstance(default, str) or not any(word.lower() in default.lower() for word in SECRET_WORDS),
                    f"credential-shaped default is not allowed in fixture: {name}")


def validate_source_info_payload(payload: dict) -> dict:
    require(isinstance(payload, dict), "source_info payload must be an object")
    raw = json.dumps(payload, sort_keys=True)
    for forbidden in FORBIDDEN_RUNTIME_STRINGS:
        require(forbidden not in raw, f"source_info payload leaked forbidden runtime string: {forbidden}")

    require(payload.get("version") == 1, "source_info.version must be 1")
    require(payload.get("ok") is True, "source_info.ok must be true")
    require(payload.get("operation") == "source_info", "source_info.operation mismatch")
    require(payload.get("hostHints", {}).get("network") is False,
            "source_info hostHints.network must be false")
    data = payload.get("data")
    require(isinstance(data, dict), "source_info.data must be an object")
    info = data.get("sourceInfo")
    require(isinstance(info, dict), "source_info.data.sourceInfo must be an object")
    for key in ("id", "name", "version", "apiVersion", "language", "contentRating"):
        require(isinstance(info.get(key), str) and info[key],
                f"source_info.sourceInfo.{key} must be a non-empty string")
    require(info["id"] == "local.test.koma.fixture", "source_info source id drifted")
    require(info["version"] == "0.2.0", "source_info version drifted")
    require(info["apiVersion"] == "0.2", "source_info apiVersion drifted")

    capabilities = data.get("capabilities")
    require(isinstance(capabilities, dict), "source_info.capabilities must be an object")
    for key in ("search", "mangaDetail", "chapters", "pages"):
        require(capabilities.get(key) is True, f"source_info capability {key} must be true")
    browse = ("listings", "mangaList", "home", "filters")
    for key in browse:
        require(capabilities.get(key) is True, f"source_info capability {key} must be true")
    optional = ("settings", "imageRequest")
    for key in optional:
        require(capabilities.get(key) is False, f"source_info capability {key} must be false")
    future = capabilities.get("future")
    require(isinstance(future, dict), "source_info.capabilities.future must be an object")
    for key, value in future.items():
        require(value is False, f"source_info future capability {key} must be false")

    return {
        "sourceId": info["id"],
        "apiVersion": info["apiVersion"],
        "coreCapabilitiesTrue": ["search", "mangaDetail", "chapters", "pages"],
        "browseCapabilitiesTrue": list(browse),
        "optionalCapabilitiesFalse": list(optional),
        "futureCapabilitiesFalse": sorted(future.keys()),
        "network": False,
    }


def validate_runtime_operation_payloads(payloads: dict) -> dict:
    require(isinstance(payloads, dict), "runtime operation payload report must be an object")
    require("source_info" in payloads, "runtime smoke did not record source_info")
    source_info = validate_source_info_payload(payloads["source_info"])

    operations = (
        "search",
        "get_manga",
        "get_chapters",
        "get_pages",
        "get_listings",
        "get_manga_list",
        "get_home",
        "get_filters",
    )
    for operation in operations:
        payload = payloads.get(operation)
        require(isinstance(payload, dict), f"runtime smoke missing {operation} payload")
        require(payload.get("version") == 1, f"{operation}.version must be 1")
        require(payload.get("ok") is True, f"{operation}.ok must be true")
        require(payload.get("operation") == operation, f"{operation}.operation mismatch")
        require(isinstance(payload.get("data"), dict), f"{operation}.data must be an object")
        require(payload.get("hostHints", {}).get("network") is False,
                f"{operation} hostHints.network must be false")
    require(payloads["get_listings"]["data"]["listings"][0]["id"] == "listing:popular",
            "get_listings fixture id drifted")
    require(payloads["get_manga_list"]["data"]["listingId"] == "listing:popular",
            "get_manga_list listingId drifted")
    require(payloads["get_manga_list"]["data"]["page"]["nextCursor"] is None,
            "get_manga_list nextCursor must be null")
    require(payloads["get_manga_list"]["data"]["page"]["hasMore"] is False,
            "get_manga_list hasMore must be false")
    http_fixture = payloads.get("get_manga_list_http_fixture")
    require(isinstance(http_fixture, dict), "runtime smoke missing HTTP fixture manga list")
    require(http_fixture.get("ok") is True, "HTTP fixture manga list must be ok")
    require(http_fixture.get("operation") == "get_manga_list",
            "HTTP fixture manga list operation mismatch")
    require(http_fixture.get("hostHints", {}).get("network") is False,
            "HTTP fixture hostHints.network must remain false")
    require(http_fixture.get("data", {}).get("listingId") == "listing:http-fixture",
            "HTTP fixture listingId drifted")
    http_policy = http_fixture.get("data", {}).get("httpFixture")
    require(isinstance(http_policy, dict), "HTTP fixture policy evidence missing")
    require(http_policy.get("allowed") is True, "HTTP fixture allowed request missing")
    require(http_policy.get("deniedHost") == "host_not_allowed",
            "HTTP fixture denied host reason drifted")
    require(http_policy.get("deniedCredentialHeader") == "credential_header_denied",
            "HTTP fixture denied credential header reason drifted")
    require(http_policy.get("networkPerformed") is False,
            "HTTP fixture must not perform real network")
    html_fixture = payloads.get("get_manga_list_html_fixture")
    require(isinstance(html_fixture, dict), "runtime smoke missing HTML fixture manga list")
    require(html_fixture.get("ok") is True, "HTML fixture manga list must be ok")
    require(html_fixture.get("operation") == "get_manga_list",
            "HTML fixture manga list operation mismatch")
    require(html_fixture.get("hostHints", {}).get("network") is False,
            "HTML fixture hostHints.network must remain false")
    require(html_fixture.get("data", {}).get("listingId") == "listing:html-fixture",
            "HTML fixture listingId drifted")
    html_policy = html_fixture.get("data", {}).get("htmlFixture")
    require(isinstance(html_policy, dict), "HTML fixture policy evidence missing")
    for key in ("parse", "select", "attr", "text"):
        require(html_policy.get(key) is True, f"HTML fixture {key} evidence missing")
    require(html_policy.get("chapterId") == "chapter:html-fixture-series:001",
            "HTML fixture chapter id drifted")
    require(html_policy.get("chapterTitle") == "Chapter 1",
            "HTML fixture chapter text drifted")
    require(html_policy.get("pageId") == "page:html-fixture-series:001:0001",
            "HTML fixture page id drifted")
    require(html_policy.get("unsupportedSelectorDenied") == "unsupported_selector",
            "HTML fixture unsupported selector denial drifted")
    require(html_policy.get("unsupportedAttrDenied") == "attribute_not_allowed",
            "HTML fixture unsupported attr denial drifted")
    require(html_policy.get("networkPerformed") is False,
            "HTML fixture must not perform real network")
    require(payloads["get_home"]["data"]["sections"][0]["id"] == "home:featured",
            "get_home featured section drifted")
    require(payloads["get_filters"]["data"]["filters"][0]["id"] == "filter:query",
            "get_filters query filter drifted")

    rejected = payloads.get("unknown_operation_rejected")
    require(isinstance(rejected, dict), "runtime smoke missing unknown operation rejection")
    require(rejected.get("ok") is False, "unknown operation must reject")
    require(rejected.get("operation") == "search", "unknown operation rejection should stay on called export")
    require(rejected.get("error", {}).get("code") == "invalid_request",
            "unknown operation rejection code drifted")
    require("Fixture Series" not in json.dumps(rejected, sort_keys=True),
            "unknown operation defaulted to search data")

    return {
        "sourceInfo": source_info,
        "coreOperations": ["search", "get_manga", "get_chapters", "get_pages"],
        "browseOperations": ["get_listings", "get_manga_list", "get_home", "get_filters"],
        "unknownOperationRejected": True,
    }


def validate_manifest(manifest_path: Path, wasm_path_override: Path | None = None) -> dict:
    manifest = read_json(manifest_path)
    forbidden_hits = walk_forbidden_keys(manifest)
    require(not forbidden_hits, "forbidden source-market/plugin keys: " + ", ".join(forbidden_hits))
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")

    package = manifest.get("package")
    require(isinstance(package, dict), "package object is required")
    package_id = package.get("id")
    require(isinstance(package_id, str) and re.fullmatch(r"[a-z][a-z0-9]*(\.[a-z0-9][a-z0-9-]*){2,}", package_id or ""),
            "package.id must be reverse-DNS-like ASCII with at least three labels")
    require(len(package_id) <= 96, "package.id is too long")
    for key in ("name", "version", "language", "type", "author", "description"):
        require(isinstance(package.get(key), str) and package[key], f"package.{key} is required")
    require(package.get("nsfw") is False, "fixture package must declare nsfw=false")
    if package.get("icon"):
        icon_path = resolve_package_path(manifest_path, package["icon"])
        require(icon_path.is_file(), f"icon placeholder does not exist: {icon_path}")

    runtime = manifest.get("runtime")
    require(isinstance(runtime, dict), "runtime object is required")
    require(runtime.get("abi") == SOURCE_ABI, f"runtime.abi must be {SOURCE_ABI}")
    permissions = manifest.get("permissions")
    require(isinstance(permissions, dict), "permissions object is required")
    experimental_http = permissions.get("experimentalHttpFixture")
    http_fixture_enabled = isinstance(experimental_http, dict) and experimental_http.get("enabled") is True
    experimental_html = permissions.get("experimentalHtmlFixture")
    html_fixture_enabled = isinstance(experimental_html, dict) and experimental_html.get("enabled") is True
    expected_host_abi = FIXTURE_HTTP_HTML_HOST_ABI if html_fixture_enabled else \
        (FIXTURE_HTTP_HOST_ABI if http_fixture_enabled else HOST_ABI)
    require(runtime.get("hostAbi") == expected_host_abi, f"runtime.hostAbi must be {expected_host_abi}")
    wasm = runtime.get("wasm")
    require(isinstance(wasm, dict), "runtime.wasm object is required")
    wasm_path = wasm_path_override if wasm_path_override else resolve_package_path(manifest_path, wasm.get("path"))
    require(wasm_path.is_file(), f"wasm file does not exist: {wasm_path}")
    wasm_size = wasm_path.stat().st_size
    limits = runtime.get("limits")
    require(isinstance(limits, dict), "runtime.limits object is required")
    require(limits.get("maxMemoryPages") == 2, "fixture maxMemoryPages must be 2")
    require(limits.get("maxPayloadBytes") == 1048576, "fixture maxPayloadBytes must be 1048576")
    require(isinstance(limits.get("maxWasmBytes"), int) and limits["maxWasmBytes"] > 0,
            "runtime.limits.maxWasmBytes must be a positive integer")
    require(wasm_size <= limits["maxWasmBytes"], "wasm exceeds maxWasmBytes")
    actual_sha = sha256_file(wasm_path)
    if wasm_path_override is None:
        require(wasm.get("sha256") == actual_sha, "runtime.wasm.sha256 does not match resolved wasm")

    declared_imports = runtime.get("requiredHostImports")
    require(isinstance(declared_imports, list) and declared_imports, "requiredHostImports must be non-empty")
    declared_pairs = {(item.get("module"), item.get("name")) for item in declared_imports if isinstance(item, dict)}
    allowed_imports = FIXTURE_HTTP_HTML_IMPORTS if html_fixture_enabled else \
        (FIXTURE_HTTP_IMPORTS if http_fixture_enabled else ALLOWED_IMPORTS)
    require(declared_pairs == allowed_imports,
            "requiredHostImports must match the active fixture host import policy")

    wasm_imports, wasm_exports = parse_wasm_imports_exports(wasm_path)
    wasm_import_set = set(wasm_imports)
    require(wasm_import_set == allowed_imports,
            f"wasm imports must match active policy {sorted(allowed_imports)}")
    require(REQUIRED_EXPORTS.issubset(set(wasm_exports)),
            "wasm exports missing required fixture functions")
    optional_exports = sorted(set(wasm_exports) & (OPTIONAL_EXPORTS | OPTIONAL_BROWSE_EXPORTS))

    capabilities = manifest.get("capabilities")
    require(isinstance(capabilities, dict), "capabilities object is required")
    require(set(capabilities.keys()) == CAPABILITY_KEYS, "capabilities keys do not match fixture boundary")
    for key in ("search", "detail", "chapterList", "pageList"):
        require(capabilities.get(key) is True, f"fixture requires {key}=true")
    for key in CAPABILITY_KEYS - {"search", "detail", "chapterList", "pageList"}:
        require(capabilities.get(key) is False, f"fixture requires {key}=false")

    validate_settings_schema(manifest.get("settingsSchema"))

    require(permissions.get("network") is False, "fixture permissions.network must be false")
    expected_permission_imports = ["koma_host.log", "koma_host.check_cancel"]
    if http_fixture_enabled:
        require(experimental_http.get("allowedHost") == "fixture.koma.local",
                "experimentalHttpFixture.allowedHost must be fixture.koma.local")
        require(experimental_http.get("networkPerformed") is False,
                "experimentalHttpFixture.networkPerformed must be false")
        require(experimental_http.get("allowedMethods") == ["GET"],
                "experimentalHttpFixture.allowedMethods must be GET only")
        require(experimental_http.get("responseKinds") == ["bodyJson", "bodyText"],
                "experimentalHttpFixture.responseKinds must be bodyJson/bodyText")
        expected_permission_imports.append("koma_host.http_request")
    if html_fixture_enabled:
        require(http_fixture_enabled, "experimentalHtmlFixture requires experimentalHttpFixture in S6")
        require(experimental_html.get("networkPerformed") is False,
                "experimentalHtmlFixture.networkPerformed must be false")
        require(experimental_html.get("selectorSubset") == [
            "article.manga-card", "h3.title", "a.chapter",
        ], "experimentalHtmlFixture.selectorSubset drifted")
        require(experimental_html.get("allowedAttributes") == ["data-id", "data-page-id"],
                "experimentalHtmlFixture.allowedAttributes drifted")
        require(experimental_html.get("maxHtmlBytes") == 4096,
                "experimentalHtmlFixture.maxHtmlBytes must be 4096")
        require(experimental_html.get("maxStringBytes") == 512,
                "experimentalHtmlFixture.maxStringBytes must be 512")
        expected_permission_imports.extend([
            "koma_host.html_parse",
            "koma_host.html_select",
            "koma_host.html_attr",
            "koma_host.html_text",
            "koma_host.html_close",
        ])
    require(permissions.get("hostImports") == expected_permission_imports,
            "permissions.hostImports must match active fixture imports")

    content_policy = manifest.get("contentPolicy")
    require(isinstance(content_policy, dict), "contentPolicy object is required")
    for key in ("publicIndex", "marketplace", "builtInSource", "remoteInstall"):
        require(content_policy.get(key) is False, f"contentPolicy.{key} must be false")

    return {
        "manifest": str(manifest_path),
        "packageId": package_id,
        "wasmPath": str(wasm_path),
        "wasmSha256": actual_sha,
        "wasmSizeBytes": wasm_size,
        "abi": runtime["abi"],
        "hostAbi": runtime["hostAbi"],
        "hostImports": sorted([f"{module}.{name}" for module, name in wasm_import_set]),
        "exports": sorted([name for name in wasm_exports if name in REQUIRED_EXPORTS]),
        "optionalExports": optional_exports,
        "sourceInfoExport": "koma_source_info" in optional_exports,
        "capabilities": capabilities,
        "network": permissions["network"],
        "experimentalHttpFixture": http_fixture_enabled,
        "experimentalHtmlFixture": html_fixture_enabled,
    }


def run_rust_fixture(manifest_path: Path, artifact_dir: Path, manifest: dict) -> dict:
    build = manifest["runtime"]["wasm"].get("build", {})
    script = resolve_package_path(manifest_path, build.get("script"))
    require(script.is_file(), f"rust fixture script does not exist: {script}")
    rust_artifact_dir = artifact_dir / "rust-fixture"
    env = os.environ.copy()
    env["KOMA_WASM_SPIKE_ARTIFACT_DIR"] = str(rust_artifact_dir)
    env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
    proc = subprocess.run(["bash", str(script)], cwd=str(repo_root()), env=env,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path = artifact_dir / "run-rust-fixture-from-package-validator.log"
    log_path.write_text(redact_text(proc.stdout), encoding="utf-8")
    result = {
        "cmd": redacted_command(["bash", str(script)], {"KOMA_WASM_SPIKE_ARTIFACT_DIR": str(rust_artifact_dir)}),
        "exitCode": proc.returncode,
        "log": redact_text(str(log_path)),
    }
    if proc.returncode != 0:
        result["status"] = "FAIL"
        return result
    artifact_rel = build.get("artifactPath")
    require(isinstance(artifact_rel, str) and artifact_rel, "runtime.wasm.build.artifactPath is required")
    wasm_path = rust_artifact_dir / artifact_rel
    require(wasm_path.is_file(), f"built rust fixture wasm missing: {wasm_path}")
    imports, exports = parse_wasm_imports_exports(wasm_path)
    permissions = manifest["permissions"]
    http_fixture_enabled = isinstance(permissions.get("experimentalHttpFixture"), dict) and \
        permissions["experimentalHttpFixture"].get("enabled") is True
    html_fixture_enabled = isinstance(permissions.get("experimentalHtmlFixture"), dict) and \
        permissions["experimentalHtmlFixture"].get("enabled") is True
    allowed_imports = FIXTURE_HTTP_HTML_IMPORTS if html_fixture_enabled else \
        (FIXTURE_HTTP_IMPORTS if http_fixture_enabled else ALLOWED_IMPORTS)
    require(set(imports) == allowed_imports, "built rust fixture imports drifted")
    require(REQUIRED_EXPORTS.issubset(set(exports)), "built rust fixture exports drifted")
    require(OPTIONAL_BROWSE_EXPORTS.issubset(set(exports)),
            "built rust fixture missing browse operation exports")
    optional_exports = sorted(set(exports) & (OPTIONAL_EXPORTS | OPTIONAL_BROWSE_EXPORTS))
    payload_path = rust_artifact_dir / "rust-source-operation-results.json"
    require(payload_path.is_file(), f"rust fixture runtime JSON evidence missing: {payload_path}")
    runtime_evidence = validate_runtime_operation_payloads(read_json(payload_path))
    result.update({
        "status": "PASS",
        "wasmPath": str(wasm_path),
        "wasmSha256": sha256_file(wasm_path),
        "wasmSizeBytes": wasm_path.stat().st_size,
        "hostImports": sorted([f"{module}.{name}" for module, name in imports]),
        "optionalExports": optional_exports,
        "sourceInfoExport": "koma_source_info" in optional_exports,
        "runtimeEvidence": runtime_evidence,
    })
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Koma local/test WASM source package manifest.")
    parser.add_argument("--manifest", default="tools/wasm-runtime-spike/source-package/manifest.example.json")
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--build-rust-fixture", action="store_true")
    args = parser.parse_args()

    manifest_path = Path(args.manifest).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    os.environ["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
    report_path = artifact_dir / "source-package-validation.json"

    report = {
        "status": "FAIL",
        "manifestPath": str(manifest_path),
        "artifactDir": str(artifact_dir),
        "evidence": [],
    }
    try:
        rust_result = {"status": "NOT_RUN"}
        wasm_path_override = None
        if args.build_rust_fixture:
            rust_result = run_rust_fixture(manifest_path, artifact_dir, read_json(manifest_path))
            report["rustFixtureBuild"] = rust_result
            require(rust_result.get("status") == "PASS", "rust fixture build/run failed")
            wasm_path_override = Path(rust_result["wasmPath"])

        manifest_evidence = validate_manifest(manifest_path, wasm_path_override)
        report["manifest"] = manifest_evidence
        report["evidence"].extend([
            f"manifest package id {manifest_evidence['packageId']} accepted",
            f"wasm sha256 {manifest_evidence['wasmSha256']} size {manifest_evidence['wasmSizeBytes']} bytes",
            "imports constrained to the active fixture host import policy",
            "capabilities cover fixture search/detail/chapter/page operations",
            "optional source_info and browse exports accepted by static wasm validation",
            "network=false, experimental HTTP fixture gate explicit, and no market/index/install scope fields",
        ])
        if args.build_rust_fixture:
            runtime_evidence = rust_result["runtimeEvidence"]
            report["evidence"].append(
                f"rust fixture built at {rust_result['wasmPath']} sha256 {rust_result['wasmSha256']}"
            )
            report["evidence"].append(
                "runtime source_info validated with core/browse capabilities true, config/image/future capabilities false, and network=false"
            )
            report["evidence"].append(
            "runtime HTTP fixture validated allowed static host request, denied host, denied credential header, and networkPerformed=false"
            )
            report["evidence"].append(
                "runtime HTML fixture validated parse/select/attr/text, denied unsupported selector/attr, and networkPerformed=false"
            )
            report["sourceInfoRuntimeEvidence"] = runtime_evidence
        else:
            report["rustFixtureBuild"] = rust_result
            report["evidence"].append(
                "static-only mode records optional koma_source_info export presence; run with --build-rust-fixture for functional metadata/capability proof"
            )
        report["status"] = "PASS"
    except Exception as err:
        report["error"] = str(err)
        report["status"] = "FAIL"

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
