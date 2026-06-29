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

const SETTINGS_SECTIONS: SettingsSection[] = [
  {
    key: 'appearance',
    title: '外观',
    rows: [
      { key: 'theme', title: '主题', detail: '跟随系统' },
      { key: 'theme-color', title: '主题色', detail: 'Koma 默认', placeholder: true },
      { key: 'language', title: '语言', detail: '跟随系统', placeholder: true },
      { key: 'list-density', title: '列表密度', detail: '标准', placeholder: true },
    ],
  },
  {
    key: 'reader',
    title: '阅读器',
    rows: [
      { key: 'page-mode', title: '翻页模式', detail: '单页' },
      { key: 'reading-direction', title: '阅读方向', detail: '从左到右' },
      { key: 'reader-background', title: '阅读背景', detail: '黑色' },
      { key: 'reader-progress', title: '页码与进度', detail: '显示' },
      { key: 'reader-keep-screen-awake', title: '屏幕常亮', detail: '开启' },
      { key: 'reader-image-fit', title: '图片适配', detail: '适合屏幕' },
      { key: 'reader-tap-navigation', title: '点击翻页', detail: '开启' },
      { key: 'reader-tap-zone-preset', title: '点击区域', detail: '窄边缘' },
      { key: 'reader-page-gap', title: '页面间距', detail: '标准' },
      { key: 'reader-trim-page-margins', title: '收紧页边（不裁图）', detail: '关闭' },
      { key: 'reader-wide-image-mode', title: '宽图处理', detail: '保持单页' },
      { key: 'reader-volume-key-navigation', title: '音量键翻页', detail: '关闭' },
    ],
  },
  {
    key: 'data',
    title: '数据',
    rows: [
      { key: 'komga', title: 'Komga 私有库', detail: '服务器与认证' },
      { key: 'opds', title: 'OPDS 私有库', detail: 'Catalog 与认证' },
      { key: 'webdav', title: 'WebDAV 私有库', detail: '远程文件夹与认证' },
      { key: 'library-auto-update', title: '自动检查更新', detail: '关闭' },
      { key: 'library-update-interval', title: '检查间隔', detail: '每 24 小时' },
      { key: 'library-update', title: '检查书架更新', detail: '尚未检查' },
      { key: 'library-update-results', title: '书架更新详情', detail: '尚无结果' },
      { key: 'library-categories', title: '书架分类', detail: '管理自定义分类' },
      { key: 'library-view-mode', title: '书架视图', detail: '网格', placeholder: true },
      { key: 'library-default-sort', title: '默认排序', detail: '最近阅读', placeholder: true },
      { key: 'library-badges', title: '角标与进度', detail: '显示未读和阅读进度', placeholder: true },
      { key: 'local-library-refresh', title: '刷新本地导入', detail: '需要重新选择本地文件' },
      { key: 'sources', title: '管理已安装的源包', detail: '暂未安装源包' },
      { key: 'downloads', title: '下载管理', detail: '离线章节与失败任务' },
      { key: 'download-concurrency', title: '并发下载数', detail: '2', placeholder: true },
      { key: 'download-retry-failed', title: '失败任务重试', detail: '手动', placeholder: true },
      { key: 'download-wifi-only', title: '仅 WLAN 下载', detail: '关闭', placeholder: true },
      { key: 'trackers', title: '追踪账号', detail: '安全存储未验证，账号未连接' },
      { key: 'tracker-auto-sync', title: '自动同步进度', detail: '关闭', placeholder: true },
      { key: 'tracker-update-strategy', title: '同步策略', detail: '阅读后同步', placeholder: true },
      { key: 'backup', title: '备份与恢复', detail: '导出书架、进度、源包和设置' },
      { key: 'backup-auto-export', title: '自动备份', detail: '关闭', placeholder: true },
      { key: 'backup-include-settings', title: '备份范围', detail: '书架、进度、源包和设置', placeholder: true },
      { key: 'image-cache', title: '图片缓存', detail: '0 B · 0 项' },
      { key: 'cache-limit', title: '缓存上限', detail: '未限制', placeholder: true },
      { key: 'cache-auto-clean', title: '自动清理缓存', detail: '关闭', placeholder: true },
    ],
  },
  {
    key: 'about',
    title: '关于',
    rows: [
      { key: 'about', title: '关于', detail: 'Koma 与项目说明' },
      { key: 'version', title: '版本', detail: 'Koma 开发版' },
      { key: 'open-source', title: '开源许可', detail: '查看依赖与许可证' },
    ],
  },
]

const SETTINGS_ROOT_SECTIONS: SettingsPaneSection[] = [
  {
    key: 'primary',
    title: '',
    items: [
      {
        key: 'appearance',
        title: '外观',
        detail: '主题',
        icon: $r('sys.symbol.gearshape'),
        color: ThemeConstants.STATUS_INFO,
      },
      {
        key: 'library',
        title: '书架',
        detail: '分类、更新、本地刷新',
        icon: $r('sys.symbol.square_fill_grid_2x2'),
        color: ThemeConstants.SOURCE_LOCAL_COLOR,
      },
      {
        key: 'reader',
        title: '阅读器',
        detail: '翻页、方向、背景、点击区域',
        icon: $r('sys.symbol.clock'),
        color: ThemeConstants.STATUS_SUCCESS,
      },
      {
        key: 'services',
        title: '私有库与源',
        detail: 'Komga、OPDS、WebDAV、源包',
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
        title: '下载',
        detail: '离线章节与失败任务',
        icon: $r('sys.symbol.clock'),
        color: ThemeConstants.STATUS_INFO,
      },
      {
        key: 'tracking',
        title: '追踪账号',
        detail: 'Bangumi / AniList 等进度同步',
        icon: $r('sys.symbol.magnifyingglass'),
        color: ThemeConstants.STATUS_WARNING,
      },
      {
        key: 'backup',
        title: '备份与恢复',
        detail: '书架、进度、源包和设置',
        icon: $r('sys.symbol.gearshape'),
        color: ThemeConstants.SOURCE_WEBDAV_COLOR,
      },
      {
        key: 'storage',
        title: '存储',
        detail: '图片缓存、刷新状态',
        icon: $r('sys.symbol.square_fill_grid_2x2'),
        color: ThemeConstants.STATUS_MUTED,
      },
      {
        key: 'about',
        title: '关于',
        detail: '版本、说明、开源许可',
        icon: $r('sys.symbol.gearshape'),
        color: ThemeConstants.STATUS_MUTED,
      },
    ],
  },
]

function safeSettingsErrorCode(error: Error): string {
  return normalizeLibraryUpdateFailureCode(error.name) ?? 'unknown'
}

export function settingsPaneTitle(pane: SettingsPaneKey): string {
  if (pane === 'appearance') {
    return '外观'
  }
  if (pane === 'library') {
    return '书架'
  }
  if (pane === 'reader') {
    return '阅读器'
  }
  if (pane === 'services') {
    return '私有库与源'
  }
  if (pane === 'downloads') {
    return '下载'
  }
  if (pane === 'tracking') {
    return '追踪账号'
  }
  if (pane === 'backup') {
    return '备份与恢复'
  }
  if (pane === 'storage') {
    return '存储'
  }
  if (pane === 'about') {
    return '关于'
  }
  return '设置'
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
  @Local private versionDetail: string = 'Koma 开发版'
  @Local private imageCacheDetail: string = '0 B · 0 项'
  @Local private libraryUpdateBusy: boolean = false
  @Local private libraryUpdateSummary?: LibraryUpdateSummary = undefined
  @Local private libraryUpdatePreferences: LibraryUpdatePreferences = DEFAULT_LIBRARY_UPDATE_PREFERENCES
  @Local private localLibraryRefreshBusy: boolean = false
  @Local private localLibraryRefreshSummary?: LocalLibraryRefreshSummary = undefined
  @Local private settingsSearchText: string = ''
  @Local private settingsMenuKey: string = ''

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
    if (row.key === 'version') {
      return this.versionDetail
    }
    if (row.key === 'sources') {
      const count = listInstalled().length
      return count > 0 ? `${count} 个源包` : '暂未安装源包'
    }
    if (row.key === 'image-cache') {
      return this.imageCacheDetail
    }
    if (row.key === 'library-auto-update') {
      return getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)
    }
    if (row.key === 'library-update-interval') {
      if (!this.libraryUpdatePreferences.autoCheckEnabled) {
        return '开启后可设置'
      }
      return `${getLibraryUpdateAutoCheckLabel(this.libraryUpdatePreferences)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update') {
      if (this.libraryUpdateBusy) {
        return '检查中...'
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
      return `${summaryText} · 上次 ${this.formatTimestamp(checkedAt)} · ${getLibraryUpdateNextDueLabel(this.libraryUpdatePreferences)}`
    }
    if (row.key === 'library-update-results') {
      return this.getEffectiveLibraryUpdateSummary() === undefined ? '尚无结果' : '查看最近检查结果'
    }
    if (row.key === 'library-categories') {
      const count = this.libraryStore === undefined ? 0 : this.libraryStore.listCustomCategories().length
      return count > 0 ? `${count} 个自定义分类` : '管理自定义分类'
    }
    if (row.key === 'local-library-refresh') {
      if (this.localLibraryRefreshBusy) {
        return '检查中...'
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
          title: '整理',
          rows: this.rowsByKeys([
            'library-categories',
            'library-view-mode',
            'library-default-sort',
            'library-badges',
          ]),
        },
        {
          key: 'library-updates',
          title: '更新',
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
          title: '私有库',
          rows: this.rowsByKeys(['komga', 'opds', 'webdav']),
        },
        {
          key: 'source-runtime',
          title: '源包',
          rows: this.rowsByKeys(['sources']),
        },
      ]
    }
    if (pane === 'downloads') {
      return [
        {
          key: 'downloads',
          title: '下载',
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
          title: '追踪',
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
          title: '备份',
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
          title: '缓存',
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
    return SETTINGS_SECTIONS.filter((section: SettingsSection): boolean => keys.includes(section.key))
  }

  private rowsByKeys(keys: string[]): SettingsRow[] {
    const rows: SettingsRow[] = []
    SETTINGS_SECTIONS.forEach((section: SettingsSection) => {
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
      this.versionDetail = 'Koma 开发版'
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
    this.imageCacheDetail = `${formatReaderRemoteImageCacheSize(stats.totalBytes)} · ${stats.entryCount} 项`
  }

  private loadImageCacheStats(): void {
    if (!this.ensureReaderRemoteImageCache()) {
      this.imageCacheDetail = '不可用'
      return
    }
    void getReaderRemoteImageCacheStats()
      .then((stats: ReaderRemoteImageCacheStats) => {
        this.updateImageCacheDetail(stats)
        console.info('[Settings] step=image_cache_stats totalBytes=' + stats.totalBytes + ' entryCount=' + stats.entryCount)
      })
      .catch((error: Error) => {
        this.imageCacheDetail = '读取失败'
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
      this.showToast('图片缓存不可用')
      return
    }
    console.info('[Settings] step=image_cache_clear_start')
    void clearReaderRemoteImageCache()
      .then((stats: ReaderRemoteImageCacheStats) => {
        this.updateImageCacheDetail(stats)
        console.info('[Settings] step=image_cache_clear_done totalBytes=' + stats.totalBytes + ' entryCount=' + stats.entryCount)
        this.showToast('图片缓存已清理')
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=image_cache_clear_failed message=' + error.message)
        this.showToast('清理缓存失败')
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
        this.showToast('保存自动检查设置失败')
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
        this.showToast('保存检查间隔失败')
      })
  }

  private checkLibraryUpdates(reason: string = 'manual'): void {
    if (this.libraryUpdateBusy) {
      return
    }
    if (this.libraryStore === undefined || this.sourceRegistry === undefined) {
      this.showToast('书架更新不可用')
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
          this.showToast(summary.updatedCount > 0 ? `发现 ${summary.updatedCount} 本更新` : '书架已是最新')
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
          this.showToast('检查书架更新失败')
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
      this.showToast('本地刷新不可用')
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
        this.showToast('没有本地导入项目')
      } else if (summary.reselectRequiredCount > 0) {
        this.showToast('刷新需要重新选择本地文件')
      } else {
        this.showToast('本地导入无需处理')
      }
    } catch (error) {
      const e = error as Error
      console.warn('[Settings] step=local_library_refresh_failed message=' + e.message)
      this.showToast('检查本地刷新失败')
    } finally {
      this.localLibraryRefreshBusy = false
    }
  }

  private showInfoDialog(title: string, message: string): void {
    void this.getUIContext().getPromptAction().showDialog({
      title,
      message,
      buttons: [
        { text: '确定', color: $r('app.color.koma_accent') },
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
    this.showInfoDialog('关于 Koma', 'Koma 是面向 HarmonyOS 的私有漫画书架与阅读器。')
  }

  private showOpenSourceDialog(): void {
    console.info('[Settings] step=open_source_dialog')
    this.showInfoDialog('开源许可', 'Koma 使用 HarmonyOS SDK 与项目内自有代码构建。\n\n第三方依赖许可将在后续版本补充完整清单。')
  }

  private showVersionDialog(): void {
    console.info('[Settings] step=version_dialog')
    this.showInfoDialog('版本', this.versionDetail)
  }

  private isSelectionRow(row: SettingsRow): boolean {
    return row.key === 'page-mode' ||
      row.key === 'reading-direction' ||
      row.key === 'theme' ||
      row.key === 'reader-background' ||
      row.key === 'reader-progress' ||
      row.key === 'reader-keep-screen-awake' ||
      row.key === 'reader-image-fit' ||
      row.key === 'reader-tap-navigation' ||
      row.key === 'reader-tap-zone-preset' ||
      row.key === 'reader-page-gap' ||
      row.key === 'reader-trim-page-margins' ||
      row.key === 'reader-wide-image-mode' ||
      row.key === 'reader-volume-key-navigation' ||
      row.key === 'library-update-interval'
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
        this.SelectionMenuItem('单页', this.pageMode === 'single_page', () => { this.savePageMode('single_page') })
        this.SelectionMenuItem('双页', this.pageMode === 'double_page', () => { this.savePageMode('double_page') })
        this.SelectionMenuItem('连续滚动', this.pageMode === 'continuous_scroll', () => { this.savePageMode('continuous_scroll') })
      } else if (row.key === 'reading-direction') {
        this.SelectionMenuItem('从左到右', this.readingDirection === ReadingDirection.LEFT_TO_RIGHT, () => { this.saveReadingDirection(ReadingDirection.LEFT_TO_RIGHT) })
        this.SelectionMenuItem('从右到左', this.readingDirection === ReadingDirection.RIGHT_TO_LEFT, () => { this.saveReadingDirection(ReadingDirection.RIGHT_TO_LEFT) })
        this.SelectionMenuItem('纵向', this.readingDirection === ReadingDirection.WEBTOON, () => { this.saveReadingDirection(ReadingDirection.WEBTOON) })
      } else if (row.key === 'theme') {
        this.SelectionMenuItem('跟随系统', this.themeMode === 'system', () => { this.saveThemeMode('system') })
        this.SelectionMenuItem('浅色', this.themeMode === 'light', () => { this.saveThemeMode('light') })
        this.SelectionMenuItem('深色', this.themeMode === 'dark', () => { this.saveThemeMode('dark') })
      } else if (row.key === 'reader-background') {
        this.SelectionMenuItem('黑色', this.readerBackgroundMode === 'black', () => { this.saveReaderBackgroundMode('black') })
        this.SelectionMenuItem('纸张', this.readerBackgroundMode === 'paper', () => { this.saveReaderBackgroundMode('paper') })
        this.SelectionMenuItem('浅色', this.readerBackgroundMode === 'light', () => { this.saveReaderBackgroundMode('light') })
      } else if (row.key === 'reader-progress') {
        this.SelectionMenuItem('显示', this.showReaderProgressControls, () => { this.saveReaderProgressControls(true) })
        this.SelectionMenuItem('隐藏', !this.showReaderProgressControls, () => { this.saveReaderProgressControls(false) })
      } else if (row.key === 'reader-keep-screen-awake') {
        this.SelectionMenuItem('开启', this.keepReaderScreenAwake, () => { this.saveReaderKeepScreenAwake(true) })
        this.SelectionMenuItem('关闭', !this.keepReaderScreenAwake, () => { this.saveReaderKeepScreenAwake(false) })
      } else if (row.key === 'reader-image-fit') {
        this.SelectionMenuItem('适合屏幕', this.readerImageFitMode === 'contain', () => { this.saveReaderImageFitMode('contain') })
        this.SelectionMenuItem('适合宽度', this.readerImageFitMode === 'fit_width', () => { this.saveReaderImageFitMode('fit_width') })
      } else if (row.key === 'reader-tap-navigation') {
        this.SelectionMenuItem('开启', this.readerTapNavigationEnabled, () => { this.saveReaderTapNavigationEnabled(true) })
        this.SelectionMenuItem('关闭', !this.readerTapNavigationEnabled, () => { this.saveReaderTapNavigationEnabled(false) })
      } else if (row.key === 'reader-tap-zone-preset') {
        this.SelectionMenuItem('窄边缘', this.readerTapZonePreset === 'edge', () => { this.saveReaderTapZonePreset('edge') })
        this.SelectionMenuItem('宽侧区', this.readerTapZonePreset === 'wide_edges', () => { this.saveReaderTapZonePreset('wide_edges') })
      } else if (row.key === 'reader-page-gap') {
        this.SelectionMenuItem('紧凑', this.readerPageGapMode === 'compact', () => { this.saveReaderPageGapMode('compact') })
        this.SelectionMenuItem('标准', this.readerPageGapMode === 'normal', () => { this.saveReaderPageGapMode('normal') })
        this.SelectionMenuItem('宽松', this.readerPageGapMode === 'wide', () => { this.saveReaderPageGapMode('wide') })
      } else if (row.key === 'reader-trim-page-margins') {
        this.SelectionMenuItem('开启', this.readerTrimPageMarginsEnabled, () => { this.saveReaderTrimPageMarginsEnabled(true) })
        this.SelectionMenuItem('关闭', !this.readerTrimPageMarginsEnabled, () => { this.saveReaderTrimPageMarginsEnabled(false) })
      } else if (row.key === 'reader-wide-image-mode') {
        this.SelectionMenuItem('保持单页', this.readerWideImageMode === 'keep_single', () => { this.saveReaderWideImageMode('keep_single') })
        this.SelectionMenuItem('拆分宽图', this.readerWideImageMode === 'split_wide_pages', () => { this.saveReaderWideImageMode('split_wide_pages') })
        this.SelectionMenuItem('旋转宽图', this.readerWideImageMode === 'rotate_wide_pages', () => { this.saveReaderWideImageMode('rotate_wide_pages') })
      } else if (row.key === 'reader-volume-key-navigation') {
        this.SelectionMenuItem('开启', this.readerVolumeKeyNavigationEnabled, () => { this.saveReaderVolumeKeyNavigationEnabled(true) })
        this.SelectionMenuItem('关闭', !this.readerVolumeKeyNavigationEnabled, () => { this.saveReaderVolumeKeyNavigationEnabled(false) })
      } else if (row.key === 'library-update-interval') {
        this.SelectionMenuItem('每 12 小时', this.libraryUpdatePreferences.intervalHours === 12, () => { this.saveLibraryUpdateInterval(12) })
        this.SelectionMenuItem('每 24 小时', this.libraryUpdatePreferences.intervalHours === 24, () => { this.saveLibraryUpdateInterval(24) })
        this.SelectionMenuItem('每 48 小时', this.libraryUpdatePreferences.intervalHours === 48, () => { this.saveLibraryUpdateInterval(48) })
      }
    }
  }

  private showImageCacheConfirm(): void {
    this.getUIContext().showAlertDialog({
      message: `清理图片缓存？\n${this.imageCacheDetail}`,
      primaryButton: {
        value: '取消',
        action: () => {},
      },
      secondaryButton: {
        value: '清理缓存',
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
        this.showToast('请先开启自动检查更新')
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
      this.showToast(`${row.title}稍后接入`)
    }
  }

  @Builder
  private SectionRow(row: SettingsRow) {
    if (row.key === 'library-auto-update') {
      ConciseListRow({
        title: row.title,
        subtitle: this.rowDetail(row),
        showChevron: false,
        hasSwitch: true,
        checked: this.libraryUpdatePreferences.autoCheckEnabled,
        switchAction: (isOn: boolean) => {
          this.setLibraryAutoUpdateEnabled(isOn)
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
      ForEach(SETTINGS_ROOT_SECTIONS, (section: SettingsPaneSection) => {
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
      SectionHeader({ title: '搜索结果' })
      if (this.settingsSearchResults().length === 0) {
        GroupedListSection() {
          ConciseListRow({
            title: '没有找到设置',
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
    Search({ value: this.settingsSearchText, placeholder: '搜索设置' })
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
