#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ALLOWED_OPERATIONS = {"search", "get_manga", "get_chapters", "get_pages"}
ALLOWED_IMAGE_KINDS = {"none", "placeholder", "remoteUrl", "imageRequest"}
ID_FIELDS = {"id", "mangaId", "chapterId"}
PATH_LEAK_RE = re.compile(
    r"(^/home/|^/Users/|^/data/|^/storage/|^/sdcard/|^/mnt/|"
    r"^[A-Za-z]:\\|file://|content://|ohos://|internal://|app-private|"
    r"\.hermes-artifacts|/cache/|/files/|/Documents/)"
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
    require(operation in ALLOWED_OPERATIONS, "operation must be one of search/get_manga/get_chapters/get_pages")
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
    require(kind in {"none", "placeholder"} or network, f"{path}.kind={kind} is gated while network=false")
    if kind == "remoteUrl":
        require(isinstance(value.get("url"), str) and value["url"].startswith(("https://", "http://")),
                f"{path}.url must be a remote URL")
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
    require(fixture_type in {"request", "response"}, "type must be request or response")
    if fixture_type == "request":
        validate_request(payload)
    else:
        validate_response(payload)
    return {
        "file": str(path),
        "type": fixture_type,
        "operation": payload.get("operation"),
        "status": "PASS",
    }


def collect_json_files(path: Path) -> list[Path]:
    require(path.is_dir(), f"fixture directory does not exist: {path}")
    files = sorted(path.glob("*.json"))
    require(files, f"no json fixtures found in {path}")
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Koma Source API v0.1 JSON envelope fixtures.")
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
            f"{report['validCases']} valid request/response fixtures accepted",
            f"{report['invalidCases']} invalid fixtures rejected with reasons",
            "network=false enforced for current hostHints",
            "response string fields scanned for raw local/picker/app-private path leaks",
        ]
    except Exception as err:
        report["status"] = "FAIL"
        report["error"] = str(err)

    write_json(report_path, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
