# Koma Local WASM Source Package Boundary

This directory is a tooling-only fixture for the future Koma WASM source
package shape. It is not product UI, a source repository, a marketplace, a
remote installer, or a built-in source list.

For the consolidated current runtime/package/archive boundary, see
`SOURCE_RUNTIME_BOUNDARY.md`.

For the candidate Source API v0.1/v0.2 operation, model, capability, and JSON
fixture design, see
`SOURCE_API_V0.md`.

For the design-only future HarmonyOS source archive ingestion boundary, see
`HARMONYOS_ARCHIVE_INGESTION_BOUNDARY.md`.

For the design-only future HarmonyOS internal-dev staging/promotion ingestion
plan, see `HARMONYOS_INTERNAL_DEV_INGESTION_PLAN.md`.

For the design-only future local source package trust/provenance boundary, see
`SOURCE_PACKAGE_TRUST_BOUNDARY.md`.

For the stricter design/tooling-only trust, provenance, and signature boundary
validated by local JSON fixtures, see `TRUST_PROVENANCE_BOUNDARY.md`.

For the design/tooling-only canonical manifest/signature payload fixture
boundary for future trust gates, see `CANONICAL_SIGNATURE_PAYLOAD_BOUNDARY.md`.

For the design/tooling-only tamper and checksum-pin mismatch fixture boundary
for future trust gates, see `TAMPER_CHECKSUM_PIN_BOUNDARY.md`.

For the design/tooling-only signer/key rotation, revocation, expiration, and
compatibility fixture boundary for future trust gates, see
`SIGNER_ROTATION_REVOCATION_BOUNDARY.md`.

For the design/tooling-only future source settings, auth, and secret reference
schema boundary, see `SOURCE_SETTINGS_AUTH_BOUNDARY.md`.

For the design/tooling-only future resource limit, cancellation, and timeout
boundary, see `RESOURCE_LIMITS_CANCELLATION_BOUNDARY.md`.

For the design/tooling-only future image/page loading strategy boundary, see
`IMAGE_PAGE_LOADING_BOUNDARY.md`.

For the design/tooling-only future duplicate/update/downgrade/rollback/removal
lifecycle fixture boundary, see `LIFECYCLE_UPDATE_ROLLBACK_BOUNDARY.md`.

The fixture keeps the useful package lessons from source index layouts such as
per-source metadata, icon paths, settings, capabilities, and runtime limits,
while staying aligned with Koma's current runtime evidence:

```text
Rust SDK source -> wasm32-unknown-unknown -> WAMR sandbox -> explicit host imports
```

## Source Author Docs

For source authors working against the current Rust SDK and Source API v0.2
fixture, the following docs live alongside this README. They are local/dev
source-author documentation only — not a source market, remote install flow,
built-in source catalog, product UI, real network, or trust/signing workflow.

- [`SOURCE_AUTHOR_STABILIZATION_AUDIT.md`](SOURCE_AUTHOR_STABILIZATION_AUDIT.md)
  — current author-facing contract, gaps, and prioritized stabilization slices.
- [`SOURCE_AUTHOR_QUICKSTART.md`](SOURCE_AUTHOR_QUICKSTART.md) — minimal Rust
  SDK authoring workflow against the v0.2 fixture surface.
- [`SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md`](SOURCE_AUTHOR_COMPATIBILITY_CHECKLIST.md)
  — pre-flight checklist of contract items to verify before the evidence suite.
- [`SOURCE_AUTHOR_FIXTURE_SDK_PARITY.md`](SOURCE_AUTHOR_FIXTURE_SDK_PARITY.md)
  — map from source-author SDK concepts to the fixtures and validators that
  prove each one.
- [`SOURCE_RUNTIME_PRODUCTIZATION_CHECKPOINT.md`](SOURCE_RUNTIME_PRODUCTIZATION_CHECKPOINT.md)
  — post-S18A–S18I checkpoint summarizing stabilized surfaces, preserved
  non-goals, and the next productization decision options.

## Manifest Boundary

`manifest.example.json` declares only a local test package:

- package metadata: id, name, version, language, type, NSFW flag, author,
  description, and an optional icon placeholder.
- runtime metadata: `koma-source-abi-v0.1`, fixture-only
  `koma-host-v0.1-fixture-http`, wasm path, wasm sha256, max memory pages, max
  payload bytes, max wasm bytes, and required host imports.
- capabilities: the four core fixture operations are enabled (`search`,
  `detail`, `chapterList`, and `pageList`); image URL/network behavior remains
  disabled.
- settings schema: typed placeholder settings with no credentials.
- permissions: `network` is false. `koma_host.http_request` is permitted only
  through `experimentalHttpFixture`, constrained to `fixture.koma.local`, `GET`,
  bodyJson/bodyText responses, static fixture data, and
  `networkPerformed=false`. `koma_host.html_parse`, `html_select`, `html_attr`,
  `html_text`, and `html_close` are permitted only through
  `experimentalHtmlFixture`, constrained to deterministic fixture HTML, the
  selector subset `article.manga-card`/`h3.title`/`a.chapter`, the attributes
  `data-id`/`data-page-id`, bounded strings/descriptors, and
  `networkPerformed=false`.
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

To validate the candidate Source API v0.2 JSON metadata/request/response
fixture corpus:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures
```

The script writes `source-api-fixtures-report.json` under the artifact
directory. It accepts valid metadata/request/response envelopes for
`SourceInfo`, `SourceCapabilities`, `search`, `get_manga`, `get_chapters`,
`get_pages`, `get_listings`, `get_manga_list`, `get_home`, `get_filters`,
`get_settings`, and `get_image_request`, and asserts that invalid fixtures are
rejected with deterministic local reasons. The validator is stdlib-only, does
not invoke WAMR, and does not perform network. Current Source API fixtures must
keep `hostHints.network=false` and must not contain raw remote URLs, local
paths, picker/content URIs, app-private paths, cookies, tokens, authorization
headers, or passwords. The S5 `httpFixtureRequest` fixtures are the only
exception for the static `https://fixture.koma.local/...` URL and exist solely
to validate the local WAMR host-import policy shape; they still require
`networkPerformed=false`.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-package.py \
  --manifest tools/wasm-runtime-spike/source-package/manifest.example.json \
  --artifact-dir /path/to/artifacts/source-package \
  --build-rust-fixture
```

The script writes `source-package-validation.json` under the artifact directory.
It validates required fields, scope rules, sha256, wasm magic/version, declared
imports, exported fixture functions, optional `koma_source_info` discovery,
capabilities, settings defaults, `network=false`, and the explicit
`experimentalHttpFixture`/`experimentalHtmlFixture` gates. With
`--build-rust-fixture` it also parses the WAMR smoke JSON and records functional
evidence that
`source_info` returns Source API v0.2 metadata, core, browse, settings, and
image request capabilities are true, future capabilities are false, browse
operations return the expected listing/home/filter/page shapes,
`get_settings` returns only safe schema/reference descriptors,
`get_image_request` returns host-owned `headersRef`, `credentialsRef`, and
`sessionRef` values with no raw credential headers, `hostHints.network=false`,
and unknown operations reject instead of falling back to search. It also
requires S5 controlled HTTP fixture evidence: allowed static host request,
denied host, denied credential header, and no real network. S6 additionally
requires controlled HTML fixture evidence: parse/select/attr/text pass,
unsupported selector/attribute deny, and no real network.

To exercise the Rust-SDK-backed package build boundary:

```sh
python3 tools/wasm-runtime-spike/source-package/build-rust-sdk-source-package.py \
  --artifact-dir /path/to/artifacts/source-package-build
```

The build report is written to
`rust-sdk-source-package-build-report.json` under the artifact directory and
includes the built wasm sha256/size, generated manifest path, validator report
path, and gate results for `packageId`, fixture HTTP host ABI,
`network=false`, exact fixture-gated host imports, wasm hash/size, and disabled
public index/marketplace/built-in/remote-install flags.

## Trust/Provenance Boundary

`trust-provenance-boundary.example.json` defines a design/tooling-only trust,
provenance, and signature policy example for future local source packages. It
does not implement signing, key generation, trust stores, cryptographic
verification, product UI, product runtime loading, remote install, source
markets, built-in sources, or network.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-trust-provenance-boundary.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/trust-provenance-fixtures \
  --artifact-dir /path/to/artifacts/trust-provenance-boundary
```

The validator writes `trust-provenance-boundary-report.json` under the artifact
directory. It loads local JSON only, performs no network I/O, executes no WASM,
and rejects unsigned release acceptance, missing or misordered trust checks,
market/remote/built-in source drift, silent downgrade or duplicate overwrite,
raw key/signature/path/secret/cookie logging, `network=true`, HTTP import drift,
non-fail-closed policy, and product runtime/UI claims.

## Canonical Signature Payload Boundary

`canonical-signature-payload.example.json` defines deterministic canonical JSON
payload bytes for future checksum/signature gates. It binds package id/version,
source ABI, host ABI, archive digest/size, canonical manifest digest/size, WASM
path/digest/size, `network=false`, closed host imports, public provenance
metadata, signer id, key id, and freshness fields. It does not implement
signing, verification, key generation, certificates, trust stores, product
runtime/UI, network, or HTTP.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-canonical-signature-payload.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/canonical-signature-fixtures \
  --artifact-dir /path/to/artifacts/canonical-signature-payload
```

The validator writes `canonical-signature-payload-report.json` under the
artifact directory. It loads local JSON only, detects duplicate keys, rejects
non-object payload models, unknown canonicalization versions, non-canonical JSON
settings, missing package/archive/manifest/WASM bindings, payload and manifest
digest mismatch, raw manifest text, `network=true`, HTTP import drift, raw
key/header/path/signature/byte leaks, product runtime/UI drift, source market,
remote install, built-in source drift, and executable validator drift.

## Tamper And Checksum Pin Boundary

`tamper-checksum-pin.example.json` makes future fail-closed behavior concrete
for archive, manifest, WASM, package id/version, signer id/key id, canonical
payload, and signature-block status mismatches. It stays static and does not
implement signing, verification, key generation, certificates, trust stores,
product ingestion, product runtime/UI, network, HTTP, or WebView behavior.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-tamper-checksum-pin.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/tamper-checksum-fixtures \
  --artifact-dir /path/to/artifacts/tamper-checksum-pin
```

The validator writes `tamper-checksum-pin-report.json` under the artifact
directory. It loads local JSON only, uses stdlib hashing only for fixture
consistency, rejects checksum/signature/payload/identity mismatch, stale
manifest or WASM metadata, unsigned release acceptance, missing or malformed
signature-block placeholder status, `network=true`, HTTP import drift,
market/remote/built-in source drift, product runtime/UI drift, diagnostic leaks,
raw archive/WASM bytes, and validator subprocess/network/executable hook drift.

## Signer Rotation And Revocation Boundary

`signer-rotation-revocation.example.json` defines static future package trust
decisions for signer/key identity, key rotation, revocation, expiration,
freshness, and compatibility checks. It stays design/tooling-only and does not
implement signing, verification, key generation, certificates, trust stores,
revocation stores, product runtime/UI, network, HTTP, remote install, source
markets, or built-in sources. `signatureMetadata.realVerificationPerformed`
must be `false` or absent because this lane must not claim real signature
verification.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-signer-rotation-revocation.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/signer-rotation-fixtures \
  --artifact-dir /path/to/artifacts/signer-rotation-revocation
```

The validator writes `signer-rotation-revocation-report.json` under the artifact
directory. It loads local JSON only and rejects display text used as trust
identity, signer/key mismatch, unapproved signer change, unapproved key
rotation, cross-package or stale rotation policy, package id drift, downgrade
without explicit approval, static revocation hits, expired or not-yet-valid
metadata, real signature verification claims, ambiguous timestamps,
incompatible source/host/app bounds, unknown policy versions, `network=true`,
HTTP import drift, product runtime/UI drift, market/remote/built-in source
drift, diagnostic leaks, and validator execution drift.

## Lifecycle Update, Downgrade, Rollback, And Removal Boundary

`lifecycle-update-rollback.example.json` defines static future lifecycle
decisions for duplicate ids, normalized collisions, duplicate versions, updates,
downgrades, rollback, and removal planning. It stays design/tooling-only and
does not implement install state, deletion, rollback, registries, signing,
verification, trust stores, revocation stores, product runtime/UI, network,
HTTP, remote install, source markets, or built-in sources.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-lifecycle-update-rollback.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/lifecycle-update-fixtures \
  --artifact-dir /path/to/artifacts/lifecycle-update-rollback
```

The validator writes `lifecycle-update-rollback-report.json` under the artifact
directory. It loads local JSON only and rejects non-canonical package ids,
silent normalized collisions, duplicate id/version digest or identity drift,
ambiguous version ordering, package-id drift across update, unapproved or stale
downgrades, rollback to revoked/expired/incompatible/unknown artifacts,
rollback gate bypass, unsafe removal categories, runtime closure drift,
diagnostic leak flags, validator execution drift, and real install/delete/store
mutation claims.

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

## Settings/Auth Boundary

`settings-auth.example.json` defines a non-executable schema example for future
settings metadata, host-owned secret references, design-only auth operations,
credential/cookie policy, and structured auth errors. It does not store
credentials, execute login/logout/status/session, enable product UI, or enable
HTTP/network.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-settings-auth-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/settings-auth-fixtures \
  --artifact-dir /path/to/artifacts/settings-auth-fixtures
```

The validator writes `settings-auth-fixtures-report.json` under the artifact
directory. It loads local JSON only, performs no network I/O, keeps
`network=false`, rejects `koma_host.http_request`, rejects executable auth
operations, and checks fixture strings for raw credential/header/cookie values
and local/picker/app-private path leaks without echoing leaked values into the
report.

## Resource Limits/Cancellation Boundary

`resource-limits.example.json` defines a design-only policy example for future
bounded source execution. It keeps `network=false`, exact
`koma_host.log`/`koma_host.check_cancel` imports, required cancellation polling,
per-operation wall-clock timeout budgets, result/list/module budgets, structured
`TIMEOUT`/`CANCELLED`/`RESOURCE_LIMIT_EXCEEDED` errors, and redacted logging.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-resource-limit-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/resource-limit-fixtures \
  --artifact-dir /path/to/artifacts/resource-limit-fixtures
```

The validator writes `resource-limit-fixtures-report.json` under the artifact
directory. It loads local JSON only, performs no network I/O, executes no WASM,
accepts the valid design fixture, and rejects oversized budgets, invalid
timeouts, disabled or omitted cancellation, forbidden imports, `network=true`,
remote URL/path/credential leaks, unsafe log bodies, and executable/product
runtime flags.

## Image/Page Loading Boundary

`image-page-loading.example.json` defines a design/tooling-only strategy for
future page descriptors, host-loaded placeholder/test images, source-resolved
image request gating, cache identity, header policy, structured image errors,
stale cache states, and network gates. It keeps current runtime behavior closed:
`network=false`, no HTTP import, no remote URLs, no raw local/picker/app-private
paths, no raw header values, and no product image loader.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-image-page-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/image-page-fixtures \
  --artifact-dir /path/to/artifacts/image-page-fixtures
```

The validator writes `image-page-fixtures-report.json` under the artifact
directory. It loads local JSON only, performs no network I/O, executes no WASM,
accepts only current placeholder/test descriptors, and rejects remote image
URLs, path leaks, credential/header leaks, unsafe cache key material, missing
opaque ids, HTTP/network drift, current image request descriptors, and
product-runtime image loading flags.

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
`WAMR_SPIKE_PASS`, `SOURCE_API_RUNTIME_SMOKE_PASS`, all four
`SOURCE_API_OPERATION ... ok:true` lines, `Fixture Series`, `HOST_LOG`,
`HOST_CHECK_CANCEL`, and `hostHints.network=false` evidence. All archives,
extracted files, wasm binaries, host builds, caches, logs, and reports remain
artifact outputs.

To run the full source-runtime evidence chain (direct Rust/WAMR fixture,
archive smoke, operation-surface parity, source API v0.2 JSON fixture
validator) in one command:

```sh
python3 tools/wasm-runtime-spike/source-package/run-source-runtime-evidence-suite.py \
  --artifact-dir /path/to/artifacts/source-runtime-evidence-suite
```

The wrapper writes `source-runtime-evidence-suite-report.json` under the
artifact directory with redacted commands, per-step report paths, and the
parity-confirmed v0.2 operations covered. It exits 0 only when every step
passes and every expected per-step report file is present.

To prove the suite's fail-closed behavior is repeatably testable as tooling
(not just QA evidence), the negative-contract validator copies the wrapper and
redaction helper under the artifact directory, patches the copied wrapper to
replace its first step with a local stub that exits nonzero without writing
its expected report, runs the patched copy, and asserts the suite exited
nonzero, the suite report status is `FAIL`, the suite findings include both a
`step exit` entry and a `missing expected report` entry for the stubbed step,
and the matching `expectedReportsPresent` entry is `false`. The validator
performs no repository mutation; all copies, patches, suite outputs, logs, and
its own report stay under the provided `--artifact-dir`:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-evidence-suite-negative-contract.py \
  --artifact-dir /path/to/artifacts/evidence-suite-negative-contract
```

The validator writes `evidence-suite-negative-contract-report.json` under the
artifact directory. The negative suite run reuses the artifact-local WAMR cache
by default; pass `--shared-wamr-root /path/to/wasm-micro-runtime` to reuse an
existing checkout and skip an extra clone.

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

## HarmonyOS Internal-Dev Ingestion Plan

`HARMONYOS_INTERNAL_DEV_INGESTION_PLAN.md` maps the existing local archive
validation gates to a future app-private copy, staging, validation, atomic
promote, and register flow. It is still non-release and design-only: no
HarmonyOS product runtime, UI, picker implementation, package registry, storage
writes, HTTP, source market, remote install, or built-in source behavior is
implemented here.

```sh
python3 tools/wasm-runtime-spike/source-package/validate-harmonyos-ingestion-plan.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/harmonyos-ingestion-fixtures \
  --artifact-dir /path/to/artifacts/harmonyos-ingestion-plan
```

The validator writes `harmonyos-ingestion-plan-report.json` under the artifact
directory. It loads local JSON only, performs no network I/O, executes no WASM,
and checks that the plan remains design-only/internal-dev-only, local archive
only, copied to app-private staging before validation, ordered through archive,
manifest, wasm hash/size, trust, import/network, settings/auth/resource/image,
and promote/register gates. Invalid fixtures prove drift is rejected for remote
install, source market, `network=true`, direct picker execution, missing gates,
raw path/secret logging, product runtime, and built-in sources.

This fixture intentionally does not add remote source index sync, source market
UI, real manga sources, APK plugins, WebView+JS runtime behavior, signing
material, WAMR source, HAP output, or Rust target directories to git.
