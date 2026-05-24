# Koma Feature Progress — 2026-05-24

This document records the feature-development baseline reached in the long 2026-05-24 controller session. It is not an instruction file; `AGENTS.md` remains only an index.

## Final Gate

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

- Cross-source search over local LibraryStore, Komga, OPDS, WebDAV, and enabled wasm sources.
- Per-source timeout/error isolation.
- Bundled wasm fixture source now returns results through native WAMR runtime.

### Settings

- Komga / OPDS / WebDAV config pages.
- Reader page mode / reading direction / theme preferences.
- Backup export/import via picker.
- About / license / version dialogs.
- Source package manager page.

### WASM Source Runtime

- `third_party/wasm-micro-runtime/` vendored and built into `libkoma_source_runtime.so`.
- Device source runtime smoke passes.
- Local source package manager supports local archive import, enable/disable/remove, and smoke.
- No remote source market/download path was added.

## Known Gaps / Follow-up

1. Source package picker import UI path is implemented but not fully hand-driven with a real selected `.koma-source.zip` on device; source runtime smoke covers archive validation/run.
2. Library multi-select long-press automation is unreliable with `uitest`; needs manual UX pass or alternative gesture handling if user reports real-device failure.
3. WebDAV public demo endpoint had Harmony device `Internal error`; local fixture covered PROPFIND/GET. Needs broader NAS/WebDAV compatibility matrix.
4. OPDS publication path uses image URL fallback for the tested Komga OPDS v2 demo; EPUB/publication manifest returned HTTP 406.
5. Error-state UI is not unified across source types; intentionally deferred because the user asked to prioritize functionality over UI detail.
6. Large CBZ / large remote chapter performance still needs stress testing.
