# Koma Canonical Manifest And Signature Payload Boundary

Status: design/tooling-only. This boundary applies only to future local
`*.koma-source.zip` WASM source package research under `tools/wasm-runtime-spike/`.
It does not implement signing, signature verification, key generation,
certificates, a trust store, product runtime loading, product UI, network, HTTP,
WebView, or JS DSL behavior.

The purpose of this lane is to make future deterministic bytes concrete so a
later checksum or signature gate can sign and verify the same payload bytes. The
validator computes local SHA-256 values only to keep static fixtures consistent;
that is not package verification and is not a trust decision.

## Canonical Manifest Input

Future signing/checksum input must be a normalized JSON object model, never raw
manifest text. Raw text is rejected because comments, trailing commas, duplicate
keys, whitespace, and parser differences can otherwise change the meaning of
what was signed.

Canonical payload bytes use:

- UTF-8 JSON serialization.
- Sorted object keys.
- No insignificant whitespace.
- NFC-normalized strings and keys.
- Decimal integer formatting with no plus sign.
- No floats in canonical payload v1.
- No duplicate keys in either parsed fixtures or the payload model.
- No `NaN`, `Infinity`, comments, trailing commas, or non-JSON extensions.

Unknown canonicalization algorithms or versions reject fail-closed.

## Signed Payload Binding

The future signed payload must bind all trust-relevant public metadata:

- Package id and version.
- Source ABI, host ABI, and payload schema version.
- Archive sha256 and byte size.
- Canonical manifest sha256 and byte size.
- Package-local WASM path, sha256, and byte size.
- `network=false`.
- Exact host import allowlist: `koma_host.log` and
  `koma_host.check_cancel`.
- Trust mode and provenance as public metadata only.
- Signer id and key id as identifiers only, not key material.
- `createdAt` and `expiresAt` freshness fields when present.

The payload does not carry a real signature. `signerId` and `keyId` are opaque
identifiers for future policy tests only.

## Exclusions

Canonical payload fixtures and diagnostics must not include:

- Raw private keys or raw app signing certificates.
- Credentials, cookies, authorization headers, or session material.
- Full user paths, picker URIs, app-private absolute paths, generated cache
  paths, or artifact paths.
- Raw archive bytes, raw WASM bytes, full request/response bodies, full
  manifest dumps, or trust-store dumps.
- Source market, public index, remote install, built-in source, product runtime,
  product UI, HTTP import, network, WebView, JS DSL, executable hooks, validator
  subprocesses, or validator network behavior.

Any payload digest mismatch, manifest digest mismatch, missing package/archive/
manifest/WASM binding, `network=true`, `koma_host.http_request`, product
runtime/UI claim, source market drift, remote install drift, or built-in source
drift rejects.

## Diagnostics

Default reports include reason codes and minimal field names only. They must not
dump raw payloads, signatures, headers, secrets, full paths, request/response
bodies, raw archive bytes, raw WASM bytes, or trust-store contents.

## Static Validation

```sh
python3 tools/wasm-runtime-spike/source-package/validate-canonical-signature-payload.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/canonical-signature-fixtures \
  --artifact-dir /path/to/artifacts/canonical-signature-payload
```

The validator is Python stdlib-only. It loads local JSON, rejects duplicate keys
with `object_pairs_hook`, rejects non-finite JSON constants, computes
deterministic JSON bytes with `json.dumps(sort_keys=True, separators=(",", ":"),
ensure_ascii=False, allow_nan=False)`, and uses `hashlib.sha256` only for static
fixture consistency. It performs no network I/O, subprocess execution, WASM
execution, signing, verification, key generation, certificate handling, or trust
store work.
