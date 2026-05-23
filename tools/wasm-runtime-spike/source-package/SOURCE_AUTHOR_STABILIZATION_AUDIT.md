# Source-Author SDK / API / Docs Stabilization Audit

## Current stable author contract

- The active lane is the Koma WASM/source-runtime authoring contract: Rust `no_std` source SDK, source package/local archive tooling, Source API DTOs/capabilities, and repeatable local evidence.
- Current core operations are `search`, `get_manga`, `get_chapters`, and `get_pages`; the v0.2 staging surface adds `get_listings`, `get_manga_list`, `get_home`, `get_filters`, `get_settings`, and `get_image_request`.
- The common JSON envelope is stable enough for fixtures: request `version`, `requestId`, `operation`, `sourceId`, `args`, `settings`, `hostHints`; response `version`, `ok`, `operation`, `data` or structured `error`, `warnings`, `hostHints`.
- The closed structured error set is documented and represented in the SDK: `unimplemented`, `invalid_request`, `not_found`, `cancelled`, `timeout`, `network_disabled`, `permission_denied`, `parse_error`, `source_error`, `internal_error`.
- Host imports remain controlled: general `koma-host-v0.1` exposes `koma_host.log` and `koma_host.check_cancel`; HTTP and HTML imports are fixture-only experimental lanes and do not imply real network support.
- The SDK owns result-buffer/header writing, response envelope wrapping, cancellation checks, host logging wrappers, source metadata/capability serialization, and per-operation request self-consistency checks.
- The evidence suite already chains direct Rust/WAMR execution, archive smoke, operation-surface parity, and Source API v0.2 JSON fixture validation into one local report.

## Gaps / confusing points

- The spec presents a richer typed SDK direction, but the current SDK still returns `JsonPayload` backed by static JSON bytes; author expectations should be documented before implying a final ergonomic API.
- `SourceCapabilities::CORE` advertises only the four core operations, while current v0.2 fixture evidence expects browse/settings/image capabilities in the full fixture source; authors need an obvious SDK helper or docs pattern for the full v0.2 fixture surface.
- Request wrappers mostly expose byte-substring helpers such as `query_is`, `manga_id_is`, or `raw_contains`, which is fine for static fixtures but confusing as an author-facing parsing story.
- API naming spans Rust snake_case, JSON camelCase, and operation strings; the mapping is mostly clear in code/spec but not consolidated in a source-author checklist.
- Fixture-only HTTP/HTML imports are visible in the SDK host module, so docs must keep emphasizing that real network, real HTML fetching, and product HTTP remain non-goals.
- The package README documents validators and boundaries well, but it does not yet give a short "write a source with the Rust SDK" quickstart.
- The evidence suite emits JSON reports, but not a generated human-readable compatibility checklist for authors.

## First stabilization slices, prioritized

1. **Rust SDK quickstart docs.** Add a concise `rust-sdk` author quickstart showing `Source` implementation, capability override, operation exports, `koma_source_info`, validation commands, and the current static-JSON limitation.
2. **API naming / compatibility checklist.** Generate or maintain a small checklist covering operation names, export symbols, capability keys, error codes, host imports, and `network=false` leak rules.
3. **Fixture-to-SDK parity guide.** Document which SDK helpers and spec shapes are exercised by the direct WAMR fixture, archive smoke, operation parity validator, and Source API fixture validator.
4. **Capability helper cleanup.** Add small SDK helpers such as a full v0.2 fixture capability constructor so authors do not accidentally implement an operation while advertising it as unsupported.
5. **Request accessor cleanup.** Add minimal `no_std`-safe typed accessors for common envelope/argument fields, without introducing a real JSON parser or allocator requirement.
6. **Error-code tightening.** Prefer SDK paths that accept `SourceErrorCode` / `SourceError` over arbitrary code strings, keeping the documented closed error set from drifting.
7. **Generated author compatibility artifact.** Extend the evidence suite to write a markdown checklist beside its JSON report so authors can see the contract without reading every validator.

## Explicit non-goals

- No product UI, bookshelf/reader work, source picker, source market, public source index, remote install, or built-in sources.
- No real HTTP/network enablement and no public manga source support; fixture HTTP remains deterministic local evidence only.
- No trust/signing implementation, key management, revocation, or real signature verification.
- No HarmonyOS product runtime ingestion, picker flow, app registry, or release-visible source management.
- No new operation family beyond the current v0.2 staging surface; future login/auth/deeplink/migration/image-processing concepts remain documentary until separately scoped.
- No dependency on `std` for the source-author SDK core; any ergonomic additions should preserve `no_std` and keep `alloc` optional if introduced later.

## Validation commands

```sh
git diff --check
```

Optional contract checks for future stabilization slices:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures

python3 tools/wasm-runtime-spike/source-package/run-source-runtime-evidence-suite.py \
  --artifact-dir /path/to/artifacts/source-runtime-evidence-suite
```
