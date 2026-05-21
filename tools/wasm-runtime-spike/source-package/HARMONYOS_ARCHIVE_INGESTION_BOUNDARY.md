# Future HarmonyOS Source Archive Ingestion Boundary

This note is design-only. It maps the already-validated local
`*.koma-source.zip` tooling archive to responsibilities a future HarmonyOS
product runtime would need to own before any product source ingestion exists.

It does not implement HarmonyOS runtime loading, UI, source installation,
source discovery, remote install, a public index, a source market, built-in
sources, HTTP, WebView workflow behavior, signing material, generated archives,
generated wasm, WAMR vendor source, or HAP/build outputs.

## Current Status

The current proven path is Linux tooling only:

```text
Rust no_std fixture -> wasm32-unknown-unknown -> source package manifest
-> .koma-source.zip validation/extraction -> Linux WAMR host runner
```

`SOURCE_RUNTIME_BOUNDARY.md`, `package-source-archive.py`, and
`run-source-archive-smoke.py` prove archive safety, staged extraction, manifest
validation, closed imports, `permissions.network=false`, and WAMR execution on
Linux. They are not a HarmonyOS product ingestion path.

## Proposed Future Ingestion Phases

1. Receive a local archive only from a user-controlled import action, such as a
   file picker or explicit local file import. Koma should not define a remote
   install URL, source repository sync, public package index, source market, or
   bundled source catalog for this boundary.
2. Copy the selected URI/file into app-private staging before validation. The
   future product runtime must not validate or execute directly from a shared
   picker/document path.
3. Validate archive safety before extraction: suffix and ZIP magic, total
   archive size, per-entry size, entry count, duplicate names, absolute paths,
   traversal, symlink entries, unexpected entries, hidden/generated build
   directories, and required entries.
4. Extract only into a temporary app-private staging directory. Extraction must
   not trust archive entry names as final paths and must fail closed on unsafe
   or unsupported entries.
5. Validate the staged manifest and wasm gates: schema, package id/version,
   `runtime.abi`, `runtime.hostAbi`, package-local wasm path, wasm
   sha256/size/magic/version, exact allowed host imports, `network=false`, and
   disabled `publicIndex`, `marketplace`, `builtInSource`, and `remoteInstall`
   flags.
6. Atomically promote the staged, validated package into an app-private package
   store. Register metadata only after promotion succeeds.
7. On any failure, remove the staging directory, temporary archive copy, partial
   extraction, and any unregistered promoted directory. Failure logs should keep
   enough reason codes for support without storing credentials, user file paths,
   or full manifest payloads unless explicitly needed for developer diagnostics.

## Storage And Sandbox Boundary

Future storage should stay entirely inside the app sandbox after the initial
user-selected input is copied. The runtime should never execute from a shared
file picker URI, a downloads path, rawfile assets, or any path controlled by the
archive filename.

A deterministic layout should be chosen before product work. One possible shape:

```text
<app-private-files>/source-packages/
  <normalized-package-id>/
    <normalized-version>/
      manifest.generated.json
      wasm/rust_source_fixture.wasm
      icon.placeholder.txt
      install-report.json
```

Rules to carry forward:

- Derive package id and version from the validated manifest, not the selected
  filename or archive root.
- Normalize package id/version into path-safe segments and reject collisions
  that normalize to the same path.
- Keep staging and package-store roots separate, then promote by rename or
  equivalent atomic filesystem operation to be confirmed on HarmonyOS.
- Enforce max archive size, max extracted size, max entry count, max path
  length, and max per-entry size before product enablement.
- Reject traversal, absolute paths, symlink entries, hidden/generated build
  directories, and unexpected files before extraction or before promotion if the
  platform extraction primitive does not expose entries early enough.
- Treat `rawfile` as bundled app resources only; user-provided source packages
  should not be stored or loaded as rawfiles.

## Runtime Handoff Boundary

The ingestion layer hands the runtime only:

- the validated extracted wasm path,
- the parsed and validated manifest,
- the package-store metadata needed to locate the package by id/version.

For the current ABI, the future HarmonyOS handoff must preserve the same gates
as Linux tooling:

- `permissions.network=false`.
- `runtime.requiredHostImports` exactly `koma_host.log` and
  `koma_host.check_cancel`.
- no `koma_host.http_request` import.
- no direct network, cookies, credential storage, cache access, or file access
  for wasm.

HTTP remains future design work under `../host-imports/http-boundary.md`. It
requires a new ABI/policy decision before product runtime code may expose it.

## HarmonyOS-Specific Risk Checklist

The following items must be revalidated during product work. API names here are
based on existing project research docs and local HarmonyOS references where
already cited there; any new usage remains to-be-confirmed before code lands.

- User input: picker-returned URI behavior, lifetime, cancellation, and error
  cases for local `*.koma-source.zip` import.
- App-private copy: confirm the chosen file APIs can copy picker URIs into
  sandbox storage for this package type on the target API/device class.
- Sandbox storage: choose `cacheDir` only for temporary staging and a persistent
  app-private files directory for promoted packages; exact directory API names
  are product-work to-be-confirmed.
- `rawfile` boundary: rawfiles are for bundled assets, not user-installed source
  packages.
- Permissions: local user-picked archive import should not request broad file
  or media permissions without a separate product/security review.
- Bundle sandbox: packages must remain private to the Koma bundle and not
  become shared files or public content providers.
- Extraction primitive: HarmonyOS ZIP APIs and any entry enumeration behavior
  must be checked against traversal, symlink, duplicate-entry, and size-limit
  requirements before reuse.
- Crash cleanup: startup should detect and remove stale staging directories,
  orphaned temporary archives, and incomplete promote markers.
- Disk quota: staging must account for copied archive plus extracted files plus
  promoted package size; low-space failures must fail closed.
- Background constraints: import/build/runtime handoff may need foreground
  progress and cancellation rather than assuming long background execution.

Existing local-import research already supports a cautious pattern for comic
archives: user picker URI, copy into app sandbox, then pass a sandbox ZIP path
to extraction. Source-package ingestion should mirror that boundary but keep it
separate from comic library import and source runtime execution.

## Trust, Update, And Removal Open Items

- Signature/provenance: whether local source packages require developer
  signatures, pinned public keys, checksum-only trust, or an enterprise/private
  provenance model.
- Revocation: how a package is disabled after trust changes or unsafe behavior
  is discovered, without implying a public source registry.
- Duplicate package/version: whether exact duplicates are idempotent, rejected,
  or require user confirmation.
- Upgrade/downgrade: whether a new version can replace an old one, whether
  downgrade is allowed, and whether rollback keeps the previous validated
  package.
- Compatibility: mapping source ABI, host ABI, package schema, and minimum app
  version before registration.
- User consent: what manifest fields, permissions, and risks must be visible
  before promote/register if product UX is later approved.
- Removal: package metadata, extracted files, caches, settings, credentials
  references, and logs need separate cleanup rules.
- Logging/redaction: logs should avoid raw picker URIs, absolute user paths,
  credentials, cookies, request payloads, and full source responses.

## Validation Mapping

Current Linux tooling evidence and future HarmonyOS mirror tests:

| Current tooling | Current proof | Future HarmonyOS mirror |
| --- | --- | --- |
| `package-source-archive.py` | Builds and validates a local `*.koma-source.zip`; checks archive shape, staged extraction, manifest, wasm hash/size, imports, and disabled content-policy flags. | Validate a copied sandbox archive with the same gates before extraction/promotion and write an install report. |
| `validate-archive-negative-fixtures.py` | Rejects traversal, absolute paths, duplicate entries, symlinks, unexpected entries, network/http import drift, wasm hash mismatch, and missing required entries. | Run equivalent malformed archives through the HarmonyOS staging validator and assert fail-closed cleanup. |
| `run-source-archive-smoke.py` | Validates an archive, extracts it, then runs only the validated extracted wasm in the Linux WAMR host. | After product runtime exists, run only promoted package wasm and assert the same manifest/import/network gates before runtime handoff. |
| `validate-source-package.py --build-rust-fixture` | Validates manifest schema, wasm magic/version/hash/size, exports/imports, capabilities, settings defaults, and `network=false`. | Use the same manifest/wasm gate list on the staged package before metadata registration. |
| `validate-http-boundary.py` | Keeps HTTP design-only; proves current `network=false` manifests reject `koma_host.http_request`. | Keep HarmonyOS runtime import table closed until a future ABI/policy explicitly enables HTTP. |

## Required Commands Before Product Work

Re-run these commands with a fresh artifact directory before any HarmonyOS
product ingestion or runtime loading work starts:

```sh
ARTIFACT=/home/gamer/git/Koma/.hermes-artifacts/20260521-211500/lane3r-harmonyos-archive-ingestion-boundary

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
