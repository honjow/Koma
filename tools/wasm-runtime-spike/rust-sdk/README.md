# Koma Rust Source SDK Spike

This crate is a non-shipping, test-only boundary sketch for Rust WASM source
authors. It keeps raw ABI details in a Koma-owned `no_std` layer while the
fixture source stays focused on source behavior.

The SDK intentionally covers only the current spike:

- `koma_host.log` and `koma_host.check_cancel` host imports.
- `hostHints.network=false` response convention.
- A provisional `Source` trait with `SourceInfo`, `SourceCapabilities`,
  structured `SourceError`, and operation-specific request wrappers.
- SDK-owned operation runners for `search`, `get_manga`, `get_chapters`, and
  `get_pages` that handle ABI request reads, operation checks, cancellation,
  JSON response envelope writing, and KOMA result buffer headers.
- Default SDK runners for v0.2 optional browse/config/image operations. Sources
  can override the trait methods later; the default response is a structured
  `unimplemented` error.
- A small `koma_source_info` export path that serializes source metadata and
  capabilities through the same KOMA result buffer format.
- KOMA result buffer header writing for the existing WAMR host runner.

It does not enable HTTP, network access, source markets, remote install, or any
HarmonyOS product runtime path.

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

    /* implement get_manga, get_chapters, and get_pages */
}
```

This is deliberately not a final public API. The request wrappers currently do
minimal byte matching so the direct `rustc`/`no_std` wasm build stays small and
does not require allocation or JSON dependencies. The SDK still expects source
authors to provide valid static JSON data fragments; typed DTO serialization,
allocation-backed JSON parsing, host HTTP, settings/auth, and image request
resolution remain later lanes.

Optional v0.2 operations are represented in the trait now:

- `get_listings`
- `get_manga_list`
- `get_home`
- `get_filters`
- `get_settings`
- `get_image_request`

The fixture does not export or smoke those operations yet. That keeps this lane
focused on trait ergonomics and preserves the existing Linux/device smoke
contract for the four core operations.

Rerun the local runtime smoke with:

```sh
HOME=/home/gamer ./tools/wasm-runtime-spike/run-rust-fixture.sh \
  --artifact-dir /tmp/koma-rust-fixture-runtime-smoke
```

The script pins the wasm build to `target-cpu=mvp` and disables
`reference-types` because the current WAMR smoke host is built with reference
types off.
