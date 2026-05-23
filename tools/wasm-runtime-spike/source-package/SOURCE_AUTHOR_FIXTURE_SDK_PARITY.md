# Koma Source Author Fixture-to-SDK Parity Guide

A concise map from source-author SDK concepts to the fixture and evidence
validators that actually prove each contract today. It is docs-only; it does
not change the SDK, the JSON envelope, or any validator behavior.

For broader context see:

- [`SOURCE_API_V0.md`](SOURCE_API_V0.md) — candidate API spec, envelopes, and
  response models.
- [`SOURCE_AUTHOR_QUICKSTART.md`](SOURCE_AUTHOR_QUICKSTART.md) — minimal
  Rust SDK authoring workflow.
- [`SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md`](SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md)
  — pre-flight contract checklist.

## Why parity matters

A v0.2 source has to satisfy the same contract from several angles. The
evidence pipeline walks an author claim through layered validators so that any
drift between the SDK and the JSON contract is caught locally before it
reaches a downstream worker:

1. **Rust SDK trait + static payloads** — `Source::info`, `Source::capabilities`,
   per-operation methods returning `JsonPayload` or a structured `SourceError`.
2. **Source API v0.2 JSON fixtures** — hand-authored request/response
   envelopes mirroring what the SDK should produce.
3. **Direct WAMR fixture** — builds `wasm32-unknown-unknown`, runs each
   operation against the WAMR host runner, and records local evidence.
4. **Source archive smoke** — packages the SDK-backed source as a local
   `.koma-source.zip`, re-validates entries/sha256/host imports, extracts,
   and re-runs WAMR against the extracted wasm.
5. **Parity / evidence suite** — chains the direct fixture, archive smoke,
   operation-surface parity, and Source API v0.2 corpus into a single report,
   plus a negative-contract validator that proves the suite fails closed.

If any layer disagrees with the others — for example, a capability flipped to
`true` without a matching export, or an unknown error `code` — the
corresponding validator must fail. The mapping below is what each command is
responsible for proving.

## SDK concept → evidence mapping

Validators are referenced by filename under
`tools/wasm-runtime-spike/source-package/`. The full commands appear in the
[Validation commands](#validation-commands) section.

### `SourceInfo` / `SourceCapabilities`

- **SDK side:** `Source::info` returns `SourceInfo` (`id`, `name`, `version`,
  `api_version`, `language`, `author`, `description`, `content_rating`).
  `Source::capabilities` returns `SourceCapabilities` with the v0.2 camelCase
  keys (`search`, `mangaDetail`, `chapters`, `pages`, `listings`, `mangaList`,
  `home`, `filters`, `settings`, `imageRequest`, plus `future.*` keys). The
  SDK provides `SourceCapabilities::CORE` for the four core operations and
  `SourceCapabilities::FULL_V02_FIXTURE` for the full 10-operation v0.2
  surface; both are author conveniences and do not bypass any validator —
  the evidence layers below still have to see real method overrides,
  exported `koma_source_*` shims, and v0.2-conforming response envelopes for
  every flag the helper sets to `true`.
- **Fixture side:** `source-api-fixtures/info.*.json` and
  `source-api-fixtures/capabilities.*.json` carry the same fields inside the
  v0.2 response envelope.
- **Proven by:**
  - `validate-source-api-fixtures.py` — checks envelope shape, capability key
    set, and that every `future.*` key is `false`.
  - `validate-operation-surface-parity.py` — checks that the operations the
    SDK exports match the v0.2 operation set used by the fixtures.
  - `run-source-runtime-evidence-suite.py` — re-runs the above against the
    real WAMR-produced envelopes.

### Operation methods / export symbols

- **SDK side:** trait methods `search`, `get_manga`, `get_chapters`,
  `get_pages`, `get_listings`, `get_manga_list`, `get_home`, `get_filters`,
  `get_settings`, `get_image_request`. ABI shims exported as
  `koma_source_<operation>` plus `koma_source_init`, `koma_source_info`,
  `koma_source_free`.
- **Fixture side:** request envelopes set `operation` to the snake_case name;
  response envelopes echo it back. The archive carries the exported symbol
  set.
- **Proven by:**
  - `validate-operation-surface-parity.py` — closed v0.2 operation set,
    unknown operations must fail closed.
  - `validate-source-package.py` — required and optional `koma_source_*`
    exports, snake_case naming.
  - `run-source-archive-smoke.py` — runs every supported operation through
    the extracted wasm after archive validation.

### `JsonPayload` response fragments

- **SDK side:** operations return `Ok(JsonPayload::new(b"..."))` with static
  JSON bytes that form the `data` field of the response envelope. The SDK
  wraps the bytes in the envelope and writes the KOMA result buffer.
- **Fixture side:** `source-api-fixtures/<operation>.*.json` response files
  contain the matching `data` shapes (search results, manga, chapter list,
  page list, listings, manga list, home, filters, settings, image request).
- **Proven by:**
  - `validate-source-api-fixtures.py` — per-operation `data` schema, image
    descriptor kinds restricted to `none` / `placeholder` / `imageRequest`,
    no raw URLs.
  - Direct Rust/WAMR fixture (`run-rust-fixture.sh`) — confirms the SDK
    actually emits the same envelope through WAMR.
  - `run-source-runtime-evidence-suite.py` — re-validates the WAMR output
    against the v0.2 corpus rules.

### `SourceError` helpers and closed error codes

- **SDK side:** `SourceError::unimplemented()`, `invalid_request(msg)`,
  `not_found(msg)`, `cancelled()`, `timeout(msg)`, `network_disabled(msg)`,
  `permission_denied(msg)`, `parse_error(msg)`, `source_error(msg)`,
  `internal_error(msg)`. Errors carry `code`, `message`, `retryable`, optional
  `details`.
- **Fixture side:** negative envelopes under `source-api-fixtures/` use only
  this closed `code` set.
- **Proven by:**
  - `validate-source-api-fixtures.py` — rejects any `error.code` not in the
    closed set, requires non-empty `message` and boolean `retryable`.
  - `run-source-runtime-evidence-suite.py` — exercises structured-error
    helpers and unknown-operation rejection through WAMR.
  - `validate-evidence-suite-negative-contract.py` — proves the suite fails
    closed when a step is intentionally broken (no silent success).

### `hostHints.network=false`

- **SDK side:** the SDK populates `hostHints.network=false` on every request
  and response envelope; `SourceError::network_disabled` exists for sources
  that try to require network.
- **Fixture side:** every fixture envelope carries `hostHints.network=false`
  and uses `kind: "none"` or `kind: "placeholder"` for image descriptors.
- **Proven by:**
  - `validate-source-api-fixtures.py` — enforces `network=false` and rejects
    `remoteUrl` while network is disabled.
  - `validate-source-package.py` / `run-source-archive-smoke.py` — fail when
    the manifest or archive declares `network=true` or unapproved host
    imports.

### Fixture-only HTTP / HTML imports

- **SDK side:** the SDK host module exposes `koma_host.http_request` and the
  HTML descriptor imports only behind the experimental fixture lanes
  (`koma-host-v0.1-fixture-http`, `koma-host-v0.1-fixture-http-html`). The
  manifest must declare `experimentalHttpFixture` / `experimentalHtmlFixture`
  for those imports to be accepted.
- **Fixture side:** requests target `fixture.koma.local` static data and
  every response carries `networkPerformed=false`.
- **Proven by:**
  - `validate-source-package.py` — host ABI tag plus exact allowed import
    set; rejects unknown imports.
  - `run-source-archive-smoke.py` — re-checks imports after archive
    extraction and runs the fixture lanes against static data.
  - `run-source-runtime-evidence-suite.py` — records the deny cases for
    non-fixture URLs and the `networkPerformed=false` evidence.

### Image request / settings / auth references

- **SDK side:** image, settings, and auth references appear as safe
  descriptors: `headersRef`, `credentialsRef`, `sessionRef`, `resourceRef`,
  `cacheKey`, `loginRefKey`. The SDK never emits raw URLs, header values, or
  credential material.
- **Fixture side:** `source-api-fixtures/get_image_request.*.json`,
  `get_settings.*.json`, and `settings-auth-fixtures/*.json` only carry
  reference-shaped fields, with image kinds restricted to
  `none` / `placeholder` / `imageRequest`.
- **Proven by:**
  - `validate-source-api-fixtures.py` — schema and forbidden-token sweep on
    image/settings payloads.
  - `validate-settings-auth-fixtures.py` — settings/auth references stay
    reference-shaped (no cookies, tokens, `Authorization` values, passwords).
  - `validate-image-page-fixtures.py` — image/page descriptor boundary
    (cache identity, header policy, network gates) for the design-only image
    lane.

## Validation commands

Run from the repository root with an out-of-repo `<ARTIFACT_DIR>`. Generated
wasm, archives, logs, and reports stay under `--artifact-dir` and must not be
committed.

Source API v0.2 JSON fixture corpus:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir <ARTIFACT_DIR>/source-api-fixtures
```

Operation-surface parity (closed v0.2 operation set):

```sh
python3 tools/wasm-runtime-spike/source-package/validate-operation-surface-parity.py \
  --artifact-dir <ARTIFACT_DIR>/operation-surface-parity
```

Settings/auth reference shape:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-settings-auth-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/settings-auth-fixtures \
  --artifact-dir <ARTIFACT_DIR>/settings-auth-fixtures
```

Image/page descriptor boundary:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-image-page-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/image-page-fixtures \
  --artifact-dir <ARTIFACT_DIR>/image-page-fixtures
```

Direct Rust/WAMR fixture (builds wasm32 and runs every operation):

```sh
HOME=$HOME ./tools/wasm-runtime-spike/run-rust-fixture.sh \
  --artifact-dir <ARTIFACT_DIR>/rust-fixture
```

Source package / local archive smoke:

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-archive-smoke.py \
  --artifact-dir <ARTIFACT_DIR>/source-archive-smoke
```

Full source-runtime evidence suite (chains direct fixture, archive smoke,
operation-surface parity, and Source API v0.2 JSON fixtures):

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-runtime-evidence-suite.py \
  --artifact-dir <ARTIFACT_DIR>/source-runtime-evidence-suite
```

Evidence suite negative contract (fail-closed proof):

```sh
python3 tools/wasm-runtime-spike/source-package/validate-evidence-suite-negative-contract.py \
  --artifact-dir <ARTIFACT_DIR>/evidence-suite-negative-contract
```

A clean pass on the evidence suite plus the negative contract is the parity
bar for this lane.

## Non-goals

This parity guide applies only to the local source-author fixture surface.
It does not cover product UI, source market, public source index, remote install,
built-in sources, real network or HTTP/HTML fetching, trust/signing, or HarmonyOS
product runtime ingestion. More explicitly, it excludes:

- Product UI (bookshelf, reader, source picker, settings UI).
- Source market, public source index, or curated catalogs.
- Remote install, over-the-air source delivery, or update streams.
- Built-in / bundled third-party manga sources.
- Real network access or real HTTP / HTML fetching.
- Trust, signing, key management, revocation, or signature verification.
- HarmonyOS product runtime, app registry, ingestion flow, or
  release-visible source management.

Those belong to separately scoped lanes and must remain disabled in current
fixtures.
