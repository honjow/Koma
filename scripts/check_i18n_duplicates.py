#!/usr/bin/env python3
"""
i18n parity & duplicate checker (ported from NextE).

For every resource qualifier under entry/src/main/resources/<locale>/element/string.json
(plus base), verify:
  - no duplicate string names within a file
  - every locale defines exactly the same key set as `base` (no missing / extra keys)

Run: python3 scripts/check_i18n_duplicates.py
Exit 1 on any violation.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "entry" / "src" / "main" / "resources"


def load_names(path: Path):
    names = []
    dups = []
    data = json.loads(path.read_text(encoding="utf-8"))
    for item in data.get("string", []):
        name = item["name"]
        if name in names:
            dups.append(name)
        names.append(name)
    return names, dups


def main() -> int:
    errors = []
    locales = {}
    for path in sorted(RES.glob("*/element/string.json")):
        locale = path.parent.parent.name
        names, dups = load_names(path)
        if dups:
            errors.append(f"{locale}: duplicate keys {sorted(set(dups))}")
        locales[locale] = set(names)

    if "base" not in locales:
        errors.append("missing base/element/string.json")
    else:
        base = locales["base"]
        for locale, keys in locales.items():
            if locale == "base":
                continue
            missing = base - keys
            extra = keys - base
            if missing:
                errors.append(f"{locale}: missing keys {sorted(missing)}")
            if extra:
                errors.append(f"{locale}: extra keys not in base {sorted(extra)}")

    if errors:
        print("x i18n parity: " + str(len(errors)) + " issue(s)")
        for error in errors:
            print("  " + error)
        return 1
    print("ok i18n parity: " + str(len(locales)) + " locales, identical key sets, no duplicates")
    return 0


if __name__ == "__main__":
    sys.exit(main())
