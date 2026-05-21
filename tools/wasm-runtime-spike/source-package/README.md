# Koma Local WASM Source Package Boundary

This directory is a tooling-only fixture for the future Koma WASM source
package shape. It is not product UI, a source repository, a marketplace, a
remote installer, or a built-in source list.

For the consolidated current runtime/package/archive boundary, see
`SOURCE_RUNTIME_BOUNDARY.md`.

For the candidate Source API v0.1 operation and JSON envelope design, see
`SOURCE_API_V0.md`.

For the design-only future HarmonyOS source archive ingestion boundary, see
`HARMONYOS_ARCHIVE_INGESTION_BOUNDARY.md`.

For the design-only future local source package trust/provenance boundary, see
`SOURCE_PACKAGE_TRUST_BOUNDARY.md`.

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

`build-rust-sdk-source-package.py` is the tooling-only bridge between the local
Rust SDK fixture and this package boundary. It builds and runs the SDK-backed
fixture through WAMR, computes the generated wasm size and sha256, writes a
local generated manifest under the artifact directory, and validates that
manifest with the same package validator. The generated manifest and wasm stay
out of git.

## Validate

To validate the candidate Source API v0.1 JSON request/response fixture corpus:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures
```

The script writes `source-api-fixtures-report.json` under the artifact
directory. It accepts valid request/response envelopes for `search`,
`get_manga`, `get_chapters`, and `get_pages`, and asserts that invalid fixtures
are rejected with deterministic local reasons. The validator is stdlib-only,
does not invoke WAMR, and does not perform network.

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

To exercise the Rust-SDK-backed package build boundary:

```sh
python3 tools/wasm-runtime-spike/source-package/build-rust-sdk-source-package.py \
  --artifact-dir /path/to/artifacts/source-package-build
```

The build report is written to
`rust-sdk-source-package-build-report.json` under the artifact directory and
includes the built wasm sha256/size, generated manifest path, validator report
path, and gate results for `packageId`, `hostAbi=koma-host-v0.1`,
`network=false`, exact `koma_host.log`/`koma_host.check_cancel` imports, wasm
hash/size, and disabled public index/marketplace/built-in/remote-install flags.

## Local Archive Boundary

`package-source-archive.py` turns the SDK-backed generated package into a local
artifact-only archive for future import/install research. The archive is still a
tooling fixture, not app install behavior, runtime loading from zip, remote sync,
or a source market.

By default the script first runs `build-rust-sdk-source-package.py`, then stages
a self-contained package under the artifact directory and writes a
`.koma-source.zip` containing:

- `manifest.generated.json`
- `wasm/rust_source_fixture.wasm`
- `icon.placeholder.txt` when the generated manifest declares the icon

The archived manifest keeps the generated wasm sha256 and rewrites only the wasm
path to the package-local `wasm/rust_source_fixture.wasm`. The validator then
checks the zip boundary for expected entries only, duplicate names, absolute
paths, path traversal, symlinks, hidden/generated build directories, oversized
files, manifest parseability, wasm sha256/size, `network=false`,
`hostAbi=koma-host-v0.1`, exact `koma_host.log`/`koma_host.check_cancel` host
imports, and disabled public index/marketplace/built-in/remote-install flags.

```sh
python3 tools/wasm-runtime-spike/source-package/package-source-archive.py \
  --artifact-dir /path/to/artifacts/source-package-archive
```

The script writes `source-package-archive-report.json` under the artifact
directory. The generated archive, staged package, extracted files, logs, wasm,
and reports are all artifact outputs and should stay out of git.

An existing local source archive can be checked without rebuilding it:

```sh
python3 tools/wasm-runtime-spike/source-package/package-source-archive.py \
  --artifact-dir /path/to/artifacts/archive-validation \
  --validate-archive /path/to/local.test.koma.fixture.koma-source.zip
```

The validate-only path runs the same archive safety, extraction, staged manifest,
wasm hash, network/import, and content-policy gates as the default happy path.

To close the Linux smoke loop from archive validation to actual WAMR execution:

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-archive-smoke.py \
  --artifact-dir /path/to/artifacts/archive-to-wamr-smoke
```

The smoke script creates a SDK-backed `.koma-source.zip` unless `--archive` is
provided, validates and extracts it through `package-source-archive.py
--validate-archive`, checks the extracted manifest gates, builds the existing
CMake WAMR host runner, and runs the extracted `wasm/rust_source_fixture.wasm`.
The report is written to `source-archive-wamr-smoke-report.json` and records
`WAMR_SPIKE_PASS`, `ok:true`, `Fixture Series`, `HOST_LOG`,
`HOST_CHECK_CANCEL`, and `hostHints.network=false` evidence. All archives,
extracted files, wasm binaries, host builds, caches, logs, and reports remain
artifact outputs.

`validate-archive-negative-fixtures.py` is a tooling-only adversarial corpus
generator. It first creates a valid baseline archive under the artifact
directory, then writes malformed zips under artifacts only and asserts the
validate-only path rejects traversal, absolute paths, duplicate entries,
symlinks, unexpected entries, network/http import drift, wasm hash mismatch, and
missing required entries.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-archive-negative-fixtures.py \
  --artifact-dir /path/to/artifacts/archive-negative-fixtures
```

Future HTTP/network source capability is tracked separately in
`../host-imports/http-boundary.md`. That boundary is design-only: its sample
manifest uses `network=true` and `koma_host.http_request` only to validate a
future contract, and the current source-package validator must still reject it.

This fixture intentionally does not add remote source index sync, source market
UI, real manga sources, APK plugins, WebView+JS runtime behavior, signing
material, WAMR source, HAP output, or Rust target directories to git.
