# Koma WASM Source Runtime Boundary

This file consolidates the current Koma WASM source runtime research boundary.
It is an implementation-oriented spec for future product/runtime work, not
product code.

## Status

The current boundary is research/tooling-only. It validates local fixtures,
package manifests, local archives, and Linux WAMR execution. It does not add a
source market, public source index, remote install path, built-in source list,
HarmonyOS product UI, or product runtime loading behavior.

Future local source package trust/provenance requirements are tracked in
`SOURCE_PACKAGE_TRUST_BOUNDARY.md`. That file is design-only and does not add
signing code, key material, product install, or runtime loading behavior.

Candidate source operation names and JSON envelopes for future search, detail,
chapter, and page calls are tracked in `SOURCE_API_V0.md`. That file is also
design-only and does not expand the current host imports or enable network.

The validated path is:

```text
Rust no_std fixture -> wasm32-unknown-unknown -> source package manifest
-> .koma-source.zip validation/extraction -> Linux WAMR host runner
```

## ABI v0.1

Current source ABI: `koma-source-abi-v0.1`

Current host ABI: `koma-host-v0.1`

Required exports for the current fixture boundary:

- `add(i32, i32) -> i32`: smoke-only arithmetic evidence.
- `koma_source_init(manifest_ptr: u32, manifest_len: u32) -> i32`.
- `koma_source_search(request_ptr: u32, request_len: u32) -> result_ptr: u32`.
- `koma_source_free(result_ptr: u32) -> void`.

The host copies manifest/request JSON into guest memory before calls. Search
returns a guest-owned result buffer. The host validates and reads this envelope,
then calls `koma_source_free`.

Result buffer layout, little endian:

```text
offset  size  field
0       4     magic: 0x4B4F4D41 ("KOMA")
4       4     flags: bit 0 means ok JSON payload
8       4     payload_len
12      4     reserved: 0
16      N     UTF-8 JSON payload
```

The current result JSON envelope includes `hostHints` with:

```json
{
  "abi": "koma-host-v0.1",
  "maxMemoryPages": 2,
  "maxPayloadBytes": 1048576,
  "network": false
}
```

`hostHints.network=false` is part of the current evidence and must not be used
to imply network support.

## Host Imports

Current runtime packages may import exactly:

- `koma_host.log(level: u32, message_ptr: u32, message_len: u32)`.
- `koma_host.check_cancel() -> i32`.

The Linux host runner logs sanitized messages and currently returns
`check_cancel=0` in smoke runs. The import set is intentionally closed for
`koma-host-v0.1`.

HTTP remains design-only under `../host-imports/http-boundary.md`, with the
concrete v0.1 candidate in `../host-imports/http-host-import-v0.md`. The
proposed `koma_host.http_request` import is gated behind a future design ABI and
`permissions.network=true`; current source-package validation must reject it.

## Rust SDK Role

`../rust-sdk` is a non-shipping, source-author-facing `no_std` shim for this
fixture boundary. It wraps `log` and `check_cancel`, writes the KOMA result
buffer header, and carries the `hostHints.network=false` response convention.

It is not a complete public SDK, does not define final source APIs, and does not
enable HTTP, storage, cookies, source discovery, installation, or HarmonyOS
runtime integration.

## Package Manifest Gates

`manifest.example.json` is the current manifest fixture. A valid package for
this boundary must declare:

- `package.id`, name, version, language, type, NSFW flag, author, and
  description; icon is optional and package-local when archived.
- `runtime.abi=koma-source-abi-v0.1`.
- `runtime.hostAbi=koma-host-v0.1`.
- `runtime.wasm.path`, `runtime.wasm.sha256`, and wasm size within
  `runtime.limits.maxWasmBytes`.
- `runtime.limits.maxMemoryPages=2` and `maxPayloadBytes=1048576` for the
  current fixture.
- `runtime.requiredHostImports` exactly `koma_host.log` and
  `koma_host.check_cancel`.
- `permissions.network=false`.
- `permissions.hostImports` matching the required imports.
- `capabilities` with only `search=true` in the current fixture; `detail`,
  `chapterList`, `pageList`, and `imageUrl` remain false.
- `settingsSchema` with typed defaults and no embedded credentials.
- `contentPolicy.publicIndex=false`, `marketplace=false`,
  `builtInSource=false`, and `remoteInstall=false`.

## Archive Format

The local archive format is a tooling fixture named `*.koma-source.zip`. It is
not product install behavior.

Expected entries:

- `manifest.generated.json`
- `wasm/rust_source_fixture.wasm`
- `icon.placeholder.txt` only when declared by the manifest

The archive validator checks suffix, duplicate entries, path traversal,
absolute paths, symlinks, unexpected entries, hidden/generated build
directories, file size limits, archive size limits, manifest parseability, wasm
magic/version, wasm sha256/size, closed imports, `network=false`, and disabled
content policy flags.

Negative fixture coverage currently asserts rejection for traversal, absolute
paths, duplicate entries, symlink entries, unexpected entries, network/http
import drift, wasm hash mismatch, and missing required entries.

## Archive-To-WAMR Smoke

The smoke path validates and extracts an archive before execution. Only the
extracted `wasm/rust_source_fixture.wasm` is passed to the Linux WAMR host
runner after archive safety and staged manifest validation pass.

Expected execution evidence includes:

- archive safety gates pass before WAMR execution
- `WAMR_SPIKE_PASS`
- `SOURCE_API_RUNTIME_SMOKE_PASS`
- `SOURCE_API_OPERATION search ok:true`
- `SOURCE_API_OPERATION get_manga ok:true`
- `SOURCE_API_OPERATION get_chapters ok:true`
- `SOURCE_API_OPERATION get_pages ok:true`
- `Fixture Series`
- `HOST_LOG`
- `HOST_CHECK_CANCEL`
- `hostHints.network=false`

## Non-Goals

- Product source install/load path.
- HarmonyOS archive ingestion or product runtime/UI changes.
- Source market, public index, remote install, built-in source list, or real
  manga source catalog.
- Real HTTP implementation, cookie handling, credential storage, or request
  policy enforcement.
- WebView workflow DSL or JavaScript source runtime.
- APK plugin flow.
- WAMR vendor source changes.
- Signing material, HAP/build outputs, generated archives/wasm, or Rust target
  directories in git.

## Open Items

- Product decision for whether and how local source packages are installed,
  trusted, updated, removed, and surfaced in UI.
- HarmonyOS archive ingestion path and sandbox storage layout.
- Real HTTP ABI, network permission UX, host allowlists, cookies, credentials,
  cache/session partitioning, and logging redaction.
- Streaming and large response strategy beyond fixed result buffers.
- Concurrency, cancellation, reentrancy, and lifecycle rules for multi-call or
  long-running sources.
- Signature, trust, provenance, revocation, and compatibility model; see
  `SOURCE_PACKAGE_TRUST_BOUNDARY.md`.
- Final public Rust SDK/API shape and versioning policy.
- Source API v0.1 fixture/schema tests for search, manga detail, chapters,
  pages, pagination, stable opaque ids, structured errors, cancellation,
  timeout, and result size behavior; see `SOURCE_API_V0.md`.

## Validation Commands

Use the lane artifact directory for reproducible evidence:

```sh
ARTIFACT=/home/gamer/git/Koma/.hermes-artifacts/20260521-210000/lane3q-runtime-boundary-spec

HOME=/home/gamer python3 tools/wasm-runtime-spike/source-package/run-source-archive-smoke.py \
  --artifact-dir "$ARTIFACT/archive-to-wamr-smoke"

HOME=/home/gamer python3 tools/wasm-runtime-spike/source-package/validate-archive-negative-fixtures.py \
  --artifact-dir "$ARTIFACT/archive-negative-fixtures"

HOME=/home/gamer python3 tools/wasm-runtime-spike/source-package/package-source-archive.py \
  --artifact-dir "$ARTIFACT/archive-boundary"

HOME=/home/gamer python3 tools/wasm-runtime-spike/source-package/validate-source-package.py \
  --manifest tools/wasm-runtime-spike/source-package/manifest.example.json \
  --artifact-dir "$ARTIFACT/source-package" \
  --build-rust-fixture

HOME=/home/gamer python3 tools/wasm-runtime-spike/host-imports/validate-http-boundary.py \
  --manifest tools/wasm-runtime-spike/host-imports/http-boundary.example.json \
  --current-manifest tools/wasm-runtime-spike/source-package/manifest.example.json \
  --artifact-dir "$ARTIFACT/http-boundary"
```

If Python scripts are edited, run `python3 -m py_compile` on the touched scripts
and remove any generated `__pycache__` directories before reporting scope.
