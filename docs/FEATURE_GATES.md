# Koma Feature Gates

This is the living feature ledger used by `scripts/check_feature_gate_status.mjs`.
It is not a one-time roadmap. Update it when a gate changes state, and keep
device/simulator evidence in `.hermes-artifacts/`.

## Status Rules

- `TODO`: not implemented or not enough code exists to review.
- `IN_PROGRESS`: current work is actively moving this gate.
- `CODE_READY_UNVERIFIED`: code exists, but the current connected device/simulator path has not accepted it.
- `ACCEPTED`: the gate is done for the current scope and protected from casual rewrites.
- `REOPENED`: an accepted gate was deliberately reopened because of a real regression, missing requirement, or design change.
- `DEFERRED`: real feature, intentionally lower priority than the current main loop.

`ACCEPTED` is the only freeze state. Changing protected files for an accepted gate
requires an active gate artifact with `"intent": "reopen"` and a concrete
`"reopenReason"`, plus this file must be staged with the new state/evidence.

## Active Gate Artifact

Before committing user-visible app work, write:

```json
{
  "gateId": "KG-001",
  "intent": "advance",
  "summary": "What this commit moves forward",
  "evidence": [
    ".hermes-artifacts/example/screenshot.png",
    ".hermes-artifacts/example/layout.json"
  ]
}
```

Save it as `.hermes-artifacts/active-feature-gate.json`, or set
`KOMA_ACTIVE_GATE=KG-001` for a narrow local-only commit. Evidence is mandatory
when moving a gate to `ACCEPTED`.

## Gate Ledger

| ID | Status | Scope | Protected paths | Evidence | Next required user-visible proof |
| --- | --- | --- | --- | --- | --- |
| KG-001 | IN_PROGRESS | Real source manga to shelf, chapter download, offline Reader with local pages. | `entry/src/main/ets/sourceRuntime/`<br>`entry/src/main/ets/model/OfflineDownload*`<br>`entry/src/main/ets/pages/ReaderPage.ets`<br>`entry/src/main/ets/model/ReaderPageSourceAdapter.ets` | `.hermes-artifacts/` pending current accepted run | Current build on connected emulator: source search/detail -> add to shelf -> download one chapter -> reopen from shelf offline/local-file Reader screenshot/layout/result. |
| KG-002 | CODE_READY_UNVERIFIED | Reader daily usability: page fit, gestures, tap zones, progress, controls. | `entry/src/main/ets/pages/ReaderPage.ets`<br>`entry/src/main/ets/components/ReaderChrome.ets`<br>`entry/src/main/ets/model/ReaderPreferencesStore.ets` | `.hermes-artifacts/` pending current accepted run | Current build Reader QA matrix on connected emulator, including single page, continuous, zoom/double-tap where implemented, tap navigation, chrome open/close. |
| KG-003 | CODE_READY_UNVERIFIED | Source project development to Koma app usage loop. | `entry/src/main/ets/sourceRuntime/`<br>`scripts/run_source_*`<br>`docs/source-*.md` | `.hermes-artifacts/` pending current accepted run | Build a local `.koma` package, install through Koma, search/open/download/read from UI with current device evidence. |
| KG-004 | REOPENED | Root/library/browse/search/detail visual baseline and navigation shell. | `entry/src/main/ets/pages/Index.ets`<br>`entry/src/main/ets/pages/LibraryPage.ets`<br>`entry/src/main/ets/pages/BrowsePage.ets`<br>`entry/src/main/ets/pages/SearchPage.ets`<br>`entry/src/main/ets/pages/MangaDetailPage.ets`<br>`entry/src/main/ets/components/SecondaryListScaffold.ets`<br>`entry/src/main/ets/components/Hds*` | User screenshots showed top overlap / duplicate title / scaffold regressions; current accepted artifact missing. | Current build screenshots/layout for every root tab and source/detail subflow; no status-bar overlap, duplicate root title, or content hidden by chrome. |
| KG-005 | TODO | Source browse/search/detail UX quality for multiple installed sources. | `entry/src/main/ets/pages/SourceBrowsePage.ets`<br>`entry/src/main/ets/pages/SourceSearchPage.ets`<br>`entry/src/main/ets/components/SourceMangaGrid.ets`<br>`entry/src/main/ets/components/SourceFilterControls.ets` | none | At least MangaDex and DM5 paths inspected on device with real cover/result/detail/chapter screenshots. |
| KG-006 | CODE_READY_UNVERIFIED | Local/import/private library flows after current UI regressions. | `entry/src/main/ets/import/`<br>`entry/src/main/ets/pages/ImportPage.ets`<br>`entry/src/main/ets/pages/Komga*`<br>`entry/src/main/ets/pages/Opds*`<br>`entry/src/main/ets/pages/WebDav*` | older artifacts only; no current accepted run | Current build local import/private-library smoke and screenshots from user path. |
| KG-007 | DEFERRED | Settings, tracker, backup, categories, i18n, and other support surfaces. | `entry/src/main/ets/pages/SettingsPage.ets`<br>`entry/src/main/ets/pages/TrackerSettingsPage.ets`<br>`entry/src/main/ets/pages/BackupManagementPage.ets`<br>`entry/src/main/ets/model/Backup*`<br>`entry/src/main/ets/model/Tracker*` | mixed older artifacts | Do not consume main development time unless blocking KG-001/KG-002/KG-003 or explicitly requested. |
| KG-008 | ACCEPTED | Public build profile tracking policy: only public `build-profile.json5` is tracked; local profiles are not pushed. | `build-profile.json5`<br>`build-profile.github.json5`<br>`build-profile.local.json5`<br>`build-profile.json5.github`<br>`.githooks/pre-commit`<br>`.githooks/pre-push`<br>`scripts/check-public-build-profile.sh` | `.githooks/pre-commit` and `.githooks/pre-push` enforce profile policy. | Reopen only for a concrete build-profile tracking regression. |
