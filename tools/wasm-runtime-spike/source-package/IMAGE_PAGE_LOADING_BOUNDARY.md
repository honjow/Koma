# Koma Image/Page Loading Boundary

This document defines a design/tooling-only boundary for future source page and
image loading. It does not enable product runtime image loading, remote image
requests, HTTP, WebView behavior, source markets, or built-in sources.

## Current Runtime

The current WASM source runtime remains fail-closed:

- `network=false`.
- allowed host imports are exactly `koma_host.log` and
  `koma_host.check_cancel`.
- `koma_host.http_request` is not available.
- source page responses must not contain remote URLs, local filesystem paths,
  picker URIs, app-private paths, raw headers, cookies, authorization values, or
  executable request descriptors.

Today, source page descriptors may only be local test/placeholder descriptors
that are opaque and non-loadable by product code. They are useful for validating
page ordering, cache identity, error shape, cancellation links, and resource
policy without creating a network-capable runtime.

## Descriptor Strategy

Future page/image loading has two conceptual ownership modes:

- `host_loaded`: the host owns bytes, transport, caching, cookies, headers,
  referer policy, timeouts, cancellation, and logging. A source may provide only
  opaque page identity and host-safe metadata.
- `source_resolved`: a future source may resolve an upstream image request only
  after explicit host ABI, manifest permission, HTTP/image capability, method,
  scheme, header, credential, cache, timeout, and redirect gates exist.

For the current runtime, only `host_loaded` placeholder/test descriptors are
accepted by the fixture validator. Future `source_resolved` request descriptors
may be documented only when marked `designOnly=true` and `futureDisabled=true`;
they are not accepted as current source API page data.

## Cache Keys

Cache identity must be deterministic but must not expose transport details.

Allowed cache key material:

- source-owned opaque page id.
- normalized source, manga, chapter, and page identity.
- integer cache policy version.
- host-owned namespace or epoch.

Forbidden cache key material:

- raw URLs or URL fragments.
- request or response headers.
- cookies, bearer tokens, API keys, session ids, passwords, or secret refs with
  values.
- local filesystem paths, picker URIs, app-private paths, cache paths, or
  artifact paths.

The source may suggest opaque ids; the host builds the final cache key. Changing
normalization or source package version should produce a deterministic cache
version bump.

## Headers And Credentials

Current source responses must not include raw header maps. Future headers are
host-owned, redacted, and allowlisted. The source must not return surprise
`Cookie`, `Authorization`, `Referer`, `User-Agent`, `Set-Cookie`, `Host`, or
proxy headers. Cookies and credentials are host-owned settings/auth concerns and
must never appear in source page/image descriptors or logs.

## Future Image Request Descriptor

A future disabled descriptor shape may name policy fields without carrying an
executable request:

```json
{
  "designOnly": true,
  "futureDisabled": true,
  "methodPolicy": ["GET", "HEAD"],
  "schemePolicy": ["https"],
  "headerPolicy": {
    "hostOwned": true,
    "redacted": true,
    "allowlist": ["Accept", "Accept-Language"],
    "forbiddenRaw": ["Cookie", "Authorization", "Referer", "User-Agent"]
  },
  "timeoutPolicy": {
    "hostOwnedWallClock": true,
    "maxMs": 10000
  }
}
```

This is not a request. It has no URL, no header values, no cookies, no body, no
runtime handler, and no product image loader.

## Errors, Cache, And Cancellation

Page/image failures should be structured and host-mappable. Candidate codes:

- `network_disabled`
- `permission_denied`
- `not_found`
- `cancelled`
- `timeout`
- `resource_limit_exceeded`
- `cache_miss`
- `stale_cache`
- `decode_error`
- `source_error`

Stale cache behavior is host-owned. Future hosts may serve stale bytes only
after policy checks and should report whether data is fresh, stale, absent, or
evicted. Cancellation remains tied to `koma_host.check_cancel`; long page
resolution loops should poll cancellation and surface `cancelled`.

## Tooling Evidence

`validate-image-page-fixtures.py` validates a local fixture corpus. It performs
no network I/O, starts no subprocesses, executes no WASM, and writes a JSON
report under `--artifact-dir`. It accepts only fail-closed current fixtures and
rejects remote URL descriptors, raw local paths, picker/app-private paths,
credential/header leaks, unsafe cache keys, missing opaque ids, HTTP import or
`network=true` drift, and product/executable runtime flags.
