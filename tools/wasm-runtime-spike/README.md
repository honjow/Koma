# Koma WASM Runtime Spike

This is a repo-local, non-shipping runtime spike for the future source ABI. It
does not add product UI, source import, source lists, network integrations, or
HarmonyOS app behavior.

The current consolidated runtime/package/archive boundary is documented in
`source-package/SOURCE_RUNTIME_BOUNDARY.md`.

The future HTTP host import remains product-disabled. The concrete v0.1
candidate is documented in `host-imports/http-host-import-v0.md`; this spike
adds only a local WAMR fixture import, `koma_host.http_request`, behind an
explicit `experimentalHttpFixture` manifest policy. It returns static data for
`https://fixture.koma.local/...`, performs no real network I/O, and does not
enable HarmonyOS app runtime HTTP, product UI, public sources, or source
markets. Current non-fixture validators still reject `network=true` and
unpermitted `koma_host.http_request`.
Static negative fixtures for that closed policy live under
`host-imports/http-policy-negative-fixtures/` and are checked by
`host-imports/validate-http-policy-negative-fixtures.py`. The validator loads
local JSON only, performs no network I/O, and does not execute WAMR.

The future HTML host import is also product-disabled. S6 adds only local WAMR
fixture imports, `koma_host.html_parse`, `html_select`, `html_attr`,
`html_text`, and `html_close`, behind `experimentalHtmlFixture`. The host parses
only deterministic fixture HTML, returns host-owned integer descriptors, accepts
only `article.manga-card`, `h3.title`, and `a.chapter`, exposes only `data-id`,
`data-page-id`, and text, bounds descriptor/string counts, and denies unsupported
selectors/attributes. It does not add WebView, JavaScript, public source
parsing, product runtime parsing, or real network behavior.

Future source settings/auth/secret reference metadata is also design-only and
documented in `source-package/SOURCE_SETTINGS_AUTH_BOUNDARY.md`. Its fixtures
keep `network=false`, reject `koma_host.http_request`, and do not contain real
credentials or executable login/logout/status/session behavior.

S7 adds local WAMR/tooling proof for `get_settings` and
`get_image_request`. The Rust fixture now returns safe setting descriptors plus
host-owned image request references (`headersRef`, `credentialsRef`, and
`sessionRef`) and a controlled `fixture-image:` URL token. It still performs no
real network I/O and does not expose raw cookie, token, password, or
`Authorization` values.

Future resource limits, cancellation, and timeout policy is design/tooling-only
and documented in
`source-package/RESOURCE_LIMITS_CANCELLATION_BOUNDARY.md`. Its fixtures keep
`network=false`, require the existing `koma_host.check_cancel` import, and
statically reject oversized budgets, invalid timeouts, disabled cancellation,
leaks, executable hooks, and product-runtime flags without executing WASM.

The HarmonyOS internal-dev ingestion plan is also design/tooling-only and is
documented in `source-package/HARMONYOS_INTERNAL_DEV_INGESTION_PLAN.md`. Its
fixtures keep ingestion local-only, require app-private staging before
validation, preserve `network=false` and closed imports, and reject source
market, remote install, built-in source, direct picker execution, raw diagnostic
leaks, and product-runtime drift.

The local source package trust, provenance, and signature boundary is
design/tooling-only and documented in
`source-package/TRUST_PROVENANCE_BOUNDARY.md`. Its fixtures keep signing,
trust-store, crypto verification, product UI/runtime, source market, remote
install, built-in sources, and network out of scope while statically rejecting
trust-order drift, unsigned release acceptance, downgrade/duplicate overwrite
drift, logging leaks, `network=true`, and HTTP import drift.

Canonical manifest/signature payload fixtures for future trust gates are
design/tooling-only and documented in
`source-package/CANONICAL_SIGNATURE_PAYLOAD_BOUNDARY.md`. They define
deterministic JSON bytes and public metadata bindings without signing,
verification, keys, trust stores, product runtime/UI, network, or HTTP.

Tamper and checksum-pin mismatch fixtures for future package trust gates are
design/tooling-only and documented in
`source-package/TAMPER_CHECKSUM_PIN_BOUNDARY.md`. They statically reject
archive, manifest, WASM, package identity, signer identity, canonical payload,
signature-block placeholder, scope, diagnostic leak, and validator drift without
signing, verification, keys, trust stores, product runtime/UI, network, or HTTP.

Signer/key rotation, revocation, expiration, and compatibility fixtures for
future package trust gates are design/tooling-only and documented in
`source-package/SIGNER_ROTATION_REVOCATION_BOUNDARY.md`. They statically reject
identity drift, unapproved rotation, revocation hits, stale or future-dated
metadata, compatibility drift, closed-runtime drift, diagnostic leak flags, and
validator execution drift without signing, verification, keys, trust stores,
product runtime/UI, network, or HTTP.

Duplicate/update/downgrade/rollback/removal fixtures for future local package
lifecycle policy are design/tooling-only and documented in
`source-package/LIFECYCLE_UPDATE_ROLLBACK_BOUNDARY.md`. They statically reject
normalized id collisions, duplicate version drift, ambiguous version ordering,
unapproved downgrades, unsafe rollback targets, removal cleanup category drift,
closed-runtime drift, and real install/delete/store mutation claims without
product runtime/UI, network, HTTP, registries, signing, verification, trust
stores, or deletion.

The spike validates this path on Linux:

```text
C fixture source -> clang wasm32 -> WAMR interpreter host -> KOMA JSON envelope
```

## Run

```sh
bash tools/wasm-runtime-spike/run.sh
```

By default the script writes build products, WAMR cache, and logs under:

```text
.hermes-artifacts/wasm-runtime-spike/
```

For controller runs, point it at the assigned artifact directory:

```sh
KOMA_WASM_SPIKE_ARTIFACT_DIR=/home/gamer/git/Koma/.hermes-artifacts/20260521-115841/lane3c-wasm-runtime-spike \
  bash tools/wasm-runtime-spike/run.sh
```

The script pins WAMR to `WAMR-2.3.0` commit
`c7b2db18329f849b81568b94e72ddd0b20f431a5`. If no `WAMR_ROOT_DIR` is provided,
it clones that tag into the ignored artifact cache. WAMR source is not vendored
or committed to this repository.

Expected evidence in the log:

```text
ADD_OK add(2,3)=5
INIT_OK manifest accepted
SOURCE_API_OPERATION search ok:true magic=KOMA flags=1 len=...
SOURCE_API_OPERATION get_manga ok:true magic=KOMA flags=1 len=...
SOURCE_API_OPERATION get_chapters ok:true magic=KOMA flags=1 len=...
SOURCE_API_OPERATION get_pages ok:true magic=KOMA flags=1 len=...
SOURCE_API_OPERATION get_listings ok:true magic=KOMA
SOURCE_API_OPERATION get_manga_list ok:true magic=KOMA
SOURCE_API_HTTP_FIXTURE_ALLOWED ok:true host=fixture.koma.local networkPerformed=false
SOURCE_API_HTTP_FIXTURE_DENIED_HOST ok:true reason=host_not_allowed
SOURCE_API_HTTP_FIXTURE_DENIED_CREDENTIAL_HEADER ok:true reason=credential_header_denied
SOURCE_API_HTML_FIXTURE_PARSE_ALLOWED ok:true descriptor=document
SOURCE_API_HTML_FIXTURE_SELECT_ALLOWED ok:true selector=article.manga-card
SOURCE_API_HTML_FIXTURE_ATTR_ALLOWED ok:true attr=data-id
SOURCE_API_HTML_FIXTURE_TEXT_ALLOWED ok:true
SOURCE_API_HTML_FIXTURE_UNSUPPORTED_SELECTOR_DENIED ok:true selector=script
SOURCE_API_HTML_FIXTURE_UNSUPPORTED_ATTR_DENIED ok:true attr=href
SOURCE_API_OPERATION get_home ok:true magic=KOMA
SOURCE_API_OPERATION get_filters ok:true magic=KOMA
SOURCE_API_OPERATION get_settings ok:true magic=KOMA
SOURCE_API_OPERATION get_image_request ok:true magic=KOMA
SOURCE_API_IMAGE_REQUEST_REFS ok:true headersRef=true credentialsRef=true sessionRef=true rawSecrets=false networkPerformed=false
SOURCE_API_RUNTIME_SMOKE_PASS
WAMR_SPIKE_PASS
```

The host runner validates:

- WAMR initializes, loads, instantiates, calls, and disposes the module.
- `add(2,3)` returns `5`.
- A JSON request buffer is copied into wasm memory.
- `koma_source_search(ptr,len)`, `koma_source_get_manga(ptr,len)`,
  `koma_source_get_chapters(ptr,len)`, `koma_source_get_pages(ptr,len)`,
  `koma_source_get_listings(ptr,len)`, `koma_source_get_manga_list(ptr,len)`,
  `koma_source_get_home(ptr,len)`, `koma_source_get_filters(ptr,len)`,
  `koma_source_get_settings(ptr,len)`, and
  `koma_source_get_image_request(ptr,len)` return result buffers with `KOMA`
  magic, flags, payload length, and UTF-8 JSON envelopes.
- `koma_source_free(ptr)` is called after the host reads the payload.

## Rust Fixture Spike

The Rust fixture is SDK-side only and uses the same host runner and ABI:

```text
Rust no_std SDK rlib -> Rust no_std fixture source -> rustc wasm32-unknown-unknown -> WAMR interpreter host -> KOMA JSON envelope
```

Run it separately from the C fixture:

```sh
bash tools/wasm-runtime-spike/run-rust-fixture.sh
```

It has no Cargo dependencies and writes generated SDK rlib/wasm/log/JSON
artifacts under the ignored artifact directory. The local `rust-sdk` crate is a
test-only, self-authored Koma boundary for the fixture's tiny ABI surface:
host logging/cancellation wrappers, provisional source-author request types,
operation helpers, KOMA result buffer/envelope writing, and the
`hostHints.network=false` convention. For S5, the fixture also imports
`koma_host.http_request` only in the local WAMR host runner. The
`listing:http-fixture` manga-list path proves one allowed static fixture request
and denied host/secret-header cases; all responses remain deterministic,
`networkPerformed=false`, and product/Harmony runtime networking stays out of
scope. For S6, `listing:html-fixture` also proves host-owned HTML
parse/select/attr/text descriptors against static fixture HTML plus denied
unsupported selector/attribute cases. The fixture exports `add`,
`koma_source_init`, the four core source operation exports, the S4 browse
operation exports, and `koma_source_free`, and returns test envelope shapes with
`Fixture Series`, deterministic listing/home/filter ids, and
`hostHints.network: false`.

The Rust SDK shape is provisional and tooling-only. Source fixture code
implements a small `Source` trait and leaves ABI request reads, cancellation,
response envelope construction, and result-buffer headers to SDK helpers. The
direct `rustc` build pins `target-cpu=mvp` and disables `reference-types` so the
generated wasm remains compatible with the current WAMR smoke host.

The source-package tooling can also build this SDK-backed wasm into an ignored
artifact directory, generate a local/test-only package manifest that points at
that exact wasm, and validate the manifest hash, size, ABI, imports, network
flag, and no-market/no-remote-install boundary:

```sh
python3 tools/wasm-runtime-spike/source-package/build-rust-sdk-source-package.py \
  --artifact-dir /path/to/artifacts/source-package-build
```

## HarmonyOS NAPI Next Step

Keep this isolated from production app behavior. The next narrow integration
step is a native sample module exposing only `hello`, `add`, and
`runJsonCall(wasmBytes, manifestJson, functionName, requestJson)` through
Node-API. That native module should reuse the same ABI flow demonstrated here:
per-call WAMR init/load/instantiate, host-owned request buffers, KOMA envelope
validation, response free, and teardown. Do not add source marketplace UI,
remote source indexes, or real network host imports in that slice.
