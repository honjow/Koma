# Koma Source Package Trust, Provenance, And Signature Boundary

Status: design/tooling-only. This boundary applies only to future local
`*.koma-source.zip` WASM source package research under `tools/wasm-runtime-spike/`.
It is not product ingestion, runtime loading, UI, device install, a trust store,
or a signing implementation.

Current posture stays closed: no source market, no public index, no remote
install, no built-in sources, no product runtime/UI, no real HTTP/network, and
no cryptographic verification against keys. The validator in this directory is a
stdlib-only local JSON checker; it does not create keys, verify signatures,
execute WASM, run subprocesses, or perform network I/O.

## Threat Model

Future local package ingestion must fail closed against:

- Tampered archive content, manifest content, or WASM bytes.
- Duplicate package ids, normalized id collisions, conflicting versions, and
  duplicate id/version imports that silently overwrite installed state.
- Downgrades to older vulnerable packages, rollback to untrusted packages, and
  missing revocation decisions.
- Unknown or untrusted authors where free-text author metadata is mistaken for a
  trust identity.
- Import, ABI, and network drift, including `network=true` or
  `koma_host.http_request` appearing before a future network policy is approved.
- ZIP attacks: traversal, absolute paths, symlinks, duplicate names, unexpected
  entries, hidden/generated directories, oversized entries, and zip bombs.
- Local path leakage from picker URIs, user paths, archive filenames, staging
  paths, app-private paths, reports, crashes, or source logs.
- Log leakage of keys, raw signatures, credentials, cookies, full manifests, and
  large request/response bodies.

## Trust Modes

These are options for future product/security design, not a UX decision:

- Unsigned local/dev-only: allowed only behind an explicit developer gate and
  never silently accepted as a release package.
- Checksum-pinned private packages: a user or private administrator pins an
  expected archive digest and/or WASM digest before import.
- Signature-pinned private keys: Koma accepts packages signed by a user-approved
  or app-configured key id, with package id, version, manifest digest, and WASM
  digest bound into the signed payload.
- Enterprise/private trust store: a private deployment controls approved keys,
  package ids, compatibility, revocation, update, and removal policy without a
  public package catalog.

## Future Metadata

Future manifest/archive metadata may need:

- `schemaVersion`, `package.id`, `package.version`, source ABI, host ABI, app
  compatibility, and package schema compatibility.
- Archive digest and size gates, for example `archive.sha256` and
  `archive.sizeBytes`, captured before any trust decision.
- Manifest digest and size gates, for example `manifest.sha256` and
  `manifest.sizeBytes`, captured after manifest parse/schema validation and
  before any trust decision.
- Package-local WASM path, WASM byte size, and WASM sha256.
- Signer id and key id, distinct from display author text.
- Signature block location, for example
  `signatures/koma-source-signature.json`.
- Deterministic signed payload/canonical manifest rules.
- `createdAt` and `expiresAt` timestamps for package/signature freshness.
- Package provenance such as local-dev, private checksum pin, private signature
  pin, or enterprise/private trust store.

Source packages must not embed private keys, app signing certificates, raw trust
store dumps, credentials, cookies, or other secret material.

## Verification Order

Future ingestion must preserve this order:

1. Archive safety.
2. Archive digest and size capture/check.
3. Manifest parse and schema validation.
4. Manifest digest and size capture/check.
5. WASM hash, magic/version, path, and size validation.
6. Package identity/version/provenance gates.
7. Future trust/signature gate for the selected trust mode.
8. ABI, host import allowlist, and network policy validation.
9. Atomic promote/register.

Archive digest, manifest digest, package identity/version, and future
trust/signature decisions are deliberately before ABI/import/network policy so a package
does not become partly accepted or runtime-eligible before its origin and
integrity decision is known. Runtime loading must never execute directly from a
picker URI, downloads path, archive filename, rawfile asset, or unregistered
staging directory.

## Fail-Closed Behavior

Any unknown trust mode, missing required metadata, verification error, archive
error, manifest error, WASM mismatch, ABI/import drift, or network drift must
reject the package. Rejection must prevent runtime handoff, registration, and
partial promotion, and must clean staging/partial extracted state.

## Updates, Removal, Rollback

Future product work must decide:

- Whether exact duplicate id/version/digest imports are idempotent or require
  explicit replacement.
- How duplicate package ids, normalized id collisions, and version conflicts are
  rejected or resolved.
- Whether package id must remain stable across updates.
- Whether signer/key id must match the installed package, and how key rotation is
  approved.
- Whether downgrade is rejected by default and when the same trust authority may
  explicitly approve it.
- How revocation works for package id, key id, digest, and expired metadata.
- How removal deletes package files, metadata, caches, sessions, settings,
  credential references, and install reports.
- Whether rollback is allowed only to a package that is still trusted,
  compatible, and not expired/revoked.

Silent downgrade and silent duplicate version overwrite are outside the
boundary.

## Logging Redaction

Default logs and reports must include reason codes and minimal evidence only.
They must not include keys, raw signatures, full user paths, picker URIs,
credentials, cookies, authorization headers, full manifests, full request or
response bodies, large responses, app-private absolute paths, or raw package
bytes.

Expanded diagnostics require a deliberate local developer diagnostic mode and
must still redact secrets and user paths. Chat output should report paths to
local artifacts and key evidence, not sensitive material.

## Validator Mapping

Existing validators already cover archive safety, staged extraction, manifest
shape, WASM hash/size, closed imports, `network=false`, HTTP drift, resource
limits, settings/auth, image/page descriptors, and HarmonyOS internal-dev
staging/promotion plan.

Missing future trust tests before product enablement:

- Canonical manifest/signature payload fixtures.
- Tampered signature, tampered manifest, tampered WASM, and checksum pin mismatch
  fixtures.
- Signer id/key id matching, rotation, revocation, expiration, and compatibility
  fixtures.
- Duplicate id, normalized collision, duplicate version, update, downgrade,
  rollback, and removal fixtures.
- Log redaction fixtures for paths, credentials, cookies, raw signatures, keys,
  full manifests, and runtime errors.
- HarmonyOS app-private promotion, cleanup, startup revocation, and runtime
  handoff tests.

## Non-Goals

This lane does not implement a source market, public index, remote install,
built-in source list, real signing, key generation, certificate handling, trust
store, cryptographic verification, product UI, product runtime loading, network
host import, WebView/JS DSL, device install, or app code.

## Static Validation

```sh
python3 tools/wasm-runtime-spike/source-package/validate-trust-provenance-boundary.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/trust-provenance-fixtures \
  --artifact-dir /path/to/artifacts/trust-provenance-boundary
```

The validator writes `trust-provenance-boundary-report.json`, accepts the closed
posture fixture, and rejects unsigned release acceptance, missing or misordered
archive digest/size, manifest digest/size, package id/version, trust checks,
source market/remote install/built-in source drift, silent downgrade or
duplicate overwrite, raw key/signature/path/secret/cookie logging,
`network=true`, HTTP import drift, non-fail-closed policy, and product runtime/UI
claims.
