#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


CORE_OPERATIONS = {"search", "get_manga", "get_chapters", "get_pages"}
NEXT_BROWSE_OPERATIONS = {"get_listings", "get_manga_list", "get_home", "get_filters"}
CONFIG_IMAGE_OPERATIONS = {"get_settings", "get_image_request"}
ALLOWED_OPERATIONS = CORE_OPERATIONS | NEXT_BROWSE_OPERATIONS | CONFIG_IMAGE_OPERATIONS
ALLOWED_IMAGE_KINDS = {"none", "placeholder", "imageRequest"}
FUTURE_DESIGN_ONLY_OPERATIONS = {
    "process_page_image",
    "page_description",
    "base_url",
    "login",
    "auth",
    "deeplink",
    "migration",
}
ID_FIELDS = {"id", "mangaId", "chapterId"}
PATH_LEAK_RE = re.compile(
    r"(^/home/|^/Users/|^/data/|^/storage/|^/sdcard/|^/mnt/|"
    r"^[A-Za-z]:\\|file://|content://|ohos://|internal://|app-private|"
    r"\.hermes-artifacts|/cache/|/files/|/Documents/)"
)
REMOTE_URL_RE = re.compile(r"https?://", re.IGNORECASE)
SECRET_RE = re.compile(
    r"(authorization|bearer\s+[a-z0-9._~+/=-]+|cookie|set-cookie|password|passwd|"
    r"access[_-]?token|refresh[_-]?token|api[_-]?key)",
    re.IGNORECASE,
)


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    require(isinstance(value, dict), "fixture root must be an object")
    return value


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_opaque_string(value: Any, field: str) -> None:
    require(isinstance(value, str) and value, f"{field} must be a non-empty opaque string")
    require(len(value) <= 256, f"{field} is too long")
    require("://" not in value and "/" not in value and "\\" not in value,
            f"{field} must not expose a URL or path-shaped structure")
    require(value.strip() == value, f"{field} must not have surrounding whitespace")


def validate_page_request(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    require(set(value.keys()).issubset({"cursor", "limit"}), f"{path} has unexpected fields")
    cursor = value.get("cursor")
    require(cursor is None or isinstance(cursor, str), f"{path}.cursor must be null or opaque string")
    if isinstance(cursor, str):
        validate_opaque_string(cursor, f"{path}.cursor")
    limit = value.get("limit")
    require(isinstance(limit, int) and not isinstance(limit, bool), f"{path}.limit must be an integer")
    require(1 <= limit <= 200, f"{path}.limit must be between 1 and 200")


def validate_page_info(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    require("hasMore" in value, f"{path}.hasMore is required")
    require(isinstance(value["hasMore"], bool), f"{path}.hasMore must be boolean")
    cursor = value.get("nextCursor")
    require(cursor is None or isinstance(cursor, str), f"{path}.nextCursor must be null or opaque string")
    if isinstance(cursor, str):
        validate_opaque_string(cursor, f"{path}.nextCursor")
    if "totalHint" in value:
        total = value["totalHint"]
        require(isinstance(total, int) and not isinstance(total, bool) and total >= 0,
                f"{path}.totalHint must be a non-negative integer")


def walk_response_strings(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            walk_response_strings(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk_response_strings(child, f"{path}[{index}]")
    elif isinstance(value, str):
        require(not PATH_LEAK_RE.search(value), f"{path} leaks a raw local/picker/app-private path")


def validate_host_hints(value: Any, path: str) -> bool:
    require(isinstance(value, dict), f"{path} must be an object")
    require(value.get("network") is False, f"{path}.network must be false for current fixtures")
    return False


def validate_common_envelope(payload: dict[str, Any]) -> tuple[str, bool]:
    require(payload.get("version") == 1, "version must be 1")
    operation = payload.get("operation")
    require(operation in ALLOWED_OPERATIONS,
            "operation must be a current Source API v0.2 fixture operation")
    network = validate_host_hints(payload.get("hostHints"), "hostHints")
    return operation, network


def validate_request(payload: dict[str, Any]) -> None:
    operation, _ = validate_common_envelope(payload)
    validate_opaque_string(payload.get("requestId"), "requestId")
    validate_opaque_string(payload.get("sourceId"), "sourceId")
    require(isinstance(payload.get("settings"), dict), "settings must be an object")
    args = payload.get("args")
    require(isinstance(args, dict), "args must be an object")
    if operation == "search":
        require(isinstance(args.get("query"), str), "args.query must be a string")
        validate_page_request(args.get("page"), "args.page")
        if "filters" in args:
            require(isinstance(args["filters"], dict), "args.filters must be an object")
    elif operation == "get_manga":
        validate_opaque_string(args.get("mangaId"), "args.mangaId")
    elif operation == "get_chapters":
        validate_opaque_string(args.get("mangaId"), "args.mangaId")
        validate_page_request(args.get("page"), "args.page")
    elif operation == "get_pages":
        validate_opaque_string(args.get("chapterId"), "args.chapterId")
    elif operation == "get_listings":
        require(args == {}, "get_listings args must be empty")
    elif operation == "get_manga_list":
        validate_opaque_string(args.get("listingId"), "args.listingId")
        validate_page_request(args.get("page"), "args.page")
        if "filters" in args:
            require(isinstance(args["filters"], dict), "args.filters must be an object")
    elif operation == "get_home":
        if "page" in args:
            validate_page_request(args["page"], "args.page")
    elif operation in {"get_filters", "get_settings"}:
        require(args == {}, f"{operation} args must be empty")
    elif operation == "get_image_request":
        validate_opaque_string(args.get("pageId"), "args.pageId")
        validate_opaque_string(args.get("imageRef"), "args.imageRef")


def validate_cover(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    kind = value.get("kind")
    require(kind in {"none", "placeholder"}, f"{path}.kind must be none/placeholder while network=false")


def validate_summary(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("title"), str) and value["title"], f"{path}.title is required")
    if "cover" in value:
        validate_cover(value["cover"], f"{path}.cover")


def validate_manga(value: Any, path: str) -> None:
    validate_summary(value, path)
    for field in ("alternateTitles", "authors", "artists", "tags", "links"):
        if field in value:
            require(isinstance(value[field], list), f"{path}.{field} must be an array")


def validate_chapter(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    validate_opaque_string(value.get("mangaId"), f"{path}.mangaId")
    require(isinstance(value.get("title"), str) and value["title"], f"{path}.title is required")
    for field in ("chapterNumber", "volumeNumber"):
        require(value.get(field) is None or isinstance(value.get(field), (str, int, float)),
                f"{path}.{field} must be null or number-ish metadata")
    if "pageCount" in value:
        require(isinstance(value["pageCount"], int) and not isinstance(value["pageCount"], bool) and value["pageCount"] >= 0,
                f"{path}.pageCount must be a non-negative integer")


def validate_image(value: Any, path: str, network: bool) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    kind = value.get("kind")
    require(kind in ALLOWED_IMAGE_KINDS, f"{path}.kind is not a known image descriptor kind")
    require(kind in {"none", "placeholder", "imageRequest"}, f"{path}.kind is not allowed in current fixtures")
    if kind == "imageRequest":
        validate_opaque_string(value.get("requestRef"), f"{path}.requestRef")
    for field in ("width", "height"):
        if field in value:
            require(isinstance(value[field], int) and not isinstance(value[field], bool) and value[field] > 0,
                    f"{path}.{field} must be a positive integer")


def validate_page_descriptor(value: Any, path: str, network: bool) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("index"), int) and not isinstance(value["index"], bool) and value["index"] >= 0,
            f"{path}.index must be a non-negative integer")
    validate_image(value.get("image"), f"{path}.image", network)


def validate_source_info(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("name"), str) and value["name"], f"{path}.name is required")
    require(isinstance(value.get("version"), str) and value["version"], f"{path}.version is required")
    if "apiVersion" in value:
        require(value["apiVersion"] == "0.2", f"{path}.apiVersion must be 0.2")
    for field in ("language", "author", "description", "contentRating"):
        if field in value:
            require(value[field] is None or isinstance(value[field], str), f"{path}.{field} must be a string or null")


def validate_capabilities(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    expected = {
        "search", "mangaDetail", "chapters", "pages", "listings", "mangaList",
        "home", "filters", "settings", "imageRequest",
    }
    require(expected.issubset(value.keys()), f"{path} must declare all v0.2 capability booleans")
    for key in expected:
        require(isinstance(value[key], bool), f"{path}.{key} must be boolean")
    if "future" in value:
        require(isinstance(value["future"], dict), f"{path}.future must be an object")
        for key in FUTURE_DESIGN_ONLY_OPERATIONS:
            if key in value["future"]:
                require(value["future"][key] is False, f"{path}.future.{key} must remain false")


def validate_metadata(payload: dict[str, Any]) -> None:
    require(payload.get("version") == 1, "version must be 1")
    validate_host_hints(payload.get("hostHints"), "hostHints")
    validate_source_info(payload.get("sourceInfo"), "sourceInfo")
    validate_capabilities(payload.get("capabilities"), "capabilities")


def validate_listing(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("name"), str) and value["name"], f"{path}.name is required")
    require(value.get("kind") in {"popular", "latest", "category", "custom"},
            f"{path}.kind must be popular/latest/category/custom")


def validate_filter(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("label"), str) and value["label"], f"{path}.label is required")
    kind = value.get("kind")
    require(kind in {"text", "sort", "check", "select", "multiSelect", "note", "range"},
            f"{path}.kind is not a known filter kind")
    if kind in {"sort", "select", "multiSelect"}:
        options = value.get("options")
        require(isinstance(options, list) and options, f"{path}.options must be a non-empty array")
        for index, option in enumerate(options):
            require(isinstance(option, dict), f"{path}.options[{index}] must be an object")
            validate_opaque_string(option.get("id"), f"{path}.options[{index}].id")
            require(isinstance(option.get("label"), str) and option["label"],
                    f"{path}.options[{index}].label is required")


def validate_setting(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("label"), str) and value["label"], f"{path}.label is required")
    kind = value.get("kind")
    require(kind in {"string", "number", "boolean", "select", "secretRef"},
            f"{path}.kind is not a known setting kind")
    require("password" not in value and "token" not in value and "authorization" not in value,
            f"{path} must not inline credential fields")
    if kind == "secretRef":
        validate_opaque_string(value.get("secretRefKey"), f"{path}.secretRefKey")
        require("default" not in value, f"{path}.default must not be present for secretRef")
    if kind == "select":
        require(isinstance(value.get("options"), list) and value["options"], f"{path}.options must be non-empty")


def validate_home_section(value: Any, path: str, network: bool) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    require(isinstance(value.get("title"), str) and value["title"], f"{path}.title is required")
    kind = value.get("kind")
    require(kind in {"mangaList", "listingLink"}, f"{path}.kind must be mangaList/listingLink")
    if kind == "mangaList":
        items = value.get("items")
        require(isinstance(items, list), f"{path}.items must be an array")
        for index, item in enumerate(items):
            validate_summary(item, f"{path}.items[{index}]")
    else:
        validate_opaque_string(value.get("listingId"), f"{path}.listingId")


def validate_image_request_descriptor(value: Any, path: str) -> None:
    require(isinstance(value, dict), f"{path} must be an object")
    validate_opaque_string(value.get("id"), f"{path}.id")
    validate_opaque_string(value.get("resourceRef"), f"{path}.resourceRef")
    require(value.get("method") in {"GET"}, f"{path}.method must be GET")
    headers = value.get("headers", [])
    require(isinstance(headers, list), f"{path}.headers must be an array")
    for index, header in enumerate(headers):
        require(isinstance(header, dict), f"{path}.headers[{index}] must be an object")
        name = header.get("name")
        require(isinstance(name, str) and name, f"{path}.headers[{index}].name is required")
        require(name.lower() not in {"authorization", "cookie", "set-cookie"},
                f"{path}.headers[{index}].name must not carry raw credentials")
        require(isinstance(header.get("value"), str), f"{path}.headers[{index}].value must be a string")
    require(isinstance(value.get("credentialRefs", []), list), f"{path}.credentialRefs must be an array")


def validate_response_data(operation: str, data: Any, network: bool) -> None:
    require(isinstance(data, dict), "data must be an object")
    if operation == "search":
        items = data.get("items")
        require(isinstance(items, list), "data.items must be an array")
        for index, item in enumerate(items):
            validate_summary(item, f"data.items[{index}]")
        validate_page_info(data.get("page"), "data.page")
    elif operation == "get_manga":
        validate_manga(data.get("manga"), "data.manga")
    elif operation == "get_chapters":
        items = data.get("items")
        require(isinstance(items, list), "data.items must be an array")
        for index, item in enumerate(items):
            validate_chapter(item, f"data.items[{index}]")
        validate_page_info(data.get("page"), "data.page")
    elif operation == "get_pages":
        validate_opaque_string(data.get("chapterId"), "data.chapterId")
        pages = data.get("pages")
        require(isinstance(pages, list), "data.pages must be an array")
        for index, page in enumerate(pages):
            validate_page_descriptor(page, f"data.pages[{index}]", network)
    elif operation == "get_listings":
        listings = data.get("listings")
        require(isinstance(listings, list), "data.listings must be an array")
        for index, listing in enumerate(listings):
            validate_listing(listing, f"data.listings[{index}]")
    elif operation == "get_manga_list":
        validate_opaque_string(data.get("listingId"), "data.listingId")
        items = data.get("items")
        require(isinstance(items, list), "data.items must be an array")
        for index, item in enumerate(items):
            validate_summary(item, f"data.items[{index}]")
        validate_page_info(data.get("page"), "data.page")
    elif operation == "get_home":
        sections = data.get("sections")
        require(isinstance(sections, list), "data.sections must be an array")
        for index, section in enumerate(sections):
            validate_home_section(section, f"data.sections[{index}]", network)
    elif operation == "get_filters":
        filters = data.get("filters")
        require(isinstance(filters, list), "data.filters must be an array")
        for index, filter_value in enumerate(filters):
            validate_filter(filter_value, f"data.filters[{index}]")
    elif operation == "get_settings":
        settings = data.get("settings")
        require(isinstance(settings, list), "data.settings must be an array")
        for index, setting in enumerate(settings):
            validate_setting(setting, f"data.settings[{index}]")
    elif operation == "get_image_request":
        validate_image_request_descriptor(data.get("imageRequest"), "data.imageRequest")


def validate_response(payload: dict[str, Any]) -> None:
    operation, network = validate_common_envelope(payload)
    require("ok" in payload and isinstance(payload["ok"], bool), "response ok boolean is required")
    walk_response_strings(payload)
    if payload["ok"]:
        require("data" in payload, "success response must include data")
        validate_response_data(operation, payload["data"], network)
    else:
        error = payload.get("error")
        require(isinstance(error, dict), "error response must include structured error")
        require(isinstance(error.get("code"), str) and error["code"], "error.code is required")


def validate_fixture(path: Path) -> dict[str, Any]:
    payload = read_json(path)
    fixture_type = payload.get("type")
    require(fixture_type in {"metadata", "request", "response"}, "type must be metadata/request/response")
    if fixture_type == "request":
        validate_request(payload)
    elif fixture_type == "response":
        validate_response(payload)
    else:
        validate_metadata(payload)
    scan_for_disallowed_strings(payload)
    return {
        "file": str(path),
        "type": fixture_type,
        "operation": payload.get("operation"),
        "status": "PASS",
    }


def scan_for_disallowed_strings(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            scan_for_disallowed_strings(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            scan_for_disallowed_strings(child, f"{path}[{index}]")
    elif isinstance(value, str):
        require(not PATH_LEAK_RE.search(value), f"{path} leaks a raw local/picker/app-private path")
        require(not REMOTE_URL_RE.search(value), f"{path} leaks a remote URL in current network=false fixtures")
        require(not SECRET_RE.search(value), f"{path} leaks raw credential-like material")


def collect_json_files(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Koma Source API v0.2 JSON envelope fixtures.")
    parser.add_argument("--fixture-dir", required=True)
    parser.add_argument("--artifact-dir", required=True)
    parser.add_argument("--report", help="Defaults to <artifact-dir>/source-api-fixtures-report.json.")
    args = parser.parse_args()

    fixture_dir = Path(args.fixture_dir).resolve()
    artifact_dir = Path(args.artifact_dir).resolve()
    report_path = Path(args.report).resolve() if args.report else artifact_dir / "source-api-fixtures-report.json"
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
        valid_files = collect_json_files(fixture_dir / "valid")
        invalid_files = collect_json_files(fixture_dir / "invalid")

        for path in valid_files:
            try:
                case = validate_fixture(path)
                case["expected"] = "accept"
                report["validCases"] += 1
            except Exception as err:
                case = {
                    "file": str(path),
                    "expected": "accept",
                    "status": "FAIL",
                    "reason": str(err),
                }
            report["cases"].append(case)

        for path in invalid_files:
            try:
                validate_fixture(path)
                case = {
                    "file": str(path),
                    "expected": "reject",
                    "status": "FAIL",
                    "reason": "invalid fixture was accepted",
                }
            except Exception as err:
                case = {
                    "file": str(path),
                    "expected": "reject",
                    "status": "PASS",
                    "reason": str(err),
                }
                report["invalidCases"] += 1
            report["cases"].append(case)

        failing = [case for case in report["cases"] if case["status"] != "PASS"]
        require(not failing, f"{len(failing)} fixture case(s) failed")
        report["status"] = "PASS"
        report["evidence"] = [
            f"{report['validCases']} valid metadata/request/response fixtures accepted",
            f"{report['invalidCases']} invalid fixtures rejected with reasons",
            "network=false enforced for current hostHints",
            "fixture string fields scanned for raw local/picker/app-private path leaks",
            "fixture string fields scanned for remote URLs and credential-like leaks",
            "unknown operations fail closed; no fallback to search is allowed",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
