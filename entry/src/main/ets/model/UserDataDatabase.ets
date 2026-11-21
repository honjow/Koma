import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { CREATE_READER_PREFERENCES, copyReaderPreferenceColumns } from './ReaderPreferenceColumns'

const DATABASE_NAME = 'Koma.db'
const PREVIOUS_DATABASE_NAME = 'koma-user-data.db'
const DATABASE_VERSION = 6
const PREVIOUS_DATABASE_VERSION = 5
const RENAMED_DATABASE = 'business-database-renamed-v1'
const opens = new Map<string, Promise<relationalStore.RdbStore>>()

const READER_POSITION_COLUMNS = 'page_id TEXT, page_index INTEGER, total_pages INTEGER, progress_ratio REAL, ' +
  'completed INTEGER, saved_at INTEGER, column_mode TEXT'
const READER_TABLES: string[] = [
  'CREATE TABLE IF NOT EXISTS reader_current_positions (' +
    'comic_id TEXT PRIMARY KEY NOT NULL, chapter_id TEXT NOT NULL, ' + READER_POSITION_COLUMNS + ')',
  'CREATE TABLE IF NOT EXISTS reader_chapter_states (' +
    'comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, is_read INTEGER, bookmarked INTEGER, updated_at INTEGER, ' +
    'source_id TEXT, source_work_id TEXT, has_position INTEGER NOT NULL, position_comic_id_override TEXT, ' +
    'position_chapter_id_override TEXT, ' + READER_POSITION_COLUMNS +
    ', PRIMARY KEY (comic_id, chapter_id))',
  'CREATE INDEX IF NOT EXISTS reader_chapter_states_read ON reader_chapter_states (comic_id, is_read)',
  'CREATE TABLE IF NOT EXISTS reader_source_history (' +
    'comic_id TEXT PRIMARY KEY NOT NULL, source_id TEXT, manga_id TEXT, manga_url TEXT, title TEXT, cover_uri TEXT, ' +
    'source_name TEXT, reading_format TEXT, chapter_id TEXT, chapter_title TEXT)',
  'CREATE TABLE IF NOT EXISTS reader_remote_history (' +
    'comic_id TEXT PRIMARY KEY NOT NULL, remote_kind TEXT, chapter_id TEXT, server_id TEXT, resource_id TEXT, title TEXT, ' +
    'chapter_title TEXT, library_id INTEGER, has_path INTEGER NOT NULL, is_opds_root_feed INTEGER, opds_feed_path TEXT, ' +
    'opds_search_query TEXT)',
  'CREATE TABLE IF NOT EXISTS reader_remote_history_paths (' +
    'comic_id TEXT NOT NULL REFERENCES reader_remote_history (comic_id) ON DELETE CASCADE, ' +
    'path_order INTEGER NOT NULL, segment TEXT NOT NULL, PRIMARY KEY (comic_id, path_order))',
  'CREATE TABLE IF NOT EXISTS reader_sessions (' +
    'comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER NOT NULL, ' +
    'session_occurrence INTEGER NOT NULL, session_order INTEGER NOT NULL, pages_read INTEGER NOT NULL, ' +
    'PRIMARY KEY (comic_id, chapter_id, started_at, ended_at, session_occurrence))',
  'CREATE INDEX IF NOT EXISTS reader_sessions_time ON reader_sessions (started_at)',
  'CREATE TABLE IF NOT EXISTS reader_outbox_positions (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, list_order INTEGER NOT NULL, source_id TEXT NOT NULL, ' +
    'source_work_id TEXT NOT NULL, comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, page_index INTEGER NOT NULL, ' +
    'total_pages INTEGER NOT NULL, completed INTEGER NOT NULL, saved_at INTEGER NOT NULL, recent_chapter_id TEXT, ' +
    'recent_chapter_title TEXT, recent_title TEXT, recent_source_name TEXT, recent_source_version TEXT, ' +
    'recent_saved_at INTEGER, recent_page_index INTEGER, recent_work_url TEXT, PRIMARY KEY (space, capture_id))',
  'CREATE TABLE IF NOT EXISTS reader_outbox_position_versions (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, field_kind TEXT NOT NULL, vector_order INTEGER NOT NULL, ' +
    'replica TEXT NOT NULL, sequence INTEGER NOT NULL, PRIMARY KEY (space, capture_id, field_kind, vector_order), ' +
    'FOREIGN KEY (space, capture_id) REFERENCES reader_outbox_positions (space, capture_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS reader_outbox_position_observed_actions (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, action_order INTEGER NOT NULL, action_id TEXT NOT NULL, ' +
    'PRIMARY KEY (space, capture_id, action_order), ' +
    'FOREIGN KEY (space, capture_id) REFERENCES reader_outbox_positions (space, capture_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS reader_outbox_actions (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, list_order INTEGER NOT NULL, source_id TEXT NOT NULL, ' +
    'source_work_id TEXT NOT NULL, chapter_id TEXT NOT NULL, PRIMARY KEY (space, capture_id))',
  'CREATE TABLE IF NOT EXISTS reader_outbox_action_edits (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, edit_order INTEGER NOT NULL, edit_key TEXT NOT NULL, ' +
    'edit_kind TEXT NOT NULL, edit_value TEXT NOT NULL, PRIMARY KEY (space, capture_id, edit_order), ' +
    'FOREIGN KEY (space, capture_id) REFERENCES reader_outbox_actions (space, capture_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS reader_outbox_action_versions (' +
    'space TEXT NOT NULL, capture_id TEXT NOT NULL, edit_order INTEGER NOT NULL, vector_order INTEGER NOT NULL, ' +
    'replica TEXT NOT NULL, sequence INTEGER NOT NULL, PRIMARY KEY (space, capture_id, edit_order, vector_order), ' +
    'FOREIGN KEY (space, capture_id, edit_order) REFERENCES reader_outbox_action_edits (space, capture_id, edit_order) ON DELETE CASCADE)',
]

const SHELF_TABLES: string[] = [
  'CREATE TABLE IF NOT EXISTS shelf_works (comic_id TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT NULL, ' +
    'has_categories INTEGER NOT NULL, title TEXT, subtitle TEXT, author TEXT, source_kind TEXT, source_path ' +
    'TEXT, source_runtime_id TEXT, remote_server_id TEXT, remote_resource_id TEXT, cover_uri TEXT, ' +
    'personal_notes TEXT, custom_cover_uri TEXT, source_cover_uri TEXT, sort_title TEXT, preferred_direction ' +
    'TEXT, chapter_count INTEGER, page_count INTEGER, created_at INTEGER, updated_at INTEGER, last_imported_at ' +
    'INTEGER, update_interval_days INTEGER, next_check_at INTEGER, has_local_metadata ' +
    'INTEGER NOT NULL, override_title TEXT, local_status TEXT, override_cover_path TEXT, has_local_authors ' +
    'INTEGER NOT NULL, import_kind TEXT, epub_order_revision INTEGER, has_source_metadata INTEGER NOT NULL, ' +
    'source_name TEXT, content_rating TEXT, artist TEXT, source_status TEXT, web_url TEXT, settings_fingerprint ' +
    'TEXT, chapter_catalog_updated_at INTEGER, has_source_tags INTEGER NOT NULL, has_excluded_chapters INTEGER ' +
    'NOT NULL, has_shared_chapters INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS shelf_chapters (comic_id TEXT NOT NULL REFERENCES shelf_works (comic_id) ON ' +
    'DELETE CASCADE, chapter_id TEXT NOT NULL, chapter_occurrence INTEGER NOT NULL, list_order INTEGER NOT NULL, ' +
    'title TEXT, chapter_index INTEGER, chapter_number REAL, volume_number TEXT, reading_order REAL, ' +
    'reading_group TEXT, reading_variant_group TEXT, reading_variant_sequence TEXT, continuation_eligible ' +
    'INTEGER, scanlator TEXT, language TEXT, date_upload INTEGER, source_path TEXT, sort_key TEXT, ' +
    'settings_fingerprint TEXT, page_count INTEGER, created_at INTEGER, updated_at INTEGER, comic_id_override TEXT, PRIMARY KEY ' +
    '(comic_id, chapter_id, chapter_occurrence))',
  'CREATE TABLE IF NOT EXISTS shelf_pages (comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, ' +
    'chapter_occurrence INTEGER NOT NULL, page_id TEXT NOT NULL, page_occurrence INTEGER NOT NULL, list_order ' +
    'INTEGER NOT NULL, page_index INTEGER, file_name TEXT, uri TEXT, sort_key TEXT, width INTEGER, height ' +
    'INTEGER, byte_size INTEGER, text_template TEXT, text_heading TEXT, text_request_template TEXT, ' +
    'overlay_version INTEGER, required_decode_kind TEXT, required_decode_rows INTEGER, required_decode_bytes ' +
    'TEXT, required_decode_pixels TEXT, comic_id_override TEXT, chapter_id_override TEXT, ' +
    'PRIMARY KEY (comic_id, chapter_id, chapter_occurrence, page_id, ' +
    'page_occurrence), FOREIGN KEY (comic_id, chapter_id, chapter_occurrence) REFERENCES shelf_chapters ' +
    '(comic_id, chapter_id, chapter_occurrence) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS shelf_work_metadata_items (comic_id TEXT NOT NULL REFERENCES shelf_works ' +
    '(comic_id) ON DELETE CASCADE, list_kind TEXT NOT NULL, item_order INTEGER NOT NULL, item_value TEXT NOT ' +
    'NULL, PRIMARY KEY (comic_id, list_kind, item_order))',
  'CREATE TABLE IF NOT EXISTS shelf_memberships (comic_id TEXT NOT NULL REFERENCES shelf_works (comic_id) ON ' +
    'DELETE CASCADE, category_id TEXT NOT NULL, category_occurrence INTEGER NOT NULL, list_order INTEGER NOT ' +
    'NULL, PRIMARY KEY (comic_id, category_id, category_occurrence))',
  'CREATE TABLE IF NOT EXISTS shelf_page_text_lines (comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, ' +
    'chapter_occurrence INTEGER NOT NULL, page_id TEXT NOT NULL, page_occurrence INTEGER NOT NULL, item_order ' +
    'INTEGER NOT NULL, body_text TEXT NOT NULL, PRIMARY KEY (comic_id, chapter_id, chapter_occurrence, page_id, ' +
    'page_occurrence, item_order), FOREIGN KEY (comic_id, chapter_id, chapter_occurrence, page_id, ' +
    'page_occurrence) REFERENCES shelf_pages (comic_id, chapter_id, chapter_occurrence, page_id, ' +
    'page_occurrence) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS shelf_page_text_balloons (comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, ' +
    'chapter_occurrence INTEGER NOT NULL, page_id TEXT NOT NULL, page_occurrence INTEGER NOT NULL, item_order ' +
    'INTEGER NOT NULL, body_text TEXT NOT NULL, x REAL NOT NULL, y REAL NOT NULL, width INTEGER NOT NULL, ' +
    'PRIMARY KEY (comic_id, chapter_id, chapter_occurrence, page_id, page_occurrence, item_order), FOREIGN KEY ' +
    '(comic_id, chapter_id, chapter_occurrence, page_id, page_occurrence) REFERENCES shelf_pages (comic_id, ' +
    'chapter_id, chapter_occurrence, page_id, page_occurrence) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS shelf_collections (id INTEGER PRIMARY KEY CHECK (id = 1), has_categories INTEGER ' +
    'NOT NULL, has_display_strategies INTEGER NOT NULL, has_smart_categories INTEGER NOT NULL, has_mihon_imports ' +
    'INTEGER NOT NULL, has_sync_moves INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS shelf_categories (category_id TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT ' +
    'NULL, name TEXT, sort_order INTEGER, created_at INTEGER, updated_at INTEGER, is_private INTEGER)',
  'CREATE TABLE IF NOT EXISTS shelf_category_display_strategies (category_id TEXT PRIMARY KEY NOT NULL, ' +
    'list_order INTEGER NOT NULL, sort_by TEXT, sort_direction TEXT, follows_default_sort INTEGER, read_state ' +
    'TEXT, updated_at INTEGER)',
  'CREATE TABLE IF NOT EXISTS shelf_smart_categories (category_id TEXT PRIMARY KEY NOT NULL, list_order ' +
    'INTEGER NOT NULL, name TEXT, sort_order INTEGER, created_at INTEGER, updated_at INTEGER)',
  'CREATE TABLE IF NOT EXISTS shelf_smart_category_filters (category_id TEXT NOT NULL REFERENCES ' +
    'shelf_smart_categories (category_id) ON DELETE CASCADE, filter_order INTEGER NOT NULL, method TEXT NOT ' +
    'NULL, filter_value TEXT, excluded INTEGER NOT NULL, PRIMARY KEY (category_id, filter_order))',
  'CREATE TABLE IF NOT EXISTS shelf_sync_moves (space TEXT NOT NULL, source_id TEXT NOT NULL, work_id TEXT NOT ' +
    'NULL, list_order INTEGER NOT NULL, target_source_id TEXT, target_work_id TEXT, has_target_categories ' +
    'INTEGER NOT NULL, PRIMARY KEY (space, source_id, work_id))',
  'CREATE TABLE IF NOT EXISTS shelf_sync_move_categories (space TEXT NOT NULL, source_id TEXT NOT NULL, ' +
    'work_id TEXT NOT NULL, category_order INTEGER NOT NULL, category_id TEXT NOT NULL, PRIMARY KEY (space, ' +
    'source_id, work_id, category_order), FOREIGN KEY (space, source_id, work_id) REFERENCES shelf_sync_moves ' +
    '(space, source_id, work_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_imports (import_id TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT ' +
    'NULL, source_name TEXT, matched_source_id TEXT, target_comic_id TEXT, ' +
    'source_id TEXT, url TEXT, title TEXT, artist TEXT, author TEXT, description TEXT, status INTEGER, ' +
    'cover_url TEXT, added_at INTEGER, favorite INTEGER, modified_at INTEGER, favorite_modified_at INTEGER, ' +
    'notes TEXT, has_linked_work INTEGER NOT NULL, linked_manga_id TEXT, linked_source_id TEXT, linked_title ' +
    'TEXT, linked_author TEXT, linked_artist TEXT, linked_description TEXT, linked_cover_url TEXT, ' +
    'linked_status TEXT, linked_content_rating TEXT, linked_url TEXT, linked_web_url TEXT, linked_has_tags ' +
    'INTEGER, linked_has_cover_headers INTEGER)',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_chapters (import_id TEXT NOT NULL REFERENCES shelf_mihon_imports ' +
    '(import_id) ON DELETE CASCADE, item_order INTEGER NOT NULL, url TEXT, title TEXT, scanlator TEXT, is_read ' +
    'INTEGER, bookmarked INTEGER, page_index INTEGER, fetched_at INTEGER, uploaded_at INTEGER, chapter_number ' +
    'REAL, source_order INTEGER, modified_at INTEGER, PRIMARY KEY (import_id, item_order))',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_history (import_id TEXT NOT NULL REFERENCES shelf_mihon_imports ' +
    '(import_id) ON DELETE CASCADE, item_order INTEGER NOT NULL, chapter_url TEXT, read_at INTEGER, ' +
    'read_duration INTEGER, PRIMARY KEY (import_id, item_order))',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_tracking (import_id TEXT NOT NULL REFERENCES shelf_mihon_imports ' +
    '(import_id) ON DELETE CASCADE, item_order INTEGER NOT NULL, service_id INTEGER, library_id TEXT, media_id ' +
    'TEXT, url TEXT, title TEXT, last_chapter_read REAL, total_chapters INTEGER, score REAL, status INTEGER, ' +
    'started_at INTEGER, finished_at INTEGER, is_private INTEGER, PRIMARY KEY (import_id, item_order))',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_text_items (import_id TEXT NOT NULL REFERENCES shelf_mihon_imports ' +
    '(import_id) ON DELETE CASCADE, item_kind TEXT NOT NULL, item_order INTEGER NOT NULL, item_text TEXT NOT ' +
    'NULL, PRIMARY KEY (import_id, item_kind, item_order))',
  'CREATE TABLE IF NOT EXISTS shelf_mihon_cover_headers (import_id TEXT NOT NULL REFERENCES ' +
    'shelf_mihon_imports (import_id) ON DELETE CASCADE, header_name TEXT NOT NULL, header_order INTEGER NOT ' +
    'NULL, header_value TEXT NOT NULL, PRIMARY KEY (import_id, header_name))',
  'CREATE INDEX IF NOT EXISTS shelf_works_order ON shelf_works (list_order)',
  'CREATE INDEX IF NOT EXISTS shelf_chapters_order ON shelf_chapters (comic_id, list_order)',
  'CREATE INDEX IF NOT EXISTS shelf_pages_order ON shelf_pages (comic_id, chapter_id, chapter_occurrence, ' +
    'list_order)',
  'CREATE INDEX IF NOT EXISTS shelf_memberships_category ON shelf_memberships (category_id, comic_id)',
]

export function openUserDataDatabase(context: common.Context): Promise<relationalStore.RdbStore> {
  const directory = context.filesDir
  const pending = opens.get(directory)
  if (pending !== undefined) return pending
  const opening = initializeUserDataDatabase(context).catch((error: Error): never => {
    opens.delete(directory)
    throw error
  })
  opens.set(directory, opening)
  return opening
}

/** Snapshot workers read the already prepared database; they never migrate or rebuild it. */
export function openUserDataSnapshotDatabase(context: common.Context): Promise<relationalStore.RdbStore> {
  return relationalStore.getRdbStore(context, {
    name: DATABASE_NAME, securityLevel: relationalStore.SecurityLevel.S3, isReadOnly: true, allowRebuild: false,
  })
}

const LEGACY_DATA_TABLES: string[] = [
  'CREATE TABLE library_document (id INTEGER PRIMARY KEY, list_mask INTEGER)',
  'CREATE TABLE library_works (id TEXT PRIMARY KEY, list_order INTEGER, payload TEXT, has_categories INTEGER)',
  'CREATE TABLE library_chapters (comic_id TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (comic_id, list_order))',
  'CREATE TABLE library_memberships (comic_id TEXT, list_order INTEGER, category_id TEXT, PRIMARY KEY (comic_id, list_order))',
  'CREATE TABLE library_lists (kind TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (kind, list_order))',
  'CREATE TABLE reading_works (kind TEXT, comic_id TEXT, payload TEXT, PRIMARY KEY (kind, comic_id))',
  'CREATE TABLE reading_chapter_states (comic_id TEXT, chapter_id TEXT, payload TEXT, PRIMARY KEY (comic_id, chapter_id))',
  'CREATE TABLE reading_local_records (kind TEXT, list_order INTEGER, payload TEXT, PRIMARY KEY (kind, list_order))',
  'CREATE TABLE user_keyed_records (domain TEXT NOT NULL, record_key TEXT NOT NULL, value TEXT NOT NULL, ' +
    'PRIMARY KEY (domain, record_key))',
  'CREATE TABLE user_record_collections (domain TEXT PRIMARY KEY)',
]

const CONFIG_TABLES: string[] = [
  CREATE_READER_PREFERENCES,
  'CREATE TABLE IF NOT EXISTS local_data_migrations (name TEXT PRIMARY KEY)',
  'CREATE TABLE IF NOT EXISTS search_history (' +
    'entry_key TEXT PRIMARY KEY, query TEXT, updated_at INTEGER, list_order INTEGER, ' +
    'source_filter TEXT, library_source_key TEXT, library_source_name TEXT, sync_source_set TEXT)',
  'CREATE INDEX IF NOT EXISTS search_history_list ON search_history (updated_at DESC, list_order)',
  'CREATE TABLE IF NOT EXISTS library_maintenance_jobs (' +
    'enqueue_order INTEGER PRIMARY KEY, job_kind TEXT NOT NULL, comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, ' +
    'UNIQUE (job_kind, comic_id, chapter_id))',
  'CREATE INDEX IF NOT EXISTS library_maintenance_jobs_order ' +
    'ON library_maintenance_jobs (job_kind, enqueue_order)',
  'CREATE TABLE IF NOT EXISTS source_subscription_selection (' +
    'id INTEGER PRIMARY KEY CHECK (id = 1), active_url TEXT, has_repository_list INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS source_subscriptions (' +
    'url TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT NULL, last_used_at INTEGER NOT NULL, disabled INTEGER, ' +
    'custom_name TEXT, repository_name TEXT, website TEXT)',
  'CREATE INDEX IF NOT EXISTS source_subscriptions_order ON source_subscriptions (list_order)',
  'CREATE TABLE IF NOT EXISTS offline_download_queues (' +
    'queue_id TEXT PRIMARY KEY NOT NULL, next_order INTEGER NOT NULL, concurrency_limit INTEGER NOT NULL, ' +
    'is_paused INTEGER NOT NULL, wifi_only INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS offline_download_tasks (' +
    'queue_id TEXT NOT NULL REFERENCES offline_download_queues (queue_id) ON DELETE CASCADE, ' +
    'comic_id TEXT NOT NULL, chapter_id TEXT NOT NULL, task_occurrence INTEGER NOT NULL, list_order INTEGER NOT NULL, ' +
    'is_automatic INTEGER, paused_by_user INTEGER, is_canceling INTEGER, request_id TEXT, source_name TEXT, ' +
    'source_id TEXT, source_manga_id TEXT, source_manga_url TEXT, comic_title TEXT, chapter_title TEXT, ' +
    'status TEXT NOT NULL, page_count INTEGER NOT NULL, downloaded_page_count INTEGER NOT NULL, ' +
    'updated_at INTEGER NOT NULL, failure_reason_code TEXT, PRIMARY KEY (queue_id, comic_id, chapter_id, task_occurrence))',
  'CREATE INDEX IF NOT EXISTS offline_download_tasks_order ' +
    'ON offline_download_tasks (queue_id, list_order)',
  'CREATE TABLE IF NOT EXISTS source_preference_documents (scope TEXT PRIMARY KEY NOT NULL)',
  'CREATE TABLE IF NOT EXISTS source_preference_sources (' +
    'scope TEXT NOT NULL REFERENCES source_preference_documents (scope) ON DELETE CASCADE, source_id TEXT NOT NULL, ' +
    'list_order INTEGER NOT NULL, PRIMARY KEY (scope, source_id))',
  'CREATE TABLE IF NOT EXISTS source_preference_groups (' +
    'scope TEXT NOT NULL, source_id TEXT NOT NULL, group_kind TEXT NOT NULL, group_order INTEGER NOT NULL, ' +
    'preset_name TEXT, preset_query TEXT, PRIMARY KEY (scope, source_id, group_kind, group_order), ' +
    'FOREIGN KEY (scope, source_id) REFERENCES source_preference_sources (scope, source_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS source_preference_fields (' +
    'scope TEXT NOT NULL, source_id TEXT NOT NULL, group_kind TEXT NOT NULL, group_order INTEGER NOT NULL, ' +
    'field_id TEXT NOT NULL, field_order INTEGER NOT NULL, value_kind TEXT NOT NULL, value_text TEXT, value_number REAL, ' +
    'value_boolean INTEGER, PRIMARY KEY (scope, source_id, group_kind, group_order, field_id), ' +
    'FOREIGN KEY (scope, source_id, group_kind, group_order) REFERENCES source_preference_groups ' +
    '(scope, source_id, group_kind, group_order) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS source_preference_field_items (' +
    'scope TEXT NOT NULL, source_id TEXT NOT NULL, group_kind TEXT NOT NULL, group_order INTEGER NOT NULL, ' +
    'field_id TEXT NOT NULL, item_order INTEGER NOT NULL, item_text TEXT NOT NULL, ' +
    'PRIMARY KEY (scope, source_id, group_kind, group_order, field_id, item_order), ' +
    'FOREIGN KEY (scope, source_id, group_kind, group_order, field_id) REFERENCES source_preference_fields ' +
    '(scope, source_id, group_kind, group_order, field_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS source_registry_state (id INTEGER PRIMARY KEY CHECK (id = 1))',
  'CREATE TABLE IF NOT EXISTS source_registry_entries (' +
    'source_id TEXT NOT NULL, source_occurrence INTEGER NOT NULL, list_order INTEGER NOT NULL, chapter_order TEXT\x2c ' +
    'manifest_id TEXT, manifest_name TEXT, manifest_version TEXT, route TEXT\x2c ' +
    'import_status TEXT, wasm_byte_count INTEGER, hash_ok INTEGER, allows_network INTEGER\x2c ' +
    'enabled INTEGER, language TEXT, source_type TEXT, nsfw INTEGER\x2c ' +
    'wasm_path TEXT, manifest_path TEXT, archive_path TEXT, package_icon_path TEXT\x2c ' +
    'catalog_origin TEXT, session_storage_identity TEXT, package_homepage TEXT, package_author TEXT\x2c ' +
    'package_description TEXT, package_content_rating TEXT, package_min_app_version TEXT, presentation_description TEXT\x2c ' +
    'presentation_icon TEXT, has_localized_names INTEGER NOT NULL, has_capabilities INTEGER NOT NULL, has_web_origins INTEGER NOT NULL\x2c ' +
    'has_required_decodes INTEGER NOT NULL, auth_kind TEXT, login_url TEXT, username_label TEXT\x2c ' +
    'password_label TEXT, credential_storage TEXT, user_agent TEXT, has_login_urls INTEGER NOT NULL\x2c ' +
    'has_cookie_names INTEGER NOT NULL, token_version INTEGER, token_storage_key TEXT, token_api_origin TEXT\x2c ' +
    'token_verify_path TEXT, token_image_key_derivation TEXT, PRIMARY KEY (source_id, source_occurrence))',
  'CREATE TABLE IF NOT EXISTS source_registry_attributes (' +
    'source_id TEXT NOT NULL, source_occurrence INTEGER NOT NULL, attribute_kind TEXT NOT NULL, item_order INTEGER NOT NULL, ' +
    'attribute_label TEXT, attribute_value TEXT NOT NULL, PRIMARY KEY (source_id, source_occurrence, attribute_kind, item_order), ' +
    'FOREIGN KEY (source_id, source_occurrence) REFERENCES source_registry_entries (source_id, source_occurrence) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS typed_preference_collections (domain TEXT PRIMARY KEY NOT NULL)',
  'CREATE TABLE IF NOT EXISTS typed_local_preferences (' +
    'domain TEXT NOT NULL REFERENCES typed_preference_collections (domain) ON DELETE CASCADE, ' +
    'preference_id TEXT NOT NULL, value_kind TEXT NOT NULL, value_text TEXT, value_number REAL, value_boolean INTEGER, ' +
    'PRIMARY KEY (domain, preference_id))',
  'CREATE TABLE IF NOT EXISTS typed_local_preference_items (' +
    'domain TEXT NOT NULL, preference_id TEXT NOT NULL, item_order INTEGER NOT NULL, item_text TEXT NOT NULL, ' +
    'PRIMARY KEY (domain, preference_id, item_order), FOREIGN KEY (domain, preference_id) ' +
    'REFERENCES typed_local_preferences (domain, preference_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS book_preferences (' +
    'comic_id TEXT PRIMARY KEY NOT NULL, sort_basis TEXT, sort_direction TEXT, read_filter TEXT, ' +
    'language_filter TEXT, group_filter TEXT, bookmark_filter TEXT, page_mode TEXT, reading_direction TEXT, ' +
    'banner_filter TEXT, synopsis_expanded INTEGER, has_chapter_settings INTEGER NOT NULL DEFAULT 0, ' +
    'has_reader_mode INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS tracker_mappings (' +
    'binding_key TEXT PRIMARY KEY NOT NULL, comic_id TEXT, provider_id TEXT, provider_title_id TEXT, provider_title TEXT, ' +
    'mapping_state TEXT, confidence REAL, user_confirmed INTEGER, created_at INTEGER, updated_at INTEGER, list_order INTEGER NOT NULL)',
  'CREATE INDEX IF NOT EXISTS tracker_mappings_work ON tracker_mappings (comic_id, provider_id)',
  'CREATE TABLE IF NOT EXISTS tracker_progress_outbox (' +
    'operation_key TEXT PRIMARY KEY NOT NULL, provider_id TEXT, comic_id TEXT, chapter_id TEXT, trigger_kind TEXT, page_index INTEGER, ' +
    'total_pages INTEGER, progress_ratio REAL, completed INTEGER, provider_progress REAL, attempts INTEGER, ' +
    'first_queued_at INTEGER, updated_at INTEGER, last_reason TEXT, list_order INTEGER NOT NULL, has_chapters INTEGER NOT NULL)',
  'CREATE INDEX IF NOT EXISTS tracker_progress_outbox_work ON tracker_progress_outbox (provider_id, comic_id, chapter_id)',
  'CREATE TABLE IF NOT EXISTS tracker_outbox_chapters (' +
    'operation_key TEXT NOT NULL REFERENCES tracker_progress_outbox (operation_key) ON DELETE CASCADE, ' +
    'chapter_order INTEGER NOT NULL, chapter_id TEXT NOT NULL, PRIMARY KEY (operation_key, chapter_order))',
  'CREATE TABLE IF NOT EXISTS library_chapter_discoveries (' +
    'discovery_key TEXT PRIMARY KEY NOT NULL, comic_id TEXT, chapter_id TEXT, discovered_at INTEGER, list_order INTEGER NOT NULL)',
  'CREATE INDEX IF NOT EXISTS library_chapter_discoveries_work ON library_chapter_discoveries (comic_id, discovered_at)',
  'CREATE TABLE IF NOT EXISTS library_update_job (' +
    'id INTEGER PRIMARY KEY CHECK (id = 1), state TEXT NOT NULL, updated_at INTEGER NOT NULL, started_at INTEGER, ' +
    'finished_at INTEGER, next_due_at INTEGER, failure_code TEXT)',
  'CREATE TABLE IF NOT EXISTS library_update_summaries (' +
    'report_kind TEXT PRIMARY KEY NOT NULL, checked_at INTEGER NOT NULL, total_count INTEGER NOT NULL, ' +
    'updated_count INTEGER NOT NULL, unchanged_count INTEGER NOT NULL, skipped_count INTEGER NOT NULL, failed_count INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS library_update_results (' +
    'report_kind TEXT NOT NULL REFERENCES library_update_summaries (report_kind) ON DELETE CASCADE, ' +
    'result_order INTEGER NOT NULL, comic_id TEXT NOT NULL, provider_kind TEXT NOT NULL, source_key TEXT NOT NULL, ' +
    'status TEXT NOT NULL, previous_chapter_count INTEGER NOT NULL, new_chapter_count INTEGER NOT NULL, ' +
    'added_chapter_count INTEGER, message TEXT NOT NULL, PRIMARY KEY (report_kind, result_order))',
  'CREATE TABLE IF NOT EXISTS library_update_provider_results (' +
    'report_kind TEXT NOT NULL, provider_order INTEGER NOT NULL, provider_kind TEXT NOT NULL, source_key TEXT NOT NULL, ' +
    'total_count INTEGER NOT NULL, updated_count INTEGER NOT NULL, unchanged_count INTEGER NOT NULL, ' +
    'skipped_count INTEGER NOT NULL, failed_count INTEGER NOT NULL, new_chapter_count INTEGER NOT NULL, ' +
    'PRIMARY KEY (report_kind, provider_order))',
  'CREATE TABLE IF NOT EXISTS library_update_provider_failures (' +
    'report_kind TEXT NOT NULL, provider_order INTEGER NOT NULL, code_order INTEGER NOT NULL, failure_code TEXT NOT NULL, ' +
    'PRIMARY KEY (report_kind, provider_order, code_order), FOREIGN KEY (report_kind, provider_order) ' +
    'REFERENCES library_update_provider_results (report_kind, provider_order) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS image_rule_state (id INTEGER PRIMARY KEY CHECK (id = 1))',
  'CREATE TABLE IF NOT EXISTS image_rule_subscriptions (' +
    'url TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT NULL, asset_digest TEXT NOT NULL, name TEXT NOT NULL, ' +
    'custom_name TEXT, description TEXT, website TEXT, updated_at INTEGER NOT NULL, revision TEXT NOT NULL, ' +
    'last_error TEXT, disabled INTEGER, last_download_at INTEGER, has_manifest_hashes INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS image_rule_manifest_hashes (' +
    'url TEXT NOT NULL REFERENCES image_rule_subscriptions (url) ON DELETE CASCADE, manifest_id TEXT NOT NULL, ' +
    'manifest_order INTEGER NOT NULL, manifest_hash TEXT NOT NULL, PRIMARY KEY (url, manifest_id))',
  'CREATE TABLE IF NOT EXISTS image_rule_installations (' +
    'origin TEXT PRIMARY KEY NOT NULL, list_order INTEGER NOT NULL, asset_digest TEXT NOT NULL, name TEXT NOT NULL, ' +
    'has_conflicts INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS image_rule_installation_items (' +
    'origin TEXT NOT NULL REFERENCES image_rule_installations (origin) ON DELETE CASCADE, item_kind TEXT NOT NULL, ' +
    'item_order INTEGER NOT NULL, rule_id TEXT NOT NULL, PRIMARY KEY (origin, item_kind, item_order))',
  'CREATE TABLE IF NOT EXISTS image_rule_plugin_groups (' +
    'origin TEXT NOT NULL REFERENCES image_rule_installations (origin) ON DELETE CASCADE, plugin_id TEXT NOT NULL, ' +
    'plugin_order INTEGER NOT NULL, PRIMARY KEY (origin, plugin_id))',
  'CREATE TABLE IF NOT EXISTS image_rule_plugin_fields (' +
    'origin TEXT NOT NULL, plugin_id TEXT NOT NULL, field_id TEXT NOT NULL, field_order INTEGER NOT NULL, ' +
    'value_kind TEXT NOT NULL, value_text TEXT, value_number REAL, value_boolean INTEGER, ' +
    'PRIMARY KEY (origin, plugin_id, field_id), FOREIGN KEY (origin, plugin_id) ' +
    'REFERENCES image_rule_plugin_groups (origin, plugin_id) ON DELETE CASCADE)',
  'CREATE TABLE IF NOT EXISTS image_rule_plugin_field_items (' +
    'origin TEXT NOT NULL, plugin_id TEXT NOT NULL, field_id TEXT NOT NULL, item_order INTEGER NOT NULL, item_text TEXT NOT NULL, ' +
    'PRIMARY KEY (origin, plugin_id, field_id, item_order), FOREIGN KEY (origin, plugin_id, field_id) ' +
    'REFERENCES image_rule_plugin_fields (origin, plugin_id, field_id) ON DELETE CASCADE)',
]

const OLD_WORK_COLUMNS = 'w.comic_id, w.list_order, w.has_categories, w.title, w.subtitle, w.author, w.source_kind, w.source_path, ' +
    'w.source_runtime_id, w.remote_server_id, w.remote_resource_id, w.cover_uri, w.personal_notes, ' +
    'w.custom_cover_uri, w.source_cover_uri, w.sort_title, w.preferred_direction, w.chapter_count, ' +
    'w.page_count, w.created_at, w.updated_at, w.last_imported_at'
const OLD_WORK_METADATA_COLUMNS = 'm.update_interval_days, m.next_check_at, COALESCE(m.has_local_metadata, 0), m.override_title, ' +
    'm.local_status, m.override_cover_path, COALESCE(m.has_local_authors, 0), m.import_kind, ' +
    'm.epub_order_revision, COALESCE(m.has_source_metadata, 0), m.source_name, m.content_rating, m.artist, ' +
    'm.source_status, m.web_url, m.settings_fingerprint, m.chapter_catalog_updated_at, ' +
    'COALESCE(m.has_source_tags, 0), COALESCE(m.has_excluded_chapters, 0), COALESCE(m.has_shared_chapters, 0)'

async function copyShelfWorks(source: relationalStore.RdbStore, transaction: relationalStore.Transaction): Promise<void> {
  await transferTable(source, transaction, 'INSERT INTO shelf_works', 'SELECT ' + OLD_WORK_COLUMNS + ', ' + OLD_WORK_METADATA_COLUMNS +
    ' FROM shelf_works w LEFT JOIN shelf_work_metadata m ON m.comic_id = w.comic_id ORDER BY w.rowid')
}

async function copyMihonImports(source: relationalStore.RdbStore, transaction: relationalStore.Transaction): Promise<void> {
  await transferTable(source, transaction, 'INSERT INTO shelf_mihon_imports', 'SELECT ' +
    'r.*, w.source_id, w.url, w.title, w.artist, w.author, w.description, w.status, w.cover_url, w.added_at, ' +
    'w.favorite, w.modified_at, w.favorite_modified_at, w.notes, l.import_id IS NOT NULL, l.manga_id, ' +
    'l.source_id, l.title, l.author, l.artist, l.description, l.cover_url, l.status, l.content_rating, ' +
    'l.url, l.web_url, l.has_tags, l.has_cover_headers' +
    ' FROM shelf_mihon_imports r JOIN shelf_mihon_source_works w ON w.import_id = r.import_id ' +
    'LEFT JOIN shelf_mihon_linked_works l ON l.import_id = r.import_id ORDER BY r.rowid')
}

async function copyBookPreferences(source: relationalStore.RdbStore, transaction: relationalStore.Transaction,
  existing: Set<string>): Promise<void> {
  if (existing.has('chapter_list_settings')) {
    await transferTable(source, transaction, 'INSERT INTO book_preferences (comic_id, sort_basis, sort_direction, read_filter, ' +
      'language_filter, group_filter, bookmark_filter, has_chapter_settings)',
      'SELECT comic_id, sort_basis, sort_direction, read_filter, language_filter, group_filter, bookmark_filter, 1 ' +
      'FROM chapter_list_settings ORDER BY rowid')
  }
  if (existing.has('reader_book_modes')) {
    await transferTable(source, transaction, 'INSERT INTO book_preferences (comic_id, page_mode, reading_direction, has_reader_mode)',
      'SELECT comic_id, page_mode, reading_direction, 1 FROM reader_book_modes ORDER BY rowid',
      ' ON CONFLICT(comic_id) DO UPDATE SET page_mode=excluded.page_mode, reading_direction=excluded.reading_direction, has_reader_mode=1')
  }
  await transaction.execute('INSERT INTO book_preferences (comic_id, banner_filter) ' +
    "SELECT preference_id, value_text FROM typed_local_preferences WHERE domain = ? AND value_kind = 'string' " +
    'ORDER BY rowid ON CONFLICT(comic_id) DO UPDATE SET banner_filter=excluded.banner_filter',
    ['preferences/koma_reader_preferences_v1/reader.bannerFilterOverrides.v1'])
  await transaction.execute('INSERT INTO book_preferences (comic_id, synopsis_expanded) ' +
    "SELECT preference_id, value_boolean FROM typed_local_preferences WHERE domain = ? AND value_kind = 'boolean' " +
    'ORDER BY rowid ON CONFLICT(comic_id) DO UPDATE SET synopsis_expanded=excluded.synopsis_expanded',
    ['preferences/koma_manga_synopsis_v1/'])
  await transaction.execute('DELETE FROM typed_local_preferences WHERE domain IN (?, ?)', [
    'preferences/koma_reader_preferences_v1/reader.bannerFilterOverrides.v1', 'preferences/koma_manga_synopsis_v1/',
  ])
}

/** The previous and current stores are opened separately. Bind values in
 * bounded batches so a large shelf does not create a whole-library JS copy.
 */
async function transferTable(source: relationalStore.RdbStore, target: relationalStore.Transaction,
  insert: string, query: string, conflict: string = ''): Promise<void> {
  const rows = await source.querySql(query)
  try {
    if (!rows.goToNextRow()) return
    const columnCount = rows.columnCount
    const rowSlots = '(' + new Array<string>(columnCount).fill('?').join(', ') + ')'
    const maxRows = Math.floor(900 / columnCount)
    let batch: relationalStore.ValueType[] = []
    let slots: string[] = []
    do {
      for (let i = 0; i < columnCount; i++) {
        batch.push(rows.isColumnNull(i) ? null : rows.getValue(i))
      }
      slots.push(rowSlots)
      if (slots.length === maxRows) {
        await target.execute(insert + ' VALUES ' + slots.join(', ') + conflict, batch)
        batch = []
        slots = []
      }
    } while (rows.goToNextRow())
    if (slots.length > 0) await target.execute(insert + ' VALUES ' + slots.join(', ') + conflict, batch)
  } finally {
    rows.close()
  }
}

async function schemaNames(source: relationalStore.RdbStore): Promise<Set<string>> {
  const rows = await source.querySql("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
  const names = new Set<string>()
  try {
    while (rows.goToNextRow()) names.add(rows.getString(0))
    return names
  } finally {
    rows.close()
  }
}

function tableName(ddl: string): string | undefined {
  return /^CREATE TABLE (?:IF NOT EXISTS )?([a-z_]+) /.exec(ddl)?.[1]
}

/** This copy is a single startup transaction. Only tables owned by this store
 * are copied. Old RDB tables needed by a domain's migration remain available,
 * and all remote transport tables stay outside the new business store.
 */
async function initializeTables(store: relationalStore.RdbStore, previous?: relationalStore.RdbStore): Promise<void> {
  const transaction = await store.createTransaction({ transactionType: relationalStore.TransactionType.IMMEDIATE })
  try {
    const statements = CONFIG_TABLES.concat(READER_TABLES, SHELF_TABLES)
    for (const statement of statements) await transaction.execute(statement)
    const complete = await transaction.querySql('SELECT name FROM local_data_migrations WHERE name = ?', [RENAMED_DATABASE])
    let committed: boolean
    try {
      committed = complete.goToNextRow()
    } finally {
      complete.close()
    }
    if (previous !== undefined && !committed) {
      const existing = await schemaNames(previous)
      if (!existing.has('local_data_migrations') || !existing.has('search_history')) {
        throw new Error('previous_user_database_unavailable')
      }
      for (const statement of statements.concat(LEGACY_DATA_TABLES)) {
        const name = tableName(statement)
        if (name === undefined || !existing.has(name)) continue
        if (name === 'shelf_works') {
          await copyShelfWorks(previous, transaction)
          continue
        }
        if (name === 'shelf_mihon_imports') {
          await copyMihonImports(previous, transaction)
          continue
        }
        if (!statement.includes('IF NOT EXISTS')) await transaction.execute(statement)
        // Several legacy owners consume rowid as insertion order.
        await transferTable(previous, transaction, 'INSERT INTO ' + name, 'SELECT * FROM ' + name + ' ORDER BY rowid')
      }
      await copyReaderPreferenceColumns(transaction)
      await copyBookPreferences(previous, transaction, existing)
    }
    await transaction.execute('INSERT OR IGNORE INTO local_data_migrations (name) VALUES (?)', [RENAMED_DATABASE])
    await transaction.commit()
  } catch (error) {
    await transaction.rollback()
    throw error as Error
  }
}

async function initializeUserDataDatabase(context: common.Context): Promise<relationalStore.RdbStore> {
  const store = await relationalStore.getRdbStore(context, {
    name: DATABASE_NAME, securityLevel: relationalStore.SecurityLevel.S3, allowRebuild: false,
  })
  if (store.version > DATABASE_VERSION) throw new Error('user_data_newer_schema')
  if (store.version === DATABASE_VERSION) return store
  // ArkData resolves its own sandbox path. Inferring it from databaseDir and
  // treating an inaccessible path as an absent database can select stale files.
  const oldConfig: relationalStore.StoreConfig = {
    name: PREVIOUS_DATABASE_NAME, securityLevel: relationalStore.SecurityLevel.S3, allowRebuild: false,
  }
  const previous = await relationalStore.getRdbStore(context, oldConfig)
  try {
    const oldVersion = previous.version
    if (oldVersion > PREVIOUS_DATABASE_VERSION) throw new Error('user_data_newer_schema')
    if (oldVersion === 0 && (await schemaNames(previous)).size > 0) {
      throw new Error('previous_user_database_version_missing')
    }
    await initializeTables(store, oldVersion > 0 ? previous : undefined)
  } finally {
    await previous.close()
  }
  store.version = DATABASE_VERSION
  return store
}

export function hasUserDataMigration(store: relationalStore.RdbStore, name: string): boolean {
  const result = store.querySqlSync('SELECT name FROM local_data_migrations WHERE name = ?', [name])
  try {
    return result.goToNextRow()
  } finally {
    result.close()
  }
}

export function markUserDataMigration(store: relationalStore.RdbStore, name: string): void {
  store.executeSync('INSERT OR IGNORE INTO local_data_migrations (name) VALUES (?)', [name])
}
