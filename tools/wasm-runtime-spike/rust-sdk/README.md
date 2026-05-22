# Koma Rust Source SDK Spike

This crate is a non-shipping, test-only boundary sketch for Rust WASM source
authors. It keeps raw ABI details in a Koma-owned `no_std` layer while the
fixture source stays focused on source behavior.

The SDK intentionally covers only the current spike:

- `koma_host.log`, `koma_host.check_cancel`, and the S5 local-fixture-only
  `koma_host.http_request` host imports.
- `hostHints.network=false` response convention.
- A provisional `Source` trait with `SourceInfo`, `SourceCapabilities`,
  structured `SourceError`, and operation-specific request wrappers.
- SDK-owned operation runners for `search`, `get_manga`, `get_chapters`, and
  `get_pages` that handle ABI request reads, operation checks, cancellation,
  JSON response envelope writing, and KOMA result buffer headers.
- SDK runners for v0.2 optional browse/config/image operations. Sources can
  override the trait methods; the default response is a structured
  `unimplemented` error.
- A small `koma_source_info` export path that serializes source metadata and
  capabilities through the same KOMA result buffer format.
- KOMA result buffer header writing for the existing WAMR host runner.

It does not enable real HTTP, network access, source markets, remote install, or
any HarmonyOS product runtime path. The HTTP helper is present only so the local
WAMR fixture can request static data from `fixture.koma.local` through a
host-owned deny-by-default policy.

The fixture under `../rust-fixture` demonstrates the intended author-facing
shape for this spike:

1. Define a zero-sized source type.
2. Implement `Source` with metadata, capabilities, and static JSON data
   fragments for each operation.
3. Return `Ok(JsonPayload::new(...))` or `Err(SourceError::...)`; the SDK maps
   those into the response envelope.
4. Keep exported ABI symbols as thin calls into `koma_source_sdk::source::*`.

Current author shape:

```rust
use koma_source_sdk::source::{
    JsonPayload, SearchRequest, Source, SourceCapabilities, SourceError,
    SourceInfo, SourceResult,
};

struct MySource;

impl Source for MySource {
    fn info(&self) -> SourceInfo {
        SourceInfo {
            id: "example.local.source",
            name: "Example Source",
            version: "0.2.0",
            api_version: "0.2",
            language: "zh-Hans",
            author: "Example",
            description: "Static no_std source fixture.",
            content_rating: "unknown",
        }
    }

    fn capabilities(&self) -> SourceCapabilities {
        SourceCapabilities::CORE
    }

    fn search(&self, request: SearchRequest<'_>) -> SourceResult {
        if request.query_is(b"fixture") {
            Ok(JsonPayload::new(br#"{"items":[],"page":{"nextCursor":null,"hasMore":false}}"#))
        } else {
            Err(SourceError::invalid_request("expected fixture query"))
        }
    }

    /* implement get_manga, get_chapters, get_pages, and optional browse methods */
}
```

Structured errors should use the named helpers instead of constructing
`SourceErrorCode` directly:

- `SourceError::unimplemented()`
- `SourceError::invalid_request(message)`
- `SourceError::not_found(message)`
- `SourceError::cancelled()`
- `SourceError::timeout(message)`
- `SourceError::network_disabled(message)`
- `SourceError::permission_denied(message)`
- `SourceError::parse_error(message)`
- `SourceError::source_error(message)`
- `SourceError::internal_error(message)`

This is deliberately not a final public API. The request wrappers currently do
minimal byte matching so the direct `rustc`/`no_std` wasm build stays small and
does not require allocation or JSON dependencies. The SDK still expects source
authors to provide valid static JSON data fragments; typed DTO serialization,
allocation-backed JSON parsing, real host HTTP, settings/auth, and image request
resolution remain later lanes.

Optional v0.2 operations are represented in the trait now:

- `get_listings`
- `get_manga_list`
- `get_home`
- `get_filters`
- `get_settings`
- `get_image_request`

The current fixture exports and smokes the browse methods. `get_settings` and
`get_image_request` remain default-unimplemented until later config/image lanes.

Rerun the local runtime smoke with:

```sh
HOME=/home/gamer ./tools/wasm-runtime-spike/run-rust-fixture.sh \
  --artifact-dir /tmp/koma-rust-fixture-runtime-smoke
```

The script pins the wasm build to `target-cpu=mvp` and disables
`reference-types` because the current WAMR smoke host is built with reference
types off.
