# Koma Source API v0.1/v0.2 Candidate

This document defines a candidate source-author/runtime contract for real manga
source operations on top of the existing WASM package/runtime boundary. It is a
design spec for future tooling and product work, not a product runtime.

## Status And Non-Goals

Status:

- Research/tooling-only.
- Candidate API shape, not a final public SDK or stable product ABI.
- Existing package/archive/runtime validators remain the active safety gates.
- General host ABI remains `koma-host-v0.1` with only `koma_host.log` and
  `koma_host.check_cancel`. S5 adds a local WAMR-only
  `koma-host-v0.1-fixture-http` smoke that imports `koma_host.http_request`
  only when the manifest declares `experimentalHttpFixture`.
- S6 extends only that local WAMR fixture lane with
  `koma-host-v0.1-fixture-http-html` and host-owned HTML descriptors for
  `html_parse`, `html_select`, `html_attr`, `html_text`, and `html_close` when
  the manifest declares `experimentalHtmlFixture`.
- Network remains disabled by default. `hostHints.network=false` is expected in
  current fixture requests, responses, and metadata fixtures.
- v0.2 extends the v0.1 four-operation fixture contract with source metadata,
  feature discovery, browse/config models, image request descriptors, and
  structured optional-operation errors. It does not enable runtime HTTP.

Non-goals:

- No HarmonyOS product runtime, UI, install/import flow, or source selection.
- No source market, public source index, remote install, or built-in sources.
- No real HTTP implementation, real network I/O, Harmony app HTTP enablement,
  or public source support. The S5 HTTP import is a deterministic local fixture
  under `fixture.koma.local`.
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
- `IMAGE_PAGE_LOADING_BOUNDARY.md`: design/tooling-only future image/page
  loading strategy, cache identity, header policy, and network gates.
- `../host-imports/http-boundary.md`: design-only future HTTP host import.
- `../host-imports/http-host-import-v0.md`: concrete HTTP v0.1 candidate for
  future host ABI, policy, settings/auth, and resource-limit work.

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

Current general allowed host imports:

- `koma_host.log(level, message_ptr, message_len)`.
- `koma_host.check_cancel() -> i32`.

S5 local WAMR fixture import:

- `koma_host.http_request(req_ptr, req_len, out_ptr, out_cap) -> i32`, accepted
  only by the fixture host ABI and only for static `fixture.koma.local` data.

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

- `koma_host.http_request` is fixture-only in S5 local WAMR tooling and remains
  product-disabled.
- `koma_host.html_parse/select/attr/text/close` are fixture-only in S6 local
  WAMR tooling and remain product-disabled. The host owns descriptors, accepts
  only deterministic fixture HTML, permits only a tiny selector/attribute
  subset, and denies unsupported selectors/attributes.
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

- `unimplemented`: optional operation is known by the API but unsupported by
  this source or disabled by its capabilities.
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

These four operations remain the current/core compatibility surface:

- `search`
- `get_manga`
- `get_chapters`
- `get_pages`

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

## Source API v0.2 Staging

v0.2 keeps the v0.1 envelope and core operations compatible. The new contract is
primarily about making the source-author model useful and discoverable before
the runtime enables HTTP, auth, or product UI.

Operation stages:

- Current/core: `search`, `get_manga`, `get_chapters`, `get_pages`.
- Next browse operations: `get_listings`, `get_manga_list`, `get_home`,
  `get_filters`.
- Config/image operations: `get_settings`, `get_image_request`.
- Future/design-only: `process_page_image`, `page_description`, `base_url`,
  `login`, `auth`, `deeplink`, and `migration`.

Rules:

- Unknown operation names fail closed. A host must never silently default an
  unknown operation to `search`.
- A known optional operation can return a structured `unimplemented` error.
- Current fixtures keep `hostHints.network=false` and must not contain remote
  URLs, raw local paths, picker/content URIs, app-private paths, raw cookies,
  raw tokens, `Authorization` headers, or passwords.
- Image requests are descriptors/references. They do not carry raw URLs or
  credential header maps while current network support is disabled. The S7
  WAMR fixture uses a controlled `fixture-image:` URL token only; no real
  network is performed.

### SourceInfo

`SourceInfo` is static or cheaply computed source metadata:

```json
{
  "id": "local.test.koma.fixture",
  "name": "Koma Fixture Source",
  "version": "0.2.0",
  "apiVersion": "0.2",
  "language": "zh-Hans",
  "author": "Koma Fixture",
  "description": "Static Source API v0.2 fixture source.",
  "contentRating": "unknown"
}
```

The `id` is the package/source id. It is not a URL and must not expose a local
path.

### SourceCapabilities

Capabilities let the host avoid guessing from operation names or accidental
export presence:

```json
{
  "search": true,
  "mangaDetail": true,
  "chapters": true,
  "pages": true,
  "listings": true,
  "mangaList": true,
  "home": true,
  "filters": true,
  "settings": true,
  "imageRequest": true,
  "future": {
    "process_page_image": false,
    "page_description": false,
    "base_url": false,
    "login": false,
    "auth": false,
    "deeplink": false,
    "migration": false
  }
}
```

`future` entries are documentary only in v0.2 fixtures and must remain disabled
until a later runtime lane defines their host policies.

The current Rust/WAMR fixture exposes `koma_source_info` as the functional
discovery entrypoint. Local smoke validation calls that export and requires a
v0.2-shaped envelope with source id/name/version/API version/language/content
rating, core capabilities (`search`, `mangaDetail`, `chapters`, `pages`) set to
`true`, implemented browse capabilities (`listings`, `mangaList`, `home`,
`filters`) set to `true`, implemented config/image capabilities (`settings`,
`imageRequest`) set to `true`, all future capabilities set to `false`, and
`hostHints.network=false`. Static package validation accepts `koma_source_info`
plus browse/settings/image exports as optional static exports and records the
same runtime evidence when `--build-rust-fixture` is used.

### Browse Operations

`get_listings` returns source-defined browse entry points:

```json
{
  "listings": [
    {
      "id": "listing:popular",
      "name": "Popular",
      "kind": "popular"
    }
  ]
}
```

`get_manga_list` returns a `MangaPageResult` for a listing id plus pagination
and optional filters:

```json
{
  "listingId": "listing:popular",
  "items": [],
  "page": {
    "nextCursor": null,
    "hasMore": false
  }
}
```

`get_home` returns grouped home sections:

```json
{
  "sections": [
    {
      "id": "home:featured",
      "title": "Featured",
      "kind": "mangaList",
      "items": []
    },
    {
      "id": "home:latest-link",
      "title": "Latest",
      "kind": "listingLink",
      "listingId": "listing:latest"
    }
  ]
}
```

`get_filters` returns author-defined filter controls. Candidate kinds are
`text`, `sort`, `check`, `select`, `multiSelect`, `note`, and `range`.

### Settings

`get_settings` returns a schema, not raw current secret values. Candidate kinds
are `string`, `number`, `boolean`, `select`, `group`, `loginRef`, and
`secretRef`.

```json
{
  "settings": [
    {
      "id": "setting:language",
      "label": "Language",
      "kind": "select",
      "default": "zh-Hans",
      "options": [
        {
          "id": "zh-Hans",
          "label": "Chinese"
        }
      ]
    },
    {
      "id": "setting:login-reference",
      "label": "Login reference",
      "kind": "loginRef",
      "loginRefKey": "login:primary"
    }
  ]
}
```

`loginRef` and `secretRef` mean the host owns any real credential/session
material and passes only bounded references through the source API. `login`
capability remains false until a later lane defines executable login behavior.

### ImageRequest Descriptor

`get_image_request` converts a source page/image reference into a
host-mediated descriptor:

```json
{
  "imageRequest": {
    "id": "image-request:fixture-page-1",
    "url": "fixture-image:fixture-page-1",
    "headersRef": "headers:image:fixture-page-1",
    "credentialsRef": "credentials:image:primary",
    "sessionRef": "session:image:primary",
    "resourceRef": "image-resource:fixture-page-1",
    "method": "GET",
    "cacheKey": "image-cache:fixture-page-1",
    "requiresAuth": true
  }
}
```

Current fixtures intentionally use `headersRef`, `credentialsRef`,
`sessionRef`, `resourceRef`, and `cacheKey` instead of raw cookies, tokens,
authorization headers, or local paths. The `url` is a controlled fixture token,
not a network URL. A later host-import lane must define URL policy before any
real HTTP image loading is enabled.

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
- `imageRequest`: host-mediated image request descriptor, intended to avoid
  exposing raw credential headers or cookies to sources.

`remoteUrl` remains future/design-only for the current fixture validator and is
invalid while `hostHints.network=false`.

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

## v0.1 Compatibility Notes

- v0.1 fixtures containing only `search`, `get_manga`, `get_chapters`, and
  `get_pages` remain valid when they obey the common envelope, opaque id,
  pagination, `network=false`, and leak-prevention rules.
- v0.2 adds metadata and optional operation shapes without changing the v0.1
  response envelope.
- Older sources can report unsupported v0.2 optional operations by returning a
  structured `unimplemented` error for known optional operation names.
- Hosts should use capabilities/export discovery before calling optional
  operations.

## Validation And Future Tests

Current fixture validator:

```sh
python3 tools/wasm-runtime-spike/source-package/validate-source-api-fixtures.py \
  --fixture-dir tools/wasm-runtime-spike/source-package/source-api-fixtures \
  --artifact-dir /path/to/artifacts/source-api-fixtures
```

The fixture corpus covers valid request/response envelopes for `search`,
`get_manga`, `get_chapters`, `get_pages`, `get_listings`, `get_manga_list`,
`get_home`, `get_filters`, `get_settings`, and `get_image_request`, plus
metadata fixtures for `SourceInfo` and `SourceCapabilities`. Invalid fixtures
cover unknown/future operations, `hostHints.network`, response envelope shape,
path/URI leaks, remote URL leaks while `network=false`, credential-like leaks,
raw authorization headers, non-opaque ids, and malformed pagination/model
shapes.

Current validators that must continue to pass for this design-only lane:

- `run-source-archive-smoke.py`: archive validation, extraction, and Linux WAMR
  execution evidence.
- `validate-archive-negative-fixtures.py`: malformed archive rejection.
- `package-source-archive.py`: local archive packaging/validation boundary.
- `validate-source-package.py --build-rust-fixture`: manifest, wasm, import,
  export, `koma_source_info`, capability, settings, unknown-operation
  rejection, and `network=false` checks.
- `validate-http-boundary.py`: HTTP remains design-only and current package
  validation rejects HTTP/network drift.

Missing future tests before product enablement:

- JSON schema fixtures for every operation.
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
