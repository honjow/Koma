# Koma Source Package Trust Boundary

This note is a design-only trust/provenance boundary for future local
`*.koma-source.zip` WASM source packages. It records the security decisions and
gates that must exist before any product ingestion, registration, or runtime
loading can be enabled.

It does not implement signing, verification code, key material, product install,
HarmonyOS UI, source discovery, remote install, a public package index, a source
market, built-in sources, HTTP, WebView workflows, WAMR vendor changes, generated
archives, generated wasm, HAP output, or Rust target directories.

Koma's boundary remains private and local: source packages are user-controlled
files or privately distributed files. This model must not assume a public
marketplace, centralized public source catalog, remote install URL, or public
revocation/index service.

## Threat Model

Future ingestion must fail closed against these package-level risks:

- Tampered archive or wasm after packaging.
- Duplicate package ids, normalized id collisions, and conflicting versions.
- Downgrade to an older vulnerable package, or rollback to a package no longer
  trusted.
- Unknown or untrusted package author identity.
- Malicious or drifting host imports, including a package that declares
  `network=false` while importing future network functions.
- Network policy drift if a future ABI enables HTTP: unexpected schemes, hosts,
  methods, redirects, credentials, cookies, cache sharing, or raw secret access.
- ZIP and extraction attacks already covered by
  `HARMONYOS_ARCHIVE_INGESTION_BOUNDARY.md`: traversal, absolute paths, symlinks,
  duplicates, unexpected entries, hidden/generated directories, and size limits.
- Local file path leakage through manifests, reports, runtime errors, source
  logs, crash traces, or support bundles.
- Log leakage of credentials, cookies, signatures, public/private key material,
  full manifests, request/response bodies, and user-selected file locations.

## Trust Options

These are future product/security options, not a current decision:

- Local unsigned/dev-only: accepted only in explicit developer mode or test
  builds, never silently promoted as trusted product packages.
- Checksum-pinned private package: the user or private admin records an expected
  archive or wasm digest before import; Koma accepts only an exact digest match.
- Signature-pinned private key: Koma trusts packages signed by a user-approved or
  app-configured public key/key id, with package id/version/wasm hash bound into
  the signed payload.
- Enterprise/private trust store: a private deployment controls approved keys,
  package ids, compatibility policy, revocation data, and update rules without
  exposing a public source market.

Public marketplace assumptions are out of scope for now. Any design that
requires public search, public ranking, remote install, public package index
sync, public package metadata service, or bundled third-party source catalog is
outside this boundary.

## Future Manifest And Archive Fields

The current fixture manifest is not required to add these fields yet. They are
candidate design fields that a future trust model may need:

- `package.id`, `package.version`, and manifest `schemaVersion`.
- `runtime.abi` and `runtime.hostAbi` compatibility.
- `runtime.wasm.sha256`, wasm size, and package-local wasm path.
- Optional signature block location, for example
  `signatures/koma-source-signature.json`.
- Signer id and key id, distinct from a free-text author field.
- Signed payload digest or manifest digest, with deterministic canonicalization
  rules chosen before implementation.
- `createdAt` and `expiresAt` for package/signature freshness.
- Minimum/maximum app version, source ABI, host ABI, and package schema
  compatibility.
- Optional trust policy metadata for private deployments, such as allowed
  package id prefixes or approved signing keys.

No private keys, raw certificates used for app signing, credentials, cookies, or
full trust-store dumps should ever be embedded in source packages.

## Verification Order

Future product ingestion must preserve this order and must fail closed:

1. Copy the user-selected local archive into app-private staging.
2. Validate archive safety before extraction: suffix/magic, total size, entry
   count, duplicate names, traversal, absolute paths, symlinks, unexpected
   entries, hidden/generated directories, required entries, and per-entry size.
3. Extract only to a temporary app-private staging directory.
4. Parse the manifest and validate schema, package id/version, paths, settings
   defaults, content policy flags, and compatibility fields.
5. Validate wasm magic/version, size, package-local path, and sha256.
6. Verify trust/provenance according to the selected future option: dev-only
   unsigned gate, checksum pin, signature pin, or private trust store.
7. Validate ABI, required imports, host import allowlist, `network` permission,
   and any future network policy before runtime handoff.
8. Atomically promote the staged package and register metadata only after every
   gate passes.
9. On any failure, delete staging and partial promoted state; do not register,
   load, execute, or leave a package half-trusted.

Runtime loading must not be allowed to bypass ingestion gates by executing a
wasm file directly from a picker URI, downloads path, archive filename, rawfile
asset, or unregistered staging directory.

## Revocation, Updates, Removal, Rollback

Future product work must decide these before enabling install/runtime:

- Revocation source: local user blocklist, private admin trust store, package id
  denylist, key id denylist, checksum denylist, or signature expiration.
- Revocation behavior: disable at startup, disable before runtime handoff, hide
  from source selection, keep metadata for audit, and require explicit user/admin
  action before re-enable.
- Update rules: whether package id must be stable across versions, whether a
  signer/key must match the installed package, whether key rotation is allowed,
  and how ABI/app compatibility gates interact with updates.
- Downgrade rules: reject by default unless explicitly approved by the same trust
  authority; record the reason if a downgrade is permitted.
- Rollback rules: keep the previous validated package only when it remains
  trusted and compatible; never roll back to a revoked key, revoked digest, or
  expired package.
- Duplicate ids: reject normalized id collisions; decide whether exact duplicate
  id/version/digest imports are idempotent or require explicit replacement.
- Removal: delete package files, package metadata, caches, sessions, settings,
  credential references, and install reports according to separately approved
  cleanup rules.

This boundary intentionally avoids a public revocation service. Private
revocation may be local, file-based, or admin-managed in a future design.

## Logging And Redaction

Validation and runtime reports should record reason codes and minimal evidence,
not sensitive payloads. Logs and artifacts must avoid:

- Private keys, signing material, raw signatures, full certificates, or trust
  store contents.
- Credentials, cookies, authorization headers, tokens, request bodies, response
  bodies, and source settings containing secrets.
- Full local paths, picker URIs, usernames, archive filenames from user storage,
  and app-private absolute package paths.
- Full manifests unless an explicit developer diagnostic mode is enabled.
- Full wasm bytes, generated archives, or copied packages outside artifact
  directories.

Developer mode diagnostics may include expanded manifests or signature metadata
only after redaction and only in local artifacts, never in chat output or product
support logs by default.

## Mapping To Current Validators

Already covered by current tooling:

- `package-source-archive.py` validates archive suffix, entry safety, staged
  extraction, expected entries, manifest parseability, wasm hash/size, closed
  imports, `network=false`, and disabled public-index/marketplace/built-in/
  remote-install flags.
- `validate-archive-negative-fixtures.py` rejects traversal, absolute paths,
  duplicate entries, symlinks, unexpected entries, network/http import drift,
  wasm hash mismatch, and missing required entries.
- `validate-source-package.py --build-rust-fixture` validates required manifest
  fields, wasm magic/version/hash/size, exports/imports, capabilities, settings
  defaults, and `network=false`.
- `run-source-archive-smoke.py` proves archive validation and staged extraction
  happen before Linux WAMR execution.
- `validate-http-boundary.py` keeps HTTP design-only and verifies the current
  source-package validator still rejects `network=true` and
  `koma_host.http_request`.

Missing future tests before product enablement:

- Trust option gates for unsigned/dev-only, checksum-pinned, signature-pinned,
  and private trust-store modes.
- Canonical manifest/signature payload tests and tampered signature/hash
  negative fixtures.
- Duplicate package id/version, normalized id collision, update, downgrade,
  rollback, removal, and revocation fixtures.
- Expired package/signature compatibility fixtures.
- Log redaction fixtures for paths, credentials, cookies, signatures, key ids,
  full manifests, and runtime errors.
- HarmonyOS app-private staging, promotion, cleanup, and startup revocation
  tests.

## Current Validation Commands

Use a fresh artifact directory for this lane:

```sh
ARTIFACT=/home/gamer/git/Koma/.hermes-artifacts/20260521-213000/lane3s-source-package-trust-boundary

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
