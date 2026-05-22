# Koma HTTP Host Import Boundary

This is a product-disabled boundary for a future Koma WASM source runtime HTTP
capability. S5 adds only a local WAMR fixture import for deterministic static
data under `fixture.koma.local`; it does not enable real network in WAMR,
HarmonyOS, product UI, source markets, WebView workflows, APK plugins, or
built-in sources.

The detailed candidate contract is now tracked in
`http-host-import-v0.md`. This file remains the short validation boundary for
the design fixture and the current-runtime rejection gates.
S6's separate product-disabled HTML fixture contract is tracked in
`html-host-import-v0.md`.
Machine-verifiable negative fixtures for the closed current policy live in
`http-policy-negative-fixtures/` and are validated by
`validate-http-policy-negative-fixtures.py`.

General runtime packages remain on `koma-host-v0.1` with only:

```text
koma_host.log
koma_host.check_cancel
```

The S5 local WAMR fixture uses a temporary `koma-host-v0.1-fixture-http` ABI
and an explicit `experimentalHttpFixture` manifest gate to exercise the proposed
HTTP import shape without network I/O:

```c
int32_t koma_host_http_request(
    uint32_t req_ptr,
    uint32_t req_len,
    uint32_t out_ptr,
    uint32_t out_cap);
```

## ABI Proposal

The source writes a UTF-8 JSON request envelope into guest memory and calls the
host import. The host validates the manifest permissions, validates the request,
checks cancellation before and after host work, writes a UTF-8 JSON response or
error envelope into `out_ptr`, and returns the byte length written.

Return values:

- `>= 0`: bytes written to `out_ptr`.
- `-1`: permission denied by manifest, host, scheme, method, host, header, or
  credential policy.
- `-2`: invalid request envelope.
- `-3`: response or error envelope would exceed `out_cap`.
- `-4`: timeout.
- `-5`: response exceeded `maxResponseBytes`.
- `-6`: cancelled; host observed `koma_host.check_cancel`.
- `-7`: runtime network capability unavailable.
- `-8`: host internal failure.

`out_cap` must be at least 1024 bytes. Hosts may require a larger minimum before
HTTP is enabled. A later ABI may switch to a two-step buffer model if real
responses need host-owned streaming or larger binary transfers.

## Request Envelope

```json
{
  "version": 1,
  "method": "GET",
  "url": "https://api.example.invalid/search?q=koma",
  "headers": {
    "Accept": "application/json"
  },
  "bodyBase64": null,
  "timeoutMs": 8000,
  "redirect": "follow",
  "credentialsRef": null,
  "sessionRef": "default"
}
```

Rules:

- Methods: `GET`, `HEAD`, and `POST` only for the first HTTP ABI.
- Schemes: `https` only by default; `http` is allowed only when the manifest
  explicitly lists it for LAN/private-library use.
- Hosts: normalized URL host must match the manifest `allowedHosts` list before
  the request and after every redirect.
- Headers: source-controlled headers are allowlisted. `Accept`, `Content-Type`,
  `If-None-Match`, `If-Modified-Since`, and `User-Agent` profile tokens are
  allowed. `Cookie`, `Authorization`, proxy headers, hop-by-hop headers, and raw
  secret-like header names are denied from source JSON.
- Credentials: tokens, passwords, cookies, and API keys are never embedded in a
  manifest or source request. A source may request `credentialsRef`; the host
  resolves it from user-owned settings and redacts it from logs.
- Payload: request body is base64 and allowed only for `POST`.
- Timeout: source may request a lower timeout; host clamps it to the manifest
  maximum.
- Redirects: `none` or `follow`; host clamps redirect count and revalidates the
  target scheme and host.
- Sessions: `sessionRef` partitions cookies/cache per source package and user
  account. Sources cannot read cookie bytes.

## Response Envelope

```json
{
  "ok": true,
  "status": 200,
  "url": "https://api.example.invalid/search?q=koma",
  "headers": {
    "content-type": "application/json"
  },
  "bodyBase64": "eyJpdGVtcyI6W119",
  "truncated": false,
  "fromCache": false,
  "elapsedMs": 42
}
```

Error envelope:

```json
{
  "ok": false,
  "error": {
    "code": "permission_denied",
    "message": "host not allowed by manifest"
  },
  "elapsedMs": 1
}
```

Hosts must redact credentials and may omit response headers except safe metadata
such as content type, ETag, Last-Modified, and cache status.

## Manifest Gate

HTTP imports require an explicit future manifest permission block:

```json
{
  "permissions": {
    "network": true,
    "hostImports": [
      "koma_host.log",
      "koma_host.check_cancel",
      "koma_host.http_request"
    ],
    "networkPolicy": {
      "allowedSchemes": ["https"],
      "allowedHosts": ["api.example.invalid"],
      "allowedMethods": ["GET", "HEAD", "POST"],
      "maxRequestBytes": 65536,
      "maxResponseBytes": 1048576,
      "timeoutMs": 8000,
      "redirects": {
        "mode": "follow",
        "maxCount": 3
      },
      "credentials": {
        "allowCredentialsRef": true,
        "allowRawSecrets": false,
        "cookiePolicy": "host-managed-session"
      }
    }
  }
}
```

Current non-fixture package validation still rejects `network=true` and
unpermitted `koma_host.http_request`. The S5 source-package validator accepts
the import only when `experimentalHttpFixture.enabled=true`,
`allowedHost=fixture.koma.local`, `networkPerformed=false`, and the wasm imports
match the fixture policy.

The future v0.1 candidate requires all of the following before any HTTP request
could run in a later implementation:

- compatible `koma-source-abi` and future `koma-host` HTTP ABI;
- `permissions.network=true`;
- `koma_host.http_request` in both runtime imports and permission imports;
- complete fail-closed network policy for scheme, host, method, request bytes,
  response bytes, timeout, redirects, headers, credentials, cache, and rate;
- host-owned credential references and cookie/session partitions rather than
  raw source-visible secrets.

## Non-Goals

- No real network implementation.
- No WebView+JavaScript source runtime.
- No source marketplace, remote source index, remote installer, or built-in
  public source list.
- No APK plugin flow.
- No raw credential literals in manifests, requests, logs, fixtures, or reports.
- No vendored WAMR source, signing material, HAP/build output, or Rust target
  directories.
