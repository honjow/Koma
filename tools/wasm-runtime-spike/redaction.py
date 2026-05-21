import json
import os
import re
from pathlib import Path
from typing import Any


SPIKE_ROOT = Path(__file__).resolve().parent
REPO_ROOT = SPIKE_ROOT.parents[1]
HOME_ROOT = Path(os.environ.get("HOME", str(Path.home()))).resolve()

SECRET_REPLACEMENTS = (
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.IGNORECASE | re.DOTALL), "<private-key>"),
    (re.compile(r"Authorization\s*:\s*[^\s,;}]+(?:\s+[^\s,;}]+)?", re.IGNORECASE), "Authorization: <redacted>"),
    (re.compile(r"(Cookie|Set-Cookie)\s*:\s*[^\r\n,;}]+", re.IGNORECASE), r"\1: <redacted>"),
    (re.compile(r"\b(privateKey|password|token|secret|api[_-]?key)\s*[=:]\s*[^\s,;}]+", re.IGNORECASE), r"\1=<redacted>"),
)
URI_REPLACEMENTS = (
    (re.compile(r"\b(content|file|ohos)://[^\s\"')>,]+", re.IGNORECASE), "<picker-uri>"),
    (re.compile(r"\bapp-private://[^\s\"')>,]+", re.IGNORECASE), "<app-private-path>"),
    (re.compile(r"(?<![\w<])/(data|storage|sdcard|mnt)/(?:[^\s\"')>,]+)", re.IGNORECASE), "<app-private-path>"),
)


def _known_roots() -> list[tuple[str, str]]:
    roots: list[tuple[Path, str]] = []
    for env_key, label in (
        ("WAMR_ROOT_DIR", "<cache>"),
        ("KOMA_WASM_SPIKE_ARTIFACT_DIR", "<artifact>"),
        ("KOMA_SOURCE_PACKAGE_ARTIFACT_DIR", "<artifact>"),
    ):
        value = os.environ.get(env_key)
        if value:
            roots.append((Path(value).resolve(), label))
    roots.extend([
        (REPO_ROOT.resolve(), "<repo>"),
        (HOME_ROOT, "<home>"),
    ])
    normalized: list[tuple[str, str]] = []
    seen: set[str] = set()
    for path, label in sorted(roots, key=lambda item: len(str(item[0])), reverse=True):
        raw = str(path)
        if raw not in seen:
            normalized.append((raw, label))
            seen.add(raw)
    return normalized


def redact_text(value: str) -> str:
    redacted = value
    for pattern, replacement in SECRET_REPLACEMENTS + URI_REPLACEMENTS:
        redacted = pattern.sub(replacement, redacted)
    redacted = re.sub(r"(?<![\w<])/[^\s\"')>,]*/cache/wasm-micro-runtime(?:/[^\s\"')>,]*)?",
                      "<cache>", redacted)
    redacted = redacted.replace("cache/wasm-micro-runtime", "<cache>")
    for root, label in _known_roots():
        redacted = redacted.replace(root, label)
    redacted = re.sub(r"(?<![\w<])/home/gamer(?:/[^\s\"')>,]+)?", "<home>", redacted)
    return redacted


def redact_value(value: Any) -> Any:
    if isinstance(value, str):
        return redact_text(value)
    if isinstance(value, list):
        return [redact_value(item) for item in value]
    if isinstance(value, dict):
        return {key: redact_value(child) for key, child in value.items()}
    return value


def redacted_path(path: Path | str) -> str:
    return redact_text(str(path))


def redacted_command(cmd: list[str], env_prefix: dict[str, str] | None = None) -> str:
    prefix = ""
    if env_prefix:
        prefix = " ".join(f"{key}={redact_text(value)}" for key, value in sorted(env_prefix.items())) + " "
    return prefix + " ".join(redact_text(part) for part in cmd)


def write_redacted_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(redact_value(payload), indent=2, sort_keys=True) + "\n", encoding="utf-8")
