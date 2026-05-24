import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomgaServerPage } from './KomgaServerPage'

const KOMGA_SERVER_ROUTE_NAME: string = 'KomgaServerPage'

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
      { key: 'sources', title: '源管理', detail: '管理已安装的源包' },
      { key: 'backup', title: '备份与恢复', detail: '导出书架及阅读进度' },
    ],
  },
  {
    key: 'about',
    title: '关于',
    rows: [
      { key: 'version', title: '版本', detail: 'Koma 开发版' },
      { key: 'open-source', title: '开源许可', detail: '查看依赖与许可证' },
    ],
  },
]

@Component
export struct SettingsPage {
  private settingsPathStack: NavPathStack = new NavPathStack()

  private openKomgaSettings(): void {
    this.settingsPathStack.pushPath({ name: KOMGA_SERVER_ROUTE_NAME })
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
      Text(row.detail)
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      if (row.key === 'komga') {
        this.openKomgaSettings()
      }
    })
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
    }
  }
}
