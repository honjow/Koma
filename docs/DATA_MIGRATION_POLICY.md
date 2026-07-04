# Koma Data Migration Policy

更新时间：2026-07-04

## 范围

Koma 当前使用文件 JSON、Harmony Preferences、AssetStore 和本地备份格式。迁移规则覆盖这些持久层：

| Domain | Store | Current version/key |
| --- | --- | --- |
| Library | `LibraryPersistence.ets` | `LIBRARY_STORE_PERSISTENCE_SCHEMA_VERSION = 1`, `library-store.v1.json` |
| Reader progress | `ReaderSessionStore.ets` | `READER_PROGRESS_PERSISTENCE_SCHEMA_VERSION = 1`, `reader-progress.v1.json` |
| Reader preferences | `ReaderPreferencesStore.ets` | `READER_PREFERENCES_STORE_NAME = koma_reader_preferences_v1` |
| Per-series reader overrides | `ReaderPreferencesStore.ets` | `SERIES_OVERRIDES_KEY = reader.seriesOverrides.v1` |
| Source settings | `SourceSettingsStore.ets` | `SOURCE_SETTINGS_SCHEMA_VERSION = 1`, `source-settings.json` |
| Source registry | `SourceRuntimeRegistry.ets` / `SourceRuntimeAppRegistry.ets` | `schemaVersion = 1`, `source-runtime-registry.json` |
| Offline downloads | `OfflineDownloadStore.ets` | `OFFLINE_DOWNLOAD_SCHEMA_VERSION = 1` |
| Offline queue | `OfflineDownloadQueueStore.ets` | `OFFLINE_DOWNLOAD_QUEUE_SCHEMA_VERSION = 1`, `offline-download-queue.v1.json` |
| Backup export | `BackupService.ets` | plaintext v1/v2/v3 accepted, new plaintext export v3 |
| Encrypted backup envelope | `BackupEncryptionService.ets` | `BACKUP_ENVELOPE_VERSION = 1`, encrypted content schema v4 |
| Tracker preferences | `TrackerModels.ets` | `TRACKER_PREFERENCES_STORE_NAME = koma_tracker_preferences_v1` |
| Tracker pending sync | `TrackerPendingSyncStore.ets` | `TRACKER_PENDING_SYNC_STORE_NAME = koma_tracker_pending_sync_v1` |
| Appearance preferences | `AppearancePreferencesStore.ets` | `APPEARANCE_PREFERENCES_STORE_NAME = koma_appearance_preferences_v1` |
| Local library folder | `LocalLibraryFolderContract.ets` | `LOCAL_LIBRARY_FOLDER_CONTRACT_VERSION = 1` |
| Local rescan | `LocalLibraryRescanService.ets` | `LOCAL_LIBRARY_RESCAN_CONTRACT_VERSION = 1` |

## Rules

1. Shape changes to JSON files require a schema/version bump and an explicit old-version parser or fail-closed rejection.
2. Preferences stores keep stable keys when adding fields; new fields must have normalizers and defaults.
3. Backup restore must accept all versions in `BACKUP_ACCEPTED_SCHEMA_VERSIONS`; removing restore support requires an explicit plan update.
4. Secrets never migrate through backup JSON. Tracker tokens stay in AssetStore; source settings block credential-like descriptors.
5. Corrupt, missing, or unsupported persisted data must not mutate live state before validation succeeds.
6. File deletion during migration is bounded to app-owned roots only.

## Add-Field Checklist

- Add a default and normalizer.
- Preserve old documents by treating missing fields as defaults.
- Extend backup export/import only when the field is user-visible state.
- Add or update one static/runtime contract test that fails if the migration boundary drifts.

## Version-Bump Checklist

- Add the new current version constant.
- Keep an old-version branch until restore/import is intentionally dropped.
- Document the domain and version in this file.
- Update `scripts/test_data_migration_policy.mjs`.
