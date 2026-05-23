#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from redaction import redacted_command, redact_text, redact_value, write_redacted_json  # noqa: E402


HOST_ABI = "koma-host-v0.1-fixture-http-html"
HOST_IMPORTS = [
    "koma_host.log",
    "koma_host.check_cancel",
    "koma_host.http_request",
    "koma_host.html_parse",
    "koma_host.html_select",
    "koma_host.html_attr",
    "koma_host.html_text",
    "koma_host.html_close",
]
WAMR_TAG = "WAMR-2.3.0"
WAMR_COMMIT = "c7b2db18329f849b81568b94e72ddd0b20f431a5"
CONTENT_POLICY_KEYS = ("publicIndex", "marketplace", "builtInSource", "remoteInstall")
EXPECTED_OPERATIONS = (
    "search",
    "get_manga",
    "get_chapters",
    "get_pages",
    "get_listings",
    "get_manga_list",
    "get_home",
    "get_filters",
    "get_settings",
    "get_image_request",
)
SURFACE_FORBIDDEN_TOKENS = (
    "https://", "http://", "file://", "content://", "ohos://", "internal://",
    "app-private", "/home/", "/Users/", "/data/", "/storage/", "/sdcard/",
    ".hermes-artifacts", "password", "token", "secret", "apiKey", "cookie",
    "Authorization", "BEGIN PRIVATE KEY", "BEGIN RSA PRIVATE KEY",
    ".p12", ".cer", ".p7b", "credential",
)


class SmokeError(Exception):
    pass


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeError(message)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(redact_value(payload), indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def command_text(cmd: list[str], env_prefix: dict[str, str] | None = None) -> str:
    return redacted_command(cmd, env_prefix)


def run_command(cmd: list[str], *, cwd: Path, env: dict[str, str], log_path: Path,
                report: dict, summary: str, env_prefix: dict[str, str] | None = None) -> dict:
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(redact_text(proc.stdout), encoding="utf-8")
    result = {
        "cmd": command_text(cmd, env_prefix),
        "exitCode": proc.returncode,
        "log": str(log_path),
        "summary": summary,
    }
    report["commands"].append(result)
    return result


def extract_operation_json(output: str) -> dict[str, dict]:
    payloads: dict[str, dict] = {}
    for line in output.splitlines():
        if line.startswith("SOURCE_API_JSON "):
            name, raw = line[len("SOURCE_API_JSON "):].split("=", 1)
            payloads[name] = json.loads(raw)
    require(payloads, "host runner did not print SOURCE_API_JSON evidence")
    return payloads


def build_or_accept_archive(args: argparse.Namespace, artifact_dir: Path, env: dict[str, str], report: dict) -> Path:
    if args.archive:
        archive_path = Path(args.archive).resolve()
        require(archive_path.is_file(), f"archive does not exist: {archive_path}")
        return archive_path

    package_artifact_dir = artifact_dir / "archive-package"
    package_script = repo_root() / "tools/wasm-runtime-spike/source-package/package-source-archive.py"
    result = run_command(
        [
            "python3",
            str(package_script),
            "--artifact-dir",
            str(package_artifact_dir),
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "package-source-archive.log",
        report=report,
        summary="Build SDK-backed local .koma-source.zip archive",
    )
    require(result["exitCode"] == 0, "package-source-archive.py failed")
    archive_path = package_artifact_dir / "archive" / "local.test.koma.fixture.koma-source.zip"
    require(archive_path.is_file(), f"generated archive missing: {archive_path}")
    return archive_path


def validate_and_extract_archive(archive_path: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> tuple[Path, Path, dict]:
    validation_dir = artifact_dir / "archive-validation"
    validation_report_path = validation_dir / "source-package-archive-validation-report.json"
    package_script = repo_root() / "tools/wasm-runtime-spike/source-package/package-source-archive.py"
    result = run_command(
        [
            "python3",
            str(package_script),
            "--artifact-dir",
            str(validation_dir),
            "--validate-archive",
            str(archive_path),
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "validate-source-archive.log",
        report=report,
        summary="Validate and extract local source archive",
    )
    require(result["exitCode"] == 0, "archive validate-only path failed")
    validation_report = read_json(validation_report_path)
    require(validation_report.get("status") == "PASS", "archive validation report did not pass")

    extract_dir = validation_dir / "archive-extracted"
    manifest_path = extract_dir / "manifest.generated.json"
    require(manifest_path.is_file(), f"extracted manifest missing: {manifest_path}")
    manifest = read_json(manifest_path)
    wasm_path = (manifest_path.parent / manifest["runtime"]["wasm"]["path"]).resolve()
    require(wasm_path.is_file(), f"extracted wasm missing: {wasm_path}")
    return manifest_path, wasm_path, validation_report


def manifest_gates(manifest_path: Path, wasm_path: Path) -> list[dict]:
    manifest = read_json(manifest_path)
    runtime = manifest.get("runtime", {})
    permissions = manifest.get("permissions", {})
    content_policy = manifest.get("contentPolicy", {})
    wasm = runtime.get("wasm", {})
    wasm_sha = sha256_file(wasm_path)
    wasm_size = wasm_path.stat().st_size
    required_imports = [
        f"{item.get('module')}.{item.get('name')}"
        for item in runtime.get("requiredHostImports", [])
        if isinstance(item, dict)
    ]
    gates = [
        {"name": "network", "status": "PASS" if permissions.get("network") is False else "FAIL",
         "value": permissions.get("network")},
        {"name": "hostAbi", "status": "PASS" if runtime.get("hostAbi") == HOST_ABI else "FAIL",
         "value": runtime.get("hostAbi")},
        {"name": "requiredHostImports", "status": "PASS" if required_imports == HOST_IMPORTS else "FAIL",
         "value": required_imports},
        {"name": "permissionsHostImports", "status": "PASS" if permissions.get("hostImports") == HOST_IMPORTS else "FAIL",
         "value": permissions.get("hostImports")},
        {"name": "wasmSha256", "status": "PASS" if wasm.get("sha256") == wasm_sha else "FAIL",
         "value": wasm.get("sha256"), "actual": wasm_sha},
        {"name": "wasmSize", "status": "PASS" if wasm_size <= runtime.get("limits", {}).get("maxWasmBytes", 0) else "FAIL",
         "value": wasm_size, "limit": runtime.get("limits", {}).get("maxWasmBytes")},
    ]
    for key in CONTENT_POLICY_KEYS:
        gates.append({
            "name": key,
            "status": "PASS" if content_policy.get(key) is False else "FAIL",
            "value": content_policy.get(key),
        })
    return gates


def ensure_wamr_checkout(wamr_root: Path, env: dict[str, str], report: dict, artifact_dir: Path) -> None:
    require(shutil.which("git") is not None, "missing required tool: git")
    if not (wamr_root / ".git").is_dir():
        result = run_command(
            ["git", "clone", "--depth", "1", "--branch", WAMR_TAG,
             "https://github.com/bytecodealliance/wasm-micro-runtime.git", str(wamr_root)],
            cwd=repo_root(),
            env=env,
            log_path=artifact_dir / "logs" / "wamr-clone.log",
            report=report,
            summary=f"Fetch ignored WAMR {WAMR_TAG} cache",
        )
        require(result["exitCode"] == 0, "WAMR clone failed")
    result = run_command(
        ["git", "-C", str(wamr_root), "rev-parse", "HEAD"],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "wamr-rev-parse.log",
        report=report,
        summary="Verify WAMR cache commit",
    )
    require(result["exitCode"] == 0, "WAMR rev-parse failed")
    actual_commit = Path(result["log"]).read_text(encoding="utf-8").strip()
    require(actual_commit == WAMR_COMMIT, f"WAMR commit mismatch: expected {WAMR_COMMIT} got {actual_commit}")


def _surface_base(payload: dict) -> dict:
    return {
        "operation": payload["operation"],
        "ok": payload["ok"],
        "version": payload["version"],
        "hostHintsNetwork": payload["hostHints"]["network"],
    }


def _surface_search(payload: dict) -> dict:
    data = payload.get("data", {})
    items = data.get("items", [])
    first = items[0] if items else {}
    return {
        "itemCount": len(items),
        "firstItemTitle": first.get("title"),
        "hasFirstItemId": bool(first.get("id")),
        "page": {
            "hasMore": bool(data.get("page", {}).get("hasMore")),
            "hasNextCursor": data.get("page", {}).get("nextCursor") is not None,
        },
    }


def _surface_get_manga(payload: dict) -> dict:
    manga = payload.get("data", {}).get("manga", {})
    return {
        "hasMangaId": bool(manga.get("id")),
        "title": manga.get("title"),
        "contentRating": manga.get("contentRating"),
        "status": manga.get("status"),
        "language": manga.get("language"),
        "tagsCount": len(manga.get("tags", [])),
    }


def _surface_get_chapters(payload: dict) -> dict:
    data = payload.get("data", {})
    items = data.get("items", [])
    first = items[0] if items else {}
    return {
        "itemCount": len(items),
        "firstChapterTitle": first.get("title"),
        "firstChapterPageCount": first.get("pageCount"),
        "page": {
            "hasMore": bool(data.get("page", {}).get("hasMore")),
            "hasNextCursor": data.get("page", {}).get("nextCursor") is not None,
        },
    }


def _surface_get_pages(payload: dict) -> dict:
    data = payload.get("data", {})
    pages = data.get("pages", [])
    first = pages[0] if pages else {}
    image = first.get("image", {}) if isinstance(first, dict) else {}
    return {
        "pageCount": len(pages),
        "hasChapterId": bool(data.get("chapterId")),
        "firstImageKind": image.get("kind"),
    }


def _surface_get_listings(payload: dict) -> dict:
    listings = payload.get("data", {}).get("listings", [])
    return {
        "listingCount": len(listings),
        "kinds": sorted({entry.get("kind") for entry in listings if entry.get("kind")}),
    }


def _surface_get_manga_list(payload: dict) -> dict:
    data = payload.get("data", {})
    items = data.get("items", [])
    first = items[0] if items else {}
    return {
        "hasListingId": bool(data.get("listingId")),
        "itemCount": len(items),
        "firstItemTitle": first.get("title"),
        "page": {
            "hasMore": bool(data.get("page", {}).get("hasMore")),
            "hasNextCursor": data.get("page", {}).get("nextCursor") is not None,
        },
    }


def _surface_get_home(payload: dict) -> dict:
    sections = payload.get("data", {}).get("sections", [])
    return {
        "sectionCount": len(sections),
        "kinds": sorted({section.get("kind") for section in sections if section.get("kind")}),
    }


def _surface_get_filters(payload: dict) -> dict:
    filters = payload.get("data", {}).get("filters", [])
    return {
        "filterCount": len(filters),
        "kinds": sorted({entry.get("kind") for entry in filters if entry.get("kind")}),
    }


def _surface_get_settings(payload: dict) -> dict:
    settings = payload.get("data", {}).get("settings", [])
    return {
        "settingCount": len(settings),
        "kinds": sorted({entry.get("kind") for entry in settings if entry.get("kind")}),
    }


def _surface_get_image_request(payload: dict) -> dict:
    image_request = payload.get("data", {}).get("imageRequest", {})
    return {
        "hasImageRequestId": bool(image_request.get("id")),
        "method": image_request.get("method"),
        "hasHeaderOrTransportRef": bool(
            image_request.get("headersRef") or image_request.get("transport-fieldsRef")
        ),
        "hasProtectedRef": bool(image_request.get("credentialsRef")),
        "hasSessionRef": bool(image_request.get("sessionRef")),
        "hasResourceRef": bool(image_request.get("resourceRef")),
        "hasCacheKey": bool(image_request.get("cacheKey")),
        "requiresAuth": image_request.get("requiresAuth"),
    }


SURFACE_BUILDERS = {
    "search": _surface_search,
    "get_manga": _surface_get_manga,
    "get_chapters": _surface_get_chapters,
    "get_pages": _surface_get_pages,
    "get_listings": _surface_get_listings,
    "get_manga_list": _surface_get_manga_list,
    "get_home": _surface_get_home,
    "get_filters": _surface_get_filters,
    "get_settings": _surface_get_settings,
    "get_image_request": _surface_get_image_request,
}


def build_operation_surface(operation_payloads: dict[str, dict], operations: list[str]) -> dict:
    entries = []
    for name in operations:
        payload = operation_payloads[name]
        entry = _surface_base(payload)
        entry["surface"] = SURFACE_BUILDERS[name](payload)
        entries.append(entry)
    require(all(entry["ok"] is True for entry in entries),
            "operation surface entries are not all ok:true")
    require(all(entry["version"] == 1 for entry in entries),
            "operation surface entries are not all version 1")
    require(all(entry["hostHintsNetwork"] is False for entry in entries),
            "operation surface entries leaked hostHints.network=true")
    require(sorted(entry["operation"] for entry in entries) == sorted(operations),
            "operation surface entries do not match expected operations")
    surface = {
        "version": 1,
        "scope": "wasm-runtime-spike archive smoke runtime operation surface evidence",
        "operationCount": len(entries),
        "operations": entries,
    }
    raw = json.dumps(surface, sort_keys=True)
    raw_lower = raw.lower()
    leaked = [token for token in SURFACE_FORBIDDEN_TOKENS if token.lower() in raw_lower]
    require(not leaked, f"operation surface leaked forbidden tokens: {leaked}")
    return surface


def run_extracted_wasm(wasm_path: Path, artifact_dir: Path, env: dict[str, str], report: dict) -> dict:
    require(shutil.which("cmake") is not None, "missing required tool: cmake")
    host_artifact_dir = artifact_dir / "host-runner"
    host_build_dir = host_artifact_dir / "build" / "host"
    wamr_root = Path(env.get("WAMR_ROOT_DIR", host_artifact_dir / "cache" / "wasm-micro-runtime")).resolve()
    ensure_wamr_checkout(wamr_root, env, report, artifact_dir)

    cmake_configure = run_command(
        [
            "cmake",
            "-S",
            str(repo_root() / "tools/wasm-runtime-spike/host"),
            "-B",
            str(host_build_dir),
            f"-DWAMR_ROOT_DIR={wamr_root}",
            "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
        ],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-cmake-configure.log",
        report=report,
        summary="Configure existing WAMR host runner",
    )
    require(cmake_configure["exitCode"] == 0, "host runner CMake configure failed")

    cmake_build = run_command(
        ["cmake", "--build", str(host_build_dir), "--target", "koma_wamr_spike", "--parallel"],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-cmake-build.log",
        report=report,
        summary="Build existing WAMR host runner",
    )
    require(cmake_build["exitCode"] == 0, "host runner CMake build failed")

    host_binary = host_build_dir / "koma_wamr_spike"
    require(host_binary.is_file(), f"host runner binary missing: {host_binary}")
    run_result = run_command(
        [str(host_binary), str(wasm_path)],
        cwd=repo_root(),
        env=env,
        log_path=artifact_dir / "logs" / "host-run-extracted-wasm.log",
        report=report,
        summary="Run extracted archive wasm through WAMR host runner",
    )
    require(run_result["exitCode"] == 0, "extracted wasm host run failed")
    output = Path(run_result["log"]).read_text(encoding="utf-8")
    operation_payloads = extract_operation_json(output)
    expected_operations = list(EXPECTED_OPERATIONS)
    require("WAMR_SPIKE_PASS" in output, "missing WAMR_SPIKE_PASS")
    require("SOURCE_API_RUNTIME_SMOKE_PASS" in output, "missing SOURCE_API_RUNTIME_SMOKE_PASS")
    for operation in expected_operations:
        require(f"SOURCE_API_OPERATION {operation} ok:true" in output,
                f"missing SOURCE_API_OPERATION {operation} ok:true")
        payload = operation_payloads.get(operation)
        require(isinstance(payload, dict), f"missing {operation} JSON payload")
        require(payload.get("version") == 1, f"{operation} JSON version was not 1")
        require(payload.get("ok") is True, f"{operation} JSON ok was not true")
        require(payload.get("operation") == operation, f"{operation} JSON operation mismatch")
        require(isinstance(payload.get("data"), dict), f"{operation} JSON missing data")
        require(payload.get("hostHints", {}).get("network") is False,
                f"{operation} JSON hostHints.network was not false")
    items = operation_payloads["search"].get("data", {}).get("items", [])
    require(items and items[0].get("title") == "Fixture Series", "missing Fixture Series search evidence")
    require("HOST_LOG level=1" in output and "rust fixture init reached host imports" in output,
            "missing HOST_LOG import evidence")
    require("HOST_CHECK_CANCEL result=0" in output, "missing HOST_CHECK_CANCEL import evidence")
    require("hostHints.network=false" in output, "missing hostHints.network=false evidence")

    operation_json_path = artifact_dir / "extracted-wasm-operation-results.json"
    write_json(operation_json_path, operation_payloads)
    operation_surface = build_operation_surface(operation_payloads, expected_operations)
    return {
        "hostBinary": str(host_binary),
        "runLog": run_result["log"],
        "operationJson": str(operation_json_path),
        "operationsCovered": list(expected_operations),
        "operationSurface": operation_surface,
        "evidence": [
            "WAMR_SPIKE_PASS",
            "SOURCE_API_RUNTIME_SMOKE_PASS",
            *[f"SOURCE_API_OPERATION {op} ok:true" for op in expected_operations],
            "Fixture Series",
            "HOST_LOG rust fixture init reached host imports",
            "HOST_CHECK_CANCEL result=0",
            "hostHints.network=false",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate/extract a local .koma-source.zip and run its wasm through the Linux WAMR host runner."
    )
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--archive", help="Existing local .koma-source.zip to validate/extract and run.")
    parser.add_argument("--report", help="Report path. Defaults to <artifact-dir>/source-archive-wamr-smoke-report.json.")
    args = parser.parse_args()

    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "source-archive-wamr-smoke-report.json"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["KOMA_SOURCE_PACKAGE_ARTIFACT_DIR"] = str(artifact_dir)
    env.setdefault("WAMR_ROOT_DIR", str(artifact_dir / "cache" / "wasm-micro-runtime"))

    report = {
        "status": "FAIL",
        "artifactDir": str(artifact_dir),
        "archive": "",
        "extractedManifest": "",
        "extractedWasm": "",
        "commands": [],
        "manifestGates": [],
        "archiveValidationReport": "",
        "wamr": {},
        "operationsCovered": [],
        "operationSurface": {},
        "evidence": [],
    }

    try:
        archive_path = build_or_accept_archive(args, artifact_dir, env, report)
        manifest_path, wasm_path, archive_validation = validate_and_extract_archive(archive_path, artifact_dir, env, report)
        gates = manifest_gates(manifest_path, wasm_path)
        require(all(gate["status"] == "PASS" for gate in gates), "extracted manifest gates failed")
        wamr = run_extracted_wasm(wasm_path, artifact_dir, env, report)
        report.update({
            "status": "PASS",
            "archive": str(archive_path),
            "extractedManifest": str(manifest_path),
            "extractedWasm": str(wasm_path),
            "manifestGates": gates,
            "archiveValidationReport": str(artifact_dir / "archive-validation" / "source-package-archive-validation-report.json"),
            "wamr": wamr,
            "operationsCovered": wamr["operationsCovered"],
            "operationSurface": wamr["operationSurface"],
        })
        report["evidence"].extend([
            f"archive validated at {archive_path}",
            f"extracted manifest {manifest_path}",
            f"extracted wasm {wasm_path}",
            "manifest gates passed for network=false, hostAbi, host imports, wasm sha/size, and closed content policy",
            f"archive smoke covered {len(wamr['operationsCovered'])} v0.2 operations: {', '.join(wamr['operationsCovered'])}",
            *wamr["evidence"],
        ])
        if archive_validation.get("safety", {}).get("status") == "PASS":
            report["evidence"].append("archive safety gates passed before WAMR execution")
    except Exception as err:
        report["error"] = str(err)

    write_redacted_json(report_path, report)
    print(json.dumps(redact_value(report), indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
