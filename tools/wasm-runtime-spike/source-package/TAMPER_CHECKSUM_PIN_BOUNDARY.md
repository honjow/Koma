# Tamper And Checksum Pin Boundary

Status: design/tooling-only. This boundary is a static fixture for future local
`*.koma-source.zip` trust checks. It does not implement signing, signature
verification, key generation, key stores, trust stores, certificates, product
ingestion, runtime loading, UI, network, HTTP, WebView, or a source market.

The validator only loads local JSON fixtures and uses Python stdlib
`hashlib`/`json` to make fixture measurements deterministic.

## Measurements

Future package trust decisions must be made from observed package measurements:

- archive `sha256` and `sizeBytes`;
- canonical manifest `sha256` and `sizeBytes`;
- package-local WASM path, WASM `sha256`, and WASM `sizeBytes`;
- canonical signed payload `sha256` and `sizeBytes` when present;
- package id/version and signer id/key id as public identifiers only.

Signer id and key id are not keys, certificates, or verification material in
this lane.

## Expected Inputs

Future checksum-pinned or signature-pinned modes must compare observed metadata
against expected trust inputs before any runtime handoff:

- checksum pins for archive and/or WASM bytes;
- expected package id and version;
- expected signer id and key id identifiers in signature-pinned mode;
- expected canonical payload digest when the payload is present.

Checksum-pinned mode must include at least one expected checksum. Signature
pinned mode must require a signature block, but this lane treats the block as a
placeholder status object only.

## Fail-Closed Cases

The static fixture gate rejects:

- archive digest or size mismatch;
- manifest digest or size mismatch;
- WASM digest, size, or package-local path mismatch;
- canonical payload digest or size mismatch;
- package id or version mismatch;
- signer id or key id mismatch;
- signature block missing, malformed, tampered, or marked unsigned in
  signature-pinned/release mode;
- checksum-pinned mode with no expected checksum;
- stale observed bytes after mutation, where manifest or WASM metadata changes
  but the trusted payload/pins do not change.

Rejection means no product registration, promotion, runtime loading, or partial
acceptance.

## Boundary Drift

The same static gate also rejects unrelated drift:

- `network=true`;
- `koma_host.http_request`;
- source market, public index, remote install, or built-in source flags;
- product runtime/UI flags;
- raw key/signature dumps, credentials, headers, cookies, local paths, picker
  URIs, app-private paths, archive bytes, WASM bytes, or full manifest dumps in
  diagnostics;
- validator drift toward subprocesses, network, executable hooks, WASM
  execution, or product runtime hooks.

## Diagnostics

Reports are redacted by default. They include case names, reason codes, minimal
field names, and digest prefixes only when useful. They must not include raw
private keys, raw signatures, full payload dumps, headers, cookies, full local
paths, picker URIs, app-private paths, archive bytes, WASM bytes, or full
manifest dumps.

## Static Validation

```sh
python3 tools/wasm-runtime-spike/source-package/validate-tamper-checksum-pin.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/tamper-checksum-fixtures \
  --artifact-dir /path/to/artifacts/tamper-checksum-pin
```

The validator writes `tamper-checksum-pin-report.json`, accepts the valid
boundary fixture, and rejects the invalid tamper/checksum/signature/scope drift
cases without performing real cryptographic verification.
