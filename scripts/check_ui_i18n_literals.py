#!/usr/bin/env python3
"""
Guard against new hardcoded UI copy in ArkUI pages/components.

This is intentionally narrow: it catches direct user-facing string literals in
common UI constructors and all Chinese literals in page/component sources,
while allowing brand names, short badges, and icon-like symbols.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN_ROOTS = [
    ROOT / "entry" / "src" / "main" / "ets" / "pages",
    ROOT / "entry" / "src" / "main" / "ets" / "components",
]

CHINESE_LITERAL_RE = re.compile(r"""(['"`])([^'"`\n]*[\u4e00-\u9fff][^'"`\n]*)\1""")
DIRECT_UI_LITERAL_RE = re.compile(
    r"""(?P<prefix>\b(?:Text|Button|MenuItem|Checkbox|Radio)\s*\(\s*|\.title\s*\(\s*|(?:label|content|placeholder|title):\s*)(?P<quote>['"`])(?P<value>[^'"`\n]+)(?P=quote)"""
)

ALLOWED_DIRECT_VALUES = {
    "-",
    "+",
    ">",
    "↓",
    "✓",
    "K",
    "C",
    "D",
    "O",
    "W",
    "Koma",
    "Komga",
    "OPDS",
    "Smoke",
    "URL",
    "WebDAV",
    "X-API-Key",
    "demo@komga.org",
    "komga-demo",
    "NSFW",
}


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda match: "\n" * match.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//.*", "", text)


def is_allowed_direct_value(value: str) -> bool:
    stripped = value.strip()
    if "${" in stripped:
        return True
    if stripped in ALLOWED_DIRECT_VALUES:
        return True
    if len(stripped) <= 2 and not re.search(r"[A-Za-z\u4e00-\u9fff]{2}", stripped):
        return True
    return False


def check_file(path: Path) -> list[str]:
    source = path.read_text(encoding="utf-8")
    comparable = strip_comments(source)
    errors: list[str] = []

    for match in CHINESE_LITERAL_RE.finditer(comparable):
        errors.append(f"{path.relative_to(ROOT)}:{line_number(comparable, match.start())}: Chinese UI literal: {match.group(2)!r}")

    for match in DIRECT_UI_LITERAL_RE.finditer(comparable):
        value = match.group("value")
        if is_allowed_direct_value(value):
            continue
        errors.append(f"{path.relative_to(ROOT)}:{line_number(comparable, match.start())}: hardcoded UI literal: {value!r}")

    return errors


def main() -> int:
    errors: list[str] = []
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.ets")):
            errors.extend(check_file(path))

    if errors:
        print(f"x UI i18n literal gate: {len(errors)} issue(s)")
        for error in errors:
            print("  " + error)
        return 1

    print("ok UI i18n literal gate: pages/components use resources for user-facing copy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
