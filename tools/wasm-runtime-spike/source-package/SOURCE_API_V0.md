# Koma Source API v0.1 Candidate

This document defines a candidate source-author/runtime contract for real manga
source operations on top of the existing WASM package/runtime boundary. It is a
design spec for future tooling and product work, not a product runtime.

## Status And Non-Goals

Status:

- Research/tooling-only.
- Candidate API shape, not a final public SDK or stable product ABI.
- Existing package/archive/runtime validators remain the active safety gates.
- Current host ABI remains `koma-host-v0.1` with only `koma_host.log` and
  `koma_host.check_cancel`.
- Network remains disabled by default. `hostHints.network=false` is expected in
  current fixture responses.

Non-goals:

- No HarmonyOS product runtime, UI, install/import flow, or source selection.
- No source market, public source index, remote install, or built-in sources.
- No real HTTP implementation or enabled HTTP host import.
- No bundled third-party manga source behavior.
- No WAMR vendor/source changes, generated wasm/archive outputs, HAP outputs,
  signing material, or Rust target directories in git.

## Relationship To Existing Boundaries

This API draft builds on:

- `SOURCE_RUNTIME_BOUNDARY.md`: ABI/result-buffer/import boundary and current
  Linux WAMR smoke evidence.
- `HARMONYOS_ARCHIVE_INGESTION_BOUNDARY.md`: future local archive ingestion and
  app-private staging boundary.
- `SOURCE_PACKAGE_TRUST_BOUNDARY.md`: future package trust/provenance boundary.
- `../host-imports/http-boundary.md`: design-only future HTTP host import.

This file does not change those boundaries. In particular, HTTP remains
design-only and current validation must still reject `network=true` and
`koma_host.http_request`.

## Call Model

The host calls source operations through exported WASM entrypoints. Two shapes
are acceptable candidates:

- explicit exports such as `koma_source_search`,
  `koma_source_get_manga`, `koma_source_get_chapters`, and
  `koma_source_get_pages`;
- one dispatcher export such as `koma_source_call(operation_ptr,
  operation_len, request_ptr, request_len)`.

The current explicit export style is preferred for the next fixture because it
is easy to validate statically. A dispatcher remains possible if operation
versioning or feature discovery becomes simpler through a single call.

Transport stays the existing result-buffer plus UTF-8 JSON payload envelope:

```text
host JSON request -> guest memory -> exported operation -> KOMA result buffer
-> host validates payload length and JSON -> koma_source_free(result_ptr)
```

Current allowed host imports:

- `koma_host.log(level, message_ptr, message_len)`.
- `koma_host.check_cancel() -> i32`.

Logging rules:

- Logs are diagnostic only. Hosts should sanitize and may drop logs.
- Source logs must not include credentials, cookies, raw request/response
  bodies, local filesystem paths, user picker URIs, or signing material.

Cancellation rules:

- The SDK should expose a cheap `check_cancel()` helper.
- Source operations should check cancellation before expensive parsing loops and
  between page/chapter batches.
- If cancelled, return a structured `cancelled` error. Hosts may also terminate
  execution by timeout or runtime policy.

HTTP and image loading:

- `koma_host.http_request` is future/design-only.
- Source API requests include `hostHints.network=false` today so fixture logic
  can branch without implying network capability.
- Future network support must be gated by manifest permissions, host ABI,
  allowed schemes/hosts/methods, timeout, credential, cookie, and logging
  policy.

## Common Request Envelope

Every operation request should be valid UTF-8 JSON:

```json
{
  "version": 1,
  "requestId": "host-generated-opaque-id",
  "operation": "search",
  "sourceId": "local.test.koma.fixture",
  "args": {},
  "settings": {},
  "hostHints": {
    "abi": "koma-host-v0.1",
    "network": false,
    "maxPayloadBytes": 1048576,
    "locale": "zh-Hans",
    "contentRatingPolicy": "host-filtered"
  }
}
```

Fields:

- `version`: source API request envelope version. Candidate v0.1 uses integer
  `1`.
- `requestId`: host-owned opaque id for correlation and cancellation logs.
- `operation`: operation name, even when explicit exports are used, so fixtures
  can validate self-consistency.
- `sourceId`: manifest package/source id.
- `args`: operation-specific request fields.
- `settings`: host-validated source settings. Secrets should be references, not
  raw values, until a credential policy exists.
- `hostHints`: host runtime facts. `network=false` means the source must not
  attempt network behavior.

## Common Response Envelope

Every operation response JSON should fit inside `maxPayloadBytes`:

```json
{
  "version": 1,
  "ok": true,
  "operation": "search",
  "data": {},
  "warnings": [],
  "hostHints": {
    "network": false
  }
}
```

Error response:

```json
{
  "version": 1,
  "ok": false,
  "operation": "search",
  "error": {
    "code": "invalid_request",
    "message": "query must be a string",
    "retryable": false,
    "details": {
      "field": "args.query"
    }
  },
  "hostHints": {
    "network": false
  }
}
```

Candidate error codes:

- `invalid_request`: malformed JSON, missing field, unsupported filter, or bad
  cursor.
- `not_found`: source-owned id is unknown.
- `cancelled`: source observed cancellation.
- `timeout`: operation exceeded host/source limit.
- `network_disabled`: request requires network but current host hints deny it.
- `permission_denied`: future permission/policy gate denied the operation.
- `parse_error`: source could not parse upstream/static data.
- `source_error`: source-specific failure that does not fit another code.
- `internal_error`: source bug or unexpected state.

Messages are developer diagnostics, not localized UI strings. Hosts should map
codes to user-facing copy.

## Core Operations v0.1

### `search(query, page, filters/settings)`

Purpose: return manga summaries matching a user query and optional source
filters. Empty query behavior is source-defined; sources may return popular,
latest, or an `invalid_request` error until `get_home_sections` exists.

Request:

```json
{
  "version": 1,
  "requestId": "req-001",
  "operation": "search",
  "sourceId": "local.test.koma.fixture",
  "args": {
    "query": "koma",
    "page": {
      "cursor": null,
      "limit": 20
    },
    "filters": {
      "sort": "relevance",
      "tags": ["slice-of-life"]
    }
  },
  "settings": {
    "language": "zh-Hans"
  },
  "hostHints": {
    "network": false,
    "maxPayloadBytes": 1048576
  }
}
```

Response:

```json
{
  "version": 1,
  "ok": true,
  "operation": "search",
  "data": {
    "items": [
      {
        "id": "manga:fixture-series",
        "title": "Fixture Series",
        "subtitle": "Static fixture result",
        "cover": {
          "kind": "none"
        },
        "authors": ["Koma Fixture"],
        "status": "unknown",
        "contentRating": "unknown",
        "sourceTags": ["fixture"]
      }
    ],
    "page": {
      "nextCursor": null,
      "hasMore": false
    }
  },
  "hostHints": {
    "network": false
  }
}
```

### `get_manga(mangaId)`

Purpose: return source-owned manga detail for a summary id. The host must pass
the `id` back exactly and must not parse it.

Request:

```json
{
  "version": 1,
  "requestId": "req-002",
  "operation": "get_manga",
  "sourceId": "local.test.koma.fixture",
  "args": {
    "mangaId": "manga:fixture-series"
  },
  "settings": {},
  "hostHints": {
    "network": false
  }
}
```

Response:

```json
{
  "version": 1,
  "ok": true,
  "operation": "get_manga",
  "data": {
    "manga": {
      "id": "manga:fixture-series",
      "title": "Fixture Series",
      "alternateTitles": ["Fixture Manga"],
      "description": "Static source API fixture detail.",
      "cover": {
        "kind": "none"
      },
      "authors": ["Koma Fixture"],
      "artists": [],
      "status": "unknown",
      "contentRating": "unknown",
      "language": "zh-Hans",
      "tags": ["fixture"],
      "links": []
    }
  },
  "hostHints": {
    "network": false
  }
}
```

### `get_chapters(mangaId)`

Purpose: return chapters for one manga id. Chapter ids are source-owned opaque
ids and should remain stable across calls when the upstream source identity has
not changed.

Request:

```json
{
  "version": 1,
  "requestId": "req-003",
  "operation": "get_chapters",
  "sourceId": "local.test.koma.fixture",
  "args": {
    "mangaId": "manga:fixture-series",
    "page": {
      "cursor": null,
      "limit": 100
    }
  },
  "settings": {},
  "hostHints": {
    "network": false
  }
}
```

Response:

```json
{
  "version": 1,
  "ok": true,
  "operation": "get_chapters",
  "data": {
    "items": [
      {
        "id": "chapter:fixture-series:001",
        "mangaId": "manga:fixture-series",
        "title": "Chapter 1",
        "chapterNumber": "1",
        "volumeNumber": null,
        "language": "zh-Hans",
        "publishedAt": null,
        "updatedAt": null,
        "pageCount": 3
      }
    ],
    "page": {
      "nextCursor": null,
      "hasMore": false
    }
  },
  "hostHints": {
    "network": false
  }
}
```

### `get_pages(chapterId)`

Purpose: return ordered page/image descriptors for a chapter. The response must
not contain raw local filesystem paths. Current `network=false` fixtures should
return static placeholder descriptors only; future network image descriptors
require a separate HTTP/image loading policy.

Request:

```json
{
  "version": 1,
  "requestId": "req-004",
  "operation": "get_pages",
  "sourceId": "local.test.koma.fixture",
  "args": {
    "chapterId": "chapter:fixture-series:001"
  },
  "settings": {},
  "hostHints": {
    "network": false,
    "imageStrategy": "descriptor-only"
  }
}
```

Response:

```json
{
  "version": 1,
  "ok": true,
  "operation": "get_pages",
  "data": {
    "chapterId": "chapter:fixture-series:001",
    "pages": [
      {
        "id": "page:fixture-series:001:0001",
        "index": 0,
        "image": {
          "kind": "placeholder",
          "label": "fixture-page-1",
          "width": 1200,
          "height": 1800
        }
      }
    ]
  },
  "hostHints": {
    "network": false
  }
}
```

## Data Schemas

These are candidate JSON shapes, not formal JSON Schema files yet.

Manga summary/result item:

```json
{
  "id": "manga:opaque-id",
  "title": "Title",
  "subtitle": "Optional subtitle",
  "cover": {
    "kind": "none"
  },
  "authors": ["Author"],
  "status": "ongoing",
  "contentRating": "safe",
  "sourceTags": ["tag"]
}
```

Manga detail:

```json
{
  "id": "manga:opaque-id",
  "title": "Title",
  "alternateTitles": ["Alt"],
  "description": "Plain text description.",
  "cover": {
    "kind": "none"
  },
  "authors": ["Author"],
  "artists": ["Artist"],
  "status": "completed",
  "contentRating": "safe",
  "language": "zh-Hans",
  "tags": ["tag"],
  "links": [
    {
      "label": "official",
      "url": "https://example.invalid/title"
    }
  ]
}
```

Chapter:

```json
{
  "id": "chapter:opaque-id",
  "mangaId": "manga:opaque-id",
  "title": "Chapter title",
  "chapterNumber": "12.5",
  "volumeNumber": "2",
  "language": "zh-Hans",
  "publishedAt": "2026-05-21T00:00:00Z",
  "updatedAt": null,
  "pageCount": 24
}
```

Page/image descriptor:

```json
{
  "id": "page:opaque-id",
  "index": 0,
  "image": {
    "kind": "remoteUrl",
    "url": "https://images.example.invalid/page.jpg",
    "headersRef": null,
    "width": 1200,
    "height": 1800,
    "mime": "image/jpeg"
  }
}
```

Allowed `image.kind` candidates:

- `none`: no cover/page image available.
- `placeholder`: static fixture or generated placeholder descriptor.
- `remoteUrl`: future network image URL; invalid while `network=false`.
- `imageRequest`: future host-mediated image request descriptor, intended to
  avoid exposing raw credential headers or cookies to sources.

Page cursor/pagination:

```json
{
  "nextCursor": "source-owned-cursor",
  "hasMore": true,
  "totalHint": 123
}
```

Rules:

- `cursor` and `nextCursor` are source-owned opaque strings.
- Hosts may store cursors temporarily but should not parse them.
- `limit` is a host request hint. Sources may return fewer items.
- `totalHint` is optional and not authoritative.

Structured error:

```json
{
  "code": "not_found",
  "message": "manga id is not known",
  "retryable": false,
  "details": {
    "idKind": "manga"
  }
}
```

Host hints:

```json
{
  "abi": "koma-host-v0.1",
  "network": false,
  "maxPayloadBytes": 1048576,
  "maxMemoryPages": 2,
  "locale": "zh-Hans",
  "imageStrategy": "descriptor-only",
  "contentRatingPolicy": "host-filtered"
}
```

## ID And URL Policy

- Manga, chapter, page, and cursor ids are source-owned opaque strings.
- Hosts must not split, decode, infer source URLs from, or normalize source ids
  beyond treating them as bounded UTF-8 strings.
- Sources should keep ids stable across calls and package upgrades when the
  upstream item identity is stable.
- Responses must not include raw local filesystem paths, picker URIs,
  app-private storage paths, archive paths, or generated build paths.
- Current `network=false` responses should use `none` or `placeholder` image
  descriptors.
- Future URL/image support must go through a host policy. Raw remote URLs may be
  acceptable only after network permission, allowed host/scheme checks,
  credential redaction, redirect policy, cache/session partitioning, and log
  policy are defined.
- Future authenticated images should prefer `imageRequest` or another
  host-mediated descriptor over exposing cookies, authorization headers, or
  local paths in source responses.

## Rust SDK Author API Direction

The Rust source-author API should hide the ABI/result-buffer details behind a
small `no_std`-friendly layer. Candidate shape:

```rust
pub trait Source {
    fn search(&self, req: SearchRequest) -> SourceResult<SearchResponse>;
    fn get_manga(&self, req: GetMangaRequest) -> SourceResult<GetMangaResponse>;
    fn get_chapters(
        &self,
        req: GetChaptersRequest,
    ) -> SourceResult<GetChaptersResponse>;
    fn get_pages(&self, req: GetPagesRequest) -> SourceResult<GetPagesResponse>;
}
```

SDK responsibilities:

- export ABI functions or dispatcher glue;
- parse request envelopes and serialize response envelopes;
- write the KOMA result buffer and free guest-owned result memory;
- wrap `koma_host.log` and `koma_host.check_cancel`;
- enforce `maxPayloadBytes` before returning;
- include `hostHints.network=false` in current fixture-compatible responses;
- provide fixture builders for static search/detail/chapter/page examples.

Direction:

- Keep `no_std` compatibility for the source core.
- Allow optional `alloc` for JSON and response buffers.
- Avoid exposing raw host imports directly to source authors.
- Keep fixture compatibility with the existing Rust SDK source package path.
- Treat exact module names, trait names, serde strategy, allocator choice, and
  error enum shape as candidate design, not final public API.

## Optional Future Operations

These are outside v0.1 core but should fit the same request/response envelope:

- `get_home_sections()`: source-defined shelves such as popular, latest, or
  curated sections.
- `get_latest(page)`: latest-updated manga summaries when the source supports
  it.
- `login`, `status`, `logout`: future account/session flow. Must not expose raw
  credentials to WASM without a separate credential policy.
- `resolve_image_request()`: future host-mediated image loading strategy where
  the source returns a descriptor and the host performs the network request.

## Validation And Future Tests

Current fixture validator:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures
```

The fixture corpus covers valid request/response envelopes for `search`,
`get_manga`, `get_chapters`, and `get_pages`, plus invalid cases for operation,
`hostHints.network`, response envelope shape, path/URI leaks, remote page image
descriptors while `network=false`, non-opaque ids, and malformed pagination.

Current validators that must continue to pass for this design-only lane:

- `run-source-archive-smoke.py`: archive validation, extraction, and Linux WAMR
  execution evidence.
- `validate-archive-negative-fixtures.py`: malformed archive rejection.
- `package-source-archive.py`: local archive packaging/validation boundary.
- `validate-source-package.py --build-rust-fixture`: manifest, wasm, import,
  export, capability, settings, and `network=false` checks.
- `validate-http-boundary.py`: HTTP remains design-only and current package
  validation rejects HTTP/network drift.

Missing future tests before product enablement:

- JSON schema fixtures for every core operation.
- Invalid request and invalid response fixtures.
- Stable opaque id behavior across search/detail/chapter/page calls.
- Pagination cursor validation and malformed cursor rejection.
- Cancellation observed during long searches and chapter/page loops.
- Timeout handling and host termination behavior.
- Result size and memory limit enforcement for large result sets.
- Structured error code mapping and log redaction.
- `network=false` rejection of `remoteUrl` or HTTP-dependent image descriptors.
- HTTP permission gates, host allowlists, redirects, credentials, cookies, cache
  partitioning, and response size limits if a future ABI enables network.
- Compatibility tests across `koma-source-abi` and `koma-host` versions.
