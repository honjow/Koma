import { bundleManager, common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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
  formatLibraryUpdateNotificationSummary,
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
  getLibraryUpdateNotificationStatusLabel,
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
}

interface SettingsSection {
  key: string
  title: string
  rows: SettingsRow[]
}

const SETTINGS_SECTIONS: SettingsSection[] = [
  {
    key: 'appearance',
    title: '外观',
    rows: [
      { key: 'theme', title: '主题', detail: '跟随系统' },
      { key: 'language', title: '语言', detail: '简体中文' },
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
      { key: 'library-update-notifications', title: '更新提醒', detail: '计划中 · 暂不发送' },
      { key: 'library-update', title: '检查书架更新', detail: '尚未检查' },
      { key: 'library-update-results', title: '书架更新详情', detail: '尚无结果' },
      { key: 'library-categories', title: '书架分类', detail: '管理自定义分类' },
      { key: 'local-library-refresh', title: '刷新本地导入', detail: '需要重新选择本地文件' },
      { key: 'sources', title: '管理已安装的源包', detail: '暂未安装源包' },
      { key: 'downloads', title: '下载管理', detail: '离线章节与失败任务' },
      { key: 'trackers', title: '追踪账号', detail: '安全存储未验证，账号未连接' },
      { key: 'backup', title: '备份与恢复', detail: '导出书架、进度、源包和设置' },
      { key: 'image-cache', title: '图片缓存', detail: '0 B · 0 项' },
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

function safeSettingsErrorCode(error: Error): string {
  return normalizeLibraryUpdateFailureCode(error.name) ?? 'unknown'
}

@Component
export struct SettingsPage {
  onOpenKomgaSettings: () => void = () => {}
  onOpenOpdsSettings: () => void = () => {}
  onOpenWebDavSettings: () => void = () => {}
  onOpenSourcePackageManager: () => void = () => {}
  onOpenLibraryUpdateResults: () => void = () => {}
  onOpenLibraryCategories: () => void = () => {}
  onOpenDownloads: () => void = () => {}
  onOpenBackupManagement: () => void = () => {}
  onOpenTrackerSettings: () => void = () => {}
  onLibraryChanged: () => void = () => {}
  libraryStore?: LibraryStore
  libraryPersistenceService?: LibraryStorePersistenceService
  sourceRegistry?: SourceRuntimeRegistry
  @State private pageMode: ReaderPageMode = 'single_page'
  @State private readingDirection: ReadingDirection = ReadingDirection.LEFT_TO_RIGHT
  @State private themeMode: ReaderThemeMode = 'system'
  @State private readerBackgroundMode: ReaderBackgroundMode = 'black'
  @State private showReaderProgressControls: boolean = true
  @State private keepReaderScreenAwake: boolean = true
  @State private readerImageFitMode: ReaderImageFitMode = 'contain'
  @State private readerTapNavigationEnabled: boolean = true
  @State private readerTapZonePreset: ReaderTapZonePreset = 'edge'
  @State private readerPageGapMode: ReaderPageGapMode = 'normal'
  @State private readerTrimPageMarginsEnabled: boolean = false
  @State private readerWideImageMode: ReaderWideImageMode = 'keep_single'
  @State private readerVolumeKeyNavigationEnabled: boolean = false
  @State private versionDetail: string = 'Koma 开发版'
  @State private imageCacheDetail: string = '0 B · 0 项'
  @State private libraryUpdateBusy: boolean = false
  @State private libraryUpdateSummary?: LibraryUpdateSummary = undefined
  @State private libraryUpdatePreferences: LibraryUpdatePreferences = DEFAULT_LIBRARY_UPDATE_PREFERENCES
  @State private localLibraryRefreshBusy: boolean = false
  @State private localLibraryRefreshSummary?: LocalLibraryRefreshSummary = undefined

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
    if (row.key === 'library-update-notifications') {
      const effectiveSummary = this.getEffectiveLibraryUpdateSummary()
      if (effectiveSummary !== undefined) {
        return `${getLibraryUpdateNotificationStatusLabel()} · ${formatLibraryUpdateNotificationSummary(effectiveSummary)}`
      }
      return getLibraryUpdateNotificationStatusLabel()
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
      row.key === 'library-update-notifications' ||
      row.key === 'local-library-refresh') {
      return 2
    }
    return 1
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

  private showPageModeSheet(): void {
    console.info('[Settings] step=page_mode_sheet')
    this.getUIContext().showActionSheet({
      title: '翻页模式',
      message: '选择阅读器默认翻页模式',
      sheets: [
        { title: '单页', action: () => { this.savePageMode('single_page') } },
        { title: '双页', action: () => { this.savePageMode('double_page') } },
        { title: '连续滚动', action: () => { this.savePageMode('continuous_scroll') } },
      ],
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

  private showReadingDirectionSheet(): void {
    console.info('[Settings] step=reading_direction_sheet')
    this.getUIContext().showActionSheet({
      title: '阅读方向',
      message: '选择阅读器默认阅读方向',
      sheets: [
        { title: '从左到右', action: () => { this.saveReadingDirection(ReadingDirection.LEFT_TO_RIGHT) } },
        { title: '从右到左', action: () => { this.saveReadingDirection(ReadingDirection.RIGHT_TO_LEFT) } },
        { title: '纵向', action: () => { this.saveReadingDirection(ReadingDirection.WEBTOON) } },
      ],
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

  private showThemeSheet(): void {
    console.info('[Settings] step=theme_sheet')
    this.getUIContext().showActionSheet({
      title: '主题',
      message: '选择应用深浅色模式',
      sheets: [
        { title: '跟随系统', action: () => { this.saveThemeMode('system') } },
        { title: '浅色', action: () => { this.saveThemeMode('light') } },
        { title: '深色', action: () => { this.saveThemeMode('dark') } },
      ],
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

  private showReaderBackgroundSheet(): void {
    console.info('[Settings] step=reader_background_sheet')
    this.getUIContext().showActionSheet({
      title: '阅读背景',
      message: '选择阅读器页面外的背景颜色',
      sheets: [
        { title: '黑色', action: () => { this.saveReaderBackgroundMode('black') } },
        { title: '纸张', action: () => { this.saveReaderBackgroundMode('paper') } },
        { title: '浅色', action: () => { this.saveReaderBackgroundMode('light') } },
      ],
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

  private showReaderProgressSheet(): void {
    console.info('[Settings] step=reader_progress_sheet')
    this.getUIContext().showActionSheet({
      title: '页码与进度',
      message: '控制阅读器底部页码和进度条显示',
      sheets: [
        { title: '显示', action: () => { this.saveReaderProgressControls(true) } },
        { title: '隐藏', action: () => { this.saveReaderProgressControls(false) } },
      ],
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

  private showReaderKeepScreenAwakeSheet(): void {
    console.info('[Settings] step=reader_keep_screen_awake_sheet')
    this.getUIContext().showActionSheet({
      title: '屏幕常亮',
      message: '控制阅读器打开时是否保持屏幕常亮',
      sheets: [
        { title: '开启', action: () => { this.saveReaderKeepScreenAwake(true) } },
        { title: '关闭', action: () => { this.saveReaderKeepScreenAwake(false) } },
      ],
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

  private showReaderImageFitSheet(): void {
    console.info('[Settings] step=reader_image_fit_sheet')
    this.getUIContext().showActionSheet({
      title: '图片适配',
      message: '控制阅读器图片缩放方式',
      sheets: [
        { title: '适合屏幕', action: () => { this.saveReaderImageFitMode('contain') } },
        { title: '适合宽度', action: () => { this.saveReaderImageFitMode('fit_width') } },
      ],
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

  private showReaderTapNavigationSheet(): void {
    console.info('[Settings] step=reader_tap_navigation_sheet')
    this.getUIContext().showActionSheet({
      title: '点击翻页',
      message: '控制左右点击区域是否翻页',
      sheets: [
        { title: '开启', action: () => { this.saveReaderTapNavigationEnabled(true) } },
        { title: '关闭', action: () => { this.saveReaderTapNavigationEnabled(false) } },
      ],
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

  private showReaderTapZonePresetSheet(): void {
    console.info('[Settings] step=reader_tap_zone_preset_sheet')
    this.getUIContext().showActionSheet({
      title: '点击区域',
      message: '选择左右翻页点击区域大小，中间区域仍用于显示或隐藏工具栏。',
      sheets: [
        { title: '窄边缘', action: () => { this.saveReaderTapZonePreset('edge') } },
        { title: '宽侧区', action: () => { this.saveReaderTapZonePreset('wide_edges') } },
      ],
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

  private showReaderPageGapSheet(): void {
    console.info('[Settings] step=reader_page_gap_sheet')
    this.getUIContext().showActionSheet({
      title: '页面间距',
      message: '控制阅读器页面之间的距离',
      sheets: [
        { title: '紧凑', action: () => { this.saveReaderPageGapMode('compact') } },
        { title: '标准', action: () => { this.saveReaderPageGapMode('normal') } },
        { title: '宽松', action: () => { this.saveReaderPageGapMode('wide') } },
      ],
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

  private showReaderTrimPageMarginsSheet(): void {
    console.info('[Settings] step=reader_trim_page_margins_sheet')
    this.getUIContext().showActionSheet({
      title: '收紧页边（不裁图）',
      message: '仅收紧阅读器页面容器留白，不裁切漫画图片内容',
      sheets: [
        { title: '开启', action: () => { this.saveReaderTrimPageMarginsEnabled(true) } },
        { title: '关闭', action: () => { this.saveReaderTrimPageMarginsEnabled(false) } },
      ],
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

  private showReaderWideImageModeSheet(): void {
    console.info('[Settings] step=reader_wide_image_mode_sheet')
    this.getUIContext().showActionSheet({
      title: '宽图处理',
      message: '宽图拆分和旋转仅在页面带有可靠宽高元数据时生效；拆分优先于旋转，缺少尺寸时保持当前显示。',
      sheets: [
        { title: '保持单页', action: () => { this.saveReaderWideImageMode('keep_single') } },
        { title: '拆分宽图', action: () => { this.saveReaderWideImageMode('split_wide_pages') } },
        { title: '旋转宽图', action: () => { this.saveReaderWideImageMode('rotate_wide_pages') } },
      ],
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

  private showReaderVolumeKeyNavigationSheet(): void {
    console.info('[Settings] step=reader_volume_key_navigation_sheet')
    this.getUIContext().showActionSheet({
      title: '音量键翻页',
      message: '开启后，阅读器获得焦点时音量上/下会执行上一页/下一页；未开启时不拦截系统音量键。',
      sheets: [
        { title: '开启', action: () => { this.saveReaderVolumeKeyNavigationEnabled(true) } },
        { title: '关闭', action: () => { this.saveReaderVolumeKeyNavigationEnabled(false) } },
      ],
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

  private showImageCacheSheet(): void {
    console.info('[Settings] step=image_cache_sheet')
    this.getUIContext().showActionSheet({
      title: '图片缓存',
      message: this.imageCacheDetail,
      sheets: [
        { title: '清理缓存', action: () => { this.clearImageCache() } },
      ],
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

  private showLibraryUpdateIntervalSheet(): void {
    if (!this.libraryUpdatePreferences.autoCheckEnabled) {
      this.showToast('请先开启自动检查更新')
      return
    }
    console.info('[Settings] step=library_update_interval_sheet')
    this.getUIContext().showActionSheet({
      title: '检查间隔',
      message: '打开应用时自动检查书架更新',
      sheets: [
        { title: '每 12 小时', action: () => { this.saveLibraryUpdateInterval(12) } },
        { title: '每 24 小时', action: () => { this.saveLibraryUpdateInterval(24) } },
        { title: '每 48 小时', action: () => { this.saveLibraryUpdateInterval(48) } },
      ],
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
        { text: '确定', color: '#8D5A3B' },
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

  private handleRowClick(row: SettingsRow): void {
    if (row.key === 'komga') {
      this.onOpenKomgaSettings()
    } else if (row.key === 'opds') {
      this.onOpenOpdsSettings()
    } else if (row.key === 'webdav') {
      this.onOpenWebDavSettings()
    } else if (row.key === 'page-mode') {
      this.showPageModeSheet()
    } else if (row.key === 'reading-direction') {
      this.showReadingDirectionSheet()
    } else if (row.key === 'theme') {
      this.showThemeSheet()
    } else if (row.key === 'reader-background') {
      this.showReaderBackgroundSheet()
    } else if (row.key === 'reader-progress') {
      this.showReaderProgressSheet()
    } else if (row.key === 'reader-keep-screen-awake') {
      this.showReaderKeepScreenAwakeSheet()
    } else if (row.key === 'reader-image-fit') {
      this.showReaderImageFitSheet()
    } else if (row.key === 'reader-tap-navigation') {
      this.showReaderTapNavigationSheet()
    } else if (row.key === 'reader-tap-zone-preset') {
      this.showReaderTapZonePresetSheet()
    } else if (row.key === 'reader-page-gap') {
      this.showReaderPageGapSheet()
    } else if (row.key === 'reader-trim-page-margins') {
      this.showReaderTrimPageMarginsSheet()
    } else if (row.key === 'reader-wide-image-mode') {
      this.showReaderWideImageModeSheet()
    } else if (row.key === 'reader-volume-key-navigation') {
      this.showReaderVolumeKeyNavigationSheet()
    } else if (row.key === 'backup') {
      this.onOpenBackupManagement()
    } else if (row.key === 'trackers') {
      this.onOpenTrackerSettings()
    } else if (row.key === 'image-cache') {
      this.showImageCacheSheet()
    } else if (row.key === 'sources') {
      this.showSourcesDialog()
    } else if (row.key === 'downloads') {
      this.onOpenDownloads()
    } else if (row.key === 'library-auto-update') {
      this.setLibraryAutoUpdateEnabled(!this.libraryUpdatePreferences.autoCheckEnabled)
    } else if (row.key === 'library-update-interval') {
      this.showLibraryUpdateIntervalSheet()
    } else if (row.key === 'library-update-notifications') {
      this.showInfoDialog('更新提醒', '当前版本只保存前台检查结果和提醒摘要，不会发送提醒。真正可投递的提醒会在权限、实现和设备验证齐备后再开放。')
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
    } else if (row.key === 'language') {
      this.showInfoDialog('语言', '当前为简体中文。')
    }
  }

  @Builder
  private SectionTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.koma_accent'))
      .padding({ left: 4, top: 8, bottom: 4 })
  }

  @Builder
  private SectionRow(row: SettingsRow) {
    Row({ space: 12 }) {
      Text(row.title)
        .fontSize(15)
        .fontColor($r('app.color.koma_text_primary'))
        .layoutWeight(1)
      Text(this.rowDetail(row))
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .maxLines(this.rowDetailMaxLines(row))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (row.key === 'library-auto-update') {
        Toggle({ type: ToggleType.Switch, isOn: this.libraryUpdatePreferences.autoCheckEnabled })
          .onChange((isOn: boolean) => {
            this.setLibraryAutoUpdateEnabled(isOn)
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      if (row.key !== 'library-auto-update') {
        this.handleRowClick(row)
      }
    })
  }

  aboutToAppear(): void {
    this.loadLatestLibraryUpdateSummary()
    this.loadVersion()
    this.loadPreferences()
    this.loadLibraryUpdatePreferences()
    this.loadImageCacheStats()
  }

  @Builder
  private Section(section: SettingsSection) {
    Column() {
      this.SectionTitle(section.title)

      Column() {
        ForEach(section.rows, (row: SettingsRow, index: number) => {
          this.SectionRow(row)
          if (index < section.rows.length - 1) {
            Divider()
              .strokeWidth(0.5)
              .color($r('app.color.koma_background'))
              .margin({ left: 16, right: 16 })
          }
        }, (row: SettingsRow) => row.key)
      }
      .width('100%')
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
    }
    .width('100%')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 18,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        ForEach(SETTINGS_SECTIONS, (section: SettingsSection) => {
          ListItem() {
            this.Section(section)
          }
        }, (section: SettingsSection) => section.key)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
