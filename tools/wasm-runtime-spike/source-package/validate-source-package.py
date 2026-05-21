#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


SOURCE_ABI = "koma-source-abi-v0.1"
HOST_ABI = "koma-host-v0.1"
ALLOWED_IMPORTS = {("koma_host", "log"), ("koma_host", "check_cancel")}
REQUIRED_EXPORTS = {
    "add",
    "koma_source_init",
    "koma_source_search",
    "koma_source_get_manga",
    "koma_source_get_chapters",
    "koma_source_get_pages",
    "koma_source_free",
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
    require(runtime.get("hostAbi") == HOST_ABI, f"runtime.hostAbi must be {HOST_ABI}")
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
    require(declared_pairs == ALLOWED_IMPORTS, "requiredHostImports must be exactly koma_host.log/check_cancel")

    wasm_imports, wasm_exports = parse_wasm_imports_exports(wasm_path)
    wasm_import_set = set(wasm_imports)
    require(wasm_import_set == ALLOWED_IMPORTS, f"wasm imports must be exactly {sorted(ALLOWED_IMPORTS)}")
    require(REQUIRED_EXPORTS.issubset(set(wasm_exports)),
            "wasm exports missing required fixture functions")

    capabilities = manifest.get("capabilities")
    require(isinstance(capabilities, dict), "capabilities object is required")
    require(set(capabilities.keys()) == CAPABILITY_KEYS, "capabilities keys do not match fixture boundary")
    for key in ("search", "detail", "chapterList", "pageList"):
        require(capabilities.get(key) is True, f"fixture requires {key}=true")
    for key in CAPABILITY_KEYS - {"search", "detail", "chapterList", "pageList"}:
        require(capabilities.get(key) is False, f"fixture requires {key}=false")

    validate_settings_schema(manifest.get("settingsSchema"))

    permissions = manifest.get("permissions")
    require(isinstance(permissions, dict), "permissions object is required")
    require(permissions.get("network") is False, "fixture permissions.network must be false")
    require(permissions.get("hostImports") == ["koma_host.log", "koma_host.check_cancel"],
            "permissions.hostImports must match allowed imports")

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
        "capabilities": capabilities,
        "network": permissions["network"],
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
    log_path.write_text(proc.stdout, encoding="utf-8")
    result = {
        "cmd": f"KOMA_WASM_SPIKE_ARTIFACT_DIR={rust_artifact_dir} bash {script}",
        "exitCode": proc.returncode,
        "log": str(log_path),
    }
    if proc.returncode != 0:
        result["status"] = "FAIL"
        return result
    artifact_rel = build.get("artifactPath")
    require(isinstance(artifact_rel, str) and artifact_rel, "runtime.wasm.build.artifactPath is required")
    wasm_path = rust_artifact_dir / artifact_rel
    require(wasm_path.is_file(), f"built rust fixture wasm missing: {wasm_path}")
    imports, exports = parse_wasm_imports_exports(wasm_path)
    require(set(imports) == ALLOWED_IMPORTS, "built rust fixture imports drifted")
    require(REQUIRED_EXPORTS.issubset(set(exports)), "built rust fixture exports drifted")
    result.update({
        "status": "PASS",
        "wasmPath": str(wasm_path),
        "wasmSha256": sha256_file(wasm_path),
        "wasmSizeBytes": wasm_path.stat().st_size,
        "hostImports": sorted([f"{module}.{name}" for module, name in imports]),
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
            "imports constrained to koma_host.log and koma_host.check_cancel",
            "capabilities cover fixture search/detail/chapter/page operations",
            "network=false and no market/index/install scope fields",
        ])
        if args.build_rust_fixture:
            report["evidence"].append(
                f"rust fixture built at {rust_result['wasmPath']} sha256 {rust_result['wasmSha256']}"
            )
        else:
            report["rustFixtureBuild"] = rust_result
        report["status"] = "PASS"
    except Exception as err:
        report["error"] = str(err)
        report["status"] = "FAIL"

    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
