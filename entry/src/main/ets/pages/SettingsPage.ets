import { bundleManager, common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ReadingDirection } from '../model/ComicModels'
import { BackupService } from '../model/BackupService'
import {
  ReaderPageMode,
  ReaderPreferencesStore,
  ReaderThemeMode,
  applyReaderThemeMode,
  getReaderPageModeLabel,
  getReaderThemeModeLabel,
  getReadingDirectionLabel,
} from '../model/ReaderPreferencesStore'
import { KomgaServerPage } from './KomgaServerPage'
import { OpdsServerPage } from './OpdsServerPage'
import { SourcePackageManagerPage } from './SourcePackageManagerPage'
import { WebDavServerPage } from './WebDavServerPage'
import { listInstalled } from '../sourceRuntime/SourceRuntimeAppRegistry'

const KOMGA_SERVER_ROUTE_NAME: string = 'KomgaServerPage'
const OPDS_SERVER_ROUTE_NAME: string = 'OpdsServerPage'
const WEBDAV_SERVER_ROUTE_NAME: string = 'WebDavServerPage'
const SOURCE_PACKAGE_MANAGER_ROUTE_NAME: string = 'SourcePackageManagerPage'

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
    ],
  },
  {
    key: 'data',
    title: '数据',
    rows: [
      { key: 'komga', title: 'Komga 私有库', detail: '服务器与认证' },
      { key: 'opds', title: 'OPDS 私有库', detail: 'Catalog 与认证' },
      { key: 'webdav', title: 'WebDAV 私有库', detail: '远程文件夹与认证' },
      { key: 'sources', title: '管理已安装的源包', detail: '暂未安装源包' },
      { key: 'backup', title: '备份与恢复', detail: '导出书架及阅读进度' },
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

@Component
export struct SettingsPage {
  private settingsPathStack: NavPathStack = new NavPathStack()
  @State private pageMode: ReaderPageMode = 'single_page'
  @State private readingDirection: ReadingDirection = ReadingDirection.LEFT_TO_RIGHT
  @State private themeMode: ReaderThemeMode = 'system'
  @State private versionDetail: string = 'Koma 开发版'

  private openKomgaSettings(): void {
    this.settingsPathStack.pushPath({ name: KOMGA_SERVER_ROUTE_NAME })
  }

  private openWebDavSettings(): void {
    this.settingsPathStack.pushPath({ name: WEBDAV_SERVER_ROUTE_NAME })
  }

  private openOpdsSettings(): void {
    this.settingsPathStack.pushPath({ name: OPDS_SERVER_ROUTE_NAME })
  }

  private openSourcePackageManager(): void {
    this.settingsPathStack.pushPath({ name: SOURCE_PACKAGE_MANAGER_ROUTE_NAME })
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private preferencesStore(): ReaderPreferencesStore {
    return new ReaderPreferencesStore(this.context())
  }

  private backupService(): BackupService {
    return new BackupService(this.context())
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
    if (row.key === 'version') {
      return this.versionDetail
    }
    if (row.key === 'sources') {
      const count = listInstalled().length
      return count > 0 ? `${count} 个源包` : '暂未安装源包'
    }
    return row.detail
  }

  private loadPreferences(): void {
    void this.preferencesStore().load()
      .then((preferences) => {
        this.pageMode = preferences.pageMode
        this.readingDirection = preferences.readingDirection
        this.themeMode = preferences.themeMode
        console.info('[Settings] step=load_preferences')
      })
      .catch((error: Error) => {
        console.warn('[Settings] step=load_preferences_failed message=' + error.message)
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

  private showBackupSheet(): void {
    console.info('[Settings] step=backup_sheet')
    this.getUIContext().showActionSheet({
      title: '备份与恢复',
      message: '导出或导入书架、阅读进度和远程服务器配置',
      sheets: [
        { title: '导出备份', action: () => { this.exportBackup() } },
        { title: '导入备份', action: () => { this.importBackup() } },
      ],
    })
  }

  private exportBackup(): void {
    console.info('[Settings] step=backup_export_start')
    void this.backupService().exportToPicker()
      .then((uri: string | undefined) => {
        if (uri !== undefined) {
          this.showInfoDialog('备份已导出', '备份 JSON 已保存到所选位置。')
        }
      })
      .catch((error: Error) => {
        console.error('[Settings] step=backup_export_failed message=' + error.message)
        this.showInfoDialog('导出失败', error.message)
      })
  }

  private importBackup(): void {
    console.info('[Settings] step=backup_import_start')
    void this.backupService().importFromPicker()
      .then(() => {
        this.showInfoDialog('备份已导入', '书架、阅读进度和远程服务器配置已恢复。')
      })
      .catch((error: Error) => {
        console.error('[Settings] step=backup_import_failed message=' + error.message)
        this.showInfoDialog('导入失败', error.message)
      })
  }

  private showSourcesDialog(): void {
    console.info('[Settings] step=sources_manager_open')
    this.openSourcePackageManager()
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
      this.openKomgaSettings()
    } else if (row.key === 'opds') {
      this.openOpdsSettings()
    } else if (row.key === 'webdav') {
      this.openWebDavSettings()
    } else if (row.key === 'page-mode') {
      this.showPageModeSheet()
    } else if (row.key === 'reading-direction') {
      this.showReadingDirectionSheet()
    } else if (row.key === 'theme') {
      this.showThemeSheet()
    } else if (row.key === 'backup') {
      this.showBackupSheet()
    } else if (row.key === 'sources') {
      this.showSourcesDialog()
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
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.handleRowClick(row)
    })
  }

  aboutToAppear(): void {
    this.loadVersion()
    this.loadPreferences()
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
    Navigation(this.settingsPathStack) {
      Column() {
        SecondaryListScaffold({
          listSpace: 18,
          horizontalPadding: 20,
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
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
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.SettingsDestination)
  }

  @Builder
  private SettingsDestination(name: string, _param: Object) {
    if (name === KOMGA_SERVER_ROUTE_NAME) {
      NavDestination() {
        KomgaServerPage()
      }
      .title('Komga')
    } else if (name === OPDS_SERVER_ROUTE_NAME) {
      NavDestination() {
        OpdsServerPage()
      }
      .title('OPDS')
    } else if (name === WEBDAV_SERVER_ROUTE_NAME) {
      NavDestination() {
        WebDavServerPage()
      }
      .title('WebDAV')
    } else if (name === SOURCE_PACKAGE_MANAGER_ROUTE_NAME) {
      NavDestination() {
        SourcePackageManagerPage()
      }
      .title('源包管理')
    }
  }
}
