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

export class TabLabel {
  static readonly LIBRARY: string = '书架'
  static readonly BROWSE: string = '浏览'
  static readonly HISTORY: string = '历史'
  static readonly SEARCH: string = '搜索'
  static readonly SETTINGS: string = '设置'
}
