# HarmonyOS Internal-Dev Source Ingestion Plan

This is a design-only, internal-development plan for a future HarmonyOS source
package ingestion path. It maps the already-proven local archive validation
pipeline to a possible app-private staging and promotion flow.

It does not implement product runtime code, UI, install screens, file picker
integration, app-private storage writes, package registry behavior, network,
HTTP, a source market, remote install, built-in sources, WebView source
execution, signing material, generated archives, generated wasm, WAMR vendor
source, device commands, or HAP outputs.

## Status And Boundary

Current evidence remains Linux tooling only:

```text
Rust no_std fixture -> wasm32-unknown-unknown -> source package manifest
-> local .koma-source.zip -> archive validation/extraction -> Linux WAMR host
```

The product runtime stays closed:

- Input is local developer-provided archive only.
- `permissions.network=false`.
- Host imports are exactly `koma_host.log` and `koma_host.check_cancel`.
- `koma_host.http_request` is not available.
- No public package index, source market, remote install URL, built-in source,
  or bundled source catalog is defined by this plan.

The future implementation lane must treat this document and
`harmonyos-ingestion-plan.example.json` as policy fixtures, not app behavior.

## Future Flow

1. Receive only a local developer-provided `*.koma-source.zip` archive through
   an internal-dev import action. Do not accept remote URLs, package index
   entries, marketplace records, bundled sources, or source repository sync.
2. Copy the selected picker/document URI into an app-private temporary archive
   location before validation. Never validate, extract, execute, hash, or trust
   bytes directly from the shared picker URI.
3. Validate archive safety before extraction: extension/magic, total archive
   size, per-entry size, entry count, duplicate names, absolute paths, traversal,
   symlink entries, unexpected entries, hidden/generated build directories,
   required entries, and path length.
4. Extract only into an app-private staging directory created for this import
   attempt. Treat archive names as package-local entries, never as final paths.
5. Parse and validate the staged manifest: schema version, package id, version,
   source ABI, host ABI, package-local wasm path, content policy, capabilities,
   settings schema, auth boundary, image/page policy, and resource limits.
6. Validate wasm from the staged extraction only: sha256, byte size, magic,
   version, declared path, import table, exported source ABI functions, memory
   limits, and result size ceilings.
7. Validate trust/provenance after hash calculation and before runtime policy
   acceptance. The trust mechanism is to-be-decided; checksum-only acceptance,
   developer signatures, pinned keys, enterprise profiles, and revocation remain
   future product/security decisions.
8. Validate ABI/import/network policy: `network=false`, exact
   `koma_host.log`/`koma_host.check_cancel` imports, no
   `koma_host.http_request`, no direct filesystem/cache/cookie/credential
   imports, and no unreviewed host capabilities.
9. Validate settings/auth/resource/image policies using the existing static
   gate shape: no inline secrets, host-owned secret references only, no
   executable auth operations, bounded timeouts/results/wasm, required
   cancellation, opaque page ids, and no raw local/picker/app-private paths.
10. Atomically promote the validated staging directory into an app-private
    package store, then register metadata. Registration must happen only after
    promote succeeds.

## App-Private Storage Shape

The exact HarmonyOS file APIs are to-be-confirmed in a future product lane. This
plan intentionally names storage roles rather than platform calls:

```text
<app-private-temp>/source-ingestion/
  attempts/<attempt-id>/
    input.koma-source.zip
    extract/
    validation-report.json

<app-private-files>/source-packages/
  <normalized-package-id>/
    <normalized-version>/
      manifest.generated.json
      wasm/rust_source_fixture.wasm
      icon.placeholder.txt
      install-report.json
```

Rules:

- Derive package id and version from the validated manifest, not from the
  selected file name or archive root.
- Normalize package id/version into path-safe deterministic segments and reject
  collisions that normalize to the same store path.
- Keep temp, staging, and package-store roots separate.
- Use atomic rename or an equivalent platform-confirmed operation for
  promotion; do not register metadata before the store directory is complete.
- Write an incomplete marker before promotion if needed, and remove it before
  registration.
- Clean stale attempt directories, temporary archive copies, partial extracts,
  incomplete promote directories, and unregistered package directories on
  validation failure, cancellation, crash recovery, and interruption.
- Account for disk quota as copied archive plus extracted bytes plus promoted
  package bytes before promotion.

## Runtime Handoff

The ingestion layer may hand the future runtime only:

- the validated extracted wasm inside the promoted app-private package store,
- the parsed and validated manifest object,
- package metadata needed to locate package id/version.

The runtime must not receive the original picker URI, raw shared path, archive
filename, unvalidated manifest JSON, unvalidated wasm bytes, full extraction
directory, user credentials, cookies, or HTTP request material.

Current runtime handoff remains closed until a later authorized lane changes the
ABI:

- `network=false`.
- host imports exactly `koma_host.log` and `koma_host.check_cancel`.
- no `koma_host.http_request`.
- no real HTTP/network, source market, remote install, built-in source, or
  public index.

## Developer Diagnostics

Developer diagnostics should help reproduce validation failures without leaking
private data by default:

- Record stable reason codes, gate names, package id, version, normalized
  package path segments, sizes, sha256 prefixes, and import names.
- Redact raw picker URIs, absolute user paths, app-private paths, credentials,
  cookies, tokens, auth headers, full manifests, request/response bodies, and
  large source responses.
- Keep long logs and validation reports under the controller artifact directory
  during tooling runs.
- Require explicit debug override for expanded local diagnostics in internal
  builds, with separate review before product use.

## Rollback, Removal, And Update

Future implementation must define these before product enablement:

- Duplicate package/version: reject, idempotently keep, or require explicit
  internal-dev confirmation.
- Upgrade/downgrade: compatibility gates for source ABI, host ABI, manifest
  schema, minimum app version, and policy version.
- Rollback: whether previous validated versions remain available after failed
  update or trust revocation.
- Removal: package files, metadata, image/cache entries, settings, host-owned
  secret references, validation reports, and logs need separate cleanup rules.
- Revocation/trust: disable unsafe packages without relying on a public source
  registry or market.
- Quotas: per-package and total source-package store limits, low-space failure
  behavior, and cleanup priority.

## HarmonyOS Notes

All platform-specific API names and semantics are to-be-confirmed before code
lands. A future lane must verify:

- picker URI lifetime, cancellation, and error behavior;
- copying from picker/document URI into app-private temp storage;
- app-private temp and persistent files directory behavior;
- atomic rename or replacement guarantees inside the app sandbox;
- ZIP entry enumeration support for duplicate names, symlinks, traversal, and
  size checks;
- startup crash cleanup behavior;
- app logging retention and redaction controls;
- storage quota and low-space reporting.

Do not infer product permission requirements from this plan. Local
developer-provided archive import should avoid broad file/media permissions
unless a future product/security review explicitly approves them.

## Test Plan Mapping

| Current tooling | Current evidence | Future app-side smoke |
| --- | --- | --- |
| `package-source-archive.py` | Builds and validates a local archive; checks archive shape, staged extraction, manifest, wasm hash/size, imports, and disabled content-policy flags. | Copy local developer archive to app-private temp, validate same gates, extract to staging, and produce a redacted install report. |
| `validate-archive-negative-fixtures.py` | Rejects traversal, absolute paths, duplicates, symlinks, unexpected entries, network/http drift, hash mismatch, and missing entries. | Run equivalent malformed archives through app-private staging and assert failure plus cleanup. |
| `validate-source-package.py --build-rust-fixture` | Validates manifest schema, wasm magic/version/hash/size, exports/imports, capabilities, settings defaults, and `network=false`. | Reuse the same manifest and wasm gates before promote/register. |
| `validate-settings-auth-fixtures.py` | Rejects inline secrets, leaked headers/cookies/tokens, path leaks, executable auth, HTTP import drift, and product runtime flags. | Apply the same static checks to staged manifest/settings before runtime handoff. |
| `validate-resource-limit-fixtures.py` | Enforces timeout, result, wasm, cancellation, logging, and product-runtime gates. | Mirror the limits in app-side validation before registration. |
| `validate-image-page-fixtures.py` | Keeps current descriptors placeholder/test only and rejects path/URL/header/cache leaks. | Assert promoted sources cannot return raw paths or remote image descriptors while network remains false. |
| `validate-http-policy-negative-fixtures.py` and `validate-http-boundary.py` | Prove current runtime rejects `network=true` and `koma_host.http_request`; future HTTP is design-only. | Keep import table closed until a separate authorized HTTP lane changes ABI/policy. |
| `run-source-archive-smoke.py` | Validates and extracts an archive, then runs only validated wasm through Linux WAMR. | After product runtime exists, run only promoted package wasm from app-private store with the same import/network gates. |

Unimplemented now:

- HarmonyOS file picker/import UX.
- App-private copy, extraction, promote, registry, rollback, and cleanup code.
- Device smoke or UI automation.
- Product runtime loading from promoted package store.
- Signing/trust enforcement and revocation.
- Network/HTTP capability.

## Stop Conditions For Future Implementation

Do not implement or enable product ingestion until these are resolved:

- Product decision approving internal-dev source ingestion UX.
- Internal-dev UX copy and confirmation requirements.
- Signing/provenance/trust and revocation model.
- Storage quota, low-space behavior, and cleanup policy.
- App logging retention and redaction policy.
- Network permission and ABI decision for any future HTTP lane.
- HarmonyOS API confirmation for picker URI copy, ZIP validation, sandbox
  storage, atomic promote, and crash cleanup.

