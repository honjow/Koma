import { bundleManager, common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ReadingDirection } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import {
  LibraryUpdateService,
  LibraryUpdateSummary,
  formatLibraryUpdateSummary,
} from '../model/LibraryUpdateService'
import {
  LocalLibraryRefreshService,
  LocalLibraryRefreshSummary,
  formatLocalLibraryRefreshSummary,
} from '../model/LocalLibraryRefreshService'
import {
  LibraryUpdateResultStore,
  clearLatestLibraryUpdateSummary,
  createLibraryUpdateJobSnapshot,
  getLatestLibraryUpdateSummary,
  setLatestLibraryUpdateJobSnapshot,
  setLatestLibraryUpdateSummary,
} from '../model/LibraryUpdateResultStore'
import {
  DEFAULT_LIBRARY_UPDATE_PREFERENCES,
  LibraryUpdatePreferences,
  LibraryUpdatePreferencesStore,
  getLibraryUpdateAutoCheckLabel,
  getLibraryUpdateLastResultLabel,
  getLibraryUpdateNextDueAt,
  getLibraryUpdateNextDueLabel,
  formatLibraryUpdateTimestamp,
  isLibraryUpdateDue,
  normalizeLibraryUpdateFailureCode,
  normalizeLibraryUpdateFailureCount,
} from '../model/LibraryUpdatePreferencesStore'
import {
  ReaderRemoteImageCacheStats,
  clearReaderRemoteImageCache,
  configureReaderRemoteImageCache,
  formatReaderRemoteImageCacheSize,
  getReaderRemoteImageCacheStats,
} from '../model/ReaderPageSourceAdapter'
import {
  ReaderBackgroundMode,
  ReaderImageFitMode,
  ReaderPageGapMode,
  ReaderPageMode,
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
  title: string
  detail: string
  placeholder?: boolean
}

interface SettingsSection {
  key: string
  title: string
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
  title: string
  detail: string
  icon: Resource
  color: ResourceColor
}

interface SettingsPaneSection {
  key: string
  title: string
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
      title: s('settings_section_appearance'),
      rows: [
        { key: 'theme', title: s('settings_row_theme_title'), detail: s('settings_row_theme_detail') },
        { key: 'theme-color', title: s('settings_row_theme_color_title'), detail: s('settings_row_theme_color_detail'), placeholder: true },
        { key: 'language', title: s('settings_row_language_title'), detail: s('settings_row_language_detail') },
        { key: 'list-density', title: s('settings_row_list_density_title'), detail: s('settings_row_list_density_detail'), placeholder: true },
      ],
    },
    {
      key: 'reader',
      title: s('settings_section_reader'),
      rows: [
        { key: 'page-mode', title: s('settings_row_page_mode_title'), detail: s('settings_row_page_mode_detail') },
        { key: 'reading-direction', title: s('settings_row_reading_direction_title'), detail: s('settings_row_reading_direction_detail') },
        { key: 'reader-background', title: s('settings_row_reader_background_title'), detail: s('settings_row_reader_background_detail') },
        { key: 'reader-progress', title: s('settings_row_reader_progress_title'), detail: s('settings_row_reader_progress_detail') },
        { key: 'reader-keep-screen-awake', title: s('settings_row_reader_keep_screen_awake_title'), detail: s('settings_row_reader_keep_screen_awake_detail') },
        { key: 'reader-image-fit', title: s('settings_row_reader_image_fit_title'), detail: s('settings_row_reader_image_fit_detail') },
        { key: 'reader-tap-navigation', title: s('settings_row_reader_tap_navigation_title'), detail: s('settings_row_reader_tap_navigation_detail') },
        { key: 'reader-tap-zone-preset', title: s('settings_row_reader_tap_zone_preset_title'), detail: s('settings_row_reader_tap_zone_preset_detail') },
        { key: 'reader-page-gap', title: s('settings_row_reader_page_gap_title'), detail: s('settings_row_reader_page_gap_detail') },
        { key: 'reader-trim-page-margins', title: s('settings_row_reader_trim_page_margins_title'), detail: s('settings_row_reader_trim_page_margins_detail') },
        { key: 'reader-wide-image-mode', title: s('settings_row_reader_wide_image_mode_title'), detail: s('settings_row_reader_wide_image_mode_detail') },
        { key: 'reader-volume-key-navigation', title: s('settings_row_reader_volume_key_navigation_title'), detail: s('settings_row_reader_volume_key_navigation_detail') },
      ],
    },
    {
      key: 'data',
      title: s('settings_section_data'),
      rows: [
        { key: 'komga', title: s('settings_row_komga_title'), detail: s('settings_row_komga_detail') },
        { key: 'opds', title: s('settings_row_opds_title'), detail: s('settings_row_opds_detail') },
        { key: 'webdav', title: s('settings_row_webdav_title'), detail: s('settings_row_webdav_detail') },
        { key: 'library-auto-update', title: s('settings_row_library_auto_update_title'), detail: s('settings_row_library_auto_update_detail') },
        { key: 'library-update-interval', title: s('settings_row_library_update_interval_title'), detail: s('settings_row_library_update_interval_detail') },
        { key: 'library-update', title: s('settings_row_library_update_title'), detail: s('settings_row_library_update_detail') },
        { key: 'library-update-results', title: s('settings_row_library_update_results_title'), detail: s('settings_row_library_update_results_detail') },
        { key: 'library-categories', title: s('settings_row_library_categories_title'), detail: s('settings_row_library_categories_detail') },
        { key: 'library-view-mode', title: s('settings_row_library_view_mode_title'), detail: s('settings_row_library_view_mode_detail'), placeholder: true },
        { key: 'library-default-sort', title: s('settings_row_library_default_sort_title'), detail: s('settings_row_library_default_sort_detail'), placeholder: true },
        { key: 'library-badges', title: s('settings_row_library_badges_title'), detail: s('settings_row_library_badges_detail'), placeholder: true },
        { key: 'local-library-refresh', title: s('settings_row_local_library_refresh_title'), detail: s('settings_row_local_library_refresh_detail') },
        { key: 'sources', title: s('settings_row_sources_title'), detail: s('settings_row_sources_detail') },
        { key: 'downloads', title: s('settings_row_downloads_title'), detail: s('settings_row_downloads_detail') },
        { key: 'download-concurrency', title: s('settings_row_download_concurrency_title'), detail: s('settings_row_download_concurrency_detail'), placeholder: true },
        { key: 'download-retry-failed', title: s('settings_row_download_retry_failed_title'), detail: s('settings_row_download_retry_failed_detail'), placeholder: true },
        { key: 'download-wifi-only', title: s('settings_row_download_wifi_only_title'), detail: s('settings_row_download_wifi_only_detail'), placeholder: true },
        { key: 'trackers', title: s('settings_row_trackers_title'), detail: s('settings_row_trackers_detail') },
        { key: 'tracker-auto-sync', title: s('settings_row_tracker_auto_sync_title'), detail: s('settings_row_tracker_auto_sync_detail'), placeholder: true },
        { key: 'tracker-update-strategy', title: s('settings_row_tracker_update_strategy_title'), detail: s('settings_row_tracker_update_strategy_detail'), placeholder: true },
        { key: 'backup', title: s('settings_row_backup_title'), detail: s('settings_row_backup_detail') },
        { key: 'backup-auto-export', title: s('settings_row_backup_auto_export_title'), detail: s('settings_row_backup_auto_export_detail'), placeholder: true },
        { key: 'backup-include-settings', title: s('settings_row_backup_include_settings_title'), detail: s('settings_row_backup_include_settings_detail'), placeholder: true },
        { key: 'image-cache', title: s('settings_row_image_cache_title'), detail: s('settings_row_image_cache_detail') },
        { key: 'cache-limit', title: s('settings_row_cache_limit_title'), detail: s('settings_row_cache_limit_detail'), placeholder: true },
        { key: 'cache-auto-clean', title: s('settings_row_cache_auto_clean_title'), detail: s('settings_row_cache_auto_clean_detail'), placeholder: true },
      ],
    },
    {
      key: 'about',
      title: s('settings_section_about'),
      rows: [
        { key: 'about', title: s('settings_row_about_title'), detail: s('settings_row_about_detail') },
        { key: 'version', title: s('settings_row_version_title'), detail: s('settings_row_version_detail') },
        { key: 'open-source', title: s('settings_row_open_source_title'), detail: s('settings_row_open_source_detail') },
      ],
    },
  ]
}

function createSettingsRootSections(): SettingsPaneSection[] {
  return [
    {
      key: 'primary',
      title: '',
      items: [
        {
          key: 'appearance',
          title: s('settings_pane_appearance_title'),
          detail: s('settings_pane_appearance_detail'),
          icon: $r('sys.symbol.gearshape'),
          color: ThemeConstants.STATUS_INFO,
        },
        {
          key: 'library',
          title: s('settings_pane_library_title'),
          detail: s('settings_pane_library_detail'),
          icon: $r('sys.symbol.square_fill_grid_2x2'),
          color: ThemeConstants.SOURCE_LOCAL_COLOR,
        },
        {
          key: 'reader',
          title: s('settings_pane_reader_title'),
          detail: s('settings_pane_reader_detail'),
          icon: $r('sys.symbol.clock'),
          color: ThemeConstants.STATUS_SUCCESS,
        },
        {
          key: 'services',
          title: s('settings_pane_services_title'),
          detail: s('settings_pane_services_detail'),
          icon: $r('sys.symbol.compass'),
          color: ThemeConstants.SOURCE_KOMGA_COLOR,
        },
      ],
    },
    {
      key: 'management',
      title: '',
      items: [
        {
          key: 'downloads',
          title: s('settings_pane_downloads_title'),
          detail: s('settings_pane_downloads_detail'),
          icon: $r('sys.symbol.clock'),
          color: ThemeConstants.STATUS_INFO,
        },
        {
          key: 'tracking',
          title: s('settings_pane_tracking_title'),
          detail: s('settings_pane_tracking_detail'),
          icon: $r('sys.symbol.magnifyingglass'),
          color: ThemeConstants.STATUS_WARNING,
        },
        {
          key: 'backup',
          title: s('settings_pane_backup_title'),
          detail: s('settings_pane_backup_detail'),
          icon: $r('sys.symbol.gearshape'),
          color: ThemeConstants.SOURCE_WEBDAV_COLOR,
        },
        {
          key: 'storage',
          title: s('settings_pane_storage_title'),
          detail: s('settings_pane_storage_detail'),
          icon: $r('sys.symbol.square_fill_grid_2x2'),
          color: ThemeConstants.STATUS_MUTED,
        },
        {
          key: 'about',
          title: s('settings_pane_about_title'),
          detail: s('settings_pane_about_detail'),
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
  @Event onLibraryChanged: () => void = () => {}
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Param sourceRegistry?: SourceRuntimeRegistry = undefined
  @Param pane: SettingsPaneKey = 'root'
  @Local private pageMode: ReaderPageMode = 'single_page'
  @Local private readingDirection: ReadingDirection = ReadingDirection.LEFT_TO_RIGHT
  @Local private themeMode: ReaderThemeMode = 'system'
  @Local private readerBackgroundMode: ReaderBackgroundMode = 'black'
  @Local private showReaderProgressControls: boolean = true
  @Local private keepReaderScreenAwake: boolean = true
  @Local private readerImageFitMode: ReaderImageFitMode = 'contain'
  @Local private readerTapNavigationEnabled: boolean = true
  @Local private readerTapZonePreset: ReaderTapZonePreset = 'edge'
  @Local private readerPageGapMode: ReaderPageGapMode = 'normal'
  @Local private readerTrimPageMarginsEnabled: boolean = false
  @Local private readerWideImageMode: ReaderWideImageMode = 'keep_single'
  @Local private readerVolumeKeyNavigationEnabled: boolean = false
  @Local private language: LanguageState = connectLanguageState()
  @Local private versionDetail: string = ''
  @Local private imageCacheDetail: string = ''
  @Local private libraryUpdateBusy: boolean = false
  @Local private libraryUpdateSummary?: LibraryUpdateSummary = undefined
  @Local private libraryUpdatePreferences: LibraryUpdatePreferences = DEFAULT_LIBRARY_UPDATE_PREFERENCES
  @Local private localLibraryRefreshBusy: boolean = false
  @Local private localLibraryRefreshSummary?: LocalLibraryRefreshSummary = undefined
  @Local private settingsSearchText: string = ''
  @Local private settingsMenuKey: string = ''
  @Local private downloadWifiOnly: boolean = false
  @Local private trackerAutoSync: boolean = false
  @Local private backupAutoExport: boolean = false
  @Local private cacheAutoClean: boolean = false

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private preferencesStore(): ReaderPreferencesStore {
    return new ReaderPreferencesStore(this.context())
  }

  private libraryUpdatePreferencesStore(): LibraryUpdatePreferencesStore {
    return new LibraryUpdatePreferencesStore(this.context())
  }

  private libraryUpdateResultStore(): LibraryUpdateResultStore {
    return new LibraryUpdateResultStore(this.context())
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
    if (row.key === 'reader-tap-zone-preset') {
      return getReaderTapZonePresetLabel(this.readerTapZonePreset)
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
    if (row.key === 'download-wifi-only') {
      return this.downloadWifiOnly ? s('common_on') : s('common_off')
    }
    if (row.key === 'tracker-auto-sync') {
      return this.trackerAutoSync ? s('common_on') : s('common_off')
    }
    if (row.key === 'backup-auto-export') {
      return this.backupAutoExport ? s('common_on') : s('common_off')
    }
    if (row.key === 'cache-auto-clean') {
      return this.cacheAutoClean ? s('common_on') : s('common_off')
    }
    if (row.key === 'version') {
      return this.versionDetail
    }
    if (row.key === 'sources') {
      const count = listInstalled().length
      return count > 0 ? s('settings_sources_installed_count').replace('%s', `${count}`) : s('settings_sources_none')
    }
    if (row.key === 'image-cache') {
      return this.imageCacheDetail
    }
    if (row.key === 'library-auto-update') {
      return getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)
    }
    if (row.key === 'library-update-interval') {
      if (!this.libraryUpdatePreferences.autoCheckEnabled) {
        return s('settings_library_update_enable_first')
      }
      return `${getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update') {
      if (this.libraryUpdateBusy) {
        return s('common_checking')
      }
      const effectiveSummary = this.getEffectiveLibraryUpdateSummary()
      const summaryText = formatLibraryUpdateSummary(effectiveSummary)
      const checkedAt = effectiveSummary?.checkedAt
      if (checkedAt === undefined) {
        const storedSummary = this.libraryUpdatePreferences.lastSummaryText
        const storedCheckedAt = this.libraryUpdatePreferences.lastCheckedAt
        if (storedSummary !== undefined && storedCheckedAt !== undefined) {
          return `${getLibraryUpdateLastResultLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
        }
        if (this.libraryUpdatePreferences.lastFailureCode !== undefined && storedCheckedAt !== undefined) {
          return `${getLibraryUpdateLastResultLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
        }
        return `${summaryText} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
      }
      return `${summaryText} · ${s('common_last_checked')} ${this.formatTimestamp(checkedAt)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update-results') {
      return this.getEffectiveLibraryUpdateSummary() === undefined ? s('library_update_no_result') : s('settings_library_update_results_view')
    }
    if (row.key === 'library-categories') {
      const count = this.libraryStore === undefined ? 0 : this.libraryStore.listCustomCategories().length
      return count > 0 ? s('settings_library_categories_count').replace('%s', `${count}`) : s('settings_row_library_categories_detail')
    }
    if (row.key === 'local-library-refresh') {
      if (this.localLibraryRefreshBusy) {
        return s('common_checking')
      }
      return formatLocalLibraryRefreshSummary(this.localLibraryRefreshSummary)
    }
    return row.detail
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
          title: s('settings_section_library_organization'),
          rows: this.rowsByKeys([
            'library-categories',
            'library-view-mode',
            'library-default-sort',
            'library-badges',
          ]),
        },
        {
          key: 'library-updates',
          title: s('settings_section_library_updates'),
          rows: this.rowsByKeys([
            'library-auto-update',
            'library-update-interval',
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
          title: s('settings_section_private_libraries'),
          rows: this.rowsByKeys(['komga', 'opds', 'webdav']),
        },
        {
          key: 'source-runtime',
          title: s('settings_section_source_runtime'),
          rows: this.rowsByKeys(['sources']),
        },
      ]
    }
    if (pane === 'downloads') {
      return [
        {
          key: 'downloads',
          title: s('settings_section_downloads'),
          rows: this.rowsByKeys([
            'downloads',
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
          title: s('settings_section_tracking'),
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
          title: s('settings_section_backup'),
          rows: this.rowsByKeys([
            'backup',
            'backup-auto-export',
            'backup-include-settings',
          ]),
        },
      ]
    }
    if (pane === 'storage') {
      return [
        {
          key: 'storage',
          title: s('settings_section_storage'),
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
          const haystack = `${paneTitle} ${section.title} ${row.title} ${row.detail} ${currentDetail}`.toLowerCase()
          if (haystack.includes(query)) {
            results.push({
              key: `${pane}:${section.key}:${row.key}`,
              pane,
              sectionTitle: section.title,
              row,
            })
          }
        })
      })
    })
    return results
  }

  private paneTitle(pane: SettingsPaneKey): string {
    return settingsPaneTitle(pane)
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
    if (this.isLibraryUpdateSummaryStaleAfterFailure(this.libraryUpdateSummary)) {
      return undefined
    }
    return this.libraryUpdateSummary
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
    if (this.isLibraryUpdateSummaryStaleAfterFailure(this.libraryUpdateSummary)) {
      this.libraryUpdateSummary = undefined
    }
  }

  private loadPreferences(): void {
    void this.preferencesStore().load()
      .then((preferences) => {
        this.pageMode = preferences.pageMode
        this.readingDirection = preferences.readingDirection
        this.themeMode = preferences.themeMode
        this.readerBackgroundMode = preferences.backgroundMode
        this.showReaderProgressControls = preferences.showProgressControls
        this.keepReaderScreenAwake = preferences.keepScreenAwake
        this.readerImageFitMode = preferences.imageFitMode
        this.readerTapNavigationEnabled = preferences.tapNavigationEnabled
        this.readerTapZonePreset = preferences.tapZonePreset
        this.readerPageGapMode = preferences.pageGapMode
        this.readerTrimPageMarginsEnabled = preferences.trimPageMarginsEnabled
        this.readerWideImageMode = preferences.wideImageMode
        this.readerVolumeKeyNavigationEnabled = preferences.volumeKeyNavigationEnabled
        console.info('[Settings] step=load_preferences')
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_preferences_failed message=' + error.message)
      })
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

  private loadLatestLibraryUpdateSummary(): void {
    const latest = getLatestLibraryUpdateSummary()
    this.libraryUpdateSummary = this.isLibraryUpdateSummaryStaleAfterFailure(latest) ? undefined : latest
    void this.libraryUpdateResultStore().load()
      .then((summary: LibraryUpdateSummary | undefined) => {
        const current = getLatestLibraryUpdateSummary()
        let effectiveSummary = current
        if (summary !== undefined && (current === undefined || summary.checkedAt > current.checkedAt)) {
          setLatestLibraryUpdateSummary(summary)
          effectiveSummary = summary
        }
        this.libraryUpdateSummary = this.isLibraryUpdateSummaryStaleAfterFailure(effectiveSummary) ? undefined : effectiveSummary
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
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=version_failed message=' + e.message)
      this.versionDetail = s('settings_version_dev')
    }
  }

  private ensureReaderRemoteImageCache(): boolean {
    try {
      const context = this.context()
      if (context.cacheDir === undefined || context.cacheDir.length === 0) {
        return false
      }
      configureReaderRemoteImageCache(context.cacheDir)
      return true
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=image_cache_configure_failed message=' + e.message)
      return false
    }
  }

  private updateImageCacheDetail(stats: ReaderRemoteImageCacheStats): void {
    this.imageCacheDetail = `${formatReaderRemoteImageCacheSize(stats.totalBytes)} · ${stats.entryCount} ${s('common_items_unit')}`
  }

  private loadImageCacheStats(): void {
    if (!this.ensureReaderRemoteImageCache()) {
      this.imageCacheDetail = s('common_unavailable')
      return
    }
    void getReaderRemoteImageCacheStats()
      .then((stats: ReaderRemoteImageCacheStats) => {
        this.updateImageCacheDetail(stats)
        console.info('[Settings] step=image_cache_stats totalBytes=' + stats.totalBytes + ' entryCount=' + stats.entryCount)
      })
      .catch((error: Error) => {
        this.imageCacheDetail = s('common_load_failed')
        console.warn('[Settings] step=image_cache_stats_failed message=' + error.message)
      })
  }

  private savePageMode(pageMode: ReaderPageMode): void {
    this.pageMode = pageMode
    void this.preferencesStore().savePageMode(pageMode)
      .then(() => {
        console.info('[Settings] step=save_page_mode value=' + pageMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_page_mode_failed message=' + error.message)
      })
  }

  private saveReadingDirection(readingDirection: ReadingDirection): void {
    this.readingDirection = readingDirection
    void this.preferencesStore().saveReadingDirection(readingDirection)
      .then(() => {
        console.info('[Settings] step=save_reading_direction value=' + readingDirection)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reading_direction_failed message=' + error.message)
      })
  }

  private saveThemeMode(themeMode: ReaderThemeMode): void {
    this.themeMode = themeMode
    try {
      applyReaderThemeMode(this.context(), themeMode)
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=apply_theme_failed message=' + e.message)
    }
    void this.preferencesStore().saveThemeMode(themeMode)
      .then(() => {
        console.info('[Settings] step=save_theme value=' + themeMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_theme_failed message=' + error.message)
      })
  }

  private saveLanguageMode(mode: string): void {
    void LanguageSettings.setMode(this.context(), mode)
      .then(() => {
        console.info('[Settings] step=save_language value=' + mode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_language_failed message=' + error.message)
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
        console.warn('[Settings] step=save_reader_background_failed message=' + error.message)
      })
  }

  private saveReaderProgressControls(showProgressControls: boolean): void {
    this.showReaderProgressControls = showProgressControls
    void this.preferencesStore().saveShowProgressControls(showProgressControls)
      .then(() => {
        console.info('[Settings] step=save_reader_progress value=' + showProgressControls)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_progress_failed message=' + error.message)
      })
  }

  private saveReaderKeepScreenAwake(keepScreenAwake: boolean): void {
    this.keepReaderScreenAwake = keepScreenAwake
    void this.preferencesStore().saveKeepScreenAwake(keepScreenAwake)
      .then(() => {
        console.info('[Settings] step=save_reader_keep_screen_awake value=' + keepScreenAwake)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_keep_screen_awake_failed message=' + error.message)
      })
  }

  private saveReaderImageFitMode(imageFitMode: ReaderImageFitMode): void {
    this.readerImageFitMode = imageFitMode
    void this.preferencesStore().saveImageFitMode(imageFitMode)
      .then(() => {
        console.info('[Settings] step=save_reader_image_fit value=' + imageFitMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_image_fit_failed message=' + error.message)
      })
  }

  private saveReaderTapNavigationEnabled(tapNavigationEnabled: boolean): void {
    this.readerTapNavigationEnabled = tapNavigationEnabled
    void this.preferencesStore().saveTapNavigationEnabled(tapNavigationEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_tap_navigation value=' + tapNavigationEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_tap_navigation_failed message=' + error.message)
      })
  }

  private saveReaderTapZonePreset(tapZonePreset: ReaderTapZonePreset): void {
    this.readerTapZonePreset = tapZonePreset
    void this.preferencesStore().saveTapZonePreset(tapZonePreset)
      .then(() => {
        console.info('[Settings] step=save_reader_tap_zone_preset value=' + tapZonePreset)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_tap_zone_preset_failed message=' + error.message)
      })
  }

  private saveReaderPageGapMode(pageGapMode: ReaderPageGapMode): void {
    this.readerPageGapMode = pageGapMode
    void this.preferencesStore().savePageGapMode(pageGapMode)
      .then(() => {
        console.info('[Settings] step=save_reader_page_gap value=' + pageGapMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_page_gap_failed message=' + error.message)
      })
  }

  private saveReaderTrimPageMarginsEnabled(trimPageMarginsEnabled: boolean): void {
    this.readerTrimPageMarginsEnabled = trimPageMarginsEnabled
    void this.preferencesStore().saveTrimPageMarginsEnabled(trimPageMarginsEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_trim_page_margins value=' + trimPageMarginsEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_trim_page_margins_failed message=' + error.message)
      })
  }

  private saveReaderWideImageMode(wideImageMode: ReaderWideImageMode): void {
    this.readerWideImageMode = wideImageMode
    void this.preferencesStore().saveWideImageMode(wideImageMode)
      .then(() => {
        console.info('[Settings] step=save_reader_wide_image_mode value=' + wideImageMode)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_wide_image_mode_failed message=' + error.message)
      })
  }

  private saveReaderVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled: boolean): void {
    this.readerVolumeKeyNavigationEnabled = volumeKeyNavigationEnabled
    void this.preferencesStore().saveVolumeKeyNavigationEnabled(volumeKeyNavigationEnabled)
      .then(() => {
        console.info('[Settings] step=save_reader_volume_key_navigation value=' + volumeKeyNavigationEnabled)
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=save_reader_volume_key_navigation_failed message=' + error.message)
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
        console.warn('[Settings] step=image_cache_clear_failed message=' + error.message)
        this.showToast(s('settings_image_cache_clear_failed'))
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
    if (this.libraryUpdatePreferences.lastSummaryText !== undefined) {
      nextPreferences.lastSummaryText = this.libraryUpdatePreferences.lastSummaryText
    }
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
        console.warn('[Settings] step=save_library_auto_update_failed message=' + error.message)
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
    if (this.libraryUpdatePreferences.lastSummaryText !== undefined) {
      nextPreferences.lastSummaryText = this.libraryUpdatePreferences.lastSummaryText
    }
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
        const summaryText = formatLibraryUpdateSummary(summary)
        console.info('[Settings] step=library_update_done reason=' + reason + ' total=' + summary.totalCount + ' updated=' + summary.updatedCount + ' failed=' + summary.failedCount)
        void this.libraryUpdatePreferencesStore().saveLastSummary(summary.checkedAt, summaryText)
          .then((preferences: LibraryUpdatePreferences) => {
            this.saveLibraryUpdatePreferences(preferences)
          })
          .catch((error: Error) => {
            console.warn('[Settings] step=save_library_update_summary_failed code=' + safeSettingsErrorCode(error))
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
      } else {
        this.showToast(s('settings_local_library_refresh_clean'))
      }
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=local_library_refresh_failed message=' + e.message)
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
      row.key === 'language' ||
      row.key === 'reader-background' ||
      row.key === 'reader-image-fit' ||
      row.key === 'reader-tap-zone-preset' ||
      row.key === 'reader-page-gap' ||
      row.key === 'reader-wide-image-mode' ||
      row.key === 'library-update-interval'
  }

  private isSwitchRow(row: SettingsRow): boolean {
    return row.key === 'library-auto-update' ||
      row.key === 'reader-progress' ||
      row.key === 'reader-keep-screen-awake' ||
      row.key === 'reader-tap-navigation' ||
      row.key === 'reader-trim-page-margins' ||
      row.key === 'reader-volume-key-navigation' ||
      row.key === 'download-wifi-only' ||
      row.key === 'tracker-auto-sync' ||
      row.key === 'backup-auto-export' ||
      row.key === 'cache-auto-clean'
  }

  private switchRowValue(row: SettingsRow): boolean {
    if (row.key === 'library-auto-update') {
      return this.libraryUpdatePreferences.autoCheckEnabled
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
    if (row.key === 'reader-trim-page-margins') {
      return this.readerTrimPageMarginsEnabled
    }
    if (row.key === 'reader-volume-key-navigation') {
      return this.readerVolumeKeyNavigationEnabled
    }
    if (row.key === 'download-wifi-only') {
      return this.downloadWifiOnly
    }
    if (row.key === 'tracker-auto-sync') {
      return this.trackerAutoSync
    }
    if (row.key === 'backup-auto-export') {
      return this.backupAutoExport
    }
    if (row.key === 'cache-auto-clean') {
      return this.cacheAutoClean
    }
    return false
  }

  private setPlaceholderSwitch(row: SettingsRow, value: boolean): void {
    if (row.key === 'download-wifi-only') {
      this.downloadWifiOnly = value
    } else if (row.key === 'tracker-auto-sync') {
      this.trackerAutoSync = value
    } else if (row.key === 'backup-auto-export') {
      this.backupAutoExport = value
    } else if (row.key === 'cache-auto-clean') {
      this.cacheAutoClean = value
    }
    this.showToast(`${row.title}${s('settings_coming_soon_suffix')}`)
  }

  private setSwitchRowValue(row: SettingsRow, value: boolean): void {
    if (row.key === 'library-auto-update') {
      this.setLibraryAutoUpdateEnabled(value)
    } else if (row.key === 'reader-progress') {
      this.saveReaderProgressControls(value)
    } else if (row.key === 'reader-keep-screen-awake') {
      this.saveReaderKeepScreenAwake(value)
    } else if (row.key === 'reader-tap-navigation') {
      this.saveReaderTapNavigationEnabled(value)
    } else if (row.key === 'reader-trim-page-margins') {
      this.saveReaderTrimPageMarginsEnabled(value)
    } else if (row.key === 'reader-volume-key-navigation') {
      this.saveReaderVolumeKeyNavigationEnabled(value)
    } else {
      this.setPlaceholderSwitch(row, value)
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
      } else if (row.key === 'library-update-interval') {
        this.SelectionMenuItem(s('library_update_interval_12h'), this.libraryUpdatePreferences.intervalHours === 12, () => { this.saveLibraryUpdateInterval(12) })
        this.SelectionMenuItem(s('library_update_interval_24h'), this.libraryUpdatePreferences.intervalHours === 24, () => { this.saveLibraryUpdateInterval(24) })
        this.SelectionMenuItem(s('library_update_interval_48h'), this.libraryUpdatePreferences.intervalHours === 48, () => { this.saveLibraryUpdateInterval(48) })
      }
    }
  }

  private showImageCacheConfirm(): void {
    this.getUIContext().showAlertDialog({
      message: `${s('settings_image_cache_confirm')}\n${this.imageCacheDetail}`,
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
    } else if (row.key === 'backup') {
      this.onOpenBackupManagement()
    } else if (row.key === 'trackers') {
      this.onOpenTrackerSettings()
    } else if (row.key === 'image-cache') {
      this.showImageCacheConfirm()
    } else if (row.key === 'sources') {
      this.showSourcesDialog()
    } else if (row.key === 'downloads') {
      this.onOpenDownloads()
    } else if (row.key === 'library-auto-update') {
      this.setLibraryAutoUpdateEnabled(!this.libraryUpdatePreferences.autoCheckEnabled)
    } else if (row.key === 'library-update') {
      this.checkLibraryUpdates()
    } else if (row.key === 'library-update-results') {
      this.openLibraryUpdateResults()
    } else if (row.key === 'library-categories') {
      this.onOpenLibraryCategories()
    } else if (row.key === 'local-library-refresh') {
      this.checkLocalLibraryRefresh()
    } else if (row.key === 'about') {
      this.showAboutDialog()
    } else if (row.key === 'version') {
      this.showVersionDialog()
    } else if (row.key === 'open-source') {
      this.showOpenSourceDialog()
    } else if (this.isPlaceholderRow(row)) {
      this.showToast(`${row.title}${s('settings_coming_soon_suffix')}`)
    }
  }

  @Builder
  private SectionRow(row: SettingsRow) {
    if (this.isSwitchRow(row)) {
      ConciseListRow({
        title: row.title,
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
        ConciseListRow({
          title: row.title,
          trailingText: this.rowDetail(row),
          trailingDropdown: true,
          showChevron: true,
          action: () => {
            this.settingsMenuKey = row.key
          },
        })
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
        title: row.title,
        trailingText: this.rowDetail(row),
        showChevron: false,
        action: () => {
          this.handleRowClick(row)
        },
      })
    } else if (this.isPlaceholderRow(row)) {
      ConciseListRow({
        title: row.title,
        trailingText: this.rowDetail(row),
        showChevron: false,
        action: () => {
          this.handleRowClick(row)
        },
      })
    } else {
      ConciseListRow({
        title: row.title,
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
      title: result.row.title,
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
      title: item.title,
      subtitle: item.detail,
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
      SectionHeader({ title: section.title })
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
    this.loadLibraryUpdatePreferences()
    this.loadImageCacheStats()
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
