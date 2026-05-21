# Koma HTTP Host Import v0.1 Candidate

This is a design-only specification for a future Koma WASM source runtime HTTP
host import. It exists so later validator, SDK, settings/auth, and resource
limit lanes can reason about one concrete policy surface before any network
implementation exists.

Current runtime status is unchanged:

- `permissions.network=false` for current source packages.
- HTTP is design-only.
- The design fixture reports `runtimeEnabled=false`.
- The design fixture reports `networkPerformed=false`.
- Current package/runtime gates reject `permissions.network=true`.
- Current package/runtime gates reject `koma_host.http_request`.
- No code path in this lane performs network I/O.

## Import Shape And ABI Versioning

Candidate import name:

```text
module: koma_host
name: http_request
qualified: koma_host.http_request
```

Candidate C-facing shape for `koma-host-v0.2-design-http`:

```c
int32_t koma_host_http_request(
    uint32_t req_ptr,
    uint32_t req_len,
    uint32_t out_ptr,
    uint32_t out_cap);
```

The exact shape is not final. The v0.1 candidate keeps a single synchronous
call so validators can inspect the full request and response contract. A later
implementation may replace this with a two-step prepare/read API or a
host-owned handle if streaming, background cancellation, or large binary bodies
need it.

Buffer model:

- `req_ptr` and `req_len` point to a UTF-8 JSON request envelope in guest
  memory.
- `out_ptr` and `out_cap` point to a guest-provided output buffer.
- The host writes a UTF-8 JSON response envelope or error envelope into the
  output buffer.
- The return value is a status/length code, not a KOMA result-buffer pointer.
- Source operation exports still return the existing KOMA result-buffer
  envelope to the runtime host.
- The HTTP response envelope is therefore nested inside source execution; it is
  not a replacement for the source operation result-buffer envelope.

Candidate return values:

- `>= 0`: byte length written to `out_ptr`.
- `-1`: permission denied by manifest, host ABI, scheme, method, host, header,
  credential, redirect, cache, or trust policy.
- `-2`: invalid request envelope.
- `-3`: output buffer too small for the response/error envelope.
- `-4`: timeout.
- `-5`: response body exceeded the active response byte limit.
- `-6`: cancelled by host cancellation state.
- `-7`: network capability unavailable in the current runtime.
- `-8`: host internal failure.

Version negotiation is fail-closed across three surfaces:

- Source package manifest declares `runtime.abi`, `runtime.hostAbi`,
  `runtime.requiredHostImports`, `permissions.network`, and
  `permissions.hostImports`.
- Host runtime advertises its active `koma-source-abi` and `koma-host` version
  through manifest validation and operation request `hostHints`.
- HTTP request envelope declares `"version": 1`.

All of these must agree before HTTP can run:

```text
runtime.abi == koma-source-abi-v0.1
runtime.hostAbi == koma-host-v0.2-design-http or later compatible HTTP host ABI
permissions.network == true
runtime.requiredHostImports contains exactly the approved HTTP import set
permissions.hostImports contains koma_host.http_request
http request envelope version == 1
networkPolicy present and compatible
```

Missing fields, unknown required versions, unsupported host ABI, undeclared
imports, or a source request version outside the negotiated range must return a
deterministic permission or invalid-request error. A host must not silently
upgrade a current `koma-host-v0.1` package into HTTP capability.

## Request Schema

Candidate request envelope:

```json
{
  "version": 1,
  "method": "GET",
  "url": "https://api.example.invalid/search?q=koma",
  "urlRef": null,
  "headers": {
    "Accept": "application/json"
  },
  "bodyBase64": null,
  "bodyRef": null,
  "timeoutMs": 8000,
  "redirect": {
    "mode": "follow",
    "maxCount": 3
  },
  "maxResponseBytes": 1048576,
  "cache": {
    "mode": "default",
    "maxAgeSeconds": null
  },
  "credentialsRef": null,
  "sessionRef": "default"
}
```

Fields:

- `version`: integer request schema version. v0.1 uses `1`.
- `method`: uppercase HTTP method.
- `url`: source-visible URL string when no credentials are embedded in it.
- `urlRef`: optional future host-owned URL descriptor reference. If present,
  it resolves to a host-owned URL and must not be logged as a raw secret.
- `headers`: source-requested headers after allowlist filtering.
- `bodyBase64`: optional base64 request body for small `POST` payloads.
- `bodyRef`: optional future host-owned body reference for large or sensitive
  payloads. It is mutually exclusive with `bodyBase64`.
- `timeoutMs`: source-requested timeout. Host clamps it to manifest and runtime
  maxima.
- `redirect`: source-requested redirect mode and max count. Host clamps it to
  manifest and runtime maxima.
- `maxResponseBytes`: source-requested response body limit. Host clamps it to
  manifest and runtime maxima.
- `cache`: source-requested cache behavior.
- `credentialsRef`: optional host-owned credential reference.
- `sessionRef`: source-visible stable label for selecting a host-owned session
  partition. It is not a cookie value.

Allowed methods for v0.1:

- `GET`
- `HEAD`
- `POST`

Denied methods include `PUT`, `PATCH`, `DELETE`, `CONNECT`, `TRACE`, and any
extension method. Later versions may add methods only through explicit manifest
and host ABI negotiation.

Allowed schemes:

- `https` by default.
- `http` only when the manifest explicitly allows it for a private-library or
  LAN use case and the user trust policy allows cleartext.

Denied schemes include `file`, `content`, `data`, `blob`, `ftp`, `ws`, `wss`,
custom app schemes, loopback-only shortcuts, and scheme-relative URLs.

URL policy:

- Host parses and normalizes the URL before policy checks.
- Host checks the normalized scheme and hostname before dispatch.
- Host rechecks the normalized scheme and hostname after every redirect.
- User info in URLs is forbidden.
- Raw credentials in query parameters are forbidden by validator policy where
  detectable, and credential-bearing URLs should be represented by `urlRef`.

Body and streaming policy:

- v0.1 accepts only small in-memory `bodyBase64` request bodies.
- Request bodies are allowed only with `POST`.
- `bodyBase64` decoded length must be no greater than
  `networkPolicy.maxRequestBytes`.
- `bodyRef` is reserved for a later settings/auth or upload lane and must fail
  closed until supported by host ABI and manifest policy.
- Streaming request bodies are out of scope for v0.1.

Header policy:

- Request header names are case-insensitive and normalized by the host.
- Allowlisted source-controlled headers are initially:
  `Accept`, `Accept-Language`, `Content-Type`, `If-None-Match`,
  `If-Modified-Since`, and a host-selected `User-Agent` profile token.
- Denied request headers include `Authorization`, `Cookie`,
  `Proxy-Authorization`, `Set-Cookie`, `Host`, `Connection`,
  `Transfer-Encoding`, `Upgrade`, `TE`, `Trailer`, `Content-Length`, proxy
  headers, and any header name matching secret-shaped policy.
- Source JSON must not include raw tokens, passwords, cookies, API keys, or
  bearer values in headers.
- The host may inject credentials, cookies, user agent, and referer only from
  host-owned policy, not from source-visible raw values.

## Response Schema

Candidate response envelope:

```json
{
  "ok": true,
  "status": 200,
  "headers": {
    "content-type": "application/json",
    "etag": "\"abc\"",
    "last-modified": "Thu, 21 May 2026 00:00:00 GMT"
  },
  "bodyBase64": "eyJpdGVtcyI6W119",
  "bodyRef": null,
  "finalUrl": "https://api.example.invalid/search?q=koma",
  "redirectCount": 0,
  "timing": {
    "elapsedMs": 42,
    "dnsMs": null,
    "connectMs": null,
    "tlsMs": null,
    "firstByteMs": null
  },
  "truncated": false,
  "fromCache": false
}
```

Fields:

- `status`: HTTP status code when a response was received.
- `headers`: response headers visible to the source after redaction.
- `bodyBase64`: base64 response body when it fits the active response limit.
- `bodyRef`: reserved future host-owned body handle for image/page loading or
  large responses. It must be null in v0.1 unless a later ABI enables it.
- `finalUrl`: normalized final URL after redirects, with credentials removed.
- `redirectCount`: number of followed redirects.
- `timing`: coarse timing values for diagnostics and retry policy.
- `truncated`: true only when the host intentionally returns a partial body
  under an explicit truncation mode. The v0.1 default is to error instead of
  returning partial parseable bodies.
- `fromCache`: true when satisfied from the host cache.

Visible response headers are allowlisted. Initial safe response headers are
`content-type`, `content-length` when not sensitive, `etag`, `last-modified`,
`cache-control` after policy filtering, and coarse cache metadata. `set-cookie`,
authentication challenges containing secrets, proxy headers, and custom secret
headers are not source-visible by default.

Error envelope:

```json
{
  "ok": false,
  "error": {
    "code": "timeout",
    "message": "request exceeded timeoutMs",
    "retryable": true,
    "phase": "request"
  },
  "timing": {
    "elapsedMs": 8000
  }
}
```

Candidate error codes:

- `dns_error`: DNS resolution failed.
- `connect_error`: TCP or proxy connection failed.
- `tls_error`: TLS handshake, certificate, or pinning policy failed.
- `timeout`: the active timeout expired.
- `redirect_error`: redirect count exceeded or redirect target invalid.
- `body_too_large`: body exceeded active request or response byte limit.
- `permission_denied`: manifest, host, scheme, method, host, header,
  credential, trust, or package policy denied the request.
- `cancelled`: host cancellation state was observed.
- `invalid_request`: malformed envelope or unsupported field combination.
- `network_unavailable`: runtime has no enabled network capability.
- `host_internal`: host failed in a way not attributable to source policy.

Redaction and logs:

- Request URL logs must strip userinfo and credential-like query parameters.
- Request/response body bytes are not logged by default.
- Source logs must not include credentials, cookies, raw response bodies, local
  filesystem paths, picker URIs, signing material, or private package paths.
- Host diagnostic artifacts may include policy decisions, normalized host,
  scheme, method, status, byte counts, elapsed time, and error code.
- Logs must preserve `networkPerformed=false` for design-only validators and
  current smoke runs.

## Permission And Manifest Gates

Future HTTP requires all of the following:

```json
{
  "runtime": {
    "abi": "koma-source-abi-v0.1",
    "hostAbi": "koma-host-v0.2-design-http",
    "requiredHostImports": [
      { "module": "koma_host", "name": "log" },
      { "module": "koma_host", "name": "check_cancel" },
      { "module": "koma_host", "name": "http_request" }
    ]
  },
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
      "headers": {
        "requestAllowlist": [
          "Accept",
          "Accept-Language",
          "Content-Type",
          "If-None-Match",
          "If-Modified-Since",
          "User-Agent"
        ],
        "responseAllowlist": [
          "content-type",
          "etag",
          "last-modified",
          "cache-control"
        ],
        "denyRawSecrets": true
      },
      "credentials": {
        "allowCredentialsRef": true,
        "allowRawSecrets": false,
        "cookiePolicy": "host-managed-session"
      },
      "cache": {
        "mode": "host-partitioned",
        "maxEntryBytes": 1048576
      },
      "rateLimit": {
        "maxConcurrentRequests": 2,
        "requestsPerMinute": 60
      }
    }
  }
}
```

Gates:

- `permissions.network=true` is required for future HTTP.
- `koma_host.http_request` must be declared in both runtime imports and
  permission imports.
- `networkPolicy` must be present and complete.
- Scheme, host, method, request bytes, response bytes, timeout, redirects,
  headers, credentials, cache, and rate limits must be policy-checked before
  dispatch.
- Per-source settings may enable optional credential references, but they must
  not expand host/domain/scheme policy beyond the manifest and user trust
  decision.
- Private package trust may decide whether a package is allowed to request
  network capability at all. Trust approval does not bypass URL/header/secret
  policy.
- Missing or incompatible fields fail closed.

Current validators must continue to treat the future manifest above as invalid
for current runtime execution because it uses `network=true`,
`koma-host-v0.2-design-http`, and `koma_host.http_request`.

## Cookies, Sessions, And Credentials

Source-visible JSON must not contain raw cookies or secrets by default.

Credential model:

- Source settings may expose labels or references such as
  `credentialsRef: "primary"`.
- The host resolves references from user-owned settings or account storage.
- The source never sees resolved passwords, tokens, API keys, cookie bytes, or
  bearer headers unless a later explicit unsafe capability is designed.
- Credential references are scoped by package id, source id, account, and
  profile.

Cookie/session model:

- Cookies are stored in a host-owned jar.
- Cookie jars are partitioned by package id, source id, user account/profile,
  host, and `sessionRef`.
- Sources can request a session partition by stable label, but cannot enumerate
  or read cookie values.
- `Set-Cookie` response headers are consumed by the host and redacted from the
  source response envelope unless a later narrow diagnostic mode exists.

Relationship to future settings/auth lane:

- `login`, `status`, and `logout` should operate on host-owned credential and
  session references.
- `login` may produce or refresh `credentialsRef` and session state through a
  host-mediated settings/auth flow.
- `status` reports coarse authenticated/expired/needs-action state, not raw
  secrets.
- `logout` clears host-owned credentials/session partitions for that source and
  account.

## Redirects, Cache, Rate Limit, And Headers

Redirect policy:

- Default mode is `none` unless manifest policy allows `follow`.
- Default max count is host-defined and no more than the manifest max.
- Every redirect target is normalized and revalidated against allowed schemes
  and hosts.
- `https` to `http` downgrade is denied by default.
- Cross-host redirects are denied unless the target host is also explicitly
  allowed.
- Redirect responses must not leak `Location` values containing credentials
  into logs or source-visible errors.

Cache policy:

- Cache keys are partitioned by package id, source id, account/profile,
  sessionRef, normalized URL, method, selected vary headers, credential
  reference, and relevant network policy version.
- Host must not share cached authenticated responses across package/source or
  account partitions.
- Source cache modes are candidates: `default`, `no-store`, `reload`,
  `force-cache`, and `only-if-cached`.
- Host policy can downgrade source cache requests to safer behavior.

Rate limit and retry:

- Host enforces max concurrent requests per source instance and per package.
- Host enforces request rate windows per source/account/host.
- Host may return `permission_denied` or `timeout`/`cancelled` style errors for
  rate-limited work depending on the final error taxonomy.
- Sources may retry only when the error envelope marks `retryable=true`, and
  should use host-provided retry-after metadata if exposed.
- Host should avoid automatic unsafe replay of non-idempotent `POST` requests.

User agent and referer:

- Sources request a user-agent profile token, not an arbitrary raw user-agent,
  unless the manifest and user trust policy allow it.
- Host constructs the final user-agent string.
- `Referer` is denied from source-controlled headers by default. A later image
  loading descriptor may allow host-owned referer policy for specific hosts.

## Cancellation And Resource Limits

HTTP cancellation must compose with the current `koma_host.check_cancel` import:

- Source SDK checks `check_cancel()` before starting work, before HTTP calls,
  and between parse/page loops.
- Host checks cancellation before policy validation, before dispatch, while
  waiting for I/O where possible, and before writing the response envelope.
- Cancellation returns deterministic `cancelled`, not an arbitrary host error.

Timeouts:

- Active timeout is the minimum of source request, manifest policy, runtime
  policy, and host global cap.
- Timeout returns deterministic `timeout`.
- Timeout and cancellation races should prefer `cancelled` if cancellation was
  already observed before timeout handling; otherwise `timeout` is acceptable
  if the timer fired first.

Limits:

- `maxRequestBytes`: decoded request body limit.
- `maxResponseBytes`: decoded response body limit.
- `maxHeaderBytes`: total visible and internal header byte budget.
- `maxHeaders`: maximum response/request header count.
- `maxRedirects`: redirect count limit.
- `maxConcurrentRequests`: per source instance and package/account cap.
- `maxHttpEnvelopeBytes`: upper bound for the JSON response/error envelope
  written to `out_ptr`.
- `maxElapsedMs`: host-level wall-clock cap for the entire source operation.

If a response body exceeds `maxResponseBytes`, v0.1 returns `body_too_large`.
It must not return partial content unless the request explicitly opted into a
future truncation mode and the response declares `truncated=true`.

## Image And Page Loading Relationship

Current source API fixtures keep `capabilities.imageUrl=false` and
`hostHints.network=false`. Future network support must not let page lists expose
raw credentials, cookies, or private host storage paths.

Two future page image shapes are candidates:

```json
{
  "kind": "remoteUrl",
  "url": "https://cdn.example.invalid/page/1.jpg"
}
```

```json
{
  "kind": "hostImageRequest",
  "request": {
    "urlRef": "page-image-opaque-ref",
    "headersRef": "page-image-headers-ref",
    "sessionRef": "default",
    "maxResponseBytes": 8388608
  }
}
```

Policy:

- Under `network=false`, raw remote URLs in `get_pages` responses remain
  invalid.
- Under future `network=true`, raw remote URLs may be allowed only when they
  contain no credentials and match manifest/host policy.
- Credentialed image loads should use host-owned request descriptors or refs so
  cookies, authorization headers, and referer policy remain host-owned.
- Page image body size, content type, cache, and redirect policy need a future
  4B design before implementation.

## Validation Plan And Negative Fixtures

Future 3X negative policy fixtures should include:

- `network=false` with `koma_host.http_request`.
- `network=true` without `koma_host.http_request`.
- `koma_host.http_request` import missing from `runtime.requiredHostImports`.
- `koma_host.http_request` missing from `permissions.hostImports`.
- unsupported `runtime.hostAbi` or request `version`.
- disallowed scheme such as `file`, `content`, `data`, `ftp`, or cleartext
  `http` without explicit policy.
- disallowed host before dispatch.
- disallowed host after redirect.
- redirect downgrade from `https` to `http`.
- disallowed method such as `DELETE`, `PATCH`, or `CONNECT`.
- raw `Authorization`, `Cookie`, `Proxy-Authorization`, or `Set-Cookie` header
  in source-visible JSON.
- credential-like URL userinfo or query parameters.
- raw cookie visible in response headers.
- raw credential visible in settings schema, manifest, logs, error messages, or
  response envelope.
- request body over `maxRequestBytes`.
- response body over `maxResponseBytes`.
- too many headers or oversized headers.
- timeout with deterministic `timeout` error.
- cancellation with deterministic `cancelled` error.
- response log leak containing URL secrets, headers, body, cookies, or
  credential refs resolved to raw values.
- remote page URL under `network=false`.
- credentialed page image represented as raw URL instead of host-owned request
  descriptor.

Existing validators that must keep passing:

- `host-imports/validate-http-boundary.py` accepts only the design-only HTTP
  fixture and reports `runtimeEnabled=false` and `networkPerformed=false`.
- `source-package/validate-source-package.py` rejects the HTTP design fixture
  for the current runtime.
- Current source package validation accepts `manifest.example.json` with
  `network=false` and only `koma_host.log`/`koma_host.check_cancel`.
- Archive smoke and archive negative fixtures continue to prove network/http
  import drift is rejected.
- Source API fixtures continue to reject remote page URLs under
  `hostHints.network=false`.
- Rust fixture runtime smoke continues to report `hostHints.network=false`.

## Non-Goals

- No public source marketplace or public source index.
- No remote source install or update channel.
- No built-in source list.
- No WebView workflow DSL.
- No APK source extension flow.
- No real HTTP implementation.
- No WAMR host runner HTTP registration.
- No Rust SDK HTTP wrapper.
- No HarmonyOS product runtime, UI, import, install, or image loader changes.
- No raw credential storage design beyond references and host ownership.
- No signing material, generated wasm/archive/HAP output, or WAMR vendor source
  changes in git.
