import { bundleManager, common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ReadingDirection } from '../model/ComicModels'
import {
  LibrarySortBy,
  LibraryStore,
} from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import {
  LibraryFilterPreferences,
  LibraryFilterStore,
  LibraryListDensity,
  LibraryViewMode,
} from '../model/LibraryFilterStore'
import {
  LibraryUpdateService,
  LibraryUpdateSummary,
  countLibraryUpdateNewChapters,
  formatLibraryUpdateSummary,
} from '../model/LibraryUpdateService'
import {
  LocalLibraryRefreshService,
  LocalLibraryRefreshSummary,
  formatLocalLibraryRefreshSummary,
} from '../model/LocalLibraryRefreshService'
import {
  LibraryUpdateJobSnapshot,
  LibraryUpdateResultStore,
  LibraryUpdateNotificationDispatchResult,
  clearLatestLibraryUpdateSummary,
  createLibraryUpdateJobSnapshot,
  getLibraryUpdateNotificationStatus,
  getLatestLibraryUpdateJobSnapshot,
  getLatestLibraryUpdateSummary,
  publishLibraryUpdateFailureNotification,
  publishLibraryUpdateNotification,
  requestLibraryUpdateNotificationPermission,
  setLatestLibraryUpdateJobSnapshot,
  setLatestLibraryUpdateSummary,
} from '../model/LibraryUpdateResultStore'
import {
  BackupContentPreferences,
  BackupService,
  DEFAULT_BACKUP_CONTENT_PREFERENCES,
} from '../model/BackupService'
import {
  DEFAULT_LIBRARY_UPDATE_PREFERENCES,
  LibraryUpdateNotificationStatus,
  LibraryUpdatePreferences,
  LibraryUpdatePreferencesStore,
  formatLibraryUpdateStoredSummary,
  getLibraryUpdateAutoCheckLabel,
  getLibraryUpdateLastResultLabel,
  getLibraryUpdateNextDueAt,
  getLibraryUpdateNextDueLabel,
  getLibraryUpdateNotificationStatusLabel,
  formatLibraryUpdateTimestamp,
  isLibraryUpdateDue,
  normalizeLibraryUpdateFailureCode,
  normalizeLibraryUpdateFailureCount,
} from '../model/LibraryUpdatePreferencesStore'
import {
  OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS,
  OfflineDownloadQueueStore,
} from '../model/OfflineDownloadQueueStore'
import {
  OfflineDownloadNotificationDispatchResult,
  OfflineDownloadNotificationStatus,
  getOfflineDownloadNotificationStatus,
  getOfflineDownloadNotificationStatusLabel,
  publishOfflineDownloadNotification,
  requestOfflineDownloadNotificationPermission,
} from '../model/OfflineDownloadNotificationStore'
import {
  OfflineDownloadStatus,
} from '../model/OfflineDownloadStore'
import { RemoteServerStore } from '../model/RemoteServerStore'
import {
  AppearanceAccentColor,
  AppearancePreferences,
  AppearancePreferencesStore,
  DEFAULT_APPEARANCE_PREFERENCES,
  getAppearanceAccentColorLabel,
  getAppearanceAccentColorValue,
} from '../model/AppearancePreferencesStore'
import {
  DEFAULT_TRACKER_PREFERENCES,
  TrackerPreferences,
  TrackerPreferencesStore,
  TrackerUpdateStrategy,
  getTrackerUpdateStrategyLabel,
} from '../model/TrackerModels'
import {
  ReaderRemoteImageCacheStats,
  DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES,
  READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS,
  clearReaderRemoteImageCache,
  configureReaderRemoteImageCache,
  formatReaderRemoteImageCacheSize,
  getReaderRemoteImageCacheStats,
  ReaderRemoteImageCachePreferences,
  ReaderRemoteImageCachePreferencesStore,
} from '../model/ReaderPageSourceAdapter'
import {
  DEFAULT_READER_PREFERENCES,
  ReaderBackgroundMode,
  ReaderImageFitMode,
  ReaderPageGapMode,
  ReaderPageMode,
  ReaderPreferences,
  ReaderPreferencesStore,
  ReaderTapZonePreset,
  ReaderThemeMode,
  ReaderWideImageMode,
  applyReaderThemeMode,
  getReaderBackgroundModeLabel,
  getReaderImageFitModeLabel,
  getReaderKeepScreenAwakeLabel,
  getReaderPageGapModeLabel,
  getReaderPageModeLabel,
  getReaderProgressControlsLabel,
  getReaderSwipeNavigationLabel,
  getReaderShowTapZonesLabel,
  getReaderTapNavigationLabel,
  getReaderTapZonePresetLabel,
  getReaderThemeModeLabel,
  getReaderTrimPageMarginsLabel,
  getReaderWideImageModeLabel,
  getReaderVolumeKeyNavigationLabel,
  getReadingDirectionLabel,
} from '../model/ReaderPreferencesStore'
import { listInstalled } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { AppStrings } from '../i18n/AppStrings'
import { LanguageSettings } from '../i18n/LanguageSettings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

interface SettingsRow {
  key: string
  titleKey: string
  detailKey: string
  placeholder?: boolean
}

interface SettingsSection {
  key: string
  titleKey: string
  rows: SettingsRow[]
}

export type SettingsPaneKey =
  'root' |
  'appearance' |
  'library' |
  'reader' |
  'services' |
  'downloads' |
  'tracking' |
  'backup' |
  'storage' |
  'about'

interface SettingsPaneItem {
  key: SettingsPaneKey
  titleKey: string
  detailKey: string
  icon: Resource
  color: ResourceColor
}

interface SettingsPaneSection {
  key: string
  titleKey: string
  items: SettingsPaneItem[]
}

interface SettingsSearchResult {
  key: string
  pane: SettingsPaneKey
  sectionTitle: string
  row: SettingsRow
}

function s(name: string): string {
  return AppStrings.get(name)
}

function createSettingsSections(): SettingsSection[] {
  return [
    {
      key: 'appearance',
      titleKey: 'settings_section_appearance',
      rows: [
        { key: 'theme', titleKey: 'settings_row_theme_title', detailKey: 'settings_row_theme_detail' },
        { key: 'theme-color', titleKey: 'settings_row_theme_color_title', detailKey: 'settings_row_theme_color_detail' },
        { key: 'language', titleKey: 'settings_row_language_title', detailKey: 'settings_row_language_detail' },
      ],
    },
    {
      key: 'reader',
      titleKey: 'settings_section_reader',
      rows: [
        { key: 'page-mode', titleKey: 'settings_row_page_mode_title', detailKey: 'settings_row_page_mode_detail' },
        { key: 'reading-direction', titleKey: 'settings_row_reading_direction_title', detailKey: 'settings_row_reading_direction_detail' },
        { key: 'reader-background', titleKey: 'settings_row_reader_background_title', detailKey: 'settings_row_reader_background_detail' },
        { key: 'reader-progress', titleKey: 'settings_row_reader_progress_title', detailKey: 'settings_row_reader_progress_detail' },
        { key: 'reader-keep-screen-awake', titleKey: 'settings_row_reader_keep_screen_awake_title', detailKey: 'settings_row_reader_keep_screen_awake_detail' },
        { key: 'reader-image-fit', titleKey: 'settings_row_reader_image_fit_title', detailKey: 'settings_row_reader_image_fit_detail' },
        { key: 'reader-tap-navigation', titleKey: 'settings_row_reader_tap_navigation_title', detailKey: 'settings_row_reader_tap_navigation_detail' },
        { key: 'reader-swipe-navigation', titleKey: 'settings_row_reader_swipe_navigation_title', detailKey: 'settings_row_reader_swipe_navigation_detail' },
        { key: 'reader-tap-zone-preset', titleKey: 'settings_row_reader_tap_zone_preset_title', detailKey: 'settings_row_reader_tap_zone_preset_detail' },
        { key: 'reader-show-tap-zones', titleKey: 'settings_row_reader_show_tap_zones_title', detailKey: 'settings_row_reader_show_tap_zones_detail' },
        { key: 'reader-page-gap', titleKey: 'settings_row_reader_page_gap_title', detailKey: 'settings_row_reader_page_gap_detail' },
        { key: 'reader-trim-page-margins', titleKey: 'settings_row_reader_trim_page_margins_title', detailKey: 'settings_row_reader_trim_page_margins_detail' },
        { key: 'reader-wide-image-mode', titleKey: 'settings_row_reader_wide_image_mode_title', detailKey: 'settings_row_reader_wide_image_mode_detail' },
        { key: 'reader-volume-key-navigation', titleKey: 'settings_row_reader_volume_key_navigation_title', detailKey: 'settings_row_reader_volume_key_navigation_detail' },
        { key: 'reader-reset-defaults', titleKey: 'settings_row_reader_reset_defaults_title', detailKey: 'settings_row_reader_reset_defaults_detail' },
      ],
    },
    {
      key: 'data',
      titleKey: 'settings_section_data',
      rows: [
        { key: 'komga', titleKey: 'settings_row_komga_title', detailKey: 'settings_row_komga_detail' },
        { key: 'opds', titleKey: 'settings_row_opds_title', detailKey: 'settings_row_opds_detail' },
        { key: 'webdav', titleKey: 'settings_row_webdav_title', detailKey: 'settings_row_webdav_detail' },
        { key: 'library-auto-update', titleKey: 'settings_row_library_auto_update_title', detailKey: 'settings_row_library_auto_update_detail' },
        { key: 'library-update-interval', titleKey: 'settings_row_library_update_interval_title', detailKey: 'settings_row_library_update_interval_detail' },
        { key: 'library-update-notifications', titleKey: 'settings_row_library_update_notifications_title', detailKey: 'settings_row_library_update_notifications_detail' },
        { key: 'library-update', titleKey: 'settings_row_library_update_title', detailKey: 'settings_row_library_update_detail' },
        { key: 'library-update-results', titleKey: 'settings_row_library_update_results_title', detailKey: 'settings_row_library_update_results_detail' },
        { key: 'library-categories', titleKey: 'settings_row_library_categories_title', detailKey: 'settings_row_library_categories_detail' },
        { key: 'library-view-mode', titleKey: 'settings_row_library_view_mode_title', detailKey: 'settings_row_library_view_mode_detail' },
        { key: 'list-density', titleKey: 'settings_row_list_density_title', detailKey: 'settings_row_list_density_detail' },
        { key: 'library-default-sort', titleKey: 'settings_row_library_default_sort_title', detailKey: 'settings_row_library_default_sort_detail' },
        { key: 'library-badges', titleKey: 'settings_row_library_badges_title', detailKey: 'settings_row_library_badges_detail' },
        { key: 'local-library-refresh', titleKey: 'settings_row_local_library_refresh_title', detailKey: 'settings_row_local_library_refresh_detail' },
        { key: 'sources', titleKey: 'settings_row_sources_title', detailKey: 'settings_row_sources_detail' },
        { key: 'downloads', titleKey: 'settings_row_downloads_title', detailKey: 'settings_row_downloads_detail' },
        { key: 'download-notifications', titleKey: 'settings_row_download_notifications_title', detailKey: 'settings_row_download_notifications_detail' },
        { key: 'download-notification-test', titleKey: 'settings_row_download_notification_test_title', detailKey: 'settings_row_download_notification_test_detail' },
        { key: 'download-concurrency', titleKey: 'settings_row_download_concurrency_title', detailKey: 'settings_row_download_concurrency_detail' },
        { key: 'download-retry-failed', titleKey: 'settings_row_download_retry_failed_title', detailKey: 'settings_row_download_retry_failed_detail' },
        { key: 'download-wifi-only', titleKey: 'settings_row_download_wifi_only_title', detailKey: 'settings_row_download_wifi_only_detail' },
        { key: 'trackers', titleKey: 'settings_row_trackers_title', detailKey: 'settings_row_trackers_detail' },
        { key: 'tracker-auto-sync', titleKey: 'settings_row_tracker_auto_sync_title', detailKey: 'settings_row_tracker_auto_sync_detail' },
        { key: 'tracker-update-strategy', titleKey: 'settings_row_tracker_update_strategy_title', detailKey: 'settings_row_tracker_update_strategy_detail' },
        { key: 'backup', titleKey: 'settings_row_backup_title', detailKey: 'settings_row_backup_detail' },
        { key: 'backup-auto-export', titleKey: 'settings_row_backup_auto_export_title', detailKey: 'settings_row_backup_auto_export_detail' },
        { key: 'backup-include-settings', titleKey: 'settings_row_backup_include_settings_title', detailKey: 'settings_row_backup_include_settings_detail' },
        { key: 'backup-include-download-queue', titleKey: 'settings_row_backup_include_download_queue_title', detailKey: 'settings_row_backup_include_download_queue_detail' },
        { key: 'backup-include-tracker-mappings', titleKey: 'settings_row_backup_include_tracker_mappings_title', detailKey: 'settings_row_backup_include_tracker_mappings_detail' },
        { key: 'image-cache', titleKey: 'settings_row_image_cache_title', detailKey: 'settings_row_image_cache_detail' },
        { key: 'cache-limit', titleKey: 'settings_row_cache_limit_title', detailKey: 'settings_row_cache_limit_detail' },
        { key: 'cache-auto-clean', titleKey: 'settings_row_cache_auto_clean_title', detailKey: 'settings_row_cache_auto_clean_detail' },
      ],
    },
    {
      key: 'about',
      titleKey: 'settings_section_about',
      rows: [
        { key: 'about', titleKey: 'settings_row_about_title', detailKey: 'settings_row_about_detail' },
        { key: 'privacy-permissions', titleKey: 'settings_row_privacy_permissions_title', detailKey: 'settings_row_privacy_permissions_detail' },
        { key: 'version', titleKey: 'settings_row_version_title', detailKey: 'settings_row_version_detail' },
        { key: 'open-source', titleKey: 'settings_row_open_source_title', detailKey: 'settings_row_open_source_detail' },
      ],
    },
  ]
}

function createSettingsRootSections(): SettingsPaneSection[] {
  return [
    {
      key: 'primary',
      titleKey: '',
      items: [
        {
          key: 'appearance',
          titleKey: 'settings_pane_appearance_title',
          detailKey: 'settings_pane_appearance_detail',
          icon: $r('sys.symbol.gearshape'),
          color: ThemeConstants.STATUS_INFO,
        },
        {
          key: 'library',
          titleKey: 'settings_pane_library_title',
          detailKey: 'settings_pane_library_detail',
          icon: $r('sys.symbol.square_fill_grid_2x2'),
          color: ThemeConstants.SOURCE_LOCAL_COLOR,
        },
        {
          key: 'reader',
          titleKey: 'settings_pane_reader_title',
          detailKey: 'settings_pane_reader_detail',
          icon: $r('sys.symbol.clock'),
          color: ThemeConstants.STATUS_SUCCESS,
        },
        {
          key: 'services',
          titleKey: 'settings_pane_services_title',
          detailKey: 'settings_pane_services_detail',
          icon: $r('sys.symbol.compass'),
          color: ThemeConstants.SOURCE_KOMGA_COLOR,
        },
      ],
    },
    {
      key: 'management',
      titleKey: '',
      items: [
        {
          key: 'downloads',
          titleKey: 'settings_pane_downloads_title',
          detailKey: 'settings_pane_downloads_detail',
          icon: $r('sys.symbol.clock'),
          color: ThemeConstants.STATUS_INFO,
        },
        {
          key: 'tracking',
          titleKey: 'settings_pane_tracking_title',
          detailKey: 'settings_pane_tracking_detail',
          icon: $r('sys.symbol.magnifyingglass'),
          color: ThemeConstants.STATUS_WARNING,
        },
        {
          key: 'backup',
          titleKey: 'settings_pane_backup_title',
          detailKey: 'settings_pane_backup_detail',
          icon: $r('sys.symbol.gearshape'),
          color: ThemeConstants.SOURCE_WEBDAV_COLOR,
        },
        {
          key: 'storage',
          titleKey: 'settings_pane_storage_title',
          detailKey: 'settings_pane_storage_detail',
          icon: $r('sys.symbol.square_fill_grid_2x2'),
          color: ThemeConstants.STATUS_MUTED,
        },
        {
          key: 'about',
          titleKey: 'settings_pane_about_title',
          detailKey: 'settings_pane_about_detail',
          icon: $r('sys.symbol.gearshape'),
          color: ThemeConstants.STATUS_MUTED,
        },
      ],
    },
  ]
}

function safeSettingsErrorCode(error: Error): string {
  return normalizeLibraryUpdateFailureCode(error.name) ?? 'unknown'
}

export function settingsPaneTitle(pane: SettingsPaneKey): string {
  if (pane === 'appearance') {
    return s('settings_pane_appearance_title')
  }
  if (pane === 'library') {
    return s('settings_pane_library_title')
  }
  if (pane === 'reader') {
    return s('settings_pane_reader_title')
  }
  if (pane === 'services') {
    return s('settings_pane_services_title')
  }
  if (pane === 'downloads') {
    return s('settings_pane_downloads_title')
  }
  if (pane === 'tracking') {
    return s('settings_pane_tracking_title')
  }
  if (pane === 'backup') {
    return s('settings_pane_backup_title')
  }
  if (pane === 'storage') {
    return s('settings_pane_storage_title')
  }
  if (pane === 'about') {
    return s('settings_pane_about_title')
  }
  return s('tab_settings')
}

@ComponentV2
export struct SettingsPage {
  @Event onOpenSettingsPane: (pane: SettingsPaneKey) => void = (_pane: SettingsPaneKey) => {}
  @Event onOpenKomgaSettings: () => void = () => {}
  @Event onOpenOpdsSettings: () => void = () => {}
  @Event onOpenWebDavSettings: () => void = () => {}
  @Event onOpenSourcePackageManager: () => void = () => {}
  @Event onOpenLibraryUpdateResults: () => void = () => {}
  @Event onOpenLibraryCategories: () => void = () => {}
  @Event onOpenDownloads: () => void = () => {}
  @Event onOpenBackupManagement: () => void = () => {}
  @Event onOpenTrackerSettings: () => void = () => {}
  @Event onOpenImportRequested: () => void = () => {}
  @Event onLibraryChanged: () => void = () => {}
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param sourceRegistry?: SourceRuntimeRegistry = undefined
  @Param pane: SettingsPaneKey = 'root'
  @Local private pageMode: ReaderPageMode = 'single_page'
  @Local private readingDirection: ReadingDirection = ReadingDirection.LEFT_TO_RIGHT
  @Local private themeMode: ReaderThemeMode = 'system'
  @Local private appearanceAccentColor: AppearanceAccentColor = DEFAULT_APPEARANCE_PREFERENCES.accentColor
  @Local private readerBackgroundMode: ReaderBackgroundMode = 'black'
  @Local private showReaderProgressControls: boolean = true
  @Local private keepReaderScreenAwake: boolean = true
  @Local private readerImageFitMode: ReaderImageFitMode = 'contain'
  @Local private readerTapNavigationEnabled: boolean = true
  @Local private readerSwipeNavigationEnabled: boolean = true
  @Local private readerTapZonePreset: ReaderTapZonePreset = 'edge'
  @Local private readerShowTapZones: boolean = false
  @Local private readerPageGapMode: ReaderPageGapMode = 'normal'
  @Local private readerTrimPageMarginsEnabled: boolean = false
  @Local private readerWideImageMode: ReaderWideImageMode = 'keep_single'
  @Local private readerVolumeKeyNavigationEnabled: boolean = false
  @Local private language: LanguageState = connectLanguageState()
  @Local private versionDetail: string = ''
  @Local private versionLoadFailed: boolean = false
  @Local private imageCacheStats?: ReaderRemoteImageCacheStats = undefined
  @Local private imageCacheState: string = 'unavailable'
  @Local private imageCacheMaxBytes: number = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.maxBytes
  @Local private imageCacheAutoCleanEnabled: boolean = DEFAULT_READER_REMOTE_IMAGE_CACHE_PREFERENCES.autoCleanEnabled
  @Local private libraryUpdateBusy: boolean = false
  @Local private libraryUpdateSummary?: LibraryUpdateSummary = undefined
  @Local private libraryUpdateJobSnapshot?: LibraryUpdateJobSnapshot = undefined
  @Local private libraryUpdatePreferences: LibraryUpdatePreferences = DEFAULT_LIBRARY_UPDATE_PREFERENCES
  @Local private libraryUpdateNotificationStatus: LibraryUpdateNotificationStatus = 'unavailable'
  @Local private localLibraryRefreshBusy: boolean = false
  @Local private localLibraryRefreshSummary?: LocalLibraryRefreshSummary = undefined
  @Local private settingsSearchText: string = ''
  @Local private settingsMenuKey: string = ''
  @Local private downloadForegroundConcurrencyLimit: number = 1
  @Local private downloadWifiOnly: boolean = false
  @Local private downloadNotificationStatus: OfflineDownloadNotificationStatus = 'unavailable'
  @Local private libraryDefaultSortBy: LibrarySortBy = 'lastRead'
  @Local private libraryViewMode: LibraryViewMode = 'grid'
  @Local private libraryListDensity: LibraryListDensity = 'standard'
  @Local private showLibraryBadges: boolean = true
  @Local private trackerAutoSyncEnabled: boolean = DEFAULT_TRACKER_PREFERENCES.autoSyncEnabled
  @Local private trackerUpdateStrategy: TrackerUpdateStrategy = DEFAULT_TRACKER_PREFERENCES.updateStrategy
  @Local private includeBackupSettings: boolean = DEFAULT_BACKUP_CONTENT_PREFERENCES.includeSettings
  @Local private includeBackupDownloadQueue: boolean = DEFAULT_BACKUP_CONTENT_PREFERENCES.includeDownloadQueue
  @Local private includeBackupTrackerMappings: boolean = DEFAULT_BACKUP_CONTENT_PREFERENCES.includeTrackerMappings

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private preferencesStore(): ReaderPreferencesStore {
    return new ReaderPreferencesStore(this.context())
  }

  private appearancePreferencesStore(): AppearancePreferencesStore {
    return new AppearancePreferencesStore(this.context())
  }

  private libraryUpdatePreferencesStore(): LibraryUpdatePreferencesStore {
    return new LibraryUpdatePreferencesStore(this.context())
  }

  private libraryUpdateResultStore(): LibraryUpdateResultStore {
    return new LibraryUpdateResultStore(this.context())
  }

  private offlineDownloadQueueStore(): OfflineDownloadQueueStore {
    return new OfflineDownloadQueueStore(this.context().filesDir)
  }

  private libraryFilterStore(): LibraryFilterStore {
    return new LibraryFilterStore(this.context())
  }

  private backupService(): BackupService {
    return new BackupService(this.context())
  }

  private trackerPreferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context())
  }

  private t(name: string): string {
    const token = `${this.language.mode}:${this.language.effectiveLocale}`
    if (token === '__koma_missing_locale__') {
      return name
    }
    return AppStrings.get(name)
  }

  private rowTitle(row: SettingsRow): string {
    return this.t(row.titleKey)
  }

  private rowBaseDetail(row: SettingsRow): string {
    return this.t(row.detailKey)
  }

  private librarySortLabel(sortBy: LibrarySortBy): string {
    if (sortBy === 'added') {
      return this.t('library_sort_added')
    }
    if (sortBy === 'title') {
      return this.t('library_sort_title')
    }
    if (sortBy === 'source') {
      return this.t('library_sort_source')
    }
    return this.t('library_sort_last_read')
  }

  private libraryViewModeLabel(viewMode: LibraryViewMode): string {
    if (viewMode === 'list') {
      return this.t('library_view_mode_list')
    }
    return this.t('library_view_mode_grid')
  }

  private libraryListDensityLabel(listDensity: LibraryListDensity): string {
    if (listDensity === 'compact') {
      return this.t('library_list_density_compact')
    }
    if (listDensity === 'comfortable') {
      return this.t('library_list_density_comfortable')
    }
    return this.t('common_standard')
  }

  private appearanceAccentColorLabel(accentColor: AppearanceAccentColor): string {
    return getAppearanceAccentColorLabel(accentColor)
  }

  private sectionTitle(section: SettingsSection): string {
    return this.t(section.titleKey)
  }

  private paneItemTitle(item: SettingsPaneItem): string {
    return this.t(item.titleKey)
  }

  private paneItemDetail(item: SettingsPaneItem): string {
    return this.t(item.detailKey)
  }

  private rowDetail(row: SettingsRow): string {
    if (row.key === 'page-mode') {
      return getReaderPageModeLabel(this.pageMode)
    }
    if (row.key === 'reading-direction') {
      return getReadingDirectionLabel(this.readingDirection)
    }
    if (row.key === 'theme') {
      return getReaderThemeModeLabel(this.themeMode)
    }
    if (row.key === 'theme-color') {
      return this.appearanceAccentColorLabel(this.appearanceAccentColor)
    }
    if (row.key === 'language') {
      return LanguageSettings.label(this.language.mode)
    }
    if (row.key === 'reader-background') {
      return getReaderBackgroundModeLabel(this.readerBackgroundMode)
    }
    if (row.key === 'reader-progress') {
      return getReaderProgressControlsLabel(this.showReaderProgressControls)
    }
    if (row.key === 'reader-keep-screen-awake') {
      return getReaderKeepScreenAwakeLabel(this.keepReaderScreenAwake)
    }
    if (row.key === 'reader-image-fit') {
      return getReaderImageFitModeLabel(this.readerImageFitMode)
    }
    if (row.key === 'reader-tap-navigation') {
      return getReaderTapNavigationLabel(this.readerTapNavigationEnabled)
    }
    if (row.key === 'reader-swipe-navigation') {
      return getReaderSwipeNavigationLabel(this.readerSwipeNavigationEnabled)
    }
    if (row.key === 'reader-tap-zone-preset') {
      return getReaderTapZonePresetLabel(this.readerTapZonePreset)
    }
    if (row.key === 'reader-show-tap-zones') {
      return getReaderShowTapZonesLabel(this.readerShowTapZones)
    }
    if (row.key === 'reader-page-gap') {
      return getReaderPageGapModeLabel(this.readerPageGapMode)
    }
    if (row.key === 'reader-trim-page-margins') {
      return getReaderTrimPageMarginsLabel(this.readerTrimPageMarginsEnabled)
    }
    if (row.key === 'reader-wide-image-mode') {
      return getReaderWideImageModeLabel(this.readerWideImageMode)
    }
    if (row.key === 'reader-volume-key-navigation') {
      return getReaderVolumeKeyNavigationLabel(this.readerVolumeKeyNavigationEnabled)
    }
    if (row.key === 'download-concurrency') {
      return `${this.downloadForegroundConcurrencyLimit}`
    }
    if (row.key === 'download-wifi-only') {
      return this.downloadWifiOnly ? this.t('common_on') : this.t('common_off')
    }
    if (row.key === 'download-notifications') {
      return getOfflineDownloadNotificationStatusLabel(this.downloadNotificationStatus)
    }
    if (row.key === 'version') {
      return this.versionDetail.length > 0
        ? this.versionDetail
        : (this.versionLoadFailed ? this.t('settings_version_dev') : '')
    }
    if (row.key === 'sources') {
      const count = listInstalled().length
      return count > 0 ? this.t('settings_sources_installed_count').replace('%s', `${count}`) : this.t('settings_sources_none')
    }
    if (row.key === 'image-cache') {
      return this.imageCacheDetailText()
    }
    if (row.key === 'cache-limit') {
      return formatReaderRemoteImageCacheSize(this.imageCacheMaxBytes)
    }
    if (row.key === 'cache-auto-clean') {
      return this.imageCacheAutoCleanEnabled ? this.t('common_on') : this.t('common_off')
    }
    if (row.key === 'library-auto-update') {
      return getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)
    }
    if (row.key === 'library-update-interval') {
      if (!this.libraryUpdatePreferences.autoCheckEnabled) {
        return this.t('settings_library_update_enable_first')
      }
      return `${getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update-notifications') {
      return getLibraryUpdateNotificationStatusLabel(this.libraryUpdateNotificationStatus)
    }
    if (row.key === 'library-update') {
      if (this.libraryUpdateBusy) {
        return this.t('common_checking')
      }
      const effectiveSummary = this.getEffectiveLibraryUpdateSummary()
      const summaryText = formatLibraryUpdateSummary(effectiveSummary)
      const checkedAt = effectiveSummary?.checkedAt
      if (checkedAt === undefined) {
        const storedSummary = formatLibraryUpdateStoredSummary(this.libraryUpdatePreferences)
        const storedCheckedAt = this.libraryUpdatePreferences.lastCheckedAt
        if (storedSummary !== undefined && storedCheckedAt !== undefined) {
          return `${getLibraryUpdateLastResultLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
        }
        if (this.libraryUpdatePreferences.lastFailureCode !== undefined && storedCheckedAt !== undefined) {
          return `${getLibraryUpdateLastResultLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
        }
        return `${summaryText} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
      }
      return `${summaryText} · ${this.t('common_last_checked')} ${this.formatTimestamp(checkedAt)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update-results') {
      return this.getEffectiveLibraryUpdateSummary() === undefined ? this.t('library_update_no_result') : this.t('settings_library_update_results_view')
    }
    if (row.key === 'library-categories') {
      const count = this.libraryStore === undefined ? 0 : this.libraryStore.listCustomCategories().length
      return count > 0 ? this.t('settings_library_categories_count').replace('%s', `${count}`) : this.t('settings_row_library_categories_detail')
    }
    if (row.key === 'library-default-sort') {
      return this.librarySortLabel(this.libraryDefaultSortBy)
    }
    if (row.key === 'library-view-mode') {
      return this.libraryViewModeLabel(this.libraryViewMode)
    }
    if (row.key === 'list-density') {
      return this.libraryListDensityLabel(this.libraryListDensity)
    }
    if (row.key === 'local-library-refresh') {
      if (this.localLibraryRefreshBusy) {
        return this.t('common_checking')
      }
      return formatLocalLibraryRefreshSummary(this.localLibraryRefreshSummary)
    }
    if (row.key === 'tracker-auto-sync') {
      return this.trackerAutoSyncEnabled ? this.t('common_on') : this.t('common_off')
    }
    if (row.key === 'tracker-update-strategy') {
      return getTrackerUpdateStrategyLabel(this.trackerUpdateStrategy)
    }
    return this.rowBaseDetail(row)
  }

  private rowDetailMaxLines(row: SettingsRow): number {
    if (row.key === 'library-update' ||
      row.key === 'library-update-interval' ||
      row.key === 'local-library-refresh') {
      return 2
    }
    return 1
  }

  private paneSections(): SettingsSection[] {
    return this.paneSectionsFor(this.pane)
  }

  private paneSectionsFor(pane: SettingsPaneKey): SettingsSection[] {
    if (pane === 'appearance') {
      return this.sectionsByKeys(['appearance'])
    }
    if (pane === 'library') {
      return [
        {
          key: 'library-organization',
          titleKey: 'settings_section_library_organization',
          rows: this.rowsByKeys([
            'library-categories',
            'library-view-mode',
            'list-density',
            'library-default-sort',
            'library-badges',
          ]),
        },
        {
          key: 'library-updates',
          titleKey: 'settings_section_library_updates',
          rows: this.rowsByKeys([
            'library-auto-update',
            'library-update-interval',
            'library-update-notifications',
            'library-update',
            'library-update-results',
            'local-library-refresh',
          ]),
        },
      ]
    }
    if (pane === 'reader') {
      return this.sectionsByKeys(['reader'])
    }
    if (pane === 'services') {
      return [
        {
          key: 'private-libraries',
          titleKey: 'settings_section_private_libraries',
          rows: this.rowsByKeys(['komga', 'opds', 'webdav']),
        },
        {
          key: 'source-runtime',
          titleKey: 'settings_section_source_runtime',
          rows: this.rowsByKeys(['sources']),
        },
      ]
    }
    if (pane === 'downloads') {
      return [
        {
          key: 'downloads',
          titleKey: 'settings_section_downloads',
          rows: this.rowsByKeys([
            'downloads',
            'download-notifications',
            'download-notification-test',
            'download-concurrency',
            'download-retry-failed',
            'download-wifi-only',
          ]),
        },
      ]
    }
    if (pane === 'tracking') {
      return [
        {
          key: 'tracking',
          titleKey: 'settings_section_tracking',
          rows: this.rowsByKeys([
            'trackers',
            'tracker-auto-sync',
            'tracker-update-strategy',
          ]),
        },
      ]
    }
    if (pane === 'backup') {
      return [
        {
          key: 'backup',
          titleKey: 'settings_section_backup',
          rows: this.rowsByKeys([
            'backup',
            'backup-auto-export',
            'backup-include-settings',
            'backup-include-download-queue',
          ]),
        },
      ]
    }
    if (pane === 'storage') {
      return [
        {
          key: 'storage',
          titleKey: 'settings_section_storage',
          rows: this.rowsByKeys([
            'image-cache',
            'cache-limit',
            'cache-auto-clean',
          ]),
        },
      ]
    }
    if (pane === 'about') {
      return this.sectionsByKeys(['about'])
    }
    return []
  }

  private searchablePanes(): SettingsPaneKey[] {
    return ['appearance', 'library', 'reader', 'services', 'downloads', 'tracking', 'backup', 'storage', 'about']
  }

  private normalizedSettingsSearchText(): string {
    return this.settingsSearchText.trim().toLowerCase()
  }

  private isSettingsSearchActive(): boolean {
    return this.pane === 'root' && this.normalizedSettingsSearchText().length > 0
  }

  private settingsSearchResults(): SettingsSearchResult[] {
    const query = this.normalizedSettingsSearchText()
    if (query.length === 0) {
      return []
    }
    const results: SettingsSearchResult[] = []
    this.searchablePanes().forEach((pane: SettingsPaneKey) => {
      const paneTitle = this.paneTitle(pane)
      this.paneSectionsFor(pane).forEach((section: SettingsSection) => {
        section.rows.forEach((row: SettingsRow) => {
          const currentDetail = this.rowDetail(row)
          const haystack =
            `${paneTitle} ${this.sectionTitle(section)} ${this.rowTitle(row)} ${this.rowBaseDetail(row)} ${currentDetail}`.toLowerCase()
          if (haystack.includes(query)) {
            results.push({
              key: `${pane}:${section.key}:${row.key}`,
              pane,
              sectionTitle: this.sectionTitle(section),
              row,
            })
          }
        })
      })
    })
    return results
  }

  private paneTitle(pane: SettingsPaneKey): string {
    if (pane === 'appearance') {
      return this.t('settings_pane_appearance_title')
    }
    if (pane === 'library') {
      return this.t('settings_pane_library_title')
    }
    if (pane === 'reader') {
      return this.t('settings_pane_reader_title')
    }
    if (pane === 'services') {
      return this.t('settings_pane_services_title')
    }
    if (pane === 'downloads') {
      return this.t('settings_pane_downloads_title')
    }
    if (pane === 'tracking') {
      return this.t('settings_pane_tracking_title')
    }
    if (pane === 'backup') {
      return this.t('settings_pane_backup_title')
    }
    if (pane === 'storage') {
      return this.t('settings_pane_storage_title')
    }
    if (pane === 'about') {
      return this.t('settings_pane_about_title')
    }
    return this.t('tab_settings')
  }

  private searchResultSubtitle(result: SettingsSearchResult): string {
    const detail = this.rowDetail(result.row)
    const path = `${this.paneTitle(result.pane)} / ${result.sectionTitle}`
    return detail.length > 0 ? `${path} · ${detail}` : path
  }

  private sectionsByKeys(keys: string[]): SettingsSection[] {
    return createSettingsSections().filter((section: SettingsSection): boolean => keys.includes(section.key))
  }

  private rowsByKeys(keys: string[]): SettingsRow[] {
    const rows: SettingsRow[] = []
    createSettingsSections().forEach((section: SettingsSection) => {
      section.rows.forEach((row: SettingsRow) => {
        if (keys.includes(row.key)) {
          rows.push(row)
        }
      })
    })
    return rows
  }

  private formatTimestamp(value: number): string {
    return formatLibraryUpdateTimestamp(value)
  }

  private getEffectiveLibraryUpdateSummary(): LibraryUpdateSummary | undefined {
    if (this.isLibraryUpdateSummaryStaleAfterFailure(this.libraryUpdateSummary) ||
      this.isLibraryUpdateSummaryBlockedByJob(this.libraryUpdateSummary, this.libraryUpdateJobSnapshot)) {
      return undefined
    }
    return this.libraryUpdateSummary
  }

  private isFailureLibraryUpdateJobSnapshot(snapshot: LibraryUpdateJobSnapshot | undefined): boolean {
    return snapshot !== undefined && (snapshot.state === 'failed' || snapshot.state === 'backed-off')
  }

  private isLibraryUpdateSummaryBlockedByJob(
    summary: LibraryUpdateSummary | undefined,
    snapshot: LibraryUpdateJobSnapshot | undefined,
  ): boolean {
    if (!this.isFailureLibraryUpdateJobSnapshot(snapshot)) {
      return false
    }
    if (summary === undefined) {
      return true
    }
    return (snapshot as LibraryUpdateJobSnapshot).updatedAt >= summary.checkedAt
  }

  private effectiveLibraryUpdateSummary(
    summary: LibraryUpdateSummary | undefined,
    snapshot: LibraryUpdateJobSnapshot | undefined,
  ): LibraryUpdateSummary | undefined {
    if (this.isLibraryUpdateSummaryStaleAfterFailure(summary) ||
      this.isLibraryUpdateSummaryBlockedByJob(summary, snapshot)) {
      return undefined
    }
    return summary
  }

  private isLibraryUpdateSummaryStaleAfterFailure(summary: LibraryUpdateSummary | undefined): boolean {
    if (summary === undefined ||
      this.libraryUpdatePreferences.lastCheckedAt === undefined ||
      this.libraryUpdatePreferences.lastFailureCode === undefined ||
      normalizeLibraryUpdateFailureCount(this.libraryUpdatePreferences.failureCount) <= 0) {
      return false
    }
    return this.libraryUpdatePreferences.lastCheckedAt >= summary.checkedAt
  }

  private clearStaleLibraryUpdateSummaryAfterFailure(): void {
    if (this.effectiveLibraryUpdateSummary(this.libraryUpdateSummary, this.libraryUpdateJobSnapshot) === undefined) {
      this.libraryUpdateSummary = undefined
    }
  }

  private loadPreferences(): void {
    void this.preferencesStore().load()
      .then((preferences: ReaderPreferences) => {
        this.applyReaderPreferences(preferences)
        console.info('[Settings] step=load_preferences')
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadAppearancePreferences(): void {
    void this.appearancePreferencesStore().load()
      .then((preferences: AppearancePreferences) => {
        this.appearanceAccentColor = preferences.accentColor
        console.info('[Settings] step=load_appearance_preferences accent=' + preferences.accentColor)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_appearance_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private applyReaderPreferences(preferences: ReaderPreferences): void {
    this.pageMode = preferences.pageMode
    this.readingDirection = preferences.readingDirection
    this.themeMode = preferences.themeMode
    this.readerBackgroundMode = preferences.backgroundMode
    this.showReaderProgressControls = preferences.showProgressControls
    this.keepReaderScreenAwake = preferences.keepScreenAwake
    this.readerImageFitMode = preferences.imageFitMode
    this.readerTapNavigationEnabled = preferences.tapNavigationEnabled
    this.readerSwipeNavigationEnabled = preferences.swipeNavigationEnabled
    this.readerTapZonePreset = preferences.tapZonePreset
    this.readerShowTapZones = preferences.showTapZones
    this.readerPageGapMode = preferences.pageGapMode
    this.readerTrimPageMarginsEnabled = preferences.trimPageMarginsEnabled
    this.readerWideImageMode = preferences.wideImageMode
    this.readerVolumeKeyNavigationEnabled = preferences.volumeKeyNavigationEnabled
  }

  private loadLibraryUpdatePreferences(): void {
    void this.libraryUpdatePreferencesStore().load()
      .then((preferences: LibraryUpdatePreferences) => {
        this.libraryUpdatePreferences = preferences
        this.clearStaleLibraryUpdateSummaryAfterFailure()
        console.info('[Settings] step=load_library_update_preferences auto=' + preferences.autoCheckEnabled + ' intervalHours=' + preferences.intervalHours)
        this.runDueLibraryUpdateCheck()
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_library_update_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadLibraryUpdateNotificationStatus(): void {
    void getLibraryUpdateNotificationStatus()
      .then((status: LibraryUpdateNotificationStatus) => {
        this.libraryUpdateNotificationStatus = status
        console.info('[Settings] step=load_library_update_notification_status status=' + status)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_library_update_notification_status_failed code=' + safeSettingsErrorCode(error))
        this.libraryUpdateNotificationStatus = 'unavailable'
      })
  }

  private loadDownloadQueuePreferences(): void {
    try {
      const preferences = this.offlineDownloadQueueStore().loadPreferences()
      this.downloadForegroundConcurrencyLimit = preferences.foregroundConcurrencyLimit
      this.downloadWifiOnly = preferences.wifiOnly
    } catch (error) {
      console.warn('[Settings] step=load_download_queue_preferences_failed code=' + safeSettingsErrorCode(error as Error))
    }
  }

  private loadDownloadNotificationStatus(): void {
    void getOfflineDownloadNotificationStatus()
      .then((status: OfflineDownloadNotificationStatus) => {
        this.downloadNotificationStatus = status
        console.info('[Settings] step=load_download_notification_status status=' + status)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_download_notification_status_failed code=' + safeSettingsErrorCode(error))
        this.downloadNotificationStatus = 'unavailable'
      })
  }

  private loadLibraryFilterPreferences(): void {
    void this.libraryFilterStore().load()
      .then((preferences: LibraryFilterPreferences) => {
        this.libraryDefaultSortBy = preferences.sortBy
        this.libraryViewMode = preferences.viewMode
        this.libraryListDensity = preferences.listDensity
        this.showLibraryBadges = preferences.showBadges
        console.info('[Settings] step=load_library_filter_preferences sortBy=' + preferences.sortBy + ' viewMode=' + preferences.viewMode + ' listDensity=' + preferences.listDensity + ' showBadges=' + preferences.showBadges)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_library_filter_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadBackupContentPreferences(): void {
    void this.backupService().loadContentPreferences()
      .then((preferences: BackupContentPreferences) => {
        this.includeBackupSettings = preferences.includeSettings
        this.includeBackupDownloadQueue = preferences.includeDownloadQueue
        this.includeBackupTrackerMappings = preferences.includeTrackerMappings
        console.info('[Settings] step=load_backup_content_preferences includeSettings=' + preferences.includeSettings + ' includeDownloadQueue=' + preferences.includeDownloadQueue + ' includeTrackerMappings=' + preferences.includeTrackerMappings)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_backup_content_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadTrackerPreferences(): void {
    void this.trackerPreferencesStore().load()
      .then((preferences: TrackerPreferences) => {
        this.trackerAutoSyncEnabled = preferences.autoSyncEnabled
        this.trackerUpdateStrategy = preferences.updateStrategy
        console.info('[Settings] step=load_tracker_preferences autoSync=' + preferences.autoSyncEnabled + ' strategy=' + preferences.updateStrategy)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_tracker_preferences_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadLatestLibraryUpdateSummary(): void {
    const latestJob = getLatestLibraryUpdateJobSnapshot()
    this.libraryUpdateJobSnapshot = latestJob
    const latest = getLatestLibraryUpdateSummary()
    this.libraryUpdateSummary = this.effectiveLibraryUpdateSummary(latest, latestJob)
    void this.libraryUpdateResultStore().loadJobSnapshot()
      .then((snapshot: LibraryUpdateJobSnapshot | undefined) => {
        const currentJob = getLatestLibraryUpdateJobSnapshot()
        let effectiveJob = currentJob
        if (snapshot !== undefined && (currentJob === undefined || snapshot.updatedAt > currentJob.updatedAt)) {
          setLatestLibraryUpdateJobSnapshot(snapshot)
          effectiveJob = snapshot
        }
        this.libraryUpdateJobSnapshot = effectiveJob
        if (this.isLibraryUpdateSummaryBlockedByJob(this.libraryUpdateSummary, effectiveJob)) {
          clearLatestLibraryUpdateSummary()
          this.libraryUpdateSummary = undefined
        }
        this.loadPersistedLibraryUpdateSummary(effectiveJob)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_library_update_job_failed code=' + safeSettingsErrorCode(error))
        this.loadPersistedLibraryUpdateSummary(latestJob)
      })
  }

  private loadPersistedLibraryUpdateSummary(jobSnapshot: LibraryUpdateJobSnapshot | undefined): void {
    void this.libraryUpdateResultStore().load()
      .then((summary: LibraryUpdateSummary | undefined) => {
        const current = getLatestLibraryUpdateSummary()
        let effectiveSummary = current
        if (summary !== undefined && (current === undefined || summary.checkedAt > current.checkedAt)) {
          setLatestLibraryUpdateSummary(summary)
          effectiveSummary = summary
        }
        this.libraryUpdateSummary = this.effectiveLibraryUpdateSummary(effectiveSummary, jobSnapshot)
        const total = this.libraryUpdateSummary === undefined ? 0 : this.libraryUpdateSummary.totalCount
        console.info('[Settings] step=load_library_update_results hasSummary=' + (this.libraryUpdateSummary !== undefined) + ' total=' + total)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_library_update_results_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private runDueLibraryUpdateCheck(): void {
    if (!isLibraryUpdateDue(this.libraryUpdatePreferences, Date.now())) {
      return
    }
    console.info('[Settings] step=library_update_due_check intervalHours=' + this.libraryUpdatePreferences.intervalHours)
    const dueAt = Date.now()
    const dueSnapshot = createLibraryUpdateJobSnapshot('due', dueAt)
    setLatestLibraryUpdateJobSnapshot(dueSnapshot)
    void this.libraryUpdateResultStore().saveJobSnapshot(dueSnapshot)
      .then(() => {
        console.info('[Settings] step=save_library_update_job_due')
        this.checkLibraryUpdates('due')
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_update_job_due_failed code=' + safeSettingsErrorCode(error))
        this.checkLibraryUpdates('due')
      })
  }

  private loadVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      this.versionDetail = `${info.versionName} (${info.versionCode})`
      this.versionLoadFailed = false
    } catch (error) {
      console.warn('[Settings] step=version_failed code=' + safeSettingsErrorCode(error as Error))
      this.versionDetail = ''
      this.versionLoadFailed = true
    }
  }

  private ensureReaderRemoteImageCache(): boolean {
    try {
      const context = this.context()
      if (context.cacheDir === undefined || context.cacheDir.length === 0) {
        return false
      }
      configureReaderRemoteImageCache(context.cacheDir, this.imageCacheMaxBytes, this.imageCacheAutoCleanEnabled)
      return true
    } catch (error) {
      console.warn('[Settings] step=image_cache_configure_failed code=' + safeSettingsErrorCode(error as Error))
      return false
    }
  }

  private updateImageCacheDetail(stats: ReaderRemoteImageCacheStats): void {
    this.imageCacheStats = stats
    this.imageCacheState = 'ready'
  }

  private imageCacheDetailText(): string {
    if (this.imageCacheState === 'load_failed') {
      return s('common_load_failed')
    }
    if (this.imageCacheState === 'unavailable') {
      return s('common_unavailable')
    }
    const stats = this.imageCacheStats
    if (stats === undefined) {
      return s('common_unavailable')
    }
    return `${formatReaderRemoteImageCacheSize(stats.totalBytes)} · ${stats.entryCount} ${s('common_items_unit')}`
  }

  private loadImageCacheStats(): void {
    if (!this.ensureReaderRemoteImageCache()) {
      this.imageCacheStats = undefined
      this.imageCacheState = 'unavailable'
      return
    }
    void getReaderRemoteImageCacheStats()
      .then((stats: ReaderRemoteImageCacheStats) => {
        this.updateImageCacheDetail(stats)
        console.info('[Settings] step=image_cache_stats totalBytes=' + stats.totalBytes + ' entryCount=' + stats.entryCount)
      })
      .catch((error: Error) => {
        this.imageCacheStats = undefined
        this.imageCacheState = 'load_failed'
        console.warn('[Settings] step=image_cache_stats_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private loadImageCachePreferences(): void {
    void new ReaderRemoteImageCachePreferencesStore(this.context()).load()
      .then((preferences: ReaderRemoteImageCachePreferences) => {
        this.imageCacheMaxBytes = preferences.maxBytes
        this.imageCacheAutoCleanEnabled = preferences.autoCleanEnabled
        console.info('[Settings] step=load_image_cache_preferences maxBytes=' + preferences.maxBytes)
        this.loadImageCacheStats()
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_image_cache_preferences_failed code=' + safeSettingsErrorCode(error))
        this.loadImageCacheStats()
      })
  }

  private savePageMode(pageMode: ReaderPageMode): void {
    this.pageMode = pageMode
    void this.preferencesStore().savePageMode(pageMode)
      .then(() => {
        console.info('[Settings] step=save_page_mode value=' + pageMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_page_mode_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReadingDirection(readingDirection: ReadingDirection): void {
    this.readingDirection = readingDirection
    void this.preferencesStore().saveReadingDirection(readingDirection)
      .then(() => {
        console.info('[Settings] step=save_reading_direction value=' + readingDirection)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reading_direction_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveThemeMode(themeMode: ReaderThemeMode): void {
    this.themeMode = themeMode
    try {
      applyReaderThemeMode(this.context(), themeMode)
    } catch (error) {
      console.warn('[Settings] step=apply_theme_failed code=' + safeSettingsErrorCode(error as Error))
    }
    void this.preferencesStore().saveThemeMode(themeMode)
      .then(() => {
        console.info('[Settings] step=save_theme value=' + themeMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_theme_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveAppearanceAccentColor(accentColor: AppearanceAccentColor): void {
    this.appearanceAccentColor = accentColor
    void this.appearancePreferencesStore().saveAccentColor(accentColor)
      .then((preferences: AppearancePreferences) => {
        this.appearanceAccentColor = preferences.accentColor
        console.info('[Settings] step=save_appearance_accent value=' + preferences.accentColor)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_appearance_accent_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_theme_color_save_failed'))
        this.loadAppearancePreferences()
      })
  }

  private saveLanguageMode(mode: string): void {
    void LanguageSettings.setMode(this.context(), mode)
      .then(() => {
        console.info('[Settings] step=save_language value=' + mode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_language_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_language_save_failed'))
      })
  }

  private saveReaderBackgroundMode(backgroundMode: ReaderBackgroundMode): void {
    this.readerBackgroundMode = backgroundMode
    void this.preferencesStore().saveBackgroundMode(backgroundMode)
      .then(() => {
        console.info('[Settings] step=save_reader_background value=' + backgroundMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_background_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderProgressControls(showProgressControls: boolean): void {
    this.showReaderProgressControls = showProgressControls
    void this.preferencesStore().saveShowProgressControls(showProgressControls)
      .then(() => {
        console.info('[Settings] step=save_reader_progress value=' + showProgressControls)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_progress_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderKeepScreenAwake(keepScreenAwake: boolean): void {
    this.keepReaderScreenAwake = keepScreenAwake
    void this.preferencesStore().saveKeepScreenAwake(keepScreenAwake)
      .then(() => {
        console.info('[Settings] step=save_reader_keep_screen_awake value=' + keepScreenAwake)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_keep_screen_awake_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderImageFitMode(imageFitMode: ReaderImageFitMode): void {
    this.readerImageFitMode = imageFitMode
    void this.preferencesStore().saveImageFitMode(imageFitMode)
      .then(() => {
        console.info('[Settings] step=save_reader_image_fit value=' + imageFitMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_image_fit_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderTapNavigationEnabled(tapNavigationEnabled: boolean): void {
    this.readerTapNavigationEnabled = tapNavigationEnabled
    void this.preferencesStore().saveTapNavigationEnabled(tapNavigationEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_tap_navigation value=' + tapNavigationEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_tap_navigation_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderSwipeNavigationEnabled(swipeNavigationEnabled: boolean): void {
    this.readerSwipeNavigationEnabled = swipeNavigationEnabled
    void this.preferencesStore().saveSwipeNavigationEnabled(swipeNavigationEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_swipe_navigation value=' + swipeNavigationEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_swipe_navigation_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderTapZonePreset(tapZonePreset: ReaderTapZonePreset): void {
    this.readerTapZonePreset = tapZonePreset
    void this.preferencesStore().saveTapZonePreset(tapZonePreset)
      .then(() => {
        console.info('[Settings] step=save_reader_tap_zone_preset value=' + tapZonePreset)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_tap_zone_preset_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderShowTapZones(showTapZones: boolean): void {
    this.readerShowTapZones = showTapZones
    void this.preferencesStore().saveShowTapZones(showTapZones)
      .then(() => {
        console.info('[Settings] step=save_reader_show_tap_zones value=' + showTapZones)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_show_tap_zones_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderPageGapMode(pageGapMode: ReaderPageGapMode): void {
    this.readerPageGapMode = pageGapMode
    void this.preferencesStore().savePageGapMode(pageGapMode)
      .then(() => {
        console.info('[Settings] step=save_reader_page_gap value=' + pageGapMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_page_gap_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderTrimPageMarginsEnabled(trimPageMarginsEnabled: boolean): void {
    this.readerTrimPageMarginsEnabled = trimPageMarginsEnabled
    void this.preferencesStore().saveTrimPageMarginsEnabled(trimPageMarginsEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_trim_page_margins value=' + trimPageMarginsEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_trim_page_margins_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderWideImageMode(wideImageMode: ReaderWideImageMode): void {
    this.readerWideImageMode = wideImageMode
    void this.preferencesStore().saveWideImageMode(wideImageMode)
      .then(() => {
        console.info('[Settings] step=save_reader_wide_image_mode value=' + wideImageMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_wide_image_mode_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private saveReaderVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled: boolean): void {
    this.readerVolumeKeyNavigationEnabled = volumeKeyNavigationEnabled
    void this.preferencesStore().saveVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_volume_key_navigation value=' + volumeKeyNavigationEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_volume_key_navigation_failed code=' + safeSettingsErrorCode(error))
      })
  }

  private resetReaderPreferences(): void {
    const defaults = DEFAULT_READER_PREFERENCES
    this.applyReaderPreferences(defaults)
    try {
      applyReaderThemeMode(this.context(), defaults.themeMode)
    } catch (error) {
      console.warn('[Settings] step=apply_reader_defaults_theme_failed code=' + safeSettingsErrorCode(error as Error))
    }
    void this.preferencesStore().save(defaults)
      .then(() => {
        console.info('[Settings] step=reset_reader_preferences')
        this.showToast(s('settings_reader_defaults_reset'))
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=reset_reader_preferences_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_reader_defaults_reset_failed'))
        this.loadPreferences()
      })
  }

  private clearImageCache(): void {
    if (!this.ensureReaderRemoteImageCache()) {
      this.showToast(s('settings_image_cache_unavailable'))
      return
    }
    console.info('[Settings] step=image_cache_clear_start')
    void clearReaderRemoteImageCache()
      .then((stats: ReaderRemoteImageCacheStats) => {
        this.updateImageCacheDetail(stats)
        console.info('[Settings] step=image_cache_clear_done totalBytes=' + stats.totalBytes + ' entryCount=' + stats.entryCount)
        this.showToast(s('settings_image_cache_cleared'))
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=image_cache_clear_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_image_cache_clear_failed'))
      })
  }

  private saveImageCacheLimit(maxBytes: number): void {
    this.imageCacheMaxBytes = maxBytes
    void new ReaderRemoteImageCachePreferencesStore(this.context()).saveMaxBytes(maxBytes)
      .then((preferences: ReaderRemoteImageCachePreferences) => {
        this.imageCacheMaxBytes = preferences.maxBytes
        this.imageCacheAutoCleanEnabled = preferences.autoCleanEnabled
        this.ensureReaderRemoteImageCache()
        this.loadImageCacheStats()
        console.info('[Settings] step=save_image_cache_limit maxBytes=' + preferences.maxBytes)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_image_cache_limit_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_cache_limit_save_failed'))
      })
  }

  private saveImageCacheAutoCleanEnabled(enabled: boolean): void {
    this.imageCacheAutoCleanEnabled = enabled
    void new ReaderRemoteImageCachePreferencesStore(this.context()).saveAutoCleanEnabled(enabled)
      .then((preferences: ReaderRemoteImageCachePreferences) => {
        this.imageCacheMaxBytes = preferences.maxBytes
        this.imageCacheAutoCleanEnabled = preferences.autoCleanEnabled
        this.ensureReaderRemoteImageCache()
        this.loadImageCacheStats()
        console.info('[Settings] step=save_image_cache_auto_clean enabled=' + preferences.autoCleanEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_image_cache_auto_clean_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_cache_auto_clean_save_failed'))
      })
  }

  private showSourcesDialog(): void {
    console.info('[Settings] step=sources_manager_open')
    this.onOpenSourcePackageManager()
  }

  private openLibraryUpdateResults(): void {
    console.info('[Settings] step=open_library_update_results')
    this.onOpenLibraryUpdateResults()
  }

  private saveLibraryUpdatePreferences(preferences: LibraryUpdatePreferences): void {
    this.libraryUpdatePreferences = preferences
  }

  private copyLibraryUpdateSummaryState(source: LibraryUpdatePreferences, target: LibraryUpdatePreferences): void {
    if (source.lastSummaryText !== undefined) {
      target.lastSummaryText = source.lastSummaryText
    }
    if (source.lastSummaryTotalCount !== undefined) {
      target.lastSummaryTotalCount = source.lastSummaryTotalCount
    }
    if (source.lastSummaryNewChapterCount !== undefined) {
      target.lastSummaryNewChapterCount = source.lastSummaryNewChapterCount
    }
    if (source.lastSummaryUpdatedCount !== undefined) {
      target.lastSummaryUpdatedCount = source.lastSummaryUpdatedCount
    }
    if (source.lastSummarySkippedCount !== undefined) {
      target.lastSummarySkippedCount = source.lastSummarySkippedCount
    }
    if (source.lastSummaryFailedCount !== undefined) {
      target.lastSummaryFailedCount = source.lastSummaryFailedCount
    }
  }

  private setLibraryAutoUpdateEnabled(autoCheckEnabled: boolean): void {
    const nextPreferences: LibraryUpdatePreferences = {
      autoCheckEnabled,
      intervalHours: this.libraryUpdatePreferences.intervalHours,
      foregroundOnly: this.libraryUpdatePreferences.foregroundOnly,
      failureCount: this.libraryUpdatePreferences.failureCount,
    }
    if (this.libraryUpdatePreferences.lastCheckedAt !== undefined) {
      nextPreferences.lastCheckedAt = this.libraryUpdatePreferences.lastCheckedAt
    }
    this.copyLibraryUpdateSummaryState(this.libraryUpdatePreferences, nextPreferences)
    if (this.libraryUpdatePreferences.lastFailureCode !== undefined) {
      nextPreferences.lastFailureCode = this.libraryUpdatePreferences.lastFailureCode
    }
    this.libraryUpdatePreferences = nextPreferences
    void this.libraryUpdatePreferencesStore().saveAutoCheckEnabled(autoCheckEnabled)
      .then((preferences: LibraryUpdatePreferences) => {
        this.saveLibraryUpdatePreferences(preferences)
        console.info('[Settings] step=save_library_auto_update value=' + preferences.autoCheckEnabled)
        if (preferences.autoCheckEnabled) {
          this.runDueLibraryUpdateCheck()
        }
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_auto_update_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_auto_update_save_failed'))
      })
  }

  private saveLibraryUpdateInterval(intervalHours: number): void {
    const nextPreferences: LibraryUpdatePreferences = {
      autoCheckEnabled: this.libraryUpdatePreferences.autoCheckEnabled,
      intervalHours,
      foregroundOnly: this.libraryUpdatePreferences.foregroundOnly,
      failureCount: this.libraryUpdatePreferences.failureCount,
    }
    if (this.libraryUpdatePreferences.lastCheckedAt !== undefined) {
      nextPreferences.lastCheckedAt = this.libraryUpdatePreferences.lastCheckedAt
    }
    this.copyLibraryUpdateSummaryState(this.libraryUpdatePreferences, nextPreferences)
    if (this.libraryUpdatePreferences.lastFailureCode !== undefined) {
      nextPreferences.lastFailureCode = this.libraryUpdatePreferences.lastFailureCode
    }
    this.libraryUpdatePreferences = nextPreferences
    void this.libraryUpdatePreferencesStore().saveIntervalHours(intervalHours)
      .then((preferences: LibraryUpdatePreferences) => {
        this.saveLibraryUpdatePreferences(preferences)
        console.info('[Settings] step=save_library_update_interval intervalHours=' + preferences.intervalHours)
        this.runDueLibraryUpdateCheck()
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_update_interval_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_update_interval_save_failed'))
      })
  }

  private saveDownloadForegroundConcurrencyLimit(limit: number): void {
    try {
      this.downloadForegroundConcurrencyLimit = this.offlineDownloadQueueStore().setForegroundConcurrencyLimit(limit).foregroundConcurrencyLimit
      console.info('[Settings] step=save_download_concurrency limit=' + this.downloadForegroundConcurrencyLimit)
    } catch (error) {
      console.warn('[Settings] step=save_download_concurrency_failed code=' + safeSettingsErrorCode(error as Error))
      this.showToast(s('settings_download_concurrency_save_failed'))
    }
  }

  private saveDownloadWifiOnly(wifiOnly: boolean): void {
    try {
      this.downloadWifiOnly = this.offlineDownloadQueueStore().setWifiOnly(wifiOnly).wifiOnly
      console.info('[Settings] step=save_download_wifi_only value=' + this.downloadWifiOnly)
    } catch (error) {
      console.warn('[Settings] step=save_download_wifi_only_failed code=' + safeSettingsErrorCode(error as Error))
      this.showToast(s('settings_download_wifi_only_save_failed'))
    }
  }

  private requestDownloadNotifications(): void {
    void requestOfflineDownloadNotificationPermission(this.context())
      .then((status: OfflineDownloadNotificationStatus) => {
        this.downloadNotificationStatus = status
        this.showToast(status === 'enabled'
          ? s('settings_download_notification_enabled')
          : s('settings_download_notification_disabled'))
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=request_download_notifications_failed code=' + safeSettingsErrorCode(error))
        this.downloadNotificationStatus = 'unavailable'
        this.showToast(s('settings_download_notification_failed'))
      })
  }

  private handleDownloadNotificationDispatch(result: OfflineDownloadNotificationDispatchResult): void {
    if (result.delivered) {
      this.downloadNotificationStatus = 'enabled'
      this.showToast(s('settings_download_notification_test_sent'))
      return
    }
    if (result.code === 'disabled') {
      this.downloadNotificationStatus = 'unavailable'
      this.showToast(s('settings_download_notification_test_disabled'))
      return
    }
    this.showToast(s('settings_download_notification_test_failed'))
    this.loadDownloadNotificationStatus()
  }

  private sendDownloadNotificationTest(): void {
    void publishOfflineDownloadNotification({
      schemaVersion: 1,
      comicId: 'koma.notification.test',
      seriesId: 'koma.notification.test',
      chapterId: 'koma.notification.test.chapter',
      pageCount: 1,
      downloadedPageCount: 1,
      status: OfflineDownloadStatus.DOWNLOADED,
      updatedAt: Date.now(),
      pages: [],
      integrityHash: 'notification-test',
    }, {
      comicTitle: s('download_notification_test_comic'),
      chapterTitle: s('download_notification_test_chapter'),
    })
      .then((result: OfflineDownloadNotificationDispatchResult) => {
        console.info('[Settings] step=download_notification_test code=' + result.code)
        this.handleDownloadNotificationDispatch(result)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=download_notification_test_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_download_notification_test_failed'))
        this.loadDownloadNotificationStatus()
      })
  }

  private saveLibraryDefaultSort(sortBy: LibrarySortBy): void {
    this.libraryDefaultSortBy = sortBy
    void this.libraryFilterStore().load()
      .then((preferences: LibraryFilterPreferences) => {
        preferences.sortBy = sortBy
        return this.libraryFilterStore().save(preferences)
      })
      .then(() => {
        console.info('[Settings] step=save_library_default_sort sortBy=' + sortBy)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_default_sort_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_default_sort_save_failed'))
      })
  }

  private saveLibraryViewMode(viewMode: LibraryViewMode): void {
    this.libraryViewMode = viewMode
    void this.libraryFilterStore().load()
      .then((preferences: LibraryFilterPreferences) => {
        preferences.viewMode = viewMode
        return this.libraryFilterStore().save(preferences)
      })
      .then(() => {
        console.info('[Settings] step=save_library_view_mode viewMode=' + viewMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_view_mode_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_view_mode_save_failed'))
      })
  }

  private saveLibraryListDensity(listDensity: LibraryListDensity): void {
    this.libraryListDensity = listDensity
    void this.libraryFilterStore().load()
      .then((preferences: LibraryFilterPreferences) => {
        preferences.listDensity = listDensity
        return this.libraryFilterStore().save(preferences)
      })
      .then(() => {
        console.info('[Settings] step=save_library_list_density listDensity=' + listDensity)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_list_density_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_list_density_save_failed'))
      })
  }

  private saveLibraryBadgesEnabled(enabled: boolean): void {
    this.showLibraryBadges = enabled
    void this.libraryFilterStore().load()
      .then((preferences: LibraryFilterPreferences) => {
        preferences.showBadges = enabled
        return this.libraryFilterStore().save(preferences)
      })
      .then(() => {
        console.info('[Settings] step=save_library_badges enabled=' + enabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_badges_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_library_badges_save_failed'))
      })
  }

  private saveTrackerAutoSyncEnabled(enabled: boolean): void {
    this.trackerAutoSyncEnabled = enabled
    void this.trackerPreferencesStore().saveSyncPreferences(enabled, this.trackerUpdateStrategy)
      .then((preferences: TrackerPreferences) => {
        this.trackerAutoSyncEnabled = preferences.autoSyncEnabled
        this.trackerUpdateStrategy = preferences.updateStrategy
        console.info('[Settings] step=save_tracker_auto_sync enabled=' + preferences.autoSyncEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_tracker_auto_sync_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_tracker_sync_save_failed'))
      })
  }

  private saveTrackerUpdateStrategy(strategy: TrackerUpdateStrategy): void {
    this.trackerUpdateStrategy = strategy
    void this.trackerPreferencesStore().saveSyncPreferences(this.trackerAutoSyncEnabled, strategy)
      .then((preferences: TrackerPreferences) => {
        this.trackerAutoSyncEnabled = preferences.autoSyncEnabled
        this.trackerUpdateStrategy = preferences.updateStrategy
        console.info('[Settings] step=save_tracker_update_strategy strategy=' + preferences.updateStrategy)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_tracker_update_strategy_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_tracker_sync_save_failed'))
      })
  }

  private saveBackupIncludeSettings(enabled: boolean): void {
    this.includeBackupSettings = enabled
    void this.backupService().saveContentPreferences({
      includeSettings: enabled,
      includeDownloadQueue: this.includeBackupDownloadQueue,
      includeTrackerMappings: this.includeBackupTrackerMappings,
    })
      .then(() => {
        console.info('[Settings] step=save_backup_include_settings enabled=' + enabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_backup_include_settings_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_backup_include_settings_save_failed'))
      })
  }

  private saveBackupIncludeDownloadQueue(enabled: boolean): void {
    this.includeBackupDownloadQueue = enabled
    void this.backupService().saveContentPreferences({
      includeSettings: this.includeBackupSettings,
      includeDownloadQueue: enabled,
      includeTrackerMappings: this.includeBackupTrackerMappings,
    })
      .then(() => {
        console.info('[Settings] step=save_backup_include_download_queue enabled=' + enabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_backup_include_download_queue_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_backup_include_download_queue_save_failed'))
      })
  }

  private saveBackupIncludeTrackerMappings(enabled: boolean): void {
    this.includeBackupTrackerMappings = enabled
    void this.backupService().saveContentPreferences({
      includeSettings: this.includeBackupSettings,
      includeDownloadQueue: this.includeBackupDownloadQueue,
      includeTrackerMappings: enabled,
    })
      .then(() => {
        console.info('[Settings] step=save_backup_include_tracker_mappings enabled=' + enabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_backup_include_tracker_mappings_failed code=' + safeSettingsErrorCode(error))
        this.showToast(s('settings_backup_include_tracker_mappings_save_failed'))
      })
  }

  private handleLibraryUpdateNotificationDispatch(result: LibraryUpdateNotificationDispatchResult, reason: string): void {
    if (result.delivered) {
      this.libraryUpdateNotificationStatus = 'enabled'
      return
    }
    if (result.code === 'disabled') {
      this.libraryUpdateNotificationStatus = 'unavailable'
      if (reason === 'manual') {
        this.showToast(s('settings_library_update_notification_disabled'))
      }
      return
    }
    if (result.code === 'publish_failed') {
      if (reason === 'manual') {
        this.showToast(s('settings_library_update_notification_failed'))
      }
      this.loadLibraryUpdateNotificationStatus()
    }
  }

  private requestLibraryUpdateNotifications(): void {
    void requestLibraryUpdateNotificationPermission(this.context())
      .then((status: LibraryUpdateNotificationStatus) => {
        this.libraryUpdateNotificationStatus = status
        this.showToast(status === 'enabled'
          ? s('settings_library_update_notification_enabled')
          : s('settings_library_update_notification_disabled'))
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=request_library_update_notifications_failed code=' + safeSettingsErrorCode(error))
        this.libraryUpdateNotificationStatus = 'unavailable'
        this.showToast(s('settings_library_update_notification_failed'))
      })
  }

  private checkLibraryUpdates(reason: string = 'manual'): void {
    if (this.libraryUpdateBusy) {
      return
    }
    if (this.libraryStore === undefined || this.sourceRegistry === undefined) {
      this.showToast(s('settings_library_update_unavailable'))
      return
    }
    this.libraryUpdateBusy = true
    const startedAt = Date.now()
    const runningSnapshot = createLibraryUpdateJobSnapshot('running', startedAt, undefined, undefined, undefined, startedAt)
    setLatestLibraryUpdateJobSnapshot(runningSnapshot)
    void this.libraryUpdateResultStore().saveJobSnapshot(runningSnapshot)
      .catch((error: Error) => {
        console.warn('[Settings] step=save_library_update_job_running_failed code=' + safeSettingsErrorCode(error))
      })
    console.info('[Settings] step=library_update_start')
    const service = new LibraryUpdateService(
      this.libraryStore,
      this.sourceRegistry,
      this.libraryPersistenceService,
      new RemoteServerStore(this.context()),
    )
    void service.checkLibraryUpdates()
      .then((summary: LibraryUpdateSummary) => {
        this.libraryUpdateSummary = summary
        setLatestLibraryUpdateSummary(summary)
        const successSnapshot = createLibraryUpdateJobSnapshot('success', summary.checkedAt, summary, undefined, undefined, startedAt)
        setLatestLibraryUpdateJobSnapshot(successSnapshot)
        void this.libraryUpdateResultStore().save(summary)
          .then(() => {
            console.info('[Settings] step=save_library_update_results total=' + summary.totalCount)
          })
          .catch((error: Error) => {
            console.warn('[Settings] step=save_library_update_results_failed code=' + safeSettingsErrorCode(error))
          })
        this.onLibraryChanged()
        console.info('[Settings] step=library_update_done trigger=' + reason + ' total=' + summary.totalCount + ' updated=' + summary.updatedCount + ' failed=' + summary.failedCount)
        void this.libraryUpdatePreferencesStore().saveLastSummary(
          summary.checkedAt,
          summary.totalCount,
          countLibraryUpdateNewChapters(summary),
          summary.updatedCount,
          summary.skippedCount,
          summary.failedCount,
        )
          .then((preferences: LibraryUpdatePreferences) => {
            this.saveLibraryUpdatePreferences(preferences)
          })
          .catch((error: Error) => {
            console.warn('[Settings] step=save_library_update_summary_failed code=' + safeSettingsErrorCode(error))
          })
        void publishLibraryUpdateNotification(summary)
          .then((result) => {
            console.info('[Settings] step=library_update_notification code=' + result.code)
            this.handleLibraryUpdateNotificationDispatch(result, reason)
          })
        if (reason === 'manual') {
          this.showToast(summary.updatedCount > 0
            ? s('settings_library_update_found_count').replace('%s', `${summary.updatedCount}`)
            : s('settings_library_update_up_to_date'))
        }
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=library_update_failed code=' + safeSettingsErrorCode(error))
        const checkedAt = Date.now()
        const failureCode = normalizeLibraryUpdateFailureCode('check_failed') ?? 'unknown'
        this.libraryUpdateSummary = undefined
        clearLatestLibraryUpdateSummary()
        this.libraryUpdatePreferences = {
          autoCheckEnabled: this.libraryUpdatePreferences.autoCheckEnabled,
          intervalHours: this.libraryUpdatePreferences.intervalHours,
          foregroundOnly: this.libraryUpdatePreferences.foregroundOnly,
          lastCheckedAt: checkedAt,
          failureCount: normalizeLibraryUpdateFailureCount(this.libraryUpdatePreferences.failureCount + 1),
          lastFailureCode: failureCode,
        }
        const nextDueAt = getLibraryUpdateNextDueAt(this.libraryUpdatePreferences)
        const failedState = nextDueAt !== undefined && nextDueAt > checkedAt ? 'backed-off' : 'failed'
        const failedSnapshot = createLibraryUpdateJobSnapshot(failedState, checkedAt, undefined, failureCode, nextDueAt, startedAt)
        setLatestLibraryUpdateJobSnapshot(failedSnapshot)
        void this.libraryUpdateResultStore().saveJobSnapshot(failedSnapshot)
          .then(() => {
            console.info('[Settings] step=save_library_update_job_failed state=' + failedState)
          })
          .catch((saveError: Error) => {
            console.warn('[Settings] step=save_library_update_job_failed_failed code=' + safeSettingsErrorCode(saveError))
          })
        void this.libraryUpdatePreferencesStore().saveFailedCheck(checkedAt, failureCode)
          .then((preferences: LibraryUpdatePreferences) => {
            this.saveLibraryUpdatePreferences(preferences)
          })
          .catch((saveError: Error) => {
            console.warn('[Settings] step=save_library_update_failure_failed code=' + safeSettingsErrorCode(saveError))
          })
        void publishLibraryUpdateFailureNotification(checkedAt, failureCode)
          .then((result) => {
            console.info('[Settings] step=library_update_notification code=' + result.code)
            this.handleLibraryUpdateNotificationDispatch(result, reason)
          })
        if (reason === 'manual') {
          this.showToast(s('settings_library_update_failed'))
        }
      })
      .finally(() => {
        this.libraryUpdateBusy = false
      })
  }

  private checkLocalLibraryRefresh(): void {
    if (this.localLibraryRefreshBusy) {
      return
    }
    if (this.libraryStore === undefined) {
      this.showToast(s('settings_local_library_refresh_unavailable'))
      return
    }
    this.localLibraryRefreshBusy = true
    console.info('[Settings] step=local_library_refresh_start')
    try {
      const summary = new LocalLibraryRefreshService(this.libraryStore).checkLocalLibraryRefresh()
      this.localLibraryRefreshSummary = summary
      console.info(
        '[Settings] step=local_library_refresh_done total=' + summary.totalCount +
          ' reselectRequired=' + summary.reselectRequiredCount
      )
      if (summary.totalCount === 0) {
        this.showToast(s('settings_local_library_refresh_none'))
      } else if (summary.reselectRequiredCount > 0) {
        this.showToast(s('settings_local_library_refresh_reselect'))
        this.onOpenImportRequested()
      } else {
        this.showToast(s('settings_local_library_refresh_clean'))
      }
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=local_library_refresh_failed code=' + safeSettingsErrorCode(e))
      this.showToast(s('settings_local_library_refresh_failed'))
    } finally {
      this.localLibraryRefreshBusy = false
    }
  }

  private showInfoDialog(title: string, message: string): void {
    void this.getUIContext().getPromptAction().showDialog({
      title,
      message,
      buttons: [
        { text: s('common_confirm'), color: $r('app.color.koma_accent') },
      ],
    })
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  private showAboutDialog(): void {
    console.info('[Settings] step=about_dialog')
    this.showInfoDialog(s('settings_about_dialog_title'), s('settings_about_dialog_message'))
  }

  private showPrivacyPermissionsDialog(): void {
    console.info('[Settings] step=privacy_permissions_dialog')
    this.showInfoDialog(s('settings_privacy_permissions_dialog_title'), s('settings_privacy_permissions_dialog_message'))
  }

  private showOpenSourceDialog(): void {
    console.info('[Settings] step=open_source_dialog')
    this.showInfoDialog(s('settings_open_source_dialog_title'), s('settings_open_source_dialog_message'))
  }

  private showVersionDialog(): void {
    console.info('[Settings] step=version_dialog')
    this.showInfoDialog(s('settings_row_version_title'), this.versionDetail)
  }

  private isSelectionRow(row: SettingsRow): boolean {
    return row.key === 'page-mode' ||
      row.key === 'reading-direction' ||
      row.key === 'theme' ||
      row.key === 'theme-color' ||
      row.key === 'language' ||
      row.key === 'reader-background' ||
      row.key === 'reader-image-fit' ||
      row.key === 'reader-tap-zone-preset' ||
      row.key === 'reader-page-gap' ||
      row.key === 'reader-wide-image-mode' ||
      row.key === 'download-concurrency' ||
      row.key === 'cache-limit' ||
      row.key === 'library-view-mode' ||
      row.key === 'list-density' ||
      row.key === 'library-default-sort' ||
      row.key === 'library-update-interval' ||
      row.key === 'tracker-update-strategy'
  }

  private isSwitchRow(row: SettingsRow): boolean {
    return row.key === 'library-auto-update' ||
      row.key === 'library-badges' ||
      row.key === 'backup-include-settings' ||
      row.key === 'backup-include-download-queue' ||
      row.key === 'backup-include-tracker-mappings' ||
      row.key === 'cache-auto-clean' ||
      row.key === 'download-wifi-only' ||
      row.key === 'tracker-auto-sync' ||
      row.key === 'reader-progress' ||
      row.key === 'reader-keep-screen-awake' ||
      row.key === 'reader-tap-navigation' ||
      row.key === 'reader-swipe-navigation' ||
      row.key === 'reader-show-tap-zones' ||
      row.key === 'reader-trim-page-margins' ||
      row.key === 'reader-volume-key-navigation'
  }

  private switchRowValue(row: SettingsRow): boolean {
    if (row.key === 'library-auto-update') {
      return this.libraryUpdatePreferences.autoCheckEnabled
    }
    if (row.key === 'library-badges') {
      return this.showLibraryBadges
    }
    if (row.key === 'backup-include-settings') {
      return this.includeBackupSettings
    }
    if (row.key === 'backup-include-download-queue') {
      return this.includeBackupDownloadQueue
    }
    if (row.key === 'backup-include-tracker-mappings') {
      return this.includeBackupTrackerMappings
    }
    if (row.key === 'cache-auto-clean') {
      return this.imageCacheAutoCleanEnabled
    }
    if (row.key === 'reader-progress') {
      return this.showReaderProgressControls
    }
    if (row.key === 'reader-keep-screen-awake') {
      return this.keepReaderScreenAwake
    }
    if (row.key === 'reader-tap-navigation') {
      return this.readerTapNavigationEnabled
    }
    if (row.key === 'reader-swipe-navigation') {
      return this.readerSwipeNavigationEnabled
    }
    if (row.key === 'reader-trim-page-margins') {
      return this.readerTrimPageMarginsEnabled
    }
    if (row.key === 'reader-show-tap-zones') {
      return this.readerShowTapZones
    }
    if (row.key === 'reader-volume-key-navigation') {
      return this.readerVolumeKeyNavigationEnabled
    }
    if (row.key === 'download-wifi-only') {
      return this.downloadWifiOnly
    }
    if (row.key === 'tracker-auto-sync') {
      return this.trackerAutoSyncEnabled
    }
    return false
  }

  private setSwitchRowValue(row: SettingsRow, value: boolean): void {
    if (row.key === 'library-auto-update') {
      this.setLibraryAutoUpdateEnabled(value)
    } else if (row.key === 'library-badges') {
      this.saveLibraryBadgesEnabled(value)
    } else if (row.key === 'backup-include-settings') {
      this.saveBackupIncludeSettings(value)
    } else if (row.key === 'backup-include-download-queue') {
      this.saveBackupIncludeDownloadQueue(value)
    } else if (row.key === 'backup-include-tracker-mappings') {
      this.saveBackupIncludeTrackerMappings(value)
    } else if (row.key === 'cache-auto-clean') {
      this.saveImageCacheAutoCleanEnabled(value)
    } else if (row.key === 'reader-progress') {
      this.saveReaderProgressControls(value)
    } else if (row.key === 'reader-keep-screen-awake') {
      this.saveReaderKeepScreenAwake(value)
    } else if (row.key === 'reader-tap-navigation') {
      this.saveReaderTapNavigationEnabled(value)
    } else if (row.key === 'reader-swipe-navigation') {
      this.saveReaderSwipeNavigationEnabled(value)
    } else if (row.key === 'reader-show-tap-zones') {
      this.saveReaderShowTapZones(value)
    } else if (row.key === 'reader-trim-page-margins') {
      this.saveReaderTrimPageMarginsEnabled(value)
    } else if (row.key === 'reader-volume-key-navigation') {
      this.saveReaderVolumeKeyNavigationEnabled(value)
    } else if (row.key === 'download-wifi-only') {
      this.saveDownloadWifiOnly(value)
    } else if (row.key === 'tracker-auto-sync') {
      this.saveTrackerAutoSyncEnabled(value)
    } else {
      this.showToast(`${this.rowTitle(row)}${s('settings_coming_soon_suffix')}`)
    }
  }

  private canOpenSelectionMenu(row: SettingsRow): boolean {
    return row.key !== 'library-update-interval' || this.libraryUpdatePreferences.autoCheckEnabled
  }

  private isPlaceholderRow(row: SettingsRow): boolean {
    return row.placeholder === true
  }

  @Builder
  private SelectionMenuItem(title: ResourceStr, checked: boolean, action: () => void) {
    MenuItem({
      content: title,
      symbolEndIcon: checked ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
    })
      .onClick(() => {
        action()
        this.settingsMenuKey = ''
      })
  }

  @Builder
  private SettingsSelectionMenu(row: SettingsRow) {
    Menu() {
      if (row.key === 'page-mode') {
        this.SelectionMenuItem(s('reader_page_mode_single'), this.pageMode === 'single_page', () => { this.savePageMode('single_page') })
        this.SelectionMenuItem(s('reader_page_mode_double'), this.pageMode === 'double_page', () => { this.savePageMode('double_page') })
        this.SelectionMenuItem(s('reader_page_mode_continuous'), this.pageMode === 'continuous_scroll', () => { this.savePageMode('continuous_scroll') })
      } else if (row.key === 'reading-direction') {
        this.SelectionMenuItem(s('reader_direction_ltr'), this.readingDirection === ReadingDirection.LEFT_TO_RIGHT, () => { this.saveReadingDirection(ReadingDirection.LEFT_TO_RIGHT) })
        this.SelectionMenuItem(s('reader_direction_rtl'), this.readingDirection === ReadingDirection.RIGHT_TO_LEFT, () => { this.saveReadingDirection(ReadingDirection.RIGHT_TO_LEFT) })
        this.SelectionMenuItem(s('reader_direction_vertical'), this.readingDirection === ReadingDirection.WEBTOON, () => { this.saveReadingDirection(ReadingDirection.WEBTOON) })
      } else if (row.key === 'theme') {
        this.SelectionMenuItem(s('theme_system'), this.themeMode === 'system', () => { this.saveThemeMode('system') })
        this.SelectionMenuItem(s('theme_light'), this.themeMode === 'light', () => { this.saveThemeMode('light') })
        this.SelectionMenuItem(s('theme_dark'), this.themeMode === 'dark', () => { this.saveThemeMode('dark') })
      } else if (row.key === 'theme-color') {
        this.SelectionMenuItem(s('appearance_accent_emerald'), this.appearanceAccentColor === 'emerald', () => { this.saveAppearanceAccentColor('emerald') })
        this.SelectionMenuItem(s('appearance_accent_ocean'), this.appearanceAccentColor === 'ocean', () => { this.saveAppearanceAccentColor('ocean') })
        this.SelectionMenuItem(s('appearance_accent_rose'), this.appearanceAccentColor === 'rose', () => { this.saveAppearanceAccentColor('rose') })
        this.SelectionMenuItem(s('appearance_accent_amber'), this.appearanceAccentColor === 'amber', () => { this.saveAppearanceAccentColor('amber') })
        this.SelectionMenuItem(s('appearance_accent_mono'), this.appearanceAccentColor === 'mono', () => { this.saveAppearanceAccentColor('mono') })
      } else if (row.key === 'language') {
        this.SelectionMenuItem(s('language_system'), this.language.mode === LanguageSettings.MODE_SYSTEM, () => { this.saveLanguageMode(LanguageSettings.MODE_SYSTEM) })
        this.SelectionMenuItem(s('language_zh_cn'), this.language.mode === LanguageSettings.MODE_ZH_CN, () => { this.saveLanguageMode(LanguageSettings.MODE_ZH_CN) })
        this.SelectionMenuItem(s('language_en_us'), this.language.mode === LanguageSettings.MODE_EN_US, () => { this.saveLanguageMode(LanguageSettings.MODE_EN_US) })
      } else if (row.key === 'reader-background') {
        this.SelectionMenuItem(s('reader_background_black'), this.readerBackgroundMode === 'black', () => { this.saveReaderBackgroundMode('black') })
        this.SelectionMenuItem(s('reader_background_paper'), this.readerBackgroundMode === 'paper', () => { this.saveReaderBackgroundMode('paper') })
        this.SelectionMenuItem(s('reader_background_light'), this.readerBackgroundMode === 'light', () => { this.saveReaderBackgroundMode('light') })
      } else if (row.key === 'reader-image-fit') {
        this.SelectionMenuItem(s('reader_image_fit_screen'), this.readerImageFitMode === 'contain', () => { this.saveReaderImageFitMode('contain') })
        this.SelectionMenuItem(s('reader_image_fit_width'), this.readerImageFitMode === 'fit_width', () => { this.saveReaderImageFitMode('fit_width') })
      } else if (row.key === 'reader-tap-zone-preset') {
        this.SelectionMenuItem(s('reader_tap_zone_edge'), this.readerTapZonePreset === 'edge', () => { this.saveReaderTapZonePreset('edge') })
        this.SelectionMenuItem(s('reader_tap_zone_wide'), this.readerTapZonePreset === 'wide_edges', () => { this.saveReaderTapZonePreset('wide_edges') })
      } else if (row.key === 'reader-page-gap') {
        this.SelectionMenuItem(s('reader_page_gap_compact'), this.readerPageGapMode === 'compact', () => { this.saveReaderPageGapMode('compact') })
        this.SelectionMenuItem(s('common_standard'), this.readerPageGapMode === 'normal', () => { this.saveReaderPageGapMode('normal') })
        this.SelectionMenuItem(s('reader_page_gap_wide'), this.readerPageGapMode === 'wide', () => { this.saveReaderPageGapMode('wide') })
      } else if (row.key === 'reader-wide-image-mode') {
        this.SelectionMenuItem(s('reader_wide_mode_keep_single'), this.readerWideImageMode === 'keep_single', () => { this.saveReaderWideImageMode('keep_single') })
        this.SelectionMenuItem(s('reader_wide_mode_split'), this.readerWideImageMode === 'split_wide_pages', () => { this.saveReaderWideImageMode('split_wide_pages') })
        this.SelectionMenuItem(s('reader_wide_mode_rotate'), this.readerWideImageMode === 'rotate_wide_pages', () => { this.saveReaderWideImageMode('rotate_wide_pages') })
      } else if (row.key === 'download-concurrency') {
        ForEach(OFFLINE_DOWNLOAD_FOREGROUND_CONCURRENCY_LIMIT_OPTIONS, (limit: number) => {
          this.SelectionMenuItem(`${limit}`, this.downloadForegroundConcurrencyLimit === limit, () => {
            this.saveDownloadForegroundConcurrencyLimit(limit)
          })
        }, (limit: number) => `${limit}`)
      } else if (row.key === 'cache-limit') {
        ForEach(READER_REMOTE_IMAGE_CACHE_MAX_BYTES_OPTIONS, (maxBytes: number) => {
          this.SelectionMenuItem(formatReaderRemoteImageCacheSize(maxBytes), this.imageCacheMaxBytes === maxBytes, () => {
            this.saveImageCacheLimit(maxBytes)
          })
        }, (maxBytes: number) => `${maxBytes}`)
      } else if (row.key === 'library-default-sort') {
        this.SelectionMenuItem(s('library_sort_last_read'), this.libraryDefaultSortBy === 'lastRead', () => { this.saveLibraryDefaultSort('lastRead') })
        this.SelectionMenuItem(s('library_sort_added'), this.libraryDefaultSortBy === 'added', () => { this.saveLibraryDefaultSort('added') })
        this.SelectionMenuItem(s('library_sort_title'), this.libraryDefaultSortBy === 'title', () => { this.saveLibraryDefaultSort('title') })
        this.SelectionMenuItem(s('library_sort_source'), this.libraryDefaultSortBy === 'source', () => { this.saveLibraryDefaultSort('source') })
      } else if (row.key === 'library-view-mode') {
        this.SelectionMenuItem(s('library_view_mode_grid'), this.libraryViewMode === 'grid', () => { this.saveLibraryViewMode('grid') })
        this.SelectionMenuItem(s('library_view_mode_list'), this.libraryViewMode === 'list', () => { this.saveLibraryViewMode('list') })
      } else if (row.key === 'list-density') {
        this.SelectionMenuItem(s('library_list_density_compact'), this.libraryListDensity === 'compact', () => { this.saveLibraryListDensity('compact') })
        this.SelectionMenuItem(s('common_standard'), this.libraryListDensity === 'standard', () => { this.saveLibraryListDensity('standard') })
        this.SelectionMenuItem(s('library_list_density_comfortable'), this.libraryListDensity === 'comfortable', () => { this.saveLibraryListDensity('comfortable') })
      } else if (row.key === 'library-update-interval') {
        this.SelectionMenuItem(s('library_update_interval_12h'), this.libraryUpdatePreferences.intervalHours === 12, () => { this.saveLibraryUpdateInterval(12) })
        this.SelectionMenuItem(s('library_update_interval_24h'), this.libraryUpdatePreferences.intervalHours === 24, () => { this.saveLibraryUpdateInterval(24) })
        this.SelectionMenuItem(s('library_update_interval_48h'), this.libraryUpdatePreferences.intervalHours === 48, () => { this.saveLibraryUpdateInterval(48) })
      } else if (row.key === 'tracker-update-strategy') {
        this.SelectionMenuItem(s('tracker_update_strategy_chapter_complete'), this.trackerUpdateStrategy === 'on_chapter_complete', () => { this.saveTrackerUpdateStrategy('on_chapter_complete') })
        this.SelectionMenuItem(s('tracker_update_strategy_reader_close'), this.trackerUpdateStrategy === 'on_reader_close', () => { this.saveTrackerUpdateStrategy('on_reader_close') })
        this.SelectionMenuItem(s('tracker_update_strategy_manual'), this.trackerUpdateStrategy === 'manual', () => { this.saveTrackerUpdateStrategy('manual') })
      }
    }
  }

  private showImageCacheConfirm(): void {
    this.getUIContext().showAlertDialog({
      message: `${s('settings_image_cache_confirm')}\n${this.imageCacheDetailText()}`,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('settings_image_cache_clear'),
        fontColor: Color.Red,
        action: () => {
          this.clearImageCache()
        },
      },
    })
  }

  private handleRowClick(row: SettingsRow): void {
    if (row.key === 'komga') {
      this.onOpenKomgaSettings()
    } else if (row.key === 'opds') {
      this.onOpenOpdsSettings()
    } else if (row.key === 'webdav') {
      this.onOpenWebDavSettings()
    } else if (this.isSelectionRow(row)) {
      if (!this.canOpenSelectionMenu(row)) {
        this.showToast(s('settings_library_update_enable_first'))
      }
    } else if (row.key === 'backup' || row.key === 'backup-auto-export') {
      this.onOpenBackupManagement()
    } else if (row.key === 'trackers') {
      this.onOpenTrackerSettings()
    } else if (row.key === 'image-cache') {
      this.showImageCacheConfirm()
    } else if (row.key === 'sources') {
      this.showSourcesDialog()
    } else if (row.key === 'downloads' || row.key === 'download-retry-failed') {
      this.onOpenDownloads()
    } else if (row.key === 'download-notifications') {
      this.requestDownloadNotifications()
    } else if (row.key === 'download-notification-test') {
      this.sendDownloadNotificationTest()
    } else if (row.key === 'library-auto-update') {
      this.setLibraryAutoUpdateEnabled(!this.libraryUpdatePreferences.autoCheckEnabled)
    } else if (row.key === 'library-update-notifications') {
      this.requestLibraryUpdateNotifications()
    } else if (row.key === 'library-update') {
      this.checkLibraryUpdates()
    } else if (row.key === 'library-update-results') {
      this.openLibraryUpdateResults()
    } else if (row.key === 'library-categories') {
      this.onOpenLibraryCategories()
    } else if (row.key === 'local-library-refresh') {
      this.checkLocalLibraryRefresh()
    } else if (row.key === 'reader-reset-defaults') {
      this.resetReaderPreferences()
    } else if (row.key === 'about') {
      this.showAboutDialog()
    } else if (row.key === 'privacy-permissions') {
      this.showPrivacyPermissionsDialog()
    } else if (row.key === 'version') {
      this.showVersionDialog()
    } else if (row.key === 'open-source') {
      this.showOpenSourceDialog()
    } else if (this.isPlaceholderRow(row)) {
      this.showToast(`${this.rowTitle(row)}${s('settings_coming_soon_suffix')}`)
    }
  }

  @Builder
  private AccentColorSuffix() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Row() {}
        .width(16)
        .height(16)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(getAppearanceAccentColorValue(this.appearanceAccentColor))
      Text(this.rowDetail({ key: 'theme-color', titleKey: 'settings_row_theme_color_title', detailKey: 'settings_row_theme_color_detail' }))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding({ left: 4, right: 12 })
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SectionRow(row: SettingsRow) {
    if (this.isSwitchRow(row)) {
      ConciseListRow({
        title: this.rowTitle(row),
        subtitle: this.rowDetail(row),
        showChevron: false,
        hasSwitch: true,
        checked: this.switchRowValue(row),
        switchAction: (isOn: boolean) => {
          this.setSwitchRowValue(row, isOn)
        },
      })
    } else if (this.isSelectionRow(row) && this.canOpenSelectionMenu(row)) {
      Column() {
        if (row.key === 'theme-color') {
          ConciseListRow({
            title: this.rowTitle(row),
            trailingDropdown: true,
            showChevron: true,
            suffixBuilderParam: () => {
              this.AccentColorSuffix()
            },
            action: () => {
              this.settingsMenuKey = row.key
            },
          })
        } else {
          ConciseListRow({
            title: this.rowTitle(row),
            trailingText: this.rowDetail(row),
            trailingDropdown: true,
            showChevron: true,
            action: () => {
              this.settingsMenuKey = row.key
            },
          })
        }
      }
        .bindMenu(this.settingsMenuKey === row.key, this.SettingsSelectionMenu(row), {
          placement: Placement.BottomRight,
          onDisappear: () => {
            if (this.settingsMenuKey === row.key) {
              this.settingsMenuKey = ''
            }
          },
        })
    } else if (this.isSelectionRow(row)) {
      ConciseListRow({
        title: this.rowTitle(row),
        trailingText: this.rowDetail(row),
        showChevron: false,
        action: () => {
          this.handleRowClick(row)
        },
      })
    } else if (this.isPlaceholderRow(row)) {
      ConciseListRow({
        title: this.rowTitle(row),
        trailingText: this.rowDetail(row),
        showChevron: false,
        action: () => {
          this.handleRowClick(row)
        },
      })
    } else {
      ConciseListRow({
        title: this.rowTitle(row),
        trailingText: this.rowDetail(row),
        showChevron: true,
        action: () => {
          this.handleRowClick(row)
        },
      })
    }
  }

  @Builder
  private SearchResultRow(result: SettingsSearchResult) {
    ConciseListRow({
      title: this.rowTitle(result.row),
      subtitle: this.searchResultSubtitle(result),
      subtitleMaxLines: 2,
      showChevron: true,
      action: () => {
        this.settingsSearchText = ''
        this.onOpenSettingsPane(result.pane)
      },
    })
  }

  @Builder
  private RootPaneRow(item: SettingsPaneItem) {
    ConciseListRow({
      title: this.paneItemTitle(item),
      subtitle: this.paneItemDetail(item),
      leadingIcon: item.icon,
      leadingIconBackgroundColor: item.color,
      showChevron: true,
      action: () => {
        this.onOpenSettingsPane(item.key)
      },
    })
  }

  @Builder
  private RootSection(section: SettingsPaneSection) {
    GroupedListSection() {
      ForEach(section.items, (item: SettingsPaneItem, index: number) => {
        this.RootPaneRow(item)
        if (index < section.items.length - 1) {
          ListDivider()
        }
      }, (item: SettingsPaneItem) => item.key)
    }
  }

  @Builder
  private RootSettings() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      ForEach(createSettingsRootSections(), (section: SettingsPaneSection) => {
        this.RootSection(section)
      }, (section: SettingsPaneSection) => section.key)
    }
    .width('100%')
  }

  @Builder
  private PaneSettings() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      ForEach(this.paneSections(), (section: SettingsSection) => {
        this.Section(section)
      }, (section: SettingsSection) => section.key)
    }
    .width('100%')
  }

  @Builder
  private SearchResults() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: s('settings_section_search_results') })
      if (this.settingsSearchResults().length === 0) {
        GroupedListSection() {
          ConciseListRow({
            title: s('settings_search_empty_title'),
            subtitle: this.settingsSearchText,
            showChevron: false,
          })
        }
      } else {
        GroupedListSection() {
          ForEach(this.settingsSearchResults(), (result: SettingsSearchResult, index: number) => {
            this.SearchResultRow(result)
            if (index < this.settingsSearchResults().length - 1) {
              ListDivider()
            }
          }, (result: SettingsSearchResult) => result.key)
        }
      }
    }
    .width('100%')
  }

  @Builder
  private Section(section: SettingsSection) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: this.sectionTitle(section) })
      GroupedListSection() {
        ForEach(section.rows, (row: SettingsRow, index: number) => {
          this.SectionRow(row)
          if (index < section.rows.length - 1) {
            ListDivider()
          }
        }, (row: SettingsRow) => row.key)
      }
    }
    .width('100%')
  }

  @Builder
  private SettingsContent() {
    if (this.isSettingsSearchActive()) {
      this.SearchResults()
    } else if (this.pane === 'root') {
      this.RootSettings()
    } else {
      this.PaneSettings()
    }
  }

  @Builder
  private SettingsSearchField() {
    Search({ value: this.settingsSearchText, placeholder: s('settings_search_placeholder') })
      .width('100%')
      .height(ThemeConstants.BUTTON_HEIGHT)
      .backgroundColor(ThemeConstants.CARD)
      .placeholderColor(ThemeConstants.TEXT_SECONDARY)
      .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
      .onChange((value: string) => {
        this.settingsSearchText = value
      })
      .onSubmit((value: string) => {
        this.settingsSearchText = value
      })
  }

  aboutToAppear(): void {
    this.loadLatestLibraryUpdateSummary()
    this.loadVersion()
    this.loadPreferences()
    this.loadAppearancePreferences()
    this.loadLibraryUpdatePreferences()
    this.loadLibraryUpdateNotificationStatus()
    this.loadDownloadQueuePreferences()
    this.loadDownloadNotificationStatus()
    this.loadLibraryFilterPreferences()
    this.loadTrackerPreferences()
    this.loadBackupContentPreferences()
    this.loadImageCachePreferences()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        if (this.pane === 'root') {
          ListItem() {
            this.SettingsSearchField()
          }
        }
        ListItem() {
          this.SettingsContent()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}
