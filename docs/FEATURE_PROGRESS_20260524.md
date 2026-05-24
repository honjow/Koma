# Koma Feature Progress — 2026-05-24

This document records the feature-development baseline reached in the long 2026-05-24 controller session. It is not an instruction file; `AGENTS.md` remains only an index.

## Latest Consolidated Gate

Artifacts:

- `.hermes-artifacts/20260525-0215-cache-management/`
- `.hermes-artifacts/20260525-0230-safe-area-main-shell/`
- `.hermes-artifacts/20260525-0245-source-settings/`

Verified after reader image-cache management, content-list safe-area avoidance, and source-specific settings:

- `node scripts/test_koma_models.mjs` PASS.
- `node scripts/test_source_package_compat.mjs` PASS.
- `node scripts/test_reader_progress.mjs` PASS.
- `bash scripts/validate-napi-source-runtime-sample.sh` PASS.
- `bash dev.sh --build-only --non-interactive` PASS.
- Debug HAP installed to `192.168.50.103:12345` as `com.honjow.koma.dev` PASS.
- Device smoke artifacts:
  - `.hermes-artifacts/20260525-0115-bf-device-smoke/` confirms Browse no longer exposes `Koma Fixture`.
  - `.hermes-artifacts/20260525-0140-bk-device-smoke/` confirms Settings backup copy includes source packages and settings.
  - `.hermes-artifacts/20260525-0245-source-settings/device/` confirms app launch, Settings, and Source Package Manager empty-state surfaces on device.

## 2026-05-24 Final Gate

Artifact: `.hermes-artifacts/20260524-2200-final-gate/`

Verified on device `192.168.50.103:12345`:

- `bash dev.sh --build-only --non-interactive` PASS.
- `node scripts/test_koma_models.mjs` PASS.
- Signed debug HAP installs as `com.honjow.koma.dev` PASS.
- HAP contains `libs/arm64-v8a/libkoma_source_runtime.so`.
- 5-tab smoke screenshots captured for Library / Browse / History / Search / Settings.
- Startup hilog includes:
  - `[SourceRuntime] step=native_loaded`
  - `[BootstrapSync] step=start`
  - `[KomgaSync] step=pull_ok page=12`
  - `[BootstrapSync] step=done updated=0 synced=1 failed=0`
  - `[Library] step=filter_restored sortBy=lastRead source=all readState=all`
  - `[Settings] step=load_preferences`

## Commits Integrated During This Session

| Area | Commit | Result |
| --- | --- | --- |
| Tab icon spacing | `6e564e9` | Minor spacing fix landed before feature push. |
| Reader real pages + persistence | `148a8cb` | Reader no longer renders mock pages; uses real page sources and persists mode/page. |
| CBZ/ZIP archive import | `1715704` | Picker/archive extraction -> Comic -> Library -> Reader path wired. |
| Local image multi-select import | `d26cbcb` | Multi-image picker -> LOCAL_FOLDER Comic -> Library -> Reader path wired. |
| Komga private library | `9c9f77c` | Settings config, Browse libraries/series/books, Reader remote images. |
| WebDAV private library | `331d7aa` | Settings config, directory browse, Reader remote URLs via fixture; public demo had device internal error. |
| OPDS private library | `26a18a0` | Settings config, OPDS v2 catalog/acquisition, Reader remote image path. |
| Cross-source search | `6af28d4` | SearchPage aggregates local / Komga / OPDS / WebDAV / wasm sources with per-source timeouts. |
| History tab | `e1a0748` | Real reading history from persisted progress, click-to-resume Reader. |
| Reader remote image cache | `dccffa8` | Disk cache + LRU + prefetch. Controller QA saw hit/miss/prefetch traces. |
| Remote favorites | `5f36ab8` | Komga/OPDS/WebDAV favorites can be added to Library; Komga full path verified. |
| Komga reader progress sync | `5758e99` | Pull on open + debounced push while reading; fail-open local-first behavior. |
| Library multi-select remove | `eb1242c` | Code/build/install pass; automated longClick QA unreliable on 103. |
| Bootstrap Komga progress sync | `b6bb1e4` | App startup/foreground pulls Komga favorite progress with 60s cooldown. |
| Library sort/filter | `c50554b` | Sort/filter by recency/added/title/source and source/read-state filters; preferences persist. |
| Settings functional rows | `36d45af` | Page mode/direction/theme/backup/about/license/version/source management rows wired. |
| Reader dual-page mode | `d71e50d` | Dual-page pair Swiper, cover handling, RTL page order. Controller QA verified two-page layout. |
| Model tests realigned | `b96dbb1` | `node scripts/test_koma_models.mjs` PASS restored. |
| Stop demo seed by default | `1726cca` | Production no longer injects mock library rows unless explicitly seeded. |
| WAMR native runtime | `d8f031f` | WAMR vendored into HAP; native smoke/search no longer `wamr_not_built`. |
| Source package manager | `a5c9e5b` | Settings manager page: list/import/enable/disable/remove/smoke local source packages. |
| Source repo `.koma` compatibility | `7ecba36` | App imports `.koma` / `.koma-source` / `.koma-source.zip` / `.zip` by archive content, not extension trust. |
| Source runtime image requests | `c4a3317` | Reader resolves `pageId -> get_image_request -> URL+headers` before remote image cache; cache key includes effective headers. |
| Source detail contract | `5946e1a` | MangaDetail source operations now use v1 request envelope and parse source-repo `data.manga` / `data.items` shapes. |
| Remove Browse mock fallback | `a09b688` | Empty source registry no longer injects `Mock Source`; Browse shows import guidance. |
| Remove bundled fixture from Browse | `3dfe08d` | Production Browse bootstrap no longer registers `Koma Fixture`; rawfile fixtures remain test-only. |
| Backup schema v2 | `1705893` | Backup/export covers library, progress, remote servers, source packages, and reader/settings preferences; v1 imports remain accepted. |
| Reader image cache management | `a48ce93` | Settings shows remote image cache stats and exposes clear action scoped to `reader-remote-image-cache`. |
| Content safe-area avoidance | `ec697de` | Keeps fullscreen transparent/floating shell while adding internal content-list insets for ordinary pages. |
| Source package settings | `23dac83` | Installed local source packages can expose non-secret settings via `get_settings`; settings persist by sourceId, inject into runtime calls, and backup schema v3 exports sanitized settings. |

## Current Product Baseline

### Library

- Local CBZ/ZIP archive import.
- Local multi-image import.
- Remote favorites from Komga / OPDS / WebDAV can appear in Library.
- Continue Reading card uses persisted reading progress.
- History and Library refresh after bootstrap progress sync.
- Sort/filter controls persist across restart.
- Multi-select remove exists; automated long-press QA is weak due uitest behavior, but build/install pass.

### Reader

- Single-page, continuous/webtoon, and dual-page modes.
- RTL visual page ordering in dual mode.
- Real page source adapter supports local extracted image files, remote URLs with auth headers, and cached remote images.
- Progress persistence and resume.
- Komga progress pull/push.
- Remote image cache under app cache with LRU and prefetch.

### Private Libraries

- Komga: Settings auth, Browse libraries/series/books, Reader, favorites, progress sync.
- OPDS: Settings auth, catalog/navigation/acquisition, Reader image fallback, favorites.
- WebDAV: Settings auth, PROPFIND directory browse, Reader, favorites; public `test.webdav.org` had device internal error, local fixture path used for QA.

### Search

- Cross-source search over local LibraryStore, Komga, OPDS, WebDAV, and enabled user-installed wasm sources.
- Per-source timeout/error isolation.
- Test wasm fixture remains available only to source-runtime smoke/tests; it is not registered in production Browse.

### Settings

- Komga / OPDS / WebDAV config pages.
- Reader page mode / reading direction / theme preferences.
- Backup export/import via picker. Schema v3 includes library, reading progress, remote server settings, installed source packages, sanitized per-source settings, and reader/settings preferences. Schema v1/v2 import remains accepted.
- About / license / version dialogs.
- Source package manager page.
- Reader remote image cache stats and clear action.

### WASM Source Runtime

- `third_party/wasm-micro-runtime/` vendored and built into `libkoma_source_runtime.so`.
- Device source runtime smoke passes.
- Local source package manager supports local archive import, enable/disable/remove, and smoke. Next source-import product path should be URL source-index import/load, not a bundled market and not local picker only; source index/package definitions are owned by `/home/gamer/git/koma-sources/dist/index.json`.
- Source package manager page: URL index as primary source import path, local picker as secondary fallback.
- App accepts source-repo `.koma` packages (`manifest.json` + `source.wasm`) and legacy/internal source archive layouts.
- Reader integrates source `get_image_request` for source-owned image URL/header resolution.
- Installed source packages can expose non-secret `get_settings` descriptors; Koma stores sanitized values per source id and injects them into Browse/detail/pages/image-request runtime envelopes.
- Production Browse lists only user-installed/enabled packages; no bundled public source or test fixture is registered.
- Source URL index import: user-configured index URL -> fetch `index.json` -> list packages -> download selected `pkg` -> install/enable via existing archive validator/registry. No built-in default source URL is included.

## Known Gaps / Follow-up

1. Source URL index import/load implemented but not yet device-smoked with a live remote index server; service layer and UI are wired.
2. Source package picker import UI path is implemented but not fully hand-driven with a real selected `.koma` on device; static/source-runtime gates cover archive validation, restore, and run.
3. Source package settings page was device-smoked only in empty-state because no installed source package was present on the device during the final smoke; per-source `设置` button/descriptor editing still needs a real installed `.koma` runtime UI pass.
4. Library multi-select long-press automation is unreliable with `uitest`; needs manual UX pass or alternative gesture handling if user reports real-device failure.
5. WebDAV public demo endpoint had Harmony device `Internal error`; local fixture covered PROPFIND/GET. Needs broader NAS/WebDAV compatibility matrix.
6. OPDS publication path uses image URL fallback for the tested Komga OPDS v2 demo; EPUB/publication manifest returned HTTP 406.
7. Error-state UI is not unified across source types; intentionally deferred because the user asked to prioritize functionality over UI detail.
8. Large CBZ / large remote chapter performance still needs stress testing.
9. Backup JSON is local user-initiated and unencrypted; encryption/password UX was explicitly not added. Source settings backup is sanitized and excludes credential-like values.
