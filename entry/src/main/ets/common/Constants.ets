import { AppStrings } from '../i18n/AppStrings'

export class TabIndex {
  static readonly LIBRARY: number = 0
  static readonly BROWSE: number = 1
  static readonly HISTORY: number = 2
  static readonly SEARCH: number = 3
  static readonly SETTINGS: number = 4
}

export class RouteName {
  static readonly READER: string = 'ReaderPage'
  static readonly IMPORT: string = 'ImportPage'
  static readonly MANGA_DETAIL: string = 'MangaDetailPage'
  static readonly KOMGA_SERVER: string = 'KomgaServerPage'
  static readonly KAVITA_SERVER: string = 'KavitaServerPage'
  static readonly OPDS_SERVER: string = 'OpdsServerPage'
  static readonly WEBDAV_SERVER: string = 'WebDavServerPage'
  static readonly SOURCE_PACKAGE_MANAGER: string = 'SourcePackageManagerPage'
  static readonly SETTINGS_PANE: string = 'SettingsPanePage'
  static readonly LIBRARY_UPDATE_RESULTS: string = 'LibraryUpdateResultPage'
  static readonly LIBRARY_CATEGORIES: string = 'LibraryCategoryManagementPage'
  static readonly DOWNLOADS: string = 'DownloadsPage'
  static readonly BACKUP_MANAGEMENT: string = 'BackupManagementPage'
  static readonly TRACKER_SETTINGS: string = 'TrackerSettingsPage'
}

export const KOMA_BUNDLE_NAME: string = 'com.honjow.koma'
export const KOMA_LAUNCH_ROUTE_PARAM: string = 'koma.launchRoute'
export const KOMA_LAUNCH_ROUTE_LIBRARY_UPDATE_RESULTS: string = 'library_update_results'
export const KOMA_LAUNCH_ROUTE_DOWNLOADS: string = 'downloads'
export const KOMA_LAUNCH_ROUTE_SOURCE_PACKAGE_MANAGER: string = 'source_package_manager'
export const KOMA_LAUNCH_ROUTE_TRACKER_SETTINGS: string = 'tracker_settings'

export function tabLabel(index: number): string {
  if (index === TabIndex.LIBRARY) {
    return AppStrings.get('tab_library')
  }
  if (index === TabIndex.BROWSE) {
    return AppStrings.get('tab_browse')
  }
  if (index === TabIndex.HISTORY) {
    return AppStrings.get('tab_history')
  }
  if (index === TabIndex.SEARCH) {
    return AppStrings.get('tab_search')
  }
  return AppStrings.get('tab_settings')
}
