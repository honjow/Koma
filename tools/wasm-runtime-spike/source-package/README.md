# Koma Local WASM Source Package Boundary

This directory is a tooling-only fixture for the future Koma WASM source
package shape. It is not product UI, a source repository, a marketplace, a
remote installer, or a built-in source list.

The fixture keeps the useful package lessons from source index layouts such as
per-source metadata, icon paths, settings, capabilities, and runtime limits,
while staying aligned with Koma's current runtime evidence:

```text
Rust SDK source -> wasm32-unknown-unknown -> WAMR sandbox -> explicit host imports
```

## Manifest Boundary

`manifest.example.json` declares only a local test package:

- package metadata: id, name, version, language, type, NSFW flag, author,
  description, and an optional icon placeholder.
- runtime metadata: `koma-source-abi-v0.1`, `koma-host-v0.1`, wasm path,
  wasm sha256, max memory pages, max payload bytes, max wasm bytes, and required
  host imports.
- capabilities: only `search` is enabled for the current fixture.
- settings schema: typed placeholder settings with no credentials.
- permissions: `network` is false and the only host imports are
  `koma_host.log` and `koma_host.check_cancel`.
- content policy: public index, marketplace, built-in source, and remote install
  are all false.

The manifest points at the committed tiny rawfile fixture so sha256 validation is
deterministic. The validator can also build the Rust no_std fixture into the
artifact directory to prove the source-to-wasm path without committing generated
wasm.

## Validate

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-package.py \
  --manifest tools/wasm-runtime-spike/source-package/manifest.example.json \
  --artifact-dir /path/to/artifacts/source-package \
  --build-rust-fixture
```

The script writes `source-package-validation.json` under the artifact directory.
It validates required fields, scope rules, sha256, wasm magic/version, declared
imports, exported fixture functions, capabilities, settings defaults, and
network=false.

This fixture intentionally does not add remote source index sync, source market
UI, real manga sources, APK plugins, WebView+JS runtime behavior, signing
material, WAMR source, HAP output, or Rust target directories to git.
