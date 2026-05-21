# Koma Source Package Signer Rotation, Revocation, Expiration, And Compatibility Boundary

Status: design/tooling-only. This boundary applies only to future local
`*.koma-source.zip` WASM source package research under `tools/wasm-runtime-spike/`.
It is not product ingestion, product runtime loading, product UI, device install,
a signing implementation, cryptographic verification, certificate handling, key
generation, a revocation store, a trust store, networking, remote install, a
source market, a public index, or built-in sources.

The validator in this directory is a Python stdlib-only local JSON fixture
checker. It compares public identifiers, timestamps, static digests, policy
versions, and compatibility fields. It does not execute WASM, run subprocesses,
perform network I/O, parse certificates, generate keys, verify signatures, load
trust material, or call product app/runtime code.

## Future Decision Model

Future package trust must fail closed before runtime eligibility. This lane makes
the decision shape concrete with static metadata only:

1. Identity binding.
2. Key rotation policy.
3. Revocation inputs.
4. Expiration and freshness windows.
5. Package/source/host/app compatibility.
6. Closed runtime posture and diagnostic redaction.

Acceptance of the fixture means only that the static policy object is internally
consistent. It is not proof of authenticity and must not be treated as a
shipping security decision.

## Identity Binding

Package id and package version are bound to a public signer id and key id. The
display name and display author are free text only and must never become trust
identity. Future update decisions must require package id stability across
updates and must match the installed signer id and key id unless an explicit
rotation policy authorizes the key transition.

Changing a package id across update rejects. Changing a signer id rejects unless
future policy deliberately approves that signer transition; the current fixture
keeps signer changes unapproved. Changing a key id rejects unless a rotation
object ties the installed key id to the candidate key id for the same signer and
package scope.

## Key Rotation

Rotation requires an explicit static policy object:

- same package id scope;
- same signer id scope;
- old key id and new key id both named;
- active validity window;
- explicit approval flag;
- no bypass of package id, version, digest, freshness, or compatibility gates.

Unapproved signer change, unapproved key id change, cross-package rotation, stale
rotation approval, or any attempt to use rotation as a shortcut around version,
digest, or compatibility gates rejects.

## Revocation

Static revocation inputs may mark these public metadata items revoked:

- signer id;
- key id;
- package id and version tuple;
- archive digest or WASM digest.

Revoked metadata rejects before runtime eligibility. Future startup/runtime
handoff must also be blocked when an installed package becomes revoked, but this
lane stays design-only and does not implement app startup, storage, or runtime
handoff behavior.

## Expiration And Freshness

`createdAt`/`expiresAt` and `notBefore`/`notAfter` are public metadata fields in
the fixture. The clock source is an explicit policy input. This lane uses only
fixture `evaluationTime`; it does not read the device clock.

`signatureMetadata.realVerificationPerformed` must be `false` or absent. A
`true` value claims real signature verification and rejects in this
design/tooling-only lane.

Expired package, signature metadata, or rotation policy rejects. Not-yet-valid
package, signature metadata, or rotation policy rejects. Timestamp parsing is
strict UTC in `YYYY-MM-DDTHH:MM:SSZ` form; timezone ambiguity or malformed
timestamps reject.

## Compatibility

Compatibility is checked before runtime eligibility. The fixture requires:

- known compatibility policy version;
- package schema version match;
- source ABI match;
- host ABI match;
- app version within declared bounds;
- explicit list of compatibility gates checked before runtime eligibility.

Unknown compatibility policy versions and incompatible package schema, source
ABI, host ABI, or app bounds reject.

## Closed Posture

Current source package research remains closed:

- `network=false`;
- host imports exactly `koma_host.log` and `koma_host.check_cancel`;
- no `koma_host.http_request`;
- no product runtime or product UI;
- no source market, public index, remote install, or built-in sources;
- no real signing, signature verification, key generation, certificates, trust
  store, revocation store, network revocation fetch, HTTP import, or WebView/JS
  DSL.

Validator drift flags reject network I/O, subprocess execution, executable
hooks, WASM execution, and product runtime hooks.

## Diagnostics

Default reports use stable reason codes and minimal field names. They must not
emit key material, raw signatures, credential/session fields, full user paths,
picker URIs, app-private absolute paths, raw payloads, full manifests,
request/response bodies, generated cache paths, trust material dumps, or raw
package bytes.

Expanded diagnostics remain out of scope for this fixture and would require a
separate local developer mode with redaction still enforced.

## Static Validation

```sh
python3 tools/wasm-runtime-spike/source-package/validate-signer-rotation-revocation.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/signer-rotation-fixtures \
  --artifact-dir /path/to/artifacts/signer-rotation-revocation
```

The validator writes `signer-rotation-revocation-report.json`, accepts the valid
static fixture, and rejects display-text trust identity, signer/key mismatch,
unapproved signer change, unapproved key rotation, cross-package rotation,
stale/expired rotation policy, package id drift, silent downgrade, revocation,
expired or not-yet-valid metadata, real signature verification claims,
ambiguous timestamps, incompatible ABI/app bounds, unknown policy versions,
`network=true`, HTTP import drift, product-runtime/UI drift,
source market/remote/built-in source drift, diagnostic leaks, and executable
validator drift.
