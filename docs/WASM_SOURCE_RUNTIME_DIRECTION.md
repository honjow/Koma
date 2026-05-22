# Koma WASM Source Runtime Direction

Date: 2026-05-22

## Why this document exists

The WASM/source-runtime track drifted into repeated package safety and fail-closed smokes. Those checks are necessary gates, but they are not the product of this track.

This document is the active direction guardrail for future controller/worker prompts: after a safety gate passes, the next default lane should advance source-author capability, API shape, SDK ergonomics, feature discovery, or host-import functionality — not another security edge case unless it directly blocks the capability lane.

## Current task boundary

Stay inside Koma **WASM / source runtime** work:

- Rust/no_std source author SDK.
- Source package / local source archive.
- ArkTS -> NAPI -> C++ -> WAMR execution chain.
- Source runtime import / registry / persistence / reload / run-by-id.
- Source API, DTOs, capabilities, feature discovery.
- Host imports for controlled HTTP/HTML/settings/image/auth references.
- Static validators and device smokes that prove the above.

Do not switch to these tracks unless explicitly asked:

- Local image/CBZ import UX.
- Bookshelf UI.
- Reader UI.
- Komga/OPDS/WebDAV private-library UI/client work.
- Product source marketplace, public source index, remote install, built-in sources, or release-visible source management.

## Correct product of this track

The goal is not merely: **a source package can run safely**.

The goal is: **a source author can write a useful Koma source against a stable, host-controlled API**.

That means the runtime must eventually support:

- discoverable source metadata and capabilities;
- search and browse operations;
- manga detail, chapter list, and page list operations;
- listings/home/filter/settings models;
- image request descriptors;
- structured errors;
- host-controlled HTTP and HTML parsing;
- settings/auth references without exposing raw credentials;
- repeatable Linux/archive/device smokes.

## Reference model: Aidoku/AidokuRunner patterns worth adapting

Use Aidoku as architecture reference, not as code to copy.

Useful observed patterns:

- A source is a package-like unit, not only a `.wasm` file:
  - `source.json`
  - `main.wasm`
  - optional `filters.json`
  - optional `settings.json`
  - optional icon/static metadata
- App loads source metadata, loads WASM, links host imports, then derives source features from the runner/export surface.
- Runner-level capability is broader than `search/detail/pages`:
  - core: search manga list, manga detail/update, page list;
  - browse: listings, home, filters;
  - settings/config: static/dynamic settings, base URL/language config;
  - image pipeline: image request modification, page image processing, page descriptions, alternate covers;
  - advanced/future: login, deep links, notifications, key migration.
- A `SourceFeatures`/capability model avoids host-side guessing.
- DTO coverage should include `SourceInfo`, `Manga`, `Chapter`, `Page`, `MangaPageResult`, `Listing`, `Filter`, `Setting`, `Home`, `Response`, and `SourceError` equivalents.
- Host imports should be capability-layered: minimal runtime imports first, then HTTP, HTML parsing, settings/defaults, image request resolution, auth/session references.

## Direction after the current safety baseline

Current safety/package baseline includes source archive validation, import/register/reload/run-by-id, persisted inventory, and missing payload fail-closed device evidence.

Do **not** default the next lane to another tamper/fail-closed case. Use security/hardening lanes only when they unblock API/runtime capability or protect a newly introduced host import.

Preferred next sequence:

### S1 — Source API v0.2 spec and fixtures

Purpose: expand the source-author contract from the current four-operation smoke into a usable API.

Scope:

- Update `tools/wasm-runtime-spike/source-package/SOURCE_API_V0.md` or add a v0.2 companion spec.
- Define/clarify:
  - `SourceInfo`
  - `SourceCapabilities`
  - `Manga`
  - `Chapter`
  - `Page`
  - `MangaPageResult`
  - `Listing`
  - `Filter`
  - `Setting`
  - `HomeSection`
  - `ImageRequest`
  - structured `SourceError`
- Add valid/invalid JSON fixtures and a local validator.

Non-goals:

- No product UI.
- No source marketplace.
- No real public source.
- No runtime HTTP enablement yet.

### S2 — Rust SDK trait ergonomics

Purpose: source authors implement a high-level trait; SDK owns raw ABI details.

Candidate shape:

```rust
pub trait Source {
    fn info(&self) -> SourceInfo;
    fn capabilities(&self) -> SourceCapabilities;

    fn search(&self, req: SearchRequest) -> SourceResult<MangaPageResult>;
    fn get_manga(&self, req: MangaRequest) -> SourceResult<Manga>;
    fn get_chapters(&self, req: ChaptersRequest) -> SourceResult<Vec<Chapter>>;
    fn get_pages(&self, req: PagesRequest) -> SourceResult<Vec<Page>>;

    fn get_listings(&self) -> SourceResult<Vec<Listing>> {
        Err(SourceError::unimplemented())
    }

    fn get_home(&self, _req: HomeRequest) -> SourceResult<Home> {
        Err(SourceError::unimplemented())
    }

    fn get_filters(&self) -> SourceResult<Vec<Filter>> {
        Err(SourceError::unimplemented())
    }

    fn get_settings(&self) -> SourceResult<Vec<Setting>> {
        Err(SourceError::unimplemented())
    }

    fn get_image_request(&self, _req: ImageRequestInput) -> SourceResult<ImageRequest> {
        Err(SourceError::unimplemented())
    }
}
```

SDK owns:

- request byte reads;
- result buffer/header writing;
- JSON envelope writing;
- operation self-consistency checks;
- cancellation checks;
- error mapping;
- `hostHints`;
- export glue.

### S3 — Capabilities / feature discovery

Purpose: host knows what the source supports.

Preferred first implementation:

- Check explicit exported functions:
  - `koma_source_search`
  - `koma_source_get_manga`
  - `koma_source_get_chapters`
  - `koma_source_get_pages`
  - `koma_source_get_listings`
  - `koma_source_get_manga_list`
  - `koma_source_get_home`
  - `koma_source_get_filters`
  - `koma_source_get_settings`
  - `koma_source_get_image_request`

Later optional self-description:

```json
{
  "version": 1,
  "features": {
    "search": true,
    "mangaDetail": true,
    "chapters": true,
    "pages": true,
    "listings": true,
    "home": false,
    "filters": true,
    "settings": false,
    "imageRequest": false
  }
}
```

Rules:

- Unknown operation fails closed.
- Missing export reports unsupported/unimplemented.
- Never silently default an unknown operation to `search`.

### S4 — Listings / Home / Filters runtime smoke

Purpose: runtime becomes browse-capable, not only search-capable.

Add operations:

- `get_listings`
- `get_manga_list`
- `get_home`
- `get_filters`

Minimum models:

- Listing: `id`, `name`, `kind`.
- Manga page result: `items`, `nextCursor`, `hasMore`.
- Filter: text, sort, check, select, multi-select, note, range.
- Home: title/subtitle plus manga list/link sections.

Validation:

- Rust fixture returns deterministic browse data.
- Linux WAMR smoke validates all operations.
- Archive-to-runtime smoke uses extracted archive WASM.
- Device smoke validates all operation names and expected fixture identifiers.

### S5 — HTTP host import v0.1 functional fixture

Purpose: source can request host-owned HTTP under strict policy.

Rules:

- Start with controlled local/static fixtures, not real public manga sites.
- Host owns URL policy, allowed domains, timeouts, response size, redirects, credentials, cookies, and logs.
- Source never receives raw cookie/token/password values.

Candidate request:

```json
{
  "method": "GET",
  "url": "https://example.test/search?q=koma",
  "headers": { "Accept": "text/html" },
  "body": null,
  "timeoutMs": 8000,
  "responseKind": "text"
}
```

Candidate response:

```json
{
  "status": 200,
  "headers": {},
  "bodyText": "...",
  "finalUrl": "..."
}
```

### S6 — HTML parse/select host imports

Purpose: source authors can parse pages without shipping heavy parsers in every WASM package.

Minimum imports:

- `html_parse`
- `html_select`
- `html_attr`
- `html_text`
- `html_html`

Validation:

- fixture HTML -> manga list;
- fixture HTML -> chapters;
- fixture HTML -> pages;
- no raw response/log leaks.

### S7 — Image request / settings / auth references

Purpose: prepare the image loading and account/config path without exposing secrets.

Image request descriptor:

```json
{
  "url": "https://example.test/page/1.jpg",
  "headersRef": "defaultImage",
  "cacheKey": "chapter-1-page-1",
  "requiresAuth": false
}
```

Settings first set:

- switch
- select
- multi-select
- text
- group
- login placeholder/reference

Auth rules:

- source returns credential/session references, not raw secrets;
- host resolves references;
- logs must redact refs and headers.

## Controller guardrails

Every future worker prompt on this track must include:

1. `Active boundary: Koma WASM/source-runtime capability track`.
2. `Primary goal: advance API/SDK/capability/host-import functionality`.
3. `Security validators are gates, not the default next roadmap item`.
4. `Do not switch to local reader/import UI or private-library tracks`.
5. `Do not implement product source market, public index, remote install, built-in sources, or release-visible source management`.
6. `If blocked, write a result JSON and stop; do not choose an unrelated lane`.

## Current next default

Unless the user explicitly changes direction, the next lane should be:

**S1 — Source API v0.2 spec and fixtures**

Not:

- persisted payload tamper smoke;
- another archive negative fixture;
- local image import;
- bookshelf/reader UI.

Security/fail-closed work remains a regression gate and may be scheduled only when it protects a newly added capability such as HTTP, HTML import, settings/auth, or image request descriptors.
