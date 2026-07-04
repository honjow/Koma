# Koma Feature Progress — 2026-05-24

This document records the feature-development baseline reached in the long 2026-05-24 controller session. It is not an instruction file; `AGENTS.md` remains only an index.

## Latest Consolidated Gate

Artifacts:

- `.hermes-artifacts/20260525-0215-cache-management/`
- `.hermes-artifacts/20260525-0230-safe-area-main-shell/`
- `.hermes-artifacts/20260525-0245-source-settings/`
- `.hermes-artifacts/20260526-d6-backup-management-ui/`
- `.hermes-artifacts/20260526-d8-tracker-skeleton/`

Verified after reader image-cache management, content-list safe-area avoidance, source-specific settings, backup management UI, and tracker settings skeleton:

- `node scripts/test_tracker_settings.mjs` PASS.
- `node scripts/test_koma_models.mjs` PASS.
- `node scripts/test_source_package_compat.mjs` PASS.
- `node scripts/test_backup_management.mjs` PASS.
- `node scripts/test_reader_settings.mjs` PASS.
- `node scripts/test_offline_download_queue.mjs` PASS.
- `node scripts/test_reader_progress.mjs` PASS.
- `bash scripts/validate-napi-source-runtime-sample.sh` PASS.
- `bash dev.sh --build-only --non-interactive` PASS.
- Debug HAP installed to `192.168.50.103:12345` as `com.honjow.koma` PASS.
- Device smoke artifacts:
  - `.hermes-artifacts/20260525-0115-bf-device-smoke/` confirms Browse no longer exposes `Koma Fixture`.
  - `.hermes-artifacts/20260525-0140-bk-device-smoke/` confirms Settings backup copy includes source packages and settings.
  - `.hermes-artifacts/20260525-0245-source-settings/device/` confirms app launch, Settings, and Source Package Manager empty-state surfaces on device.

## 2026-05-24 Final Gate

Artifact: `.hermes-artifacts/20260524-2200-final-gate/`

Verified on device `192.168.50.103:12345`:

- `bash dev.sh --build-only --non-interactive` PASS.
- `node scripts/test_koma_models.mjs` PASS.
- Signed debug HAP installs as `com.honjow.koma` PASS.
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
| Library update check MVP | `d9` | Settings foreground action checks Library for source-runtime chapter changes, updates chapter metadata, and reports new-chapter/updated/skipped/failed counts without a background scheduler. |
| Library auto-update preferences | `d9` | Settings persists an app-open due-check preference with 12h/24h/48h intervals, deterministic last-check/next-due text, and foreground-only copy. |
| Library update result persistence | `d9` | Latest sanitized per-comic update results persist across app restarts for the details page without rerunning checks. |
| Library update reminder skeleton | `d9` | Settings exposes a planned update reminder row, but Koma does not request notification permission and does not send real notifications in this lane. |
| Downloads queue MVP | `7a4c0d1` | Settings Downloads page, durable queue records, per-chapter MangaDetail download action, retry/remove for feasible rows, and Reader offline manifest path preservation. |
| Library category management | `87a03fb` | Built-in Favorite / Read Later category filters and multi-select add/remove category actions preserve other memberships. |
| Reader advanced settings | `031157a` | Settings adds image fit, tap navigation, and page gap controls; Reader consumes persisted settings with non-cropping fit-width and narrow edge tap zones. |
| Downloads queue controls | `a61c63b` | MangaDetail visible-chapter batch download actions plus Downloads page status filters, batch retry for feasible failed/partial rows, and cleanup controls. |
| Source package update UX / SDK docs | `54debb0` | Source Package Manager surfaces update/capability UX hooks, persisted capability summaries are bounded by manifest-derived allowlists, and `docs/source-package-sdk.md` documents the author contract. |
| Reader trim/volume navigation | `08c203e` / current | Settings adds non-destructive trim-page-margins and volume-key-navigation preferences; trim removes container inset without rounded clipping, and Reader handles volume up/down key events on the focused reader surface. |
| Source index visible download reader smoke | `fa6e6ec` | Pura X smoke installs a source from URL index, adds a real source manga to Library, downloads a chapter, and opens the downloaded chapter in Reader with visible page evidence. |
| Offline resume hash preservation | `2438de3` | Partial download retry preserves reused page `contentHash` values so same-size page corruption remains detectable after resume. |
| D6 backup management UI | `8bc42bf` | Settings opens a dedicated Backup Management page showing schema/status, included domains, export/import actions, picker-file ownership limits, and the current encrypted backup flow; cloud sync and scheduling remain out of scope. |
| D8 tracker settings skeleton | `pending` | Settings opens a dedicated tracker page with AniList/MyAnimeList/Kitsu/MangaUpdates/Bangumi unavailable placeholders plus local-only provider/status and per-comic mapping models. Public tracker account sync, login, credential storage, and remote write APIs remain explicitly out of scope. |

## Current Product Baseline

### Library

- Local CBZ/ZIP archive import.
- Local multi-image import.
- Remote favorites from Komga / OPDS / WebDAV can appear in Library.
- Continue Reading card uses persisted reading progress.
- History and Library refresh after bootstrap progress sync.
- Sort/filter controls persist across restart.
- Built-in category filters for Favorite / Read Later and batch category add/remove actions.
- Multi-select remove exists; automated long-press QA is weak due uitest behavior, but build/install pass.

### Reader

- Single-page, continuous/webtoon, and dual-page modes.
- RTL visual page ordering in dual mode.
- Real page source adapter supports local extracted image files, remote URLs with auth headers, and cached remote images.
- Progress persistence and resume.
- Komga progress pull/push.
- Remote image cache under app cache with LRU and prefetch.
- Offline chapter download records durable queue rows under app files, exposes a Settings Downloads page, lets MangaDetail and Downloads retry hydrate source chapter pages, supports queue status filters plus batch retry/cleanup, preserves page hashes across partial resume, and publishes completion/failure notifications when permission allows. This remains an in-app foreground downloader, not an OS background scheduler.
- Advanced reader settings persist image fit mode, tap navigation, and page gap mode. `fit_width` widens the container without `Cover` cropping; tap navigation uses narrow edge zones and can be disabled.
- Reader trim-page-margins and volume-key-navigation preferences persist and round-trip through backups. Trim is a presentation-only inset reduction with no rounded clipping when enabled; volume-key navigation is handled by Reader key events when the reader surface has focus.

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
- Reader image fit / tap navigation / page gap preferences.
- Backup export/import via a dedicated Settings secondary page backed by system file pickers. Schema v3 includes library, reading progress, remote server settings, installed source packages, sanitized per-source settings, and reader/settings preferences. Schema v1/v2 import remains accepted; picker-selected files remain external and user-managed rather than an in-app backup history.
- About / license / version dialogs.
- Source package manager page.
- Reader remote image cache stats and clear action.
- Downloads page lists offline chapters / failed tasks from the durable queue, with retry for failed/partial rows, direct read for readable offline rows, and source page hydration before retry for recoverable `pages_missing` rows.
- Foreground library update check with last summary/status row, new-chapter count, updated/skipped/failed counts, and next-due text when app-open auto-check is enabled.
- Library update details page shows the latest in-memory or persisted check summary and sanitized per-comic results from Settings.
- Library update auto-check preferences are persisted and run only when Settings opens and a due interval has elapsed while the app is foregrounded.
- Library update reminder preference is a planned skeleton only; no notification permission is requested and no delivery path is exposed.
- Tracker settings page lists AniList, MyAnimeList, Kitsu, MangaUpdates, and Bangumi as unavailable/not-connected placeholders. The tracker data skeleton stores only local provider id/display name/status and an inert per-comic mapping shape; there is no login UI, credential storage, public account sync, or remote write API in this lane.

### WASM Source Runtime

- `third_party/wasm-micro-runtime/` vendored and built into `libkoma_source_runtime.so`.
- Device source runtime smoke passes.
- Local source package manager supports local archive import, enable/disable/remove, and smoke. Next source-import product path should be URL source-index import/load, not a bundled market and not local picker only; source index/package definitions are owned by `/home/gamer/git/koma-sources/dist/index.json`.
- Source package manager page: URL index as primary source import path, local picker as secondary fallback.
- App accepts source-repo `.koma` packages (`manifest.json` + `source.wasm`) and legacy/internal source archive layouts.
- Reader integrates source `get_image_request` for source-owned image URL/header resolution.
- Installed source packages can expose non-secret `get_settings` descriptors; Koma stores sanitized values per source id and injects them into Browse/detail/pages/image-request runtime envelopes.
- Installed source cards can validate saved non-secret settings through a `get_settings` runtime request and show per-source PASS/FAIL state without exposing setting values.
- Production Browse lists only user-installed/enabled packages; no bundled public source or test fixture is registered.
- Source URL index import: user-configured index URL -> fetch `index.json` -> list packages -> download selected `pkg` -> install/enable via existing archive validator/registry. No built-in default source URL is included. Live device smoke verified with a locally served source index and `com.dm5.koma` install on `192.168.50.103:12345`.
- Source browsing runtime smoke now covers a real URL source index on Pura X: locally served `/Users/honjow/git/koma-sources/dist/index.json`, `org.mangadex.koma`, `source-index-browse`, 21 index entries, 20 listings, 3 home sections / 30 manga, 4 filters, 20 default listing rows, and 20 filtered listing rows. Artifact: `.hvigor/outputs/source-index-browse-smoke/source-runtime-smoke-result.json`.
- Installed source package update check/upgrade MVP uses the user-configured source index to show per-package latest/update/missing/failure status and update installed packages safely.
- Installed source cards include an inline runtime diagnostics panel with safe smoke/update/capability/settings summary and refresh logging.
- Source Package Manager exposes source-index/update controls, user-facing capability summaries, and source author SDK docs. Persisted capability summaries are display hints only and are bounded by manifest-derived capabilities plus an allowlist on reload.
- Library update MVP supports installed source-runtime comics via `get_chapters`; local imports and Komga/OPDS/WebDAV metadata refresh are skipped until safe refresh APIs are wired.

## Known Gaps / Follow-up

1. Source package picker import UI path is implemented but not fully hand-driven with a real selected `.koma` on device; static/source-runtime gates cover archive validation, restore, and run.
2. Source package settings page was device-smoked only in empty-state because no installed source package was present on the device during the final smoke; per-source `设置` button/descriptor editing still needs a real installed `.koma` runtime UI pass.
3. Library multi-select long-press automation is unreliable with `uitest`; needs manual UX pass or alternative gesture handling if user reports real-device failure.
4. WebDAV public demo endpoint had Harmony device `Internal error`; local fixture covered PROPFIND/GET. Needs broader NAS/WebDAV compatibility matrix.
5. OPDS publication path uses image URL fallback for the tested Komga OPDS v2 demo; EPUB/publication manifest returned HTTP 406.
6. Error-state UI is not unified across source types; intentionally deferred because the user asked to prioritize functionality over UI detail.
7. Large CBZ / large remote chapter performance still needs stress testing.
8. Backup JSON remains local user-initiated. Legacy JSON export is still unencrypted and labeled as such; encrypted export/import uses a passphrase-gated envelope path. Source settings backup is sanitized and excludes credential-like values.
9. Downloads are foreground/in-app only: no OS background scheduler yet. Notification permission, pause/concurrency, queue retry/cleanup, and source-backed `pages_missing` retry hydration are implemented, but still need a broader permission/denied-state and interrupted-network device matrix.
10. Library category runtime device QA covered empty-state/safe-area only because the device had no library rows; static tests cover category membership/filter contracts.
11. Reader advanced settings still need real chapter visual QA for unusual image aspect ratios; static/build gates and Settings persistence device smoke pass.
12. Source package update/capability UX was device-smoked only in empty-state because no installed source package was present; static tests cover tampered persisted capability metadata and update-state contracts.
13. Volume-key reader navigation has runtime key-event handling; remaining risk is device matrix coverage for focus retention after overlays, route transitions, and system volume interception.
14. Tracker settings is a local-only skeleton; real OAuth/account linking and public tracker sync remain future work.
15. Library update scheduling remains foreground-only. Real background scheduling and notification delivery still require a verified Harmony API path, permissions, implementation tests, and device QA.
16. Source browsing has Pura X runtime evidence for MangaDex home/listings/filters/default listing/filtered listing; remaining product QA is hand-driven UI navigation from Browse to MangaDetail, Reader, download, and per-source settings editing with real installed sources.
