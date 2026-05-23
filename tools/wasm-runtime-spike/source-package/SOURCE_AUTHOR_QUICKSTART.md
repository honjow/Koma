# Koma Source Author Quickstart (Rust SDK / Source API v0.2 Fixture)

This is a concise quickstart for authoring a Koma source against the **current**
Rust SDK and Source API v0.2 fixture state. It is docs-only and does not change
the contract.

For the candidate API model and JSON shapes, see
[`SOURCE_API_V0.md`](SOURCE_API_V0.md). For the stabilization audit (current
contract, gaps, and prioritized slices), see
[`SOURCE_AUTHOR_STABILIZATION_AUDIT.md`](SOURCE_AUTHOR_STABILIZATION_AUDIT.md).
For the package/archive boundary and validator inventory, see
[`README.md`](README.md).

## Author-facing status today

- **Rust source crate is `no_std`.** Authors implement a `Source` trait and
  thin exported ABI symbols. There is no allocator and no JSON parser
  requirement on the source side.
- **Static JSON payloads only.** Operations return `Ok(JsonPayload::new(b"..."))`
  with hand-authored static JSON bytes, or a structured `SourceError`. The SDK
  wraps payloads in the response envelope and writes the KOMA result buffer.
- **Source API v0.2 staged operation surface.** Core (`search`, `get_manga`,
  `get_chapters`, `get_pages`) plus browse/config/image
  (`get_listings`, `get_manga_list`, `get_home`, `get_filters`, `get_settings`,
  `get_image_request`). Future operation families (`process_page_image`,
  `page_description`, `base_url`, `login`, `auth`, `deeplink`, `migration`)
  remain documentary only and must stay disabled.
- **Local deterministic evidence only.** `hostHints.network=false` is required.
  No real HTTP or HTML fetching: `koma_host.http_request` and the HTML host
  imports are local WAMR fixture lanes gated by `experimentalHttpFixture` /
  `experimentalHtmlFixture` and serve only static `fixture.koma.local` data.
- **General host imports are minimal.** `koma_host.log` and
  `koma_host.check_cancel` are the only general-ABI imports.

## Minimal author workflow

### 1. Define source metadata and capabilities

Implement `Source::info` and `Source::capabilities` with the v0.2 shape:

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

    // implement search/get_manga/get_chapters/get_pages and any optional
    // browse/config/image operations the source actually serves.
}
```

`SourceInfo.id` must be a package id, not a URL or local path. Capabilities you
advertise as `true` must be backed by a real method override; everything else
should remain off so the SDK returns a structured `unimplemented` error.

Two SDK constants are provided for the common shapes:

- `SourceCapabilities::CORE` advertises only the four core operations
  (`search`, `mangaDetail`, `chapters`, `pages`). Use this as the default when
  the source only implements and exports the core surface.
- `SourceCapabilities::FULL_V02_FIXTURE` advertises all 10 current v0.2
  operations (core plus `listings`, `mangaList`, `home`, `filters`,
  `settings`, `imageRequest`). Use this **only** when the source actually
  implements every v0.2 method and exports a matching `koma_source_*` ABI
  shim for each one; otherwise build a `SourceCapabilities` value by hand so
  no flag is `true` without a real method and export behind it. All
  `future.*` keys stay `false` in both helpers.

### 2. Implement / export currently supported operations

For each operation the source supports, override the trait method and return
`Ok(JsonPayload::new(b"..."))` with a static JSON `data` fragment that matches
the v0.2 response model in [`SOURCE_API_V0.md`](SOURCE_API_V0.md). Use the
named `SourceError` helpers for failures:

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

Export thin ABI shims that delegate to `koma_source_sdk::source::*` for the
operations your source supports plus `koma_source_info` and
`koma_source_free`. Keep static fixture payloads small enough to fit
`hostHints.maxPayloadBytes`.

### 3. Build and run the direct Rust/WAMR fixture

This builds `wasm32-unknown-unknown` for the source SDK and the source crate,
then exercises every operation through the WAMR host runner and records local
evidence (operation envelopes, capability matrix, structured-error helpers,
unknown-operation rejection, fixture HTTP/HTML denial cases):

```sh
HOME=$HOME ./tools/wasm-runtime-spike/run-rust-fixture.sh \
  --artifact-dir <ARTIFACT_DIR>/rust-fixture
```

Replace `<ARTIFACT_DIR>` with your own outside-of-repo artifacts root. Generated
wasm, host build output, logs, and JSON reports stay under that directory and
must not be committed.

### 4. Run the source package / archive smoke

This packages the SDK-backed source as a local `.koma-source.zip`, validates
the archive boundary (entries, sha256, host imports, `network=false`), extracts
it under the artifact directory, and re-runs WAMR against the extracted wasm:

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-archive-smoke.py \
  --artifact-dir <ARTIFACT_DIR>/source-archive-smoke
```

### 5. Run the evidence suite and the negative contract

The evidence suite chains the direct Rust/WAMR fixture, archive smoke,
operation-surface parity validator, and the Source API v0.2 JSON fixture
corpus into one report with per-step paths and the parity-confirmed v0.2
operation list:

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-runtime-evidence-suite.py \
  --artifact-dir <ARTIFACT_DIR>/source-runtime-evidence-suite
```

The negative-contract validator copies the suite under the artifact directory,
patches it to fail one step, and asserts the suite exits nonzero with the
expected `step exit` and `missing expected report` findings — proving the
fail-closed behavior is repeatably testable as tooling:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-evidence-suite-negative-contract.py \
  --artifact-dir <ARTIFACT_DIR>/evidence-suite-negative-contract
```

Both wrappers perform no repository mutation; all generated wasm, archives,
logs, suite reports, and patched copies remain under the supplied
`--artifact-dir`.

## Compatibility checklist

- **Operation names (10).** `search`, `get_manga`, `get_chapters`,
  `get_pages`, `get_listings`, `get_manga_list`, `get_home`, `get_filters`,
  `get_settings`, `get_image_request`. Unknown operation names must fail
  closed; never silently fall back to `search`.
- **Capability keys.** `search`, `mangaDetail`, `chapters`, `pages`,
  `listings`, `mangaList`, `home`, `filters`, `settings`, `imageRequest`,
  plus `future.process_page_image`, `future.page_description`,
  `future.base_url`, `future.login`, `future.auth`, `future.deeplink`,
  `future.migration`. All `future.*` entries must remain `false`.
- **Closed `SourceError` codes.** `unimplemented`, `invalid_request`,
  `not_found`, `cancelled`, `timeout`, `network_disabled`,
  `permission_denied`, `parse_error`, `source_error`, `internal_error`. No
  ad-hoc code strings.
- **`network=false`.** Every request and response must carry
  `hostHints.network=false`. `koma_host.http_request` is fixture-only behind
  `experimentalHttpFixture` and must report `networkPerformed=false`.
- **Host imports.** General ABI exposes only `koma_host.log` and
  `koma_host.check_cancel`. HTTP/HTML imports are accepted only by the
  experimental fixture host ABI and only for `fixture.koma.local` /
  the deterministic HTML descriptor subset.
- **No raw path/secret/URL leaks.** Responses, fixtures, logs, and reports
  must not contain raw remote URLs, local filesystem paths, picker URIs,
  app-private paths, archive paths, cookies, tokens, `Authorization`
  headers, passwords, or signing material.

## Non-goals

This quickstart and the current author contract explicitly do **not** cover:

- Product UI (bookshelf, reader, source picker, settings UI).
- Source market, public source index, or a curated catalog.
- Remote install, over-the-air source delivery, or update streams.
- Built-in / bundled third-party manga sources.
- Real network access or real HTTP/HTML fetching.
- Trust, signing, key management, revocation, or signature verification.
- HarmonyOS product runtime, app registry, ingestion flow, or
  release-visible source management.

These belong to later, separately-scoped lanes. Authoring against this
quickstart should keep the local fixture surface stable while those lanes are
designed.
