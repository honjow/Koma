# Lifecycle Update, Downgrade, Rollback, And Removal Boundary

This document defines static fixture semantics for future local source package
lifecycle decisions. It is design/tooling-only. It does not add product install
state, package deletion, rollback execution, registry storage, signing,
signature verification, trust stores, revocation stores, runtime loading, UI,
network, HTTP, WebView, source markets, public indexes, remote install, or
built-in sources.

The validator for this boundary reads local JSON fixtures only. It compares
package ids, normalized ids, versions, public signer/key/provenance identifiers,
static digests, compatibility fields, host imports, `network=false`, and cleanup
category names. It must not mutate product state or delete files.

## Identity

Package ids are accepted only in canonical form:

- trim surrounding whitespace
- lowercase
- collapse repeated dot separators
- convert underscores to hyphens
- require `^[a-z][a-z0-9]*(?:[.][a-z0-9][a-z0-9-]*){2,}$`

The canonical package id and `normalizedPackageId` must match for stored
artifacts. A candidate that normalizes to an installed id but uses a different
literal id is a normalized collision and rejects. Display name, author,
signer, key, provenance, and digest changes must not silently overwrite a
previously accepted id/version.

## Duplicate Versions

An exact same id/version/digest may be a no-op only when
`explicitIdempotentPolicy=true`. Same id/version with a changed archive,
manifest, WASM, or payload digest rejects by default. Same id/version with
changed signer, key, provenance, display name, or author also rejects unless a
future replacement policy is explicitly designed and separately validated.

## Updates

Updates must preserve package id stability. Version ordering is deterministic:
the fixtures use semantic-version core tuple ordering. Update eligibility also
requires signer/key/trust-authority continuity and must pass digest, ABI,
import, network, trust, and compatibility gates before any future runtime
eligibility.

## Downgrades

Downgrades reject by default. A downgrade approval must be explicit and bound
to package id, from version, to version, signer id, key id, approval creation
time, approval expiration time, evaluation time, and relevant archive digests.
Expired, stale, mismatched, or incomplete approvals reject.

## Rollback

Rollback is allowed only to a previously accepted artifact that remains trusted,
compatible, unexpired, not revoked, and available by the expected digest.
Rollback must not bypass current trust, ABI, import, network, or compatibility
gates. Rollback to revoked signer, key, package version, digest, expired
package, incompatible ABI/app/host policy, or unknown artifact rejects.

## Removal

Removal remains a plan, not an implementation. The plan lists cleanup
categories rather than raw storage locations:

- app-private-package-files
- package-metadata
- derived-caches
- active-sessions
- source-settings
- credential-references
- diagnostic-reports
- runtime-handles

Future removal must be atomic and idempotent and must not leave
runtime-eligible stale handles. Reports must not dump credentials, concrete
storage locations, trust-store contents, or raw package bytes.

## Diagnostics

Default reports are redacted and use minimal field names only:
`status`, `case`, `reasonCode`, and `field`. Reason codes are stable uppercase
tokens. Logs and reports should avoid raw command lines, concrete local storage
locations, cache locations, key material, signatures, payload bodies, trust
store material, credentials, cookies, or transport headers.

## Validate

```sh
python3 tools/wasm-runtime-spike/source-package/validate-lifecycle-update-rollback.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/lifecycle-update-fixtures \
  --artifact-dir /path/to/artifacts/lifecycle-update-rollback
```

The validator writes `lifecycle-update-rollback-report.json` under the artifact
directory. It accepts the valid boundary fixture and rejects drift cases for
duplicate id, normalized collision, duplicate version, update, downgrade,
rollback, removal, runtime closure, diagnostics, and validator scope.
