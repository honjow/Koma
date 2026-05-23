# Koma Source Author Compatibility Checklist

A short pre-flight checklist for source authors and future workers to run
**before** the evidence suite. It is the smallest set of contract items that
must hold today for a v0.2 Rust SDK source fixture.

For deeper context see:

- [`SOURCE_API_V0.md`](SOURCE_API_V0.md) — candidate API spec, envelopes,
  models.
- [`SOURCE_AUTHOR_QUICKSTART.md`](SOURCE_AUTHOR_QUICKSTART.md) — minimal
  authoring workflow.
- [`SOURCE_AUTHOR_STABILIZATION_AUDIT.md`](SOURCE_AUTHOR_STABILIZATION_AUDIT.md)
  — current contract, gaps, prioritized slices.

## Operation surface (v0.2, exactly 10)

Operation strings appear in request/response envelopes as `operation` and in
the SDK as method names. They are **snake_case**:

- Core (4): `search`, `get_manga`, `get_chapters`, `get_pages`.
- Browse (4): `get_listings`, `get_manga_list`, `get_home`, `get_filters`.
- Config/image (2): `get_settings`, `get_image_request`.

Rules:

- [ ] Unknown operation names fail closed. Never silently fall back to
  `search`.
- [ ] Optional operations the source does not serve return a structured
  `unimplemented` error (not absence, not panic).

## Export symbols (WASM)

The package validator requires exact `koma_source_*` exports. They are also
**snake_case**, prefixed with `koma_source_`:

- Required: `koma_source_init`, `koma_source_search`, `koma_source_get_manga`,
  `koma_source_get_chapters`, `koma_source_get_pages`, `koma_source_free`.
- Optional discovery: `koma_source_info`.
- Optional browse: `koma_source_get_listings`, `koma_source_get_manga_list`,
  `koma_source_get_home`, `koma_source_get_filters`.
- Optional config/image: `koma_source_get_settings`,
  `koma_source_get_image_request`.

Rule:

- [ ] Every operation the source claims to serve has a matching exported
  `koma_source_<operation>` ABI shim.

## Capability keys (v0.2 `SourceCapabilities`)

Capability keys in the `SourceCapabilities` JSON object are **camelCase**.
They do **not** match operation names 1:1 — do not confuse them.

- `search` -> `search`
- `get_manga` -> `mangaDetail`
- `get_chapters` -> `chapters`
- `get_pages` -> `pages`
- `get_listings` -> `listings`
- `get_manga_list` -> `mangaList`
- `get_home` -> `home`
- `get_filters` -> `filters`
- `get_settings` -> `settings`
- `get_image_request` -> `imageRequest`

Rules:

- [ ] Every capability set to `true` is backed by a real exported operation
  that returns a valid v0.2 response.
- [ ] All `future.*` keys remain `false`:
  `future.process_page_image`, `future.page_description`, `future.base_url`,
  `future.login`, `future.auth`, `future.deeplink`, `future.migration`.

The SDK ships `SourceCapabilities::CORE` (the four core operations) and
`SourceCapabilities::FULL_V02_FIXTURE` (all 10 current v0.2 operations) as
convenience constants. They are author shorthand only — using
`FULL_V02_FIXTURE` does not relax this checklist. Every flag the helper turns
`true` must still have a matching trait method override **and** a matching
exported `koma_source_<operation>` shim, and the evidence validators must
still see a valid v0.2 response for each one.

## Envelope naming conventions

- [ ] `operation` field carries the **snake_case** operation name
  (`get_manga`, not `mangaDetail`).
- [ ] Top-level envelope fields are camelCase: `version`, `requestId`,
  `operation`, `sourceId`, `args`, `settings`, `hostHints`, `ok`, `data`,
  `warnings`, `error`.
- [ ] `SourceCapabilities` keys are **camelCase**
  (`mangaDetail`, `imageRequest`); operation names inside the envelope stay
  snake_case.
- [ ] Reference fields are camelCase and reference-shaped, not raw secrets:
  `headersRef`, `credentialsRef`, `sessionRef`, `resourceRef`, `cacheKey`,
  `loginRefKey`.

## Closed `SourceError` code set

Only these `code` values may appear in a response `error.code`. The fixture
validator treats this as a closed set; ad-hoc strings are rejected.

- [ ] `unimplemented`
- [ ] `invalid_request`
- [ ] `not_found`
- [ ] `cancelled`
- [ ] `timeout`
- [ ] `network_disabled`
- [ ] `permission_denied`
- [ ] `parse_error`
- [ ] `source_error`
- [ ] `internal_error`

Each error must include a non-empty diagnostic `message`, a boolean
`retryable`, and, when present, an object `details`.

## Host imports and network gates

- [ ] General host ABI `koma-host-v0.1` exposes **only**
  `koma_host.log` and `koma_host.check_cancel`.
- [ ] `koma_host.http_request` is accepted **only** under
  `koma-host-v0.1-fixture-http` and only when the manifest declares
  `experimentalHttpFixture`. Requests target `fixture.koma.local` static
  data and must report `networkPerformed=false`.
- [ ] `koma_host.html_parse`, `html_select`, `html_attr`, `html_text`,
  `html_close` are accepted **only** under
  `koma-host-v0.1-fixture-http-html` with `experimentalHtmlFixture`, the
  approved selector/attribute subset, and `networkPerformed=false`.
- [ ] Every request and response carries `hostHints.network=false`. Image
  descriptors use `kind: "none"` or `kind: "placeholder"`; `remoteUrl` is
  invalid while `network=false`.

## No raw path / secret / URL / signing leaks

Responses, fixtures, logs, and reports must not contain:

- [ ] Raw remote URLs (other than the controlled `fixture.koma.local` /
  `fixture-image:` tokens used by the experimental fixtures).
- [ ] Local filesystem paths, picker URIs, app-private storage paths,
  archive paths, or generated build paths.
- [ ] Cookies, tokens, `Authorization` header values, passwords, or other
  raw credential material.
- [ ] Signing material: private keys, certificates (`.p12`, `.cer`, `.p7b`),
  raw signatures, or trust-store contents.
- [ ] Manga/chapter/page/cursor ids that are anything other than
  source-owned opaque UTF-8 strings (no decoded URLs, no path fragments).

## Validation commands

Run these from the repository root with an out-of-repo `<ARTIFACT_DIR>`.
Generated wasm, archives, logs, and reports stay under `--artifact-dir` and
must not be committed.

Source API v0.2 JSON fixture corpus:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir <ARTIFACT_DIR>/source-api-fixtures
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

Evidence suite negative contract (proves fail-closed behavior):

```sh
python3 tools/wasm-runtime-spike/source-package/validate-evidence-suite-negative-contract.py \
  --artifact-dir <ARTIFACT_DIR>/evidence-suite-negative-contract
```

A clean pass on the evidence suite plus the negative contract is the
compatibility bar for this lane.

## Non-goals

This checklist applies only to the local source-author fixture surface. It
does not cover product UI, source market, public source index, remote install,
built-in sources, real network or HTTP, trust/signing, or HarmonyOS product
runtime ingestion. Those belong to separately scoped lanes and must remain
disabled in current fixtures.
