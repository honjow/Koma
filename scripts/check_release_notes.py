#!/usr/bin/env python3
"""Validate the version/notes/packaged-metadata relationship before publishing."""
import argparse
import os
from pathlib import Path
import re
import sys
import json

ROOT = Path(__file__).resolve().parent.parent
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-?pre)?", re.I)


def field(path, name):
    # These public version keys are unique; accepting JSON5 comments needs no external runtime.
    content = path.read_text(encoding="utf-8")
    content = re.sub(r"/\*.*?\*/|^\s*//[^\n]*", "", content, flags=re.S | re.M)
    match = re.search(r'["\']' + re.escape(name) + r'["\']\s*:\s*(?:["\']([^"\']+)["\']|([0-9]+))', content)
    if match is None:
        raise ValueError(f"Missing {name} in {path.relative_to(ROOT)}")
    return match.group(1) or match.group(2)


def verify(tag="", manifest=None):
    app = ROOT / "AppScope/app.json5"
    version = field(app, "versionName")
    code = int(field(app, "versionCode"))
    if VERSION.fullmatch(version) is None or code <= 0:
        raise ValueError("Invalid app versionName/versionCode")
    for relative in ("oh-package.json5", "entry/oh-package.json5"):
        if field(ROOT / relative, "version") != version:
            raise ValueError(f"{relative} version must equal AppScope version {version}")
    base = re.sub(r"-?pre$", "", version, flags=re.I)
    if tag:
        tagged = tag[1:] if tag.startswith("v") else tag
        if VERSION.fullmatch(tagged) is None or re.sub(r"-?pre$", "", tagged, flags=re.I) != base:
            raise ValueError("Release tag does not match app version")
        if version.lower().endswith("pre") and not tagged.lower().endswith("pre"):
            raise ValueError("A prerelease app cannot be published with a stable tag")
    relative = f"changelog/v{base}.md"
    notes = (ROOT / relative).read_text(encoding="utf-8").strip()
    if not notes or not re.search(r"^\s*-\s+\S", notes, re.M):
        raise ValueError("Release notes must contain user-facing changes")
    if manifest is not None:
        data = json.loads(Path(manifest).read_text(encoding="utf-8"))
        if data.get("versionName") != version or data.get("versionCode") != code:
            raise ValueError("Built HAP metadata does not match app version")
        if data.get("bundleName") != "com.honjow.koma" or data.get("buildMode") != "release":
            raise ValueError("Expected a Koma Release artifact")
    return version, code, relative


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default="")
    parser.add_argument("--manifest")
    parser.add_argument("--github-env", action="store_true")
    args = parser.parse_args()
    try:
        tag = args.tag or (os.environ.get("GITHUB_REF_NAME", "") if os.environ.get("GITHUB_REF", "").startswith("refs/tags/") else "")
        version, code, notes = verify(tag, args.manifest)
        if args.github_env:
            with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as target:
                target.write(f"APP_VERSION={version}\nRELEASE_NOTES_PATH={notes}\n")
        print(f"Release notes verified: version={version} code={code} file={notes}")
        return 0
    except (ValueError, OSError, KeyError) as error:
        print(f"Release notes check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
